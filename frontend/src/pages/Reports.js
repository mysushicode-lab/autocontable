import React, { useState } from 'react';
import { useQuery } from 'react-query';
import { 
  BarChart3, 
  Download, 
  FileText,
  TrendingUp,
  TrendingDown,
  Users,
  Car
} from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import { fetchMonthlyReport, fetchTrends, getExportUrl } from '../api';
import { CHART_COLORS_ARRAY } from '../constants/colors';

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
  const monthOptions = generateLast12Months();
  const [period, setPeriod] = useState(monthOptions[0].value);
  const [trendMonths, setTrendMonths] = useState(12); // For evolution chart
  const [year, month] = period.split('-').map(Number);
  
  // Fetch monthly report for selected period (KPI cards)
  const { data, isLoading } = useQuery(['monthly-report', year, month], () => fetchMonthlyReport({ year, month }));
  
  // Fetch trends for evolution chart with selected period
  const { data: trendsData, isLoading: trendsLoading } = useQuery(
    ['trends', trendMonths], 
    () => fetchTrends(trendMonths)
  );

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

  // Export Grand Livre (all invoices with details)
  const exportGrandLivre = () => {
    const invoices = data?.invoices || [];
    const headers = ['Date', 'N° Facture', 'Fournisseur', 'Catégorie', 'Description', 'Montant HT', 'TVA', 'Montant TTC', 'Mode Paiement', 'Statut'];
    const rows = invoices.map((inv) => [
      inv.date ? new Date(inv.date).toLocaleDateString('fr-FR') : '-',
      inv.invoice_number,
      inv.supplier,
      inv.category,
      inv.description || '-',
      inv.amount_ht || inv.amount,
      inv.tva_amount || 0,
      inv.amount,
      inv.payment_method || '-',
      inv.status,
    ]);
    downloadCSV(`grand_livre_${period}.csv`, headers, rows);
  };

  // Export Balance (summary by account/category)
  const exportBalance = () => {
    const categories = Object.entries(data?.by_category || {});
    const headers = ['Compte', 'Libellé', 'Total Débit', 'Total Crédit', 'Solde'];
    const rows = categories.map(([name, values]) => {
      const accountNum = {
        'Pièces détachées': '601',
        'Peinture et vernis': '602',
        'Fournitures atelier': '606',
        'Sous-traitance': '611',
        'Équipement et outillage': '213',
      }[name] || '600';
      return [
        accountNum,
        name,
        values.amount.toFixed(2),
        '0.00',
        values.amount.toFixed(2),
      ];
    });
    // Add total row
    const total = data?.total_amount || 0;
    rows.push(['', 'TOTAL', total.toFixed(2), '0.00', total.toFixed(2)]);
    downloadCSV(`balance_${period}.csv`, headers, rows);
  };

  // Export Journal des Achats
  const exportJournalAchats = () => {
    const invoices = data?.invoices || [];
    const headers = ['Date', 'Journée', 'N° Pièce', 'N° Compte', 'Libellé', 'Débit', 'Crédit'];
    const rows = [];

    invoices.forEach((inv) => {
      const accountNum = {
        'Pièces détachées': '601',
        'Peinture et vernis': '602',
        'Fournitures atelier': '606',
        'Sous-traitance': '611',
        'Équipement et outillage': '213',
      }[inv.category] || '600';

      const date = inv.date ? new Date(inv.date).toLocaleDateString('fr-FR') : '-';

      // Débit compte charge
      rows.push([
        date,
        'ACH',
        inv.invoice_number,
        accountNum,
        `${inv.supplier} - ${inv.description || inv.category}`,
        inv.amount.toFixed(2),
        '',
      ]);

      // Crédit compte fournisseur (401) ou banque (512)
      const creditAccount = inv.payment_method === 'card' || inv.payment_method === 'transfer' ? '512' : '401';
      rows.push([
        date,
        'ACH',
        inv.invoice_number,
        creditAccount,
        `${inv.supplier} - ${inv.invoice_number}`,
        '',
        inv.amount.toFixed(2),
      ]);
    });

    downloadCSV(`journal_achats_${period}.csv`, headers, rows);
  };

  const exportExcelUrl = getExportUrl('/api/export/monthly-report', { year, month });
  const exportCsvUrl = getExportUrl('/api/export/invoices', { year, month });

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
        <div className="flex gap-3">
          <select
            className="px-4 py-2 border rounded-lg"
            value={period}
            onChange={(e) => setPeriod(e.target.value)}
          >
            {monthOptions.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label.charAt(0).toUpperCase() + opt.label.slice(1)}
              </option>
            ))}
          </select>
          <select
            className="px-4 py-2 border rounded-lg"
            value={trendMonths}
            onChange={(e) => setTrendMonths(Number(e.target.value))}
            title="Période d'analyse pour le graphique"
          >
            {PERIOD_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>
                Graphique: {opt.label}
              </option>
            ))}
          </select>
          <a href={exportExcelUrl} className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center gap-2">
            <Download className="w-4 h-4" />
            Export Excel
          </a>
        </div>
      </div>

      {(isLoading || trendsLoading) && <div className="text-sm text-gray-500">Chargement du rapport mensuel...</div>}

      {/* KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <KpiCard 
          title="Total Dépenses"
          value={`${(data?.total_amount || 0).toLocaleString('fr-FR')} €`}
          change={`${(trendsData?.month_over_month_change || 0).toFixed(1)}%`}
          trend={trendsData?.trend_direction || 'stable'}
          icon={BarChart3}
        />
        <KpiCard 
          title="Nombre de Factures"
          value={data?.total_invoices || 0}
          icon={FileText}
        />
        <KpiCard 
          title="Fournisseurs Actifs"
          value={topSuppliers.length}
          icon={Users}
        />
        <KpiCard 
          title="Factures rapprochées"
          value={data?.matched_invoices || 0}
          icon={Car}
          trend="up"
        />
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Dépenses mensuelles */}
        <div className="bg-white rounded-xl shadow-sm border p-6">
          <h3 className="font-semibold text-gray-900 mb-4">Évolution des Dépenses</h3>
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
        <div className="bg-white rounded-xl shadow-sm border p-6">
          <h3 className="font-semibold text-gray-900 mb-4">Répartition par Catégorie</h3>
          <div className="h-64">
            {categoryData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={categoryData}
                    cx="50%"
                    cy="50%"
                    outerRadius={100}
                    dataKey="value"
                    nameKey="name"
                    label={({ percent }) => `${(percent * 100).toFixed(0)}%`}
                  >
                    {categoryData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip formatter={(value) => `${Number(value).toLocaleString('fr-FR')} €`} />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-full flex items-center justify-center text-sm text-gray-500">Aucune donnée</div>
            )}
          </div>
        </div>
      </div>

      {/* Top Fournisseurs */}
      <div className="bg-white rounded-xl shadow-sm border p-6">
        <h3 className="font-semibold text-gray-900 mb-4">Top Fournisseurs - {period}</h3>
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
      <div className="bg-gradient-to-r from-blue-600 to-blue-700 rounded-xl p-6 text-white">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-xl font-semibold mb-2">Export pour Expert-Comptable</h3>
            <p className="text-blue-100">Générez un fichier Excel complet avec toutes les données du mois</p>
          </div>
          <div className="flex gap-3">
            <a href={exportCsvUrl} className="px-4 py-2 bg-white text-blue-600 rounded-lg font-medium hover:bg-blue-50">
              Export CSV
            </a>
            <a href={exportExcelUrl} className="px-4 py-2 bg-blue-500 text-white rounded-lg font-medium hover:bg-blue-400 border border-blue-400">
              Export Excel
            </a>
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

const KpiCard = ({ title, value, change, icon: Icon, trend }) => {
  const isUp = trend === 'up';
  const isDown = trend === 'down';
  
  return (
    <div className="bg-white rounded-xl shadow-sm border p-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-gray-600">{title}</p>
          <p className="text-2xl font-bold text-gray-900">{value}</p>
          {change && (
            <div className={`flex items-center gap-1 mt-1 text-sm ${
              isUp ? 'text-green-600' : isDown ? 'text-red-600' : 'text-gray-600'
            }`}>
              {isUp ? <TrendingUp className="w-4 h-4" /> : isDown ? <TrendingDown className="w-4 h-4" /> : <span className="w-4 h-4">−</span>}
              {change} vs mois dernier
            </div>
          )}
        </div>
        <div className="p-3 bg-blue-50 rounded-lg">
          <Icon className="w-5 h-5 text-blue-600" />
        </div>
      </div>
    </div>
  );
};

const DocumentCard = ({ title, description, icon: Icon, onExport }) => (
  <button
    onClick={onExport}
    className="bg-white rounded-xl shadow-sm border p-6 hover:shadow-md transition-shadow text-left w-full"
  >
    <div className="flex items-start gap-4">
      <div className="p-3 bg-blue-100 rounded-lg">
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
