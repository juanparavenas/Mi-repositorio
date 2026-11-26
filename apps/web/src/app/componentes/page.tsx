import type { Metadata } from "next";

import { EmptyState } from "@/components/EmptyState";
import { Icon } from "@/components/Icon";
import { PageHeader } from "@/components/PageHeader";

export const metadata: Metadata = { title: "Sistema de diseño" };

const COLORS = [
  "paper",
  "surface",
  "raised",
  "sunken",
  "ink",
  "ink-2",
  "ink-3",
  "border",
  "border-strong",
  "accent",
  "accent-tint",
  "ok",
  "warn",
  "critical",
  "info",
];

function Section({ id, title, children }: { id: string; title: string; children: React.ReactNode }) {
  return (
    <section aria-labelledby={id} style={{ marginBottom: "var(--space-12)" }}>
      <h2 id={id}>{title}</h2>
      {children}
    </section>
  );
}

/** Galería de referencia de los componentes. Cambia el tema arriba para revisarlos en claro y oscuro. */
export default function ComponentsPage() {
  return (
    <>
      <PageHeader
        title="Sistema de diseño"
        lede="Referencia viva de tokens y componentes. Usa el selector de la barra superior para verlos en modo claro y oscuro."
        crumbs={[
          { href: "/", label: "Inicio" },
          { href: "/acerca", label: "Acerca de" },
          { label: "Sistema de diseño" },
        ]}
      />

      <Section id="color" title="Color">
        <div className="swatch-grid">
          {COLORS.map((c) => (
            <div className="swatch" key={c}>
              <i style={{ background: `var(--color-${c})` }} />
              <span>
                <b>--color-{c}</b>
              </span>
            </div>
          ))}
        </div>
        <p className="small muted">
          Contraste verificado en CI con <span className="mono">scripts/check_contrast.py</span>: 36 pares
          cumplen WCAG 2.2 AA en cada modo.
        </p>
      </Section>

      <Section id="tipografia" title="Tipografía">
        <div className="stack">
          <p className="h1" style={{ margin: 0 }}>
            Título de tema · Newsreader 42
          </p>
          <p className="h2" style={{ margin: 0 }}>
            Título de sección · Newsreader 30
          </p>
          <p className="lede" style={{ margin: 0 }}>
            Entradilla · Newsreader 22, para presentar cada tema.
          </p>
          <div className="prose">
            <p>
              Cuerpo de lectura en Newsreader 18 con interlineado 1,65 y una medida máxima de 68 caracteres,
              pensado para secciones académicas extensas.
              <a className="cite" href="#tipografia">
                1
              </a>
              <a className="cite" href="#tipografia">
                2
              </a>
            </p>
          </div>
          <p style={{ margin: 0 }}>Interfaz · Inter 16 y 14 para controles y tablas.</p>
          <p style={{ margin: 0 }}>
            Identificadores · <span className="doi">doi:10.1016/j.ijom.2015.05.024</span>
          </p>
        </div>
      </Section>

      <Section id="botones" title="Botones">
        <div className="row">
          <button className="btn btn-primary" type="button">
            Principal
          </button>
          <button className="btn btn-secondary" type="button">
            Secundario
          </button>
          <button className="btn btn-quiet" type="button">
            Discreto
          </button>
          <button className="btn btn-danger" type="button">
            Peligro
          </button>
          <button className="btn btn-secondary btn-sm" type="button">
            Pequeño
          </button>
          <button className="btn btn-secondary btn-icon" type="button" aria-label="Solo icono">
            <Icon name="search" />
          </button>
          <button className="btn btn-primary" type="button" disabled>
            Deshabilitado
          </button>
        </div>
      </Section>

      <Section id="insignias" title="Insignias y estados">
        <div className="row">
          <span className="badge">Neutra</span>
          <span className="badge dot accent">Revisado por un editor</span>
          <span className="badge dot warn">Borrador · generado por IA</span>
          <span className="badge dot ok">Público</span>
          <span className="badge dot critical">Excluido</span>
          <span className="badge dot info">Acceso abierto · CC BY</span>
          <span className="evidence">
            <b>1</b>Revisión sistemática
          </span>
        </div>
      </Section>

      <Section id="avisos" title="Avisos">
        <div className="grid grid-2">
          <div className="alert info">
            <Icon name="info" />
            <div>
              <strong>Información</strong>Texto completo restringido por derechos de autor.
            </div>
          </div>
          <div className="alert warn">
            <Icon name="alert" />
            <div>
              <strong>Advertencia</strong>Pendiente de revisión editorial.
            </div>
          </div>
          <div className="alert critical">
            <Icon name="shield" />
            <div>
              <strong>Crítico</strong>Exclusión permanente: no se puede liberar.
            </div>
          </div>
          <div className="alert ok">
            <Icon name="check" />
            <div>
              <strong>Correcto</strong>Derechos verificados por un editor.
            </div>
          </div>
        </div>
      </Section>

      <Section id="formularios" title="Formularios">
        <div className="grid grid-2">
          <div className="field">
            <label htmlFor="demo-titulo">Título</label>
            <input id="demo-titulo" className="input" placeholder="Por ejemplo: Discopexia" />
            <span className="hint">Ayuda breve debajo del campo.</span>
          </div>
          <div className="field">
            <label htmlFor="demo-estado">Estado</label>
            <select id="demo-estado" className="select" defaultValue="borrador">
              <option value="borrador">Borrador</option>
              <option value="revision">En revisión</option>
              <option value="publicado">Publicado</option>
            </select>
          </div>
          <div className="field">
            <label htmlFor="demo-doi">DOI</label>
            <input
              id="demo-doi"
              className="input"
              aria-invalid="true"
              aria-describedby="demo-doi-error"
              defaultValue="10.1016"
            />
            <span className="error" id="demo-doi-error">
              El DOI está incompleto.
            </span>
          </div>
          <div className="field" style={{ justifyContent: "end" }}>
            <label className="check">
              <input type="checkbox" defaultChecked /> Permitir procesamiento por IA
            </label>
          </div>
        </div>
      </Section>

      <Section id="tablas" title="Tablas">
        <div className="table-wrap">
          <table className="table">
            <caption>Literatura: artículos reales, verificados en PubMed.</caption>
            <thead>
              <tr>
                <th scope="col">Año</th>
                <th scope="col">Obra</th>
                <th scope="col">DOI</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td className="nowrap tnum">2015</td>
                <td className="work">
                  The surgery-first approach in orthognathic surgery: a retrospective study of 50 cases
                  <small>Yu HB et al. · Int J Oral Maxillofac Surg 44(12):1463–7</small>
                </td>
                <td>
                  <a className="doi" href="https://doi.org/10.1016/j.ijom.2015.05.024">
                    10.1016/j.ijom.2015.05.024
                  </a>
                </td>
              </tr>
              <tr>
                <td className="nowrap tnum">2011</td>
                <td className="work">
                  Sequencing bimaxillary surgery: mandible first
                  <small>Perez D, Ellis E · J Oral Maxillofac Surg 69(8):2217–24</small>
                </td>
                <td>
                  <a className="doi" href="https://doi.org/10.1016/j.joms.2010.10.053">
                    10.1016/j.joms.2010.10.053
                  </a>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </Section>

      <Section id="vacios" title="Estados vacíos">
        <EmptyState icon="library" title="Todavía sin contenido">
          <p>Se explica qué falta y cuándo llega, sin mostrar datos de ejemplo.</p>
        </EmptyState>
      </Section>
    </>
  );
}
