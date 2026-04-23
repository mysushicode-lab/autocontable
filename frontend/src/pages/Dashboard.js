import React, { useState, useEffect } from 'react';
import { useQuery } from 'react-query';
import { useNavigate } from 'react-router-dom';
import { 
  FileText, 
  CreditCard, 
  AlertCircle, 
  Car,
  TrendingUp,
  TrendingDown,
  Clock
} from 'lucide-react';
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from 'recharts';
import { fetchInvoices, fetchMonthlyReport, fetchReconciliationDetails, fetchReconciliationStatus, fetchTrends } from '../api';
import { CHART_COLORS_ARRAY } from '../constants/colors';

const COLORS = CHART_COLORS_ARRAY;

// Period options for trend analysis
const PERIOD_OPTIONS = [
  { value: 1, label: '1 mois' },
  { value: 2, label: '2 mois' },
  { value: 3, label: '3 mois' },
  { value: 6, label: '6 mois' },
  { value: 12, label: '12 mois' },
];

const Dashboard = () => {
  const navigate = useNavigate();
  const [vehicleSearch, setVehicleSearch] = useState('');
  const [trendMonths, setTrendMonths] = useState(12);
  const today = new Date();
  const filters = { month: today.getMonth() + 1, year: today.getFullYear() };

  // Note: Automatic email fetch disabled to avoid conflicts with scheduler
  // Scheduler handles initial fetch on startup (from start of current month)

  const handleVehicleSearch = () => {
    const plate = vehicleSearch.trim().toUpperCase();
    if (plate) {
      navigate(`/vehicles/${plate}`);
    }
  };

  const handleKeyPress = (e) => {
    if (e.key === 'Enter') {
      handleVehicleSearch();
    }
  };

  const { data: invoicesData } = useQuery(['dashboard-invoices', filters], () => fetchInvoices(filters));
  const { data: reportData } = useQuery(['dashboard-report', filters], () => fetchMonthlyReport(filters));
  const { data: reconciliationStatus } = useQuery(['dashboard-reconciliation-status', filters], () => fetchReconciliationStatus(filters));
  const { data: reconciliationDetails } = useQuery(['dashboard-reconciliation-details', filters], () => fetchReconciliationDetails(filters));
  const { data: trendsData } = useQuery(['dashboard-trends', trendMonths], () => fetchTrends(trendMonths));

  const invoices = invoicesData?.invoices || [];
  const recentInvoices = invoices.slice(0, 5).map((invoice) => ({
    id: invoice.id,
    number: invoice.invoice_number,
    supplier: invoice.supplier || 'Fournisseur inconnu',
    amount: invoice.amount || 0,
    date: invoice.date ? new Date(invoice.date).toLocaleDateString('fr-FR') : '-',
    status: invoice.status,
    vehicle: invoice.vehicle_registration,
  }));
  
  // Use real month-over-month change from trends API instead of match_rate
  const stats = {
    totalInvoices: reportData?.total_invoices || invoices.length,
    pendingReconciliation: reconciliationStatus?.pending || (reportData ? reportData.total_invoices - reportData.matched_invoices : 0),
    unmatchedBank: reconciliationDetails?.bank_only?.length || 0,
    totalAmount: reportData?.total_amount || 0,
    monthlyChange: trendsData?.month_over_month_change || 0,
    trendDirection: trendsData?.trend_direction || 'stable',
  };
  const categoryData = Object.entries(reportData?.by_category || {}).map(([name, values], index) => ({
    name,
    value: values.amount,
    color: COLORS[index % COLORS.length],
  }));

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Tableau de Bord</h1>
          <p className="text-gray-500">Vue d'ensemble de votre activité comptable</p>
        </div>
        <div className="flex gap-3 items-center">
          <select
            className="px-3 py-2 border rounded-lg text-sm"
            value={trendMonths}
            onChange={(e) => setTrendMonths(Number(e.target.value))}
            title="Période d'analyse"
          >
            {PERIOD_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
          <button onClick={() => navigate('/invoices')} className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center gap-2">
            <FileText className="w-4 h-4" />
            Nouvelle Facture
          </button>
          <button onClick={() => navigate('/reconciliation')} className="px-4 py-2 bg-white border rounded-lg hover:bg-gray-50 flex items-center gap-2">
            <CreditCard className="w-4 h-4" />
            Import Bancaire
          </button>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard 
          title="Factures ce mois"
          value={stats.totalInvoices}
          icon={FileText}
          color="blue"
        />
        <StatCard 
          title="En attente rapprochement"
          value={stats.pendingReconciliation}
          icon={Clock}
          alert={stats.pendingReconciliation > 20}
          color="yellow"
        />
        <StatCard 
          title="Paiements non rapprochés"
          value={stats.unmatchedBank}
          icon={AlertCircle}
          alert={stats.unmatchedBank > 0}
          color="red"
        />
        <StatCard 
          title="Montant total"
          value={`${stats.totalAmount.toLocaleString('fr-FR')} €`}
          icon={CreditCard}
          trend={stats.monthlyChange.toFixed(1)}
          trendUp={stats.trendDirection === 'up'}
          trendDown={stats.trendDirection === 'down'}
          color="green"
        />
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Expenses by Category */}
        <div className="bg-white rounded-xl shadow-sm border p-6">
          <h3 className="font-semibold text-gray-900 mb-4">Dépenses par Catégorie</h3>
          <div className="h-64">
            {categoryData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={categoryData}
                    cx="50%"
                    cy="50%"
                    innerRadius={60}
                    outerRadius={100}
                    dataKey="value"
                    nameKey="name"
                  >
                    {categoryData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip 
                    formatter={(value) => `${Number(value).toLocaleString('fr-FR')} €`}
                  />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-full flex items-center justify-center text-sm text-gray-500">
                Aucune donnée disponible
              </div>
            )}
          </div>
          <div className="grid grid-cols-2 gap-2 mt-4">
            {categoryData.map((item) => (
              <div key={item.name} className="flex items-center gap-2 text-sm">
                <div 
                  className="w-3 h-3 rounded-full" 
                  style={{ backgroundColor: item.color }}
                />
                <span className="text-gray-600">{item.name}</span>
                <span className="font-medium ml-auto">
                  {item.value.toLocaleString('fr-FR')} €
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* Recent Activity */}
        <div className="bg-white rounded-xl shadow-sm border p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-gray-900">Factures Récentes</h3>
            <a href="/invoices" className="text-blue-600 text-sm hover:underline">
              Voir tout
            </a>
          </div>
          <div className="space-y-3">
            {recentInvoices.map((invoice) => (
              <div 
                key={invoice.id} 
                className="flex items-center justify-between p-3 hover:bg-gray-50 rounded-lg border"
              >
                <div className="flex items-center gap-3">
                  <div className={`w-2 h-2 rounded-full ${
                    invoice.status === 'matched' ? 'bg-green-500' :
                    invoice.status === 'pending' ? 'bg-yellow-500' : 'bg-red-500'
                  }`} />
                  <div>
                    <p className="font-medium text-gray-900">{invoice.supplier}</p>
                    <p className="text-sm text-gray-500">{invoice.number}</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="font-medium">{invoice.amount.toLocaleString('fr-FR')} €</p>
                  <div className="flex items-center gap-2 text-sm text-gray-500">
                    {invoice.vehicle && (
                      <span className="flex items-center gap-1">
                        <Car className="w-3 h-3" />
                        {invoice.vehicle}
                      </span>
                    )}
                    <span>{invoice.date}</span>
                  </div>
                </div>
              </div>
            ))}
            {recentInvoices.length === 0 && (
              <div className="text-sm text-gray-500">Aucune facture disponible pour le moment.</div>
            )}
          </div>
        </div>
      </div>

      {/* Vehicle Quick Search */}
      <div className="bg-gradient-to-r from-blue-600 to-blue-700 rounded-xl p-6 text-white">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-xl font-semibold mb-2">Rechercher par Immatriculation</h3>
            <p className="text-blue-100">Trouvez rapidement toutes les factures liées à un véhicule</p>
          </div>
          <div className="flex gap-3">
            <input
              type="text"
              placeholder="AB-123-CD"
              className="px-4 py-2 rounded-lg text-gray-900 w-48 uppercase"
              maxLength={9}
              value={vehicleSearch}
              onChange={(e) => setVehicleSearch(e.target.value)}
              onKeyPress={handleKeyPress}
            />
            <button
              onClick={handleVehicleSearch}
              className="px-4 py-2 bg-white text-blue-600 rounded-lg font-medium hover:bg-blue-50"
            >
              Rechercher
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

const StatCard = ({ title, value, icon: Icon, trend, trendUp, trendDown, alert, color }) => {
  const colors = {
    blue: 'bg-blue-50 text-blue-600',
    yellow: 'bg-yellow-50 text-yellow-600',
    red: 'bg-red-50 text-red-600',
    green: 'bg-green-50 text-green-600',
  };

  return (
    <div className="bg-white rounded-xl shadow-sm border p-6">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-sm text-gray-600">{title}</p>
          <p className="text-2xl font-bold text-gray-900 mt-1">{value}</p>
          {trend !== undefined && (
            <div className={`flex items-center gap-1 mt-2 text-sm ${
              trendUp ? 'text-green-600' : trendDown ? 'text-red-600' : 'text-gray-600'
            }`}>
              {trendUp ? <TrendingUp className="w-4 h-4" /> : trendDown ? <TrendingDown className="w-4 h-4" /> : <span className="w-4 h-4">−</span>}
              {Math.abs(trend)}%
              <span className="text-gray-500 ml-1">vs mois dernier</span>
            </div>
          )}
        </div>
        <div className={`p-3 rounded-lg ${colors[color]}`}>
          <Icon className="w-5 h-5" />
        </div>
      </div>
      {alert && (
        <div className="mt-3 px-3 py-1 bg-red-50 text-red-700 text-xs rounded-full inline-block">
          Action requise
        </div>
      )}
    </div>
  );
};

export default Dashboard;
