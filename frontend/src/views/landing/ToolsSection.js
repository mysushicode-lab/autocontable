import { useState, useEffect, useRef } from 'react';
import { TOOLS } from './_data';
import { sectionBadge, sectionSubtext } from './_styles';

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
          <span className={sectionBadge}>Proposition de valeur</span>
          <h2 className="text-3xl sm:text-4xl font-medium text-[#181818] tracking-tight leading-tight mb-2">
            Chaque outil pensé pour votre quotidien
          </h2>
          <p className={sectionSubtext}>
            De la réception de la facture jusqu'à l'écriture comptable, chaque étape qui vous prenait du temps se fait désormais sans vous.
          </p>
        </div>

        <div className="grid lg:grid-cols-2 gap-0 lg:gap-20">

          {/* Left — sticky (desktop only) */}
          <div className="hidden lg:flex flex-col">
            <div className="sticky top-28">
              <span className={sectionBadge}>Proposition de valeur</span>
              <h2 className="text-3xl sm:text-4xl font-medium text-[#181818] tracking-tight leading-tight mb-3">
                Chaque outil pensé pour votre quotidien
              </h2>
              <p className={`mb-10 max-w-xs ${sectionSubtext}`}>
                De la réception de la facture jusqu'à l'écriture comptable, chaque étape qui vous prenait du temps se fait désormais sans vous.
              </p>
              <div className="flex flex-col">
                {TOOLS.map((f, i) => (
                  <div key={f.title} className="relative py-4 pl-5">
                    <div className={`absolute left-0 top-0 bottom-0 w-[2px] rounded-full transition-all duration-300 ${active === i ? 'bg-[#466cf3]' : 'bg-[#6c6f7635]'}`} />
                    <p className={`text-sm font-medium transition-colors duration-300 ${active === i ? 'text-[#181818]' : 'text-[#6b7280]'}`}>
                      {f.title}
                    </p>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Right — scrollable items */}
          <div className="relative border-x border-[#6c6f7635] divide-y divide-[#6c6f7635] -mx-4 sm:-mx-6 lg:mx-0 lg:-my-28 lg:py-28 bg-white">
            <div className="absolute inset-0 opacity-[0.06] pointer-events-none" style={{ backgroundImage: "url(\"data:image/svg+xml,%3Csvg viewBox='0 0 300 300' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='1.5' numOctaves='5' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E\")" }} />
            {TOOLS.map((f, i) => (
              <div
                key={f.title}
                ref={(el) => (itemRefs.current[i] = el)}
                className="relative flex flex-col gap-3 py-6 px-4 sm:px-6"
              >
                <div>
                  <h3 className="text-sm font-semibold text-[#181818] mb-1">{f.title}</h3>
                  <p className={sectionSubtext}>{f.description}</p>
                </div>
                <div className="relative border border-[#6c6f7635] overflow-hidden bg-[#fafafa] min-h-[180px] sm:min-h-[220px] lg:min-h-[280px]">
                  <div className="absolute top-4 left-4 w-[130%] rounded-xl border border-[#6c6f7635] overflow-hidden shadow-sm">
                    <img src={f.image} alt={f.title} className="w-full h-auto block" />
                  </div>
                  <div className="absolute inset-x-0 bottom-0 h-8 bg-gradient-to-t from-[#fafafa]/60 to-transparent pointer-events-none" />
                </div>
              </div>
            ))}
          </div>

        </div>
      </div>
    </section>
  );
}
