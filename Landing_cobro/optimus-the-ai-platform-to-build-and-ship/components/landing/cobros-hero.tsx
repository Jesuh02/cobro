"use client";

import Link from "next/link";
import dynamic from "next/dynamic";
import { CobroPill } from "@/components/cobro-pill";
import { Button } from "@/components/ui/button";
import { useState } from "react";

const GL = dynamic(() => import("@/components/gl").then((m) => ({ default: m.GL })), {
  ssr: false,
  loading: () => <div className="absolute inset-0 bg-black" />,
});

const stats = [
  { value: "95%", label: "apertura de mensajes WhatsApp" },
  { value: "−40%", label: "reducción en mora" },
  { value: "6h", label: "ahorradas por semana" },
  { value: "<2s", label: "entrega de notificaciones" },
  { value: "99.9%", label: "disponibilidad garantizada" },
  { value: "3 pasos", label: "para gestionar tu cartera" },
];

export function CobrosHero() {
  const [hovering, setHovering] = useState(false);
  return (
    <div className="flex flex-col h-svh justify-between bg-black relative">
      <GL hovering={hovering} />

      <div className="pb-16 mt-auto text-center relative z-10 px-4">
        <CobroPill className="mb-6">SISTEMA DE COBROS</CobroPill>
        <h1 className="text-5xl sm:text-6xl md:text-7xl font-sentient text-white">
          Recupera tu cartera
          <br />
          <i className="font-light">sin esfuerzo</i>
        </h1>
        <p className="font-mono text-sm sm:text-base text-white/60 text-balance mt-8 max-w-[480px] mx-auto">
          Automatiza los cobros de tu negocio. Recordatorios por WhatsApp y email que llegan solos, en el momento exacto.
        </p>

        <div className="flex items-center justify-center gap-4 mt-14 max-sm:flex-col">
          <Link href="#pricing">
            <Button
              className="bg-white text-black hover:bg-white/90 font-mono rounded-none px-8 h-12"
              onMouseEnter={() => setHovering(true)}
              onMouseLeave={() => setHovering(false)}
            >
              [Empezar gratis]
            </Button>
          </Link>
          <Link href="#how-it-works">
            <Button
              className="bg-transparent border border-white/30 text-white hover:bg-white/10 hover:text-white font-mono rounded-none px-8 h-12"
            >
              [Cómo funciona]
            </Button>
          </Link>
        </div>
      </div>

      {/* Stats marquee */}
      <div className="relative z-10 pb-8 overflow-hidden">
        <div className="flex gap-16 whitespace-nowrap" style={{ animation: "marqueeHero 25s linear infinite" }}>
          {[...Array(2)].map((_, i) => (
            <div key={i} className="flex gap-16 shrink-0">
              {stats.map((stat) => (
                <div key={`${stat.label}-${i}`} className="flex items-baseline gap-3">
                  <span className="text-3xl lg:text-4xl font-sentient text-white">{stat.value}</span>
                  <span className="text-xs text-white/40 font-mono">{stat.label}</span>
                </div>
              ))}
            </div>
          ))}
        </div>
      </div>

      <style jsx>{`
        @keyframes marqueeHero {
          0% { transform: translateX(0); }
          100% { transform: translateX(-50%); }
        }
      `}</style>
    </div>
  );
}
