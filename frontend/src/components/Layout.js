import React, { useState, useRef, useEffect } from 'react';
import { Link, useLocation } from 'react-router-dom';
import {
  LayoutDashboard,
  FileText,
  CreditCard,
  BarChart3,
  Car,
  Settings,
  Bell,
  Search,
  CheckCircle,
  AlertCircle,
  Info,
  AlertTriangle,
  X,
  Trash2
} from 'lucide-react';
import { useNotifications, NOTIF_TYPES } from '../context/NotificationContext';
import { useAuth } from '../context/AuthContext';

const TYPE_CONFIG = {
  [NOTIF_TYPES.SUCCESS]: { icon: CheckCircle, color: 'text-green-500', bg: 'bg-green-50' },
  [NOTIF_TYPES.ERROR]:   { icon: AlertCircle, color: 'text-red-500',   bg: 'bg-red-50'   },
  [NOTIF_TYPES.WARNING]: { icon: AlertTriangle, color: 'text-yellow-500', bg: 'bg-yellow-50' },
  [NOTIF_TYPES.INFO]:    { icon: Info,         color: 'text-blue-500', bg: 'bg-blue-50'  },
};

const timeAgo = (date) => {
  const diff = Math.floor((Date.now() - new Date(date)) / 1000);
  if (diff < 60) return "À l'instant";
  if (diff < 3600) return `Il y a ${Math.floor(diff / 60)} min`;
  if (diff < 86400) return `Il y a ${Math.floor(diff / 3600)} h`;
  return new Date(date).toLocaleDateString('fr-FR');
};

