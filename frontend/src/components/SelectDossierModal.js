import React from 'react';
import { createPortal } from 'react-dom';
import { X, Briefcase } from 'lucide-react';

const SelectDossierModal = ({ clientFiles, onSelect, onClose }) => {
  return createPortal(
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-md shadow-2xl w-full max-w-sm">
        <div className="flex items-center justify-between px-5 py-4 border-b">
          <h3 className="text-base font-semibold text-gray-900">Choisir un dossier</h3>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded-md text-gray-400 hover:text-gray-600">
            <X className="w-4 h-4" />
          </button>
        </div>
        <div className="p-3">
          <p className="text-xs text-gray-500 px-2 pb-2">Sélectionnez le dossier auquel rattacher cette facture</p>
          <div className="space-y-1 max-h-64 overflow-y-auto">
            {clientFiles.map(file => (
              <button
                key={file.id}
                onClick={() => onSelect(file)}
                className="w-full flex items-center gap-3 px-3 py-2.5 rounded-md hover:bg-blue-50 hover:text-blue-700 text-left transition-colors"
              >
                <Briefcase className="w-4 h-4 text-gray-400 flex-shrink-0" />
                <div className="min-w-0">
                  <p className="text-sm font-medium text-gray-900 truncate">{file.name}</p>
                  {file.activity && <p className="text-xs text-gray-400 truncate">{file.activity}</p>}
                </div>
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>,
    document.body
  );
};

export default SelectDossierModal;
