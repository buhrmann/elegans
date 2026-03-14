// @ts-check

/**
 * @param {HTMLInputElement} input
 * @param {string[]} options
 */
export function attachTokenAutocomplete(input, options) {
  const menu = document.createElement("div");
  menu.className = "token-menu hidden";
  input.parentElement?.append(menu);

  /**
   * @param {string} value
   */
  function split(value) {
    return value.split(",").map((token) => token.trimStart());
  }

  /**
   * @param {string} nextValue
   */
  function replaceCurrentToken(nextValue) {
    const tokens = split(input.value);
    tokens[tokens.length - 1] = nextValue;
    input.value = `${tokens.filter(Boolean).join(", ")}${input.value.endsWith(",") ? " " : ""}`;
    input.dispatchEvent(new Event("change"));
    hideMenu();
    input.focus();
  }

  function hideMenu() {
    menu.classList.add("hidden");
    menu.replaceChildren();
  }

  function renderMenu() {
    const tokens = split(input.value);
    const fragment = tokens.at(-1)?.trim().toLowerCase() ?? "";
    if (!fragment) {
      hideMenu();
      return;
    }

    const matches = options.filter((option) => option.toLowerCase().startsWith(fragment)).slice(0, 8);
    if (matches.length === 0) {
      hideMenu();
      return;
    }

    menu.replaceChildren(
      ...matches.map((match) => {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "token-menu-item";
        button.textContent = match;
        button.addEventListener("mousedown", (event) => {
          event.preventDefault();
          replaceCurrentToken(match);
        });
        return button;
      }),
    );
    menu.classList.remove("hidden");
  }

  input.addEventListener("input", renderMenu);
  input.addEventListener("focus", renderMenu);
  input.addEventListener("blur", () => {
    window.setTimeout(hideMenu, 100);
  });
}
