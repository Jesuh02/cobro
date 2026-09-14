"use client";

import { useEffect, useRef, useState } from "react";

const features = [
  {
    number: "01",
    title: "Cobros Automatizados",
    description: "Configura una vez y deja que el sistema trabaje por ti. Recordatorios automáticos por WhatsApp y email que se envían en el momento exacto, sin intervención manual.",
    visual: "deploy",
  },
  {
    number: "02",
    title: "Gestión de Cartera",
    description: "Visualiza el estado de cada cliente, sus cuotas pendientes y su historial de pagos en tiempo real. Control total de tu cartera de crédito en un solo lugar.",
    visual: "collab",
  },
  {
    number: "03",
    title: "Notificaciones Multicanal",
    description: "Llega a tus clientes donde están: WhatsApp y email. Mensajes personalizados con el nombre del cliente, el monto y la fecha límite de pago.",
    visual: "network",
  },
  {
    number: "04",
    title: "Seguridad Financiera",
    description: "Cifrado bancario para toda tu información. Cumplimiento con las regulaciones financieras colombianas y la Ley de Habeas Data. Tu cartera siempre protegida.",
    visual: "security",
  },
];

function DeployVisual() {
  return (
    <svg viewBox="0 0 200 160" className="w-full h-full">
      <rect x="20" y="20" width="160" height="120" rx="6" fill="none" stroke="currentColor" strokeWidth="2" />
      <rect x="20" y="20" width="160" height="28" rx="6" fill="currentColor" opacity="0.08" />
      <rect x="35" y="30" width="40" height="8" rx="2" fill="currentColor" opacity="0.4" />
      <rect x="140" y="30" width="28" height="8" rx="4" fill="currentColor" opacity="0.6" />
      {[0, 1, 2, 3, 4].map((i) => (
        <g key={i}>
          <rect x="35" y={62 + i * 16} width="10" height="8" rx="1" fill="currentColor" opacity="0.3" />
          <rect x="52" y={62 + i * 16} width="70" height="8" rx="2" fill="currentColor" opacity="0.15">
            <animate attributeName="opacity" values="0.15;0.4;0.15" dur="2s" begin={`${i * 0.3}s`} repeatCount="indefinite" />
          </rect>
          <rect x="140" y={62 + i * 16} width="28" height="8" rx="4" fill="currentColor" opacity={i % 3 === 0 ? "0.6" : i % 3 === 1 ? "0.25" : "0.15"} />
        </g>
      ))}
    </svg>
  );
}

function NetworkVisual() {
  const nodes = [
    { x: 100, y: 40 },
    { x: 50, y: 100 },
    { x: 150, y: 100 },
    { x: 30, y: 140 },
    { x: 170, y: 140 },
  ];
  return (
    <svg viewBox="0 0 200 160" className="w-full h-full">
      {nodes.slice(1).map((node, i) => (
        <line key={i} x1="100" y1="40" x2={node.x} y2={node.y} stroke="currentColor" strokeWidth="1.5" opacity="0.3">
          <animate attributeName="opacity" values="0.3;0.7;0.3" dur="2s" begin={`${i * 0.4}s`} repeatCount="indefinite" />
        </line>
      ))}
      <line x1="50" y1="100" x2="30" y2="140" stroke="currentColor" strokeWidth="1" opacity="0.2" />
      <line x1="150" y1="100" x2="170" y2="140" stroke="currentColor" strokeWidth="1" opacity="0.2" />
      {nodes.map((node, i) => (
        <circle key={i} cx={node.x} cy={node.y} r={i === 0 ? 10 : 6} fill="currentColor" opacity={i === 0 ? "0.9" : "0.5"}>
          {i === 0 && <animate attributeName="r" values="10;12;10" dur="1.5s" repeatCount="indefinite" />}
        </circle>
      ))}
      <text x="100" y="43" textAnchor="middle" fontSize="7" fill="white" fontFamily="monospace">WA</text>
      <text x="50" y="103" textAnchor="middle" fontSize="6" fill="white" fontFamily="monospace">C1</text>
      <text x="150" y="103" textAnchor="middle" fontSize="6" fill="white" fontFamily="monospace">C2</text>
    </svg>
  );
}

