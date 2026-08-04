'use client';

import React from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import {
  FolderKanban, Gauge, Receipt, GitMerge, BookMarked, TrendingUp,
  SlidersHorizontal, Shield, LogOut, ArrowUp, BarChart3, Plug,
} from 'lucide-react';
import { useQuery } from '@tanstack/react-query';
import { useAuth } from '../../context/AuthContext';
import { fetchPendingMatches, fetchBillingUsage } from '../../api';
import { formatDateMedium } from '../../utils/formatHelpers';
import DossierSwitcher from './DossierSwitcher';

const NAV_ITEMS = [
  { path: '/portfolio',      icon: FolderKanban, label: 'Portefeuille',   roles: ['admin', 'accountant'] },
  { path: '/dashboard',      icon: Gauge,        label: 'Tableau de bord', roles: ['admin', 'accountant'] },
  { path: '/invoices',       icon: Receipt,      label: 'Factures',        roles: ['admin', 'accountant'] },
  { path: '/reconciliation', icon: GitMerge,     label: 'Rapprochement',   roles: ['admin', 'accountant'] },
  { path: '/integrations',   icon: Plug,         label: 'Connecteur',      roles: ['admin', 'accountant'] },
  { path: '/reference',      icon: BookMarked,   label: 'Référence',       roles: ['admin', 'accountant'] },
  { path: '/reports',        icon: TrendingUp,   label: 'Rapports',        roles: ['admin', 'accountant'] },
  { path: '/analytics',      icon: BarChart3,    label: 'Analytics',       roles: ['admin', 'accountant'] },
  { path: '/portal',         icon: Gauge,        label: 'Mon Espace',      roles: ['client'] },
];

const NavItem = ({ path, icon: Icon, label, open, badge }) => {
  const pathname = usePathname();
  const active = pathname === path || pathname.startsWith(path + '/');

  return (
    <Link
      to={path}
      title={!open ? label : undefined}
      className={`flex items-center rounded-md text-[13px] transition-colors duration-100 group relative ${
        open ? 'gap-2.5 px-2.5 py-1.5' : 'justify-center p-1.5'
      } ${
        active
          ? 'bg-white text-gray-900 font-medium border border-gray-200 shadow-sm'
          : 'text-gray-500 hover:bg-gray-50 hover:text-gray-700'
      }`}
    >
      <Icon className={`w-4 h-4 shrink-0 ${active ? 'text-gray-700' : 'text-gray-400 group-hover:text-gray-500'}`} />
      {open && <span className="truncate">{label}</span>}
      {badge > 0 && (
        <span className={`${open ? 'ml-auto' : 'absolute -top-0.5 -right-0.5'} min-w-[16px] h-4 px-1 bg-orange-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center`}>
          {badge > 9 ? '9+' : badge}
        </span>
      )}
    </Link>
  );
};

const SidebarNav = ({ open, planStatus }) => {
  const router = useRouter();
  const { logout, user } = useAuth();
  const { data: pendingData } = useQuery(['pending-matches'], fetchPendingMatches, {
    refetchInterval: 30000,
    enabled: user?.role !== 'client',
  });

  const { data: billingData } = useQuery(['billing-usage'], fetchBillingUsage, {
    refetchInterval: 60000,
    enabled: user?.role !== 'client',
  });

  const isTrial = planStatus?.plan_type === 'trial' && planStatus?.is_trial_active;
  const isExpired = planStatus?.is_trial_expired;
  const daysLeft = planStatus?.days_remaining ?? 0;
  const pendingCount = pendingData?.count || 0;
  const isAdmin = user?.role === 'admin';
  const isClient = user?.role === 'client';

  const visibleNavItems = NAV_ITEMS.filter(item =>
    !item.roles || item.roles.includes(user?.role)
  );

  return (
    <div className="flex flex-col h-full select-none">
      <nav className="flex-1 px-2 pt-3 pb-2 space-y-px overflow-y-auto">
        {!isClient && (
          <div className={`mb-1 ${!open ? 'flex justify-center' : ''}`}>
            <DossierSwitcher open={open} />
          </div>
        )}
        {visibleNavItems.map((item) => (
          <NavItem
            key={item.path}
            {...item}
            open={open}
            badge={item.path === '/reconciliation' ? pendingCount : 0}
          />
        ))}
      </nav>

      <div className="px-2 border-t border-gray-100 pt-2 pb-2 space-y-px">
        {isAdmin && <NavItem path="/audit" icon={Shield} label="Journal d'audit" open={open} />}
        <NavItem path="/settings" icon={SlidersHorizontal} label="Paramètres" open={open} />
        <button
          onClick={() => { logout(); router.push('/login'); }}
          title={!open ? 'Déconnexion' : undefined}
          className={`w-full flex items-center rounded-md text-[13px] text-gray-500 hover:bg-gray-100 hover:text-gray-700 transition-colors ${open ? 'gap-2.5 px-2.5 py-1.5' : 'justify-center p-1.5'}`}
        >
          <LogOut className="w-4 h-4 shrink-0 text-gray-400" />
          {open && <span>Déconnexion</span>}
        </button>
      </div>

      {open && !isClient && (
        <div className="px-2 py-3 border-t border-gray-100">
          <div className="bg-white border border-gray-200 rounded-lg p-3">
          {billingData && billingData.dossier_count > 0 ? (
            <>
              <div className="flex items-center justify-between mb-0.5">
                <span className="text-[12px] font-medium text-gray-700">Usage</span>
                <span className="text-[12px] text-gray-500">
                  {billingData.dossier_count} dossier{billingData.dossier_count > 1 ? 's' : ''}
                </span>
              </div>
              <p className="text-[10px] text-gray-400 mb-2">
                {billingData.billable_dossiers > 0
                  ? `${billingData.monthly_total.toFixed(2)} €/mois · ${billingData.price_per_dossier.toFixed(0)} €/dossier`
                  : `${billingData.dossier_count}/${billingData.free_dossiers} gratuits`
                }
              </p>
            </>
          ) : (
            <>
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
            </>
          )}
          <button
            onClick={() => router.push('/settings?tab=plan')}
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

export default SidebarNav;
