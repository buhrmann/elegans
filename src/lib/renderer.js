// @ts-check

import * as d3 from "d3";

const AUTO_ARROW_EDGE_THRESHOLD = 1000;
const ARROW_TARGET_PADDING = 0;
const HOVER_FOCUS_DELAY_MS = 180;

const TYPE_COLORS = new Map([
  ["inter", "#00ADEF"],
  ["motor", "#F5892D"],
  ["inter, motor", "#4dc0ee"],
  ["sensory", "#ED008C"],
  ["sensory, inter", "#ff5cb6"],
  ["sensory, motor", "#ff9a4a"],
  ["muscle", "#666666"],
]);

/**
 * @param {string} type
 */
export function colorForType(type) {
  return TYPE_COLORS.get(type) ?? "#BBBBBB";
}

/**
 * @typedef {{
 *   id: string;
 *   kind: string;
 *   name: string;
 *   type: string;
 *   D: number;
 *   kx?: number | null;
 *   ky?: number | null;
 *   pos?: number;
 *   x?: number;
 *   y?: number;
 *   vx?: number;
 *   vy?: number;
 *   fx?: number | null;
 *   fy?: number | null;
 *   radius?: number;
 * }} RenderNode
 */

/**
 * @typedef {{
 *   id: string;
 *   sourceId: string;
 *   targetId: string;
 *   type: string;
 *   weight: number;
 *   source?: RenderNode;
 *   target?: RenderNode;
 * }} RenderEdge
 */

/**
 * @param {{
 *   container: HTMLElement;
 *   onNodeSelect: (node: RenderNode | null) => void;
 *   onEdgeHover?: (edge: RenderEdge | null) => void;
 * }} options
 */
