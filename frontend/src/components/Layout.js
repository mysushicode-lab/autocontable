import React, { useState, useRef, useEffect } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import {
  FolderKanban, Gauge, Receipt, GitMerge, BookMarked, TrendingUp,
  SlidersHorizontal, Bell, CheckCircle, AlertCircle, Info, AlertTriangle,
  X, Trash2, LogOut, Zap, Menu, ChevronRight, ArrowUp, FolderOpen,
  Clock, Gift, BookOpen, HelpCircle, MessageSquare, ExternalLink,
} from 'lucide-react';
import { useQuery } from 'react-query';
import { useNotifications, NOTIF_TYPES } from '../context/NotificationContext';
import { useAuth } from '../context/AuthContext';
import { useClientFile } from '../context/ClientFileContext';
import { useAuthImage } from '../hooks/useAuthImage';
import { fetchPlanStatus, fetchClientFilesSummary } from '../api';
import { formatDate, formatDateMedium } from '../utils/formatHelpers';

const TYPE_CONFIG = {
  [NOTIF_TYPES.SUCCESS]: { icon: CheckCircle, color: 'text-green-500', bg: 'bg-green-50' },
  [NOTIF_TYPES.ERROR]:   { icon: AlertCircle, color: 'text-red-500',   bg: 'bg-red-50'   },
  [NOTIF_TYPES.WARNING]: { icon: AlertTriangle, color: 'text-yellow-500', bg: 'bg-yellow-50' },
  [NOTIF_TYPES.INFO]:    { icon: Info,         color: 'text-blue-500', bg: 'bg-blue-50'  },
};

const PAGE_NAMES = {
  '/dashboard':      'Tableau de bord',
  '/invoices':       'Factures',
  '/reconciliation': 'Rapprochement',
  '/reports':        'Rapports',
  '/portfolio':      'Portefeuille',
  '/reference':      'Référence',
  '/settings':       'Paramètres',
};

const NAV_ITEMS = [
  { path: '/portfolio',      icon: FolderKanban, label: 'Portefeuille'    },
  { path: '/dashboard',      icon: Gauge,        label: 'Tableau de bord' },
  { path: '/invoices',       icon: Receipt,      label: 'Factures'        },
  { path: '/reconciliation', icon: GitMerge,     label: 'Rapprochement'   },
  { path: '/reference',      icon: BookMarked,   label: 'Référence'       },
  { path: '/reports',        icon: TrendingUp,   label: 'Rapports'        },
];

const timeAgo = (date) => {
  const diff = Math.floor((Date.now() - new Date(date)) / 1000);
  if (diff < 60) return "À l'instant";
  if (diff < 3600) return `Il y a ${Math.floor(diff / 60)} min`;
  if (diff < 86400) return `Il y a ${Math.floor(diff / 3600)} h`;
  return formatDate(date);
};

const statusDot = (status) => {
  if (status === 'ok') return 'bg-green-500';
  if (status === 'warning') return 'bg-yellow-400';
  if (status === 'alert') return 'bg-red-500';
  return 'bg-gray-300';
};

// ─── Nav item ────────────────────────────────────────────────────────────────

const NavItem = ({ path, icon: Icon, label, open }) => {
  const location = useLocation();
  const active = location.pathname === path || location.pathname.startsWith(path + '/');

  return (
    <Link
      to={path}
      title={!open ? label : undefined}
      className={`flex items-center rounded-md text-[13px] transition-colors duration-100 group ${
        open ? 'gap-2.5 px-2.5 py-1.5' : 'justify-center p-1.5'
      } ${
        active
          ? 'bg-white text-gray-900 font-medium border border-gray-200 shadow-sm'
          : 'text-gray-500 hover:bg-gray-50 hover:text-gray-700'
      }`}
    >
      <Icon className={`w-4 h-4 shrink-0 ${active ? 'text-gray-700' : 'text-gray-400 group-hover:text-gray-500'}`} />
      {open && <span className="truncate">{label}</span>}
    </Link>
  );
};

// ─── Dossier switcher (accordion) ────────────────────────────────────────────

