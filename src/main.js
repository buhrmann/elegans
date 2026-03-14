// @ts-check

import { createDataStore } from "./lib/data-store.js";
import {
  downloadSvgPng,
  downloadText,
  serializeAdjList,
  serializeAdjacency,
  serializeGml,
  serializeGraphML,
  serializeNodeLink,
} from "./lib/exporters.js";
import { searchPubmedGroups } from "./lib/pubmed-client.js";
import {
  applyMuscleSelection,
  createIndex,
  createInitialGraph,
  expandGraph,
  graphForGroups,
  parseInputList,
  subgraph,
} from "./lib/query-engine.js";
import { colorForType, createRenderer } from "./lib/renderer.js";
import { attachTokenAutocomplete } from "./lib/token-autocomplete.js";

/**
 * @typedef {import("./lib/query-engine.js").ConnectomeNode} ConnectomeNode
 * @typedef {import("./lib/query-engine.js").ConnectomeEdge} ConnectomeEdge
 */

const controls = {
  graph: /** @type {HTMLElement} */ (document.getElementById("graph")),
  graphStatus: /** @type {HTMLElement} */ (document.getElementById("graph-status")),
  group1: /** @type {HTMLInputElement} */ (document.getElementById("group1")),
  group2: /** @type {HTMLInputElement} */ (document.getElementById("group2")),
  receptors: /** @type {HTMLInputElement} */ (document.getElementById("rec-sel")),
  pathDirection: /** @type {HTMLSelectElement} */ (document.getElementById("path-direction")),
  searchNode: /** @type {HTMLInputElement} */ (document.getElementById("search-node")),
  searchNodeOptions: /** @type {HTMLDataListElement} */ (document.getElementById("search-node-options")),
  searchButton: /** @type {HTMLButtonElement} */ (document.getElementById("search-button")),
  presetSelect: /** @type {HTMLSelectElement} */ (document.getElementById("preset-select")),
  fetchButton: /** @type {HTMLAnchorElement} */ (document.getElementById("fetchbutton")),
  expandButton: /** @type {HTMLAnchorElement} */ (document.getElementById("expandbutton")),
  resetButton: /** @type {HTMLAnchorElement} */ (document.getElementById("resetbutton")),
  subwSlider: /** @type {HTMLInputElement} */ (document.getElementById("subwslider")),
  subjSlider: /** @type {HTMLInputElement} */ (document.getElementById("subjslider")),
  subpSlider: /** @type {HTMLInputElement} */ (document.getElementById("subpslider")),
  subwLabel: /** @type {HTMLOutputElement} */ (document.getElementById("subwlabel")),
  subjLabel: /** @type {HTMLOutputElement} */ (document.getElementById("subjlabel")),
  subpLabel: /** @type {HTMLOutputElement} */ (document.getElementById("subplabel")),
  ndegSlider: /** @type {HTMLInputElement} */ (document.getElementById("ndegslider")),
  wminSlider: /** @type {HTMLInputElement} */ (document.getElementById("wminslider")),
  jminSlider: /** @type {HTMLInputElement} */ (document.getElementById("jminslider")),
  ndegLabel: /** @type {HTMLOutputElement} */ (document.getElementById("ndeglabel")),
  wminLabel: /** @type {HTMLOutputElement} */ (document.getElementById("wminlabel")),
  jminLabel: /** @type {HTMLOutputElement} */ (document.getElementById("jminlabel")),
  showSynapses: /** @type {HTMLInputElement} */ (document.getElementById("show-synapses")),
  showJunctions: /** @type {HTMLInputElement} */ (document.getElementById("show-junctions")),
  showArcs: /** @type {HTMLInputElement} */ (document.getElementById("show-arcs")),
  nodeHeading: /** @type {HTMLElement} */ (document.getElementById("node-heading")),
  nodeInfo: /** @type {HTMLElement} */ (document.getElementById("nodeinfo")),
  exportFormat: /** @type {HTMLSelectElement} */ (document.getElementById("export-format")),
  exportButton: /** @type {HTMLButtonElement} */ (document.getElementById("export-button")),
  downloadPng: /** @type {HTMLButtonElement} */ (document.getElementById("download-png")),
  pubmedSearch: /** @type {HTMLInputElement} */ (document.getElementById("pmsearch")),
  pubmedThreshold: /** @type {HTMLInputElement} */ (document.getElementById("pubnumslider")),
  pubmedThresholdLabel: /** @type {HTMLOutputElement} */ (document.getElementById("pubnumlabel")),
  pubmedPopulateOnly: /** @type {HTMLInputElement} */ (document.getElementById("pubmed-check")),
  pubmedButton: /** @type {HTMLButtonElement} */ (document.getElementById("pmbutton")),
  pubmedStatus: /** @type {HTMLElement} */ (document.getElementById("pubmed-status")),
  muscleHead: /** @type {HTMLInputElement} */ (document.getElementById("mhead-check")),
  muscleNeck: /** @type {HTMLInputElement} */ (document.getElementById("mneck-check")),
  muscleBody: /** @type {HTMLInputElement} */ (document.getElementById("mbody-check")),
  leftWidget: /** @type {HTMLElement} */ (document.getElementById("left-widget")),
  rightWidget: /** @type {HTMLElement} */ (document.getElementById("right-widget")),
  leftHandle: /** @type {HTMLElement} */ (document.getElementById("left-handle")),
  rightHandle: /** @type {HTMLElement} */ (document.getElementById("right-handle")),
  introPanel: /** @type {HTMLElement} */ (document.getElementById("intro-panel")),
  introHandle: /** @type {HTMLElement} */ (document.getElementById("intro-handle")),
  introHandleTab: /** @type {HTMLElement} */ (document.getElementById("intro-handle-tab")),
  introToggle: /** @type {HTMLButtonElement} */ (document.getElementById("intro-toggle")),
  stats: {
    n: /** @type {HTMLElement} */ (document.getElementById("stats-n")),
    m: /** @type {HTMLElement} */ (document.getElementById("stats-m")),
    s: /** @type {HTMLElement} */ (document.getElementById("stats-s")),
    ej: /** @type {HTMLElement} */ (document.getElementById("stats-ej")),
    nmj: /** @type {HTMLElement} */ (document.getElementById("stats-nmj")),
  },
  visibilityModeInputs: /** @type {NodeListOf<HTMLInputElement>} */ (
    document.querySelectorAll('input[name="visibility-mode"]')
  ),
};