export function createRenderer(options) {
  const { container, onNodeSelect, onEdgeHover } = options;
  const canvas = document.createElement("canvas");
  canvas.className = "graph-edge-canvas";
  container.append(canvas);
  const backgroundContext = canvas.getContext("2d");
  if (!backgroundContext) {
    throw new Error("Canvas rendering is unavailable in this browser.");
  }
  const svg = d3
    .select(container)
    .append("svg")
    .attr("viewBox", `0 0 ${container.clientWidth || window.innerWidth} ${container.clientHeight || window.innerHeight}`)
    .on("click", () => {
      clearPendingHover();
      hoveredNodeId = null;
      selectedNodeId = null;
      applyFocusState();
      onNodeSelect(null);
    });

  const defs = svg.append("defs");
  defs
    .append("marker")
    .attr("id", "arrowhead")
    .attr("viewBox", "0 -4 8 8")
    .attr("refX", 8)
    .attr("refY", 0)
    .attr("markerWidth", 8)
    .attr("markerHeight", 8)
    .attr("markerUnits", "userSpaceOnUse")
    .attr("orient", "auto")
    .append("path")
    .attr("d", "M0,-4L8,0L0,4")
    .attr("fill", "context-stroke");

  const root = svg.append("g");
  const linkLayer = root.append("g");
  const nodeLayer = root.append("g");
  const tooltip = d3.select(document.body).append("div").attr("class", "graph-tooltip hidden");

  const zoom = d3
    .zoom()
    .scaleExtent([0.5, 3])
    .on("start", () => {
      svg.classed("is-panning", true);
    })
    .on("zoom", (event) => {
      currentTransform = event.transform;
      root.attr("transform", currentTransform.toString());
      drawBackgroundEdges();
    })
    .on("end", () => {
      svg.classed("is-panning", false);
    });
  svg.call(zoom);

  /** @type {RenderNode[]} */
  let nodes = [];
  /** @type {RenderEdge[]} */
  let edges = [];
  /** @type {Map<string, RenderNode>} */
  let previousNodesById = new Map();
  /** @type {Set<string>} */
  let hiddenNodeIds = new Set();
  /** @type {Set<string>} */
  let hiddenEdgeIds = new Set();
  /** @type {Map<string, { nodeIds: Set<string>; edgeIds: Set<string> }>} */
  let neighborhoodsByNodeId = new Map();
  let selectedNodeId = null;
  let hoveredNodeId = null;
  let arcs = false;
  let showArrowheads = false;
  let width = container.clientWidth || window.innerWidth;
  let height = container.clientHeight || window.innerHeight;
  let pixelRatio = window.devicePixelRatio || 1;
  let currentTransform = d3.zoomIdentity;
  let lastFocusKey = null;
  let hoverTimerId = null;
  let pendingHoverNodeId = null;
  let didDrag = false;
  /** @type {RenderEdge[]} */
  let backgroundEdges = [];
  /** @type {RenderEdge[]} */
  let foregroundEdges = [];

  const nodeRadiusScale = d3.scaleLinear().range([10, 25]);
  const edgeWeightScale = d3.scaleLinear().range([1, 5]);

  const simulation = d3
    .forceSimulation()
    .force(
      "link",
      d3
        .forceLink()
        .id((node) => /** @type {RenderNode} */ (node).id)
        .distance(85)
        .strength(0.45),
    )
    .force("charge", d3.forceManyBody().strength(-180))
    .force("collide", d3.forceCollide().radius((node) => /** @type {RenderNode} */ (node).radius ?? 12))
    .force("center", d3.forceCenter(width / 2, height / 2))
    .force("x", d3.forceX((node) => targetX(/** @type {RenderNode} */ (node), width)).strength(0.14))
    .force("y", d3.forceY((node) => targetY(/** @type {RenderNode} */ (node), height)).strength(0.2))
    .on("tick", ticked);

  /** @type {d3.Selection<SVGGElement, RenderNode, SVGGElement, unknown>} */
  let nodeSelection = nodeLayer.selectAll(".graph-node");
  /** @type {d3.Selection<SVGPathElement, RenderEdge, SVGGElement, unknown>} */
  let linkSelection = linkLayer.selectAll(".graph-link");

  function resizeCanvas() {
    pixelRatio = window.devicePixelRatio || 1;
    canvas.width = Math.round(width * pixelRatio);
    canvas.height = Math.round(height * pixelRatio);
    canvas.style.width = `${width}px`;
    canvas.style.height = `${height}px`;
  }

  function resize() {
    width = container.clientWidth || window.innerWidth;
    height = container.clientHeight || window.innerHeight;
    resizeCanvas();
    svg.attr("viewBox", `0 0 ${width} ${height}`);
    simulation.force("center", d3.forceCenter(width / 2, height / 2));
    simulation.force("x", d3.forceX((node) => targetX(/** @type {RenderNode} */ (node), width)).strength(0.14));
    simulation.force("y", d3.forceY((node) => targetY(/** @type {RenderNode} */ (node), height)).strength(0.2));
    simulation.alpha(0.5).restart();
    drawBackgroundEdges();
  }

  resizeCanvas();
  window.addEventListener("resize", resize);

  function clearPendingHover() {
    if (hoverTimerId != null) {
      window.clearTimeout(hoverTimerId);
      hoverTimerId = null;
    }
    pendingHoverNodeId = null;
  }

  /**
   * @param {string} nodeId
   */
  function queueHoverFocus(nodeId) {
    clearPendingHover();
    pendingHoverNodeId = nodeId;
    hoverTimerId = window.setTimeout(() => {
      hoverTimerId = null;
      if (selectedNodeId || pendingHoverNodeId !== nodeId) {
        return;
      }
      pendingHoverNodeId = null;
      hoveredNodeId = nodeId;
      applyFocusState();
    }, HOVER_FOCUS_DELAY_MS);
  }

  /**
   * @param {{ nodes: RenderNode[]; edges: RenderEdge[] }} graph
   */
  function setGraph(graph) {
    const prevMap = new Map(previousNodesById);
    const degrees = graph.nodes.map((node) => node.D);
    const weights = graph.edges.map((edge) => edge.weight);
    nodeRadiusScale.domain(d3.extent(degrees.length ? degrees : [0, 1]));
    edgeWeightScale.domain(d3.extent(weights.length ? weights : [1, 2]));

    nodes = graph.nodes.map((node) => {
      const prev = prevMap.get(node.id);
      const nextNode = {
        ...node,
        radius: nodeRadiusScale(node.D || 0),
      };
      if (prev) {
        nextNode.x = prev.x;
        nextNode.y = prev.y;
        nextNode.fx = prev.fx ?? null;
        nextNode.fy = prev.fy ?? null;
      } else {
        seedPosition(nextNode, width, height);
      }
      return nextNode;
    });
    previousNodesById = new Map(nodes.map((node) => [node.id, node]));

    /** @type {Map<string, RenderNode>} */
    const nodesById = new Map(nodes.map((node) => [node.id, node]));
    edges = graph.edges.map((edge) => ({
      ...edge,
      source: nodesById.get(edge.sourceId),
      target: nodesById.get(edge.targetId),
    }));
    clearPendingHover();
    hoveredNodeId = null;
    if (selectedNodeId && !nodesById.has(selectedNodeId)) {
      selectedNodeId = null;
      onNodeSelect(null);
    }
    neighborhoodsByNodeId = buildNeighborhoods(nodes, edges);
    lastFocusKey = null;

    nodeSelection = nodeLayer.selectAll(".graph-node").data(nodes, (node) => /** @type {RenderNode} */ (node).id);
    nodeSelection.exit().remove();

    const nodeEnter = nodeSelection
      .enter()
      .append("g")
      .attr("class", "graph-node selectable")
      .call(
        d3
          .drag()
          .on("start", dragStarted)
          .on("drag", dragged)
          .on("end", dragEnded),
      )
      .on("click", (event, node) => {
        event.stopPropagation();
        clearPendingHover();
        hoveredNodeId = null;
        selectedNodeId = selectedNodeId === node.id ? null : node.id;
        onNodeSelect(selectedNodeId ? node : null);
        applyFocusState();
      })
      .on("dblclick", (event, node) => {
        event.stopPropagation();
        node.fx = null;
        node.fy = null;
        applyFixedState();
        simulation.alpha(0.4).restart();
      })
      .on("mouseenter", (_event, node) => {
        if (selectedNodeId || hoveredNodeId === node.id || pendingHoverNodeId === node.id) {
          return;
        }
        queueHoverFocus(node.id);
      })
      .on("mouseleave", (_event, node) => {
        if (pendingHoverNodeId === node.id) {
          clearPendingHover();
        }
        if (selectedNodeId) {
          return;
        }
        if (hoveredNodeId === node.id) {
          hoveredNodeId = null;
          applyFocusState();
        }
      });

    nodeEnter
      .append("circle")
      .attr("r", (node) => node.radius ?? 12)
      .style("fill", (node) => colorForType(node.type));

    nodeEnter
      .append("text")
      .attr("class", "graph-node-label")
      .attr("text-anchor", "middle")
      .attr("dy", "0.35em")
      .text((node) => node.name);

    nodeSelection = nodeEnter.merge(nodeSelection);
    nodeSelection.select("circle").attr("r", (node) => node.radius ?? 12).style("fill", (node) => colorForType(node.type));

    simulation.nodes(nodes);
    simulation.force("link").links(edges);
    simulation.alpha(0.7).restart();
    applyVisibilityState();
    applyFixedState();
    applyFocusState(true);
  }

  /**
   * @param {Set<string>} nextHiddenNodeIds
   * @param {Set<string>} nextHiddenEdgeIds
   */
  function setHidden(nextHiddenNodeIds, nextHiddenEdgeIds) {
    hiddenNodeIds = nextHiddenNodeIds;
    hiddenEdgeIds = nextHiddenEdgeIds;
    applyVisibilityState();
  }

  /**
   * @param {boolean} value
   */
  function setArcs(value) {
    arcs = value;
    ticked();
  }

  /**
   * @param {string | null} nodeId
   */
  function focusNode(nodeId) {
    clearPendingHover();
    hoveredNodeId = null;
    selectedNodeId = nodeId;
    const selectedNode = nodeId ? previousNodesById.get(nodeId) ?? null : null;
    onNodeSelect(selectedNode);
    applyFocusState();
  }

  function ticked() {
    linkSelection.attr("d", (edge) => linkPath(edge, arcs, showArrowheads));
    nodeSelection.attr("transform", (node) => `translate(${node.x ?? 0},${node.y ?? 0})`);
    drawBackgroundEdges();
  }

  function applyVisibilityState() {
    nodeSelection
      .classed("hidden", (node) => hiddenNodeIds.has(node.id))
      .classed("is-fixed", (node) => node.fx != null && node.fy != null);
    refreshEdgeLayers();
  }

  function applyFixedState() {
    nodeSelection.classed("is-fixed", (node) => node.fx != null && node.fy != null);
  }

  /**
   * @param {boolean} [force]
   */
  function applyFocusState(force = false) {
    const focusId = selectedNodeId ?? hoveredNodeId;
    const focusKey = focusId ?? "";
    if (!force && focusKey === lastFocusKey) {
      return;
    }
    lastFocusKey = focusKey;

    const neighborhood = focusId ? neighborhoodsByNodeId.get(focusId) : null;
    const neighboringNodeIds = neighborhood?.nodeIds ?? EMPTY_IDS;
    const neighboringEdgeIds = neighborhood?.edgeIds ?? EMPTY_IDS;
    const suppressBackgroundLinks = focusId != null && edges.length > AUTO_ARROW_EDGE_THRESHOLD;

    nodeSelection
      .classed("is-selected", (node) => node.id === selectedNodeId)
      .classed("is-muted", (node) => focusId != null && !neighboringNodeIds.has(node.id));
    refreshEdgeLayers(focusId, neighboringEdgeIds, suppressBackgroundLinks);
    linkSelection.classed("is-muted", (edge) => focusId != null && !suppressBackgroundLinks && !neighboringEdgeIds.has(edge.id));
  }

  /**
   * @param {string | null} [focusId]
   * @param {Set<string>} [neighboringEdgeIds]
   * @param {boolean} [suppressBackgroundLinks]
   */
  function refreshEdgeLayers(
    focusId = selectedNodeId ?? hoveredNodeId,
    neighboringEdgeIds = (focusId ? neighborhoodsByNodeId.get(focusId)?.edgeIds : null) ?? EMPTY_IDS,
    suppressBackgroundLinks = focusId != null && edges.length > AUTO_ARROW_EDGE_THRESHOLD,
  ) {
    const visibleEdges = edges.filter((edge) => !hiddenEdgeIds.has(edge.id));
    if (focusId && suppressBackgroundLinks) {
      foregroundEdges = visibleEdges.filter((edge) => neighboringEdgeIds.has(edge.id));
      backgroundEdges = [];
    } else if (edges.length > AUTO_ARROW_EDGE_THRESHOLD) {
      foregroundEdges = [];
      backgroundEdges = visibleEdges;
    } else {
      foregroundEdges = visibleEdges;
      backgroundEdges = [];
    }

    showArrowheads = foregroundEdges.length > 0 && foregroundEdges.length <= AUTO_ARROW_EDGE_THRESHOLD;
    updateForegroundEdgeSelection();
    drawBackgroundEdges();
  }

  function updateForegroundEdgeSelection() {
    linkSelection = linkLayer
      .selectAll(".graph-link")
      .data(foregroundEdges, (edge) => /** @type {RenderEdge} */ (edge).id);
    linkSelection.exit().remove();
    linkSelection = linkSelection
      .enter()
      .append("path")
      .attr("class", "graph-link")
      .merge(linkSelection)
      .attr("marker-end", (edge) => (edgeHasArrow(edge, showArrowheads) ? "url(#arrowhead)" : null))
      .classed("ej", (edge) => edge.type === "EJ")
      .style("stroke", (edge) => colorForType(edge.source?.type ?? ""))
      .style("stroke-width", (edge) => edgeWeightScale(edge.weight))
      .on("mouseenter", (event, edge) => {
        if (!onEdgeHover) {
          return;
        }
        tooltip
          .text(`${edge.type} ${edge.weight}`)
          .classed("hidden", false)
          .style("left", `${event.clientX + 12}px`)
          .style("top", `${event.clientY + 12}px`);
        onEdgeHover(edge);
      })
      .on("mousemove", (event) => {
        tooltip.style("left", `${event.clientX + 12}px`).style("top", `${event.clientY + 12}px`);
      })
      .on("mouseleave", () => {
        tooltip.classed("hidden", true);
        onEdgeHover?.(null);
      });
    linkSelection.attr("d", (edge) => linkPath(edge, arcs, showArrowheads));
  }

  function drawBackgroundEdges() {
    backgroundContext.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
    backgroundContext.clearRect(0, 0, width, height);

    if (backgroundEdges.length === 0) {
      return;
    }

    backgroundContext.save();
    backgroundContext.translate(currentTransform.x, currentTransform.y);
    backgroundContext.scale(currentTransform.k, currentTransform.k);

    for (const edge of backgroundEdges) {
      const source = edge.source;
      const target = edge.target;
      if (!source || !target) {
        continue;
      }

      const sourceX = source.x ?? 0;
      const sourceY = source.y ?? 0;
      const targetX = target.x ?? 0;
      const targetY = target.y ?? 0;

      backgroundContext.beginPath();
      backgroundContext.strokeStyle = colorForType(source.type);
      backgroundContext.lineWidth = edgeWeightScale(edge.weight);
      backgroundContext.setLineDash(edge.type === "EJ" ? [3, 3] : []);

      if (arcs && edge.type !== "EJ") {
        const { mx, my } = curveControlPoint(sourceX, sourceY, targetX, targetY, edge.type);
        backgroundContext.moveTo(sourceX, sourceY);
        backgroundContext.quadraticCurveTo(mx, my, targetX, targetY);
      } else {
        backgroundContext.moveTo(sourceX, sourceY);
        backgroundContext.lineTo(targetX, targetY);
      }

      backgroundContext.stroke();
    }

    backgroundContext.restore();
  }

  /**
   * @param {d3.D3DragEvent<SVGGElement, RenderNode, RenderNode>} event
   * @param {RenderNode} node
   */
  function dragStarted(event, node) {
    event.sourceEvent.stopPropagation();
    clearPendingHover();
    didDrag = false;
    if (!event.active) {
      simulation.alphaTarget(0.3).restart();
    }
  }

  /**
   * @param {d3.D3DragEvent<SVGGElement, RenderNode, RenderNode>} event
   * @param {RenderNode} node
   */
  function dragged(event, node) {
    event.sourceEvent.stopPropagation();
    if (!didDrag) {
      node.fx = node.x ?? 0;
      node.fy = node.y ?? 0;
      didDrag = true;
    }
    node.fx = event.x;
    node.fy = event.y;
  }

  /**
   * @param {d3.D3DragEvent<SVGGElement, RenderNode, RenderNode>} event
   */
  function dragEnded(event) {
    event.sourceEvent.stopPropagation();
    if (!event.active) {
      simulation.alphaTarget(0);
    }
    didDrag = false;
    applyFixedState();
  }

  return {
    setGraph,
    setHidden,
    setArcs,
    focusNode,
    getCanvasElement: () => canvas,
    getSvgElement: () => /** @type {SVGSVGElement} */ (svg.node()),
    destroy() {
      clearPendingHover();
      window.removeEventListener("resize", resize);
      tooltip.remove();
      simulation.stop();
      canvas.remove();
      svg.remove();
    },
  };
}

