// @ts-check

import fs from "node:fs/promises";
import path from "node:path";
import xlsx from "xlsx";

/**
 * @typedef {{ name: string; g1: string; g2: string; smin: number; jmin: number; length: number }} Preset
 * @typedef {{ kx: number; ky: number }} Position
 * @typedef {{ group: string; type: string }} WormWebEntry
 * @typedef {{ organ: string; modalities: string; functions: string }} SensorEntry
 * @typedef {{ source: string; target: string; type: string; weight: number }} RawNeuronEdge
 * @typedef {Record<string, string | number>} WorkbookRow
 * @typedef {{
 *   id: string;
 *   kind: "neuron";
 *   name: string;
 *   group: string;
 *   type: string;
 *   SomaPosition: number;
 *   SomaRegion: string;
 *   AYGanglionDesignation: string;
 *   AYNbr: number;
 *   kx: number | null;
 *   ky: number | null;
 *   organ: string;
 *   modalities: string;
 *   functions: string;
 *   inD: number;
 *   outD: number;
 *   D: number;
 * }} BuilderNeuronNode
 * @typedef {{
 *   id: string;
 *   kind: "muscle";
 *   name: string;
 *   type: "muscle";
 *   group: "";
 *   part: string;
 *   pos: number;
 *   kx: null;
 *   ky: null;
 *   inD: number;
 *   outD: number;
 *   D: number;
 * }} BuilderMuscleNode
 * @typedef {BuilderNeuronNode | BuilderMuscleNode} BuilderNode
 * @typedef {{
 *   id: string;
 *   sourceId: string;
 *   targetId: string;
 *   type: string;
 *   weight: number;
 *   scope: "neuron" | "muscle";
 *   initialVisible: boolean;
 *   part?: string;
 * }} BuilderEdge
 * @typedef {{
 *   neuronCount: number;
 *   muscleCount: number;
 *   neuronEdgeCount: number;
 *   muscleEdgeCount: number;
 *   initialVisibleNodeCount: number;
 *   initialVisibleEdgeCount: number;
 * }} BuildSummary
 * @typedef {{
 *   nodes: BuilderNode[];
 *   edges: BuilderEdge[];
 *   groups: string[];
 *   receptors: string[];
 *   presets: Preset[];
 *   summary: BuildSummary;
 * }} BuildConnectomeResult
 */

/** @type {Preset[]} */
const PRESETS = [
  { name: "Salt klinotaxis S", g1: "ASE", g2: "SMB", smin: 2, jmin: 2, length: 3 },
  { name: "Salt klinotaxis L", g1: "ASE", g2: "SMB", smin: 1, jmin: 1, length: 3 },
  {
    name: "Isothermal tracking",
    g1: "AFD,AWC",
    g2: "VB, DB, RMD, RIM, SMD, VA, DA, DD",
    smin: 1,
    jmin: 1,
    length: 2,
  },
  {
    name: "Backward escape",
    g1: "ASH",
    g2: "VB, DB, RMD, RIM, SMD, VA, DA, DD",
    smin: 1,
    jmin: 1,
    length: 2,
  },
];

const LINE_SPLIT_RE = /\r\n?|\n/;

/**
 * @param {string} value
 * @returns {string}
 */
function removeLeadingZero(value) {
  if (!value || value.length < 2) {
    return value;
  }
  const end = value.at(-1);
  const prev = value.at(-2);
  if (end && /\d/.test(end) && prev === "0") {
    return `${value.slice(0, -2)}${end}`;
  }
  return value;
}

/**
 * @param {string} value
 * @returns {string}
 */
function symmetricNodeName(value) {
  if (value.endsWith("L")) {
    return `${value.slice(0, -1)}R`;
  }
  if (value.endsWith("R")) {
    return `${value.slice(0, -1)}L`;
  }
  return value;
}

/**
 * @param {string} rawType
 * @returns {string}
 */
function expandType(rawType) {
  const parts = [];
  const value = rawType || "";
  if (value.includes("se")) {
    parts.push("sensory");
  }
  if (value.includes("mo")) {
    parts.push("motor");
  }
  if (value.includes("in")) {
    parts.push("inter");
  }
  if (value.includes("mu")) {
    parts.push("muscle");
  }
  if (value.includes("bm")) {
    parts.push("basement membrane");
  }
  if (value.includes("gln")) {
    parts.push("gland cell");
  }
  if (value.includes("mc")) {
    parts.push("marginal cell");
  }
  return parts.join(", ");
}

/**
 * @param {string} name
 * @returns {string}
 */
function muscleToBodyPart(name) {
  const match = name.match(/(\d{1,2})$/);
  if (!match) {
    return "body";
  }
  const number = Number(match[1]);
  if (number <= 4) {
    return "head";
  }
  if (number <= 8) {
    return "neck";
  }
  return "body";
}

/**
 * @param {string} value
 * @returns {string[]}
 */
function parseTokens(value) {
  return value
    .split(",")
    .map((token) => token.trim())
    .filter(Boolean);
}