const DossierSwitcher = ({ open }) => {
  const { activeClientFile, selectClientFile, clearClientFile } = useClientFile();
  const navigate = useNavigate();
  const { data: dossiersData } = useQuery('client-files-summary', fetchClientFilesSummary);
  const [expanded, setExpanded] = useState(false);

  const dossiers = dossiersData?.client_files || [];
  const displayName = activeClientFile ? activeClientFile.name : 'Tous les dossiers';

  return (
    <div>
      <button
        onClick={() => open ? setExpanded(v => !v) : navigate('/portfolio')}
        title={!open ? displayName : undefined}
        className={`w-full flex items-center gap-2 rounded-md transition-colors hover:bg-gray-50 ${
          open ? 'px-2 py-1.5' : 'justify-center p-1.5'
        }`}
      >
        <FolderOpen className="w-4 h-4 text-gray-400 shrink-0" />
        {open && (
          <>
            <span className="flex-1 min-w-0 text-left text-[13px] font-medium text-gray-700 truncate">{displayName}</span>
            <ChevronRight className={`w-3.5 h-3.5 text-gray-400 shrink-0 transition-transform duration-150 ${expanded ? 'rotate-90' : ''}`} />
          </>
        )}
      </button>

      {open && expanded && (
        <div className="mt-1 space-y-px pl-3 ml-3 border-l border-gray-200">
          <p className="px-2 pt-1 pb-0.5 text-[10px] font-semibold text-gray-400 uppercase tracking-widest">Dossiers</p>

          <div className="relative">
            {!activeClientFile && <span className="absolute -left-3 top-1/2 -translate-y-1/2 w-0.5 h-4 bg-blue-500 rounded-full" />}
            <button
              onClick={() => { clearClientFile(); setExpanded(false); navigate('/portfolio'); }}
              className={`w-full flex items-center px-2 py-1.5 rounded-md text-left text-[13px] transition-colors ${
                !activeClientFile ? 'text-gray-800 font-medium' : 'text-gray-500 hover:bg-gray-50 hover:text-gray-800'
              }`}
            >
              <span className="flex-1 truncate">Tous les dossiers</span>
            </button>
          </div>

          {dossiers.map(cf => {
            const active = activeClientFile?.id === cf.id;
            return (
              <div key={cf.id} className="relative">
                {active && <span className="absolute -left-3 top-1/2 -translate-y-1/2 w-0.5 h-4 bg-blue-500 rounded-full" />}
                <button
                  onClick={() => { selectClientFile(cf); setExpanded(false); }}
                  className={`w-full flex items-center gap-2 px-2 py-1.5 rounded-md text-left text-[13px] transition-colors ${
                    active ? 'text-gray-800 font-medium' : 'text-gray-500 hover:bg-gray-50 hover:text-gray-800'
                  }`}
                >
                  <div className="flex-1 min-w-0">
                    <p className="truncate leading-tight">{cf.name}</p>
                    {cf.activity && <p className="text-[10px] text-gray-400 truncate">{cf.activity}</p>}
                  </div>
                  <div className={`w-1.5 h-1.5 rounded-full shrink-0 ${statusDot(cf.status)}`} />
                </button>
              </div>
            );
          })}

          <button
            onClick={() => { setExpanded(false); navigate('/portfolio'); }}
            className="w-full text-left text-[11px] text-gray-400 hover:text-gray-600 transition-colors px-2 py-1"
          >
            Gérer les dossiers →
          </button>
        </div>
      )}
    </div>
  );
};

// ─── Sidebar ─────────────────────────────────────────────────────────────────

