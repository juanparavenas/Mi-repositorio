import type { Metadata } from "next";

import { SectionPlaceholder } from "@/components/SectionPlaceholder";

export const metadata: Metadata = { title: "Investigación" };

export default function Page() {
  return <SectionPlaceholder href="/investigacion" />;
}
