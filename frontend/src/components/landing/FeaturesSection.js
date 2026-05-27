import React, { useState } from 'react';

const FEATURES = [
  {
    id: 'email',
    title: 'Récupération automatique',
    description:
      'Vos factures fournisseurs sont importées automatiquement depuis votre boîte email.',
    image: '/capture-161409.png',
  },
  {
    id: 'ai',
    title: 'Rapprochement IA',
    description:
      "Notre IA rapproche factures et transactions bancaires en quelques secondes.",
    image: '/capture-161601.png',
  },
  {
    id: 'export',
    title: 'Exports comptables',
    description:
      'Exportez vos données vers Excel ou CSV, prêtes pour votre expert-comptable.',
    image: '/capture-161747.png',
  },
  {
    id: 'team',
    title: 'Collaboration équipe',
    description:
      'Invitez vos collaborateurs dans un espace de travail multi-utilisateurs sécurisé.',
    image: '/capture-161954.png',
  },
];

const FeaturesSection = () => {
  const [hoveredId, setHoveredId] = useState(FEATURES[0].id);
  const activeFeature = FEATURES.find((f) => f.id === hoveredId);

  return (
    <section
      id="features"
      aria-label="Fonctionnalités"
      className="bg-white pt-24 pb-16 lg:pt-[140px] lg:pb-[100px] scroll-mt-24"
    >
      <div className="max-w-7xl mx-auto px-6">
        <div className="mx-auto mb-16 max-w-[520px] text-center lg:mb-[90px]">
          <span className="mb-2 block text-[9px] font-semibold uppercase tracking-wider text-blue-600">
            Fonctionnalités
          </span>
          <h2 className="mb-3 text-2xl sm:text-3xl md:text-[32px] md:leading-[1.2] font-bold text-slate-900">
            Tout ce qu'il faut pour automatiser votre comptabilité
          </h2>
          <p className="text-base text-slate-600">
            Une plateforme complète pour collecter, traiter, rapprocher et exporter vos données comptables.
          </p>
        </div>
        <div className="max-w-4xl mx-auto">
          <div className="border border-slate-200 rounded-xl overflow-hidden">
            <div className="grid grid-cols-1 lg:grid-cols-2">
              <div>
                {FEATURES.map((feature, index) => (
                  <div
                    key={feature.id}
                    onMouseEnter={() => setHoveredId(feature.id)}
                    className={`group py-6 px-6 transition-colors ${
                      index !== FEATURES.length - 1 ? 'border-b border-slate-200' : ''
                    } ${hoveredId === feature.id ? 'bg-slate-50' : ''}`}
                  >
                    <div className="flex items-start gap-3">
                      <span
                        className={`w-2 h-2 rounded-full mt-2 transition-colors ${
                          hoveredId === feature.id ? 'bg-blue-600' : 'bg-slate-300'
                        }`}
                      />
                      <div className="flex-1">
                        <h3 className="text-lg font-medium text-slate-900 group-hover:text-blue-600 transition-colors">
                          {feature.title}
                        </h3>
                        {hoveredId === feature.id && (
                          <p className="mt-2 text-base text-slate-600 leading-relaxed">
                            {feature.description}
                          </p>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
              <div className="relative h-full min-h-[400px] overflow-hidden bg-blue-900">
                <img
                  src={activeFeature.image}
                  alt={activeFeature.title}
                  className="w-full h-full object-contain p-4 transition-opacity duration-300"
                  key={activeFeature.id}
                />
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default FeaturesSection;