let selectedNodeId = null;
let canExpand = false;
let lastRenderNodes = null;
let lastRenderEdges = null;

showGraphStatus("Loading connectome data...");

const dataset = await fetch("/data/connectome.v1.json").then((response) => {
  if (!response.ok) {
    throw new Error(`Could not load connectome dataset (${response.status}).`);
  }
  return response.json();
});
const index = createIndex(dataset);
const store = createDataStore(index);
const renderer = createRenderer({
  container: controls.graph,
  onNodeSelect(node) {
    selectedNodeId = node?.id ?? null;
    renderNodeInfo(node);
  },
});

setupControls(dataset);

store.subscribe((state) => {
  const nodesChanged = lastRenderNodes !== state.visibility.renderGraph.nodes;
  const edgesChanged = lastRenderEdges !== state.visibility.renderGraph.edges;
  if (nodesChanged || edgesChanged) {
    renderer.setGraph(state.visibility.renderGraph);
    lastRenderNodes = state.visibility.renderGraph.nodes;
    lastRenderEdges = state.visibility.renderGraph.edges;
  }
  renderer.setArcs(state.arcs);
  renderer.setHidden(
    state.filters.mode === "hide" ? state.visibility.hiddenNodeIds : new Set(),
    state.filters.mode === "hide" ? state.visibility.hiddenEdgeIds : new Set(),
  );

  renderStats(state.visibility.stats);
  renderSearchOptions(state.visibility.searchNames);

  if (selectedNodeId && !state.currentGraph.nodes.some((node) => node.id === selectedNodeId)) {
    selectedNodeId = null;
    renderer.focusNode(null);
  }
});

store.setGraph(createInitialGraph(index));
showGraphStatus("");

/**
 * @param {{ groups: string[]; receptors: string[]; presets: Array<{ name: string; g1: string; g2: string; smin: number; jmin: number; length: number }> }} data
 */