const SidebarNav = ({ open, planStatus }) => {
  const navigate = useNavigate();
  const { logout } = useAuth();

  const isTrial = planStatus?.plan_type === 'trial' && planStatus?.is_trial_active;
  const isExpired = planStatus?.is_trial_expired;
  const daysLeft = planStatus?.days_remaining ?? 0;

  return (
    <div className="flex flex-col h-full select-none">
      <nav className="flex-1 px-2 pt-3 pb-2 space-y-px overflow-y-auto">
        <div className={`mb-1 ${!open ? 'flex justify-center' : ''}`}>
          <DossierSwitcher open={open} />
        </div>
        {NAV_ITEMS.map((item) => (
          <NavItem key={item.path} {...item} open={open} />
        ))}
      </nav>

      <div className="px-2 border-t border-gray-100 pt-2 pb-2 space-y-px">
        <NavItem path="/settings" icon={SlidersHorizontal} label="Paramètres" open={open} />
        <button
          onClick={() => { logout(); navigate('/login'); }}
          title={!open ? 'Déconnexion' : undefined}
          className={`w-full flex items-center rounded-md text-[13px] text-gray-500 hover:bg-gray-100 hover:text-gray-700 transition-colors ${open ? 'gap-2.5 px-2.5 py-1.5' : 'justify-center p-1.5'}`}
        >
          <LogOut className="w-4 h-4 shrink-0 text-gray-400" />
          {open && <span>Déconnexion</span>}
        </button>
      </div>

      {open && (
        <div className="px-2 py-3 border-t border-gray-100">
          <div className="bg-white border border-gray-200 rounded-lg p-3">
          <div className="flex items-center justify-between mb-0.5">
            <span className="text-[12px] font-medium text-gray-700">Crédits</span>
            <span className="text-[12px] text-gray-500">
              {isExpired ? '0 / 0' : isTrial ? `${daysLeft} / 7` : '∞'}
            </span>
          </div>
          {(isTrial || isExpired) && planStatus?.trial_end_date ? (
            <p className="text-[10px] text-gray-400 mb-2">
              Expire le {formatDateMedium(planStatus.trial_end_date)}
            </p>
          ) : (
            <p className="text-[10px] text-gray-400 mb-2">Renouvellement le 1er du mois</p>
          )}
          {(isTrial || isExpired) && (
            <div className="w-full h-1 bg-gray-100 rounded-full overflow-hidden mb-2">
              <div
                className={`h-full rounded-full ${isExpired ? 'bg-red-400' : 'bg-blue-500'}`}
                style={{ width: `${Math.max(4, (daysLeft / 7) * 100)}%` }}
              />
            </div>
          )}
          <button
            onClick={() => navigate('/settings?tab=plan')}
            className="w-full py-1.5 text-[12px] font-medium text-gray-700 hover:bg-gray-50 transition-colors flex items-center justify-center gap-1.5 rounded-md"
            style={{ background: 'linear-gradient(white, white) padding-box, linear-gradient(to right, #fb923c, #f472b6, #a855f7) border-box', border: '1px solid transparent' }}
          >
            <span className="w-4 h-4 rounded-full bg-gray-900 flex items-center justify-center shrink-0">
              <ArrowUp className="w-2.5 h-2.5 text-white" />
            </span>
            Upgrade
          </button>
          </div>
        </div>
      )}
    </div>
  );
};

// ─── Layout ───────────────────────────────────────────────────────────────────