/**
 * @param {string} source
 * @param {string} delimiter
 * @returns {Record<string, string>[]}
 */
function parseDelimited(source, delimiter) {
  const normalized = source.trim();
  if (!normalized) {
    return [];
  }
  const [headerLine, ...lines] = normalized.split(LINE_SPLIT_RE).map((line) => line.trimEnd());
  const headers = headerLine.split(delimiter).map((header) => header.trim());
  return lines.filter((line) => line.trim()).map((line) => {
    const values = line.split(delimiter);
    return Object.fromEntries(headers.map((header, index) => [header, values[index]?.trim() ?? ""]));
  });
}

/**
 * @param {string} source
 * @returns {Record<string, string>[]}
 */
function parseWhitespaceTriples(source) {
  return source
    .split(LINE_SPLIT_RE)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"))
    .map((line) => {
      const [name, group, type] = line.split(/\s+/);
      return { name, group, type };
    });
}

/**
 * @param {string} value
 * @returns {number}
 */
function toNumber(value) {
  return Number.parseFloat(value);
}

/**
 * @param {string} rootDir
 * @returns {Promise<BuildConnectomeResult>}
 */
export async function buildConnectome(rootDir) {
  const read = (relativePath) => fs.readFile(path.join(rootDir, relativePath), "utf8");
  const readWorkbook = (relativePath) => xlsx.readFile(path.join(rootDir, relativePath), { raw: true });

  const positionLabels = (await read("data/DynamicConnectome/celegans277/celegans277labels.csv"))
    .split(LINE_SPLIT_RE)
    .map((line) => line.trim())
    .filter(Boolean);
  const positionRows = (await read("data/DynamicConnectome/celegans277/celegans277positions.csv"))
    .split(LINE_SPLIT_RE)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => line.split(",").map((value) => Number.parseFloat(value)));

  /** @type {Map<string, Position>} */
  const positionsByName = new Map();
  for (let index = 0; index < positionLabels.length; index += 1) {
    const [kx, ky] = positionRows[index];
    positionsByName.set(positionLabels[index], { kx, ky });
  }

  const neuronWorkbook = readWorkbook("data/ChenVarshney/NeuronType.xls");
  /** @type {WorkbookRow[]} */
  const neuronRows = xlsx.utils.sheet_to_json(neuronWorkbook.Sheets[neuronWorkbook.SheetNames[0]], {
    defval: "",
  });

  const wormWebRows = parseWhitespaceTriples(await read("data/WormWeb/name_neurons.txt"));
  /** @type {Map<string, WormWebEntry>} */
  const wormWebByName = new Map(
    wormWebRows.map((row) => [row.name, { group: row.group, type: expandType(row.type) }]),
  );

  const sensorRows = parseDelimited(await read("data/Self/Sensors.tsv"), "\t");
  /** @type {Map<string, SensorEntry>} */
  const sensorsByGroup = new Map(
    sensorRows.map((row) => [
      row.group,
      {
        organ: row.organ ?? "",
        modalities: row.modality ?? "",
        functions: row.functions ?? "",
      },
    ]),
  );

  /** @type {Map<string, BuilderNeuronNode>} */
  const nodesById = new Map();
  /** @type {Map<string, number>} */
  const neuronOrder = new Map();
  /** @type {string[]} */
  const groups = [];
  const groupSet = new Set();
  const receptorSet = new Set();

  neuronRows.forEach((row, index) => {
    const name = removeLeadingZero(String(row.Neuron));
    const position = positionsByName.get(name) ?? positionsByName.get(symmetricNodeName(name));
    const wormWeb = wormWebByName.get(name);
    const sensor = wormWeb ? sensorsByGroup.get(wormWeb.group) : undefined;
    /** @type {BuilderNeuronNode} */
    const node = {
      id: `neuron/${name}`,
      kind: "neuron",
      name,
      group: wormWeb?.group ?? "",
      type: wormWeb?.type ?? "",
      SomaPosition: Number(row["Soma Position"]),
      SomaRegion: String(row["Soma Region"] ?? ""),
      AYGanglionDesignation: String(row[" AY Ganglion Designation"] ?? "").trim(),
      AYNbr: Number(row[" AYNbr "] ?? 0),
      kx: position?.kx ?? null,
      ky: position?.ky ?? null,
      organ: sensor?.organ ?? "",
      modalities: sensor?.modalities ?? "",
      functions: sensor?.functions ?? "",
      inD: 0,
      outD: 0,
      D: 0,
    };
    nodesById.set(node.id, node);
    neuronOrder.set(name, index);

    if (node.group && !groupSet.has(node.group)) {
      groupSet.add(node.group);
      groups.push(node.group);
    }

    for (const token of parseTokens(node.modalities)) {
      receptorSet.add(token);
    }
  });

  const muscleWorkbook = readWorkbook("data/ChenVarshney/NeuronFixedPoints.xls");
  /** @type {WorkbookRow[]} */
  const muscleRows = xlsx.utils.sheet_to_json(muscleWorkbook.Sheets[muscleWorkbook.SheetNames[0]], {
    defval: "",
  });

  /** @type {Map<string, BuilderMuscleNode>} */
  const musclesById = new Map();
  /** @type {BuilderEdge[]} */
  const muscleEdges = [];
  for (const row of muscleRows) {
    const landmark = removeLeadingZero(String(row.Landmark));
    if (!landmark.startsWith("M")) {
      continue;
    }
    const neuronName = removeLeadingZero(String(row.Neuron));
    const nodeId = `muscle/${landmark}`;
    if (!musclesById.has(nodeId)) {
      musclesById.set(nodeId, {
        id: nodeId,
        kind: "muscle",
        name: landmark,
        type: "muscle",
        group: "",
        part: muscleToBodyPart(landmark),
        pos: Number(row["Landmark Position"] ?? 0),
        kx: null,
        ky: null,
        inD: 0,
        outD: 0,
        D: 0,
      });
    }

    const sourceId = `neuron/${neuronName}`;
    if (!nodesById.has(sourceId)) {
      continue;
    }
    const muscle = musclesById.get(nodeId);
    if (!muscle) {
      continue;
    }
    /** @type {BuilderEdge} */
    const edge = {
      id: `edge/nmj/${sourceId}->${nodeId}/${muscleEdges.length}`,
      sourceId,
      targetId: nodeId,
      type: "NMJ",
      weight: Number(row.Weight ?? 0),
      scope: "muscle",
      initialVisible: false,
      part: muscle.part,
    };
    muscleEdges.push(edge);
    muscle.inD += 1;
    muscle.D = muscle.inD;
  }

  /** @type {RawNeuronEdge[]} */
  const neuronEdgeRows = parseDelimited(await read("data/ChenVarshney/NeuronConnect.csv"), ";")
    .map((row) => ({
      source: removeLeadingZero(row["Neuron 1"]),
      target: removeLeadingZero(row["Neuron 2"]),
      type: row.Type,
      weight: toNumber(row.Nbr),
    }))
    .filter((row) => !["R", "Rp", "NMJ"].includes(row.type));

  for (const edge of neuronEdgeRows) {
    const sourceNode = nodesById.get(`neuron/${edge.source}`);
    const targetNode = nodesById.get(`neuron/${edge.target}`);
    if (!sourceNode || !targetNode) {
      continue;
    }
    sourceNode.outD += 1;
    targetNode.inD += 1;
  }

  for (const node of nodesById.values()) {
    node.D = node.inD + node.outD;
  }

  /** @type {Map<string, RawNeuronEdge>} */
  const dedupedEJ = new Map();
  /** @type {RawNeuronEdge[]} */
  const chemicalEdges = [];
  for (const edge of neuronEdgeRows) {
    if (edge.type !== "EJ") {
      chemicalEdges.push(edge);
      continue;
    }

    const sourceOrder = neuronOrder.get(edge.source) ?? Number.POSITIVE_INFINITY;
    const targetOrder = neuronOrder.get(edge.target) ?? Number.POSITIVE_INFINITY;
    const canonicalSource = sourceOrder <= targetOrder ? edge.source : edge.target;
    const canonicalTarget = sourceOrder <= targetOrder ? edge.target : edge.source;
    const key = `${canonicalSource}|${canonicalTarget}|EJ`;
    if (!dedupedEJ.has(key)) {
      if (canonicalSource === edge.source && canonicalTarget === edge.target) {
        dedupedEJ.set(key, edge);
      } else {
        dedupedEJ.set(key, {
          source: canonicalSource,
          target: canonicalTarget,
          type: "EJ",
          weight: edge.weight,
        });
      }
    }
  }

  /** @type {BuilderEdge[]} */
  const neuronEdges = [...chemicalEdges, ...dedupedEJ.values()].map((edge, index) => ({
    id: `edge/neuron/${edge.source}->${edge.target}/${edge.type}/${index}`,
    sourceId: `neuron/${edge.source}`,
    targetId: `neuron/${edge.target}`,
    type: edge.type,
    weight: edge.weight,
    scope: "neuron",
    initialVisible: true,
  }));

  /** @type {BuilderNode[]} */
  const nodes = [...nodesById.values(), ...musclesById.values()];
  /** @type {BuilderEdge[]} */
  const edges = [...neuronEdges, ...muscleEdges];

  return {
    nodes,
    edges,
    groups: groups.sort(),
    receptors: [...receptorSet].sort(),
    presets: PRESETS,
    summary: {
      neuronCount: [...nodesById.values()].length,
      muscleCount: [...musclesById.values()].length,
      neuronEdgeCount: neuronEdges.length,
      muscleEdgeCount: muscleEdges.length,
      initialVisibleNodeCount: [...nodesById.values()].length,
      initialVisibleEdgeCount: neuronEdges.length,
    },
  };
}
