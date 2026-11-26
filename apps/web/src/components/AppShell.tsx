"use client";

import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";

import { Icon } from "./Icon";
import { SearchBox } from "./SearchBox";
import { Sidebar } from "./Sidebar";
import { ThemeToggle } from "./ThemeToggle";

const SIDEBAR_ID = "barra-lateral";

/** Estructura común: barra lateral, barra superior, contenido y pie. */
export function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const [menuOpen, setMenuOpen] = useState(false);

  // Al navegar, el menú móvil se cierra.
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setMenuOpen(false);
  }, [pathname]);

  useEffect(() => {
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") setMenuOpen(false);
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        const input = document.querySelector<HTMLInputElement>("[data-global-search]");
        if (input) {
          event.preventDefault();
          input.focus();
        }
      }
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, []);

  return (
    <div className="app" data-menu={menuOpen ? "open" : "closed"}>
      <a className="skip-link" href="#contenido">
        Saltar al contenido
      </a>
      <div className="scrim" onClick={() => setMenuOpen(false)} aria-hidden="true" />
      <Sidebar id={SIDEBAR_ID} />
      <div>
        <header className="topbar">
          <button
            className="btn btn-quiet btn-icon menu-button"
            type="button"
            aria-controls={SIDEBAR_ID}
            aria-expanded={menuOpen}
            aria-label={menuOpen ? "Cerrar menú" : "Abrir menú"}
            onClick={() => setMenuOpen((open) => !open)}
          >
            <Icon name="menu" />
          </button>
          <SearchBox />
          <span className="spacer" />
          <ThemeToggle />
        </header>
        <main className="content" id="contenido" tabIndex={-1}>
          <div className="container">{children}</div>
        </main>
        <footer className="footer">
          <span>CMF Academy · The Oral &amp; Maxillofacial Knowledge Platform</span>
          <span>Creado por Dr. Juan Pablo Aravena S.</span>
        </footer>
      </div>
    </div>
  );
}
