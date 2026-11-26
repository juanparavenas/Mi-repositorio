#!/usr/bin/env python3
"""Verifica el contraste WCAG 2.2 de los tokens de diseño en los cuatro temas.

Lee docs/diseno/tokens.css, arma los temas claro y oscuro (acento petróleo) y
comprueba cada par de texto y fondo que usa el sistema de diseño:

    · texto normal ≥ 4,5:1 (AA)
    · bordes de controles e indicador de foco ≥ 3:1 (AA, componentes no textuales)

También exige que el modo oscuro por preferencia del sistema y el modo oscuro
elegido a mano definan exactamente los mismos valores.

Uso:  python3 scripts/check_contrast.py          (sale con 1 si algo falla)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

TOKENS = Path(__file__).resolve().parent.parent / "docs" / "diseno" / "tokens.css"

TEXT = 4.5
UI = 3.0

BACKGROUNDS = ("paper", "surface", "raised")

PAIRS: list[tuple[str, str, float]] = []
for bg in BACKGROUNDS + ("sunken",):
    PAIRS += [("ink", bg, TEXT), ("ink-2", bg, TEXT)]
for bg in BACKGROUNDS:
    PAIRS += [("ink-3", bg, TEXT), ("accent", bg, TEXT), ("accent-hover", bg, TEXT)]
PAIRS += [
    ("accent", "accent-tint", TEXT),
    ("ink", "accent-tint", TEXT),
    ("on-accent", "accent", TEXT),
    ("on-accent", "accent-hover", TEXT),
    ("ink-3", "raised", UI),        # borde de campos de formulario
    ("focus", "paper", UI),          # anillo de foco
    ("focus", "raised", UI),
]
for state in ("ok", "warn", "critical", "info"):
    PAIRS += [(state, f"{state}-tint", TEXT), (state, "raised", TEXT), (state, "paper", TEXT)]


def _blocks(css: str) -> dict[str, dict[str, str]]:
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    found: dict[str, dict[str, str]] = {}
    for selector, body in re.findall(r"([^{}]+)\{([^{}]*)\}", css):
        decls = dict(re.findall(r"--color-([\w-]+)\s*:\s*([^;]+);", body))
        if decls:
            found[" ".join(selector.split())] = {k: v.strip() for k, v in decls.items()}
    return found


def load_themes(path: Path = TOKENS) -> dict[str, dict[str, str]]:
    b = _blocks(path.read_text(encoding="utf-8"))
    base = b[":root"]
    media_dark = b[':root:not([data-theme="light"])']
    dark = b[':root[data-theme="dark"]']
    if media_dark != dark:
        raise ValueError("El modo oscuro del sistema y el elegido a mano no definen los mismos colores")
    themes = {
        "claro": dict(base),
        "oscuro": {**base, **dark},
    }
    for t in themes.values():
        for k, v in list(t.items()):
            m = re.fullmatch(r"var\(--color-([\w-]+)\)", v)
            if m:
                t[k] = t[m.group(1)]
    return themes


def _rgb(value: str) -> tuple[float, float, float]:
    m = re.fullmatch(r"#([0-9a-fA-F]{6})", value)
    if not m:
        raise ValueError(f"Color no comparable: {value}")
    h = m.group(1)
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))  # type: ignore[return-value]


def luminance(value: str) -> float:
    def lin(c: float) -> float:
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(c) for c in _rgb(value))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(fg: str, bg: str) -> float:
    a, b = luminance(fg), luminance(bg)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def check(path: Path = TOKENS) -> list[str]:
    failures = []
    for name, theme in load_themes(path).items():
        for fg, bg, minimum in PAIRS:
            r = ratio(theme[fg], theme[bg])
            if r < minimum:
                failures.append(f"{name}: --color-{fg} sobre --color-{bg} = {r:.2f}:1 (mínimo {minimum}:1)")
    return failures


def report(path: Path = TOKENS) -> str:
    lines = []
    for name, theme in load_themes(path).items():
        worst = min((ratio(theme[f], theme[b]) / m, f, b, ratio(theme[f], theme[b])) for f, b, m in PAIRS)
        lines.append(f"{name}: {len(PAIRS)} pares; el más ajustado es --color-{worst[1]} sobre "
                     f"--color-{worst[2]} ({worst[3]:.2f}:1)")
    return "\n".join(lines)


if __name__ == "__main__":
    problems = check()
    print(report())
    if problems:
        print("\n".join(["", "Contraste insuficiente:"] + problems))
        sys.exit(1)
    print("Contraste verificado en modo claro y oscuro.")
