import React from 'react';
import { Plug, Cpu, CheckCircle2 } from 'lucide-react';

const STEPS = [
  {
    icon: Plug,
    number: '01',
    title: 'Connectez vos sources',
    description:
      'Reliez votre boîte email professionnelle et votre compte bancaire en quelques clics.',
  },
  {
    icon: Cpu,
    number: '02',
    title: "Laissez l'IA travailler",
    description:
      'Notre moteur extrait, classe et rapproche automatiquement vos factures avec vos transactions.',
  },
  {
    icon: CheckCircle2,
    number: '03',
    title: 'Validez et exportez',
    description:
      'Contrôlez les rapprochements, ajustez si besoin, puis exportez vers votre comptabilité.',
  },
];

const HowItWorksSection = () => (
  <section
    id="how-it-works"
    aria-label="Comment ça marche"
    className="bg-slate-50 pt-24 pb-16 lg:pt-[140px] lg:pb-[100px] scroll-mt-24"
  >
    <div className="max-w-7xl mx-auto px-6">
      <div className="mx-auto mb-16 max-w-[520px] text-center lg:mb-[90px]">
        <span className="mb-2 block text-[9px] font-semibold uppercase tracking-wider text-blue-600">
          Comment ça marche
        </span>
        <h2 className="mb-3 text-2xl sm:text-3xl md:text-[32px] md:leading-[1.2] font-bold text-slate-900">
          Votre comptabilité en 3 étapes
        </h2>
        <p className="text-base text-slate-600">
          De la collecte des factures à l'export comptable, en moins de cinq minutes.
        </p>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-0 border border-slate-200 rounded-xl overflow-hidden">
        {STEPS.map((step, index) => {
          const Icon = step.icon;
          return (
            <div
              key={step.number}
              className={`text-center p-8 ${index !== STEPS.length - 1 ? 'border-b md:border-b-0 md:border-r border-slate-200' : ''}`}
            >
              <div className="inline-flex h-10 w-10 items-center justify-center rounded-lg bg-blue-600/80 backdrop-blur-sm mb-4">
                <Icon className="w-5 h-5 text-white" strokeWidth={2} />
              </div>
              <h3 className="mb-2 text-base font-bold text-slate-900">{step.title}</h3>
              <p className="text-sm text-slate-600 leading-relaxed">
                {step.description}
              </p>
            </div>
          );
        })}
      </div>
    </div>
  </section>
);

export default HowItWorksSection;
