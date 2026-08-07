'use client';

import React, { useState, useRef } from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  FileText,
  TrendingUp,
  TrendingDown,
  Wallet,
  Building2,
  CheckCircle,
  BarChart3,
  Archive,
  Download,
  FileCheck,
} from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip as RechartsTooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import { fetchMonthlyReport, fetchTrends, fetchInvoices, getExportUrl } from '../api';
import { CHART_COLORS_ARRAY } from '../constants/colors';
import { PCG_COMPTES, DEFAULT_COMPTE } from '../constants/pcg';
import DropdownButton from '../components/DropdownButton';
import { useFilters } from '../context/FilterContext';
import { useClientFile } from '../context/ClientFileContext';
import HelpTooltip from '../components/ui/HelpTooltip';
import IconBox from '../components/ui/IconBox';
import { useAutoSelectRecentMonth } from '../hooks/useAutoSelectRecentMonth';
import { formatCurrency, formatDate } from '../utils/formatHelpers';
import { downloadBlob, downloadAuthenticatedFile } from '../utils/downloadHelpers';
import { generateMonthOptions } from '../utils/dateHelpers';

const COLORS = CHART_COLORS_ARRAY;

const downloadCSV = (filename, headers, rows) => {
  const csvContent = [
    headers.join(';'),
    ...rows.map((row) => row.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(';')),
  ].join('\n');
  downloadBlob(new Blob([csvContent], { type: 'text/csv;charset=utf-8;' }), filename);
};

// Period options for trend analysis
const PERIOD_OPTIONS = [
  { value: 1, label: '1 mois' },
  { value: 2, label: '2 mois' },
  { value: 3, label: '3 mois' },
  { value: 6, label: '6 mois' },
  { value: 12, label: '12 mois' },
  { value: 24, label: '24 mois' },
];

