import React from 'react';
import { createPortal } from 'react-dom';
import { X, Save } from 'lucide-react';
import { PREDEFINED_CATEGORIES } from '../constants/categories';

const InvoiceEditModal = ({ editingInvoice, editForm, setEditForm, onClose, onSave, isLoading }) => {
  if (!editingInvoice) return null;

  return createPortal(
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-md shadow-xl w-full max-w-2xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between p-6 border-b">
          <h3 className="text-lg font-semibold text-gray-900">Modifier la facture</h3>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded-md"><X className="w-5 h-5" /></button>
        </div>
        <div className="p-6 overflow-y-auto grid grid-cols-2 gap-4">
          <div className="space-y-1">
            <label className="text-xs font-medium text-gray-600">N° Facture</label>
            <input className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.invoice_number} onChange={e => setEditForm(f => ({ ...f, invoice_number: e.target.value }))} />
          </div>
          <div className="space-y-1">
            <label className="text-xs font-medium text-gray-600">Fournisseur</label>
            <input className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.supplier_name} onChange={e => setEditForm(f => ({ ...f, supplier_name: e.target.value }))} />
          </div>
          <div className="space-y-1">
            <label className="text-xs font-medium text-gray-600">Montant TTC (€)</label>
            <input type="number" step="0.01" className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.amount} onChange={e => setEditForm(f => ({ ...f, amount: e.target.value }))} />
          </div>
          <div className="space-y-1">
            <label className="text-xs font-medium text-gray-600">Montant HT (€)</label>
            <input type="number" step="0.01" className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.amount_ht} onChange={e => setEditForm(f => ({ ...f, amount_ht: e.target.value }))} />
          </div>
          <div className="space-y-1">
            <label className="text-xs font-medium text-gray-600">TVA (€)</label>
            <input type="number" step="0.01" className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.amount_tax} onChange={e => setEditForm(f => ({ ...f, amount_tax: e.target.value }))} />
          </div>
          <div className="space-y-1">
            <label className="text-xs font-medium text-gray-600">Catégorie</label>
            <select
              className="w-full px-3 py-2 border rounded-md text-sm bg-white"
              value={editForm.category || ''}
              onChange={e => setEditForm(f => ({ ...f, category: e.target.value }))}
            >
              <option value="">Sélectionner une catégorie</option>
              {PREDEFINED_CATEGORIES.map(cat => (
                <option key={cat} value={cat}>{cat}</option>
              ))}
            </select>
          </div>
          <div className="space-y-1">
            <label className="text-xs font-medium text-gray-600">Date facture</label>
            <input type="date" className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.date} onChange={e => setEditForm(f => ({ ...f, date: e.target.value }))} />
          </div>
          <div className="space-y-1">
            <label className="text-xs font-medium text-gray-600">Date échéance</label>
            <input type="date" className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.due_date} onChange={e => setEditForm(f => ({ ...f, due_date: e.target.value }))} />
          </div>
          <div className="space-y-1">
            <label className="text-xs font-medium text-gray-600">Référence (immatriculation, n° dossier, etc.)</label>
            <input className="w-full px-3 py-2 border rounded-md text-sm uppercase" value={editForm.reference_number} onChange={e => setEditForm(f => ({ ...f, reference_number: e.target.value }))} />
          </div>
          <div className="space-y-1">
            <label className="text-xs font-medium text-gray-600">N° Dossier / Référence interne</label>
            <input className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.work_order_reference} onChange={e => setEditForm(f => ({ ...f, work_order_reference: e.target.value }))} />
          </div>
          <div className="space-y-1">
            <label className="text-xs font-medium text-gray-600">Bon de commande</label>
            <input className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.purchase_order} onChange={e => setEditForm(f => ({ ...f, purchase_order: e.target.value }))} />
          </div>
          <div className="space-y-1">
            <label className="text-xs font-medium text-gray-600">Mode de paiement</label>
            <select className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.payment_method} onChange={e => setEditForm(f => ({ ...f, payment_method: e.target.value }))}>
              <option value="">—</option>
              <option value="virement">Virement</option>
              <option value="cheque">Chèque</option>
              <option value="carte">Carte bancaire</option>
              <option value="especes">Espèces</option>
              <option value="prelevement">Prélèvement</option>
            </select>
          </div>
          <div className="space-y-1 col-span-2">
            <label className="text-xs font-medium text-gray-600">Statut</label>
            <select className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.status} onChange={e => setEditForm(f => ({ ...f, status: e.target.value }))}>
              <option value="pending">En attente</option>
              <option value="processed">Traitée</option>
              <option value="matched">Rapprochée</option>
              <option value="unmatched">Non rapprochée</option>
            </select>
          </div>
        </div>
        <div className="flex gap-3 justify-end p-6 border-t bg-gray-50">
          <button onClick={onClose} className="px-4 py-2 border border-gray-200 rounded-md hover:bg-gray-100">Annuler</button>
          <button
            onClick={onSave}
            disabled={isLoading}
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 flex items-center gap-2"
          >
            <Save className="w-4 h-4" />
            {isLoading ? 'Enregistrement...' : 'Enregistrer'}
          </button>
        </div>
      </div>
    </div>,
    document.body
  );
};

export default InvoiceEditModal;
