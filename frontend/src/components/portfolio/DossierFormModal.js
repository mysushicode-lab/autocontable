'use client';

import React from 'react';
import { createPortal } from 'react-dom';
import { X, Check } from 'lucide-react';
import HelpTooltip from '../ui/HelpTooltip';
import { INPUT_CLASS } from '../../utils/formHelpers';
import { validateSiret } from '../../utils/siretValidation';

const EMPTY_FORM = { name: '', siret: '', activity: '', contact_email: '', scheduler_email: '', phone: '', notes: '', color: '#3b82f6' };

const PRESET_COLORS = [
  '#3b82f6', // blue
  '#8b5cf6', // purple
  '#ec4899', // pink
  '#f59e0b', // amber
  '#10b981', // emerald
  '#06b6d4', // cyan
  '#f43f5e', // rose
  '#6366f1', // indigo
];

const DossierFormModal = ({
  show,
  editingFile,
  form,
  setForm,
  siretValidation,
  setSiretValidation,
  onSubmit,
  onClose,
  isSubmitting,
}) => {
  if (!show) return null;

  return createPortal(
    <div
      className="fixed inset-0 z-[60] flex items-center justify-center p-4"
      style={{
        backgroundColor: '#ffffff',
        backgroundImage: 'radial-gradient(circle, #d1d5db 1px, transparent 1px)',
        backgroundSize: '20px 20px',
      }}
    >
      <div className="pointer-events-none fixed inset-0" style={{ background: 'radial-gradient(ellipse at center, transparent 25%, white 100%)' }} />
      <div className="bg-white rounded-md p-6 w-full max-w-md">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-gray-900">
            {editingFile ? 'Modifier le dossier' : 'Nouveau dossier client'}
          </h2>
          <button
            onClick={onClose}
            className="p-1 text-gray-400 hover:text-gray-600"
          >
            <X className="w-5 h-5" />
          </button>
        </div>
        <form onSubmit={onSubmit} className="space-y-3">
          <div>
            <label className="text-xs font-medium text-gray-700">Nom du client *</label>
            <input
              required
              className={`mt-1 ${INPUT_CLASS}`}
              placeholder="Boulangerie Martin, SCI Leblanc..."
              value={form.name}
              onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
            />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-medium text-gray-700">SIRET</label>
              <div className="relative">
                <input
                  className={`mt-1 pr-8 ${INPUT_CLASS} ${
                    form.siret && siretValidation.error ? '!border-red-300' :
                    form.siret && siretValidation.valid ? '!border-green-300' : ''
                  }`}
                  placeholder="12345678901234"
                  maxLength={17}
                  value={form.siret}
                  onChange={e => {
                    const value = e.target.value;
                    setForm(f => ({ ...f, siret: value }));
                    setSiretValidation(validateSiret(value));
                  }}
                />
                {form.siret && siretValidation.valid && (
                  <Check className="absolute right-2 top-1/2 -translate-y-1/2 w-4 h-4 text-green-600" />
                )}
              </div>
              {form.siret && siretValidation.error && (
                <p className="text-[10px] text-red-500 mt-0.5">{siretValidation.error}</p>
              )}
            </div>
            <div>
              <label className="text-xs font-medium text-gray-700">Activité</label>
              <input
                className={`mt-1 ${INPUT_CLASS}`}
                placeholder="Boulangerie, BTP, Commerce..."
                value={form.activity}
                onChange={e => setForm(f => ({ ...f, activity: e.target.value }))}
              />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-medium text-gray-700 flex items-center gap-1">
                Email
                <HelpTooltip text="Email du client pour contact et import automatique des factures" />
              </label>
              <input
                type="email"
                className={`mt-1 ${INPUT_CLASS}`}
                placeholder="contact@entreprise.fr"
                value={form.contact_email}
                onChange={e => {
                  setForm(f => ({
                    ...f,
                    contact_email: e.target.value,
                    scheduler_email: e.target.value
                  }));
                }}
              />
            </div>
            <div>
              <label className="text-xs font-medium text-gray-700 flex items-center gap-1">
                Téléphone
                <HelpTooltip text="Téléphone du client pour contact et notifications WhatsApp" />
              </label>
              <input
                type="tel"
                className={`mt-1 ${INPUT_CLASS}`}
                placeholder="+33612345678"
                value={form.phone}
                onChange={e => setForm(f => ({ ...f, phone: e.target.value }))}
              />
            </div>
          </div>

          <div>
            <label className="text-xs font-medium text-gray-700">Notes</label>
            <textarea
              rows={2}
              className={`mt-1 ${INPUT_CLASS}`}
              placeholder="Informations utiles..."
              value={form.notes}
              onChange={e => setForm(f => ({ ...f, notes: e.target.value }))}
            />
          </div>

          <div>
            <label className="text-xs font-medium text-gray-700 flex items-center gap-1">
              Couleur du dossier
              <HelpTooltip text="Couleur pour différencier visuellement les dossiers" />
            </label>
            <div className="mt-2 flex items-center gap-2">
              {PRESET_COLORS.map((color) => (
                <button
                  key={color}
                  type="button"
                  onClick={() => setForm(f => ({ ...f, color }))}
                  className={`w-8 h-8 rounded-md transition-all hover:scale-110 ${
                    form.color === color ? 'ring-2 ring-offset-2 ring-gray-900' : ''
                  }`}
                  style={{ backgroundColor: color }}
                  title={color}
                />
              ))}
              <input
                type="color"
                value={form.color || '#3b82f6'}
                onChange={e => setForm(f => ({ ...f, color: e.target.value }))}
                className="w-8 h-8 rounded-md cursor-pointer border border-gray-300"
                title="Couleur personnalisée"
              />
            </div>
          </div>
          <div className="flex gap-3 justify-end pt-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 border rounded-md text-sm hover:bg-gray-50"
            >
              Annuler
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="px-4 py-2 bg-blue-600 text-white rounded-md text-sm font-medium hover:bg-blue-500 transition-colors disabled:opacity-50"
            >
              {editingFile ? 'Enregistrer' : 'Créer le dossier'}
            </button>
          </div>
        </form>
      </div>
    </div>,
    document.body
  );
};

export { EMPTY_FORM };
export default DossierFormModal;
