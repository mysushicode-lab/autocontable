import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { Zap, AlertTriangle } from 'lucide-react';
import { fetchPlanStatus } from '../api';
import { useAuth } from '../context/AuthContext';

export const QuotaBadge = () => {
  const { user } = useAuth();

  const { data } = useQuery({
    queryKey: ['plan-status'],
    queryFn: fetchPlanStatus,
    enabled: !!user, // Only fetch if user is logged in
    refetchInterval: 60000, // Refresh every minute
  });

  if (!data || !user) return null;

  const { quota, used, remaining } = data;

  // Plan illimité (réseau)
  if (quota === null) {
    return (
      <div className="flex items-center gap-2 px-3 py-1.5 bg-gradient-to-r from-blue-50 to-purple-50 border border-blue-200 rounded-full">
        <Zap className="w-3.5 h-3.5 text-blue-600" />
        <span className="text-xs font-medium text-gray-700">Factures illimitées</span>
      </div>
    );
  }

  // Calculer le pourcentage utilisé
  const percentage = (used / quota) * 100;
  const isLow = remaining <= quota * 0.1; // Alerte si < 10% restant
  const isCritical = remaining === 0;

  return (
    <div className={`flex items-center gap-2 px-3 py-1.5 rounded-full border ${
      isCritical
        ? 'bg-red-50 border-red-200'
        : isLow
        ? 'bg-orange-50 border-orange-200'
        : 'bg-gray-50 border-gray-200'
    }`}>
      {(isLow || isCritical) && <AlertTriangle className={`w-3.5 h-3.5 ${isCritical ? 'text-red-600' : 'text-orange-600'}`} />}
      <Zap className={`w-3.5 h-3.5 ${isCritical ? 'text-red-600' : isLow ? 'text-orange-600' : 'text-gray-600'}`} />
      <span className={`text-xs font-medium ${isCritical ? 'text-red-700' : isLow ? 'text-orange-700' : 'text-gray-700'}`}>
        {used} / {quota} factures IA
      </span>
      {isCritical && (
        <a href="/settings?section=plan" className="text-xs font-semibold text-red-600 hover:underline ml-1">
          Upgrader
        </a>
      )}
    </div>
  );
};
