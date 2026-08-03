import React, { useState } from 'react';
import { useQuery } from 'react-query';
import { useParams, useNavigate } from 'react-router-dom';
import {
  FileText,
  Calendar,
  Search,
  ArrowLeft,
  Download,
  Hash,
} from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, Tooltip as RechartsTooltip, ResponsiveContainer } from 'recharts';
import HelpTooltip from '../components/ui/HelpTooltip';
import { formatCurrency, formatDate, formatDateShort } from '../utils/formatHelpers';
import { downloadAuthenticatedFile } from '../utils/downloadHelpers';
import { jsPDF } from 'jspdf';
import 'jspdf-autotable';
import { fetchReferenceHistory } from '../api';

const handleDownloadInvoice = (invoiceId) =>
  downloadAuthenticatedFile(`/api/invoices/${invoiceId}/download`, `facture_${invoiceId}.pdf`)
    .catch(console.error);

const ReferenceHistory = () => {
  const { registration } = useParams();
  const [searchRef, setSearchRef] = useState(registration || '');
  const [activeRef, setActiveRef] = useState(registration || '');
  const navigate = useNavigate();

  const { data: result, isFetching, isError } = useQuery(
    ['reference-history', activeRef],
    () => fetchReferenceHistory(activeRef),
    { enabled: !!activeRef }
  );

  const handleSearch = () => {
    const ref = searchRef.toUpperCase().trim();
    if (ref) {
      setActiveRef(ref);
      navigate(`/reference/${ref}`, { replace: true });
    }
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter') handleSearch();
  };

  const spendingHistory = (result?.history || [])
    .slice()
    .reverse()
    .map((item) => ({
      month: item.date ? formatDateShort(item.date) : '-',
      amount: item.amount || 0,
    }));

  if (!result) {
    return (
      <div className="space-y-6">
        <div>
          <div className="flex items-center gap-1.5">
            <h1 className="text-lg font-semibold text-gray-900">Recherche par référence</h1>
            <HelpTooltip text="Saisissez une immatriculation ou référence pour consulter l'historique complet des factures associées." />
          </div>
          <p className="text-xs text-gray-500 mt-0.5">Retrouvez toutes les factures liées à une référence</p>
        </div>

        <div className="rounded-md border border-gray-100 bg-white p-8 text-center shadow-sm">
          <Hash className="w-12 h-12 text-gray-300 mx-auto mb-4" />
          <h2 className="text-lg font-semibold text-gray-900 mb-2">Entrez une référence</h2>
          <p className="text-gray-500 mb-6 text-sm">
            Immatriculation, numéro de dossier, référence interne…
          </p>
          <div className="flex justify-center gap-3 max-w-sm mx-auto">
            <input
              type="text"
              placeholder="AB-123-CD, REF-2024…"
              className="flex-1 px-4 py-2.5 border rounded-md uppercase text-sm tracking-wide"
              value={searchRef}
              onChange={(e) => setSearchRef(e.target.value)}
              onKeyDown={handleKeyDown}
              maxLength={30}
              autoFocus
            />
            <button
              onClick={handleSearch}
              className="px-5 py-2.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-2 text-sm"
            >
              <Search className="w-4 h-4" />
              Chercher
            </button>
          </div>
          <div className="mt-6">
            {isFetching && <p className="text-sm text-gray-400">Recherche en cours…</p>}
            {isError && activeRef && (
              <p className="text-sm text-red-500">Aucune facture trouvée pour « {activeRef} ».</p>
            )}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div className="flex items-center gap-3">
          <button
            onClick={() => { setActiveRef(''); setSearchRef(''); navigate('/reference'); }}
            className="p-2 hover:bg-gray-100 rounded-md flex-shrink-0"
          >
            <ArrowLeft className="w-5 h-5" />
          </button>
          <div>
            <h1 className="text-lg font-semibold text-gray-900">{result.registration}</h1>
            <p className="text-sm text-gray-500">
              {result.intervention_count} facture{result.intervention_count > 1 ? 's' : ''} associée{result.intervention_count > 1 ? 's' : ''}
            </p>
          </div>
        </div>
        <ExportPdfButton data={result} />
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="rounded-md border border-gray-100 bg-white p-5 shadow-sm flex items-center gap-4">
          <div className="p-3 bg-blue-50 rounded-md"><FileText className="w-5 h-5 text-blue-600" /></div>
          <div>
            <p className="text-sm text-gray-500">Total facturé</p>
            <p className="text-2xl font-bold text-gray-900">{formatCurrency(result.total_spent)}</p>
          </div>
        </div>
        <div className="rounded-md border border-gray-100 bg-white p-5 shadow-sm flex items-center gap-4">
          <div className="p-3 bg-green-50 rounded-md"><Hash className="w-5 h-5 text-green-600" /></div>
          <div>
            <p className="text-sm text-gray-500">Factures</p>
            <p className="text-2xl font-bold text-gray-900">{result.intervention_count}</p>
          </div>
        </div>
        <div className="rounded-md border border-gray-100 bg-white p-5 shadow-sm flex items-center gap-4">
          <div className="p-3 bg-yellow-50 rounded-md"><Calendar className="w-5 h-5 text-yellow-600" /></div>
          <div>
            <p className="text-sm text-gray-500">Dernière facture</p>
            <p className="text-2xl font-bold text-gray-900">
              {formatDate(result.last_visit)}
            </p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Évolution */}
        {spendingHistory.length > 1 && (
          <div className="rounded-md border border-gray-100 bg-white p-6 shadow-sm">
            <h3 className="font-semibold text-gray-900 mb-4">Évolution des montants</h3>
            <div className="h-56">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={spendingHistory}>
                  <XAxis dataKey="month" />
                  <YAxis />
                  <RechartsTooltip formatter={(v) => `${v} €`} />
                  <Line type="monotone" dataKey="amount" stroke="#3b82f6" strokeWidth={2} dot={{ fill: '#3b82f6' }} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>
        )}

        {/* Historique */}
        <div className="rounded-md border border-gray-100 bg-white p-6 shadow-sm">
          <h3 className="font-semibold text-gray-900 mb-4">Factures associées</h3>
          <div className="space-y-3">
            {result.history.map((invoice, index) => (
              <div key={index} className="flex items-start gap-3 p-3 bg-gray-50 rounded-md">
                <div className="p-1.5 bg-blue-100 rounded-md flex-shrink-0">
                  <FileText className="w-4 h-4 text-blue-600" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="font-medium text-gray-900 text-sm truncate">{invoice.invoice_number || invoice.description || '—'}</p>
                  {invoice.category && <p className="text-xs text-gray-400 mt-0.5">{invoice.category}</p>}
                  <p className="text-xs text-gray-400 mt-0.5">
                    {formatDate(invoice.date)}
                  </p>
                </div>
                <div className="flex items-center gap-2 flex-shrink-0">
                  {invoice.invoice_id && (
                    <button
                      onClick={() => handleDownloadInvoice(invoice.invoice_id)}
                      className="p-1.5 text-blue-600 hover:bg-blue-50 rounded-md"
                      title="Télécharger"
                    >
                      <Download className="w-4 h-4" />
                    </button>
                  )}
                  <span className="font-semibold text-gray-900 text-sm">{formatCurrency(invoice.amount)}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

const ExportPdfButton = ({ data }) => {
  const [isGenerating, setIsGenerating] = useState(false);

  const generatePDF = async () => {
    if (!data) return;
    setIsGenerating(true);
    try {
      const doc = new jsPDF();
      const today = formatDate(new Date());
      doc.setFontSize(18);
      doc.text('Historique par référence', 14, 20);
      doc.setFontSize(12);
      doc.text(`Référence : ${data.registration}`, 14, 32);
      doc.text(`Export : ${today}`, 14, 40);
      doc.setFontSize(11);
      doc.text(`Total facturé : ${formatCurrency(data.total_spent)}`, 14, 52);
      doc.text(`Nombre de factures : ${data.intervention_count}`, 14, 60);

      doc.autoTable({
        startY: 72,
        head: [['Date', 'N° Facture', 'Catégorie', 'Montant']],
        body: data.history.map((inv) => [
          formatDate(inv.date),
          inv.invoice_number || '-',
          inv.category || '-',
          formatCurrency(inv.amount),
        ]),
        theme: 'striped',
        headStyles: { fillColor: [59, 130, 246] },
        styles: { fontSize: 10 },
      });

      doc.save(`reference_${data.registration}_${today.replace(/\//g, '-')}.pdf`);
    } catch (error) {
      alert('Erreur PDF : ' + error.message);
    } finally {
      setIsGenerating(false);
    }
  };

  return (
    <button
      onClick={generatePDF}
      disabled={isGenerating}
      className="px-3 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-2 text-sm disabled:opacity-50"
    >
      <Download className="w-4 h-4" />
      <span className="hidden sm:inline">{isGenerating ? 'Génération…' : 'Export PDF'}</span>
    </button>
  );
};

export default ReferenceHistory;
