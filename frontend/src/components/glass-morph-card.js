import React from 'react';

export const GlassMorphCard = ({ children, className = '', ...props }) => {
  return (
    <div
      className={`group relative overflow-hidden rounded-lg border border-white/30 bg-white/20 shadow-xl backdrop-blur-xl transition-all duration-300 hover:-translate-y-1 hover:rotate-[0.5deg] hover:shadow-2xl ${className}`}
      {...props}
    >
      <div className="absolute inset-0 bg-gradient-to-br from-white/40 via-white/10 to-transparent opacity-70" />
      <div className="absolute -left-20 -top-20 h-40 w-40 rounded-full bg-blue-400/20 blur-3xl transition-transform duration-500 group-hover:translate-x-8 group-hover:translate-y-6" />
      <div className="absolute -bottom-24 -right-20 h-48 w-48 rounded-full bg-purple-400/20 blur-3xl transition-transform duration-500 group-hover:-translate-x-8 group-hover:-translate-y-6" />
      <div className="relative z-10">{children}</div>
    </div>
  );
};

export default GlassMorphCard;
