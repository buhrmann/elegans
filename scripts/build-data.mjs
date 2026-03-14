// @ts-check

import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildConnectome } from "./lib/build-connectome.mjs";

const rootDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const outputDir = path.join(rootDir, "public", "data");
const outputFile = path.join(outputDir, "connectome.v1.json");

const connectome = await buildConnectome(rootDir);

await fs.mkdir(outputDir, { recursive: true });
await fs.writeFile(outputFile, JSON.stringify(connectome, null, 2));

console.log(`Wrote ${path.relative(rootDir, outputFile)}`);
console.log(connectome.summary);