function setupControls(data) {
  attachTokenAutocomplete(controls.group1, data.groups);
  attachTokenAutocomplete(controls.group2, data.groups);
  attachTokenAutocomplete(controls.receptors, data.receptors);

  for (const preset of data.presets) {
    const option = document.createElement("option");
    option.value = preset.name;
    option.textContent = preset.name;
    controls.presetSelect.append(option);
  }

  controls.presetSelect.addEventListener("change", () => {
    const preset = data.presets.find((entry) => entry.name === controls.presetSelect.value);
    if (!preset) {
      return;
    }
    clearFocusedNode();
    controls.group1.value = preset.g1;
    controls.group2.value = preset.g2;
    setRangeValue(controls.subwSlider, controls.subwLabel, preset.smin);
    setRangeValue(controls.subjSlider, controls.subjLabel, preset.jmin);
    setRangeValue(controls.subpSlider, controls.subpLabel, preset.length);
  });

  bindRange(controls.subwSlider, controls.subwLabel);
  bindRange(controls.subjSlider, controls.subjLabel);
  bindRange(controls.subpSlider, controls.subpLabel);
  bindRange(controls.ndegSlider, controls.ndegLabel, (value) => store.setFilters({ nodeDegree: value }));
  bindRange(controls.wminSlider, controls.wminLabel, (value) => store.setFilters({ minWeightS: value }));
  bindRange(controls.jminSlider, controls.jminLabel, (value) => store.setFilters({ minWeightJ: value }));
  bindRange(controls.pubmedThreshold, controls.pubmedThresholdLabel);

  controls.visibilityModeInputs.forEach((input) => {
    input.addEventListener("change", () => {
      controls.visibilityModeInputs.forEach((radio) => {
        radio.parentElement?.classList.toggle("active", radio.checked);
      });
      store.setFilters({ mode: input.value === "hide" ? "hide" : "prune" });
    });
  });

  controls.showSynapses.addEventListener("change", () => {
    store.setFilters({ showSynapses: controls.showSynapses.checked });
  });
  controls.showJunctions.addEventListener("change", () => {
    store.setFilters({ showJunctions: controls.showJunctions.checked });
  });
  controls.showArcs.addEventListener("change", () => {
    store.setArcs(controls.showArcs.checked);
  });

  [controls.muscleHead, controls.muscleNeck, controls.muscleBody].forEach((input) => {
    input.addEventListener("change", () => {
      store.setGraph(applyMuscleSelection(index, store.getState().currentGraph, selectedMuscleParts()));
    });
  });

  controls.searchButton.addEventListener("click", () => searchNode());
  controls.searchNode.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      searchNode();
    }
  });

  controls.fetchButton.addEventListener("click", async (event) => {
    event.preventDefault();
    await runWithButton(controls.fetchButton, "Fetching...", async () => {
      clearFocusedNode();
      const graph = subgraph(index, {
        groups1: parseInputList(controls.group1.value),
        groups2: parseInputList(controls.group2.value),
        receptors: parseInputList(controls.receptors.value),
        minWeightS: Number(controls.subwSlider.value),
        minWeightJ: Number(controls.subjSlider.value),
        maxLength: Number(controls.subpSlider.value),
        direction: controls.pathDirection.value === "bi" ? "bi" : "uni",
        muscleParts: selectedMuscleParts(),
      });
      canExpand = graph.nodes.length > 0;
      controls.expandButton.classList.toggle("disabled", !canExpand);
      store.setGraph(graph);
      showGraphStatus(
        graph.nodes.length > 0 ? "" : "No matching subgraph was found for the current parameters.",
      );
    });
  });

  controls.expandButton.addEventListener("click", async (event) => {
    event.preventDefault();
    if (!canExpand) {
      return;
    }
    await runWithButton(controls.expandButton, "Expanding...", async () => {
      const graph = expandGraph(index, store.getState().currentGraph, selectedMuscleParts());
      store.setGraph(graph);
      showGraphStatus("");
    });
  });

  controls.resetButton.addEventListener("click", async (event) => {
    event.preventDefault();
    await runWithButton(controls.resetButton, "Resetting...", async () => {
      canExpand = false;
      controls.expandButton.classList.add("disabled");
      clearFocusedNode();
      store.setGraph(applyMuscleSelection(index, createInitialGraph(index), selectedMuscleParts()));
      showGraphStatus("");
    });
  });

  controls.exportButton.addEventListener("click", () => exportCurrentGraph());
  controls.downloadPng.addEventListener("click", async () => {
    try {
      await downloadSvgPng(renderer.getSvgElement(), "graph.png", renderer.getCanvasElement());
    } catch (error) {
      showGraphStatus(error instanceof Error ? error.message : "PNG export failed.");
    }
  });

  controls.pubmedButton.addEventListener("click", async () => {
    const query = controls.pubmedSearch.value.trim();
    const threshold = Number(controls.pubmedThreshold.value);
    if (!query) {
      controls.pubmedStatus.textContent = "Enter a PubMed query first.";
      return;
    }

    await runWithButton(controls.pubmedButton, "Starting...", async (button) => {
      controls.pubmedStatus.textContent = "";
      try {
        const results = await searchPubmedGroups(index.data.groups, query, (completed, total) => {
          button.textContent = `${Math.round((completed / total) * 100)}% done`;
        });
        const filteredGroups = results.filter((result) => result.count >= threshold).map((result) => result.name);
        if (controls.pubmedPopulateOnly.checked) {
          controls.group1.value = filteredGroups.join(", ");
          controls.group2.value = filteredGroups.join(", ");
          controls.pubmedStatus.textContent = filteredGroups.length
            ? `Loaded ${filteredGroups.length} matching groups into the subgraph form.`
            : "No groups met the PubMed threshold.";
          return;
        }

        clearFocusedNode();
        const graph = applyMuscleSelection(index, graphForGroups(index, filteredGroups), selectedMuscleParts());
        canExpand = graph.nodes.length > 0;
        controls.expandButton.classList.toggle("disabled", !canExpand);
        store.setGraph(graph);
        controls.pubmedStatus.textContent = filteredGroups.length
          ? `Fetched a graph for ${filteredGroups.length} matching groups.`
          : "No groups met the PubMed threshold.";
      } catch (error) {
        console.error(error);
        controls.pubmedStatus.textContent =
          "PubMed lookups are unavailable from this browser or are being rate-limited.";
      }
    });
  });

  controls.leftHandle.addEventListener("click", () => toggleWidget(controls.leftWidget, controls.leftHandle, "left"));
  controls.rightHandle.addEventListener("click", () =>
    toggleWidget(controls.rightWidget, controls.rightHandle, "right"),
  );
  updateWidgetHandle(controls.leftWidget, controls.leftHandle, "left");
  updateWidgetHandle(controls.rightWidget, controls.rightHandle, "right");
  controls.introHandle.addEventListener("click", toggleIntro);
  controls.introHandleTab.addEventListener("click", toggleIntro);
  controls.introToggle.addEventListener("click", toggleIntro);
}

