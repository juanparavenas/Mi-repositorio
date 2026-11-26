"""Pruebas del clasificador de la política de exclusión documental.

Ejecutar desde la raíz del repositorio:

    python3 -m unittest discover -s scripts/tests -v

Los nombres de carpetas y archivos son ficticios.
"""

import json
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

from politica_exclusion import (  # noqa: E402
    RULES_PATH,
    SEVERITY,
    Item,
    Policy,
    extension_of,
    fingerprint,
)

BASE = ("Mi unidad", "Docencia", "CMF")


def item(name, *folders, mime="", **kw):
    return Item(name=name, mime=mime, path=BASE + tuple(folders), **kw)


class PolicyTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.policy = Policy.load()

    def decide(self, items):
        return {i.name: d for i, d in zip(items, self.policy.classify_all(items))}

    def one(self, it):
        return self.policy.classify(it)


class ReglasTest(PolicyTestCase):
    def test_codigos_y_decisiones_son_coherentes(self):
        for code, rule in self.policy.rules.items():
            self.assertIn(rule["decision"], SEVERITY)
            self.assertIsInstance(rule["liberable"], bool, code)
            self.assertTrue(rule["descripcion"], code)

    def test_exclusiones_duras_no_son_liberables(self):
        for code in ("EXC-DICOM", "EXC-PROYECTO-PROPLAN", "EXC-PROYECTO-MIMICS", "EXC-PROYECTO-3MATIC",
                     "EXC-PROYECTO-IPS", "EXC-PROYECTO-DECLARADO", "EXC-DATOS-PACIENTE"):
            self.assertFalse(self.policy.rules[code]["liberable"], code)

    def test_los_modelos_clinicos_se_liberan_solo_con_autorizacion(self):
        rule = self.policy.rules["EXC-MODELO-3D-CLINICO"]
        self.assertEqual(rule["decision"], "excluded")
        self.assertTrue(rule["liberable"])

    def test_extensiones_minimas_de_la_politica(self):
        for ext in ("dcm", "sppc", "sgc", "mcs", "mxp"):
            self.assertIn(ext, self.policy.excluded_ext)

    def test_no_se_inventan_extensiones_para_ips(self):
        ips_ext = [e for e in self.policy.excluded_ext.values() if e["regla"] == "EXC-PROYECTO-IPS"]
        self.assertEqual(ips_ext, [], "IPS CaseDesigner se identifica por estructura, no por extensión")

    def test_formatos_no_verificados_quedan_declarados(self):
        for ext in ("mxp", "sgc"):
            self.assertEqual(self.policy.excluded_ext[ext]["evidencia"], "declared")

    def test_regla_referenciada_inexistente_se_rechaza(self):
        data = json.loads(RULES_PATH.read_text(encoding="utf-8"))
        data["extensiones_excluidas"].append(
            {"extension": "zzz", "regla": "EXC-NO-EXISTE", "programa": "x", "evidencia": "declared", "fuente": "x"})
        with self.assertRaises(ValueError):
            Policy(data)

    def test_codigos_sincronizados_con_la_migracion(self):
        sql = (ROOT / "supabase" / "migrations" / "20261125000800_exclusion_policy.sql").read_text(encoding="utf-8")
        seeded = set(re.findall(r"\('((?:EXC|CUA|REV)-[A-Z0-9-]+)',\s*'(\w+)',\s*(true|false)", sql))
        expected = {(c, r["decision"], str(r["liberable"]).lower()) for c, r in self.policy.rules.items()}
        self.assertEqual(seeded, expected, "las reglas de la base deben coincidir con config/politica-exclusion.json")
        seeded_ext = set(re.findall(r"\('([a-z0-9]+)',\s*'((?:EXC)-[A-Z0-9-]+)',\s*'[^']*',\s*'(verified|declared)'",
                                    sql))
        expected_ext = {(e, v["regla"], v["evidencia"]) for e, v in self.policy.excluded_ext.items()}
        self.assertEqual(seeded_ext, expected_ext, "las extensiones bloqueadas deben coincidir")


