import type { Metadata } from "next";

import { EmptyState } from "@/components/EmptyState";
import { PageHeader } from "@/components/PageHeader";

export const metadata: Metadata = { title: "Buscar" };

export default async function SearchPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string | string[] }>;
}) {
  const { q } = await searchParams;
  const query = (Array.isArray(q) ? q[0] : q)?.trim().slice(0, 200) ?? "";
  return (
    <>
      <PageHeader title="Buscar" crumbs={[{ href: "/", label: "Inicio" }, { label: "Buscar" }]} />
      <EmptyState
        icon="search"
        title={query ? `Sin resultados para «${query}»` : "Escribe qué quieres buscar"}
      >
        <p>
          La búsqueda global recorrerá temas, obras y autores cuando la biblioteca esté conectada a la base de
          datos (etapa 1.9). Todavía no hay contenido en el que buscar.
        </p>
      </EmptyState>
    </>
  );
}
