import React from 'react';
import { FileDown, Pencil, Trash2, Car } from 'lucide-react';
import { getInvoicePdfUrl } from '../api';

const InvoiceTable = ({ invoices, statusConfig, onEdit, onDelete, columnVisibility }) => {
  const handleDownloadPdf = async (invoiceId) => {
    const token = localStorage.getItem('auth_token');
    const url = getInvoicePdfUrl(invoiceId);
    
    try {
      const response = await fetch(url, {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });
      
      if (!response.ok) {
        throw new Error('Failed to download PDF');
      }
      
      const blob = await response.blob();
      const downloadUrl = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.download = `facture_${invoiceId}.pdf`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(downloadUrl);
    } catch (error) {
      console.error('Error downloading PDF:', error);
    }
  };

  return (
    <div className="rounded-md border border-white/30 bg-white/50 shadow-sm backdrop-blur-md overflow-hidden">
      <table className="w-full table-fixed">
        <thead className="bg-gray-50 border-b">
          <tr>
            {columnVisibility?.invoice_number !== false && <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-48">Facture</th>}
            {columnVisibility?.supplier !== false && <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-40">Fournisseur</th>}
            {columnVisibility?.category !== false && <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-28">Catégorie</th>}
            {columnVisibility?.amount_ht !== false && <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-24">Montant HT</th>}
            {columnVisibility?.amount_tax !== false && <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-20">TVA</th>}
            {columnVisibility?.amount !== false && <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-24">Montant TTC</th>}
            {columnVisibility?.date !== false && <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-28">Date</th>}
            {columnVisibility?.vehicle !== false && <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-32">Véhicule/OT</th>}
            {columnVisibility?.status !== false && <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-32">Statut</th>}
            {columnVisibility?.actions !== false && <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase w-24">Actions</th>}
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-200">
          {invoices.map((invoice) => {
            const status = statusConfig[invoice.status] || statusConfig.pending;
            const StatusIcon = status.icon;
            
            return (
              <tr key={invoice.id} className="hover:bg-gray-50">
                {columnVisibility?.invoice_number !== false && <td className="px-4 py-3 whitespace-nowrap overflow-hidden">
                  <div className="font-medium text-gray-900 truncate" title={invoice.invoice_number}>
                    {invoice.invoice_number}
                  </div>
                  <div className="text-xs text-gray-500 truncate">
                    {invoice.purchase_order || '-'}
                  </div>
                </td>}
                {columnVisibility?.supplier !== false && <td className="px-4 py-3 whitespace-nowrap overflow-hidden">
                  <div className="font-medium text-gray-900 truncate" title={invoice.supplier}>
                    {invoice.supplier}
                  </div>
                  <div className="text-xs text-gray-500 capitalize truncate">
                    {invoice.payment_method || '-'}
                  </div>
                </td>}
                {columnVisibility?.category !== false && <td className="px-4 py-3 whitespace-nowrap">
                  <span className="px-2 py-1 bg-gray-100 rounded-full text-xs truncate inline-block max-w-full">
                    {invoice.category}
                  </span>
                </td>}
                {columnVisibility?.amount_ht !== false && <td className="px-4 py-3 whitespace-nowrap font-medium">
                  {invoice.amount_ht ? invoice.amount_ht.toLocaleString('fr-FR') : '-'} €
                </td>}
                {columnVisibility?.amount_tax !== false && <td className="px-4 py-3 whitespace-nowrap font-medium">
                  {invoice.amount_tax ? invoice.amount_tax.toLocaleString('fr-FR') : '-'} €
                </td>}
                {columnVisibility?.amount !== false && <td className="px-4 py-3 whitespace-nowrap font-medium">
                  {invoice.amount ? invoice.amount.toLocaleString('fr-FR') : '-'} €
                </td>}
                {columnVisibility?.date !== false && <td className="px-4 py-3 whitespace-nowrap text-gray-500 text-sm">
                  {invoice.date ? new Date(invoice.date).toLocaleDateString('fr-FR') : '-'}
                </td>}
                {columnVisibility?.vehicle !== false && <td className="px-4 py-3 whitespace-nowrap">
                  {invoice.vehicle_registration ? (
                    <div className="flex items-center gap-1">
                      <Car className="w-3 h-3 text-blue-600 flex-shrink-0" />
                      <span className="font-mono text-sm truncate">{invoice.vehicle_registration}</span>
                    </div>
                  ) : invoice.work_order_reference ? (
                    <span className="text-xs text-gray-600 truncate block">{invoice.work_order_reference}</span>
                  ) : (
                    <span className="text-gray-400">-</span>
                  )}
                </td>}
                {columnVisibility?.status !== false && <td className="px-4 py-3 whitespace-nowrap">
                  <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium ${status.color}`}>
                    <StatusIcon className="w-3 h-3 flex-shrink-0" />
                    <span className="truncate">{status.label}</span>
                  </span>
                </td>}
                {columnVisibility?.actions !== false && <td className="px-4 py-3 whitespace-nowrap text-center">
                  <div className="flex items-center justify-center gap-1">
                    <button
                      onClick={() => handleDownloadPdf(invoice.id)}
                      className="p-1.5 text-blue-600 hover:text-blue-800 hover:bg-blue-50 rounded-md inline-flex items-center justify-center"
                      title="Télécharger PDF"
                    >
                      <FileDown className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => onEdit(invoice)}
                      className="p-1.5 text-gray-500 hover:text-blue-600 hover:bg-blue-50 rounded-md"
                      title="Modifier"
                    >
                      <Pencil className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => onDelete(invoice)}
                      className="p-1.5 text-gray-500 hover:text-red-600 hover:bg-red-50 rounded-md"
                      title="Supprimer"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </td>}
              </tr>
            );
          })}
          {invoices.length === 0 && (
            <tr>
              <td colSpan="10" className="px-6 py-8 text-center text-sm text-gray-500">
                Aucune facture trouvée.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
};

export default InvoiceTable;
