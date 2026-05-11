import React from 'react';
import { Link } from 'react-router-dom';

export const GlassDock = ({ items = [], activePath = '', orientation = 'horizontal', className = '' }) => {
  const isVertical = orientation === 'vertical';

  return (
    <nav
      className={`relative flex ${isVertical ? 'flex-col gap-2' : 'items-center gap-2'} rounded-lg border border-white/10 bg-white/5 p-2 shadow-2xl backdrop-blur-xl ${className}`}
    >
      {items.map((item) => {
        const Icon = item.icon;
        const isActive = activePath === item.path;

        return (
          <Link
            key={item.path}
            to={item.path}
            className={`group relative flex items-center gap-3 rounded-lg px-4 py-3 text-sm transition-all duration-300 ${
              isActive
                ? 'bg-white/15 text-white shadow-lg ring-1 ring-white/20'
                : 'text-slate-300 hover:bg-white/10 hover:text-white'
            } ${isVertical ? 'w-full' : ''}`}
          >
            <span className={`absolute inset-0 rounded-lg bg-gradient-to-r from-blue-500/30 to-white/10 opacity-0 transition-opacity duration-300 ${isActive ? 'opacity-100' : 'group-hover:opacity-70'}`} />
            <Icon className={`relative z-10 h-5 w-5 transition-transform duration-300 ${isActive ? 'scale-110 text-blue-400' : 'group-hover:scale-110'}`} />
            <span className="relative z-10 truncate">{item.label}</span>
          </Link>
        );
      })}
    </nav>
  );
};

export default GlassDock;
