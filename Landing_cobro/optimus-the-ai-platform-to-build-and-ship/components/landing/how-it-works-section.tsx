"use client";

import { useEffect, useRef, useState } from "react";
import { Users, Bell, CheckCircle } from "lucide-react";

const steps = [
  {
    number: "I",
    icon: Users,
    title: "Registra tu cartera",
    description: "Importa tus clientes desde Excel o CSV, o agrégalos uno a uno. En minutos tienes toda tu cartera en el sistema lista para gestionar.",
    detail: [
      "Importación masiva desde Excel o CSV",
      "Registro manual de clientes",
      "Historial de pagos y cuotas",
      "Segmentación por estado de cuenta",
    ],
    status: "Cartera importada",
    statusValue: "247 clientes activos",
  },
  {
    number: "II",
    icon: Bell,
    title: "Configura tus reglas",
    description: "Define cuándo y cómo notificar a cada cliente. Por WhatsApp, email, o ambos. Con el mensaje personalizado que tú decides.",
    detail: [
      "Recordatorio 5 días antes del vencimiento",
      "Alerta el día del vencimiento",
      "Seguimiento a los 3, 7 y 15 días de mora",
      "Mensajes personalizados por cliente",
    ],
    status: "Reglas configuradas",
    statusValue: "3 flujos activos",
  },
  {
    number: "III",
    icon: CheckCircle,
    title: "Recibe tus pagos",
    description: "Tus clientes reciben recordatorios oportunos y personalizados. Tú recibes los pagos y actualizas el estado con un clic.",
    detail: [
      "Notificaciones entregadas automáticamente",
      "Registro de pagos recibidos",
      "Actualización de estado en tiempo real",
      "Reportes de recuperación de cartera",
    ],
    status: "Pagos recibidos",
    statusValue: "Esta semana: 38 cobros",
  },
];

export function HowItWorksSection() {
  const [activeStep, setActiveStep] = useState(0);
  const [isVisible, setIsVisible] = useState(false);
  const sectionRef = useRef<HTMLDivElement>(null);

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
      setActiveStep((prev) => (prev + 1) % steps.length);
    }, 5000);
    return () => clearInterval(interval);
  }, []);

  const active = steps[activeStep];
  const ActiveIcon = active.icon;

  return (
    <section
      id="how-it-works"
      ref={sectionRef}
      className="relative py-24 lg:py-32 bg-foreground text-background overflow-hidden"
    >
      <div className="absolute inset-0 opacity-[0.03] pointer-events-none">
        <div className="absolute inset-0" style={{
          backgroundImage: `repeating-linear-gradient(-45deg, transparent, transparent 40px, currentColor 40px, currentColor 41px)`
        }} />
      </div>

      <div className="relative z-10 max-w-[1400px] mx-auto px-6 lg:px-12">
        <div className="mb-16 lg:mb-24">
          <span className="inline-flex items-center gap-3 text-sm font-mono text-background/50 mb-6">
            <span className="w-8 h-px bg-background/30" />
            Proceso
          </span>
          <h2
            className={`text-4xl lg:text-6xl font-display tracking-tight transition-all duration-700 ${isVisible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"}`}
          >
            Tres pasos.
            <br />
            <span className="text-background/50">Resultados desde el primer día.</span>
          </h2>
        </div>

        <div className="grid lg:grid-cols-2 gap-16 lg:gap-24">
          {/* Steps list */}
          <div className="space-y-0">
            {steps.map((step, index) => {
              const StepIcon = step.icon;
              return (
                <button
                  key={step.number}
                  type="button"
                  onClick={() => setActiveStep(index)}
                  className={`w-full text-left py-8 border-b border-background/10 transition-all duration-500 group ${activeStep === index ? "opacity-100" : "opacity-40 hover:opacity-70"}`}
                >
                  <div className="flex items-start gap-6">
                    <span className="font-display text-3xl text-background/30 shrink-0">{step.number}</span>
                    <div className="flex-1">
                      <div className="flex items-center gap-3 mb-3">
                        <StepIcon className="w-5 h-5 text-background/60" />
                        <h3 className="text-2xl lg:text-3xl font-display group-hover:translate-x-2 transition-transform duration-300">
                          {step.title}
                        </h3>
                      </div>
                      <p className="text-background/60 leading-relaxed">
                        {step.description}
                      </p>
                      {activeStep === index && (
                        <div className="mt-4 h-px bg-background/20 overflow-hidden">
                          <div
                            className="h-full bg-background w-0"
                            style={{ animation: 'progress 5s linear forwards' }}
                          />
                        </div>
                      )}
                    </div>
                  </div>
                </button>
              );
            })}
          </div>

          {/* Detail panel — no code, just a visual card */}
          <div className="lg:sticky lg:top-32 self-start">
            <div className="border border-background/10 overflow-hidden">
              {/* Panel header */}
              <div className="px-6 py-4 border-b border-background/10 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full border border-background/20 flex items-center justify-center">
                    <ActiveIcon className="w-4 h-4 text-background/70" />
                  </div>
                  <span className="text-sm font-medium">{active.title}</span>
                </div>
                <span className="text-xs font-mono text-background/40">
                  paso {activeStep + 1}/{steps.length}
                </span>
              </div>

              {/* Detail list */}
              <div className="p-8 min-h-[280px]">
                <ul className="space-y-4">
                  {active.detail.map((item, i) => (
                    <li
                      key={i}
                      className="flex items-start gap-3 text-background/70"
                      style={{ animation: `fadeInLeft 0.4s ease forwards`, animationDelay: `${i * 80}ms`, opacity: 0 }}
                    >
                      <span className="mt-1.5 w-1.5 h-1.5 rounded-full bg-background/50 shrink-0" />
                      <span className="text-sm leading-relaxed">{item}</span>
                    </li>
                  ))}
                </ul>
              </div>

              {/* Status footer */}
              <div className="px-6 py-4 border-t border-background/10 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <span className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
                  <span className="text-xs font-mono text-background/50">{active.status}</span>
                </div>
                <span className="text-xs font-mono text-background/70 font-medium">{active.statusValue}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <style jsx>{`
        @keyframes progress {
          from { width: 0%; }
          to { width: 100%; }
        }
        @keyframes fadeInLeft {
          from { opacity: 0; transform: translateX(-8px); }
          to { opacity: 1; transform: translateX(0); }
        }
      `}</style>
    </section>
  );
}
