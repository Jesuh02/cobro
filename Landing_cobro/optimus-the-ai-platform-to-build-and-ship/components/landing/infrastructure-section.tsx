"use client";

import { useEffect, useState, useRef } from "react";

const estadisticas = [
  { label: "Tasa de apertura WhatsApp", valor: "95%", descripcion: "Vs 20% del email tradicional" },
  { label: "Reducción en mora", valor: "40%", descripcion: "Con recordatorios automáticos" },
  { label: "Tiempo ahorrado por cobrador", valor: "6h", descripcion: "Por semana en gestión manual" },
  { label: "Entrega de mensajes", valor: "<2s", descripcion: "Tiempo promedio de notificación" },
  { label: "Disponibilidad de la plataforma", valor: "99.9%", descripcion: "SLA garantizado" },
  { label: "Soporte técnico", valor: "24/7", descripcion: "Para planes Pro y Empresarial" },
];

export function InfrastructureSection() {
  const [isVisible, setIsVisible] = useState(false);
  const [activeItem, setActiveItem] = useState(0);
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) setIsVisible(true); },
      { threshold: 0.1 }
    );
    if (sectionRef.current) observer.observe(sectionRef.current);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    const interval = setInterval(() => {
      setActiveItem((prev) => (prev + 1) % estadisticas.length);
    }, 2000);
    return () => clearInterval(interval);
  }, []);

  return (
    <section ref={sectionRef} className="relative py-24 lg:py-32 overflow-hidden">
      <div className="max-w-[1400px] mx-auto px-6 lg:px-12">
        <div className="grid lg:grid-cols-2 gap-16 lg:gap-24 items-center">
          {/* Left: Content */}
          <div
            className={`transition-all duration-700 ${isVisible ? "opacity-100 translate-x-0" : "opacity-0 -translate-x-8"}`}
          >
            <span className="inline-flex items-center gap-3 text-sm font-mono text-muted-foreground mb-6">
              <span className="w-8 h-px bg-foreground/30" />
              Por qué funciona
            </span>
            <h2 className="text-4xl lg:text-6xl font-display tracking-tight mb-8">
              El cobro inteligente
              <br />
              da resultados.
            </h2>
            <p className="text-xl text-muted-foreground leading-relaxed mb-12">
              Los recordatorios oportunos por WhatsApp reducen drásticamente la cartera vencida. Automatizar el proceso elimina el trabajo repetitivo y mejora la relación con tus clientes.
            </p>

            <div className="grid grid-cols-3 gap-8">
              <div>
                <div className="text-4xl lg:text-5xl font-display mb-2">95%</div>
                <div className="text-sm text-muted-foreground">Apertura de mensajes WhatsApp</div>
              </div>
              <div>
                <div className="text-4xl lg:text-5xl font-display mb-2">−40%</div>
                <div className="text-sm text-muted-foreground">Reducción en mora</div>
              </div>
              <div>
                <div className="text-4xl lg:text-5xl font-display mb-2">6h</div>
                <div className="text-sm text-muted-foreground">Ahorradas por semana</div>
              </div>
            </div>
          </div>

          {/* Right: Stats list */}
          <div
            className={`transition-all duration-700 delay-200 ${isVisible ? "opacity-100 translate-x-0" : "opacity-0 translate-x-8"}`}
          >
            <div className="border border-foreground/10">
              <div className="px-6 py-4 border-b border-foreground/10 flex items-center justify-between">
                <span className="text-sm font-mono text-muted-foreground">Métricas del sistema</span>
                <span className="flex items-center gap-2 text-xs font-mono text-green-600">
                  <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
                  Operativo
                </span>
              </div>

              <div>
                {estadisticas.map((item, index) => (
                  <div
                    key={item.label}
                    className={`px-6 py-5 border-b border-foreground/5 last:border-b-0 flex items-center justify-between transition-all duration-300 ${activeItem === index ? "bg-foreground/[0.02]" : ""}`}
                  >
                    <div className="flex items-center gap-4">
                      <span
                        className={`w-2 h-2 rounded-full transition-colors duration-300 ${activeItem === index ? "bg-foreground" : "bg-foreground/20"}`}
                      />
                      <div>
                        <div className="font-medium text-sm">{item.label}</div>
                        <div className="text-xs text-muted-foreground">{item.descripcion}</div>
                      </div>
                    </div>
                    <span className="font-mono text-sm font-medium text-foreground">{item.valor}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
