import {
  THEME_BOOT_SCRIPT,
  THEME_STORAGE_KEY,
  applyThemeMode,
  parseThemeMode,
  readStoredThemeMode,
  storeThemeMode,
} from "./theme";

describe("tema", () => {
  it("acepta solo modos conocidos", () => {
    expect(parseThemeMode("dark")).toBe("dark");
    expect(parseThemeMode("light")).toBe("light");
    expect(parseThemeMode("azul")).toBe("system");
    expect(parseThemeMode(null)).toBe("system");
  });

  it("'system' quita el atributo y los demás lo fijan", () => {
    const root = document.createElement("html");
    applyThemeMode(root, "dark");
    expect(root.getAttribute("data-theme")).toBe("dark");
    applyThemeMode(root, "system");
    expect(root.hasAttribute("data-theme")).toBe(false);
  });

  it("guarda y lee la preferencia, y tolera un almacenamiento bloqueado", () => {
    const mem = new Map<string, string>();
    const storage = {
      getItem: (k: string) => mem.get(k) ?? null,
      setItem: (k: string, v: string) => void mem.set(k, v),
    };
    storeThemeMode(storage, "light");
    expect(mem.get(THEME_STORAGE_KEY)).toBe("light");
    expect(readStoredThemeMode(storage)).toBe("light");

    const blocked = {
      getItem: () => {
        throw new Error("bloqueado");
      },
      setItem: () => {
        throw new Error("bloqueado");
      },
    };
    expect(readStoredThemeMode(blocked)).toBe("system");
    expect(() => storeThemeMode(blocked, "dark")).not.toThrow();
    expect(readStoredThemeMode(undefined)).toBe("system");
  });

  it("el script de arranque aplica el tema guardado antes de pintar", () => {
    localStorage.setItem(THEME_STORAGE_KEY, "dark");
    document.documentElement.removeAttribute("data-theme");
    new Function(THEME_BOOT_SCRIPT)();
    expect(document.documentElement.getAttribute("data-theme")).toBe("dark");
    localStorage.setItem(THEME_STORAGE_KEY, "otro");
    document.documentElement.removeAttribute("data-theme");
    new Function(THEME_BOOT_SCRIPT)();
    expect(document.documentElement.hasAttribute("data-theme")).toBe(false);
    localStorage.clear();
  });
});
