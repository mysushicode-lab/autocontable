'use client';

import React from 'react';
import {
  Pencil, Trash2, Users, LogOut
} from 'lucide-react';

const STATUS_CONFIG = {
  ok:      { label: 'À jour' },
  warning: { label: 'En attente' },
  alert:   { label: 'Pièces manquantes' },
  empty:   { label: 'Aucune pièce' },
};

const DossierCard = ({ file, isClient, onOpen, onEdit, onDelete, onQuit, onPermissions }) => {
  const cfg = STATUS_CONFIG[file.status] || STATUS_CONFIG.empty;
  const hex = '#3b82f6';

  return (
    <div
      className="max-h-[300px] rounded-xl border border-gray-200 transition-all hover:border-gray-300 overflow-visible cursor-pointer"
      onClick={() => onOpen(file)}
    >
      {/* Header with paper texture */}
      <div
        className="relative flex h-[200px] w-full items-end justify-center overflow-hidden rounded-t-xl"
        style={{ backgroundColor: hex }}
      >
        {/* Paper grain texture */}
        <div className="absolute inset-0 opacity-40 pointer-events-none" style={{
          backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='1.2' numOctaves='5' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
          backgroundSize: '150px 150px',
          mixBlendMode: 'overlay'
        }} />

        {/* Status badge */}
        <span className="absolute top-3 right-3 z-10 text-[10px] font-medium px-2 py-0.5 rounded-full backdrop-blur-sm bg-white/20 text-white border border-white/30">
          {cfg.label}
        </span>

        {/* White card mockup */}
        <div className="z-10 flex h-[85%] w-[min(280px,92%)] flex-col overflow-hidden rounded-t-2xl border border-gray-200 translate-y-3 shadow-lg">
          {/* Header with miniature filters */}
          <div className="flex h-7 w-full shrink-0 items-center justify-between px-2.5 border-b border-gray-100" style={{ background: 'linear-gradient(0deg, rgba(0,0,0,0.02) 0.44%, rgba(0,0,0,0) 49.5%), #fff' }}>
            <div className="flex items-center gap-1.5">
              <div className="w-14 h-2 rounded bg-blue-500/80" />
              <div className="w-10 h-2 rounded bg-gray-200/80" />
              <div className="w-10 h-2 rounded bg-gray-200/80" />
            </div>
            <div className="flex items-center gap-1">
              <div className="w-12 h-2 rounded bg-gray-200/60" />
              <div className="w-2 h-2 rounded-full bg-blue-500/60" />
            </div>
          </div>

          {/* Invoice list mockup */}
          <div className="flex w-full flex-grow flex-col gap-0.5 bg-white px-2 py-1.5">
            <MockInvoiceRow color="green" widths={['w-full', 'w-full', 'w-3/4']} />
            <MockInvoiceRow color="green" widths={['w-full', 'w-4/5', 'w-2/3']} />
            <MockInvoiceRow color="yellow" widths={['w-full', 'w-full', 'w-1/2']} />
            <MockInvoiceRow color="green" widths={['w-full', 'w-3/5', 'w-full']} />
            <MockInvoiceRow color="yellow" widths={['w-full', 'w-4/5', 'w-3/4']} />
            <MockInvoiceRow color="gray" widths={['w-full', 'w-2/3', 'w-1/2']} faded />
          </div>
        </div>
      </div>

      <div className="border-t border-gray-200" />

      {/* Footer with info and actions */}
      <div className="flex items-center justify-between gap-4 p-6">
        <div className="min-w-0 flex-1">
          <p className="line-clamp-1 break-all font-medium text-gray-900 leading-tight text-sm">{file.name}</p>
          <p className="line-clamp-1 text-xs text-gray-400 font-medium mt-1">
            {file.invoice_count} factures &bull; {file.matched_count} rapprochées &bull; {file.pending_count} en attente
          </p>
        </div>
        <div className="flex gap-1 shrink-0">
          {isClient ? (
            <button
              onClick={e => { e.stopPropagation(); onQuit(file); }}
              className="p-2 bg-gray-100 hover:bg-red-50 text-gray-600 hover:text-red-600 rounded-lg border border-gray-200 hover:border-red-200 transition-colors"
              title="Quitter ce dossier"
            >
              <LogOut className="w-4 h-4" />
            </button>
          ) : (
            <>
              <button
                onClick={e => { e.stopPropagation(); onPermissions(file); }}
                className="p-2 bg-gray-100 hover:bg-blue-50 text-gray-600 hover:text-blue-600 rounded-lg border border-gray-200 hover:border-blue-200 transition-colors"
                title="Gérer l'accès (PME/Clients)"
              >
                <Users className="w-4 h-4" />
              </button>
              <button
                onClick={e => onEdit(file, e)}
                className="p-2 bg-gray-100 hover:bg-gray-200 text-gray-600 rounded-lg border border-gray-200 transition-colors"
                title="Modifier"
              >
                <Pencil className="w-4 h-4" />
              </button>
              <button
                onClick={e => { e.stopPropagation(); onDelete(file); }}
                className="p-2 bg-gray-100 hover:bg-red-50 text-gray-600 hover:text-red-600 rounded-lg border border-gray-200 hover:border-red-200 transition-colors"
                title="Supprimer"
              >
                <Trash2 className="w-4 h-4" />
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

const MockInvoiceRow = ({ color, widths, faded }) => (
  <div className={`flex items-center gap-2 px-2 py-1.5 rounded bg-gray-50/60 border border-gray-100/50${faded ? ' opacity-50' : ''}`}>
    <div className={`w-1.5 h-1.5 rounded-sm bg-${color === 'gray' ? 'gray-300' : `${color}-500/90`}`} />
    <div className="flex-1 min-w-0 grid grid-cols-3 gap-1.5">
      <div className={`h-1.5 ${widths[0]} rounded ${color === 'gray' ? 'bg-gray-200' : 'bg-gray-300'}`} />
      <div className={`h-1.5 ${widths[1]} rounded ${color === 'gray' ? 'bg-gray-200' : 'bg-gray-200/70'}`} />
      <div className={`h-1.5 ${widths[2]} rounded ${color === 'gray' ? 'bg-gray-200' : 'bg-gray-200/70'}`} />
    </div>
    <div className={`h-1.5 w-8 rounded bg-${color === 'gray' ? 'gray-200/60' : `${color}-500/40`}`} />
  </div>
);

export default DossierCard;
