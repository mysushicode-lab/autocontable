'use client';

import { useMutation } from '@tanstack/react-query';
import { deleteInvoice, updateInvoice, getExportUrl } from '../../api';
import { NOTIF_TYPES, NotificationHelpers } from '../../context/NotificationContext';
import { downloadAuthenticatedFile } from '../../utils/downloadHelpers';

export const useInvoiceDelete = ({ addNotif, invalidateQueries }) => {
  return useMutation({
    mutationFn: (id) => deleteInvoice(id),
    onSuccess: (_, deletedInvoice) => {
      invalidateQueries();
      const notif = NotificationHelpers.invoiceDeleted(deletedInvoice);
      addNotif(notif.type, notif.title, notif.message);
    },
    onError: () => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur suppression', 'Impossible de supprimer la facture.');
    },
  });
};

export const useInvoiceUpdate = ({ addNotif, invalidateQueries }) => {
  return useMutation({
    mutationFn: ({ id, data }) => updateInvoice(id, data),
    onSuccess: (result, { id }) => {
      invalidateQueries();
      const notif = NotificationHelpers.invoiceUpdated(id);
      addNotif(notif.type, notif.title, notif.message);
    },
    onError: (error) => {
      let errorMessage = 'Impossible de modifier la facture.';
      try {
        const detail = error?.response?.data?.detail;
        if (detail) {
          if (typeof detail === 'string') {
            errorMessage = detail;
          } else if (typeof detail === 'object') {
            errorMessage = JSON.stringify(detail);
          }
        }
      } catch (e) {
        console.error('Error parsing error message:', e);
      }
      addNotif(NOTIF_TYPES.ERROR, 'Erreur', errorMessage);
    },
  });
};

export const handleExportInvoices = async (parsedMonth) => {
  const today = new Date();
  const year = parsedMonth.year || today.getFullYear();
  const month = parsedMonth.month || today.getMonth() + 1;
  try {
    await downloadAuthenticatedFile(
      getExportUrl('/api/reports/export/invoices', parsedMonth),
      `invoices_${year}_${month}.csv`
    );
  } catch (error) {
    console.error('Error exporting invoices:', error);
  }
};

export const prepareEditForm = (invoice) => ({
  invoice_number: invoice.invoice_number || '',
  supplier_name: invoice.supplier || '',
  amount: invoice.amount || '',
  amount_ht: invoice.amount_ht || '',
  amount_tax: invoice.amount_tax || '',
  date: invoice.date ? invoice.date.slice(0, 10) : '',
  due_date: invoice.due_date ? invoice.due_date.slice(0, 10) : '',
  category: invoice.category || '',
  reference_number: invoice.reference_number || '',
  work_order_reference: invoice.work_order_reference || '',
  purchase_order: invoice.purchase_order || '',
  payment_method: invoice.payment_method || '',
  status: invoice.status || 'pending',
});

export const prepareSaveData = (editForm) => ({
  ...editForm,
  amount: editForm.amount || null,
  amount_ht: editForm.amount_ht || null,
  amount_tax: editForm.amount_tax || null,
});
