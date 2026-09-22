(() => {
  const toggle = document.querySelector("[data-nav-toggle]");
  const menu = document.querySelector("[data-nav-menu]");

  if (toggle && menu) {
    toggle.addEventListener("click", () => {
      const isOpen = menu.dataset.open === "true";
      menu.dataset.open = String(!isOpen);
      toggle.setAttribute("aria-expanded", String(!isOpen));
    });

    menu.addEventListener("click", (event) => {
      if (event.target.closest("a")) {
        menu.dataset.open = "false";
        toggle.setAttribute("aria-expanded", "false");
      }
    });
  }

  const filters = document.querySelectorAll("[data-filter]");
  const cards = document.querySelectorAll("[data-category]");

  filters.forEach((button) => {
    button.addEventListener("click", () => {
      const selected = button.dataset.filter;

      filters.forEach((candidate) => {
        candidate.setAttribute("aria-pressed", String(candidate === button));
      });

      cards.forEach((card) => {
        card.hidden = selected !== "all" && card.dataset.category !== selected;
      });
    });
  });

  document.querySelectorAll("[data-current-year]").forEach((node) => {
    node.textContent = String(new Date().getFullYear());
  });
})();
