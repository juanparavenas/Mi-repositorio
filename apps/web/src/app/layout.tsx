import "@fontsource-variable/inter";
import "@fontsource-variable/newsreader/opsz.css";
import "@fontsource-variable/newsreader/opsz-italic.css";
import "@fontsource/ibm-plex-mono/400.css";
import "@fontsource/ibm-plex-mono/500.css";
import "@/styles/tokens.css";
import "@/styles/estilos.css";

import type { Metadata, Viewport } from "next";

import { AppShell } from "@/components/AppShell";
import { THEME_BOOT_SCRIPT } from "@/lib/theme";

export const metadata: Metadata = {
  title: { default: "CMF Academy", template: "%s · CMF Academy" },
  description:
    "Biblioteca científica y plataforma académica de Cirugía Oral y Maxilofacial: conocimiento revisado, citado y conectado.",
  applicationName: "CMF Academy",
  authors: [{ name: "Dr. Juan Pablo Aravena S." }],
  // Vista previa no pública hasta el lanzamiento (plan, fase 1).
  robots: { index: false, follow: false },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#FBFAF7" },
    { media: "(prefers-color-scheme: dark)", color: "#151618" },
  ],
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    // data-theme lo fija el script de arranque antes de que React hidrate.
    <html lang="es" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_BOOT_SCRIPT }} />
      </head>
      <body>
        <AppShell>{children}</AppShell>
      </body>
    </html>
  );
}
