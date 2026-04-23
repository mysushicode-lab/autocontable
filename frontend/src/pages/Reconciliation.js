import React, { useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from 'react-query';
import { 
  CreditCard, 
  CheckCircle, 
  XCircle, 
  AlertTriangle,
  Link,
  Unlink,
  FileText,
  RefreshCw
} from 'lucide-react';
import {
  confirmReconciliationMatch,
  createManualReconciliationLink,
  fetchReconciliationDetails,
  fetchReconciliationStatus,
  importBankStatementFile,
  rejectReconciliationMatch,
  runAutomaticReconciliation,
} from '../api';

const Reconciliation = () => {
  const [activeTab, setActiveTab] = useState('matches');
  const bankFileInputRef = useRef(null);
  const queryClient = useQueryClient();
  const today = new Date();
  const filters = { month: today.getMonth() + 1, year: today.getFullYear() };
  const { data: statsData } = useQuery(['reconciliation-status', filters], () => fetchReconciliationStatus(filters));
  const { data: detailsData, isLoading } = useQuery(['reconciliation-details', filters], () => fetchReconciliationDetails(filters));
  const refreshAll = () => {
    queryClient.invalidateQueries('reconciliation-status');
    queryClient.invalidateQueries('reconciliation-details');
    queryClient.invalidateQueries('invoices');
    queryClient.invalidateQueries('transactions');
    queryClient.invalidateQueries('dashboard-reconciliation-status');
    queryClient.invalidateQueries('dashboard-reconciliation-details');
    queryClient.invalidateQueries('dashboard-invoices');
    queryClient.invalidateQueries('dashboard-report');
  };

  const importMutation = useMutation(importBankStatementFile, {
    onSuccess: (result) => {
      refreshAll();
      alert(`Relevé importé: ${result.imported_count} transaction(s)`);
    },
    onError: (error) => {
      alert(error?.response?.data?.detail || 'Échec de l\'import bancaire');
    },
  });

  const runMutation = useMutation(() => runAutomaticReconciliation(filters), {
    onSuccess: (result) => {
      refreshAll();
      alert(`Rapprochement terminé: ${result.matches_created} correspondance(s) créée(s)`);
    },
    onError: (error) => {
      alert(error?.response?.data?.detail || 'Échec du rapprochement automatique');
    },
  });

  const confirmMutation = useMutation(confirmReconciliationMatch, {
    onSuccess: () => refreshAll(),
  });

  const rejectMutation = useMutation(rejectReconciliationMatch, {
    onSuccess: () => refreshAll(),
  });

  const manualLinkMutation = useMutation(createManualReconciliationLink, {
    onSuccess: () => {
      refreshAll();
      alert('Lien manuel créé');
    },
    onError: (error) => {
      alert(error?.response?.data?.detail || 'Échec du lien manuel');
    },
  });

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

  const handleManualLink = async (transactionDbId) => {
    const invoiceId = window.prompt('Entrez l\'ID de la facture à lier manuellement :');
    if (!invoiceId) {
      return;
    }
    await manualLinkMutation.mutateAsync({
      invoice_id: Number(invoiceId),
      transaction_id: Number(transactionDbId),
    });
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Rapprochement Bancaire</h1>
          <p className="text-gray-500">Matcher les factures avec les opérations bancaires</p>
        </div>
        <div className="flex gap-3">
          <button onClick={handleBankImportClick} className="px-4 py-2 bg-white border rounded-lg hover:bg-gray-50 flex items-center gap-2">
            <CreditCard className="w-4 h-4" />
            {importMutation.isLoading ? 'Import...' : 'Import bancaire'}
          </button>
          <input
            ref={bankFileInputRef}
            type="file"
            accept=".csv,.ofx,.qfx"
            className="hidden"
            onChange={handleBankFileSelected}
          />
          <button onClick={() => runMutation.mutate()} className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center gap-2">
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
      <div className="bg-white rounded-xl shadow-sm border">
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
          </div>
        </div>

        <div className="p-6">
          {isLoading && <div className="text-sm text-gray-500 mb-4">Chargement du rapprochement...</div>}
          {activeTab === 'matches' && (
            <div className="space-y-4">
              {matches.map((match) => (
                <div key={match.id} className="flex items-center gap-4 p-4 bg-green-50 rounded-lg border border-green-200">
                  {/* Facture */}
                  <div className="flex-1 p-3 bg-white rounded-lg">
                    <div className="flex items-center gap-2 mb-2">
                      <FileText className="w-4 h-4 text-blue-600" />
                      <span className="font-medium">{match.invoice.number}</span>
                    </div>
                    <p className="text-sm text-gray-600">{match.invoice.supplier}</p>
                    <p className="font-semibold">{match.invoice.amount.toLocaleString('fr-FR')} €</p>
                    <p className="text-xs text-gray-500">{match.invoice.date ? new Date(match.invoice.date).toLocaleDateString('fr-FR') : '-'}</p>
                  </div>

                  {/* Connector */}
                  <div className="flex flex-col items-center">
                    <div className="flex items-center gap-2">
                      <Link className="w-5 h-5 text-green-600" />
                      <span className="text-xs font-medium text-green-700">
                        {match.score}%
                      </span>
                    </div>
                    <div className="w-px h-8 bg-green-300 my-1"></div>
                  </div>

                  {/* Transaction */}
                  <div className="flex-1 p-3 bg-white rounded-lg">
                    <div className="flex items-center gap-2 mb-2">
                      <CreditCard className="w-4 h-4 text-green-600" />
                      <span className="font-medium text-sm">{match.transaction.id}</span>
                    </div>
                    <p className="text-sm text-gray-600">{match.transaction.description}</p>
                    <p className="font-semibold">{match.transaction.amount.toLocaleString('fr-FR')} €</p>
                    <p className="text-xs text-gray-500">{match.transaction.date ? new Date(match.transaction.date).toLocaleDateString('fr-FR') : '-'}</p>
                  </div>

                  {/* Actions */}
                  <div className="flex gap-2">
                    <button onClick={() => confirmMutation.mutate(match.id)} className="p-2 text-green-600 hover:bg-green-100 rounded-lg">
                      <CheckCircle className="w-5 h-5" />
                    </button>
                    <button onClick={() => rejectMutation.mutate(match.id)} className="p-2 text-red-600 hover:bg-red-100 rounded-lg">
                      <XCircle className="w-5 h-5" />
                    </button>
                  </div>
                </div>
              ))}
              {matches.length === 0 && <div className="text-sm text-gray-500">Aucune correspondance disponible.</div>}
            </div>
          )}

          {activeTab === 'unmatched' && (
            <div className="space-y-4">
              {unmatchedInvoices.map((match) => (
                <div key={match.id} className="flex items-center gap-4 p-4 bg-red-50 rounded-lg border border-red-200">
                  <div className="p-3 bg-white rounded-lg flex-1">
                    <div className="flex items-center gap-2 mb-2">
                      <FileText className="w-4 h-4 text-blue-600" />
                      <span className="font-medium">{match.invoice.number}</span>
                      {match.vehicle && (
                        <span className="ml-2 px-2 py-0.5 bg-blue-100 text-blue-700 text-xs rounded">
                          {match.vehicle}
                        </span>
                      )}
                    </div>
                    <p className="text-sm text-gray-600">{match.invoice.supplier}</p>
                    <p className="font-semibold">{match.invoice.amount.toLocaleString('fr-FR')} €</p>
                    <p className="text-xs text-gray-500">{match.invoice.date ? new Date(match.invoice.date).toLocaleDateString('fr-FR') : '-'}</p>
                  </div>

                  <div className="flex items-center gap-2 text-red-600">
                    <XCircle className="w-5 h-5" />
                    <span className="text-sm font-medium">Aucun paiement trouvé</span>
                  </div>

                  <div className="flex gap-2">
                    <button onClick={() => runMutation.mutate()} className="px-3 py-2 bg-white border rounded-lg text-sm hover:bg-gray-50">
                      Relancer auto
                    </button>
                    <button onClick={handleBankImportClick} className="px-3 py-2 bg-red-600 text-white rounded-lg text-sm hover:bg-red-700">
                      Import relevé
                    </button>
                  </div>
                </div>
              ))}
              {unmatchedInvoices.length === 0 && <div className="text-sm text-gray-500">Aucune facture non rapprochée.</div>}
            </div>
          )}

          {activeTab === 'bankonly' && (
            <div className="space-y-4">
              {bankOnly.map((tx) => (
                <div key={tx.id} className="flex items-center gap-4 p-4 bg-yellow-50 rounded-lg border border-yellow-200">
                  <div className="p-3 bg-white rounded-lg flex-1">
                    <div className="flex items-center gap-2 mb-2">
                      <CreditCard className="w-4 h-4 text-yellow-600" />
                      <span className="font-medium">{tx.id}</span>
                    </div>
                    <p className="text-sm text-gray-600">{tx.description}</p>
                    <p className="font-semibold">{tx.amount.toLocaleString('fr-FR')} €</p>
                    <p className="text-xs text-gray-500">{tx.date ? new Date(tx.date).toLocaleDateString('fr-FR') : '-'}</p>
                  </div>

                  <div className="flex items-center gap-2 text-yellow-600">
                    <AlertTriangle className="w-5 h-5" />
                    <span className="text-sm font-medium">Pas de facture associée</span>
                  </div>

                  <div className="flex gap-2">
                    <button onClick={() => handleManualLink(tx.db_id || tx.id)} className="px-3 py-2 bg-white border rounded-lg text-sm hover:bg-gray-50">
                      Lier manuellement
                    </button>
                    <button onClick={() => window.alert('Importez d\'abord la facture via le bouton Nouvelle Facture, puis utilisez Lier manuellement.')} className="px-3 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700">
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
    <div className="bg-white rounded-xl shadow-sm border p-4">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-gray-600">{title}</p>
          <p className="text-xl font-bold text-gray-900">{value}</p>
        </div>
        <div className={`p-2 rounded-lg ${colors[color]}`}>
          <Icon className="w-5 h-5" />
        </div>
      </div>
    </div>
  );
};

export default Reconciliation;
