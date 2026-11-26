"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { SECTIONS, isSectionActive } from "@/lib/navigation";

import { Icon } from "./Icon";

export function Sidebar({ id }: { id: string }) {
  const pathname = usePathname();
  return (
    <aside className="sidebar" id={id} aria-label="Navegación principal">
      <Link className="wordmark" href="/">
        <span className="wordmark-name">
          CMF <span>Academy</span>
        </span>
        <span className="wordmark-sub">The Oral &amp; Maxillofacial Knowledge Platform</span>
      </Link>
      <nav className="nav" aria-label="Secciones">
        {SECTIONS.map((s) => (
          <Link
            key={s.href}
            href={s.href}
            aria-current={isSectionActive(s.href, pathname) ? "page" : undefined}
          >
            <Icon name={s.icon} />
            {s.label}
          </Link>
        ))}
      </nav>
      <div className="sidebar-foot">
        Creado por
        <br />
        Dr. Juan Pablo Aravena S.
      </div>
    </aside>
  );
}
