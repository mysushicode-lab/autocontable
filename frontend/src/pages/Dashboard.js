import React, { useRef, useState } from 'react';
import { useQuery } from 'react-query';
import { useNavigate } from 'react-router-dom';
import { useFilters } from '../context/FilterContext';
import { useClientFile } from '../context/ClientFileContext';
import { useAutoSelectRecentMonth } from '../hooks/useAutoSelectRecentMonth';
import { 
  FileText, 
  CreditCard, 
  AlertCircle, 
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
import DropdownButton from '../components/DropdownButton';
import HelpTooltip from '../components/ui/HelpTooltip';
import { formatCurrency, formatDate } from '../utils/formatHelpers';
import { generateMonthOptions } from '../utils/dateHelpers';
import { getInvoiceStatus } from '../constants/statusConfig';


const Dashboard = () => {
  const navigate = useNavigate();
  const { selectedMonth, setSelectedMonth } = useFilters();
  const { activeClientFileId, activeClientFile } = useClientFile();
  const [showMonthDropdown, setShowMonthDropdown] = useState(false);
  const monthButtonRef = useRef(null);
  const trendMonths = 12; // Default to 12 months for trends
  const today = new Date();
  
  // Use selectedMonth from FilterContext, default to current month if not set
  const globalPeriod = selectedMonth !== undefined ? selectedMonth : `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;
  const filters = {
    ...(globalPeriod ? { month: parseInt(globalPeriod.split('-')[1]), year: parseInt(globalPeriod.split('-')[0]) } : {}),
    ...(activeClientFileId != null ? { client_file_id: activeClientFileId } : {}),
  };
  
  const periodOptions = [
    { value: '', label: 'Toutes périodes' },
    ...generateMonthOptions(12),
  ];

  // Note: Automatic email fetch disabled to avoid conflicts with scheduler
  // Scheduler handles initial fetch on startup (from start of current month)

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
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div>
          <div className="flex items-center gap-1.5">
            <h1 className="text-lg font-semibold text-gray-900">Tableau de Bord</h1>
            <HelpTooltip text="Vue synthétique des factures, transactions et rapprochements du dossier sélectionné." />
          </div>
          <p className="text-xs text-gray-500 mt-0.5">
            {activeClientFile
              ? `Dossier : ${activeClientFile.name}${activeClientFile.activity ? ` · ${activeClientFile.activity}` : ''}`
              : 'Vue d\'ensemble — tous les dossiers'}
          </p>
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
          value={formatCurrency(stats.totalAmount)}
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
        <div className="rounded-md border border-gray-100 bg-white p-6 shadow-sm">
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
                className="flex items-center justify-between p-3 rounded-md border border-gray-100 bg-gray-50 hover:bg-white"
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
                  <p className="font-medium text-gray-900">{formatCurrency(tx.amount)}</p>
                  <span className="text-sm text-gray-500">{formatDate(tx.date)}</span>
                </div>
              </div>
            ))}
            {recentTransactions.length === 0 && (
              <div className="text-sm text-gray-500">Aucune transaction disponible pour le moment.</div>
            )}
          </div>
        </div>

        {/* Recent Activity */}
        <div className="rounded-md border border-gray-100 bg-white p-6 shadow-sm">
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
                className="flex items-center justify-between p-3 rounded-md border border-gray-100 bg-gray-50 hover:bg-white"
              >
                <div className="flex items-center gap-3">
                  <div className="relative">
                    <div className={`w-2 h-2 rounded-full ${getInvoiceStatus(invoice.status).dot}`} />
                    <div className={`absolute inset-0 w-2 h-2 rounded-full animate-ping opacity-75 ${getInvoiceStatus(invoice.status).dot}`} />
                  </div>
                  <div>
                    <p className="font-medium text-gray-900">{invoice.supplier}</p>
                    <p className="text-sm text-gray-500">{invoice.number}</p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="font-medium text-gray-900">{formatCurrency(invoice.amount)}</p>
                  <div className="flex items-center gap-2 text-sm text-gray-500">
                    {invoice.reference_number && (
                      <span>{invoice.reference_number}</span>
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

      {/* CTA rapprochement si factures en attente */}
      {stats.pendingReconciliation > 0 && (
        <div className="rounded-md border border-white/40 bg-blue-600 p-5 text-white shadow-xl">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div>
              <h3 className="text-lg font-semibold mb-1">
                {stats.pendingReconciliation} facture{stats.pendingReconciliation > 1 ? 's' : ''} en attente de rapprochement
              </h3>
              <p className="text-blue-100 text-sm">Lancez le rapprochement automatique pour les traiter</p>
            </div>
            <a
              href="/reconciliation"
              className="px-4 py-2 bg-white text-blue-600 rounded-md font-medium hover:bg-blue-50 whitespace-nowrap text-sm text-center"
            >
              Aller au rapprochement →
            </a>
          </div>
        </div>
      )}
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
    <div className="rounded-md border border-gray-100 bg-white p-6 shadow-sm">
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
