import type { Metadata } from "next";

import { SectionPlaceholder } from "@/components/SectionPlaceholder";

export const metadata: Metadata = { title: "Asistente IA" };

export default function Page() {
  return <SectionPlaceholder href="/asistente" />;
}
