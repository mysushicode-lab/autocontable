import React, { useState, useRef, useEffect } from 'react';
import { useQuery } from 'react-query';
import { 
  Download, 
  FileText,
  TrendingUp,
  TrendingDown,
  Wallet,
  Building2,
  CheckCircle,
  BarChart3,
  Archive
} from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import { fetchMonthlyReport, fetchTrends, fetchInvoices, getExportUrl } from '../api';
import { CHART_COLORS_ARRAY } from '../constants/colors';
import DropdownButton from '../components/DropdownButton';
import { useFilters } from '../context/FilterContext';

const COLORS = CHART_COLORS_ARRAY;

const generateLast12Months = () => {
  const months = [];
  const today = new Date();
  for (let i = 0; i < 12; i++) {
    const d = new Date(today.getFullYear(), today.getMonth() - i, 1);
    const value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    const label = d.toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' });
    months.push({ value, label });
  }
  return months;
};

const downloadCSV = (filename, headers, rows) => {
  const csvContent = [
    headers.join(';'),
    ...rows.map((row) => row.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(';')),
  ].join('\n');

  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
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
  const monthOptions = generateLast12Months();
  const today = new Date();
  const currentPeriod = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;
  
  // Use selectedMonth from FilterContext, default to current period if not set
  const period = selectedMonth || currentPeriod;
  const [trendMonths, setTrendMonths] = useState(12); // For evolution chart
  const [showPeriodDropdown, setShowPeriodDropdown] = useState(false);
  const [showTrendDropdown, setShowTrendDropdown] = useState(false);
  const periodButtonRef = useRef(null);
  const trendButtonRef = useRef(null);
  const [year, month] = period.split('-').map(Number);
  const periodLabel = monthOptions.find(o => o.value === period)?.label || period;
  const periodDisplay = periodLabel.charAt(0).toUpperCase() + periodLabel.slice(1);
  
  // Fetch monthly report for selected period (KPI cards)
  const { data, isLoading } = useQuery(['monthly-report', year, month], () => fetchMonthlyReport({ year, month }));

  // Fetch individual invoices for client-side CSV exports (needs amount_ht, amount_tax, due_date)
  const { data: invoicesData } = useQuery(['report-invoices', year, month], () => fetchInvoices({ year, month }));
  const exportInvoices = invoicesData?.invoices || [];

  // Fetch trends for evolution chart with selected period
  const { data: trendsData, isLoading: trendsLoading } = useQuery(
    ['trends', trendMonths], 
    () => fetchTrends(trendMonths)
  );
  
  // Auto-set month filter to most recent invoice date on initial load
  useEffect(() => {
    const fetchMostRecentInvoiceMonth = async () => {
      try {
        // Fetch all invoices without filters to get the most recent one
        const data = await fetchInvoices({});
        if (data?.invoices && data.invoices.length > 0) {
          // Sort by date descending to find the most recent
          const sortedInvoices = data.invoices.sort((a, b) => {
            if (!a.date) return 1;
            if (!b.date) return -1;
            return new Date(b.date) - new Date(a.date);
          });
          const mostRecentInvoice = sortedInvoices[0];
          if (mostRecentInvoice.date) {
            const date = new Date(mostRecentInvoice.date);
            const year = date.getFullYear();
            const month = date.getMonth() + 1;
            const monthValue = `${year}-${String(month).padStart(2, '0')}`;
            // Only set if not already set by user
            if (!selectedMonth) {
              setSelectedMonth(monthValue);
            }
          }
        }
      } catch (error) {
        console.error('Error fetching most recent invoice:', error);
      }
    };
    
    fetchMostRecentInvoiceMonth();
  }, []); // Run only on mount

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

  // PCG account mapping (Plan Comptable Général — carrosserie auto)
  const COMPTE_CHARGES = {
    'Pièces détachées':              '607100',
    'Peinture et vernis':            '607200',
    'Fournitures atelier':           '606400',
    'Sous-traitance':                '611000',
    'Équipement et outillage':       '606310',
    'Énergie et locaux':             '606110',
    'Assurances et frais':           '616000',
    'Déplacements et véhicules':     '625100',
    'Informatique et communication': '626000',
    'Formation et divers':           '628000',
  };
  const STATUS_FR = { pending: 'En attente', processed: 'Traité', matched: 'Rapproché', unmatched: 'Non rapproché' };

  // Export Grand Livre (all invoices with details)
  const exportGrandLivre = () => {
    const invoices = exportInvoices;
    const headers = ['Date', 'Échéance', 'N° Facture', 'Fournisseur', 'Catégorie', 'N° Compte PCG', 'Montant HT', 'TVA', 'Montant TTC', 'Mode Paiement', 'Statut'];
    const rows = invoices.map((inv) => [
      inv.date ? new Date(inv.date).toLocaleDateString('fr-FR') : '-',
      inv.due_date ? new Date(inv.due_date).toLocaleDateString('fr-FR') : '-',
      inv.invoice_number,
      inv.supplier || '-',
      inv.category || '-',
      COMPTE_CHARGES[inv.category] || '608000',
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
      const compte = COMPTE_CHARGES[inv.category] || '608000';
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
      const compte = COMPTE_CHARGES[inv.category] || '608000';
      const supplier = inv.supplier || 'Fournisseur inconnu';
      const date = inv.date ? new Date(inv.date).toLocaleDateString('fr-FR') : '-';
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

  const exportExcelUrl = getExportUrl('/api/reports/export/monthly-report', { year, month });
  
  const handleCsvExport = async () => {
    const token = localStorage.getItem('auth_token');
    const url = getExportUrl('/api/reports/export/invoices', { year, month });
    
    try {
      const response = await fetch(url, {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });
      
      if (!response.ok) {
        throw new Error('Failed to export CSV');
      }
      
      const blob = await response.blob();
      const downloadUrl = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.download = `invoices_${year}_${month}.csv`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(downloadUrl);
    } catch (error) {
      console.error('Error exporting CSV:', error);
    }
  };

  const handleDossierExport = async () => {
    const token = localStorage.getItem('auth_token');
    const url = `${getExportUrl('/api/reports/export/dossier', { year, month })}`;
    try {
      const response = await fetch(url, { headers: { 'Authorization': `Bearer ${token}` } });
      if (!response.ok) throw new Error('Export dossier failed');
      const blob = await response.blob();
      const downloadUrl = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.download = `dossier_comptable_${year}_${String(month).padStart(2,'0')}.zip`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(downloadUrl);
    } catch (error) {
      console.error('Error exporting dossier:', error);
    }
  };

  const handleExcelExport = async () => {
    const token = localStorage.getItem('auth_token');
    const url = getExportUrl('/api/reports/export/monthly-report', { year, month });
    
    try {
      const response = await fetch(url, {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });
      
      if (!response.ok) {
        throw new Error('Failed to export Excel');
      }
      
      const blob = await response.blob();
      const downloadUrl = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.download = `monthly_report_${year}_${month}.xlsx`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(downloadUrl);
    } catch (error) {
      console.error('Error exporting Excel:', error);
    }
  };

  // Use real 12-month trends data instead of single month
  const monthlyData = trendsData?.months || [];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Rapports Comptables</h1>
          <p className="text-gray-500">Analyse et export pour l'expert-comptable</p>
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
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <KpiCard 
          title="Total Dépenses TTC"
          value={`${(data?.total_amount || 0).toLocaleString('fr-FR')} €`}
          change={`${(trendsData?.month_over_month_change || 0).toFixed(1)}%`}
          trend={trendsData?.trend_direction || 'stable'}
          invertTrend
          icon={Wallet}
        />
        <KpiCard 
          title="Nombre de Factures"
          value={data?.total_invoices || 0}
          icon={FileText}
        />
        <KpiCard 
          title="Fournisseurs Actifs"
          value={topSuppliers.length}
          icon={Building2}
        />
        <KpiCard 
          title="Factures rapprochées"
          value={data?.matched_invoices || 0}
          icon={CheckCircle}
          trend={data?.total_invoices > 0 ? (data.matched_invoices / data.total_invoices >= 0.8 ? 'up' : 'down') : 'stable'}
        />
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Dépenses mensuelles */}
        <div className="rounded-md border border-white/30 bg-white/50 p-6 shadow-sm backdrop-blur-md">
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
                <Tooltip formatter={(value) => `${Number(value).toLocaleString('fr-FR')} €`} />
                <Bar dataKey="amount" fill="#3b82f6" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Répartition par catégorie */}
        <div className="rounded-md border border-white/30 bg-white/50 p-6 shadow-sm backdrop-blur-md">
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
                    <Tooltip formatter={(value) => `${Number(value).toLocaleString('fr-FR')} €`} />
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
      <div className="rounded-md border border-white/30 bg-white/50 p-6 shadow-sm backdrop-blur-md">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-semibold text-gray-900">Top Fournisseurs</h3>
          <span className="text-sm text-gray-400">{periodDisplay}</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Fournisseur</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Montant Total</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Nombre Factures</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Moyenne</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">% du Total</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {topSuppliers.map((supplier, index) => (
                <tr key={index} className="hover:bg-gray-50">
                  <td className="px-6 py-4 font-medium">{supplier.name}</td>
                  <td className="px-6 py-4">{supplier.amount.toLocaleString('fr-FR')} €</td>
                  <td className="px-6 py-4">{supplier.invoices}</td>
                  <td className="px-6 py-4">
                    {Math.round(supplier.amount / supplier.invoices).toLocaleString('fr-FR')} €
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-2">
                      <div className="w-24 bg-gray-200 rounded-full h-2">
                        <div 
                          className="bg-blue-600 h-2 rounded-full" 
                          style={{ width: `${data?.total_amount ? (supplier.amount / data.total_amount) * 100 : 0}%` }}
                        />
                      </div>
                      <span className="text-sm">{(data?.total_amount ? (supplier.amount / data.total_amount) * 100 : 0).toFixed(1)}%</span>
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

      {/* Export Options */}
      <div className="bg-gradient-to-r from-blue-600 to-blue-700 rounded-md p-6 text-white">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-xl font-semibold mb-2">Export pour Expert-Comptable</h3>
            <p className="text-blue-100">Générez un fichier Excel complet avec toutes les données du mois</p>
          </div>
          <div className="flex gap-3 flex-wrap">
            <button onClick={handleCsvExport} className="px-4 py-2 bg-white text-blue-600 rounded-md font-medium hover:bg-blue-50">
              Export CSV
            </button>
            <button onClick={handleExcelExport} className="px-4 py-2 bg-blue-500 text-white rounded-md font-medium hover:bg-blue-400 border border-blue-400">
              Export Excel
            </button>
            <button onClick={handleDossierExport} className="flex items-center gap-2 px-4 py-2 text-white rounded-md font-medium border border-white hover:bg-white/10">
              <Archive className="w-4 h-4" />
              Dossier complet (ZIP)
            </button>
          </div>
        </div>
      </div>

      {/* Documents comptables */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
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
      </div>
    </div>
  );
};

const KpiCard = ({ title, value, change, icon: Icon, trend, invertTrend }) => {
  const isUp = trend === 'up';
  const isDown = trend === 'down';
  // For expenses: up = bad (red), down = good (green)
  const isPositive = invertTrend ? isDown : isUp;
  const isNegative = invertTrend ? isUp : isDown;

  return (
    <div className="rounded-md border border-white/30 bg-white/50 p-6 shadow-sm backdrop-blur-md">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-gray-600">{title}</p>
          <p className="text-2xl font-bold text-gray-900">{value}</p>
          {change && (
            <div className={`flex items-center gap-1 mt-1 text-sm ${
              isPositive ? 'text-green-600' : isNegative ? 'text-red-600' : 'text-gray-600'
            }`}>
              {isUp ? <TrendingUp className="w-4 h-4" /> : isDown ? <TrendingDown className="w-4 h-4" /> : <span className="w-4 h-4">−</span>}
              {change} vs mois dernier
            </div>
          )}
        </div>
        <div className="p-3 bg-blue-50 rounded-md">
          <Icon className="w-5 h-5 text-blue-600" />
        </div>
      </div>
    </div>
  );
};

const DocumentCard = ({ title, description, icon: Icon, onExport }) => (
  <button
    onClick={onExport}
    className="rounded-md border border-white/30 bg-white/50 p-6 shadow-sm backdrop-blur-md hover:shadow-md transition-shadow text-left w-full"
  >
    <div className="flex items-start gap-4">
      <div className="p-3 bg-blue-100 rounded-md">
        <Icon className="w-5 h-5 text-blue-600" />
      </div>
      <div className="flex-1">
        <h4 className="font-semibold text-gray-900">{title}</h4>
        <p className="text-sm text-gray-500 mt-1">{description}</p>
      </div>
      <Download className="w-5 h-5 text-blue-400" />
    </div>
  </button>
);

export default Reports;
