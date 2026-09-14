'use client'

import dynamic from "next/dynamic";
import { Navigation } from "@/components/landing/navigation";
import { CobrosHero } from "@/components/landing/cobros-hero";
import { FeaturesSection } from "@/components/landing/features-section";
import { HowItWorksSection } from "@/components/landing/how-it-works-section";
import { InfrastructureSection } from "@/components/landing/infrastructure-section";
import { MetricsSection } from "@/components/landing/metrics-section";
import { IntegrationsSection } from "@/components/landing/integrations-section";
import { SecuritySection } from "@/components/landing/security-section";
import { PricingSection } from "@/components/landing/pricing-section";
import { CtaSection } from "@/components/landing/cta-section";
import { FooterSection } from "@/components/landing/footer-section";

const Leva = dynamic(() => import("leva").then((m) => ({ default: m.Leva })), { ssr: false });

export default function Home() {
  return (
    <>
      <Leva hidden />
      <Navigation />
      <CobrosHero />
      <main className="relative overflow-x-hidden noise-overlay bg-background">
        <FeaturesSection />
        <HowItWorksSection />
        <InfrastructureSection />
        <MetricsSection />
        <IntegrationsSection />
        <SecuritySection />
        <PricingSection />
        <CtaSection />
        <FooterSection />
      </main>
    </>
  );
}
