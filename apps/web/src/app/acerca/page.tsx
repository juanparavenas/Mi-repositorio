import type { Metadata } from "next";
import Link from "next/link";

import { Icon } from "@/components/Icon";
import { PageHeader } from "@/components/PageHeader";

export const metadata: Metadata = { title: "Acerca de" };

const PRINCIPLES = [
  {
    title: "Rigor antes que velocidad",
    text: "Las síntesis las revisa un editor antes de publicarse. Lo redactado por la IA queda en borrador hasta su aprobación.",
  },
  {
    title: "Solo lo que se puede citar",
    text: "Cada afirmación del asistente lleva su fuente. Si la biblioteca no tiene respaldo suficiente, lo dice en vez de responder.",
  },
  {
    title: "Derechos de autor respetados",
    text: "El material de terceros conserva sus derechos y se presenta con atribución y enlace a la fuente original. Lo protegido no se distribuye.",
  },
  {
    title: "Privacidad de los pacientes",
    text: "No se importan estudios DICOM, proyectos de planificación quirúrgica ni datos de pacientes. Las imágenes clínicas exigen consentimiento y anonimización.",
  },
  {
    title: "Herramienta educativa",
    text: "CMF Academy apoya el estudio y la docencia. No reemplaza el juicio clínico ni la evaluación de cada paciente.",
  },
];

export default function AboutPage() {
  return (
    <>
      <PageHeader
        title="Acerca de CMF Academy"
        lede="Una biblioteca científica pública y una plataforma académica colaborativa de Cirugía Oral y Maxilofacial."
        crumbs={[{ href: "/", label: "Inicio" }, { label: "Acerca de" }]}
      />
      <div className="split">
        <div className="stack">
          <div className="prose">
            <p>
              CMF Academy organiza el conocimiento de la especialidad como un árbol de temas de profundidad
              libre. Cada tema reúne una síntesis académica revisada, la literatura científica de PubMed,
              documentos, material multimedia y un asistente de inteligencia artificial que solo afirma lo que
              puede citar.
            </p>
            <p>
              Su valor no está en almacenar archivos, sino en relacionar la evidencia con los temas y hacerla
              consultable con rigor: referencias verificables, nivel de evidencia visible y una separación
              explícita entre lo que dice la fuente y lo que interpreta la IA.
            </p>
          </div>
          <h2>Principios</h2>
          <ul className="principles">
            {PRINCIPLES.map((p) => (
              <li key={p.title}>
                <Icon name="check" />
                <span>
                  <strong>{p.title}</strong>
                  {p.text}
                </span>
              </li>
            ))}
          </ul>
        </div>
        <aside className="panel">
          <div className="panel-head">
            <h2 className="h3">Créditos</h2>
          </div>
          <div className="panel-body stack small">
            <p style={{ margin: 0 }}>
              Creado por <strong>Dr. Juan Pablo Aravena S.</strong>
            </p>
            <p className="muted" style={{ margin: 0 }}>
              La identidad y el contenido original de CMF Academy pertenecen a su creador. El material de
              terceros conserva sus derechos.
            </p>
            <p className="muted" style={{ margin: 0 }}>
              Estado: vista previa en construcción (fase 1). Los términos de uso y la política de privacidad
              se publicarán antes del lanzamiento.
            </p>
            <Link href="/componentes">Sistema de diseño</Link>
          </div>
        </aside>
      </div>
    </>
  );
}
