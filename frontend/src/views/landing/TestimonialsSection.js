import { useEffect, useRef, useState } from 'react';
import { NOISE_SVG } from './_constants';

const TESTIMONIALS = [
  {
    quote: "Mes clients PME connectent leur boîte. Leurs factures fournisseurs arrivent automatiquement. Je gagne 120h/mois. Zéro relance.",
    name: "Pierre M.",
    role: "Cabinet comptable, 80 dossiers",
    avatar: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=600&h=600&fit=crop&crop=face",
    color: '#466cf3',
  },
  {
    quote: "Extraction HT/TVA instantanée. Rapprochement auto. Export FEC conforme 2026 en 2 clics. Je passe enfin du temps à auditer, pas à ressaisir.",
    name: "Valérie D.",
    role: "Collaboratrice comptable",
    avatar: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=600&h=600&fit=crop&crop=face",
    color: '#f59e0b',
  },
  {
    quote: "Zéro erreur de saisie. Zéro facture oubliée. Dossiers exportés conformes 2026 sans retouche. Zéro réclamation client.",
    name: "Marc T.",
    role: "Gérant, petit cabinet",
    avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&h=600&fit=crop&crop=face",
    color: '#10b981',
  },
];

const STATS = [
  { end: 2,    prefix: '',  suffix: 'M+', label: 'Factures traitées' },
  { end: 120,  prefix: '',  suffix: 'h',  label: 'Gagnées / cabinet / mois' },
  { end: 4.9,  prefix: '',  suffix: '/5', label: 'Note cabinets comptables', decimals: 1 },
  { end: 300,  prefix: '+', suffix: '',   label: 'Banques compatibles' },
];

function Counter({ end, prefix, suffix, decimals = 0, duration = 1800 }) {
  const [count, setCount] = useState(0);
  const ref = useRef(null);
  const started = useRef(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && !started.current) {
          started.current = true;
          if (prefersReduced) {
            setCount(end);
            return;
          }
          const startTime = performance.now();
          const tick = (now) => {
            const elapsed = now - startTime;
            const progress = Math.min(elapsed / duration, 1);
            const eased = 1 - Math.pow(1 - progress, 3);
            setCount(parseFloat((eased * end).toFixed(decimals)));
            if (progress < 1) requestAnimationFrame(tick);
          };
          requestAnimationFrame(tick);
        }
      },
      { threshold: 0.5 }
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, [end, duration, decimals]);

  return (
    <span ref={ref}>
      {prefix}{decimals > 0 ? count.toFixed(decimals) : count}{suffix}
    </span>
  );
}

export default function TestimonialsSection() {
  return (
    <section id="testimonials" className="bg-[#181818] scroll-mt-20">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-20 lg:py-28">

        <div className="text-center mb-16">
          <span className="inline-block px-3 py-1 text-xs text-white/60 bg-white/10 border border-white/10 rounded-full mb-4">
            Témoignages
          </span>
          <h2 className="text-3xl sm:text-4xl font-medium text-white tracking-tight">
            Pourquoi les cabinets passent à FactPilot
          </h2>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-0">
          {TESTIMONIALS.map((t) => (
            <div key={t.name} className="relative overflow-hidden min-h-[400px] sm:min-h-[480px]" style={{ backgroundColor: t.color }}>
              <img src={t.avatar} alt={t.name} className="absolute inset-0 w-full h-full object-cover object-top mix-blend-luminosity opacity-70" />
              <div className="absolute inset-0 opacity-[0.35] pointer-events-none" style={{ backgroundImage: NOISE_SVG }} />
              <div className="absolute inset-0 pointer-events-none" style={{ background: `radial-gradient(circle at center, rgba(255,255,255,0.3) 0%, transparent 40%, ${t.color} 75%)` }} />
              <div className="absolute top-5 right-5 text-right">
                <p className="text-sm font-semibold text-white">{t.name}</p>
                <p className="text-xs text-white/70">{t.role}</p>
              </div>
              <div className="absolute bottom-0 left-0 right-0 p-6">
                <p className="text-base sm:text-lg font-medium text-white leading-snug">
                  "{t.quote}"
                </p>
              </div>
            </div>
          ))}
        </div>

        <div className="mt-0 grid grid-cols-2 lg:grid-cols-4 border border-white/10 border-t-0">
          {STATS.map((s, i) => (
            <div key={s.label} className={`flex flex-col items-center gap-2 py-8 px-4 text-center ${i > 0 ? 'border-l border-white/10' : ''}`}>
              <p className="text-2xl sm:text-3xl font-semibold text-white tracking-tight tabular-nums">
                <Counter end={s.end} prefix={s.prefix} suffix={s.suffix} decimals={s.decimals} />
              </p>
              <p className="text-xs text-white/60 leading-snug max-w-[120px]">{s.label}</p>
            </div>
          ))}
        </div>

      </div>
    </section>
  );
}