class UtilidadesTest(unittest.TestCase):
    def test_extension(self):
        self.assertEqual(extension_of("Plan final.SPPC"), "sppc")
        self.assertEqual(extension_of(".DS_Store"), "")
        self.assertEqual(extension_of("DICOMDIR"), "")
        self.assertEqual(extension_of("articulo.v2.pdf"), "pdf")

    def test_huella(self):
        a = fingerprint("google_drive", "abc123")
        self.assertRegex(a, r"^[0-9a-f]{64}$")
        self.assertEqual(a, fingerprint("google_drive", "abc123"))
        self.assertNotEqual(a, fingerprint("upload", "abc123"))
        with self.assertRaises(ValueError):
            fingerprint("google_drive", "")


class ExclusionesDurasTest(PolicyTestCase):
    def test_proyectos_nativos(self):
        casos = {
            "Avance maxilar.sppc": "EXC-PROYECTO-PROPLAN",
            "Segmentacion.MCS": "EXC-PROYECTO-MIMICS",
            "Diseno guia.mxp": "EXC-PROYECTO-3MATIC",
            "caso.sgc": "EXC-PROYECTO-DECLARADO",
        }
        for name, code in casos.items():
            d = self.one(item(name, "Cursos"))
            self.assertEqual(d.decision, "excluded", name)
            self.assertIn(code, d.rules, name)

    def test_proyecto_por_tipo_mime_sin_extension(self):
        d = self.one(item("Planificacion", "Cursos", mime="application/sppc"))
        self.assertIn("EXC-PROYECTO-PROPLAN", d.rules)

    def test_dicom_por_extension_mime_nombre_cabecera_y_carpeta(self):
        header = b"\x00" * 128 + b"DICM" + b"\x00" * 10
        casos = [
            item("IM0001.dcm", "Caso"),
            item("IM0002", "Caso", mime="application/dicom"),
            item("DICOMDIR", "Caso"),
            item("IM0003", "Caso", mime="application/octet-stream", header=header),
            item("IM0004", "Caso", "DICOM", mime="application/octet-stream"),
        ]
        for it in casos:
            d = self.one(it)
            self.assertEqual(d.decision, "excluded", it.name)
            self.assertIn("EXC-DICOM", d.rules, it.name)

    def test_cabecera_sin_firma_no_es_dicom(self):
        d = self.one(item("datos", "Varios", mime="application/octet-stream", header=b"\x00" * 140))
        self.assertNotIn("EXC-DICOM", d.rules)
        self.assertEqual(d.decision, "quarantined")

    def test_archivos_de_sistema(self):
        for it in (item(".DS_Store", "x"), item("Thumbs.db", "x"), item("clase.lnk", "x"),
                   item("Atajo", "x", mime="application/vnd.google-apps.shortcut")):
            self.assertEqual(self.one(it).rules, ["EXC-SISTEMA"], it.name)

    def test_carpeta_de_paciente_excluye_todo_su_contenido(self):
        d = self.one(item("IMG_0001.JPG", "Implantologia", "Pacientes", "Caso A"))
        self.assertIn("EXC-DATOS-PACIENTE", d.rules)
        d = self.one(item("informe.pdf", "Rotaciones", "Protocolos y epicrisis"))
        self.assertIn("EXC-DATOS-PACIENTE", d.rules)

    def test_marca_de_identificadores(self):
        d = self.one(item("resumen.docx", "Clases", patient_flag=True))
        self.assertEqual(d.decision, "excluded")
        self.assertIn("EXC-DATOS-PACIENTE", d.rules)


