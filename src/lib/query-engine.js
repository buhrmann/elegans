// @ts-check

/**
 * @typedef {{
 *   id: string;
 *   kind: string;
 *   name: string;
 *   group?: string;
 *   type: string;
 *   modalities?: string;
 *   functions?: string;
 *   inD: number;
 *   outD: number;
 *   D: number;
 *   part?: string;
 *   kx?: number | null;
 *   ky?: number | null;
 *   pos?: number;
 * }} ConnectomeNode
 */

/**
 * @typedef {{
 *   id: string;
 *   sourceId: string;
 *   targetId: string;
 *   type: string;
 *   weight: number;
 *   scope: string;
 *   initialVisible: boolean;
 *   part?: string;
 * }} ConnectomeEdge
 */

/**
 * @typedef {{
 *   nodes: ConnectomeNode[];
 *   edges: ConnectomeEdge[];
 * }} GraphView
 */

/**
 * @typedef {{ name: string; g1: string; g2: string; smin: number; jmin: number; length: number }} ConnectomePreset
 */

/**
 * @typedef {{
 *   nodes: ConnectomeNode[];
 *   edges: ConnectomeEdge[];
 *   groups: string[];
 *   receptors: string[];
 *   presets: ConnectomePreset[];
 *   summary: Record<string, number>;
 * }} ConnectomeData
 */

/**
 * @typedef {{
 *   nodeDegree: number;
 *   minWeightS: number;
 *   minWeightJ: number;
 *   showSynapses: boolean;
 *   showJunctions: boolean;
 *   mode: "prune" | "hide";
 * }} VisibilityFilters
 */

/**
 * @typedef {{
 *   neurons: number;
 *   muscles: number;
 *   synapses: number;
 *   junctions: number;
 *   nmj: number;
 * }} GraphStats
 */

/**
 * @typedef {{
 *   renderGraph: GraphView;
 *   filteredGraph: GraphView;
 *   hiddenNodeIds: Set<string>;
 *   hiddenEdgeIds: Set<string>;
 *   searchNames: string[];
 *   stats: GraphStats;
 *   nodeIds: Set<string>;
 * }} VisibilityResult
 */

/**
 * @typedef {{
 *   data: ConnectomeData;
 *   nodesById: Map<string, ConnectomeNode>;
 *   nodesByName: Map<string, ConnectomeNode>;
 *   edgesById: Map<string, ConnectomeEdge>;
 *   groupsToNodeIds: Map<string, string[]>;
 *   modalityToNodeIds: Map<string, string[]>;
 *   incidentEdgesByNodeId: Map<string, ConnectomeEdge[]>;
 *   neuronNodes: ConnectomeNode[];
 *   neuronEdges: ConnectomeEdge[];
 *   muscleEdges: ConnectomeEdge[];
 * }} ConnectomeIndex
 */

/**
 * @param {string} value
 * @returns {string[]}
 */
export function parseInputList(value) {
  return [...new Set(value.split(",").map((token) => token.trim()).filter(Boolean))];
}

/**
 * @param {ConnectomeData} data
 * @returns {ConnectomeIndex}
 */
export function createIndex(data) {
  /** @type {Map<string, ConnectomeNode>} */
  const nodesById = new Map(data.nodes.map((node) => [node.id, node]));
  /** @type {Map<string, ConnectomeNode>} */
  const nodesByName = new Map(data.nodes.map((node) => [node.name, node]));
  /** @type {Map<string, ConnectomeEdge>} */
  const edgesById = new Map(data.edges.map((edge) => [edge.id, edge]));
  /** @type {Map<string, string[]>} */
  const groupsToNodeIds = new Map();
  /** @type {Map<string, string[]>} */
  const modalityToNodeIds = new Map();
  /** @type {Map<string, ConnectomeEdge[]>} */
  const incidentEdgesByNodeId = new Map();

  for (const node of data.nodes) {
    if (node.group) {
      const list = groupsToNodeIds.get(node.group) ?? [];
      list.push(node.id);
      groupsToNodeIds.set(node.group, list);
    }
    if (node.modalities) {
      for (const modality of parseInputList(node.modalities)) {
        const list = modalityToNodeIds.get(modality) ?? [];
        list.push(node.id);
        modalityToNodeIds.set(modality, list);
      }
    }
  }

  for (const edge of data.edges) {
    const sourceEdges = incidentEdgesByNodeId.get(edge.sourceId) ?? [];
    sourceEdges.push(edge);
    incidentEdgesByNodeId.set(edge.sourceId, sourceEdges);

    const targetEdges = incidentEdgesByNodeId.get(edge.targetId) ?? [];
    targetEdges.push(edge);
    incidentEdgesByNodeId.set(edge.targetId, targetEdges);
  }

  const neuronNodes = data.nodes.filter((node) => node.kind === "neuron");
  const neuronEdges = data.edges.filter((edge) => edge.scope === "neuron");
  const muscleEdges = data.edges.filter((edge) => edge.scope === "muscle");

  return {
    data,
    nodesById,
    nodesByName,
    edgesById,
    groupsToNodeIds,
    modalityToNodeIds,
    incidentEdgesByNodeId,
    neuronNodes,
    neuronEdges,
    muscleEdges,
  };
}