function renderSearchOptions(names) {
  controls.searchNodeOptions.replaceChildren(
    ...names.map((name) => {
      const option = document.createElement("option");
      option.value = name;
      return option;
    }),
  );
}

/**
 * @param {{ neurons: number; muscles: number; synapses: number; junctions: number; nmj: number }} stats
 */
function renderStats(stats) {
  controls.stats.n.textContent = String(stats.neurons);
  controls.stats.m.textContent = String(stats.muscles);
  controls.stats.s.textContent = String(stats.synapses);
  controls.stats.ej.textContent = String(stats.junctions);
  controls.stats.nmj.textContent = String(stats.nmj);
}

/**
 * @param {ConnectomeNode | null | undefined} node
 */
function renderNodeInfo(node) {
  if (!node) {
    controls.nodeHeading.textContent = "Node info";
    controls.nodeInfo.textContent = "Click to select...";
    return;
  }

  controls.nodeHeading.textContent = node.name;
  const badges = [];
  badges.push(`<span class="badge" style="background-color:${colorForType(node.type)}">${escapeHtml(node.type)}</span>`);
  if (node.modalities) {
    for (const modality of parseInputList(node.modalities)) {
      badges.push(`<span class="badge">${escapeHtml(modality)}</span>`);
    }
  }

  if (node.kind === "muscle") {
    controls.nodeInfo.innerHTML = `
      <p>${badges.join(" ")}</p>
      <ul class="list-group">
        <li class="list-group-item"><span class="badge">${escapeHtml(node.part ?? "")}</span>Location</li>
        <li class="list-group-item"><span class="badge">${node.inD}</span>In Degree</li>
      </ul>
    `;
    return;
  }

  controls.nodeInfo.innerHTML = `
    <p>${badges.join(" ")}</p>
    ${node.functions ? `<p><strong>Functions</strong>: ${escapeHtml(node.functions)}</p>` : ""}
    <ul class="list-group">
      <li class="list-group-item"><span class="badge">${escapeHtml(node.group ?? "")}</span>Group</li>
      <li class="list-group-item"><span class="badge">${escapeHtml(node.AYGanglionDesignation ?? "")}</span>Ganglion</li>
      <li class="list-group-item"><span class="badge">${node.inD}</span>In Degree</li>
      <li class="list-group-item"><span class="badge">${node.outD}</span>Out Degree</li>
      <li class="list-group-item"><span class="badge">${node.D}</span>Total Degree</li>
      <li class="list-group-item"><span class="badge">${node.AYNbr ?? ""}</span>AYNbr</li>
      ${node.organ ? `<li class="list-group-item"><span class="badge">${escapeHtml(node.organ)}</span>Organ</li>` : ""}
      <li class="list-group-item">
        <a target="_blank" rel="noreferrer" href="http://wormweb.org/neuralnet#c=${encodeURIComponent(node.group ?? "")}&m=1">
          <span class="glyphicon glyphicon-new-window pull-right"></span>In WormWeb
        </a>
      </li>
    </ul>
  `;
}