class CasoClinicoTest(PolicyTestCase):
    """Reproduce la estructura real encontrada en el inventario: un caso con
    proyecto de ProPlan, segmentación de Mimics, DICOM y modelos STL."""

    def setUp(self):
        caso = ("Residencia", "III", "Hospital X")
        self.items = [
            item("3. Canteo + avance 5 mm.sppc", *caso, mime="application/sppc"),
            item("2. Segmentacion inicial.mcs", *caso, mime="application/mcs"),
            item("IM0001", *caso, "DICOM", mime="application/octet-stream"),
            item("Maxilar intraoral.stl", *caso, "STL"),
            item("Craneo sin maxilar.stl", *caso, "STL", "STL movimientos finales"),
            item("captura.png", *caso),
            item("informe planificacion.pdf", *caso),
            item("plan.sppc.bak", *caso),
            item("Revision sistematica.pdf", "Residencia", "III", "Articulos"),
        ]
        self.d = self.decide(self.items)

    def test_proyectos_y_dicom(self):
        self.assertIn("EXC-PROYECTO-PROPLAN", self.d["3. Canteo + avance 5 mm.sppc"].rules)
        self.assertIn("EXC-PROYECTO-MIMICS", self.d["2. Segmentacion inicial.mcs"].rules)
        self.assertIn("EXC-DICOM", self.d["IM0001"].rules)

    def test_modelos_3d_del_caso_quedan_excluidos(self):
        for name in ("Maxilar intraoral.stl", "Craneo sin maxilar.stl"):
            self.assertEqual(self.d[name].rules, ["EXC-MODELO-3D-CLINICO"], name)
            self.assertEqual(self.d[name].decision, "excluded")
            self.assertEqual(self.d[name].software, "ProPlan CMF")

    def test_exportaciones_respaldos_y_documentos_del_caso(self):
        self.assertEqual(self.d["captura.png"].rules, ["EXC-DERIVADO-CASO"])
        self.assertEqual(self.d["plan.sppc.bak"].rules, ["EXC-AUXILIAR-SOFTWARE"])
        self.assertEqual(self.d["informe planificacion.pdf"].rules, ["CUA-DOCUMENTO-EN-CASO"])
        self.assertEqual(self.d["informe planificacion.pdf"].decision, "quarantined")

    def test_carpeta_hermana_no_se_contamina(self):
        self.assertEqual(self.d["Revision sistematica.pdf"].decision, "allowed")

    def test_estudio_tomografico_comprimido_marca_el_caso(self):
        d = self.decide([
            item("TC (1).zip", "Residencia", "II", "Caso B", mime="application/x-zip-compressed"),
            item("foto.jpg", "Residencia", "II", "Caso B"),
        ])
        self.assertEqual(d["TC (1).zip"].rules, ["EXC-DERIVADO-CASO"])
        self.assertEqual(d["foto.jpg"].rules, ["EXC-DERIVADO-CASO"])


class CarpetasDeProgramasTest(PolicyTestCase):
    def test_configuracion_interna_de_proplan(self):
        d = self.one(item("Ricketts.xml", "Proplan CMF", "Cefalometria", "Static", mime="text/xml"))
        self.assertEqual(d.rules, ["EXC-AUXILIAR-SOFTWARE"])
        self.assertEqual(d.software, "ProPlan CMF")

    def test_clases_en_carpeta_de_programa_quedan_en_cuarentena(self):
        d = self.one(item("Clase oclusion.mp4", "Proplan CMF", "Clases", mime="video/mp4"))
        self.assertEqual(d.rules, ["CUA-CARPETA-SOFTWARE"])

    def test_autoguardado_de_mimics(self):
        d = self.one(item("proyecto_autosave.tmp", "Mimics", "Trabajos"))
        self.assertEqual(d.rules, ["EXC-AUXILIAR-SOFTWARE"])
        self.assertEqual(d.software, "Mimics / Mimics Medical")

    def test_ips_por_estructura_sin_extension_propia(self):
        caso = ("Planificacion", "IPS CaseDesigner", "Caso 2024-03")
        d = self.decide([
            item("IM0001", *caso, "DICOM", mime="application/octet-stream"),
            item("Escaneo superior.stl", *caso),
            item("Ferula intermedia.stl", *caso),
            item("caso.dat", *caso),
            item("Informe.pdf", *caso),
        ])
        self.assertEqual(d["Escaneo superior.stl"].rules, ["EXC-PROYECTO-IPS"])
        self.assertEqual(d["Ferula intermedia.stl"].rules, ["EXC-PROYECTO-IPS"])
        self.assertEqual(d["caso.dat"].rules, ["EXC-PROYECTO-IPS"])
        self.assertEqual(d["Informe.pdf"].rules, ["CUA-DOCUMENTO-EN-CASO"])
        self.assertEqual(d["Escaneo superior.stl"].software, "IPS CaseDesigner")

    def test_manual_del_programa_en_una_biblioteca_no_se_excluye(self):
        d = self.one(item("IFU_IPS_CaseDesigner_2.5_es.pdf", "Bibliografia", "Libros", mime="application/pdf"))
        self.assertEqual(d.decision, "allowed")


