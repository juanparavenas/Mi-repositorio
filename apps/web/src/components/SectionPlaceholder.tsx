import { SECTIONS } from "@/lib/navigation";

import { EmptyState } from "./EmptyState";
import { PageHeader } from "./PageHeader";

/** Página de una sección cuyo contenido real se construye en una fase posterior. */
export function SectionPlaceholder({ href, note }: { href: string; note?: React.ReactNode }) {
  const section = SECTIONS.find((s) => s.href === href);
  if (!section) throw new Error(`Sección desconocida: ${href}`);
  return (
    <>
      <PageHeader
        title={section.label}
        lede={section.description}
        crumbs={[{ href: "/", label: "Inicio" }, { label: section.label }]}
      />
      <EmptyState icon={section.icon} title="Todavía sin contenido">
        <p>
          Esta sección se construye en la{" "}
          <strong>{section.phase.includes(".") ? `etapa ${section.phase}` : `fase ${section.phase}`}</strong>{" "}
          del plan de implementación. No se muestra contenido de ejemplo para no confundirlo con información
          real.
        </p>
        {note}
      </EmptyState>
    </>
  );
}
