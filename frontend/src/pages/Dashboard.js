import React, { useState, useRef } from 'react';
import { useQuery } from 'react-query';
import { useNavigate } from 'react-router-dom';
import { useFilters } from '../context/FilterContext';
import { useAutoSelectRecentMonth } from '../hooks/useAutoSelectRecentMonth';
import { 
  FileText, 
  CreditCard, 
  AlertCircle, 
  Car,
  TrendingUp,
  TrendingDown,
  Clock
} from 'lucide-react';
import { 
  fetchInvoices, 
  fetchMonthlyReport, 
  fetchReconciliationDetails, 
  fetchReconciliationStatus, 
  fetchTrends,
  fetchTransactions
} from '../api';
import { PoweredByMysushicode } from '../components/powered-by-mysushicode';
import DropdownButton from '../components/DropdownButton';

// Period options for trend analysis
const PERIOD_OPTIONS = [
  { value: 1, label: '1 mois' },
  { value: 2, label: '2 mois' },
  { value: 3, label: '3 mois' },
  { value: 4, label: '4 mois' },
  { value: 5, label: '5 mois' },
  { value: 6, label: '6 mois' },
  { value: 7, label: '7 mois' },
  { value: 8, label: '8 mois' },
  { value: 9, label: '9 mois' },
  { value: 10, label: '10 mois' },
  { value: 11, label: '11 mois' },
  { value: 12, label: '12 mois' },
];

