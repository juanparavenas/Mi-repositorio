/* =============================================================================
   CMF Academy · Control de tema (Sistema / Claro / Oscuro) y acento
   - "Sistema" quita data-theme y deja que mande prefers-color-scheme.
   - La elección se recuerda en este navegador (localStorage, si está
     disponible); si no lo está, la página funciona igual.
   - Para evitar un destello al cargar, el bloque inline del <head> aplica la
     preferencia guardada antes de pintar (ver prototipo.html).
   ============================================================================= */
(function () {
  "use strict";
  var root = document.documentElement;
  var KEY_THEME = "cmf-theme";
  var KEY_ACCENT = "cmf-accent";

  function read(key) {
    try { return window.localStorage.getItem(key); } catch (e) { return null; }
  }
  function write(key, value) {
    try { window.localStorage.setItem(key, value); } catch (e) { /* sin almacenamiento: no pasa nada */ }
  }

  function applyTheme(mode) {
    if (mode === "light" || mode === "dark") root.setAttribute("data-theme", mode);
    else root.removeAttribute("data-theme");
    document.querySelectorAll("[data-theme-option]").forEach(function (b) {
      b.setAttribute("aria-pressed", String(b.getAttribute("data-theme-option") === (mode || "system")));
    });
  }
  function applyAccent(accent) {
    if (accent === "blue") root.setAttribute("data-accent", "blue");
    else root.removeAttribute("data-accent");
    document.querySelectorAll("[data-accent-option]").forEach(function (b) {
      b.setAttribute("aria-pressed", String(b.getAttribute("data-accent-option") === (accent || "petrol")));
    });
  }

  applyTheme(read(KEY_THEME));
  applyAccent(read(KEY_ACCENT));

  document.addEventListener("click", function (event) {
    var t = event.target.closest("[data-theme-option]");
    if (t) {
      var mode = t.getAttribute("data-theme-option");
      write(KEY_THEME, mode);
      applyTheme(mode);
      return;
    }
    var a = event.target.closest("[data-accent-option]");
    if (a) {
      var accent = a.getAttribute("data-accent-option");
      write(KEY_ACCENT, accent);
      applyAccent(accent);
      return;
    }
    var m = event.target.closest("[data-menu-toggle]");
    if (m) {
      var app = document.querySelector(".app");
      var open = app.getAttribute("data-menu") !== "open";
      app.setAttribute("data-menu", open ? "open" : "closed");
      document.querySelectorAll("[data-menu-toggle][aria-expanded]").forEach(function (b) {
        b.setAttribute("aria-expanded", String(open));
      });
    }
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") {
      var app = document.querySelector(".app");
      if (app && app.getAttribute("data-menu") === "open") app.setAttribute("data-menu", "closed");
    }
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
      var input = document.querySelector(".search input");
      if (input) { event.preventDefault(); input.focus(); }
    }
  });
})();
