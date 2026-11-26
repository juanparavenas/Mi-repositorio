import Link from "next/link";

export interface Crumb {
  href?: string;
  label: string;
}

export function PageHeader({
  title,
  lede,
  eyebrow,
  crumbs,
}: {
  title: string;
  lede?: string;
  eyebrow?: string;
  crumbs?: Crumb[];
}) {
  return (
    <div className="page-head">
      {crumbs && crumbs.length > 0 ? (
        <nav className="crumbs" aria-label="Ruta">
          {crumbs.map((c, i) => (
            <span key={`${c.label}-${i}`} className="row" style={{ gap: 6 }}>
              {c.href ? <Link href={c.href}>{c.label}</Link> : <span aria-current="page">{c.label}</span>}
              {i < crumbs.length - 1 ? <span aria-hidden="true">/</span> : null}
            </span>
          ))}
        </nav>
      ) : null}
      {eyebrow ? <p className="eyebrow">{eyebrow}</p> : null}
      <h1>{title}</h1>
      {lede ? <p className="lede">{lede}</p> : null}
    </div>
  );
}
