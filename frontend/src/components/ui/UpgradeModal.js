'use client';

import React, { useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { useRouter } from 'next/navigation';
import { Plug } from 'lucide-react';

const integrationColors = {
  sage: '#00D639',
  cegid: '#0066FF',
  acd: '#003366',
  quadratus: '#E30613',
  pennylane: '#6C5CE7',
  fec: '#2C3E50'
};

const UpgradeModal = ({
  show,
  onClose,
  title = 'Plan Pro requis',
  description = 'Les intégrations comptables sont disponibles à partir du plan Pro.',
  integration = null
}) => {
  const router = useRouter();
  const overlayRef = useRef(null);

  const integrationColor = integration ? integrationColors[integration.name.toLowerCase()] || '#2563EB' : '#2563EB';

  useEffect(() => {
    const onKey = (e) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose]);

  if (!show) return null;

  return createPortal(
    <div
      ref={overlayRef}
      className="fixed inset-0 flex items-center justify-center px-4"
      style={{ zIndex: 9999, background: 'rgba(0,0,0,0.4)' }}
      onClick={(e) => {
        if (e.target === overlayRef.current) onClose();
      }}
    >
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 flex flex-col items-center text-center p-8">
        {/* Header avec icônes */}
        <div className="flex items-center gap-2 mb-8">
          <div className="w-12 h-12 rounded bg-black flex items-center justify-center">
            <img alt="FactPilot" className="w-8 h-8 object-contain" src="/factpilot-logo.svg" />
          </div>
          <div className="flex gap-1">
            <div className="w-1.5 h-1.5 rounded-full bg-gray-800"></div>
            <div className="w-1.5 h-1.5 rounded-full bg-gray-800"></div>
            <div className="w-1.5 h-1.5 rounded-full bg-gray-800"></div>
            <div className="w-1.5 h-1.5 rounded-full bg-gray-300"></div>
            <div className="w-1.5 h-1.5 rounded-full bg-gray-300"></div>
            <div className="w-1.5 h-1.5 rounded-full bg-gray-300"></div>
            <div className="w-1.5 h-1.5 rounded-full bg-gray-300"></div>
          </div>
          <div
            className={`w-12 h-12 rounded flex items-center justify-center ${
              integration?.name?.toLowerCase() === 'acd' ? 'bg-[#003366]' : 'bg-white'
            }`}
            style={{ borderWidth: '1px', borderColor: integrationColor }}
          >
            {integration ? (
              <img
                src={`/logos/${['pennylane', 'quadratus', 'acd', 'cegid'].includes(integration.name.toLowerCase()) ? integration.name + '.png' : integration.name + '.svg'}`}
                alt={integration.display_name}
                className="w-8 h-8 object-contain"
                onError={(e) => {
                  e.target.style.display = 'none';
                  e.target.nextSibling.style.display = 'flex';
                }}
              />
            ) : null}
            <Plug className={`w-5 h-5 ${integration ? 'hidden' : ''}`} style={{ color: integrationColor }} strokeWidth={1.75} />
          </div>
        </div>

        {/* Content */}
        <h3 className="text-xl font-semibold text-gray-900 mb-2">{title}</h3>
        <p className="text-sm text-gray-500 mb-8 max-w-[320px] leading-relaxed">{description}</p>
        <button
          onClick={() => {
            router.push('/settings?tab=billing');
            onClose();
          }}
          className="px-16 py-2.5 rounded-lg text-sm font-semibold text-white bg-blue-600 hover:bg-blue-500 transition-colors"
        >
          Passer en Pro
        </button>
      </div>
    </div>,
    document.body
  );
};

export default UpgradeModal;
