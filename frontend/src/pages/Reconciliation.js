import React, { useRef, useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useNotifications, NOTIF_TYPES } from '../context/NotificationContext';
import { useMutation, useQuery, useQueryClient } from 'react-query';
import { 
  CreditCard, 
  CheckCircle, 
  XCircle, 
  AlertTriangle,
  Link,
  Unlink,
  FileText,
  RefreshCw,
  ChevronLeft,
  ChevronRight
} from 'lucide-react';
import {
  confirmReconciliationMatch,
  createManualReconciliationLink,
  fetchReconciliationDetails,
  fetchReconciliationStatus,
  fetchTransactions,
  importBankStatementFile,
  rejectReconciliationMatch,
  runAutomaticReconciliation,
  deleteTransaction,
} from '../api';
import DropdownButton from '../components/DropdownButton';

const Reconciliation = () => {
  const [activeTab, setActiveTab] = useState('matches');
  const [linkModal, setLinkModal] = useState(null); // { txDbId, txDescription }
  const [linkInvoiceId, setLinkInvoiceId] = useState('');
  const [showPeriodDropdown, setShowPeriodDropdown] = useState(false);
  const periodButtonRef = useRef(null);
  const bankFileInputRef = useRef(null);
  const navigate = useNavigate();
  const { add: addNotif } = useNotifications();
  const queryClient = useQueryClient();
  const today = new Date();
  const [globalPeriod, setGlobalPeriod] = useState(''); // '' = all, 'YYYY-MM' = filtered
  const periodMonths = Array.from({ length: 18 }, (_, i) => {
    const d = new Date(today.getFullYear(), today.getMonth() - i);
    return { value: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`, label: d.toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' }) };
  });
  
  const periodOptions = [
    { value: '', label: 'Toutes périodes' },
    ...periodMonths
  ];
  const filters = globalPeriod ? { month: parseInt(globalPeriod.split('-')[1]), year: parseInt(globalPeriod.split('-')[0]) } : {};

  const { data: statsData } = useQuery(['reconciliation-status', filters], () => fetchReconciliationStatus(filters));
  const { data: detailsData, isLoading } = useQuery(['reconciliation-details', filters], () => fetchReconciliationDetails(filters));
  const refreshAll = () => {
    queryClient.invalidateQueries('reconciliation-status');
    queryClient.invalidateQueries('reconciliation-details');
    queryClient.invalidateQueries('invoices');
    queryClient.invalidateQueries('transactions');
    queryClient.invalidateQueries('all-transactions');
    queryClient.invalidateQueries('dashboard-reconciliation-status');
    queryClient.invalidateQueries('dashboard-reconciliation-details');
    queryClient.invalidateQueries('dashboard-invoices');
    queryClient.invalidateQueries('dashboard-report');
  };

  const importMutation = useMutation(importBankStatementFile, {
    onSuccess: (result) => {
      refreshAll();
      setActiveTab('transactions');
      addNotif(NOTIF_TYPES.SUCCESS, 'Relevé bancaire importé', `${result.imported_count} opération${result.imported_count > 1 ? 's' : ''} importée${result.imported_count > 1 ? 's' : ''} avec succès.`);
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur import bancaire', error?.response?.data?.detail || 'Impossible d\'importer le relevé.');
    },
  });

  const runMutation = useMutation(() => runAutomaticReconciliation(filters), {
    onSuccess: (result) => {
      refreshAll();
      const n = result.matches_created;
      addNotif(
        n > 0 ? NOTIF_TYPES.SUCCESS : NOTIF_TYPES.INFO,
        'Rapprochement automatique terminé',
        n > 0 ? `${n} correspondance${n > 1 ? 's' : ''} créée${n > 1 ? 's' : ''} automatiquement.` : 'Aucune nouvelle correspondance trouvée.'
      );
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur rapprochement', error?.response?.data?.detail || 'Analyse automatique échouée.');
    },
  });

  const confirmMutation = useMutation(confirmReconciliationMatch, {
    onSuccess: () => { refreshAll(); addNotif(NOTIF_TYPES.SUCCESS, 'Correspondance confirmée', 'La facture a été rapprochée manuellement.'); },
  });

  const rejectMutation = useMutation(rejectReconciliationMatch, {
    onSuccess: () => { refreshAll(); addNotif(NOTIF_TYPES.WARNING, 'Correspondance rejetée', 'Le rapprochement a été rejeté.'); },
  });

  const manualLinkMutation = useMutation(createManualReconciliationLink, {
    onSuccess: () => {
      refreshAll();
      addNotif(NOTIF_TYPES.SUCCESS, 'Lien manuel créé', 'La facture a été liée manuellement à l\'opération bancaire.');
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur lien manuel', error?.response?.data?.detail || 'Impossible de créer le lien.');
    },
  });

  const deleteTransactionMutation = useMutation(deleteTransaction, {
    onSuccess: () => {
      refreshAll();
      addNotif(NOTIF_TYPES.SUCCESS, 'Transaction supprimée', 'La transaction a été supprimée avec succès.');
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur suppression', error?.response?.data?.detail || 'Impossible de supprimer la transaction.');
    },
  });

  const { data: transactionsData } = useQuery(['all-transactions', filters], () => fetchTransactions(filters));
  const allTransactions = transactionsData?.transactions || [];

  const matches = detailsData?.matches || [];
  const unmatchedInvoices = detailsData?.unmatched_invoices || [];
  const bankOnly = detailsData?.bank_only || [];
  const stats = {
    totalMatches: statsData?.total_matches || 0,
    confirmed: statsData?.confirmed || 0,
    pending: statsData?.pending || 0,
    unmatched: unmatchedInvoices.length,
    bankOnly: bankOnly.length,
    successRate: statsData?.total_matches ? Math.round((statsData.confirmed / statsData.total_matches) * 100) : 0,
  };

  const handleBankImportClick = () => {
    bankFileInputRef.current?.click();
  };

  const handleBankFileSelected = async (event) => {
    const selectedFile = event.target.files?.[0];
    if (!selectedFile) {
      return;
    }
    await importMutation.mutateAsync(selectedFile);
    event.target.value = '';
  };

  const handleManualLink = (txDbId, txDescription) => {
    setLinkInvoiceId('');
    setLinkModal({ txDbId, txDescription });
  };

  const submitManualLink = async () => {
    if (!linkInvoiceId) return;
    await manualLinkMutation.mutateAsync({
      invoice_id: Number(linkInvoiceId),
      transaction_id: Number(linkModal.txDbId),
    });
    setLinkModal(null);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Rapprochement Bancaire</h1>
          <p className="text-gray-500">Matcher les factures avec les opérations bancaires</p>
        </div>
        <div className="flex items-center gap-3">
          {/* Sélecteur de période */}
          <DropdownButton
            label="Toutes périodes"
            value={globalPeriod}
            options={periodOptions}
            onChange={setGlobalPeriod}
            isOpen={showPeriodDropdown}
            onToggle={() => setShowPeriodDropdown(!showPeriodDropdown)}
            buttonRef={periodButtonRef}
            width="200px"
          />
          <button onClick={handleBankImportClick} className="px-4 py-2 bg-white border rounded-md hover:bg-gray-50 flex items-center gap-2">
            <CreditCard className="w-4 h-4" />
            {importMutation.isLoading ? 'Import...' : 'Import bancaire'}
          </button>
          <input
            ref={bankFileInputRef}
            type="file"
            accept=".csv,.ofx,.qfx,.pdf"
            className="hidden"
            onChange={handleBankFileSelected}
          />
          <button onClick={() => runMutation.mutate()} className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-2">
            <RefreshCw className="w-4 h-4" />
            {runMutation.isLoading ? 'Analyse...' : 'Lancer le rapprochement'}
          </button>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <StatCard title="Total rapprochés" value={stats.totalMatches} icon={Link} color="blue" />
        <StatCard title="Confirmés" value={stats.confirmed} icon={CheckCircle} color="green" />
        <StatCard title="En attente" value={stats.pending} icon={AlertTriangle} color="yellow" />
        <StatCard title="Non rapprochés" value={stats.unmatched} icon={Unlink} color="red" />
        <StatCard title="Taux de succès" value={`${stats.successRate}%`} icon={CreditCard} color="purple" />
      </div>

      {/* Tabs */}
      <div className="rounded-md border border-white/30 bg-white/50 shadow-sm backdrop-blur-md">
        <div className="border-b">
          <div className="flex">
            <button
              onClick={() => setActiveTab('matches')}
              className={`px-6 py-4 font-medium border-b-2 ${
                activeTab === 'matches' 
                  ? 'border-blue-600 text-blue-600' 
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              Correspondances ({matches.filter(m => m.transaction).length})
            </button>
            <button
              onClick={() => setActiveTab('unmatched')}
              className={`px-6 py-4 font-medium border-b-2 ${
                activeTab === 'unmatched' 
                  ? 'border-blue-600 text-blue-600' 
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              Factures sans paiement ({unmatchedInvoices.length})
            </button>
            <button
              onClick={() => setActiveTab('bankonly')}
              className={`px-6 py-4 font-medium border-b-2 ${
                activeTab === 'bankonly' 
                  ? 'border-blue-600 text-blue-600' 
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              Paiements sans facture ({bankOnly.length})
            </button>
            <button
              onClick={() => setActiveTab('transactions')}
              className={`px-6 py-4 font-medium border-b-2 ${
                activeTab === 'transactions'
                  ? 'border-blue-600 text-blue-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              Transactions importées ({allTransactions.length})
            </button>
          </div>
        </div>

        <div className="p-6">
          {isLoading && <div className="text-sm text-gray-500 mb-4">Chargement du rapprochement...</div>}
          {activeTab === 'matches' && (
            <div className="space-y-2">
              {matches.map((match) => (
                <div key={match.id} className="grid grid-cols-3 items-center px-4 py-3 rounded-md border border-white/30 bg-white/50 backdrop-blur-sm">
                  {/* Fournisseur + N° facture + score */}
                  <div className="min-w-0">
                    <p className="font-medium text-gray-900 truncate">{match.invoice.supplier || '—'}</p>
                    <p className="text-xs text-gray-400">{match.invoice.number} · {match.invoice.date ? new Date(match.invoice.date).toLocaleDateString('fr-FR') : '—'} · <span className={match.score >= 80 ? 'text-green-600 font-medium' : match.score >= 60 ? 'text-orange-500 font-medium' : 'text-red-500 font-medium'}>{match.score}%</span></p>
                  </div>
                  {/* Montant centré */}
                  <p className="font-bold text-gray-900 text-center">{match.invoice.amount.toLocaleString('fr-FR')} €</p>
                  {/* Supprimer uniquement */}
                  <div className="flex items-center justify-end">
                    <button onClick={() => rejectMutation.mutate(match.id)} className="p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-md" title="Supprimer la correspondance">
                      <XCircle className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              ))}
              {matches.length === 0 && <div className="text-sm text-gray-500">Aucune correspondance disponible.</div>}
            </div>
          )}

          {activeTab === 'unmatched' && (
            <div className="space-y-2">
              {unmatchedInvoices.map((match) => (
                <div key={match.id} className="grid grid-cols-3 items-center px-4 py-3 rounded-md border border-white/30 bg-white/50 backdrop-blur-sm">
                  <div className="min-w-0">
                    <p className="font-medium text-gray-900 truncate">{match.invoice.supplier || '—'}</p>
                    <p className="text-xs text-gray-400">{match.invoice.number} · {match.invoice.date ? new Date(match.invoice.date).toLocaleDateString('fr-FR') : '—'}</p>
                  </div>
                  <p className="font-bold text-gray-900 text-center">{match.invoice.amount.toLocaleString('fr-FR')} €</p>
                  <div className="flex items-center justify-end gap-2">
                    <button onClick={() => runMutation.mutate()} className="px-3 py-1.5 border border-gray-200 rounded-md text-xs text-gray-600 hover:bg-gray-50">
                      Relancer
                    </button>
                    <button onClick={handleBankImportClick} className="px-3 py-1.5 border border-gray-200 rounded-md text-xs text-gray-600 hover:bg-gray-50">
                      Import relevé
                    </button>
                  </div>
                </div>
              ))}
              {unmatchedInvoices.length === 0 && <div className="text-sm text-gray-500">Aucune facture non rapprochée.</div>}
            </div>
          )}

          {activeTab === 'transactions' && (
            <div className="space-y-3">
              {allTransactions.length === 0 && (
                <div className="text-sm text-gray-500">Aucune transaction pour cette période.</div>
              )}
              {allTransactions.map((tx) => (
                <div key={tx.id} className="flex items-center gap-4 p-4 bg-gray-50 rounded-md border hover:bg-gray-100 transition-colors">
                  <CreditCard className="w-5 h-5 text-gray-400 flex-shrink-0" />
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-gray-900 truncate">{tx.description || '—'}</p>
                    {tx.effect_number && (
                      <div className="mt-1">
                        <span className="text-xs text-gray-500">N° Effet : <span className="font-mono text-gray-700">{tx.effect_number}</span></span>
                      </div>
                    )}
                  </div>
                  <div className="text-right flex-shrink-0">
                    <p className={`font-bold text-lg ${tx.amount < 0 ? 'text-red-600' : 'text-green-700'}`}>
                      {tx.amount < 0 ? '' : '+'}{tx.amount?.toLocaleString('fr-FR', { minimumFractionDigits: 2 })} €
                    </p>
                    <p className="text-xs text-gray-500">{tx.date ? new Date(tx.date).toLocaleDateString('fr-FR') : '—'}</p>
                  </div>
                  <button
                    onClick={() => deleteTransactionMutation.mutate(tx.id)}
                    className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-md flex-shrink-0"
                    title="Supprimer la transaction"
                  >
                    <XCircle className="w-4 h-4" />
                  </button>
                </div>
              ))}
            </div>
          )}

          {activeTab === 'bankonly' && (
            <div className="space-y-2">
              {bankOnly.map((tx) => (
                <div key={tx.id} className="grid grid-cols-3 items-center px-4 py-3 rounded-md border border-white/30 bg-white/50 backdrop-blur-sm">
                  <div className="min-w-0">
                    <p className="font-medium text-gray-900 truncate">{tx.description || '—'}</p>
                    <p className="text-xs text-gray-400">{tx.date ? new Date(tx.date).toLocaleDateString('fr-FR') : '—'}</p>
                  </div>
                  <p className="font-bold text-gray-900 text-center">{tx.amount.toLocaleString('fr-FR')} €</p>
                  <div className="flex items-center justify-end gap-2">
                    <button onClick={() => handleManualLink(tx.db_id || tx.id, tx.description)} className="px-3 py-1.5 border border-gray-200 rounded-md text-xs text-gray-600 hover:bg-gray-50">
                      Lier
                    </button>
                    <button onClick={() => navigate('/invoices')} className="px-3 py-1.5 border border-gray-200 rounded-md text-xs text-gray-600 hover:bg-gray-50">
                      Créer facture
                    </button>
                  </div>
                </div>
              ))}
              {bankOnly.length === 0 && <div className="text-sm text-gray-500">Aucun paiement isolé trouvé.</div>}
            </div>
          )}
        </div>
      </div>
      {/* Modal lien manuel */}
      {linkModal && (
        <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50">
          <div className="bg-white rounded-md shadow-xl p-6 w-full max-w-sm mx-4">
            <h3 className="font-semibold text-gray-900 mb-1">Lier à une facture</h3>
            <p className="text-xs text-gray-500 mb-4 truncate">{linkModal.txDescription}</p>
            <label className="block text-xs font-medium text-gray-600 mb-1">ID de la facture</label>
            <input
              autoFocus
              type="number"
              value={linkInvoiceId}
              onChange={e => setLinkInvoiceId(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && submitManualLink()}
              placeholder="ex: 3"
              className="w-full px-3 py-2 border rounded-md text-sm mb-4 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <div className="flex gap-2 justify-end">
              <button onClick={() => setLinkModal(null)} className="px-4 py-2 text-sm text-gray-600 border rounded-md hover:bg-gray-50">Annuler</button>
              <button onClick={submitManualLink} disabled={!linkInvoiceId} className="px-4 py-2 text-sm bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-40">Lier</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

const StatCard = ({ title, value, icon: Icon, color }) => {
  const colors = {
    blue: 'bg-blue-50 text-blue-600',
    green: 'bg-green-50 text-green-600',
    yellow: 'bg-yellow-50 text-yellow-600',
    red: 'bg-red-50 text-red-600',
    purple: 'bg-purple-50 text-purple-600',
  };

  return (
    <div className="rounded-md border border-white/30 bg-white/50 shadow-sm backdrop-blur-md p-4">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-gray-600">{title}</p>
          <p className="text-xl font-bold text-gray-900">{value}</p>
        </div>
        <div className={`p-2 rounded-md ${colors[color]}`}>
          <Icon className="w-5 h-5" />
        </div>
      </div>
    </div>
  );
};

export default Reconciliation;