/**
 * @param {ReturnType<typeof createIndex>} index
 * @returns {GraphView}
 */
export function createInitialGraph(index) {
  return {
    nodes: index.neuronNodes,
    edges: index.neuronEdges.filter((edge) => edge.initialVisible),
  };
}

/**
 * @param {ReturnType<typeof createIndex>} index
 * @param {string[]} groups
 * @returns {GraphView}
 */
export function graphForGroups(index, groups) {
  const neuronIds = new Set(resolveGroupNodeIds(index, groups));
  return graphForNodeIds(index, neuronIds, []);
}

/**
 * @param {ReturnType<typeof createIndex>} index
 * @param {GraphView} graph
 * @param {string[]} muscleParts
 * @returns {GraphView}
 */
export function expandGraph(index, graph, muscleParts) {
  const neuronIds = new Set(graph.nodes.filter((node) => node.kind === "neuron").map((node) => node.id));
  return graphForNodeIds(index, neuronIds, muscleParts);
}

/**
 * @param {ReturnType<typeof createIndex>} index
 * @param {GraphView} graph
 * @param {string[]} muscleParts
 * @returns {GraphView}
 */
export function applyMuscleSelection(index, graph, muscleParts) {
  const neuronNodeIds = new Set(graph.nodes.filter((node) => node.kind === "neuron").map((node) => node.id));
  const neuronEdgeIds = new Set(graph.edges.filter((edge) => edge.scope === "neuron").map((edge) => edge.id));
  const baseGraph = graphFromIds(index, neuronNodeIds, neuronEdgeIds);
  return muscleParts.length > 0 ? addMuscles(index, baseGraph, muscleParts) : baseGraph;
}

/**
 * @param {ReturnType<typeof createIndex>} index
 * @param {{ groups1: string[]; groups2: string[]; receptors: string[]; minWeightS: number; minWeightJ: number; maxLength: number; direction: "uni" | "bi"; muscleParts: string[] }} params
 * @returns {GraphView}
 */
export function subgraph(index, params) {
  const startIds = new Set([
    ...resolveGroupNodeIds(index, params.groups1),
    ...resolveReceptorNodeIds(index, params.receptors),
  ]);
  const targetIds = new Set(resolveGroupNodeIds(index, params.groups2));
  /** @type {Set<string>} */
  const collectedNodeIds = new Set();
  /** @type {Set<string>} */
  const collectedEdgeIds = new Set();

  if (startIds.size === 0 || targetIds.size === 0) {
    return { nodes: [], edges: [] };
  }

  /**
   * @param {string} currentNodeId
   * @param {Set<string>} visited
   * @param {string[]} pathEdgeIds
   * @param {number} depth
   */
  function walk(currentNodeId, visited, pathEdgeIds, depth) {
    if (depth >= params.maxLength) {
      return;
    }

    const incident = index.incidentEdgesByNodeId.get(currentNodeId) ?? [];
    for (const edge of incident) {
      if (edge.scope !== "neuron") {
        continue;
      }
      if (edge.type === "EJ" && edge.weight < params.minWeightJ) {
        continue;
      }
      if (edge.type !== "EJ" && edge.weight < params.minWeightS) {
        continue;
      }

      const nextNodeId = nextNodeForTraversal(edge, currentNodeId, params.direction);
      if (!nextNodeId || visited.has(nextNodeId)) {
        continue;
      }

      const nextVisited = new Set(visited);
      nextVisited.add(nextNodeId);
      const nextPathEdgeIds = [...pathEdgeIds, edge.id];

      if (targetIds.has(nextNodeId)) {
        for (const nodeId of nextVisited) {
          collectedNodeIds.add(nodeId);
        }
        for (const edgeId of nextPathEdgeIds) {
          collectedEdgeIds.add(edgeId);
        }
      }

      walk(nextNodeId, nextVisited, nextPathEdgeIds, depth + 1);
    }
  }

  for (const startId of startIds) {
    walk(startId, new Set([startId]), [], 0);
  }

  if (collectedEdgeIds.size === 0) {
    return { nodes: [], edges: [] };
  }

  const graph = graphFromIds(index, collectedNodeIds, collectedEdgeIds);
  return params.muscleParts.length > 0 ? addMuscles(index, graph, params.muscleParts) : graph;
}

/**
 * @param {ConnectomeIndex} index
 * @param {GraphView} graph
 * @param {VisibilityFilters} filters
 * @returns {VisibilityResult}
 */
