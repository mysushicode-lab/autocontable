import { useEffect, useRef, useState } from 'react';
import { sectionBadge, sectionHeading } from './_styles';

const TESTIMONIALS = [
  {
    quote: "On a réduit le temps de clôture mensuelle de 3 jours à une demi-journée. Les collaborateurs font enfin du vrai travail d'expert-comptable, pas de la ressaisie.",
    name: "Laurent Morel",
    role: "Expert-comptable, Cabinet Morel & Fils",
    initials: "LM",
  },
  {
    quote: "Le rapprochement d'un dossier complet prenait une journée entière. Maintenant tout un mois tient en 10 minutes. J'ai du mal à croire que c'était aussi long avant.",
    name: "Thomas Legrand",
    role: "DAF, Groupe Legrand Industries",
    initials: "TL",
  },
  {
    quote: "J'avais peur que ce soit compliqué à mettre en place. On était opérationnels en moins d'une heure. Le support répond en moins de 2h.",
    name: "Claire Dubois",
    role: "Responsable comptable, SCI Dubois",
    initials: "CD",
  },
];

const STATS = [
  { end: 2,    prefix: '',  suffix: 'M+', label: 'Documents numérisés' },
  { end: 40,   prefix: '',  suffix: 'h',  label: 'Économisées par cabinet / mois' },
  { end: 4.9,  prefix: '',  suffix: '/5', label: 'Note moyenne clients', decimals: 1 },
  { end: 300,  prefix: '+', suffix: '',   label: 'Banques connectées' },
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
            Ce que disent ceux qui ont arrêté la saisie manuelle
          </h2>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {TESTIMONIALS.map((t) => (
            <blockquote key={t.name} className="bg-white/5 border border-white/10 p-6 flex flex-col gap-6 shadow-[0_1px_3px_rgba(255,255,255,0.04)]">
              <p className="text-sm text-white/80 leading-relaxed">"{t.quote}"</p>
              <div className="flex items-center gap-3 mt-auto">
                <div className="w-9 h-9 rounded-full bg-white/10 shrink-0 flex items-center justify-center">
                  <span className="text-xs font-semibold text-white/80">{t.initials}</span>
                </div>
                <cite className="not-italic">
                  <p className="text-sm font-semibold text-white">{t.name}</p>
                  <p className="text-xs text-white/50">{t.role}</p>
                </cite>
              </div>
            </blockquote>
          ))}
        </div>

        <div className="mt-20 border-t border-white/10 pt-16 grid grid-cols-2 lg:grid-cols-4 gap-10 text-center">
          {STATS.map((s) => (
            <div key={s.label} className="flex flex-col items-center gap-2">
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
