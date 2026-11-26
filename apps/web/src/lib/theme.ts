/**
 * Tema de la interfaz: "system" sigue a prefers-color-scheme; "light" y "dark"
 * lo fijan con el atributo data-theme de <html>. La elección se guarda en
 * localStorage cuando está disponible.
 */
export type ThemeMode = "system" | "light" | "dark";

export const THEME_STORAGE_KEY = "cmf-theme";
export const THEME_MODES: readonly ThemeMode[] = ["system", "light", "dark"];

export function parseThemeMode(value: unknown): ThemeMode {
  return value === "light" || value === "dark" ? value : "system";
}

/** Aplica el modo al elemento raíz. */
export function applyThemeMode(root: HTMLElement, mode: ThemeMode): void {
  if (mode === "system") root.removeAttribute("data-theme");
  else root.setAttribute("data-theme", mode);
}

export function readStoredThemeMode(storage: Pick<Storage, "getItem"> | undefined): ThemeMode {
  try {
    return parseThemeMode(storage?.getItem(THEME_STORAGE_KEY));
  } catch {
    return "system";
  }
}

export function storeThemeMode(storage: Pick<Storage, "setItem"> | undefined, mode: ThemeMode): void {
  try {
    storage?.setItem(THEME_STORAGE_KEY, mode);
  } catch {
    /* Sin almacenamiento disponible: la elección dura solo esta visita. */
  }
}

/**
 * Script que se ejecuta en <head> antes de pintar, para evitar el destello del
 * tema equivocado. Debe ser autónomo: no puede importar nada.
 */
export const THEME_BOOT_SCRIPT = `(function(){try{var t=localStorage.getItem("${THEME_STORAGE_KEY}");if(t==="light"||t==="dark")document.documentElement.setAttribute("data-theme",t);}catch(e){}})();`;
