'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import { FolderOpen, ChevronRight } from 'lucide-react';
import { useQuery } from '@tanstack/react-query';
import { useClientFile } from '../../context/ClientFileContext';
import { fetchClientFilesSummary } from '../../api';

const statusDot = (status) => {
  if (status === 'ok') return 'bg-green-500';
  if (status === 'warning') return 'bg-yellow-400';
  if (status === 'alert') return 'bg-red-500';
  return 'bg-gray-300';
};

const DossierSwitcher = ({ open }) => {
  const { activeClientFile, selectClientFile, clearClientFile } = useClientFile();
  const router = useRouter();
  const { data: dossiersData } = useQuery({
    queryKey: ['client-files-summary'],
    queryFn: fetchClientFilesSummary,
  });
  const [expanded, setExpanded] = useState(false);

  const dossiers = dossiersData?.client_files || [];
  const displayName = activeClientFile ? activeClientFile.name : 'Tous les dossiers';

  return (
    <div>
      <button
        onClick={() => open ? setExpanded(v => !v) : router.push('/portfolio')}
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
        <div className="mt-1 ml-3 pl-3 space-y-0.5 relative">
          {/* Ligne verticale */}
          <div className="absolute left-0 top-0 bottom-0 w-px bg-gray-200" />

          {dossiers.map(cf => {
            const active = activeClientFile?.id === cf.id;
            return (
              <div key={cf.id} className="relative">
                {/* Barre bleue pour le dossier actif */}
                {active && (
                  <div className="absolute -left-3 top-1/2 -translate-y-1/2 w-px h-full bg-blue-500" />
                )}
                <button
                  onClick={() => { selectClientFile(cf); setExpanded(false); }}
                  className={`w-full flex items-center gap-2 px-2 py-1.5 rounded-md text-left text-[13px] transition-colors ${
                    active ? 'text-gray-800 font-medium bg-gray-50' : 'text-gray-500'
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
            onClick={() => { setExpanded(false); router.push('/portfolio'); }}
            className="w-full text-left text-[11px] text-gray-400 transition-colors px-2 py-1.5 mt-1"
          >
            Gérer les dossiers →
          </button>
        </div>
      )}
    </div>
  );
};

export default DossierSwitcher;
