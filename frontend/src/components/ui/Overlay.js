import React from 'react';

const Overlay = ({ show, onClick, className = '', blur = true }) => {
  if (!show) return null;

  return (
    <div
      className={`fixed inset-0 z-40 ${blur ? 'bg-black/40 backdrop-blur-sm' : 'bg-black/50'} ${className}`}
      onClick={onClick}
      aria-hidden="true"
    />
  );
};

export default Overlay;
