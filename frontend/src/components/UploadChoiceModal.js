import React from 'react';
import { createPortal } from 'react-dom';
import { X, Sparkles, Pencil } from 'lucide-react';
import Overlay from './ui/Overlay';

const UploadChoiceModal = ({ onClose, onChooseAI, onChooseManual }) => {
  return createPortal(
    <>
      <Overlay show={true} onClick={onClose} />
      <div className="fixed inset-0 flex items-center justify-center z-50 p-4 pointer-events-none">
        <div className="pointer-events-auto bg-white rounded-md shadow-2xl w-full max-w-sm" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between px-5 py-4 border-b">
          <h3 className="text-base font-semibold text-gray-900">Nouvelle facture</h3>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded-md text-gray-400 hover:text-gray-600">
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="p-4 space-y-3">
          <button
            onClick={onChooseAI}
            className="w-full flex items-start gap-4 p-4 border-2 border-blue-100 rounded-md hover:border-blue-400 hover:bg-blue-50 transition-all text-left group"
          >
            <div className="p-2 bg-blue-100 rounded-md group-hover:bg-blue-200 transition-colors flex-shrink-0">
              <Sparkles className="w-5 h-5 text-blue-600" />
            </div>
            <div>
              <p className="font-semibold text-gray-900 text-sm">Analyse automatique</p>
              <p className="text-xs text-gray-500 mt-0.5">L'IA extrait les données du document — fournisseur, montants, date, TVA</p>
            </div>
          </button>

          <button
            onClick={onChooseManual}
            className="w-full flex items-start gap-4 p-4 border-2 border-gray-100 rounded-md hover:border-gray-300 hover:bg-gray-50 transition-all text-left group"
          >
            <div className="p-2 bg-gray-100 rounded-md group-hover:bg-gray-200 transition-colors flex-shrink-0">
              <Pencil className="w-5 h-5 text-gray-600" />
            </div>
            <div>
              <p className="font-semibold text-gray-900 text-sm">Saisie manuelle</p>
              <p className="text-xs text-gray-500 mt-0.5">Importez le document et remplissez les champs vous-même</p>
            </div>
          </button>
        </div>
        </div>
      </div>
    </>,
    document.body
  );
};

export default UploadChoiceModal;
