/**
 * Las siete secciones del documento maestro, en el orden de la barra lateral.
 * `phase` indica en qué fase del plan se construye su contenido real.
 */
export type IconName = "home" | "library" | "search" | "chat" | "image" | "users" | "info";

export interface Section {
  href: string;
  label: string;
  icon: IconName;
  description: string;
  phase: string;
}

export const SECTIONS: readonly Section[] = [
  { href: "/", label: "Inicio", icon: "home", description: "Panel de inicio", phase: "1.9" },
  {
    href: "/biblioteca",
    label: "Biblioteca",
    icon: "library",
    description: "El árbol de conocimiento: áreas, temas y subtemas con su literatura y documentos.",
    phase: "1.6",
  },
  {
    href: "/investigacion",
    label: "Investigación",
    icon: "search",
    description:
      "Búsqueda en PubMed por palabra clave, autor, año y tipo de estudio, con enlaces a la fuente.",
    phase: "3",
  },
  {
    href: "/asistente",
    label: "Asistente IA",
    icon: "chat",
    description: "Un asistente que solo afirma lo que puede citar de la biblioteca y de PubMed.",
    phase: "4",
  },
  {
    href: "/multimedia",
    label: "Multimedia",
    icon: "image",
    description: "Galerías, videos, esquemas y modelos 3D educativos, con consentimiento y anonimización.",
    phase: "5",
  },
  {
    href: "/comunidad",
    label: "Comunidad",
    icon: "users",
    description: "Aportes, comentarios y moderación de la comunidad académica.",
    phase: "6",
  },
  {
    href: "/acerca",
    label: "Acerca de",
    icon: "info",
    description: "Qué es CMF Academy, cómo trabaja y quién la creó.",
    phase: "1.10",
  },
] as const;

/** ¿La ruta actual pertenece a la sección? La raíz solo coincide consigo misma. */
export function isSectionActive(sectionHref: string, pathname: string): boolean {
  if (sectionHref === "/") return pathname === "/";
  return pathname === sectionHref || pathname.startsWith(`${sectionHref}/`);
}

export function sectionFor(pathname: string): Section | undefined {
  return SECTIONS.find((s) => isSectionActive(s.href, pathname));
}
