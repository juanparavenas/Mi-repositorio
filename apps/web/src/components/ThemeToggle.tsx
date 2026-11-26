"use client";

import { useEffect, useState } from "react";

import {
  THEME_MODES,
  applyThemeMode,
  readStoredThemeMode,
  storeThemeMode,
  type ThemeMode,
} from "@/lib/theme";

import { Icon } from "./Icon";

const LABELS: Record<ThemeMode, { text: string; title: string; icon: "monitor" | "sun" | "moon" }> = {
  system: { text: "Sistema", title: "Seguir al sistema", icon: "monitor" },
  light: { text: "Claro", title: "Modo claro", icon: "sun" },
  dark: { text: "Oscuro", title: "Modo oscuro", icon: "moon" },
};

function browserStorage(): Storage | undefined {
  try {
    return window.localStorage;
  } catch {
    return undefined;
  }
}

/** Selector Sistema / Claro / Oscuro. El script de <head> ya aplicó el tema guardado. */
export function ThemeToggle() {
  const [mode, setMode] = useState<ThemeMode | null>(null);

  useEffect(() => {
    // Se lee después de montar para que el HTML del servidor y del cliente coincidan.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setMode(readStoredThemeMode(browserStorage()));
  }, []);

  function choose(next: ThemeMode) {
    setMode(next);
    storeThemeMode(browserStorage(), next);
    applyThemeMode(document.documentElement, next);
  }

  return (
    <div className="segmented" role="group" aria-label="Tema">
      {THEME_MODES.map((m) => (
        <button
          key={m}
          type="button"
          title={LABELS[m].title}
          aria-label={LABELS[m].title}
          aria-pressed={mode === null ? undefined : mode === m}
          onClick={() => choose(m)}
          data-theme-option={m}
        >
          <Icon name={LABELS[m].icon} />
          <span className="hide-sm">{LABELS[m].text}</span>
        </button>
      ))}
    </div>
  );
}
