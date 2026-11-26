import { Icon } from "./Icon";

/** Búsqueda global. Envía a /buscar; el atajo ⌘K / Ctrl+K lo gestiona AppShell. */
export function SearchBox({ large = false, placeholder }: { large?: boolean; placeholder?: string }) {
  return (
    <form action="/buscar" role="search" className={large ? "search search-lg" : "search"}>
      <Icon name="search" small={!large} />
      <label className="sr-only" htmlFor={large ? "q-hero" : "q-global"}>
        Buscar en CMF Academy
      </label>
      <input
        id={large ? "q-hero" : "q-global"}
        name="q"
        type="search"
        autoComplete="off"
        placeholder={placeholder ?? "Buscar temas, artículos, autores…"}
        data-global-search={large ? undefined : true}
      />
      {large ? null : (
        <span className="kbd" aria-hidden="true">
          ⌘K
        </span>
      )}
    </form>
  );
}
