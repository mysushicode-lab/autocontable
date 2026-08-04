import { useState } from 'react';
import { Users, Zap, Target, Clock } from 'lucide-react';
import { FEATURES, STATS } from './_data';
import { sectionBadge, sectionHeading } from './_styles';
import { NOISE_SVG } from './_constants';

const STAT_ICONS   = { users: Users, zap: Zap, target: Target, clock: Clock };
const STAT_ANIMATE = {
  users:  'animate-bounce',
  zap:    'animate-pulse',
  target: 'animate-spin',
  clock:  'animate-spin',
};

export default function FeaturesSection() {
  const [active, setActive] = useState(0);

  return (
    <section id="features" className="bg-[#f7f7f5] scroll-mt-20">

      <div className="max-w-7xl mx-auto px-4 sm:px-6 pt-20 lg:pt-28">
        <div className="text-center mb-12">
          <span className={sectionBadge}>Le pipeline complet</span>
          <h2 className={sectionHeading}>Autocontable : La comptabilité qui travaille pendant que vous travaillez</h2>
        </div>
      </div>

      <div className="relative max-w-6xl mx-auto px-4 sm:px-6">
        <div className="bg-white border border-[#6c6f7635] rounded-t-2xl" style={{overflow: 'clip'}}>
          <div className="grid lg:grid-cols-2">
            <div className="flex flex-col divide-y divide-[#6c6f760f] h-full">
              {FEATURES.map((f, i) => (
                <button
                  key={f.title}
                  type="button"
                  onMouseEnter={() => setActive(i)}
                  onClick={() => setActive(i)}
                  aria-pressed={active === i}
                  className={`relative flex-1 text-left px-6 py-6 flex flex-col justify-center transition-colors ${active === i ? 'bg-white' : 'bg-[#fafafa]'}`}
                >
                  <p className={`text-sm font-semibold mb-2 ${active === i ? 'text-[#181818]' : 'text-[#46484d]'}`}>{f.title}</p>
                  <p className="text-sm text-[#6b7280]">{f.description}</p>
                  {active === i && (
                    <span
                      className="progress-fill-bar absolute bottom-0 left-0 h-[2px] bg-[#466cf3]"
                      style={{ animation: 'progress-fill 0.5s cubic-bezier(0.22, 1, 0.36, 1) forwards' }}
                    />
                  )}
                </button>
              ))}
            </div>

            <div className="relative border-l border-[#6c6f760f] overflow-hidden self-stretch min-h-[240px] sm:min-h-[360px] lg:min-h-[500px] bg-[#fafafa]">
              <div className="absolute inset-0 opacity-[0.08] pointer-events-none" style={{ backgroundImage: NOISE_SVG }} />
              <div className="absolute top-6 left-4 sm:top-10 sm:left-8 w-[180%] sm:w-[250%] rounded-xl border border-[#6c6f7635] overflow-hidden">
                <img
                  src={FEATURES[active].image}
                  alt={FEATURES[active].title}
                  className="w-full h-auto block"
                />
              </div>
            </div>
          </div>

          <div className="grid grid-cols-2 lg:grid-cols-4 divide-x divide-[#6c6f760f] border-t border-[#6c6f7635]">
            {STATS.map((s) => {
              const StatIcon = STAT_ICONS[s.icon];
              return (
                <div key={s.label} className="text-center px-6 py-5 flex flex-col items-center gap-1">
                  <div className="flex items-center gap-1.5">
                    <StatIcon className={`w-4 h-4 text-[#466cf3] ${STAT_ANIMATE[s.icon]}`} strokeWidth={1.5} aria-hidden="true" />
                    <p className="text-xl font-medium text-[#181818] leading-none">{s.value}</p>
                  </div>
                  <p className="text-xs text-[#6b7280]">{s.label}</p>
                </div>
              );
            })}
          </div>
        </div>
        <div className="absolute bottom-0 left-0 right-0 h-6 bg-gradient-to-t from-[#f7f7f5] to-transparent pointer-events-none" />
      </div>
      <div className="pb-20 lg:pb-28" />
    </section>
  );
}
