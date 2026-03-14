// @ts-check

import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { serializeAdjList, serializeAdjacency, serializeGml, serializeGraphML, serializeNodeLink } from "../src/lib/exporters.js";
import {
  applyMuscleSelection,
  createIndex,
  expandGraph,
  graphForGroups,
  parseInputList,
  subgraph,
} from "../src/lib/query-engine.js";
import { buildConnectome } from "../scripts/lib/build-connectome.mjs";

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

test("buildConnectome produces the expected baseline counts and symmetric fallbacks", async () => {
  const connectome = await buildConnectome(rootDir);
  assert.equal(connectome.summary.neuronCount, 279);
  assert.equal(connectome.summary.muscleCount, 97);
  assert.equal(connectome.summary.neuronEdgeCount, 3092);
  assert.equal(connectome.summary.muscleEdgeCount, 563);

  const aibl = connectome.nodes.find((node) => node.name === "AIBL");
  const aibr = connectome.nodes.find((node) => node.name === "AIBR");
  assert.ok(aibl);
  assert.ok(aibr);
  assert.equal(aibl.kx, aibr.kx);
  assert.equal(aibl.ky, aibr.ky);
});

test("parseInputList removes whitespace and duplicates", () => {
  assert.deepEqual(parseInputList(" ASE, SMB,ASE , "), ["ASE", "SMB"]);
});

test("subgraph preserves directional and bidirectional traversal rules", () => {
  const data = {
    nodes: [
      { id: "neuron/A", kind: "neuron", name: "A", group: "G1", type: "sensory", inD: 0, outD: 1, D: 1 },
      { id: "neuron/B", kind: "neuron", name: "B", group: "MID", type: "inter", inD: 2, outD: 1, D: 3 },
      { id: "neuron/C", kind: "neuron", name: "C", group: "G2", type: "motor", inD: 1, outD: 0, D: 1 },
      { id: "neuron/D", kind: "neuron", name: "D", group: "G2", type: "motor", inD: 0, outD: 1, D: 1 },
      { id: "muscle/M1", kind: "muscle", name: "M1", group: "", type: "muscle", part: "head", inD: 1, outD: 0, D: 1 },
    ],
    edges: [
      {
        id: "edge-ab",
        sourceId: "neuron/A",
        targetId: "neuron/B",
        type: "S",
        weight: 2,
        scope: "neuron",
        initialVisible: true,
      },
      {
        id: "edge-bc",
        sourceId: "neuron/B",
        targetId: "neuron/C",
        type: "Sp",
        weight: 2,
        scope: "neuron",
        initialVisible: true,
      },
      {
        id: "edge-db",
        sourceId: "neuron/D",
        targetId: "neuron/B",
        type: "S",
        weight: 2,
        scope: "neuron",
        initialVisible: true,
      },
      {
        id: "edge-cm",
        sourceId: "neuron/C",
        targetId: "muscle/M1",
        type: "NMJ",
        weight: 4,
        scope: "muscle",
        part: "head",
        initialVisible: false,
      },
    ],
    groups: ["G1", "G2", "MID"],
    receptors: [],
    presets: [],
    summary: {},
  };
  const index = createIndex(data);

  const directed = subgraph(index, {
    groups1: ["G1"],
    groups2: ["G2"],
    receptors: [],
    minWeightS: 1,
    minWeightJ: 1,
    maxLength: 3,
    direction: "uni",
    muscleParts: [],
  });
  assert.deepEqual(
    directed.nodes.map((node) => node.name).sort(),
    ["A", "B", "C"],
  );

  const bidirectional = subgraph(index, {
    groups1: ["G1"],
    groups2: ["G2"],
    receptors: [],
    minWeightS: 1,
    minWeightJ: 1,
    maxLength: 3,
    direction: "bi",
    muscleParts: [],
  });
  assert.deepEqual(
    bidirectional.nodes.map((node) => node.name).sort(),
    ["A", "B", "C", "D"],
  );

  const expanded = expandGraph(index, directed, ["head"]);
  assert.deepEqual(
    expanded.nodes.map((node) => node.name).sort(),
    ["A", "B", "C", "M1"],
  );
  assert.ok(expanded.edges.some((edge) => edge.type === "NMJ"));

  const withMuscles = applyMuscleSelection(index, directed, ["head"]);
  assert.deepEqual(
    withMuscles.nodes.map((node) => node.name).sort(),
    ["A", "B", "C", "M1"],
  );
  const withoutMuscles = applyMuscleSelection(index, withMuscles, []);
  assert.deepEqual(
    withoutMuscles.nodes.map((node) => node.name).sort(),
    ["A", "B", "C"],
  );
  assert.equal(withoutMuscles.edges.some((edge) => edge.type === "NMJ"), false);

  const groupGraph = graphForGroups(index, ["G1", "MID", "G2"]);
  assert.equal(groupGraph.edges.length, 3);
});

test("export serializers emit the expected wire formats", () => {
  const nodes = [
    { id: "neuron/A", name: "A", type: "sensory", group: "G1", kind: "neuron", inD: 0, outD: 1, D: 1 },
    { id: "neuron/B", name: "B", type: "inter", group: "G2", kind: "neuron", inD: 1, outD: 0, D: 1 },
  ];
  const edges = [{ id: "edge-ab", sourceId: "neuron/A", targetId: "neuron/B", type: "S", weight: 2 }];
  const graphml = serializeGraphML(nodes, edges);

  assert.match(serializeNodeLink(nodes, edges), /"links": \[/);
  assert.match(serializeAdjacency(nodes, edges), /"neuron\/A"/);
  assert.match(graphml, /<graphml/);
  assert.match(graphml, /<key id="node_name" for="node" attr.name="name" attr.type="string"/);
  assert.match(graphml, /<key id="edge_weight" for="edge" attr.name="weight" attr.type="double"/);
  assert.match(graphml, /<data key="node_name">A<\/data>/);
  assert.match(graphml, /<data key="edge_type">S<\/data>/);
  assert.match(serializeGml(nodes, edges), /graph \[/);
  assert.match(serializeAdjList(nodes, edges), /neuron\/A neuron\/B/);
});
