#!/usr/bin/env python3
"""Verifica que los enlaces relativos de los archivos Markdown apunten a archivos existentes.

Uso: python3 scripts/check_docs_links.py
Sale con código 1 si encuentra enlaces rotos. No consulta enlaces externos.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LINK = re.compile(r"!?\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
SKIP_DIRS = {".git", "node_modules"}


def markdown_files() -> list[Path]:
    return [
        p for p in ROOT.rglob("*.md")
        if not any(part in SKIP_DIRS for part in p.relative_to(ROOT).parts)
    ]


def strip_code(text: str) -> str:
    """Elimina bloques de código para no validar ejemplos."""
    text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    return re.sub(r"`[^`\n]*`", "", text)


def main() -> int:
    broken: list[str] = []
    checked = 0
    for md in markdown_files():
        for target in LINK.findall(strip_code(md.read_text(encoding="utf-8"))):
            if re.match(r"^[a-z][a-z0-9+.-]*:", target) or target.startswith("#"):
                continue
            path = target.split("#", 1)[0]
            if not path:
                continue
            checked += 1
            if not (md.parent / path).resolve().exists():
                broken.append(f"{md.relative_to(ROOT)} → {target}")
    if broken:
        print("Enlaces rotos:")
        for item in broken:
            print(f"  {item}")
        return 1
    print(f"Enlaces relativos verificados: {checked}, sin errores.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
