'use client';

import React, { useState, useRef, useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
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
import IconBox from '../components/ui/IconBox';
import { usePlanGate } from '../hooks/usePlanGate';
import UpgradeOverlay from '../components/ui/UpgradeOverlay';
import { useFilters } from '../context/FilterContext';
import DropdownButton from '../components/DropdownButton';
import { generateMonthOptions } from '../utils/dateHelpers';

const COLORS = CHART_COLORS_ARRAY;

const Analytics = () => {
  const [trendMonths, setTrendMonths] = useState(6);
  const { selectedMonth, setSelectedMonth } = useFilters();
  const [showMonthDropdown, setShowMonthDropdown] = useState(false);
  const [showTrendDropdown, setShowTrendDropdown] = useState(false);
  const monthButtonRef = useRef(null);
  const trendButtonRef = useRef(null);
  const { canAccess, getRequiredPlan, billing } = usePlanGate();

  const today = new Date();
  const globalPeriod = selectedMonth !== undefined ? selectedMonth : `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;

  const periodOptions = [
    { value: '', label: 'Toutes périodes' },
    ...generateMonthOptions(12),
  ];

  const trendOptions = [
    { value: 3, label: '3 mois' },
    { value: 6, label: '6 mois' },
    { value: 12, label: '12 mois' },
    { value: 24, label: 'Tout' },
  ];

  const filters = useMemo(() => {
    if (!globalPeriod) return {};
    const [year, month] = globalPeriod.split('-').map(Number);
    return { month, year };
  }, [globalPeriod]);

  const periodLabel = periodOptions.find(o => o.value === globalPeriod)?.label || 'Toutes périodes';
  const periodDisplay = periodLabel.charAt(0).toUpperCase() + periodLabel.slice(1);

  const hasAccess = billing ? canAccess('analytics') : false;

  const { data: analytics, isLoading } = useQuery({
    queryKey: ['analytics', filters],
    queryFn: () => fetchAnalytics(filters),
    enabled: hasAccess,
  });
  const { data: trendData } = useQuery({
    queryKey: ['analytics-trend', trendMonths],
    queryFn: () => fetchMonthlyTrend(trendMonths),
    enabled: hasAccess,
  });

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
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div>
          <div className="flex items-center gap-1.5">
            <h1 className="text-lg font-semibold text-gray-900">Analytics</h1>
            <HelpTooltip text="Métriques opérationnelles pour suivre l'efficacité du système de traitement automatique des factures." />
          </div>
          <p className="text-xs text-gray-500 mt-0.5">Suivi des performances et du ROI</p>
        </div>
        <div className="flex gap-3 items-center">
          <DropdownButton
            label={periodOptions.find(o => o.value === globalPeriod)?.label || 'Toutes périodes'}
            value={globalPeriod}
            options={periodOptions}
            onChange={setSelectedMonth}
            isOpen={showMonthDropdown}
            onToggle={() => setShowMonthDropdown(!showMonthDropdown)}
            buttonRef={monthButtonRef}
            width="200px"
          />
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 border border-gray-200 rounded-lg overflow-hidden bg-white divide-y md:divide-y-0 md:divide-x divide-gray-200">
        <KpiCard
          title="Factures traitées"
          value={totals.invoices || 0}
          icon={FileText}
          color="blue"
          period={periodDisplay}
        />
        <KpiCard
          title="Taux de rapprochement"
          value={`${totals.match_rate || 0}%`}
          icon={CheckCircle}
          color="blue"
          period={periodDisplay}
        />
        <KpiCard
          title="Temps gagné"
          value={`${savings.time_saved_hours || 0}h`}
          icon={Clock}
          color="blue"
          period={periodDisplay}
        />
        <KpiCard
          title="Coût IA"
          value={`${savings.ai_cost_eur || 0}€`}
          icon={DollarSign}
          color="blue"
          period={periodDisplay}
        />
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Monthly Trend */}
        <div className="rounded-lg border border-gray-200 bg-white p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-gray-900">Factures traitées par mois</h3>
            <DropdownButton
              label={trendOptions.find(o => o.value === trendMonths)?.label || '6 mois'}
              value={trendMonths}
              options={trendOptions}
              onChange={(val) => setTrendMonths(Number(val))}
              isOpen={showTrendDropdown}
              onToggle={() => setShowTrendDropdown(!showTrendDropdown)}
              buttonRef={trendButtonRef}
              width="120px"
            />
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
        <div className="rounded-lg border border-gray-200 bg-white p-6">
          <div className="flex items-start justify-between mb-4">
            <h3 className="font-semibold text-gray-900">Taux d'automatisation</h3>
            <div className="text-right">
              <div className="text-sm text-gray-400 mb-1">{periodDisplay}</div>
              <div className="text-2xl font-bold text-blue-600">{automation.automation_rate || 0}%</div>
            </div>
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
      <div className="rounded-lg border border-gray-200 bg-white p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-semibold text-gray-900">Performance par dossier</h3>
          <span className="text-sm text-gray-400">{periodDisplay}</span>
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
                <tr key={dossier.id} className="">
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
      {totals.invoices > 0 && (
        <div className="rounded-lg border border-gray-200 bg-white p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-gray-900">Estimation des gains</h3>
            <Activity className="w-5 h-5 text-gray-400" />
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
            <div>
              <div className="text-xs font-medium text-gray-500 mb-1">Temps économisé</div>
              <div className="text-2xl font-bold text-gray-900">{savings.time_saved_hours || 0}h</div>
              <div className="text-xs text-gray-500 mt-1">{totals.invoices} factures traitées</div>
            </div>
            <div>
              <div className="text-xs font-medium text-gray-500 mb-1">Saisie manuelle</div>
              <div className="text-2xl font-bold text-gray-400">{Math.round((totals.invoices || 0) * 3 / 60)}h</div>
              <div className="text-xs text-gray-500 mt-1">~3 min/facture</div>
            </div>
            <div>
              <div className="text-xs font-medium text-gray-500 mb-1">Coût IA</div>
              <div className="text-2xl font-bold text-gray-900">{savings.ai_cost_eur || 0}€</div>
              <div className="text-xs text-gray-500 mt-1">~{savings.cost_per_invoice_eur || 0}€/facture</div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

const KpiCard = ({ title, value, icon: Icon, color = 'blue', period }) => {
  return (
    <div className="p-5">
      <IconBox color={color} size="sm" className="inline-flex mb-3">
        <Icon className="w-3.5 h-3.5" />
      </IconBox>

      <div className="flex items-center justify-between mb-3">
        <p className="text-xs font-medium text-gray-600">{title}</p>
        {period && <span className="text-[10px] text-gray-400">{period}</span>}
      </div>

      <p className="text-3xl font-bold text-gray-900">{value}</p>
    </div>
  );
};

export default Analytics;
