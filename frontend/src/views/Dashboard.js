'use client';

import React, { useRef, useState, useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
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
  fetchTransactions,
  fetchClientFilesSummary
} from '../api';
import DropdownButton from '../components/DropdownButton';
import HelpTooltip from '../components/ui/HelpTooltip';
import IconBox from '../components/ui/IconBox';
import { formatCurrency, formatDate } from '../utils/formatHelpers';
import { generateMonthOptions } from '../utils/dateHelpers';
import { getInvoiceStatus } from '../constants/statusConfig';


const Dashboard = () => {
  const router = useRouter();
  const { selectedMonth, setSelectedMonth } = useFilters();
  const { activeClientFileId, activeClientFile, selectClientFile, initialized } = useClientFile();
  const [showMonthDropdown, setShowMonthDropdown] = useState(false);
  const monthButtonRef = useRef(null);
  const trendMonths = 12; // Default to 12 months for trends
  const today = new Date();

  // Auto-select first dossier if none selected
  const { data: clientFilesData } = useQuery({
    queryKey: ['client-files-summary'],
    queryFn: fetchClientFilesSummary,
    enabled: initialized && !activeClientFileId,
  });

  useEffect(() => {
    if (initialized && !activeClientFileId && clientFilesData?.client_files?.length > 0) {
      // Auto-select the first dossier
      selectClientFile(clientFilesData.client_files[0]);
    }
  }, [initialized, activeClientFileId, clientFilesData, selectClientFile]);
  
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

  const periodLabel = periodOptions.find(o => o.value === globalPeriod)?.label || 'Toutes périodes';
  const periodDisplay = periodLabel.charAt(0).toUpperCase() + periodLabel.slice(1);

  // Note: Automatic email fetch disabled to avoid conflicts with scheduler
  // Scheduler handles initial fetch on startup (from start of current month)

  const { data: invoicesData } = useQuery({
    queryKey: ['dashboard-invoices', filters],
    queryFn: () => fetchInvoices(filters),
  });
  const { data: reportData } = useQuery({
    queryKey: ['dashboard-report', filters],
    queryFn: () => fetchMonthlyReport(filters),
  });
  const { data: reconciliationStatus } = useQuery({
    queryKey: ['dashboard-reconciliation-status', filters],
    queryFn: () => fetchReconciliationStatus(filters),
  });
  const { data: reconciliationDetails } = useQuery({
    queryKey: ['dashboard-reconciliation-details', filters],
    queryFn: () => fetchReconciliationDetails(filters),
  });
  const { data: trendsData } = useQuery({
    queryKey: ['dashboard-trends', trendMonths],
    queryFn: () => fetchTrends(trendMonths),
  });
  const { data: transactionsData } = useQuery({
    queryKey: ['dashboard-transactions', filters],
    queryFn: () => fetchTransactions(filters),
  });
  
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
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 border border-gray-200 rounded-lg overflow-hidden bg-white divide-y md:divide-y-0 md:divide-x divide-gray-200">
        <StatCard
          title="Factures ce mois"
          value={stats.totalInvoices}
          icon={FileText}
          color="orange"
          period={periodDisplay}
        />
        <StatCard
          title="En attente rapprochement"
          value={stats.pendingReconciliation}
          icon={Clock}
          alert={stats.pendingReconciliation > 20}
          color="orange"
          period={periodDisplay}
        />
        <StatCard
          title="Paiements non rapprochés"
          value={stats.unmatchedBank}
          icon={AlertCircle}
          alert={stats.unmatchedBank > 0}
          color="orange"
          period={periodDisplay}
        />
        <StatCard
          title="Montant total"
          value={formatCurrency(stats.totalAmount)}
          icon={CreditCard}
          trend={stats.monthlyChange.toFixed(1)}
          trendUp={stats.trendDirection === 'up'}
          trendDown={stats.trendDirection === 'down'}
          color="orange"
          period={periodDisplay}
        />
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Recent Bank Transactions */}
        <div className="rounded-lg border border-gray-200 bg-white p-5">
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
        <div className="rounded-lg border border-gray-200 bg-white p-5">
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

const StatCard = ({ title, value, icon: Icon, trend, trendUp, trendDown, alert, color, period }) => {
  const getTrendIcon = () => {
    if (trendUp) return <TrendingUp className="w-3.5 h-3.5" />;
    if (trendDown) return <TrendingDown className="w-3.5 h-3.5" />;
    return null;
  };

  const getTrendColor = () => {
    if (trendUp) return 'text-green-600';
    if (trendDown) return 'text-red-600';
    return 'text-gray-600';
  };

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

      {trend !== undefined && (
        <div className={`flex items-center gap-1 mt-2 text-xs font-medium ${getTrendColor()}`}>
          {getTrendIcon()}
          <span>{Math.abs(trend)}%</span>
          <span className="text-gray-400 font-normal">vs mois dernier</span>
        </div>
      )}

      {alert && (
        <div className="mt-3 px-2 py-1 bg-red-50 text-red-600 text-[10px] font-medium rounded-md inline-flex items-center gap-1">
          <AlertCircle className="w-3 h-3" />
          Action requise
        </div>
      )}
    </div>
  );
};

export default Dashboard;