export function applyVisibilityFilters(index, graph, filters) {
  const thresholdNodeIds = new Set(
    graph.nodes.filter((node) => node.D >= filters.nodeDegree).map((node) => node.id),
  );

  /** @type {ConnectomeEdge[]} */
  const filteredEdges = [];
  const filteredEdgeIds = new Set();
  const connectedNodeIds = new Set();
  for (const edge of graph.edges) {
    if (!thresholdNodeIds.has(edge.sourceId) || !thresholdNodeIds.has(edge.targetId)) {
      continue;
    }
    if (edge.type === "EJ") {
      if (!filters.showJunctions || edge.weight < filters.minWeightJ) {
        continue;
      }
    } else if (!filters.showSynapses || edge.weight < filters.minWeightS) {
      continue;
    }

    filteredEdges.push(edge);
    filteredEdgeIds.add(edge.id);
    connectedNodeIds.add(edge.sourceId);
    connectedNodeIds.add(edge.targetId);
  }

  /** @type {ConnectomeNode[]} */
  const filteredNodes = [];
  const hiddenNodeIds = new Set();
  for (const node of graph.nodes) {
    if (connectedNodeIds.has(node.id)) {
      filteredNodes.push(node);
    } else {
      hiddenNodeIds.add(node.id);
    }
  }

  const hiddenEdgeIds = new Set();
  for (const edge of graph.edges) {
    if (!filteredEdgeIds.has(edge.id)) {
      hiddenEdgeIds.add(edge.id);
    }
  }

  const renderGraph =
    filters.mode === "prune"
      ? { nodes: filteredNodes, edges: filteredEdges }
      : { nodes: graph.nodes, edges: graph.edges };

  return {
    renderGraph,
    filteredGraph: { nodes: filteredNodes, edges: filteredEdges },
    hiddenNodeIds,
    hiddenEdgeIds,
    searchNames: filteredNodes.map((node) => node.name).sort(),
    stats: summarizeGraph(filteredNodes, filteredEdges),
    nodeIds: connectedNodeIds,
  };
}

/**
 * @param {ConnectomeNode[]} nodes
 * @param {ConnectomeEdge[]} edges
 * @returns {GraphStats}
 */
export function summarizeGraph(nodes, edges) {
  return {
    neurons: nodes.filter((node) => node.kind !== "muscle").length,
    muscles: nodes.filter((node) => node.kind === "muscle").length,
    synapses: edges.filter((edge) => edge.type === "S" || edge.type === "Sp").length,
    junctions: edges.filter((edge) => edge.type === "EJ").length,
    nmj: edges.filter((edge) => edge.type === "NMJ").length,
  };
}

/**
 * @param {ConnectomeIndex} index
 * @param {Set<string>} nodeIds
 * @param {string[]} muscleParts
 * @returns {GraphView}
 */
function graphForNodeIds(index, nodeIds, muscleParts) {
  /** @type {Set<string>} */
  const edgeIds = new Set();
  for (const edge of index.neuronEdges) {
    if (nodeIds.has(edge.sourceId) && nodeIds.has(edge.targetId)) {
      edgeIds.add(edge.id);
    }
  }
  const graph = graphFromIds(index, nodeIds, edgeIds);
  return muscleParts.length > 0 ? addMuscles(index, graph, muscleParts) : graph;
}

/**
 * @param {ConnectomeIndex} index
 * @param {GraphView} graph
 * @param {string[]} muscleParts
 * @returns {GraphView}
 */
function addMuscles(index, graph, muscleParts) {
  const parts = new Set(muscleParts);
  const nodeIds = new Set(graph.nodes.map((node) => node.id));
  const edgeIds = new Set(graph.edges.map((edge) => edge.id));

  for (const edge of index.muscleEdges) {
    if (!parts.has(edge.part ?? "")) {
      continue;
    }
    if (!nodeIds.has(edge.sourceId)) {
      continue;
    }
    edgeIds.add(edge.id);
    nodeIds.add(edge.targetId);
  }

  return graphFromIds(index, nodeIds, edgeIds);
}

/**
 * @param {ConnectomeIndex} index
 * @param {Set<string>} nodeIds
 * @param {Set<string>} edgeIds
 * @returns {GraphView}
 */
function graphFromIds(index, nodeIds, edgeIds) {
  const nodes = [...nodeIds].map((nodeId) => index.nodesById.get(nodeId)).filter(Boolean);
  const edges = [...edgeIds].map((edgeId) => index.edgesById.get(edgeId)).filter(Boolean);
  return { nodes, edges };
}

/**
 * @param {ConnectomeIndex} index
 * @param {string[]} groups
 * @returns {string[]}
 */
function resolveGroupNodeIds(index, groups) {
  return groups.flatMap((group) => index.groupsToNodeIds.get(group) ?? []);
}

/**
 * @param {ConnectomeIndex} index
 * @param {string[]} receptors
 * @returns {string[]}
 */
function resolveReceptorNodeIds(index, receptors) {
  return receptors.flatMap((receptor) => index.modalityToNodeIds.get(receptor) ?? []);
}

/**
 * @param {ConnectomeEdge} edge
 * @param {string} currentNodeId
 * @param {"uni" | "bi"} direction
 * @returns {string | null}
 */
function nextNodeForTraversal(edge, currentNodeId, direction) {
  if (edge.type === "EJ") {
    if (edge.sourceId === currentNodeId) {
      return edge.targetId;
    }
    if (edge.targetId === currentNodeId) {
      return edge.sourceId;
    }
    return null;
  }

  if (edge.sourceId === currentNodeId) {
    return edge.targetId;
  }
  if (direction === "bi" && edge.targetId === currentNodeId) {
    return edge.sourceId;
  }
  return null;
}