function CollabVisual() {
  return (
    <svg viewBox="0 0 200 160" className="w-full h-full">
      <rect x="20" y="15" width="160" height="55" rx="4" fill="none" stroke="currentColor" strokeWidth="1.5" />
      <rect x="20" y="15" width="160" height="18" rx="4" fill="currentColor" opacity="0.08" />
      <rect x="30" y="20" width="30" height="6" rx="2" fill="currentColor" opacity="0.4" />
      {[0, 1, 2].map((i) => (
        <g key={i}>
          <circle cx="32" cy={44 + i * 13} r="4" fill="currentColor" opacity="0.3" />
          <rect x="42" y={40 + i * 13} width="60" height="5" rx="1" fill="currentColor" opacity="0.2" />
          <rect x="150" y={40 + i * 13} width="20" height="5" rx="2" fill="currentColor" opacity={i === 0 ? "0.6" : "0.2"}>
            {i === 0 && <animate attributeName="opacity" values="0.6;1;0.6" dur="1.5s" repeatCount="indefinite" />}
          </rect>
        </g>
      ))}
      <rect x="20" y="90" width="75" height="55" rx="4" fill="none" stroke="currentColor" strokeWidth="1.5" />
      <rect x="105" y="90" width="75" height="55" rx="4" fill="none" stroke="currentColor" strokeWidth="1.5" />
      <rect x="30" y="100" width="40" height="5" rx="1" fill="currentColor" opacity="0.3" />
      <rect x="30" y="110" width="25" height="20" rx="2" fill="currentColor" opacity="0.1" />
      <rect x="60" y="110" width="25" height="20" rx="2" fill="currentColor" opacity="0.2">
        <animate attributeName="opacity" values="0.2;0.5;0.2" dur="2s" repeatCount="indefinite" />
      </rect>
      <rect x="115" y="100" width="40" height="5" rx="1" fill="currentColor" opacity="0.3" />
      <rect x="115" y="110" width="55" height="8" rx="2" fill="currentColor" opacity="0.15" />
      <rect x="115" y="122" width="40" height="8" rx="2" fill="currentColor" opacity="0.15" />
    </svg>
  );
}

function SecurityVisual() {
  return (
    <svg viewBox="0 0 200 160" className="w-full h-full">
      <path d="M 100 20 L 150 40 L 150 90 Q 150 130 100 145 Q 50 130 50 90 L 50 40 Z" fill="none" stroke="currentColor" strokeWidth="2" />
      <path d="M 100 35 L 135 50 L 135 85 Q 135 115 100 128 Q 65 115 65 85 L 65 50 Z" fill="currentColor" opacity="0.1">
        <animate attributeName="opacity" values="0.1;0.2;0.1" dur="2s" repeatCount="indefinite" />
      </path>
      <rect x="85" y="70" width="30" height="25" rx="3" fill="currentColor" />
      <path d="M 90 70 L 90 60 Q 90 50 100 50 Q 110 50 110 60 L 110 70" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" />
      <circle cx="100" cy="80" r="4" fill="white" />
      <rect x="98" y="82" width="4" height="8" fill="white" />
      <line x1="60" y1="60" x2="140" y2="60" stroke="currentColor" strokeWidth="1" opacity="0">
        <animate attributeName="y1" values="40;120;40" dur="3s" repeatCount="indefinite" />
        <animate attributeName="y2" values="40;120;40" dur="3s" repeatCount="indefinite" />
        <animate attributeName="opacity" values="0;0.5;0" dur="3s" repeatCount="indefinite" />
      </line>
    </svg>
  );
}

function AnimatedVisual({ type }: { type: string }) {
  switch (type) {
    case "deploy": return <DeployVisual />;
    case "collab": return <CollabVisual />;
    case "network": return <NetworkVisual />;
    case "security": return <SecurityVisual />;
    default: return <DeployVisual />;
  }
}

function FeatureCard({ feature, index }: { feature: typeof features[0]; index: number }) {
  const [isVisible, setIsVisible] = useState(false);
  const cardRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) setIsVisible(true); },
      { threshold: 0.2 }
    );
    if (cardRef.current) observer.observe(cardRef.current);
    return () => observer.disconnect();
  }, []);

  return (
    <div
      ref={cardRef}
      className={`group relative transition-all duration-700 ${isVisible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-12"}`}
      style={{ transitionDelay: `${index * 100}ms` }}
    >
      <div className="flex flex-col lg:flex-row gap-8 lg:gap-16 py-12 lg:py-20 border-b border-foreground/10">
        <div className="shrink-0">
          <span className="font-mono text-sm text-muted-foreground">{feature.number}</span>
        </div>
        <div className="flex-1 grid lg:grid-cols-2 gap-8 items-center">
          <div>
            <h3 className="text-3xl lg:text-4xl font-display mb-4 group-hover:translate-x-2 transition-transform duration-500">
              {feature.title}
            </h3>
            <p className="text-lg text-muted-foreground leading-relaxed">
              {feature.description}
            </p>
          </div>
          <div className="flex justify-center lg:justify-end">
            <div className="w-48 h-40 text-foreground">
              <AnimatedVisual type={feature.visual} />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export function FeaturesSection() {
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

  return (
    <section id="features" ref={sectionRef} className="relative py-24 lg:py-32">
      <div className="max-w-[1400px] mx-auto px-6 lg:px-12">
        <div className="mb-16 lg:mb-24">
          <span className="inline-flex items-center gap-3 text-sm font-mono text-muted-foreground mb-6">
            <span className="w-8 h-px bg-foreground/30" />
            Capacidades
          </span>
          <h2
            className={`text-4xl lg:text-6xl font-display tracking-tight transition-all duration-700 ${isVisible ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"}`}
          >
            Todo lo que necesitas.
            <br />
            <span className="text-muted-foreground">Sin complicaciones.</span>
          </h2>
        </div>
        <div>
          {features.map((feature, index) => (
            <FeatureCard key={feature.number} feature={feature} index={index} />
          ))}
        </div>
      </div>
    </section>
  );
}