const EMPTY_IDS = new Set();

/**
 * @param {RenderNode[]} nodes
 * @param {RenderEdge[]} edges
 */
function buildNeighborhoods(nodes, edges) {
  /** @type {Map<string, { nodeIds: Set<string>; edgeIds: Set<string> }>} */
  const neighborhoods = new Map(
    nodes.map((node) => [node.id, { nodeIds: new Set([node.id]), edgeIds: new Set() }]),
  );

  for (const edge of edges) {
    const sourceNeighborhood = neighborhoods.get(edge.sourceId);
    const targetNeighborhood = neighborhoods.get(edge.targetId);
    if (sourceNeighborhood) {
      sourceNeighborhood.nodeIds.add(edge.targetId);
      sourceNeighborhood.edgeIds.add(edge.id);
    }
    if (targetNeighborhood) {
      targetNeighborhood.nodeIds.add(edge.sourceId);
      targetNeighborhood.edgeIds.add(edge.id);
    }
  }

  return neighborhoods;
}

/**
 * @param {RenderNode} node
 * @param {number} width
 * @param {number} height
 */
function seedPosition(node, width, height) {
  if (node.kind === "muscle") {
    node.x = ((node.pos ?? 0.5) * width * 0.7) + width * 0.15;
    node.y = height * 0.88;
    return;
  }

  const px = node.kx ?? Math.random();
  const py = node.ky ?? Math.random();
  node.x = width * 0.15 + px * width * 7;
  node.y = height * 0.15 + (py + 0.05) * height * 15;

  if (node.name.endsWith("L")) {
    node.x = Math.min(node.x, width * 0.42);
  } else if (node.name.endsWith("R")) {
    node.x = Math.max(node.x, width * 0.58);
  }
}

