import type { Metadata } from "next";

import { SectionPlaceholder } from "@/components/SectionPlaceholder";

export const metadata: Metadata = { title: "Multimedia" };

export default function Page() {
  return <SectionPlaceholder href="/multimedia" />;
}