const Layout = ({ children }) => {
  const location = useLocation();
  const { notifications, unreadCount, markRead, markAllRead, remove, clearAll } = useNotifications();
  const { user } = useAuth();
  const navigate = useNavigate();

  const [panelOpen, setPanelOpen]       = useState(false);
  const [sidebarOpen, setSidebarOpen]   = useState(false);
  const [desktopOpen, setDesktopOpen]   = useState(true);
  const [planStatus, setPlanStatus]     = useState(null);
  const [showUpgradePopup, setShowUpgradePopup] = useState(false);
  const [profileMenuOpen, setProfileMenuOpen] = useState(false);

  const panelRef = useRef(null);
  const profileMenuRef = useRef(null);
  const profilePhotoSrc = useAuthImage(user?.profile_photo ? `${user.profile_photo}` : null);

  useEffect(() => {
    fetchPlanStatus()
      .then(d => { setPlanStatus(d); if (d.is_trial_expired) setShowUpgradePopup(true); })
      .catch(() => {});
  }, []);

  useEffect(() => { setSidebarOpen(false); }, [location.pathname]);

  useEffect(() => {
    const handler = (e) => {
      if (panelRef.current && !panelRef.current.contains(e.target)) setPanelOpen(false);
      if (profileMenuRef.current && !profileMenuRef.current.contains(e.target)) setProfileMenuOpen(false);
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const currentPageName = Object.entries(PAGE_NAMES).find(
    ([path]) => location.pathname === path || location.pathname.startsWith(path + '/')
  )?.[1] || '';

  return (
    <div className="flex h-screen overflow-hidden bg-white">
      {/* Header — full width, above everything */}
      <header className="fixed top-0 left-0 right-0 h-12 z-[70] bg-gray-50/70 backdrop-blur-md border-b border-gray-200 px-4 md:px-6 flex items-center gap-3">
        <button
          onClick={() => setSidebarOpen(true)}
          className="lg:hidden p-1.5 rounded-lg text-gray-400 hover:bg-gray-100 hover:text-gray-600 transition-colors"
        >
          <Menu className="w-5 h-5" />
        </button>

        <Link to="/dashboard">
          <img src="/automatchfact.png" alt="Autocontable" className="h-5 w-auto" />
        </Link>

        {currentPageName && (
          <div className="hidden lg:flex items-center gap-2">
            <span className="text-gray-300 text-sm">/</span>
            <span className="text-sm font-medium text-gray-800">{currentPageName}</span>
          </div>
        )}

        <div className="flex-1" />

        <div className="flex items-center gap-0.5">
          {[Clock, Gift, BookOpen, HelpCircle].map((Icon, i) => (
            <button key={i} className="w-7 h-7 flex items-center justify-center rounded-md text-gray-400 hover:bg-gray-100 hover:text-gray-600 transition-colors">
              <Icon style={{ width: 15, height: 15 }} />
            </button>
          ))}

          <span className="w-px h-4 bg-gray-200 mx-1" />

          {/* Notifications */}
          <div className="relative" ref={panelRef}>
            <button
              onClick={() => setPanelOpen(v => !v)}
              className="relative w-7 h-7 flex items-center justify-center rounded-md text-gray-400 hover:bg-gray-100 hover:text-gray-600 transition-colors"
            >
              <Bell style={{ width: 15, height: 15 }} />
              {unreadCount > 0 && (
                <span className="absolute top-0.5 right-0.5 min-w-[12px] h-3 bg-red-500 rounded-full text-white text-[8px] font-bold flex items-center justify-center px-0.5">
                  {unreadCount > 9 ? '9+' : unreadCount}
                </span>
              )}
            </button>

            {panelOpen && (
              <div className="absolute right-0 top-10 w-80 sm:w-96 bg-white rounded-xl shadow-lg border border-gray-100 z-50 flex flex-col max-h-[480px]">
                <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100">
                  <div className="flex items-center gap-2">
                    <h3 className="text-sm font-semibold text-gray-900">Notifications</h3>
                    {unreadCount > 0 && (
                      <span className="px-1.5 py-0.5 bg-red-100 text-red-600 text-[10px] font-semibold rounded-full">{unreadCount}</span>
                    )}
                  </div>
                  <div className="flex items-center gap-2">
                    {unreadCount > 0 && (
                      <button onClick={markAllRead} className="text-xs text-blue-600 hover:text-blue-700">Tout lire</button>
                    )}
                    {notifications.length > 0 && (
                      <button onClick={clearAll} className="p-1 text-gray-300 hover:text-red-400 rounded">
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    )}
                  </div>
                </div>
                <div className="overflow-y-auto flex-1 divide-y divide-gray-50">
                  {notifications.length === 0 ? (
                    <div className="flex flex-col items-center justify-center py-10">
                      <Bell className="w-7 h-7 mb-2 text-gray-300" />
                      <p className="text-sm text-gray-400">Aucune notification</p>
                    </div>
                  ) : notifications.map((notif) => {
                    const { icon: Icon, color, bg } = TYPE_CONFIG[notif.type] || TYPE_CONFIG[NOTIF_TYPES.INFO];
                    return (
                      <div
                        key={notif.id}
                        onClick={() => markRead(notif.id)}
                        className={`flex gap-3 px-4 py-3 cursor-pointer hover:bg-gray-50 transition-colors ${!notif.read ? 'bg-blue-50/30' : ''}`}
                      >
                        <div className={`mt-0.5 p-1.5 rounded-lg ${bg} shrink-0`}>
                          <Icon className={`w-3.5 h-3.5 ${color}`} />
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-start justify-between gap-2">
                            <p className={`text-sm text-gray-900 ${!notif.read ? 'font-semibold' : 'font-medium'}`}>{notif.title}</p>
                            <button onClick={(e) => { e.stopPropagation(); remove(notif.id); }} className="text-gray-300 hover:text-gray-400 shrink-0">
                              <X className="w-3 h-3" />
                            </button>
                          </div>
                          <p className="text-xs text-gray-500 mt-0.5">{notif.message}</p>
                          <p className="text-[10px] text-gray-400 mt-1">{timeAgo(notif.date)}</p>
                        </div>
                        {!notif.read && <div className="w-1.5 h-1.5 bg-blue-500 rounded-full mt-2 shrink-0" />}
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
          </div>

          {/* Avatar + dropdown */}
          <div className="relative ml-0.5" ref={profileMenuRef}>
            <button
              onClick={() => setProfileMenuOpen(v => !v)}
              className="w-6 h-6 rounded-full overflow-hidden shrink-0 ring-1 ring-transparent hover:ring-blue-300 transition-all"
            >
              {profilePhotoSrc
                ? <img src={profilePhotoSrc} alt="" className="w-full h-full object-cover" />
                : <div className="w-full h-full bg-blue-600 flex items-center justify-center text-white text-[10px] font-semibold">
                    {user?.name?.charAt(0).toUpperCase() || user?.username?.charAt(0).toUpperCase() || 'U'}
                  </div>
              }
            </button>
            {profileMenuOpen && (
              <div className="absolute right-0 top-9 w-56 bg-white rounded-xl shadow-lg border border-gray-100 overflow-hidden z-[110]">
                <div className="px-4 py-3 border-b border-gray-100">
                  <p className="text-sm font-semibold text-gray-900">{user?.name || user?.username || 'Utilisateur'}</p>
                  <p className="text-xs text-gray-400">{user?.email || ''}</p>
                </div>
                <div className="p-1">
                  <button
                    onClick={() => { navigate('/settings'); setProfileMenuOpen(false); }}
                    className="w-full flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 rounded-lg transition-colors"
                  >
                    Paramètres
                  </button>
                  <a
                    href="mailto:support@autocontable.com"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="w-full flex items-center gap-2 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 rounded-lg transition-colors"
                    onClick={() => setProfileMenuOpen(false)}
                  >
                    <MessageSquare size={14} className="text-gray-400 shrink-0" />
                    <span className="flex-1">Assistance</span>
                    <ExternalLink size={12} className="text-gray-300 shrink-0" />
                  </a>
                  <div className="border-t border-gray-100 mt-1 pt-1">
                    <button
                      onClick={() => { logout(); navigate('/login'); setProfileMenuOpen(false); }}
                      className="w-full flex items-center gap-2 px-3 py-2 text-sm text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                    >
                      Déconnexion
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </header>

      {/* Body below header */}
      <div className="flex pt-12 h-screen overflow-hidden w-full">
        {sidebarOpen && (
          <div className="fixed inset-0 bg-black/40 z-30 lg:hidden" onClick={() => setSidebarOpen(false)} />
        )}

        {/* Desktop sidebar */}
        <div className={`hidden lg:flex relative flex-col shrink-0 bg-gray-50/70 backdrop-blur-md border-r border-gray-200 transition-[width] duration-200 ease-in-out ${desktopOpen ? 'w-52' : 'w-12'}`}>
          <SidebarNav open={desktopOpen} planStatus={planStatus} />
          <button
            onClick={() => setDesktopOpen(v => !v)}
            className="absolute -right-3 top-1/2 -translate-y-1/2 w-6 h-6 bg-white border border-gray-200 rounded-full shadow-sm flex items-center justify-center text-gray-400 hover:text-gray-700 transition-colors z-20"
          >
            <ChevronRight className={`w-3 h-3 transition-transform duration-200 ${desktopOpen ? 'rotate-180' : ''}`} />
          </button>
        </div>

        {/* Mobile sidebar */}
        <aside className={`fixed top-12 bottom-0 left-0 z-40 w-52 bg-gray-50/70 backdrop-blur-md border-r border-gray-200 flex flex-col transform transition-transform duration-200 ${sidebarOpen ? 'translate-x-0' : '-translate-x-full'} lg:hidden`}>
          <div className="absolute top-3 right-3">
            <button onClick={() => setSidebarOpen(false)} className="p-1.5 rounded-md text-gray-400 hover:bg-gray-100">
              <X className="w-4 h-4" />
            </button>
          </div>
          <SidebarNav open={true} planStatus={planStatus} />
        </aside>

        {/* Page content */}
        <div className="flex-1 overflow-auto">
          <main className="p-4 md:p-6">
            {children}
          </main>
        </div>
      </div>

      {/* Trial expired popup */}
      {showUpgradePopup && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-6 max-w-md w-full mx-4 shadow-xl">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 bg-red-50 rounded-lg">
                <Zap className="w-5 h-5 text-red-600" />
              </div>
              <h3 className="text-base font-semibold text-gray-900">Période d'essai terminée</h3>
            </div>
            <p className="text-sm text-gray-600 mb-2">Votre période d'essai de 7 jours est terminée. Toutes les fonctionnalités sont maintenant bloquées.</p>
            <p className="text-xs text-gray-400 mb-6">Pour continuer, veuillez passer à un plan payant.</p>
            <div className="flex gap-2 justify-end">
              <button onClick={() => setShowUpgradePopup(false)} className="px-4 py-2 text-sm text-gray-600 hover:bg-gray-100 rounded-lg transition-colors">Fermer</button>
              <button onClick={() => navigate('/settings')} className="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-medium transition-colors">Voir les plans</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Layout;