const Reports = () => {
  const { selectedMonth, setSelectedMonth } = useFilters();
  const { activeClientFileId } = useClientFile();
  const monthOptions = generateMonthOptions(12);
  const today = new Date();
  const currentPeriod = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;
  
  // Use selectedMonth from FilterContext, default to current period if not set
  const period = selectedMonth !== undefined ? selectedMonth : currentPeriod;
  const [trendMonths, setTrendMonths] = useState(12); // For evolution chart
  const [showPeriodDropdown, setShowPeriodDropdown] = useState(false);
  const [showTrendDropdown, setShowTrendDropdown] = useState(false);
  const periodButtonRef = useRef(null);
  const trendButtonRef = useRef(null);
  const [year, month] = period.split('-').map(Number);
  const periodLabel = monthOptions.find(o => o.value === period)?.label || period;
  const periodDisplay = periodLabel.charAt(0).toUpperCase() + periodLabel.slice(1);
  
  const reportFilters = {
    year,
    month,
    ...(activeClientFileId != null ? { client_file_id: activeClientFileId } : {}),
  };

  // Fetch monthly report for selected period (KPI cards)
  const { data, isLoading } = useQuery({
    queryKey: ['monthly-report', year, month, activeClientFileId],
    queryFn: () => fetchMonthlyReport(reportFilters),
  });

  // Fetch individual invoices for client-side CSV exports (needs amount_ht, amount_tax, due_date)
  const { data: invoicesData } = useQuery({
    queryKey: ['report-invoices', year, month, activeClientFileId],
    queryFn: () => fetchInvoices({ ...reportFilters, include_reconciled: true }),
  });
  const exportInvoices = invoicesData?.invoices || [];

  // Fetch trends for evolution chart with selected period
  const { data: trendsData, isLoading: trendsLoading } = useQuery({
    queryKey: ['trends', trendMonths],
    queryFn: () => fetchTrends(trendMonths),
  });
  
  useAutoSelectRecentMonth(selectedMonth, setSelectedMonth);

  const categoryData = Object.entries(data?.by_category || {}).map(([name, values], index) => ({
    name,
    value: values.amount,
    color: COLORS[index % COLORS.length],
  }));
  const topSuppliers = Object.entries(data?.by_supplier || {}).map(([name, values]) => ({
    name,
    amount: values.amount,
    invoices: values.count,
  })).sort((a, b) => b.amount - a.amount);

  const STATUS_FR = { pending: 'En attente', processed: 'Traité', matched: 'Rapproché', unmatched: 'Non rapproché' };

  // Export Grand Livre (all invoices with details)
  const exportGrandLivre = () => {
    const invoices = exportInvoices;
    const headers = ['Date', 'Échéance', 'N° Facture', 'Fournisseur', 'Catégorie', 'N° Compte PCG', 'Montant HT', 'TVA', 'Montant TTC', 'Mode Paiement', 'Statut'];
    const rows = invoices.map((inv) => [
      formatDate(inv.date),
      formatDate(inv.due_date),
      inv.invoice_number,
      inv.supplier || '-',
      inv.category || '-',
      PCG_COMPTES[inv.category] || DEFAULT_COMPTE,
      (inv.amount_ht ?? 0).toFixed(2),
      (inv.amount_tax ?? 0).toFixed(2),
      (inv.amount ?? 0).toFixed(2),
      inv.payment_method || '-',
      STATUS_FR[inv.status] || inv.status,
    ]);
    downloadCSV(`grand_livre_${period}.csv`, headers, rows);
  };

  // Export Balance (summary by account/category)
  const exportBalance = () => {
    const invoices = exportInvoices;
    const headers = ['N° Compte', 'Libellé compte', 'Total Débit', 'Total Crédit', 'Solde'];
    const rows = [];

    // Accumulate per charge account
    const chargeMap = {};
    let totalHT = 0, totalTVA = 0, totalTTC = 0;
    invoices.forEach((inv) => {
      const compte = PCG_COMPTES[inv.category] || DEFAULT_COMPTE;
      const label = inv.category || 'Achats divers';
      const tva = inv.amount_tax ?? 0;
      const ttc = inv.amount ?? 0;
      const ht = (inv.amount_ht != null && inv.amount_ht !== 0) ? inv.amount_ht : (ttc - tva);
      if (!chargeMap[compte]) chargeMap[compte] = { label, debit: 0 };
      chargeMap[compte].debit += ht;
      totalHT += ht; totalTVA += tva; totalTTC += ttc;
    });

    // Ligne par compte de charge (6xx)
    Object.entries(chargeMap).sort().forEach(([compte, { label, debit }]) => {
      rows.push([compte, label, debit.toFixed(2), '0.00', debit.toFixed(2)]);
    });
    // Ligne TVA déductible (445660)
    if (totalTVA) rows.push(['445660', 'TVA déductible — achats et services', totalTVA.toFixed(2), '0.00', totalTVA.toFixed(2)]);
    // Ligne Fournisseurs (401000)
    rows.push(['401000', 'Fournisseurs', '0.00', totalTTC.toFixed(2), (-totalTTC).toFixed(2)]);
    // Total de contrôle (doit être 0 — partie double)
    const controle = totalHT + totalTVA - totalTTC;
    rows.push(['', 'TOTAL DE CONTRÔLE (doit être 0)', (totalHT + totalTVA).toFixed(2), totalTTC.toFixed(2), controle.toFixed(2)]);

    downloadCSV(`balance_${period}.csv`, headers, rows);
  };

  // Export Journal des Achats (écritures comptables PCG — partie double)
  const exportJournalAchats = () => {
    const invoices = exportInvoices;
    const headers = ['Date', 'Journal', 'N° Pièce', 'N° Compte', 'Libellé compte', 'Libellé écriture', 'Débit', 'Crédit'];
    const rows = [];

    invoices.forEach((inv) => {
      const compte = PCG_COMPTES[inv.category] || DEFAULT_COMPTE;
      const supplier = inv.supplier || 'Fournisseur inconnu';
      const date = formatDate(inv.date);
      const tva = inv.amount_tax ?? 0;
      const ttc = inv.amount     ?? 0;
      const ht  = (inv.amount_ht != null && inv.amount_ht !== 0) ? inv.amount_ht : (ttc - tva);
      const isAvoir = ttc < 0;
      const libelleBase = `${isAvoir ? 'Avoir' : 'Facture'} ${supplier} — ${inv.invoice_number}`;

      // Ligne 1 — Compte de charge (6xx) : débit HT (ou crédit si avoir)
      rows.push([
        date, 'ACH', inv.invoice_number,
        compte, inv.category || 'Achats divers',
        libelleBase,
        isAvoir ? '' : Math.abs(ht).toFixed(2),
        isAvoir ? Math.abs(ht).toFixed(2) : '',
      ]);

      // Ligne 2 — TVA déductible (445660) : débit TVA (ou crédit si avoir)
      if (tva !== 0) {
        rows.push([
          date, 'ACH', inv.invoice_number,
          '445660', 'TVA déductible — achats et services',
          `TVA — ${libelleBase}`,
          isAvoir ? '' : Math.abs(tva).toFixed(2),
          isAvoir ? Math.abs(tva).toFixed(2) : '',
        ]);
      }

      // Ligne 3 — Fournisseur (401000) : crédit TTC (ou débit si avoir)
      rows.push([
        date, 'ACH', inv.invoice_number,
        '401000', 'Fournisseurs',
        `Fournisseur — ${supplier}`,
        isAvoir ? Math.abs(ttc).toFixed(2) : '',
        isAvoir ? '' : Math.abs(ttc).toFixed(2),
      ]);
    });

    downloadCSV(`journal_achats_${period}.csv`, headers, rows);
  };

  const handleCsvExport = () =>
    downloadAuthenticatedFile(
      getExportUrl('/api/reports/export/invoices', { year, month }),
      `invoices_${year}_${month}.csv`
    ).catch(console.error);

  const handleDossierExport = () =>
    downloadAuthenticatedFile(
      getExportUrl('/api/reports/export/dossier', { year, month }),
      `dossier_comptable_${year}_${String(month).padStart(2, '0')}.zip`
    ).catch(console.error);

  const handleExcelExport = () =>
    downloadAuthenticatedFile(
      getExportUrl('/api/reports/export/monthly-report', { year, month }),
      `monthly_report_${year}_${month}.xlsx`
    ).catch(console.error);

  const handleFecExport = () =>
    downloadAuthenticatedFile(
      getExportUrl('/api/reports/export/fec', { year, month }),
      `FEC_${year}_${String(month).padStart(2, '0')}.txt`
    ).catch(console.error);

  // Use real 12-month trends data instead of single month
  const monthlyData = trendsData?.months || [];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div>
          <div className="flex items-center gap-1.5">
            <h1 className="text-lg font-semibold text-gray-900">Rapports Comptables</h1>
            <HelpTooltip text="Générez et exportez les rapports mensuels, annuels et par fournisseur pour votre expert-comptable." />
          </div>
          <p className="text-xs text-gray-500 mt-0.5">Analyse et export pour l'expert-comptable</p>
        </div>
        <div className="flex gap-3 items-center">
          <DropdownButton
            label={periodDisplay}
            value={period}
            options={monthOptions.map(opt => ({ ...opt, label: opt.label.charAt(0).toUpperCase() + opt.label.slice(1) }))}
            onChange={setSelectedMonth}
            isOpen={showPeriodDropdown}
            onToggle={() => setShowPeriodDropdown(!showPeriodDropdown)}
            buttonRef={periodButtonRef}
            width="200px"
          />
        </div>
      </div>

      {(isLoading || trendsLoading) && <div className="text-sm text-gray-500">Chargement du rapport mensuel...</div>}

      {/* KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 border border-gray-200 rounded-lg overflow-hidden bg-white divide-y md:divide-y-0 md:divide-x divide-gray-200">
        <KpiCard
          title="Total Dépenses TTC"
          value={formatCurrency(data?.total_amount || 0)}
          change={`${(trendsData?.month_over_month_change || 0).toFixed(1)}%`}
          trend={trendsData?.trend_direction || 'stable'}
          invertTrend
          icon={Wallet}
          period={periodDisplay}
        />
        <KpiCard
          title="Nombre de Factures"
          value={data?.total_invoices || 0}
          icon={FileText}
          period={periodDisplay}
        />
        <KpiCard
          title="Fournisseurs Actifs"
          value={topSuppliers.length}
          icon={Building2}
          period={periodDisplay}
        />
        <KpiCard
          title="Factures rapprochées"
          value={data?.matched_invoices || 0}
          icon={CheckCircle}
          trend={data?.total_invoices > 0 ? (data.matched_invoices / data.total_invoices >= 0.8 ? 'up' : 'down') : 'stable'}
          period={periodDisplay}
        />
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Dépenses mensuelles */}
        <div className="rounded-lg border border-gray-200 bg-white p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-gray-900">Évolution des Dépenses</h3>
            <DropdownButton
              label="12 mois"
              value={trendMonths}
              options={PERIOD_OPTIONS}
              onChange={setTrendMonths}
              isOpen={showTrendDropdown}
              onToggle={() => setShowTrendDropdown(!showTrendDropdown)}
              buttonRef={trendButtonRef}
              width="150px"
            />
          </div>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={monthlyData}>
                <XAxis dataKey="label" tick={{fontSize: 12}} interval={0} angle={-45} textAnchor="end" height={60} />
                <YAxis />
                <RechartsTooltip formatter={(value) => formatCurrency(value)} />
                <Bar dataKey="amount" fill="#3b82f6" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Répartition par catégorie */}
        <div className="rounded-lg border border-gray-200 bg-white p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-gray-900">Répartition par Catégorie</h3>
            <span className="text-sm text-gray-400">{periodDisplay}</span>
          </div>
          {categoryData.length > 0 ? (
            <div className="flex gap-4">
              <div className="h-52 flex-shrink-0" style={{ width: 180 }}>
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={categoryData}
                      cx="50%"
                      cy="50%"
                      outerRadius={80}
                      dataKey="value"
                      nameKey="name"
                    >
                      {categoryData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <RechartsTooltip formatter={(value) => formatCurrency(value)} />
                  </PieChart>
                </ResponsiveContainer>
              </div>
              <div className="flex-1 flex flex-col justify-center gap-1.5 overflow-auto">
                {categoryData.map((entry, index) => {
                  const total = categoryData.reduce((s, e) => s + e.value, 0);
                  const pct = total > 0 ? ((entry.value / total) * 100).toFixed(0) : 0;
                  return (
                    <div key={index} className="flex items-center gap-2 text-sm">
                      <span className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ backgroundColor: entry.color }} />
                      <span className="truncate text-gray-700 flex-1" title={entry.name}>{entry.name}</span>
                      <span className="text-gray-500 font-medium flex-shrink-0">{pct}%</span>
                    </div>
                  );
                })}
              </div>
            </div>
          ) : (
            <div className="h-52 flex items-center justify-center text-sm text-gray-500">Aucune donnée</div>
          )}
        </div>
      </div>

      {/* Top Fournisseurs */}
      <div className="rounded-lg border border-gray-200 bg-white p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-semibold text-gray-900">Top Fournisseurs</h3>
          <span className="text-sm text-gray-400">{periodDisplay}</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-xs sm:text-sm">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-3 sm:px-6 py-2 sm:py-3 text-left text-xs font-medium text-gray-500 uppercase">Fournisseur</th>
                <th className="px-3 sm:px-6 py-2 sm:py-3 text-left text-xs font-medium text-gray-500 uppercase">Montant</th>
                <th className="hidden sm:table-cell px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Factures</th>
                <th className="hidden sm:table-cell px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Moyenne</th>
                <th className="px-3 sm:px-6 py-2 sm:py-3 text-left text-xs font-medium text-gray-500 uppercase">%</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {topSuppliers.map((supplier, index) => (
                <tr key={index} className="">
                  <td className="px-3 sm:px-6 py-2 sm:py-4 font-medium truncate max-w-[120px] sm:max-w-none">{supplier.name}</td>
                  <td className="px-3 sm:px-6 py-2 sm:py-4 whitespace-nowrap">{formatCurrency(supplier.amount)}</td>
                  <td className="hidden sm:table-cell px-6 py-4">{supplier.invoices}</td>
                  <td className="hidden sm:table-cell px-6 py-4">
                    {formatCurrency(Math.round(supplier.amount / supplier.invoices))}
                  </td>
                  <td className="px-3 sm:px-6 py-2 sm:py-4">
                    <div className="flex items-center gap-1.5">
                      <div className="w-10 sm:w-24 bg-gray-200 rounded-full h-1.5">
                        <div
                          className="bg-blue-600 h-1.5 rounded-full"
                          style={{ width: `${data?.total_amount ? (supplier.amount / data.total_amount) * 100 : 0}%` }}
                        />
                      </div>
                      <span>{(data?.total_amount ? (supplier.amount / data.total_amount) * 100 : 0).toFixed(1)}%</span>
                    </div>
                  </td>
                </tr>
              ))}
              {topSuppliers.length === 0 && (
                <tr>
                  <td colSpan="5" className="px-6 py-8 text-center text-sm text-gray-500">Aucune donnée fournisseur.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Export Options - Fusionné */}
      <div className="border border-gray-200 rounded-lg overflow-hidden bg-white">
        {/* Section Export principale */}
        <div className="relative bg-blue-600 p-6 text-white overflow-hidden">
          {/* Texture grain papier nuageux */}
          <div className="absolute inset-0 opacity-40" style={{
            backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='1.2' numOctaves='5' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
            backgroundSize: '150px 150px',
            mixBlendMode: 'overlay'
          }} />

          <div className="relative flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div>
              <h3 className="text-xl font-semibold mb-1">Export du dossier</h3>
              <p className="text-blue-100 text-sm">Générez les fichiers comptables pour le dossier sélectionné</p>
            </div>
            <div className="flex gap-3 flex-wrap">
              <button onClick={handleCsvExport} className="px-2 py-1.5 sm:px-4 sm:py-2 bg-white text-blue-600 rounded-md font-medium text-xs sm:text-sm">
                CSV
              </button>
              <button onClick={handleExcelExport} className="px-2 py-1.5 sm:px-4 sm:py-2 bg-blue-500 text-white rounded-md font-medium border border-blue-400 text-xs sm:text-sm">
                Excel
              </button>
              <button onClick={handleDossierExport} className="flex items-center gap-1.5 px-2 py-1.5 sm:px-4 sm:py-2 text-white rounded-md font-medium border border-blue-400 text-xs sm:text-sm">
                <Archive className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                <span className="hidden sm:inline">Dossier complet (ZIP)</span>
                <span className="sm:hidden">ZIP</span>
              </button>
            </div>
          </div>
        </div>

        {/* Documents comptables */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 divide-y md:divide-y-0 md:divide-x divide-gray-200">
          <DocumentCard
            title="Grand Livre"
            description="Toutes les écritures comptables"
            icon={FileText}
            onExport={exportGrandLivre}
          />
          <DocumentCard
            title="Balance"
            description="Synthèse par compte"
            icon={BarChart3}
            onExport={exportBalance}
          />
          <DocumentCard
            title="Journal des Achats"
            description="Détail des factures fournisseurs"
            icon={TrendingUp}
            onExport={exportJournalAchats}
          />
          <DocumentCard
            title="Export FEC (DGFiP)"
            description="Fichier des Écritures Comptables"
            icon={FileCheck}
            onExport={handleFecExport}
          />
        </div>
      </div>
    </div>
  );
};

