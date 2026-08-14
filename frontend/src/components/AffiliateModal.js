'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { X, Copy, Check, ExternalLink } from 'lucide-react';
import api from '../api/client';

export default function AffiliateModal({ onClose }) {
  const router = useRouter();
  const [affiliate, setAffiliate] = useState(null);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    api.get('/api/affiliates/me')
      .then(r => setAffiliate(r.data))
      .catch(async (err) => {
        // Auto-register if not yet affiliate
        if (err?.response?.status === 404) {
          try {
            await api.post('/api/affiliates/register');
            const r2 = await api.get('/api/affiliates/me');
            setAffiliate(r2.data);
          } catch {}
        }
      });
  }, []);

  const copy = () => {
    if (!affiliate) return;
    const link = `${window.location.origin}/signup?ref=${affiliate.code}`;
    navigator.clipboard.writeText(link).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  };

  const referralLink = affiliate ? `${typeof window !== 'undefined' ? window.location.origin : ''}/signup?ref=${affiliate.code}` : '';

  return (
    <div className="fixed inset-0 z-[300] flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={onClose} />
      <div className="relative bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden">

        {/* Header */}
        <div className="relative px-6 pt-6 pb-5 border-b border-gray-100">
          <button
            onClick={onClose}
            className="absolute top-4 right-4 w-7 h-7 flex items-center justify-center rounded-full bg-gray-100 hover:bg-gray-200 transition-colors text-gray-500"
          >
            <X size={14} />
          </button>
          <div className="flex items-center gap-3">
            <div className="relative w-10 h-10">
              <div className="absolute top-1.5 left-1.5 w-8 h-8 rounded-md bg-gray-200 border border-gray-300" />
              <div className="absolute top-0 left-0 w-8 h-8 rounded-md bg-gray-100 border border-gray-200 flex items-center justify-center">
                <img src="/factpilot-logo.svg" alt="" style={{ height: '0.85rem', width: 'auto' }} />
              </div>
            </div>
            <div>
              <h2 className="text-base font-semibold text-gray-900">Programme d'affiliation</h2>
              <p className="text-xs text-gray-400">Gagnez des commissions récurrentes</p>
            </div>
          </div>
        </div>

        <div className="px-6 py-5 space-y-5">

          {/* Highlights */}
          <div className="flex border border-gray-200 bg-gray-50 overflow-hidden rounded-lg">
            <div className="flex-1 flex flex-col items-center py-3 px-2">
              <span className="text-sm font-bold text-gray-900">20%</span>
              <span className="text-[10px] text-gray-400 text-center">Commission</span>
            </div>
            <div className="w-px bg-gray-200" />
            <div className="flex-1 flex flex-col items-center py-3 px-2">
              <span className="text-sm font-bold text-gray-900">Récurrent</span>
              <span className="text-[10px] text-gray-400 text-center">Chaque mois</span>
            </div>
            <div className="w-px bg-gray-200" />
            <div className="flex-1 flex flex-col items-center py-3 px-2">
              <span className="text-sm font-bold text-gray-900">Illimité</span>
              <span className="text-[10px] text-gray-400 text-center">Filleuls</span>
            </div>
          </div>

          {/* How it works */}
          <div>
            <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Comment ça marche</p>
            <ol className="space-y-0">
              {[
                'Partagez votre lien avec votre audience',
                'Ils s\'inscrivent et souscrivent à un plan payant',
                'Vous gagnez 20% de commission chaque mois',
              ].map((step, i, arr) => (
                <li key={i} className="flex gap-3">
                  <div className="flex flex-col items-center">
                    <div className="w-4 h-4 rounded-full bg-gray-100 border border-gray-200 flex items-center justify-center shrink-0 mt-0.5">
                      <span className="text-[9px] font-semibold text-gray-400">{i + 1}</span>
                    </div>
                    {i < arr.length - 1 && (
                      <div className="w-px flex-1 my-1"
                        style={{ background: 'linear-gradient(to bottom, #d1d5db 0%, transparent 100%)', minHeight: 20 }} />
                    )}
                  </div>
                  <p className="text-xs text-gray-500 leading-relaxed pb-4">{step}</p>
                </li>
              ))}
            </ol>
          </div>

          {/* Referral link */}
          <div>
            <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Votre lien de parrainage</p>
            <div className="flex items-center gap-2 p-2.5 bg-gray-50 rounded-xl border border-gray-200">
              <span className="flex-1 text-xs text-gray-600 font-mono truncate">
                {referralLink || <span className="text-gray-300">Chargement…</span>}
              </span>
              <button
                onClick={copy}
                disabled={!affiliate}
                className="shrink-0 flex items-center gap-1.5 px-3 py-1.5 bg-white hover:bg-gray-50 disabled:opacity-40 text-gray-700 text-xs font-medium rounded-lg border border-gray-200 transition-colors"
              >
                {copied ? <Check size={11} /> : <Copy size={11} />}
                {copied ? 'Copié !' : 'Copier'}
              </button>
            </div>
          </div>

          {/* CTA */}
          <button
            onClick={() => { onClose(); router.push('/affiliation'); }}
            className="flex items-center justify-center gap-2 w-full py-2.5 bg-gray-900 hover:bg-gray-700 text-white text-sm font-medium rounded-lg transition-colors"
          >
            Voir le tableau de bord & stats
            <ExternalLink size={13} />
          </button>
        </div>
      </div>
    </div>
  );
}
