import React, { useState, useRef, useEffect } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard,
  FileText,
  CreditCard,
  BarChart3,
  Car,
  Settings,
  Bell,
  CheckCircle,
  AlertCircle,
  Info,
  AlertTriangle,
  X,
  Trash2,
  LogOut,
  Zap
} from 'lucide-react';
import { useNotifications, NOTIF_TYPES } from '../context/NotificationContext';
import { useAuth } from '../context/AuthContext';
import { GlassDock } from './glass-dock';
import { PoweredByMysushicode } from './powered-by-mysushicode';
import { fetchPlanStatus } from '../api';

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
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [planStatus, setPlanStatus] = useState(null);
  const [showUpgradePopup, setShowUpgradePopup] = useState(false);

  useEffect(() => {
    const loadPlanStatus = async () => {
      try {
        const data = await fetchPlanStatus();
        setPlanStatus(data);
        if (data.is_trial_expired) {
          setShowUpgradePopup(true);
        }
      } catch (error) {
        console.error('Failed to load plan status:', error);
      }
    };
    loadPlanStatus();
  }, []);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };
  const [panelOpen, setPanelOpen] = useState(false);
  const panelRef = useRef(null);

  const API_BASE_URL = '';

  const menuItems = [
    { path: '/dashboard', icon: LayoutDashboard, label: 'Tableau de Bord' },
    { path: '/invoices', icon: FileText, label: 'Factures' },
    { path: '/reconciliation', icon: CreditCard, label: 'Rapprochement' },
    { path: '/vehicles', icon: Car, label: 'Par Véhicule' },
    { path: '/reports', icon: BarChart3, label: 'Rapports' },
    { path: '/settings', icon: Settings, label: 'Paramètres' },
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
        <div className="p-6 pl-8 text-left">
          <img 
            src="/automatchfact_blanc.png" 
            alt="Logo" 
            className="h-16 w-auto"
          />
        </div>
        <div className="p-4">
          <GlassDock items={menuItems} activePath={location.pathname} orientation="vertical" />
        </div>
      </aside>

      {/* Main Content */}
      <div className="flex-1 flex flex-col overflow-hidden">
        {/* Header */}
        <header className="bg-white border-gray-200 border-b px-6 py-4 flex items-center justify-between">
          <div className="flex-1" />
          
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
                <div className="absolute right-0 top-12 w-96 bg-white rounded-lg shadow-xl border z-50 flex flex-col max-h-[520px]">
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
      <div className="fixed bottom-4 left-4 z-40">
        <PoweredByMysushicode />
      </div>

      {showUpgradePopup && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 animate-in fade-in duration-200">
          <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4 animate-in zoom-in-95 duration-200">
            <div className="flex items-center gap-3 mb-4">
              <Zap className="w-8 h-8 text-red-600" />
              <h3 className="text-xl font-semibold text-gray-900">Période d'essai terminée</h3>
            </div>
            <p className="text-sm text-gray-600 mb-4">
              Votre période d'essai de 7 jours est terminée. Toutes les fonctionnalités sont maintenant bloquées.
            </p>
            <p className="text-xs text-gray-500 mb-6">
              Pour continuer à utiliser autofactmatch, veuillez mettre à niveau vers un plan payant.
            </p>
            <div className="flex gap-3 justify-end">
              <button
                onClick={() => setShowUpgradePopup(false)}
                className="px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50 text-sm font-medium transition-colors"
              >
                Fermer
              </button>
              <button
                onClick={() => navigate('/settings')}
                className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm font-medium transition-colors"
              >
                Voir les plans
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Layout;
