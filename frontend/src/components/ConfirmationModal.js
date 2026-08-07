import React from 'react';
import { AlertTriangle } from 'lucide-react';
import Overlay from './ui/Overlay';

const ConfirmationModal = ({
  show,
  title,
  message,
  confirmLabel = 'Confirmer',
  cancelLabel = 'Annuler',
  onConfirm,
  onCancel,
  danger = true,
  loading = false,
}) => {
  if (!show) return null;

  return (
    <>
      <Overlay show={show} onClick={onCancel} />
      <div className="fixed inset-0 flex items-center justify-center z-50 p-4 pointer-events-none">
        <div className="pointer-events-auto bg-white rounded-2xl p-6 max-w-md w-full border border-gray-200 shadow-xl">
          <div className="mb-6">
            {danger && (
              <div className="w-7 h-7 rounded-md bg-red-50 border border-red-100 flex items-center justify-center mb-3">
                <AlertTriangle className="w-3.5 h-3.5 text-red-500" />
              </div>
            )}
            <h3 className="text-base font-semibold text-gray-900 mb-2">{title}</h3>
            <p className="text-sm text-gray-500 leading-relaxed">{message}</p>
          </div>
          <div className="flex gap-2">
            <button
              onClick={onCancel}
              disabled={loading}
              className="flex-1 px-3 py-2 border border-gray-200 rounded-lg text-xs font-medium text-gray-700 hover:bg-gray-50 transition-colors disabled:opacity-50"
            >
              {cancelLabel}
            </button>
            <button
              onClick={onConfirm}
              disabled={loading}
              className={`flex-1 px-3 py-2 rounded-lg text-xs font-semibold transition-colors disabled:opacity-50 disabled:cursor-not-allowed ${
                danger
                  ? 'bg-red-600 text-white hover:bg-red-500'
                  : 'bg-blue-600 text-white hover:bg-blue-500'
              }`}
            >
              {loading ? 'Chargement...' : confirmLabel}
            </button>
          </div>
        </div>
      </div>
    </>
  );
};

export default ConfirmationModal;
