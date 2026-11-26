import Link from "next/link";

import { EmptyState } from "@/components/EmptyState";
import { PageHeader } from "@/components/PageHeader";

export default function NotFound() {
  return (
    <>
      <PageHeader title="Página no encontrada" />
      <EmptyState icon="search" title="Esta dirección no existe">
        <p>Puede que el enlace esté mal escrito o que la página todavía no se haya creado.</p>
        <p>
          <Link href="/">Volver al inicio</Link>
        </p>
      </EmptyState>
    </>
  );
}