const Layout = ({ children }) => {
  const location = useLocation();
  const { notifications, unreadCount, markRead, markAllRead, remove, clearAll } = useNotifications();
  const { user } = useAuth();
  const [panelOpen, setPanelOpen] = useState(false);
  const panelRef = useRef(null);

  const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

  const menuItems = [
    { path: '/', icon: LayoutDashboard, label: 'Tableau de Bord' },
    { path: '/invoices', icon: FileText, label: 'Factures' },
    { path: '/reconciliation', icon: CreditCard, label: 'Rapprochement' },
    { path: '/vehicles', icon: Car, label: 'Par Véhicule' },
    { path: '/reports', icon: BarChart3, label: 'Rapports' },
    ...(user?.role === 'admin' ? [{ path: '/settings', icon: Settings, label: 'Paramètres' }] : []),
  ];

  // Close panel on outside click
  useEffect(() => {
    const handler = (e) => {
      if (panelRef.current && !panelRef.current.contains(e.target)) {
        setPanelOpen(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const handleBellClick = () => {
    setPanelOpen((prev) => !prev);
  };

  return (
    <div className="flex h-screen bg-gray-50">
      {/* Sidebar */}
      <aside className="w-64 bg-slate-900 text-white flex flex-col">
        <div className="p-6 border-b border-slate-700">
          <h1 className="text-xl font-bold flex items-center gap-2">
            <Car className="w-6 h-6 text-blue-400" />
            contamail
          </h1>
          <p className="text-sm text-slate-400 mt-1">Gestion Comptable</p>
        </div>
        
        <nav className="flex-1 p-4">
          {menuItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.path;
            return (
              <Link
                key={item.path}
                to={item.path}
                className={`flex items-center gap-3 px-4 py-3 rounded-lg mb-1 transition-colors ${
                  isActive 
                    ? 'bg-blue-600 text-white' 
                    : 'text-slate-300 hover:bg-slate-800'
                }`}
              >
                <Icon className="w-5 h-5" />
                {item.label}
              </Link>
            );
          })}
        </nav>
        
        <div className="p-4 border-t border-slate-700">
          <Link to="/settings" className="flex items-center gap-3 px-4 py-3 text-slate-300 hover:bg-slate-800 rounded-lg w-full">
            <Settings className="w-5 h-5" />
            Paramètres
          </Link>
        </div>
      </aside>

      {/* Main Content */}
      <div className="flex-1 flex flex-col overflow-hidden">
        {/* Header */}
        <header className="bg-white border-b px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-4 flex-1">
            <div className="relative flex-1 max-w-md">
              <Search className="w-5 h-5 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input 
                type="text"
                placeholder="Rechercher une facture, immatriculation, fournisseur..."
                className="w-full pl-10 pr-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
          </div>
          
          <div className="flex items-center gap-4">
            {/* Bell + Notification Panel */}
            <div className="relative" ref={panelRef}>
              <button
                onClick={handleBellClick}
                className="relative p-2 text-gray-600 hover:bg-gray-100 rounded-lg"
              >
                <Bell className="w-5 h-5" />
                {unreadCount > 0 && (
                  <span className="absolute top-1 right-1 min-w-[16px] h-4 bg-red-500 rounded-full text-white text-[10px] font-bold flex items-center justify-center px-0.5">
                    {unreadCount > 9 ? '9+' : unreadCount}
                  </span>
                )}
              </button>

              {panelOpen && (
                <div className="absolute right-0 top-12 w-96 bg-white rounded-xl shadow-xl border z-50 flex flex-col max-h-[520px]">
                  {/* Panel header */}
                  <div className="flex items-center justify-between px-4 py-3 border-b">
                    <h3 className="font-semibold text-gray-900">
                      Notifications
                      {unreadCount > 0 && (
                        <span className="ml-2 px-1.5 py-0.5 bg-red-100 text-red-600 text-xs rounded-full">{unreadCount} non lue{unreadCount > 1 ? 's' : ''}</span>
                      )}
                    </h3>
                    <div className="flex gap-2">
                      {unreadCount > 0 && (
                        <button onClick={markAllRead} className="text-xs text-blue-600 hover:underline">
                          Tout marquer lu
                        </button>
                      )}
                      {notifications.length > 0 && (
                        <button onClick={clearAll} className="text-xs text-gray-400 hover:text-red-500">
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      )}
                    </div>
                  </div>

                  {/* Notification list */}
                  <div className="overflow-y-auto flex-1 divide-y">
                    {notifications.length === 0 ? (
                      <div className="flex flex-col items-center justify-center py-12 text-gray-400">
                        <Bell className="w-8 h-8 mb-2 opacity-30" />
                        <p className="text-sm">Aucune notification</p>
                      </div>
                    ) : (
                      notifications.map((notif) => {
                        const { icon: Icon, color, bg } = TYPE_CONFIG[notif.type] || TYPE_CONFIG[NOTIF_TYPES.INFO];
                        return (
                          <div
                            key={notif.id}
                            onClick={() => markRead(notif.id)}
                            className={`flex gap-3 px-4 py-3 cursor-pointer hover:bg-gray-50 transition-colors ${!notif.read ? 'bg-blue-50/40' : ''}`}
                          >
                            <div className={`mt-0.5 p-1.5 rounded-lg ${bg} flex-shrink-0`}>
                              <Icon className={`w-4 h-4 ${color}`} />
                            </div>
                            <div className="flex-1 min-w-0">
                              <div className="flex items-start justify-between gap-2">
                                <p className={`text-sm font-medium text-gray-900 ${!notif.read ? 'font-semibold' : ''}`}>
                                  {notif.title}
                                </p>
                                <button
                                  onClick={(e) => { e.stopPropagation(); remove(notif.id); }}
                                  className="text-gray-300 hover:text-gray-500 flex-shrink-0"
                                >
                                  <X className="w-3.5 h-3.5" />
                                </button>
                              </div>
                              <p className="text-xs text-gray-500 mt-0.5 leading-relaxed">{notif.message}</p>
                              <p className="text-xs text-gray-400 mt-1">{timeAgo(notif.date)}</p>
                            </div>
                            {!notif.read && (
                              <div className="w-2 h-2 bg-blue-500 rounded-full mt-2 flex-shrink-0" />
                            )}
                          </div>
                        );
                      })
                    )}
                  </div>
                </div>
              )}
            </div>

            <div className="flex items-center gap-3">
              {user?.profile_photo ? (
                <img
                  src={`${API_BASE_URL}${user.profile_photo}`}
                  alt="Profile"
                  className="w-10 h-10 rounded-full object-cover border-2 border-blue-600"
                />
              ) : (
                <div className="w-10 h-10 bg-blue-600 rounded-full flex items-center justify-center text-white font-semibold">
                  {user?.name?.charAt(0).toUpperCase() || user?.username?.charAt(0).toUpperCase() || 'U'}
                </div>
              )}
              <div className="hidden md:block">
                <p className="font-medium">{user?.name || user?.username}</p>
                <p className="text-sm text-gray-500">{user?.role === 'admin' ? 'Admin' : 'Comptable'}</p>
              </div>
            </div>
          </div>
        </header>

        {/* Page Content */}
        <main className="flex-1 overflow-auto p-6">
          {children}
        </main>
      </div>
    </div>
  );
};

export default Layout;
