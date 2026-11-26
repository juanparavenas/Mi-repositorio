import Link from "next/link";

import { EmptyState } from "@/components/EmptyState";
import { SearchBox } from "@/components/SearchBox";
import { SECTIONS } from "@/lib/navigation";

export default function HomePage() {
  return (
    <>
      <section className="hero" aria-labelledby="t-inicio">
        <p className="eyebrow">Biblioteca científica de Cirugía Oral y Maxilofacial</p>
        <h1 id="t-inicio">Conocimiento revisado, citado y conectado</h1>
        <p className="lede">
          Cada tema reúne una síntesis académica revisada, la literatura de PubMed, documentos y un asistente
          que solo afirma lo que puede citar.
        </p>
        <SearchBox large placeholder="Por ejemplo: osteotomía sagital, cirugía primero, Le Fort I" />
      </section>

      <div className="split">
        <div className="stack">
          <h2>Secciones</h2>
          <ul className="area-list">
            {SECTIONS.filter((s) => s.href !== "/").map((s) => (
              <li key={s.href}>
                <div>
                  <Link href={s.href}>{s.label}</Link>
                  <div className="sub">{s.description}</div>
                </div>
              </li>
            ))}
          </ul>
        </div>
        <EmptyState icon="library" title="La biblioteca todavía está vacía">
          <p>
            Las cifras del panel, las áreas y las publicaciones recientes aparecerán cuando la aplicación se
            conecte a la base de datos (etapas 1.2 y 1.9). Hasta entonces no se muestran números de ejemplo.
          </p>
          <p>
            <Link href="/acerca">Cómo funciona CMF Academy</Link>
          </p>
        </EmptyState>
      </div>
    </>
  );
}