/**
 * @param {RenderNode} node
 * @param {number} width
 */
function targetX(node, width) {
  if (node.kind === "muscle") {
    return ((node.pos ?? 0.5) * width * 0.7) + width * 0.15;
  }
  if (node.name.endsWith("L")) {
    return width * 0.28;
  }
  if (node.name.endsWith("R")) {
    return width * 0.72;
  }
  return width * 0.5;
}

/**
 * @param {RenderNode} node
 * @param {number} height
 */
function targetY(node, height) {
  if (node.kind === "muscle") {
    return height * 0.88;
  }
  if (node.type.includes("sensory")) {
    return height * 0.18;
  }
  if (node.type.includes("motor")) {
    return height * 0.7;
  }
  return height * 0.45;
}

/**
 * @param {RenderEdge} edge
 * @param {boolean} arcs
 * @param {boolean} showArrowheads
 */
function linkPath(edge, arcs, showArrowheads) {
  const source = edge.source;
  const target = edge.target;
  if (!source || !target) {
    return "";
  }
  const sourceX = source.x ?? 0;
  const sourceY = source.y ?? 0;
  const targetPoint = edgeHasArrow(edge, showArrowheads)
    ? trimTargetPoint(source, target, (target.radius ?? 0) + ARROW_TARGET_PADDING)
    : { x: target.x ?? 0, y: target.y ?? 0 };

  if (!arcs || edge.type === "EJ") {
    return `M${sourceX},${sourceY}L${targetPoint.x},${targetPoint.y}`;
  }
  const { mx, my } = curveControlPoint(sourceX, sourceY, targetPoint.x, targetPoint.y, edge.type);
  return `M${sourceX},${sourceY}Q${mx},${my} ${targetPoint.x},${targetPoint.y}`;
}