class TiposMimeYCarpetasDePacienteTest(PolicyTestCase):
    """Regresiones encontradas al aplicar la política al inventario real (v1.1.1)."""

    def test_presentacion_sin_extension_se_reconoce_por_mime(self):
        mime = "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        d = self.one(item("Planilla PC ORT", "CMF UCH", mime=mime))
        self.assertEqual(d.rules, ["EXC-PRESENTACION"])
        for m in ("application/vnd.ms-powerpoint", "application/vnd.apple.keynote",
                  "application/vnd.oasis.opendocument.presentation"):
            self.assertEqual(self.one(item("Clase", "X", mime=m)).rules, ["EXC-PRESENTACION"], m)

    def test_documento_office_sin_extension_se_permite(self):
        for m in ("application/vnd.openxmlformats-officedocument.wordprocessingml.document", "application/msword",
                  "application/epub+zip"):
            self.assertEqual(self.one(item("Resumen", "Clases", mime=m)).decision, "allowed", m)

    def test_carpetas_de_paciente_abreviadas(self):
        for folders in (("Trauma", "Fracturas mandibulares", "PCTE 1 - Parasinfisis"),
                        ("CMF UCH", "II", "CC. Nombre Apellido", "23-08-2024"),
                        ("Cirugía Bucal", "Caso clínico", "Fotos"),
                        ("Docencia", "Casos clínicos")):
            d = self.one(item("IMG_0001.JPG", *folders))
            self.assertIn("EXC-DATOS-PACIENTE", d.rules, folders)

    def test_palabras_parecidas_no_son_carpetas_de_paciente(self):
        for folders in (("Concepto", "Cirugía"), ("Accidentes",), ("CCMF",), ("Discusión de casos",)):
            self.assertEqual(self.one(item("articulo.pdf", *folders)).decision, "allowed", folders)


class DuplicadosTest(PolicyTestCase):
    def test_se_conserva_una_sola_copia(self):
        items = [item("Borba.pdf", "Ortognatica", "Abordajes"), item("Borba copia.pdf", "Ortognatica", "Secuencia"),
                 item("Otro.pdf", "Ortognatica")]
        recs = [{"name": "Borba.pdf", "doi": "10.1016/J.IJOM.2015.10.008", "folder_depth": 5, "size": 10},
                {"name": "Borba copia.pdf", "doi": "10.1016/j.ijom.2015.10.008", "folder_depth": 5, "size": 10},
                {"name": "Otro.pdf", "doi": "10.1/otro", "folder_depth": 4, "size": 5}]
        out = self.policy.mark_duplicates(recs, self.policy.classify_all(items))
        self.assertEqual(out[0].decision, "allowed")
        self.assertEqual(out[1].rules, ["EXC-DUPLICADO"])
        self.assertEqual(out[1].duplicate_of, 0)
        self.assertEqual(out[2].decision, "allowed")

    def test_grupos_por_sha_doi_o_pmid_encadenados(self):
        items = [item(f"a{i}.pdf", "X") for i in range(3)]
        recs = [{"name": "a0", "sha256": "aa", "size": 1}, {"name": "a1", "sha256": "aa", "pmid": "9", "size": 3},
                {"name": "a2", "pmid": "9", "size": 2}]
        out = self.policy.mark_duplicates(recs, self.policy.classify_all(items))
        self.assertEqual([d.decision for d in out], ["excluded", "allowed", "excluded"])

    def test_lo_excluido_no_compite(self):
        items = [item("Clase.pptx", "X"), item("articulo.pdf", "X")]
        recs = [{"name": "Clase.pptx", "doi": "10.1/x"}, {"name": "articulo.pdf", "doi": "10.1/x"}]
        out = self.policy.mark_duplicates(recs, self.policy.classify_all(items))
        self.assertEqual(out[0].rules, ["EXC-PRESENTACION"])
        self.assertEqual(out[1].decision, "allowed")


