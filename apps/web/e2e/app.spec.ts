import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";

const ROUTES = [
  { path: "/", heading: "Conocimiento revisado, citado y conectado" },
  { path: "/biblioteca", heading: "Biblioteca" },
  { path: "/investigacion", heading: "Investigación" },
  { path: "/asistente", heading: "Asistente IA" },
  { path: "/multimedia", heading: "Multimedia" },
  { path: "/comunidad", heading: "Comunidad" },
  { path: "/acerca", heading: "Acerca de CMF Academy" },
  { path: "/componentes", heading: "Sistema de diseño" },
  { path: "/buscar?q=discopexia", heading: "Buscar" },
];

/**
 * Desborde respecto del ancho real del dispositivo. En teléfonos, si el
 * contenido no cabe, el navegador ensancha el área de diseño (innerWidth crece)
 * y el desborde no se ve comparando con innerWidth: se compara con el viewport.
 */
async function horizontalOverflow(page: Page) {
  const deviceWidth = page.viewportSize()?.width ?? 0;
  const { scrollWidth, innerWidth } = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    innerWidth: window.innerWidth,
  }));
  return Math.max(scrollWidth, innerWidth) - deviceWidth;
}

async function bodyIsDark(page: Page) {
  // Espera a que termine la transición de color del cuerpo.
  await page.waitForTimeout(260);
  return page.evaluate(() => {
    const m = getComputedStyle(document.body).backgroundColor.match(/\d+/g)?.map(Number) ?? [255, 255, 255];
    return (m[0]! + m[1]! + m[2]!) / 3 < 80;
  });
}

for (const route of ROUTES) {
  test(`${route.path}: carga, título, sin desborde horizontal y sin errores de consola`, async ({ page }) => {
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(e.message));
    page.on("console", (m) => m.type() === "error" && errors.push(m.text()));
    await page.goto(route.path);
    await expect(page.getByRole("heading", { level: 1, name: route.heading })).toBeVisible();
    expect(await horizontalOverflow(page)).toBeLessThanOrEqual(0);
    expect(errors).toEqual([]);
  });

  for (const theme of ["light", "dark"] as const) {
    test(`${route.path}: accesibilidad WCAG 2.2 AA en modo ${theme === "light" ? "claro" : "oscuro"}`, async ({
      page,
    }) => {
      await page.emulateMedia({ colorScheme: theme });
      await page.goto(route.path);
      await page.waitForTimeout(260);
      const results = await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"])
        .analyze();
      expect(
        results.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(" ")).join(", ")}`),
      ).toEqual([]);
    });
  }
}

test("la página inexistente muestra un 404 amable", async ({ page }) => {
  const res = await page.goto("/no-existe");
  expect(res?.status()).toBe(404);
  await expect(page.getByRole("heading", { level: 1, name: "Página no encontrada" })).toBeVisible();
});

test("el tema sigue al sistema y se puede fijar a mano, y se recuerda al recargar", async ({ page }) => {
  await page.emulateMedia({ colorScheme: "dark" });
  await page.goto("/");
  expect(await page.evaluate(() => document.documentElement.getAttribute("data-theme"))).toBeNull();
  expect(await bodyIsDark(page)).toBe(true);

  await page.getByRole("button", { name: "Modo claro" }).click();
  await expect(page.getByRole("button", { name: "Modo claro" })).toHaveAttribute("aria-pressed", "true");
  expect(await bodyIsDark(page)).toBe(false);

  await page.reload();
  // El script de arranque fija el tema antes de que React hidrate: sin destello.
  expect(await page.evaluate(() => document.documentElement.getAttribute("data-theme"))).toBe("light");
  expect(await bodyIsDark(page)).toBe(false);

  await page.getByRole("button", { name: "Seguir al sistema" }).click();
  expect(await page.evaluate(() => document.documentElement.getAttribute("data-theme"))).toBeNull();
  expect(await bodyIsDark(page)).toBe(true);
});

test("el primer Tab ofrece saltar al contenido", async ({ page }) => {
  await page.goto("/acerca");
  await page.keyboard.press("Tab");
  const skip = page.getByRole("link", { name: "Saltar al contenido" });
  await expect(skip).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.locator("#contenido")).toBeFocused();
});

test("la búsqueda envía la consulta a /buscar", async ({ page }) => {
  await page.goto("/");
  const input = page.getByRole("searchbox", { name: "Buscar en CMF Academy" }).first();
  await input.fill("le fort");
  await input.press("Enter");
  await expect(page).toHaveURL(/\/buscar\?q=le\+fort/);
  await expect(page.getByRole("heading", { name: "Sin resultados para «le fort»" })).toBeVisible();
});

test.describe("escritorio", () => {
  test.skip(({ isMobile }) => isMobile, "solo en escritorio");

  test("la barra lateral navega por las siete secciones y marca la actual", async ({ page }) => {
    await page.goto("/");
    const nav = page.getByRole("navigation", { name: "Secciones" });
    await expect(page.getByRole("button", { name: "Abrir menú" })).toBeHidden();
    for (const label of [
      "Biblioteca",
      "Investigación",
      "Asistente IA",
      "Multimedia",
      "Comunidad",
      "Acerca de",
      "Inicio",
    ]) {
      await nav.getByRole("link", { name: label }).click();
      await expect(nav.getByRole("link", { name: label })).toHaveAttribute("aria-current", "page");
    }
  });

  test("⌘K / Ctrl+K lleva el foco a la búsqueda", async ({ page }) => {
    await page.goto("/acerca");
    await page.keyboard.press("Control+k");
    await expect(page.locator("[data-global-search]")).toBeFocused();
  });
});

test.describe("teléfono", () => {
  test.skip(({ isMobile }) => !isMobile, "solo en teléfono");

  test("el menú se abre, navega, se cierra al navegar y con Escape", async ({ page }) => {
    await page.goto("/");
    const toggle = page.getByRole("button", { name: "Abrir menú" });
    await expect(toggle).toBeVisible();
    await expect(page.locator(".sidebar")).not.toBeInViewport();

    await toggle.click();
    await expect(page.getByRole("button", { name: "Cerrar menú" })).toHaveAttribute("aria-expanded", "true");
    await expect(page.locator(".sidebar")).toBeInViewport();

    await page
      .getByRole("navigation", { name: "Secciones" })
      .getByRole("link", { name: "Biblioteca" })
      .click();
    await expect(page).toHaveURL(/\/biblioteca$/);
    await expect(page.locator(".app")).toHaveAttribute("data-menu", "closed");

    await page.getByRole("button", { name: "Abrir menú" }).click();
    await page.keyboard.press("Escape");
    await expect(page.locator(".app")).toHaveAttribute("data-menu", "closed");
  });

  test("la barra superior cabe completa a 360 px: búsqueda y los tres botones de tema visibles", async ({
    page,
  }) => {
    await page.setViewportSize({ width: 360, height: 740 });
    await page.goto("/");
    expect(await horizontalOverflow(page)).toBeLessThanOrEqual(0);
    for (const name of ["Seguir al sistema", "Modo claro", "Modo oscuro"]) {
      await expect(page.getByRole("button", { name })).toBeInViewport({ ratio: 1 });
    }
    await expect(page.locator("[data-global-search]")).toBeInViewport();
    await expect(page.locator(".app")).toHaveAttribute("data-menu", "closed");
  });
});