const KpiCard = ({ title, value, change, icon: Icon, trend, invertTrend, period }) => {
  const isUp = trend === 'up';
  const isDown = trend === 'down';
  // For expenses: up = bad (red), down = good (green)
  const isPositive = invertTrend ? isDown : isUp;
  const isNegative = invertTrend ? isUp : isDown;

  const colorName = Icon.name === 'Wallet' ? 'blue' : Icon.name === 'FileText' ? 'green' : Icon.name === 'Building2' ? 'purple' : 'yellow';

  return (
    <div className="p-5">
      <IconBox color={colorName} size="sm" className="inline-flex mb-3">
        <Icon className="w-3.5 h-3.5" />
      </IconBox>

      <div className="flex items-center justify-between mb-3">
        <p className="text-xs font-medium text-gray-600">{title}</p>
        {period && <span className="text-[10px] text-gray-400">{period}</span>}
      </div>

      <p className="text-3xl font-bold text-gray-900">{value}</p>

      {change && (
        <div className={`flex items-center gap-1 mt-2 text-xs font-medium ${
          isPositive ? 'text-green-600' : isNegative ? 'text-red-600' : 'text-gray-600'
        }`}>
          {isUp ? <TrendingUp className="w-3.5 h-3.5" /> : isDown ? <TrendingDown className="w-3.5 h-3.5" /> : null}
          <span>{change}</span>
          <span className="text-gray-400 font-normal">vs mois dernier</span>
        </div>
      )}
    </div>
  );
};

const DocumentCard = ({ title, description, icon: Icon, onExport }) => (
  <button
    onClick={onExport}
    className="p-5 text-left w-full"
  >
    <div className="flex items-start gap-3">
      <IconBox color="blue" size="md" className="flex-shrink-0">
        <Icon className="w-4 h-4" />
      </IconBox>
      <div className="flex-1 min-w-0">
        <h4 className="font-semibold text-gray-900 text-sm mb-1">{title}</h4>
        <p className="text-xs text-gray-500">{description}</p>
      </div>
      <Download className="w-4 h-4 text-blue-400 flex-shrink-0 mt-1" />
    </div>
  </button>
);

export default Reports;
