// @ts-check

/**
 * @typedef {{ id: string; name: string; type: string; group?: string; kind: string; inD: number; outD: number; D: number; part?: string }} ExportNode
 * @typedef {{ id: string; sourceId: string; targetId: string; type: string; weight: number }} ExportEdge
 * @typedef {{ nodes: ExportNode[]; edges: ExportEdge[] }} ExportGraph
 */

/**
 * @param {string} value
 */
function escapeXml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

/**
 * @param {ExportNode[]} nodes
 * @param {ExportEdge[]} edges
 */
export function serializeNodeLink(nodes, edges) {
  return JSON.stringify(
    {
      nodes,
      links: edges.map((edge) => ({
        source: edge.sourceId,
        target: edge.targetId,
        type: edge.type,
        weight: edge.weight,
        id: edge.id,
      })),
    },
    null,
    2,
  );
}

/**
 * @param {ExportNode[]} nodes
 * @param {ExportEdge[]} edges
 */
export function serializeAdjacency(nodes, edges) {
  const adjacency = Object.fromEntries(nodes.map((node) => [node.id, []]));
  for (const edge of edges) {
    adjacency[edge.sourceId].push({
      target: edge.targetId,
      type: edge.type,
      weight: edge.weight,
      id: edge.id,
    });
  }
  return JSON.stringify(adjacency, null, 2);
}

/**
 * @param {ExportNode[]} nodes
 * @param {ExportEdge[]} edges
 */
export function serializeGraphML(nodes, edges) {
  const lines = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<graphml xmlns="http://graphml.graphdrawing.org/xmlns">',
    '  <key id="node_name" for="node" attr.name="name" attr.type="string" />',
    '  <key id="node_type" for="node" attr.name="type" attr.type="string" />',
    '  <key id="node_group" for="node" attr.name="group" attr.type="string" />',
    '  <key id="edge_type" for="edge" attr.name="type" attr.type="string" />',
    '  <key id="edge_weight" for="edge" attr.name="weight" attr.type="double" />',
    '  <graph edgedefault="directed">',
  ];

  for (const node of nodes) {
    lines.push(
      `    <node id="${escapeXml(node.id)}">`,
      `      <data key="node_name">${escapeXml(node.name)}</data>`,
      `      <data key="node_type">${escapeXml(node.type)}</data>`,
      `      <data key="node_group">${escapeXml(node.group ?? "")}</data>`,
      "    </node>",
    );
  }

  for (const edge of edges) {
    lines.push(
      `    <edge id="${escapeXml(edge.id)}" source="${escapeXml(edge.sourceId)}" target="${escapeXml(edge.targetId)}">`,
      `      <data key="edge_type">${escapeXml(edge.type)}</data>`,
      `      <data key="edge_weight">${edge.weight}</data>`,
      "    </edge>",
    );
  }

  lines.push("  </graph>", "</graphml>");
  return lines.join("\n");
}

/**
 * @param {ExportNode[]} nodes
 * @param {ExportEdge[]} edges
 */
export function serializeGml(nodes, edges) {
  const lines = ["graph [", "  directed 1"];
  for (const node of nodes) {
    lines.push(
      "  node [",
      `    id "${node.id}"`,
      `    label "${node.name}"`,
      `    type "${node.type}"`,
      `    group "${node.group ?? ""}"`,
      "  ]",
    );
  }

  for (const edge of edges) {
    lines.push(
      "  edge [",
      `    source "${edge.sourceId}"`,
      `    target "${edge.targetId}"`,
      `    id "${edge.id}"`,
      `    type "${edge.type}"`,
      `    weight ${edge.weight}`,
      "  ]",
    );
  }

  lines.push("]");
  return lines.join("\n");
}

/**
 * @param {ExportNode[]} nodes
 * @param {ExportEdge[]} edges
 */
export function serializeAdjList(nodes, edges) {
  const adjacency = new Map(nodes.map((node) => [node.id, []]));
  for (const edge of edges) {
    adjacency.get(edge.sourceId)?.push(edge.targetId);
  }
  return [...adjacency.entries()]
    .map(([nodeId, targets]) => `${nodeId}${targets.length ? ` ${targets.join(" ")}` : ""}`)
    .join("\n");
}

/**
 * @param {string} filename
 * @param {string} text
 * @param {string} mimeType
 */
export function downloadText(filename, text, mimeType) {
  const blob = new Blob([text], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

/**
 * @param {SVGSVGElement} svg
 * @param {string} filename
 * @param {HTMLCanvasElement | null} [backgroundCanvas]
 */
export async function downloadSvgPng(svg, filename, backgroundCanvas = null) {
  const xml = new XMLSerializer().serializeToString(svg);
  const blob = new Blob([xml], { type: "image/svg+xml;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const image = new Image();
  image.decoding = "async";

  await new Promise((resolve, reject) => {
    image.onload = resolve;
    image.onerror = reject;
    image.src = url;
  });

  const width = svg.viewBox.baseVal.width || svg.clientWidth || 1600;
  const height = svg.viewBox.baseVal.height || svg.clientHeight || 900;
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext("2d");
  if (!context) {
    URL.revokeObjectURL(url);
    throw new Error("Canvas export is unavailable in this browser.");
  }
  context.fillStyle = "#ffffff";
  context.fillRect(0, 0, width, height);
  if (backgroundCanvas) {
    context.drawImage(backgroundCanvas, 0, 0, width, height);
  }
  context.drawImage(image, 0, 0, width, height);
  URL.revokeObjectURL(url);

  const pngUrl = canvas.toDataURL("image/png");
  const link = document.createElement("a");
  link.href = pngUrl;
  link.download = filename;
  link.click();
}
