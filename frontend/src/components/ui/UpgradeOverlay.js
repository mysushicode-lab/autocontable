'use client';

import React from 'react';
import { Lock, ArrowUpRight } from 'lucide-react';
import { useRouter } from 'next/navigation';

const PLAN_LABELS = {
  pro: 'Pro',
  cabinet: 'Cabinet',
  reseau: 'Réseau',
};

const UpgradeOverlay = ({ requiredPlan = 'pro', featureName = 'cette fonctionnalité' }) => {
  const router = useRouter();

  return (
    <div className="absolute inset-0 z-40 flex items-center justify-center bg-white/80 backdrop-blur-sm rounded-lg">
      <div className="text-center p-6 max-w-sm">
        <div className="w-12 h-12 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <Lock className="w-6 h-6 text-gray-400" />
        </div>
        <h3 className="text-sm font-semibold text-gray-900 mb-1">
          Plan {PLAN_LABELS[requiredPlan] || requiredPlan} requis
        </h3>
        <p className="text-xs text-gray-500 mb-4">
          {featureName} est disponible à partir du plan {PLAN_LABELS[requiredPlan]}.
        </p>
        <button
          onClick={() => router.push('/settings?tab=billing')}
          className="inline-flex items-center gap-1.5 px-4 py-2 bg-gray-900 text-white text-xs font-medium rounded-md hover:bg-gray-800 transition-colors"
        >
          Passer au plan supérieur
          <ArrowUpRight className="w-3.5 h-3.5" />
        </button>
      </div>
    </div>
  );
};

export default UpgradeOverlay;
