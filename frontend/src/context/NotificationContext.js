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
