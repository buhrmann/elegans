// @ts-check

const PUBMED_BASE_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi";

/**
 * @param {number} milliseconds
 */
function sleep(milliseconds) {
  return new Promise((resolve) => window.setTimeout(resolve, milliseconds));
}

/**
 * @param {string} group
 * @param {string} query
 */
function cacheKey(group, query) {
  return `pubmed:${group}:${query.toLowerCase()}`;
}

/**
 * @param {string} group
 * @param {string} query
 * @returns {Promise<number>}
 */
export async function fetchPubmedCount(group, query) {
  const key = cacheKey(group, query);
  const cachedValue = window.sessionStorage.getItem(key);
  if (cachedValue) {
    return Number(cachedValue);
  }

  const params = new URLSearchParams({
    db: "pubmed",
    retmode: "json",
    term: `"Caenorhabditis elegans"[All Fields] AND "${query}"[All Fields] AND "${group}"[All Fields]`,
  });
  const response = await fetch(`${PUBMED_BASE_URL}?${params.toString()}`);
  if (!response.ok) {
    throw new Error(`PubMed request failed with status ${response.status}`);
  }
  const payload = await response.json();
  const count = Number(payload.esearchresult?.count ?? 0);
  window.sessionStorage.setItem(key, String(count));
  return count;
}

/**
 * @param {string[]} groups
 * @param {string} query
 * @param {(completed: number, total: number) => void} progress
 * @returns {Promise<Array<{ name: string; count: number }>>}
 */
export async function searchPubmedGroups(groups, query, progress) {
  /** @type {Array<{ name: string; count: number }>} */
  const results = [];
  for (let index = 0; index < groups.length; index += 1) {
    const group = groups[index];
    const count = await fetchPubmedCount(group, query);
    results.push({ name: group, count });
    progress(index + 1, groups.length);
    if (index < groups.length - 1) {
      await sleep(350);
    }
  }
  return results;
}
