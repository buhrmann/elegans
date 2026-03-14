import { defineConfig } from "vite";
import path from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  build: {
    rollupOptions: {
      input: {
        main: path.resolve(rootDir, "index.html"),
      },
    },
  },
});
