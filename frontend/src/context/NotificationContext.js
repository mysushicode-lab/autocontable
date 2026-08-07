import React, { createContext, useContext, useState, useCallback, useRef, useEffect } from 'react';
import { fetchInvoices } from '../api';

const NotificationContext = createContext(null);

let _idCounter = 0;
const nextId = () => ++_idCounter;

export const NOTIF_TYPES = {
  SUCCESS: 'success',
  ERROR: 'error',
  INFO: 'info',
  WARNING: 'warning',
};

// Helper functions for comptable-friendly notifications
export const NotificationHelpers = {
  invoiceImported: (invoice) => ({
    type: NOTIF_TYPES.SUCCESS,
    title: 'Facture importée',
    message: `${invoice.invoice_number || 'N/A'} • ${invoice.supplier || 'Fournisseur'} • ${invoice.amount ? new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(invoice.amount) : '-'}`,
  }),

  invoicesImported: (count, total) => ({
    type: NOTIF_TYPES.SUCCESS,
    title: `${count} facture${count > 1 ? 's' : ''} importée${count > 1 ? 's' : ''}`,
    message: total ? `Montant total: ${new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(total)}` : `${count} nouvelle${count > 1 ? 's' : ''} facture${count > 1 ? 's' : ''}`,
  }),

  reconciliationComplete: (matched, total) => ({
    type: NOTIF_TYPES.INFO,
    title: 'Rapprochement terminé',
    message: `${matched}/${total} facture${total > 1 ? 's' : ''} rapprochée${matched > 1 ? 's' : ''} (${total > 0 ? Math.round((matched / total) * 100) : 0}%)`,
  }),

  bankImported: (count, period) => ({
    type: NOTIF_TYPES.SUCCESS,
    title: 'Relevé bancaire importé',
    message: `${count} opération${count > 1 ? 's' : ''} importée${count > 1 ? 's' : ''}${period ? ` • ${period}` : ''}`,
  }),

  reconciliationPending: (count) => ({
    type: NOTIF_TYPES.WARNING,
    title: `${count} facture${count > 1 ? 's' : ''} en attente`,
    message: `Rapprochement bancaire à effectuer`,
  }),

  dossierQuotaWarning: (used, limit) => ({
    type: NOTIF_TYPES.WARNING,
    title: 'Quota dossiers',
    message: `${used}/${limit} dossiers utilisés`,
  }),

  invoiceUpdated: (invoice) => ({
    type: NOTIF_TYPES.SUCCESS,
    title: 'Facture mise à jour',
    message: `${invoice.invoice_number || 'N/A'} • ${invoice.supplier || 'Fournisseur'}`,
  }),

  invoiceDeleted: (invoice) => ({
    type: NOTIF_TYPES.SUCCESS,
    title: 'Facture supprimée',
    message: `${invoice.invoice_number || 'N/A'} • ${invoice.supplier || 'Fournisseur'}`,
  }),
};

export const NotificationProvider = ({ children }) => {
  const [notifications, setNotifications] = useState([]);
  const prevInvoiceCount = useRef(null);

  const add = useCallback((type, title, message) => {
    const notif = {
      id: nextId(),
      type,
      title,
      message,
      date: new Date(),
      read: false,
    };
    setNotifications((prev) => [notif, ...prev].slice(0, 50));
  }, []);

  const markRead = useCallback((id) => {
    setNotifications((prev) =>
      prev.map((n) => (n.id === id ? { ...n, read: true } : n))
    );
  }, []);

  const markAllRead = useCallback(() => {
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
  }, []);

  const remove = useCallback((id) => {
    setNotifications((prev) => prev.filter((n) => n.id !== id));
  }, []);

  const clearAll = useCallback(() => setNotifications([]), []);

  // Poll for new invoices added by scheduler (every 60s)
  useEffect(() => {
    const check = async () => {
      if (!localStorage.getItem('auth_token')) return;
      try {
        const data = await fetchInvoices({});
        const count = data?.count ?? 0;
        if (prevInvoiceCount.current !== null && count > prevInvoiceCount.current) {
          const diff = count - prevInvoiceCount.current;
          add(
            NOTIF_TYPES.INFO,
            'Nouvelles factures détectées',
            `${diff} nouvelle${diff > 1 ? 's' : ''} facture${diff > 1 ? 's' : ''} importée${diff > 1 ? 's' : ''} par le scheduler.`
          );
        }
        prevInvoiceCount.current = count;
      } catch (err) {
        console.error('Notification polling error:', err);
      }
    };

    check();
    const interval = setInterval(check, 60_000);
    return () => clearInterval(interval);
  }, [add]);

  const unreadCount = notifications.filter((n) => !n.read).length;

  return (
    <NotificationContext.Provider value={{ notifications, unreadCount, add, markRead, markAllRead, remove, clearAll }}>
      {children}
    </NotificationContext.Provider>
  );
};

export const useNotifications = () => {
  const ctx = useContext(NotificationContext);
  if (!ctx) throw new Error('useNotifications must be used inside NotificationProvider');
  return ctx;
};