/**
 * @param {RenderEdge} edge
 * @param {boolean} showArrowheads
 */
function edgeHasArrow(edge, showArrowheads) {
  return showArrowheads && edge.type !== "EJ";
}

/**
 * @param {RenderNode} source
 * @param {RenderNode} target
 * @param {number} padding
 */
function trimTargetPoint(source, target, padding) {
  const sourceX = source.x ?? 0;
  const sourceY = source.y ?? 0;
  const targetX = target.x ?? 0;
  const targetY = target.y ?? 0;
  const dx = targetX - sourceX;
  const dy = targetY - sourceY;
  const distance = Math.hypot(dx, dy) || 1;
  if (distance <= padding) {
    return { x: targetX, y: targetY };
  }
  return {
    x: targetX - (dx / distance) * padding,
    y: targetY - (dy / distance) * padding,
  };
}

/**
 * @param {number} sourceX
 * @param {number} sourceY
 * @param {number} targetX
 * @param {number} targetY
 * @param {string} edgeType
 */
function curveControlPoint(sourceX, sourceY, targetX, targetY, edgeType) {
  const dx = targetX - sourceX;
  const dy = targetY - sourceY;
  const distance = Math.hypot(dx, dy) || 1;
  const offset = edgeType === "S" ? 20 : -20;
  return {
    mx: (sourceX + targetX) / 2 + (-dy / distance) * offset,
    my: (sourceY + targetY) / 2 + (dx / distance) * offset,
  };
}
