'use client';

import React, { useState, useRef, useEffect } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { Bell, Zap, Menu, ChevronRight, X, Gift, HelpCircle, BookOpen } from 'lucide-react';
import { useNotifications, NotificationHelpers } from '../context/NotificationContext';
import { useAuth } from '../context/AuthContext';
import { useClientFile } from '../context/ClientFileContext';
import { fetchPlanStatus } from '../api';
import SidebarNav from './layout/Sidebar';
import NotificationPanel from './layout/NotificationPanel';
import UserMenu from './layout/UserMenu';
import AffiliateModal from './AffiliateModal';

const PAGE_NAMES = {
  '/dashboard':      'Tableau de bord',
  '/invoices':       'Factures',
  '/reconciliation': 'Rapprochement',
  '/integrations':   'Connecteur',
  '/reports':        'Rapports',
  '/analytics':      'Analytics',
  '/portfolio':      'Portefeuille',
  '/settings':       'Paramètres',
  '/audit':          'Journal d\'audit',
};

const Layout = ({ children }) => {
  const pathname = usePathname();
  const { notifications, unreadCount, markRead, markAllRead, remove, clearAll, add: addNotification } = useNotifications();
  const { user } = useAuth();
  const { activeClientFile } = useClientFile();
  const router = useRouter();

  const [panelOpen, setPanelOpen] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [desktopOpen, setDesktopOpen] = useState(true);
  const [planStatus, setPlanStatus] = useState(null);
  const [showUpgradePopup, setShowUpgradePopup] = useState(false);
  const [profileMenuOpen, setProfileMenuOpen] = useState(false);
  const [showAffiliate, setShowAffiliate] = useState(false);

  const panelRef = useRef(null);
  const profileMenuRef = useRef(null);

  useEffect(() => {
    fetchPlanStatus()
      .then(d => {
        setPlanStatus(d);
        if (d.is_trial_expired) setShowUpgradePopup(true);
        if (d.is_trial_active && d.days_remaining <= 3) {
          const n = NotificationHelpers.trialExpiring(d.days_remaining);
          addNotification(n.type, n.title, n.message);
        }
      })
      .catch(() => {});
  }, []);

  useEffect(() => { setSidebarOpen(false); }, [pathname]);

  useEffect(() => {
    const handler = (e) => {
      if (panelRef.current && !panelRef.current.contains(e.target)) setPanelOpen(false);
      if (profileMenuRef.current && !profileMenuRef.current.contains(e.target)) setProfileMenuOpen(false);
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const currentPageName = Object.entries(PAGE_NAMES).find(
    ([path]) => pathname === path || pathname.startsWith(path + '/')
  )?.[1] || '';

  return (
    <div className="flex h-dvh overflow-hidden bg-white">
      <header className="fixed top-0 left-0 right-0 h-12 z-[70] bg-gray-50/70 backdrop-blur-md border-b border-gray-200 px-4 md:px-6 flex items-center gap-3">
        <button
          onClick={() => setSidebarOpen(true)}
          aria-label="Ouvrir le menu"
          className="lg:hidden p-1.5 rounded-lg text-gray-400 hover:bg-gray-100 hover:text-gray-600 transition-colors"
        >
          <Menu className="w-5 h-5" />
        </button>

        <Link href="/dashboard">
          <img src="/factpilot-logo.svg" alt="FactPilot" className="h-5 w-auto" />
        </Link>

        <div className="hidden lg:flex items-center gap-2">
          {activeClientFile && (
            <>
              <span className="text-gray-300 text-sm">/</span>
              <span className="text-sm font-medium text-gray-700">{activeClientFile.name}</span>
            </>
          )}
          {currentPageName && (
            <>
              <span className="text-gray-300 text-sm">/</span>
              <span className="text-sm font-medium text-gray-800">{currentPageName}</span>
            </>
          )}
        </div>

        <div className="flex-1" />

        <div className="flex items-center gap-0.5">
          <button
            onClick={() => setShowAffiliate(true)}
            aria-label="Affiliation"
            className="w-7 h-7 flex items-center justify-center rounded-md text-gray-400 hover:bg-gray-100 hover:text-gray-600 transition-colors"
          >
            <Gift style={{ width: 15, height: 15 }} />
          </button>
          <Link href="/docs" aria-label="Documentation" className="w-7 h-7 flex items-center justify-center rounded-md text-gray-400 hover:bg-gray-100 hover:text-gray-600 transition-colors">
            <BookOpen style={{ width: 15, height: 15 }} />
          </Link>

          <span className="w-px h-4 bg-gray-200 mx-1" />

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
              <NotificationPanel
                panelRef={panelRef}
                notifications={notifications}
                unreadCount={unreadCount}
                markRead={markRead}
                markAllRead={markAllRead}
                remove={remove}
                clearAll={clearAll}
              />
            )}
          </div>

          <UserMenu
            profileMenuRef={profileMenuRef}
            profileMenuOpen={profileMenuOpen}
            setProfileMenuOpen={setProfileMenuOpen}
          />
        </div>
      </header>

      <div className="flex pt-12 h-dvh overflow-hidden w-full">
        {sidebarOpen && (
          <div className="fixed inset-0 bg-black/40 z-30 lg:hidden" onClick={() => setSidebarOpen(false)} />
        )}

        <div className={`hidden lg:flex relative flex-col shrink-0 bg-gray-50/70 backdrop-blur-md border-r border-gray-200 transition-[width] duration-200 ease-in-out ${desktopOpen ? 'w-52' : 'w-12'}`}>
          <SidebarNav open={desktopOpen} planStatus={planStatus} />
          <button
            onClick={() => setDesktopOpen(v => !v)}
            className="absolute -right-3 top-1/2 -translate-y-1/2 w-6 h-6 bg-white border border-gray-200 rounded-full flex items-center justify-center text-gray-400 hover:text-gray-700 transition-colors z-20"
          >
            <ChevronRight className={`w-3 h-3 transition-transform duration-200 ${desktopOpen ? 'rotate-180' : ''}`} />
          </button>
        </div>

        <aside className={`fixed top-12 bottom-0 left-0 z-40 w-52 bg-gray-50/70 backdrop-blur-md border-r border-gray-200 flex flex-col transform transition-transform duration-200 ${sidebarOpen ? 'translate-x-0' : '-translate-x-full'} lg:hidden`}>
          <div className="absolute top-3 right-3">
            <button onClick={() => setSidebarOpen(false)} className="p-1.5 rounded-md text-gray-400 hover:bg-gray-100">
              <X className="w-4 h-4" />
            </button>
          </div>
          <SidebarNav open={true} planStatus={planStatus} />
        </aside>

        <div className="flex-1 overflow-auto">
          <main className="p-4 md:p-6">
            {children}
          </main>
        </div>
      </div>

      {showAffiliate && <AffiliateModal onClose={() => setShowAffiliate(false)} />}

      {showUpgradePopup && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50">
          <div className="bg-white rounded-xl p-6 max-w-md w-full mx-4">
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
              <button onClick={() => router.push('/settings')} className="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-medium transition-colors">Voir les plans</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Layout;
