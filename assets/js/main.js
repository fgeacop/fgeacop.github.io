(() => {
  document.documentElement.classList.add("js");

  const header = document.querySelector(".site-header");
  const toggle = document.querySelector(".menu-toggle");
  const navigation = document.querySelector("#site-nav");
  const desktopQuery = window.matchMedia("(min-width: 62.001rem)");

  const setMenu = (open, returnFocus = false) => {
    if (!toggle || !navigation) return;
    toggle.setAttribute("aria-expanded", String(open));
    toggle.setAttribute("aria-label", open ? "Close navigation" : "Open navigation");
    navigation.hidden = !open && !desktopQuery.matches;
    document.body.classList.toggle("menu-open", open);
    if (returnFocus) toggle.focus();
  };

  if (toggle && navigation) {
    setMenu(false);

    toggle.addEventListener("click", () => {
      setMenu(toggle.getAttribute("aria-expanded") !== "true");
    });

    navigation.addEventListener("click", (event) => {
      if (event.target.closest("a") && !desktopQuery.matches) setMenu(false);
    });

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && toggle.getAttribute("aria-expanded") === "true") {
        setMenu(false, true);
      }
    });

    desktopQuery.addEventListener("change", () => setMenu(false));
  }

  const updateHeader = () => header?.classList.toggle("scrolled", window.scrollY > 16);
  updateHeader();
  window.addEventListener("scroll", updateHeader, { passive: true });

  const revealItems = document.querySelectorAll("[data-reveal]");
  if (revealItems.length && "IntersectionObserver" in window) {
    try {
      const observer = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              entry.target.classList.add("is-visible");
              observer.unobserve(entry.target);
            }
          });
        },
        { threshold: 0.1 },
      );
      document.documentElement.classList.add("reveal-supported");
      revealItems.forEach((item) => observer.observe(item));
    } catch {
      document.documentElement.classList.remove("reveal-supported");
    }
  }
})();
