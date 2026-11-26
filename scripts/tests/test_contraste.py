"""Pruebas de contraste de los tokens de diseño (modo claro y oscuro, acento petróleo)."""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from check_contrast import TOKENS, check, load_themes, ratio  # noqa: E402


class ContrasteTest(unittest.TestCase):
    def test_claro_y_oscuro_cumplen_aa(self):
        self.assertEqual(check(), [])

    def test_hay_dos_temas_y_el_oscuro_es_oscuro(self):
        themes = load_themes()
        self.assertEqual(set(themes), {"claro", "oscuro"})
        for name, t in themes.items():
            light_paper = ratio(t["paper"], "#000000") > ratio(t["paper"], "#FFFFFF")
            self.assertEqual(light_paper, name.startswith("claro"), name)

    def test_texto_sobre_acento_cambia_en_modo_oscuro(self):
        t = load_themes()
        self.assertEqual(t["claro"]["accent"].upper(), "#0F5257")
        self.assertEqual(t["claro"]["on-accent"].upper(), "#FFFFFF")
        self.assertNotEqual(t["oscuro"]["on-accent"].upper(), "#FFFFFF")

    def test_detecta_un_color_insuficiente(self):
        css = TOKENS.read_text(encoding="utf-8").replace("--color-ink-3: #686B72;", "--color-ink-3: #B0B0B0;", 1)
        with tempfile.NamedTemporaryFile("w", suffix=".css", delete=False, encoding="utf-8") as fh:
            fh.write(css)
        try:
            self.assertTrue(any("ink-3" in f for f in check(Path(fh.name))))
        finally:
            Path(fh.name).unlink()

    def test_detecta_modo_oscuro_desincronizado(self):
        css = TOKENS.read_text(encoding="utf-8")
        i = css.index(':root[data-theme="dark"] {')
        css = css[:i] + css[i:].replace("--color-ink: #ECEAE4;", "--color-ink: #FFFFFF;", 1)
        with tempfile.NamedTemporaryFile("w", suffix=".css", delete=False, encoding="utf-8") as fh:
            fh.write(css)
        try:
            with self.assertRaises(ValueError):
                load_themes(Path(fh.name))
        finally:
            Path(fh.name).unlink()

    def test_ratio_conocido(self):
        self.assertAlmostEqual(ratio("#000000", "#FFFFFF"), 21.0, places=2)


if __name__ == "__main__":
    unittest.main()
