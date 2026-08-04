'use client';

import React, { useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useAuth } from '../context/AuthContext';
import { FileText, CheckCircle, Clock, AlertCircle, ChevronLeft, ChevronRight, Upload, Camera, XCircle } from 'lucide-react';
import { fetchClientSummary, fetchClientInvoices, portalUploadInvoice } from '../api';
import { formatCurrency, formatDate } from '../utils/formatHelpers';

const StatCard = ({ title, value, icon: Icon, color }) => {
  const colorClasses = {
    blue: 'bg-blue-50 text-blue-600',
    green: 'bg-green-50 text-green-600',
    orange: 'bg-orange-50 text-orange-600',
    red: 'bg-red-50 text-red-600',
  };

  return (
    <div className="bg-white rounded-lg border border-gray-200 p-4 shadow-sm">
      <div className="flex items-center justify-between mb-2">
        <span className="text-sm text-gray-500">{title}</span>
        <div className={`p-2 rounded-lg ${colorClasses[color] || colorClasses.blue}`}>
          <Icon className="w-4 h-4" />
        </div>
      </div>
      <div className="text-2xl font-semibold text-gray-900">{value}</div>
    </div>
  );
};

const StatusBadge = ({ status }) => {
  const config = {
    matched: { label: 'Rapprochée', className: 'bg-green-100 text-green-700' },
    pending: { label: 'En attente', className: 'bg-orange-100 text-orange-700' },
    unmatched: { label: 'Non rapprochée', className: 'bg-red-100 text-red-700' },
    processed: { label: 'Traitée', className: 'bg-blue-100 text-blue-700' },
  };

  const { label, className } = config[status] || config.pending;
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium ${className}`}>
      {label}
    </span>
  );
};

const ClientPortal = () => {
  const { user } = useAuth();
  const queryClient = useQueryClient();
  const [currentPage, setCurrentPage] = useState(1);
  const [uploading, setUploading] = useState(false);
  const [uploadResults, setUploadResults] = useState([]);
  const [dragOver, setDragOver] = useState(false);

  // For client users, clientFileId is null (backend reads from user.client_file_id)
  // For accountants, they can pass client_file_id (future enhancement)
  const clientFileId = user?.role === 'client' ? null : null;

  const { data: summary, isLoading: summaryLoading } = useQuery(
    ['client-summary', clientFileId],
    () => fetchClientSummary(clientFileId)
  );

  const { data: invoicesData, isLoading: invoicesLoading } = useQuery(
    ['client-invoices', clientFileId, currentPage],
    () => fetchClientInvoices(clientFileId, currentPage)
  );

  const handleFiles = async (files) => {
    setUploading(true);
    const results = [];

    for (const file of files) {
      try {
        const result = await portalUploadInvoice(file);
        results.push({ file: file.name, success: true, ...result });
      } catch (err) {
        results.push({ file: file.name, success: false, error: err.response?.data?.detail || "Erreur" });
      }
    }

    setUploadResults(results);
    setUploading(false);
    // Refetch invoices and summary
    queryClient.invalidateQueries(['client-invoices']);
    queryClient.invalidateQueries(['client-summary']);
  };

  const handleDrop = (e) => {
    e.preventDefault();
    setDragOver(false);
    const files = Array.from(e.dataTransfer.files);
    if (files.length) handleFiles(files);
  };

  const handleFileInput = (e) => {
    const files = Array.from(e.target.files);
    if (files.length) handleFiles(files);
  };

  if (summaryLoading || invoicesLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-gray-500">Chargement...</div>
      </div>
    );
  }

  const stats = summary?.stats || {};
  const dossier = summary?.dossier || {};
  const invoices = invoicesData?.invoices || [];
  const totalPages = invoicesData?.total_pages || 1;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-lg font-semibold text-gray-900">Mon Espace</h1>
        <p className="text-xs text-gray-500 mt-0.5">
          {dossier.name ? `Dossier : ${dossier.name}` : 'Votre espace client'}
        </p>
      </div>

      {/* Upload Section */}
      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <h2 className="text-sm font-semibold text-gray-900 mb-3">Envoyer une facture</h2>
        <div
          onDrop={handleDrop}
          onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
          onDragLeave={() => setDragOver(false)}
          className={`border-2 border-dashed rounded-lg p-8 text-center transition-colors ${
            dragOver ? 'border-blue-400 bg-blue-50' : 'border-gray-200 hover:border-gray-300'
          }`}
        >
          <Upload className="w-8 h-8 text-gray-400 mx-auto mb-3" />
          <p className="text-sm text-gray-600 mb-1">Glissez vos factures ici</p>
          <p className="text-xs text-gray-400 mb-3">PDF, PNG, JPG — max 10 Mo</p>
          <label className="inline-flex items-center gap-2 px-4 py-2 bg-gray-900 text-white rounded-md text-xs font-medium cursor-pointer hover:bg-gray-800">
            <Camera className="w-3.5 h-3.5" />
            {uploading ? 'Import en cours...' : 'Scanner ou choisir un fichier'}
            <input type="file" multiple accept=".pdf,.png,.jpg,.jpeg" onChange={handleFileInput} className="hidden" disabled={uploading} />
          </label>
        </div>

        {/* Upload results */}
        {uploadResults.length > 0 && (
          <div className="mt-4 space-y-2">
            {uploadResults.map((r, i) => (
              <div key={i} className={`flex items-center gap-2 text-xs p-2 rounded ${r.success ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'}`}>
                {r.success ? <CheckCircle className="w-3.5 h-3.5" /> : <XCircle className="w-3.5 h-3.5" />}
                <span className="font-medium">{r.file}</span>
                {r.success && <span>— {r.supplier || 'Fournisseur'} · {r.amount?.toFixed(2)}€</span>}
                {!r.success && <span>— {r.error}</span>}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="Total factures"
          value={stats.total_invoices || 0}
          icon={FileText}
          color="blue"
        />
        <StatCard
          title="Rapprochées"
          value={stats.matched || 0}
          icon={CheckCircle}
          color="green"
        />
        <StatCard
          title="En attente"
          value={stats.pending || 0}
          icon={Clock}
          color="orange"
        />
        <StatCard
          title="Taux de rapprochement"
          value={`${stats.match_rate || 0}%`}
          icon={CheckCircle}
          color="green"
        />
      </div>

      {/* Recent Invoices */}
      <div className="bg-white rounded-lg border border-gray-200 shadow-sm">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-base font-semibold text-gray-900">Vos Factures</h2>
        </div>

        {invoices.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-12">
            <FileText className="w-10 h-10 text-gray-300 mb-3" />
            <p className="text-sm text-gray-500">Aucune facture pour le moment</p>
          </div>
        ) : (
          <>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Date
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Numéro
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Fournisseur
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Montant
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Statut
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {invoices.map((invoice) => (
                    <tr key={invoice.id} className="hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {invoice.date ? formatDate(invoice.date) : '—'}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {invoice.invoice_number || '—'}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {invoice.supplier || '—'}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-right font-medium">
                        {formatCurrency(invoice.amount)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm">
                        <StatusBadge status={invoice.status} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="px-6 py-4 border-t border-gray-200 flex items-center justify-between">
                <div className="text-sm text-gray-500">
                  Page {currentPage} sur {totalPages}
                </div>
                <div className="flex gap-2">
                  <button
                    onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                    disabled={currentPage === 1}
                    className="px-3 py-1.5 text-sm border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-1"
                  >
                    <ChevronLeft className="w-4 h-4" />
                    Précédent
                  </button>
                  <button
                    onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                    disabled={currentPage === totalPages}
                    className="px-3 py-1.5 text-sm border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-1"
                  >
                    Suivant
                    <ChevronRight className="w-4 h-4" />
                  </button>
                </div>
              </div>
            )}
          </>
        )}
      </div>

      {/* Info Footer */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div className="flex gap-3">
          <div className="shrink-0">
            <AlertCircle className="w-5 h-5 text-blue-600" />
          </div>
          <div>
            <h3 className="text-sm font-medium text-blue-900 mb-1">Qu'est-ce que le rapprochement ?</h3>
            <p className="text-xs text-blue-700 leading-relaxed">
              Le rapprochement vérifie que vos factures correspondent bien aux paiements sur votre compte bancaire.
              Une facture "rapprochée" signifie que le paiement a été identifié et validé par votre comptable.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ClientPortal;