class ModelosYPresentacionesTest(PolicyTestCase):
    def test_stl_academico_no_se_excluye_automaticamente(self):
        d = self.one(item("Craneo anatomico.stl", "Anatomia"))
        self.assertEqual(d.decision, "quarantined")
        self.assertEqual(d.rules, ["CUA-MODELO-3D-SIN-PROCEDENCIA"])
        self.assertNotEqual(d.decision, "excluded")

    def test_obj_con_nombre_de_planificacion(self):
        d = self.one(item("Mandibula cortada final.obj", "Varios"))
        self.assertEqual(d.rules, ["CUA-MODELO-3D-PLANIFICACION"])

    def test_carpeta_educativa_declarada(self):
        data = json.loads(RULES_PATH.read_text(encoding="utf-8"))
        data["carpetas_modelos_educativos"] = ["Modelos anatomicos educativos"]
        policy = Policy(data)
        d = policy.classify(item("Craneo.stl", "Modelos anatomicos educativos"))
        self.assertEqual(d.rules, ["REV-MODELO-3D-EDUCATIVO"])
        self.assertEqual(d.decision, "review_required")

    def test_presentaciones_no_se_importan(self):
        for it in (item("Clase trauma.pptx", "Clases"), item("Clase.ppt", "Clases"), item("Charla.key", "Clases"),
                   item("Seminario", "Clases", mime="application/vnd.google-apps.presentation"),
                   item("ATM + CORT.pptx", "Prótesis articular")):
            d = self.one(it)
            self.assertEqual(d.rules, ["EXC-PRESENTACION"], it.name)
            self.assertEqual(d.decision, "excluded")
        self.assertTrue(self.policy.rules["EXC-PRESENTACION"]["liberable"])

    def test_presentacion_en_caso_clinico_tambien_se_excluye(self):
        d = self.decide([item("plan.sppc", "Caso X"), item("Caso.pptx", "Caso X")])
        self.assertEqual(d["Caso.pptx"].rules, ["EXC-PRESENTACION"])

    def test_libros_y_capitulos_se_pueden_importar(self):
        for it in (item("2005. Meneghini. Analisis facial clinico.pdf", "Libros"),
                   item("Capitulo 14.pdf", "Libros"),
                   item("Fundamentos.epub", "Libros")):
            self.assertEqual(self.one(it).decision, "allowed", it.name)

    def test_comprimido_y_formato_desconocido(self):
        self.assertEqual(self.one(item("Libro.zip", "Libros")).rules, ["CUA-COMPRIMIDO"])
        self.assertEqual(self.one(item("datos.xyz", "Varios")).rules, ["CUA-FORMATO-DESCONOCIDO"])

    def test_posible_fotografia_clinica(self):
        self.assertEqual(self.one(item("IMG_8581.JPG", "Clases")).rules, ["CUA-IMAGEN-CLINICA-POSIBLE"])
        self.assertEqual(self.one(item("esquema-lefort.png", "Clases")).decision, "allowed")

    def test_documentos_academicos_siguen_el_flujo_normal(self):
        for it in (item("articulo.pdf", "Ortognatica"), item("Apunte", "Clases",
                                                              mime="application/vnd.google-apps.document")):
            self.assertEqual(self.one(it).decision, "allowed", it.name)


if __name__ == "__main__":
    unittest.main()
