import { useState, useEffect, useRef } from 'react';
import { FEATURES } from './_data';

export default function ToolsSection() {
  const [active, setActive] = useState(0);
  const itemRefs = useRef([]);

  useEffect(() => {
    const observers = itemRefs.current.map((el, i) => {
      if (!el) return null;
      const obs = new IntersectionObserver(
        ([entry]) => { if (entry.isIntersecting) setActive(i); },
        { threshold: 0.5 }
      );
      obs.observe(el);
      return obs;
    });
    return () => observers.forEach((obs) => obs && obs.disconnect());
  }, []);

  return (
    <section className="bg-white">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-12 lg:py-28">

        {/* Mobile header */}
        <div className="lg:hidden mb-8">
          <span className="inline-block px-3 py-1 text-xs text-[#46484d] bg-white/60 backdrop-blur-md border border-[#6c6f761f] shadow-sm rounded-full mb-4">
            Boîte à outils
          </span>
          <h2 className="text-2xl font-medium text-[#181818] tracking-tight leading-tight mb-2">
            Tout ce dont vous avez besoin
          </h2>
          <p className="text-sm text-[#46484d]/60">
            Autocontable simplifie la gestion comptable grâce à l'intelligence artificielle.
          </p>
        </div>

        <div className="grid lg:grid-cols-2 gap-0 lg:gap-20">

          {/* Left — sticky (desktop only) */}
          <div className="hidden lg:flex flex-col">
            <div className="sticky top-28">
              <span className="inline-block px-3 py-1 text-xs text-[#46484d] bg-white/60 backdrop-blur-md border border-white shadow-sm rounded-full mb-6">
                Boîte à outils
              </span>
              <h2 className="text-3xl sm:text-4xl font-medium text-[#181818] tracking-tight leading-tight mb-3">
                Tout ce dont vous avez besoin
              </h2>
              <p className="text-sm text-[#46484d]/60 mb-10 max-w-xs">
                Autocontable simplifie la gestion comptable grâce à l'intelligence artificielle.
              </p>
              <div className="flex flex-col">
                {FEATURES.map((f, i) => (
                  <div key={f.title} className="relative py-4 pl-5">
                    <div className={`absolute left-0 top-0 bottom-0 w-[2px] rounded-full transition-all duration-300 ${active === i ? 'bg-[#466cf3]' : 'bg-[#6c6f761f]'}`} />
                    <p className={`text-sm font-medium transition-colors duration-300 ${active === i ? 'text-[#181818]' : 'text-[#46484d]/40'}`}>
                      {f.title}
                    </p>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Right — scrollable items */}
          <div className="border-x border-[#6c6f761f] divide-y divide-[#6c6f761f] -mx-4 sm:-mx-6 lg:mx-0 lg:-my-28 lg:py-28">
            {FEATURES.map((f, i) => (
              <div
                key={f.title}
                ref={(el) => (itemRefs.current[i] = el)}
                className="flex flex-col gap-3 py-6 px-4 sm:px-6 bg-white"
              >
                <div>
                  <h3 className="text-sm font-semibold text-[#181818] mb-1">{f.title}</h3>
                  <p className="text-xs text-[#46484d]/70 leading-relaxed">{f.description}</p>
                </div>
                <div className="relative border border-[#6c6f761f] overflow-hidden bg-[#fafafa] min-h-[180px] sm:min-h-[220px] lg:min-h-[280px]">
                  <div className="absolute top-4 left-4 w-[130%] rounded-xl border border-[#6c6f761f] overflow-hidden shadow-sm">
                    <img src={f.image} alt={f.title} className="w-full h-auto block" />
                  </div>
                  <div className="absolute inset-x-0 bottom-0 h-16 bg-gradient-to-t from-[#fafafa] to-transparent pointer-events-none" />
                </div>
              </div>
            ))}
          </div>

        </div>
      </div>
    </section>
  );
}
