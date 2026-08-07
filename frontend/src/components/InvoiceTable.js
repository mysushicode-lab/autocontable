import React from 'react';
import { FileDown, Pencil, Trash2 } from 'lucide-react';
import { getInvoicePdfUrl } from '../api';
import { formatCurrency, formatDate } from '../utils/formatHelpers';
import { downloadAuthenticatedFile } from '../utils/downloadHelpers';

const InvoiceTable = ({ invoices, statusConfig, onEdit, onDelete, columnVisibility }) => {
  const handleDownloadPdf = async (invoiceId) => {
    try {
      await downloadAuthenticatedFile(getInvoicePdfUrl(invoiceId), `facture_${invoiceId}.pdf`);
    } catch (error) {
      console.error('Error downloading PDF:', error);
    }
  };

  return (
    <div className="rounded-md border border-gray-100 bg-white overflow-hidden">
      <div className="overflow-x-auto">
      <table className="w-full min-w-[640px] table-fixed">
        <thead className="bg-gray-50 border-b">
          <tr>
            {columnVisibility?.invoice_number !== false && <th className="px-2 py-1.5 sm:px-4 sm:py-3 text-left text-[10px] sm:text-xs font-medium text-gray-500 uppercase w-36 sm:w-48">Facture</th>}
            {columnVisibility?.supplier !== false && <th className="px-2 py-1.5 sm:px-4 sm:py-3 text-left text-[10px] sm:text-xs font-medium text-gray-500 uppercase w-28 sm:w-40">Fournisseur</th>}
            {columnVisibility?.category !== false && <th className="px-2 py-1.5 sm:px-4 sm:py-3 text-left text-[10px] sm:text-xs font-medium text-gray-500 uppercase w-20 sm:w-28">Catégorie</th>}
            {columnVisibility?.amount_ht !== false && <th className="px-2 py-1.5 sm:px-4 sm:py-3 text-left text-[10px] sm:text-xs font-medium text-gray-500 uppercase w-16 sm:w-24">HT</th>}
            {columnVisibility?.amount_tax !== false && <th className="px-2 py-1.5 sm:px-4 sm:py-3 text-left text-[10px] sm:text-xs font-medium text-gray-500 uppercase w-14 sm:w-20">TVA</th>}
            {columnVisibility?.amount !== false && <th className="px-2 py-1.5 sm:px-4 sm:py-3 text-left text-[10px] sm:text-xs font-medium text-gray-500 uppercase w-16 sm:w-24">TTC</th>}
            {columnVisibility?.date !== false && <th className="px-2 py-1.5 sm:px-4 sm:py-3 text-left text-[10px] sm:text-xs font-medium text-gray-500 uppercase w-16 sm:w-28">Date</th>}
            {columnVisibility?.reference !== false && <th className="px-2 py-1.5 sm:px-4 sm:py-3 text-left text-[10px] sm:text-xs font-medium text-gray-500 uppercase w-20 sm:w-32">Référence</th>}
            {columnVisibility?.status !== false && <th className="px-2 py-1.5 sm:px-4 sm:py-3 text-left text-[10px] sm:text-xs font-medium text-gray-500 uppercase w-20 sm:w-32">Statut</th>}
            {columnVisibility?.actions !== false && <th className="px-2 py-1.5 sm:px-4 sm:py-3 text-center text-[10px] sm:text-xs font-medium text-gray-500 uppercase w-16 sm:w-24">Actions</th>}
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-200">
          {invoices.map((invoice) => {
            const status = statusConfig[invoice.status] || statusConfig.pending;
            const StatusIcon = status.icon;
            return (
              <tr key={invoice.id} className="">
                {columnVisibility?.invoice_number !== false && <td className="px-2 py-1.5 sm:px-4 sm:py-3 whitespace-nowrap overflow-hidden">
                  <div className="font-medium text-gray-900 truncate text-xs sm:text-sm" title={invoice.invoice_number}>{invoice.invoice_number}</div>
                  <div className="text-[10px] text-gray-500 truncate">{invoice.purchase_order || '-'}</div>
                </td>}
                {columnVisibility?.supplier !== false && <td className="px-2 py-1.5 sm:px-4 sm:py-3 whitespace-nowrap overflow-hidden">
                  <div className="font-medium text-gray-900 truncate text-xs sm:text-sm" title={invoice.supplier}>{invoice.supplier}</div>
                  <div className="text-[10px] text-gray-500 capitalize truncate">{invoice.payment_method || '-'}</div>
                </td>}
                {columnVisibility?.category !== false && <td className="px-2 py-1.5 sm:px-4 sm:py-3 whitespace-nowrap">
                  <span className="px-1.5 py-0.5 sm:px-2 sm:py-1 bg-gray-100 rounded-full text-[10px] sm:text-xs truncate inline-block max-w-full">{invoice.category}</span>
                </td>}
                {columnVisibility?.amount_ht !== false && <td className="px-2 py-1.5 sm:px-4 sm:py-3 whitespace-nowrap font-medium text-xs sm:text-sm">
                  {invoice.amount_ht ? formatCurrency(invoice.amount_ht) : '—'}
                </td>}
                {columnVisibility?.amount_tax !== false && <td className="px-2 py-1.5 sm:px-4 sm:py-3 whitespace-nowrap font-medium text-xs sm:text-sm">
                  {invoice.amount_tax ? formatCurrency(invoice.amount_tax) : '—'}
                </td>}
                {columnVisibility?.amount !== false && <td className="px-2 py-1.5 sm:px-4 sm:py-3 whitespace-nowrap font-medium text-xs sm:text-sm">
                  {invoice.amount ? formatCurrency(invoice.amount) : '—'}
                </td>}
                {columnVisibility?.date !== false && <td className="px-2 py-1.5 sm:px-4 sm:py-3 whitespace-nowrap text-gray-500 text-xs sm:text-sm">
                  {formatDate(invoice.date)}
                </td>}
                {columnVisibility?.reference !== false && <td className="px-2 py-1.5 sm:px-4 sm:py-3 whitespace-nowrap">
                  {invoice.reference_number ? (
                    <span className="font-mono text-xs sm:text-sm truncate block">{invoice.reference_number}</span>
                  ) : invoice.work_order_reference ? (
                    <span className="text-xs text-gray-600 truncate block">{invoice.work_order_reference}</span>
                  ) : <span className="text-gray-400">-</span>}
                </td>}
                {columnVisibility?.status !== false && <td className="px-2 py-1.5 sm:px-4 sm:py-3 whitespace-nowrap">
                  <span className={`inline-flex items-center gap-1 px-1.5 py-0.5 sm:px-2 sm:py-1 rounded-full text-[10px] sm:text-xs font-medium ${status.color}`}>
                    <StatusIcon className="w-2.5 h-2.5 sm:w-3 sm:h-3 flex-shrink-0" />
                    <span className="truncate">{status.label}</span>
                  </span>
                </td>}
                {columnVisibility?.actions !== false && <td className="px-2 py-1.5 sm:px-4 sm:py-3 whitespace-nowrap text-center">
                  <div className="flex items-center justify-center gap-0.5 sm:gap-1">
                    <button onClick={() => handleDownloadPdf(invoice.id)} className="p-1 sm:p-1.5 text-blue-600 hover:text-blue-800 hover:bg-blue-50 rounded-md inline-flex items-center justify-center" title="Télécharger PDF">
                      <FileDown className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                    </button>
                    <button onClick={() => onEdit(invoice)} className="p-1 sm:p-1.5 text-gray-500 hover:text-blue-600 hover:bg-blue-50 rounded-md" title="Modifier">
                      <Pencil className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                    </button>
                    <button onClick={() => onDelete(invoice)} className="p-1 sm:p-1.5 text-gray-500 hover:text-red-600 hover:bg-red-50 rounded-md" title="Supprimer">
                      <Trash2 className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                    </button>
                  </div>
                </td>}
              </tr>
            );
          })}
          {invoices.length === 0 && (
            <tr>
              <td colSpan="10" className="px-6 py-8 text-center text-sm text-gray-500">Aucune facture trouvée.</td>
            </tr>
          )}
        </tbody>
      </table>
      </div>
    </div>
  );
};

export default InvoiceTable;