function searchNode() {
  const name = controls.searchNode.value.trim();
  const node = store
    .getState()
    .currentGraph.nodes.find((entry) => entry.name === name);

  controls.searchNode.classList.toggle("alert-danger", !node);
  if (!node) {
    return;
  }
  showGraphStatus("");
  renderer.focusNode(node.id);
}

function clearFocusedNode() {
  selectedNodeId = null;
  renderer.focusNode(null);
}

function selectedMuscleParts() {
  return [
    controls.muscleHead.checked ? "head" : null,
    controls.muscleNeck.checked ? "neck" : null,
    controls.muscleBody.checked ? "body" : null,
  ].filter(Boolean);
}

function exportCurrentGraph() {
  const graph = store.getState().currentGraph;
  if (graph.nodes.length === 0) {
    showGraphStatus("There is no fetched graph to export.");
    return;
  }

  let filename = "graph.txt";
  let mimeType = "text/plain";
  let text = "";
  switch (controls.exportFormat.value) {
    case "json-list":
      filename = "graph.node-link.json";
      mimeType = "application/json";
      text = serializeNodeLink(graph.nodes, graph.edges);
      break;
    case "json-graph":
      filename = "graph.adjacency.json";
      mimeType = "application/json";
      text = serializeAdjacency(graph.nodes, graph.edges);
      break;
    case "graphml":
      filename = "graph.graphml";
      text = serializeGraphML(graph.nodes, graph.edges);
      break;
    case "gml":
      filename = "graph.gml";
      text = serializeGml(graph.nodes, graph.edges);
      break;
    default:
      filename = "graph.adj";
      text = serializeAdjList(graph.nodes, graph.edges);
      break;
  }
  downloadText(filename, text, mimeType);
}

/**
 * @param {HTMLElement} widget
 * @param {HTMLElement} handle
 * @param {"left" | "right"} side
 */
function toggleWidget(widget, handle, side) {
  widget.classList.toggle("out");
  updateWidgetHandle(widget, handle, side);
}

/**
 * @param {HTMLElement} widget
 * @param {HTMLElement} handle
 * @param {"left" | "right"} side
 */
function updateWidgetHandle(widget, handle, side) {
  const visible = widget.classList.contains("out");
  const icon = handle.querySelector(".glyphicon");
  if (!icon) {
    return;
  }
  handle.setAttribute("aria-expanded", visible ? "true" : "false");
  icon.classList.toggle("glyphicon-chevron-left", side === "left" ? visible : !visible);
  icon.classList.toggle("glyphicon-chevron-right", side === "left" ? !visible : visible);
}

function toggleIntro() {
  controls.introPanel.classList.toggle("out");
}

/**
 * @param {HTMLInputElement} input
 * @param {HTMLOutputElement} output
 * @param {(value: number) => void} [onChange]
 */
function bindRange(input, output, onChange) {
  setRangeValue(input, output, Number(input.value));
  input.addEventListener("input", () => {
    const value = Number(input.value);
    setRangeValue(input, output, value);
    onChange?.(value);
  });
}

/**
 * @param {HTMLInputElement} input
 * @param {HTMLOutputElement} output
 * @param {number} value
 */
function setRangeValue(input, output, value) {
  input.value = String(value);
  output.value = String(value);
  output.textContent = String(value);
}

/**
 * @param {HTMLElement} button
 * @param {string} busyText
 * @param {(button: HTMLElement) => Promise<void>} fn
 */
async function runWithButton(button, busyText, fn) {
  const originalText = button.textContent ?? "";
  button.textContent = busyText;
  button.setAttribute("aria-busy", "true");
  try {
    await fn(button);
  } catch (error) {
    console.error(error);
    showGraphStatus(error instanceof Error ? error.message : "Unexpected error.");
  } finally {
    button.textContent = originalText;
    button.removeAttribute("aria-busy");
  }
}

/**
 * @param {string} message
 */
function showGraphStatus(message) {
  controls.graphStatus.textContent = message;
  controls.graphStatus.classList.toggle("hidden", !message);
}

/**
 * @param {string} value
 */
function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
