"use client";

import { useEffect, useState, useRef } from "react";
import { MessageCircle, Mail, FileSpreadsheet, Webhook, Database, Lock } from "lucide-react";

const integrations = [
  {
    icon: MessageCircle,
    name: "WhatsApp",
    category: "Notificación principal",
    description: "Envía recordatorios directamente al WhatsApp de tus clientes con mensajes personalizados.",
    highlight: true,
  },
  {
    icon: Mail,
    name: "Email",
    category: "Notificación secundaria",
    description: "Correos automáticos con detalles del cobro, fechas y montos pendientes.",
    highlight: false,
  },
  {
    icon: FileSpreadsheet,
    name: "Excel / CSV",
    category: "Importación de datos",
    description: "Importa tu cartera existente directamente desde tus archivos de Excel o CSV.",
    highlight: false,
  },
  {
    icon: Database,
    name: "API REST",
    category: "Integración técnica",
    description: "Conecta Cobro con tu sistema actual a través de nuestra API para sincronizar datos.",
    highlight: false,
  },
  {
    icon: Webhook,
    name: "Webhooks",
    category: "Automatización",
    description: "Recibe notificaciones en tiempo real cuando un cliente paga o cuando vence una cuota.",
    highlight: false,
  },
];

export function IntegrationsSection() {
  const [isVisible, setIsVisible] = useState(false);
  const sectionRef = useRef<HTMLElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) setIsVisible(true); },
      { threshold: 0.1 }
    );
    if (sectionRef.current) observer.observe(sectionRef.current);
    return () => observer.disconnect();
  }, []);

  return (
    <section id="integrations" ref={sectionRef} className="relative py-24 lg:py-32 overflow-hidden">
      <div className="max-w-[1400px] mx-auto px-6 lg:px-12">
        {/* Header */}
        <div
          className={`max-w-3xl mb-16 lg:mb-24 transition-all duration-700 ${isVisible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-8"}`}
        >
          <span className="inline-flex items-center gap-3 text-sm font-mono text-muted-foreground mb-6">
            <span className="w-8 h-px bg-foreground/30" />
            Canales e integraciones
          </span>
          <h2 className="text-4xl lg:text-6xl font-display tracking-tight mb-6">
            Llega a tus clientes
            <br />
            donde están.
          </h2>
          <p className="text-xl text-muted-foreground">
            Notifica por WhatsApp y email. Importa tu cartera desde Excel. Conecta con tu sistema actual.
          </p>
        </div>

        {/* Integration cards */}
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6 mb-16">
          {integrations.map((item, index) => {
            const Icon = item.icon;
            return (
              <div
                key={item.name}
                className={`p-6 border border-foreground/10 hover:border-foreground/25 transition-all duration-500 group ${isVisible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-8"} ${item.highlight ? "border-foreground/25 bg-foreground/[0.02]" : ""}`}
                style={{ transitionDelay: `${index * 80}ms` }}
              >
                <div className="flex items-start gap-4">
                  <div className={`shrink-0 w-10 h-10 flex items-center justify-center border transition-colors duration-300 ${item.highlight ? "border-foreground/30 bg-foreground text-background" : "border-foreground/10 group-hover:bg-foreground group-hover:text-background"}`}>
                    <Icon className="w-5 h-5" />
                  </div>
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <h3 className="font-medium">{item.name}</h3>
                      {item.highlight && (
                        <span className="text-xs px-2 py-0.5 bg-foreground text-background font-mono">Principal</span>
                      )}
                    </div>
                    <p className="text-xs text-muted-foreground mb-2 font-mono">{item.category}</p>
                    <p className="text-sm text-muted-foreground leading-relaxed">{item.description}</p>
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {/* Wompi optional banner */}
        <div
          className={`border border-foreground/10 p-6 lg:p-8 transition-all duration-700 delay-500 ${isVisible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-8"}`}
        >
          <div className="flex flex-col lg:flex-row items-start lg:items-center gap-6">
            <div className="shrink-0 w-12 h-12 flex items-center justify-center border border-foreground/10">
              <Lock className="w-6 h-6 text-muted-foreground" />
            </div>
            <div className="flex-1">
              <div className="flex items-center gap-3 mb-2">
                <h3 className="text-xl font-display">Wompi — Pagos en línea</h3>
                <span className="text-xs px-3 py-1 border border-foreground/20 text-muted-foreground font-mono">Opcional</span>
              </div>
              <p className="text-muted-foreground leading-relaxed">
                Integración opcional con <strong className="text-foreground">Wompi</strong> para que tus clientes puedan pagar directamente desde el recordatorio.
                Acepta tarjetas de crédito, débito, PSE, Nequi y Bancolombia. Actívalo solo si lo necesitas — no es obligatorio para usar Cobro.
              </p>
            </div>
            <div className="shrink-0">
              <a href="#pricing" className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors border border-foreground/10 hover:border-foreground/30 px-4 py-2">
                Ver planes que incluyen Wompi
              </a>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
