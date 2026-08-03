import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { FolderOpen, ChevronRight } from 'lucide-react';
import { useQuery } from 'react-query';
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

export default DossierSwitcher;
