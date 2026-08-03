import React, { useState } from 'react';
import { useQuery } from 'react-query';
import {
  FileText,
  TrendingUp,
  Clock,
  DollarSign,
  BarChart3,
  CheckCircle,
  Folder,
  Activity,
} from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip as RechartsTooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import { fetchAnalytics, fetchMonthlyTrend } from '../api';
import { CHART_COLORS_ARRAY } from '../constants/colors';
import HelpTooltip from '../components/ui/HelpTooltip';
import { usePlanGate } from '../hooks/usePlanGate';
import UpgradeOverlay from '../components/ui/UpgradeOverlay';

const COLORS = CHART_COLORS_ARRAY;

const Analytics = () => {
  const [trendMonths, setTrendMonths] = useState(6);
  const { canAccess, getRequiredPlan } = usePlanGate();

  const { data: analytics, isLoading } = useQuery(['analytics'], fetchAnalytics);
  const { data: trendData } = useQuery(['analytics-trend', trendMonths], () => fetchMonthlyTrend(trendMonths));

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-sm text-gray-500">Chargement des analytics...</div>
      </div>
    );
  }

  const totals = analytics?.totals || {};
  const automation = analytics?.automation || {};
  const savings = analytics?.savings || {};
  const dossiers = analytics?.dossiers || [];
  const trends = trendData?.trends || [];

  const automationData = [
    { name: 'Automatique', value: automation.auto_matches || 0, color: COLORS[0] },
    { name: 'Manuel', value: automation.manual_matches || 0, color: COLORS[1] },
  ];

  return (
    <div className="relative space-y-6">
      {!canAccess('analytics') && (
        <UpgradeOverlay requiredPlan={getRequiredPlan('analytics')} featureName="Analytics" />
      )}
      {/* Header */}
      <div>
        <div className="flex items-center gap-1.5">
          <h1 className="text-lg font-semibold text-gray-900">Analytics</h1>
          <HelpTooltip text="Métriques opérationnelles pour suivre l'efficacité du système de traitement automatique des factures." />
        </div>
        <p className="text-xs text-gray-500 mt-0.5">Suivi des performances et du ROI</p>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <KpiCard
          title="Factures traitées"
          value={totals.invoices || 0}
          icon={FileText}
          color="blue"
        />
        <KpiCard
          title="Taux de rapprochement"
          value={`${totals.match_rate || 0}%`}
          icon={CheckCircle}
          color="green"
        />
        <KpiCard
          title="Temps gagné"
          value={`${savings.time_saved_hours || 0}h`}
          icon={Clock}
          color="purple"
        />
        <KpiCard
          title="Coût IA"
          value={`${savings.ai_cost_eur || 0}€`}
          icon={DollarSign}
          color="orange"
        />
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Monthly Trend */}
        <div className="rounded-md border border-gray-100 bg-white p-6 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-gray-900">Factures traitées par mois</h3>
            <select
              value={trendMonths}
              onChange={(e) => setTrendMonths(Number(e.target.value))}
              className="text-sm border border-gray-200 rounded px-2 py-1"
            >
              <option value={3}>3 mois</option>
              <option value={6}>6 mois</option>
              <option value={12}>12 mois</option>
            </select>
          </div>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={trends}>
                <XAxis dataKey="label" tick={{ fontSize: 12 }} interval={0} angle={-45} textAnchor="end" height={60} />
                <YAxis />
                <RechartsTooltip />
                <Bar dataKey="invoices" fill="#3b82f6" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Automation Rate */}
        <div className="rounded-md border border-gray-100 bg-white p-6 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-gray-900">Taux d'automatisation</h3>
            <span className="text-2xl font-bold text-blue-600">{automation.automation_rate || 0}%</span>
          </div>
          {automationData.some(d => d.value > 0) ? (
            <div className="flex gap-4">
              <div className="h-52 flex-shrink-0" style={{ width: 180 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={automationData}
                      cx="50%"
                      cy="50%"
                      outerRadius={80}
                      dataKey="value"
                      nameKey="name"
                    >
                      {automationData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <RechartsTooltip />
                  </PieChart>
                </ResponsiveContainer>
              </div>
              <div className="flex-1 flex flex-col justify-center gap-2">
                {automationData.map((entry, index) => (
                  <div key={index} className="flex items-center gap-2 text-sm">
                    <span className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ backgroundColor: entry.color }} />
                    <span className="text-gray-700 flex-1">{entry.name}</span>
                    <span className="text-gray-900 font-medium">{entry.value}</span>
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <div className="h-52 flex items-center justify-center text-sm text-gray-500">Aucune donnée</div>
          )}
        </div>
      </div>

      {/* Dossiers Table */}
      <div className="rounded-md border border-gray-100 bg-white p-6 shadow-sm">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-semibold text-gray-900">Performance par dossier</h3>
          <Folder className="w-5 h-5 text-gray-400" />
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Dossier</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Factures</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Rapprochées</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Taux</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {dossiers.map((dossier) => (
                <tr key={dossier.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 font-medium text-gray-900">{dossier.name}</td>
                  <td className="px-6 py-4 text-gray-700">{dossier.invoices}</td>
                  <td className="px-6 py-4 text-gray-700">{dossier.matched}</td>
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-2">
                      <div className="w-24 bg-gray-200 rounded-full h-1.5">
                        <div
                          className="bg-green-600 h-1.5 rounded-full"
                          style={{ width: `${dossier.rate}%` }}
                        />
                      </div>
                      <span className="text-gray-900 font-medium">{dossier.rate}%</span>
                    </div>
                  </td>
                </tr>
              ))}
              {dossiers.length === 0 && (
                <tr>
                  <td colSpan="4" className="px-6 py-8 text-center text-sm text-gray-500">Aucun dossier.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Savings Info */}
      <div className="bg-blue-50 rounded-md p-6 border border-blue-100">
        <div className="flex items-start gap-4">
          <div className="p-3 bg-blue-100 rounded-md">
            <Activity className="w-6 h-6 text-blue-600" />
          </div>
          <div className="flex-1">
            <h3 className="font-semibold text-gray-900 mb-2">Estimation des gains</h3>
            <p className="text-sm text-gray-700 mb-3">
              Le système a traité <strong>{totals.invoices || 0} factures</strong> avec l'IA,
              économisant environ <strong>{savings.time_saved_hours || 0} heures</strong> de saisie manuelle.
            </p>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-sm">
              <div>
                <div className="text-gray-500">Temps manuel estimé</div>
                <div className="text-lg font-semibold text-gray-900">{Math.round((totals.invoices || 0) * 3 / 60)}h</div>
              </div>
              <div>
                <div className="text-gray-500">Temps avec IA</div>
                <div className="text-lg font-semibold text-gray-900">{Math.round((totals.invoices || 0) * 0.25 / 60)}h</div>
              </div>
              <div>
                <div className="text-gray-500">Coût IA total</div>
                <div className="text-lg font-semibold text-gray-900">{savings.ai_cost_eur || 0}€</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

const KpiCard = ({ title, value, icon: Icon, color = 'blue' }) => {
  const colorClasses = {
    blue: 'bg-blue-50 text-blue-600',
    green: 'bg-green-50 text-green-600',
    purple: 'bg-purple-50 text-purple-600',
    orange: 'bg-orange-50 text-orange-600',
  };

  return (
    <div className="rounded-md border border-gray-100 bg-white p-6 shadow-sm">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-gray-600">{title}</p>
          <p className="text-2xl font-bold text-gray-900 mt-1">{value}</p>
        </div>
        <div className={`p-3 rounded-md ${colorClasses[color]}`}>
          <Icon className="w-5 h-5" />
        </div>
      </div>
    </div>
  );
};

export default Analytics;
