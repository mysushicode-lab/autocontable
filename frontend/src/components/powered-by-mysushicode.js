import React, { useState } from 'react';
import { GlassMorphCard } from './glass-morph-card';

export const PoweredByMysushicode = ({ className = '' }) => {
  const [visible, setVisible] = useState(true);

  if (!visible) {
    return null;
  }

  return (
    <div className={`relative inline-block ${className}`}>
      <div className="absolute inset-0 translate-x-2 translate-y-2 rounded-lg border border-white/20 bg-white/10 backdrop-blur-md" />
      <div className="absolute inset-0 translate-x-1 translate-y-1 rounded-lg border border-white/20 bg-white/10 backdrop-blur-md" />
      <GlassMorphCard className="relative">
      <div className="px-5 py-4 text-center text-sm text-gray-700">
        <div className="flex items-center justify-center gap-2">
          <img 
            src="/logo_mysushicode.png" 
            alt="Mysushicode logo" 
            className="h-4 w-auto"
          />
          <span className="text-white">Powered by </span>
          <a
            href="https://mysushicode.fr"
            target="_blank"
            className="font-semibold text-[#ff7f7f] hover:text-[#ff6b6b]"
          >
            mysushicode.fr
          </a>
        </div>
      </div>
      </GlassMorphCard>
    </div>
  );
};

export default PoweredByMysushicode;
