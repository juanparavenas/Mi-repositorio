import { SECTIONS, isSectionActive, sectionFor } from "./navigation";

describe("navegación", () => {
  it("tiene las siete secciones del documento maestro, en orden", () => {
    expect(SECTIONS.map((s) => s.label)).toEqual([
      "Inicio",
      "Biblioteca",
      "Investigación",
      "Asistente IA",
      "Multimedia",
      "Comunidad",
      "Acerca de",
    ]);
    expect(new Set(SECTIONS.map((s) => s.href)).size).toBe(SECTIONS.length);
  });

  it("la raíz solo está activa en la raíz", () => {
    expect(isSectionActive("/", "/")).toBe(true);
    expect(isSectionActive("/", "/biblioteca")).toBe(false);
  });

  it("una sección está activa en sus subrutas, no en rutas parecidas", () => {
    expect(isSectionActive("/biblioteca", "/biblioteca/cirugia-ortognatica")).toBe(true);
    expect(isSectionActive("/biblioteca", "/bibliotecas")).toBe(false);
    expect(sectionFor("/asistente")?.label).toBe("Asistente IA");
    expect(sectionFor("/no-existe")).toBeUndefined();
  });
});