const Dashboard = () => {
  const navigate = useNavigate();
  const { selectedMonth, setSelectedMonth } = useFilters();
  const [vehicleSearch, setVehicleSearch] = useState('');
  const [showMonthDropdown, setShowMonthDropdown] = useState(false);
  const monthButtonRef = useRef(null);
  const trendMonths = 12; // Default to 12 months for trends
  const today = new Date();
  
  // Use selectedMonth from FilterContext, default to current month if not set
  const globalPeriod = selectedMonth !== undefined ? selectedMonth : `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;
  const filters = globalPeriod ? { month: parseInt(globalPeriod.split('-')[1]), year: parseInt(globalPeriod.split('-')[0]) } : {};
  
  // Generate period options
  const periodMonths = Array.from({ length: 12 }, (_, i) => {
    const d = new Date(today.getFullYear(), today.getMonth() - i);
    return { value: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`, label: d.toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' }) };
  });
  
  const periodOptions = [
    { value: '', label: 'Toutes périodes' },
    ...periodMonths
  ];

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
  const { data: transactionsData } = useQuery(['dashboard-transactions', filters], () => fetchTransactions(filters));
  
  // Get recent invoices (first 5)
  const recentInvoices = invoicesData?.invoices?.slice(0, 5) || [];
  
  // Get recent transactions (first 5)
  const recentTransactions = transactionsData?.transactions?.slice(0, 5) || [];
  
  // Auto-set month filter to most recent invoice date on initial load
  useAutoSelectRecentMonth(selectedMonth, setSelectedMonth);

  const invoices = invoicesData?.invoices || [];
  
  // Use real month-over-month change from trends API instead of match_rate
  const stats = {
    totalInvoices: reportData?.total_invoices || invoices.length,
    pendingReconciliation: reconciliationStatus?.unmatched_invoices ?? (reportData ? reportData.total_invoices - reportData.matched_invoices : 0),
    unmatchedBank: reconciliationDetails?.bank_only?.length || 0,
    totalAmount: reportData?.total_amount || 0,
    monthlyChange: trendsData?.month_over_month_change || 0,
    trendDirection: trendsData?.trend_direction || 'stable',
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Tableau de Bord</h1>
          <p className="text-gray-500">Vue d'ensemble de votre activité comptable</p>
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
        {/* Recent Bank Transactions */}
        <div className="rounded-md border border-slate-200/70 bg-white/70 p-6 shadow-sm backdrop-blur-md">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-semibold text-gray-900">Transactions Bancaires Récentes</h3>
            <a href="/reconciliation" className="text-blue-600 text-sm hover:underline">
              Voir tout
            </a>
          </div>
          <div className="space-y-3">
            {recentTransactions.map((tx) => (
              <div 
                key={tx.id} 
                className="flex items-center justify-between p-3 rounded-md border border-slate-200/70 bg-white/60 backdrop-blur-md hover:bg-white/80"
              >
                <div className="flex items-center gap-3">
                  <div className="relative">
                    <div className="w-2 h-2 rounded-full bg-blue-500" />
                    <div className="absolute inset-0 w-2 h-2 rounded-full bg-blue-500 animate-ping opacity-75" />
                  </div>
                  <div>
                    <p className="font-medium text-gray-900">{tx.description || 'Transaction'}</p>
                    <p className="text-sm text-gray-500">{tx.reference || tx.transaction_id}</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="font-medium text-gray-900">{tx.amount.toLocaleString('fr-FR')} €</p>
                  <span className="text-sm text-gray-500">{tx.date ? new Date(tx.date).toLocaleDateString('fr-FR') : '-'}</span>
                </div>
              </div>
            ))}
            {recentTransactions.length === 0 && (
              <div className="text-sm text-gray-500">Aucune transaction disponible pour le moment.</div>
            )}
          </div>
        </div>

        {/* Recent Activity */}
        <div className="rounded-md border border-slate-200/70 bg-white/70 p-6 shadow-sm backdrop-blur-md">
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
                className="flex items-center justify-between p-3 rounded-md border border-slate-200/70 bg-white/60 backdrop-blur-md hover:bg-white/80"
              >
                <div className="flex items-center gap-3">
                  <div className="relative">
                    <div className={`w-2 h-2 rounded-full ${
                      invoice.status === 'matched' ? 'bg-green-500' :
                      invoice.status === 'pending' ? 'bg-yellow-500' : 'bg-red-500'
                    }`} />
                    <div className={`absolute inset-0 w-2 h-2 rounded-full animate-ping opacity-75 ${
                      invoice.status === 'matched' ? 'bg-green-500' :
                      invoice.status === 'pending' ? 'bg-yellow-500' : 'bg-red-500'
                    }`} />
                  </div>
                  <div>
                    <p className="font-medium text-gray-900">{invoice.supplier}</p>
                    <p className="text-sm text-gray-500">{invoice.number}</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="font-medium text-gray-900">{invoice.amount.toLocaleString('fr-FR')} €</p>
                  <div className="flex items-center gap-2 text-sm text-gray-500">
                    {invoice.vehicle && (
                      <span>{invoice.vehicle}</span>
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
      <div className="rounded-md border border-white/40 bg-gradient-to-r from-blue-600/80 to-blue-700/80 p-6 text-white shadow-xl backdrop-blur-xl">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-xl font-semibold mb-2">Rechercher par Immatriculation</h3>
            <p className="text-blue-100">Trouvez rapidement toutes les factures liées à un véhicule</p>
          </div>
          <div className="flex gap-3">
            <input
              type="text"
              placeholder="AB-123-CD"
              className="px-4 py-2 rounded-md bg-white/90 text-gray-900 placeholder:text-gray-400 w-48 uppercase"
              maxLength={9}
              value={vehicleSearch}
              onChange={(e) => setVehicleSearch(e.target.value)}
              onKeyDown={handleKeyPress}
            />
            <button
              onClick={handleVehicleSearch}
              className="px-4 py-2 bg-white text-blue-600 rounded-md font-medium hover:bg-blue-50"
            >
              Rechercher
            </button>
          </div>
        </div>
      </div>
      <div className="fixed bottom-4 left-4 z-40">
        <PoweredByMysushicode />
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
    <div className="rounded-md border border-slate-200/70 bg-white/70 p-6 shadow-sm backdrop-blur-md">
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
        <div className={`p-3 rounded-md ${colors[color]}`}>
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
