# Worm Circuitry Explorer

This repo is now a static Bun + Vite app for exploring the *C. elegans* connectome in the browser.

There is no Flask app, no Neo4j runtime, and no Python build step anymore. The graph dataset is generated at build time as `public/data/connectome.v1.json`, then loaded by the frontend as a static asset.

## Requirements

- Bun 1.3+
- Node.js 20+  
  Bun is the package manager, but the data builder and tests still run on Node for compatibility.

## Local development

```bash
bun install
bun run build:data
bun run dev
```

Open the local Vite URL, usually `http://localhost:5173`.

Useful commands:

```bash
bun run test
bun run build
bun run preview
```

Notes:

- `bun run build:data` regenerates `public/data/connectome.v1.json`.
- `bun run test` and `bun run build` both regenerate the dataset first.
- `public/data/connectome.v1.json` is ignored in git because it is a generated artifact.

## Data pipeline

The data build entrypoint is:

- `scripts/build-data.mjs`

The actual builder logic is here:

- `scripts/lib/build-connectome.mjs`

The builder currently reads these raw inputs:

- `data/ChenVarshney/NeuronType.xls`
- `data/ChenVarshney/NeuronFixedPoints.xls`
- `data/ChenVarshney/NeuronConnect.csv`
- `data/DynamicConnectome/celegans277/celegans277labels.csv`
- `data/DynamicConnectome/celegans277/celegans277positions.csv`
- `data/WormWeb/name_neurons.txt`
- `data/Self/Sensors.tsv`

The generated dataset contains:

- Canonical `nodes[]` and `edges[]`
- Group and receptor indexes
- Presets used by the UI
- Summary counts for the baseline graph

The builder preserves the legacy project rules that are still needed:

- merge connectivity, type, group, sensor, and layout inputs
- fill missing coordinates from symmetric left/right partner neurons
- compute `inD`, `outD`, and `D`
- include muscle nodes and NMJ edges from the muscle workbook
- dedupe reciprocal electrical junction pairs for the initial full graph

## Data provenance

Primary currently-used sources:

- `data/ChenVarshney/`
  Connectivity/type/muscle tables used by the current build. The folder includes its own `SOURCES.txt`.
- `data/WormWeb/`
  Neuron name/group/type mapping used by the current build. The folder includes its own `SOURCES.txt`.
- `data/Self/Sensors.tsv`
  Local curated sensor annotations carried over from the legacy project.
- `data/DynamicConnectome/celegans277/`
  Layout labels and coordinates used for node positioning in the static app.

Historical reference data retained in the repo but not read by the current builder:

- `data/OpenWorm/`
- `data/WormAtlas/`

Those folders are still useful as provenance/reference material, but they are not part of the modernized build path.

## Repo layout

- `index.html`
  Static app shell.
- `src/`
  Modern browser code and app styles.
- `scripts/`
  Build-time data generation.
- `tests/`
  Node-based tests for the builder, query engine, and exporters.
- `public/static/`
  Small set of legacy CSS/font/image assets still used by the current static app.
- `data/`
  Raw source datasets and reference material.

## What was removed

The old server-side/runtime stack has been removed from the working tree:

- Flask templates
- Python app/helper scripts
- Neo4j-specific runtime code
- legacy Sigma renderer assets
- duplicated old `static/` tree
- generated GraphML export artifacts

If you need the original implementation details, use git history rather than keeping those files in the active tree.
