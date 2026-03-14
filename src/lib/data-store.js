// @ts-check

import { applyVisibilityFilters, createInitialGraph } from "./query-engine.js";

/**
 * @param {ReturnType<import("./query-engine.js").createIndex>} index
 */
export function createDataStore(index) {
  /** @type {{
   *   currentGraph: ReturnType<typeof createInitialGraph>;
   *   filters: {
   *     nodeDegree: number;
   *     minWeightS: number;
   *     minWeightJ: number;
   *     showSynapses: boolean;
   *     showJunctions: boolean;
   *     mode: "prune" | "hide";
   *   };
   *   arcs: boolean;
   *   visibility: ReturnType<typeof applyVisibilityFilters>;
   * }} */
  let state = {
    currentGraph: createInitialGraph(index),
    filters: {
      nodeDegree: 0,
      minWeightS: 1,
      minWeightJ: 1,
      showSynapses: true,
      showJunctions: true,
      mode: "prune",
    },
    arcs: false,
    visibility: /** @type {ReturnType<typeof applyVisibilityFilters>} */ (
      applyVisibilityFilters(index, createInitialGraph(index), {
        nodeDegree: 0,
        minWeightS: 1,
        minWeightJ: 1,
        showSynapses: true,
        showJunctions: true,
        mode: "prune",
      })
    ),
  };

  /** @type {Set<(state: typeof state) => void>} */
  const listeners = new Set();

  function publish() {
    state = {
      ...state,
      visibility: applyVisibilityFilters(index, state.currentGraph, state.filters),
    };
    for (const listener of listeners) {
      listener(state);
    }
  }

  return {
    getState() {
      return state;
    },
    subscribe(listener) {
      listeners.add(listener);
      listener(state);
      return () => listeners.delete(listener);
    },
    setGraph(graph) {
      state = { ...state, currentGraph: graph };
      publish();
    },
    setFilters(nextFilters) {
      state = {
        ...state,
        filters: {
          ...state.filters,
          ...nextFilters,
        },
      };
      publish();
    },
    setArcs(nextValue) {
      state = { ...state, arcs: nextValue };
      for (const listener of listeners) {
        listener(state);
      }
    },
  };
}
