#!/usr/bin/env python3
"""Clasificador de referencia de la política de exclusión documental de CMF Academy.

Aplica las reglas de ``config/politica-exclusion.json`` a un conjunto de
elementos de origen (archivos de Google Drive o cargas directas) y decide, para
cada uno, si puede importarse (``allowed``), requiere revisión individual
(``review_required``), queda en cuarentena (``quarantined``) o se excluye
(``excluded``).

Lo usan el inventario documental y, desde la fase 2, el importador de Google
Drive y la carga de archivos. Solo usa la biblioteca estándar. La decisión se
toma con metadatos (nombre, tipo MIME, ruta y vecinos de carpeta); nunca hace
falta descargar el archivo. Para archivos sin extensión puede recibir, como
máximo, los primeros 132 bytes para reconocer la firma DICOM.

Documento canónico: docs/politica-de-exclusion-documental.md

Uso por línea de comandos (inventario en JSON Lines, un objeto por línea con
``name``, ``mime``, ``path`` como lista de carpetas y, opcionalmente, ``keys``):

    python3 scripts/politica_exclusion.py inventario.jsonl > decisiones.jsonl
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Sequence

RULES_PATH = Path(__file__).resolve().parent.parent / "config" / "politica-exclusion.json"

# Orden de severidad: coincide con el enum public.import_decision.
SEVERITY = {"allowed": 0, "review_required": 1, "quarantined": 2, "excluded": 3}

_EXT_RE = re.compile(r"\.([A-Za-z0-9]{1,10})$")
_COPY_SUFFIX_RE = re.compile(r"\s*\(\d+\)$")


def fingerprint(source: str, ref: str) -> str:
    """Huella estable de un elemento de origen.

    Permite reconocer un archivo excluido en importaciones futuras sin conservar
    su identificador de Drive. Los identificadores de Drive son aleatorios, por
    lo que la huella no permite reconstruirlos.
    """
    if not source or not ref:
        raise ValueError("source y ref son obligatorios")
    return hashlib.sha256(f"{source}:{ref}".encode("utf-8")).hexdigest()


def extension_of(name: str) -> str:
    if not name or name.startswith(".") and name.count(".") == 1:
        return ""
    match = _EXT_RE.search(name)
    return match.group(1).lower() if match else ""


def stem_of(name: str) -> str:
    ext = extension_of(name)
    stem = name[: -(len(ext) + 1)] if ext else name
    return _COPY_SUFFIX_RE.sub("", stem).strip()


@dataclass(frozen=True)
class Item:
    """Elemento de origen tal como lo ve el inventario o el importador."""

    name: str
    mime: str = ""
    path: tuple[str, ...] = ()
    keys: tuple[str, ...] | None = None
    patient_flag: bool = False
    header: bytes | None = None

    def folder_keys(self) -> tuple[str, ...]:
        if self.keys is not None:
            if len(self.keys) != len(self.path):
                raise ValueError("keys y path deben tener el mismo largo")
            return self.keys
        return tuple("\x1f".join(self.path[: i + 1]) for i in range(len(self.path)))


@dataclass
class Decision:
    decision: str
    rules: list[str]
    reason: str
    software: str | None = None
    case_root: str | None = None


@dataclass
class Context:
    """Lo que se sabe de las carpetas después de mirar todo el inventario."""

    case_roots: dict[str, str] = field(default_factory=dict)  # clave → motivo
    patient_roots: set[str] = field(default_factory=set)
    case_software: dict[str, str] = field(default_factory=dict)  # clave → programa


class Policy:
    def __init__(self, rules: dict):
        self.raw = rules
        self.version: str = rules["version"]
        self.rules = {r["codigo"]: r for r in rules["reglas"]}
        self.excluded_ext = {e["extension"]: e for e in rules["extensiones_excluidas"]}
        self.excluded_mime = {m["mime"]: m["regla"] for m in rules["tipos_mime_excluidos"]}
        self.excluded_names = {n["nombre"]: n["regla"] for n in rules["nombres_excluidos"]}
        system = rules["archivos_de_sistema"]
        self.system_names = set(system["nombres"])
        self.system_ext = set(system["extensiones"])
        self.system_mime = set(system["tipos_mime"])
        self.programs = [
            {**p, "_re": [re.compile(x, re.I) for x in p["patrones_carpeta"]]}
            for p in rules["programas"]
        ]
        compile_all = lambda key: [re.compile(x, re.I) for x in rules[key]]  # noqa: E731
        self.dicom_folder_re = compile_all("patrones_carpeta_dicom")
        self.patient_folder_re = compile_all("patrones_carpeta_paciente")
        self.study_re = compile_all("patrones_carpeta_estudio")
        self.dental_scan_re = compile_all("patrones_escaneo_dental")
        self.aux_re = compile_all("patrones_auxiliar")
        self.plan_name_re = compile_all("patrones_nombre_planificacion")
        self.camera_re = compile_all("patrones_camara")
        self.formats = {k: set(v) for k, v in rules["formatos"].items()}
        self.educational_folders = [f.lower() for f in rules["carpetas_modelos_educativos"]]
        self.header_signatures = rules["lectura_de_cabecera"]["firmas"]
        self.header_max = rules["lectura_de_cabecera"]["bytes_maximos"]
        self._validate()

    @classmethod
    def load(cls, path: Path | str = RULES_PATH) -> "Policy":
        with open(path, encoding="utf-8") as fh:
            return cls(json.load(fh))

    # ------------------------------------------------------------------ reglas

    def _validate(self) -> None:
        for code, rule in self.rules.items():
            if rule["decision"] not in SEVERITY:
                raise ValueError(f"Decisión desconocida en {code}")
            if not re.fullmatch(r"(EXC|CUA|REV)-[A-Z0-9-]+", code):
                raise ValueError(f"Código de regla no válido: {code}")
            prefix = {"EXC": "excluded", "CUA": "quarantined", "REV": "review_required"}[code[:3]]
            if rule["decision"] != prefix:
                raise ValueError(f"El prefijo de {code} no coincide con su decisión")
        referenced = (
            [e["regla"] for e in self.excluded_ext.values()]
            + list(self.excluded_mime.values())
            + list(self.excluded_names.values())
            + [p["regla_proyecto"] for p in self.programs]
            + [s["regla"] for s in self.header_signatures]
        )
        missing = sorted(set(referenced) - set(self.rules))
        if missing:
            raise ValueError(f"Reglas referenciadas que no existen: {missing}")

    # --------------------------------------------------------------- formatos

    def format_of(self, item: Item) -> str:
        ext = extension_of(item.name)
        mime = (item.mime or "").lower()
        if ext:
            for fmt, exts in self.formats.items():
                if not fmt.endswith("_mime") and ext in exts:
                    return fmt
        if mime in self.formats["presentacion_mime"]:
            return "presentacion"
        if mime in self.formats["documento_mime"] or mime in ("application/pdf", "text/plain"):
            return "documento"
        if mime.startswith("application/vnd.google-apps."):
            return "documento"
        for prefix, fmt in (("image/", "imagen"), ("video/", "video"), ("audio/", "audio")):
            if mime.startswith(prefix):
                return fmt
        if mime in ("text/xml", "application/xml"):
            return "configuracion"
        if "stl" in mime:
            return "modelo_3d"
        if "zip" in mime or "compressed" in mime:
            return "comprimido"
        return "desconocido"

    def _is_system(self, item: Item) -> bool:
        name = item.name.lower()
        return (
            name in self.system_names
            or extension_of(name) in self.system_ext
            or (item.mime or "").lower() in self.system_mime
        )

    def _is_dicom_file(self, item: Item) -> str | None:
        ext = extension_of(item.name)
        if ext in self.excluded_ext and self.excluded_ext[ext]["regla"] == "EXC-DICOM":
            return f"extensión .{ext}"
        if self.excluded_mime.get((item.mime or "").lower()) == "EXC-DICOM":
            return f"tipo MIME {item.mime}"
        if self.excluded_names.get(item.name.lower()) == "EXC-DICOM":
            return "índice DICOMDIR"
        if item.header is not None:
            head = item.header[: self.header_max]
            for sig in self.header_signatures:
                start = sig["desplazamiento"]
                expected = sig["bytes_ascii"].encode("ascii")
                if head[start : start + len(expected)] == expected and sig["regla"] == "EXC-DICOM":
                    return "firma DICM en la cabecera"
        return None

    def _project_rule(self, item: Item) -> tuple[str, str] | None:
        ext = extension_of(item.name)
        entry = self.excluded_ext.get(ext)
        if entry and entry["regla"] != "EXC-DICOM":
            note = "" if entry["evidencia"] == "verified" else ", formato declarado por el administrador"
            return entry["regla"], f"extensión .{ext} ({entry['programa']}{note})"
        rule = self.excluded_mime.get((item.mime or "").lower())
        if rule and rule != "EXC-DICOM":
            return rule, f"tipo MIME {item.mime}"
        return None

    def _matches(self, patterns, text: str) -> bool:
        return any(p.search(text) for p in patterns)

    def _program_for_folder(self, name: str) -> dict | None:
        for program in self.programs:
            if self._matches(program["_re"], name):
                return program
        return None

    def _program_name(self, rule_code: str) -> str | None:
        for program in self.programs:
            if program["regla_proyecto"] == rule_code:
                return program["nombre"]
        return None

    # --------------------------------------------------------------- contexto

    def analyze(self, items: Iterable[Item]) -> Context:
        """Primera pasada: identifica las carpetas de casos clínicos y de pacientes."""
        ctx = Context()

        def mark_case(key: str | None, why: str, software: str | None = None) -> None:
            if key is None:
                return
            ctx.case_roots.setdefault(key, why)
            if software and key not in ctx.case_software:
                ctx.case_software[key] = software

        for item in items:
            keys = item.folder_keys()
            parent = keys[-1] if keys else None
            for i, folder in enumerate(item.path):
                if self._matches(self.patient_folder_re, folder):
                    ctx.patient_roots.add(keys[i])
                    mark_case(keys[i], "carpeta de paciente")
                    break
            for i, folder in enumerate(item.path):
                if self._matches(self.dicom_folder_re, folder) or self._matches(self.study_re, folder):
                    mark_case(keys[i - 1] if i > 0 else None, "contiene un estudio DICOM o tomográfico")
            if self._is_dicom_file(item):
                in_dicom_folder = item.path and self._matches(self.dicom_folder_re, item.path[-1])
                root = keys[-2] if in_dicom_folder and len(keys) > 1 else parent
                mark_case(root, "contiene archivos DICOM")
            project = self._project_rule(item)
            if project:
                mark_case(parent, "contiene un proyecto nativo de planificación",
                          self._program_name(project[0]))
            fmt = self.format_of(item)
            if fmt in ("comprimido", "desconocido") and self._matches(self.study_re, stem_of(item.name)):
                mark_case(parent, "contiene un estudio tomográfico comprimido")
        return ctx

    # ---------------------------------------------------------- clasificación

    def classify(self, item: Item, ctx: Context | None = None) -> Decision:
        ctx = ctx or self.analyze([item])
        keys = item.folder_keys()
        fmt = self.format_of(item)
        name = item.name

        if self._is_system(item):
            return self._decide(["EXC-SISTEMA"], "archivo de sistema o acceso directo")

        codes: list[str] = []
        evidence: list[str] = []
        software: str | None = None

        dicom = self._is_dicom_file(item)
        dicom_folder = next(
            (f for f in item.path if self._matches(self.dicom_folder_re, f)), None
        )
        if dicom or dicom_folder:
            codes.append("EXC-DICOM")
            evidence.append(dicom or "ubicado en una carpeta DICOM")

        project = self._project_rule(item)
        if project:
            codes.append(project[0])
            evidence.append(project[1])
            software = self._program_name(project[0])

        patient_root = next((k for k in keys if k in ctx.patient_roots), None)
        if patient_root or item.patient_flag:
            codes.append("EXC-DATOS-PACIENTE")
            evidence.append("carpeta de paciente" if patient_root else "contiene identificadores de paciente")

        case_root = next((k for k in keys if k in ctx.case_roots), None)
        program = None
        for folder in item.path:
            program = self._program_for_folder(folder) or program
        if case_root and not software:
            software = ctx.case_software.get(case_root)
        if program and not software:
            software = program["nombre"]

        if codes:
            return self._decide(codes, "; ".join(evidence), software, case_root)

        is_aux = self._matches(self.aux_re, name)
        is_ips = program is not None and program["id"] == "ips"

        if case_root or program:
            where = (
                f"carpeta de caso clínico ({ctx.case_roots[case_root]})"
                if case_root
                else f"carpeta de {program['nombre']}"
            )
            if is_aux:
                return self._decide(["EXC-AUXILIAR-SOFTWARE"], f"respaldo, temporal o auxiliar en {where}",
                                    software, case_root)
            if case_root and is_ips and fmt not in ("documento", "presentacion"):
                return self._decide(["EXC-PROYECTO-IPS"], f"archivo de un caso de IPS CaseDesigner en {where}",
                                    software, case_root)
            if fmt == "modelo_3d":
                return self._decide(["EXC-MODELO-3D-CLINICO"], f"modelo 3D en {where}", software, case_root)
            if case_root:
                if fmt in ("documento", "presentacion"):
                    return self._decide(["CUA-DOCUMENTO-EN-CASO"], f"documento en {where}", software, case_root)
                return self._decide(["EXC-DERIVADO-CASO"], f"archivo no documental en {where}",
                                    software, case_root)
            if fmt in ("configuracion", "desconocido"):
                return self._decide(["EXC-AUXILIAR-SOFTWARE"], f"configuración o dependencia en {where}",
                                    software)
            return self._decide(["CUA-CARPETA-SOFTWARE"], f"material en {where} sin un caso identificado",
                                software)

        if fmt == "modelo_3d":
            folders = [f.lower() for f in item.path]
            if any(edu in folders for edu in self.educational_folders):
                return self._decide(["REV-MODELO-3D-EDUCATIVO"], "modelo 3D en carpeta declarada como educativa")
            if self._matches(self.plan_name_re, name) or self._matches(self.dental_scan_re, name):
                return self._decide(["CUA-MODELO-3D-PLANIFICACION"],
                                    "modelo 3D con nombre de planificación quirúrgica, fuera de un caso identificado")
            return self._decide(["CUA-MODELO-3D-SIN-PROCEDENCIA"], "modelo 3D sin procedencia académica acreditada")
        if fmt == "comprimido":
            return self._decide(["CUA-COMPRIMIDO"], "archivo comprimido de contenido desconocido")
        if fmt == "presentacion":
            return self._decide(["REV-PRESENTACION"], "presentación: revisión individual obligatoria")
        if fmt == "imagen" and self._matches(self.camera_re, name):
            return self._decide(["CUA-IMAGEN-CLINICA-POSIBLE"], "nombre de cámara o teléfono")
        if fmt in ("desconocido", "configuracion"):
            ext = extension_of(name)
            return self._decide(["CUA-FORMATO-DESCONOCIDO"],
                                f"formato no reconocido ({'.' + ext if ext else item.mime or 'sin extensión'})")
        return Decision("allowed", [], "sin reglas de exclusión aplicables")

    def classify_all(self, items: Sequence[Item]) -> list[Decision]:
        ctx = self.analyze(items)
        return [self.classify(item, ctx) for item in items]

    def _decide(self, codes: list[str], reason: str, software: str | None = None,
                case_root: str | None = None) -> Decision:
        unique = list(dict.fromkeys(codes))
        decision = max((self.rules[c]["decision"] for c in unique), key=SEVERITY.__getitem__)
        return Decision(decision, unique, reason, software, case_root)


def _main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    policy = Policy.load()
    items = []
    with open(argv[1], encoding="utf-8") as fh:
        for line in fh:
            if line.strip():
                obj = json.loads(line)
                items.append(Item(name=obj["name"], mime=obj.get("mime", ""),
                                  path=tuple(obj.get("path", [])),
                                  keys=tuple(obj["keys"]) if obj.get("keys") else None,
                                  patient_flag=bool(obj.get("patient_flag"))))
    for item, decision in zip(items, policy.classify_all(items)):
        print(json.dumps({"name": item.name, "decision": decision.decision, "rules": decision.rules,
                          "reason": decision.reason, "software": decision.software,
                          "policy_version": policy.version}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(_main(sys.argv))
