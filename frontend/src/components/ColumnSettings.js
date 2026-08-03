import React, { useState, useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { Settings, ChevronDown } from 'lucide-react';

const DEFAULT_COLUMNS = {
  invoice_number: true,
  supplier: true,
  category: true,
  amount_ht: true,
  amount_tax: true,
  amount: true,
  date: true,
  reference: true,
  status: true,
  actions: true
};

const COLUMN_LABELS = {
  invoice_number: 'N° Facture',
  supplier: 'Fournisseur',
  category: 'Catégorie',
  amount_ht: 'Montant HT',
  amount_tax: 'TVA',
  amount: 'Montant TTC',
  date: 'Date',
  reference: 'Référence/Dossier',
  status: 'Statut',
  actions: 'Actions'
};

export const useColumnVisibility = (storageKey = 'invoice_column_visibility') => {
  const [columnVisibility, setColumnVisibility] = useState(DEFAULT_COLUMNS);

  useEffect(() => {
    // Load from localStorage on mount
    const saved = localStorage.getItem(storageKey);
    if (saved) {
      try {
        setColumnVisibility(JSON.parse(saved));
      } catch (e) {
        console.error('Error loading column visibility:', e);
      }
    }
  }, [storageKey]);

  const handleColumnToggle = (column) => {
    setColumnVisibility(prev => {
      const updated = { ...prev, [column]: !prev[column] };
      localStorage.setItem(storageKey, JSON.stringify(updated));
      return updated;
    });
  };

  const resetToDefaults = () => {
    setColumnVisibility(DEFAULT_COLUMNS);
    localStorage.setItem(storageKey, JSON.stringify(DEFAULT_COLUMNS));
  };

  return { columnVisibility, handleColumnToggle, resetToDefaults };
};

export const ColumnSettings = ({ columnVisibility, onToggle, onClose, position }) => {
  return createPortal(
    <>
      <div className="fixed inset-0 z-50" onClick={onClose} />
      <div 
        className="fixed bg-white rounded-md shadow-xl border z-[100] p-2 w-48"
        style={{ top: `${position.top}px`, left: `${Math.max(16, position.left)}px` }}
      >
        <div className="space-y-1">
          {Object.entries(COLUMN_LABELS).map(([key, label]) => (
            <label key={key} className="flex items-center gap-2 px-2 py-1 hover:bg-gray-50 rounded cursor-pointer">
              <input
                type="checkbox"
                checked={columnVisibility[key]}
                onChange={() => onToggle(key)}
                className="rounded"
              />
              <span className="text-sm">{label}</span>
            </label>
          ))}
        </div>
      </div>
    </>,
    document.body
  );
};

export const ColumnSettingsButton = ({ columnVisibility, onToggle }) => {
  const [isOpen, setIsOpen] = useState(false);
  const buttonRef = useRef(null);
  const [position, setPosition] = useState({ top: 0, left: 0 });

  useEffect(() => {
    if (isOpen && buttonRef.current) {
      const rect = buttonRef.current.getBoundingClientRect();
      setPosition({
        top: rect.bottom + 8,
        left: rect.right - 192,
      });
    }
  }, [isOpen]);

  return (
    <>
      <button
        ref={buttonRef}
        onClick={() => setIsOpen(!isOpen)}
        className="px-2 py-2 sm:px-3 border rounded-md hover:bg-gray-50 flex items-center gap-2 text-gray-700 text-sm"
      >
        <Settings className="w-4 h-4" />
        <span className="hidden sm:inline">Colonnes</span>
        <ChevronDown className="w-3 h-3 sm:w-4 sm:h-4" />
      </button>
      {isOpen && (
        <ColumnSettings 
          columnVisibility={columnVisibility} 
          onToggle={(key) => {
            onToggle(key);
          }}
          onClose={() => setIsOpen(false)}
          position={position}
        />
      )}
    </>
  );
};
