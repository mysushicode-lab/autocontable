import React, { useState, useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { ChevronDown, Calendar } from 'lucide-react';

const DropdownButton = ({ label, value, options, onChange, isOpen, onToggle, buttonRef, width = '150px', compact = false }) => {
  const [position, setPosition] = useState({ top: 0, left: 0 });

  useEffect(() => {
    if (isOpen && buttonRef.current) {
      const rect = buttonRef.current.getBoundingClientRect();
      setPosition({
        top: rect.bottom + 8,
        left: rect.right - parseInt(width),
      });
    }
  }, [isOpen, buttonRef, width]);

  const selectedLabel = options.find(opt => opt.value === value)?.label || label;

  const handleBackdropClick = (e) => {
    e.preventDefault();
    e.stopPropagation();
    onToggle();
  };

  return (
    <>
      <button
        ref={buttonRef}
        onClick={(e) => {
          e.preventDefault();
          onToggle();
        }}
        className={`bg-white rounded-md border border-gray-200 hover:bg-gray-50 flex items-center gap-2 focus:ring-1 focus:ring-blue-500 outline-none whitespace-nowrap text-gray-600 ${compact ? 'px-2.5 py-1.5 text-xs' : 'px-3 py-1.5 text-sm'}`}
      >
        <Calendar className={`shrink-0 text-gray-400 ${compact ? 'w-3 h-3' : 'w-3.5 h-3.5'}`} />
        <span className="truncate max-w-[140px]">{selectedLabel}</span>
        <ChevronDown className={`shrink-0 text-gray-400 ${compact ? 'w-3 h-3' : 'w-3.5 h-3.5'}`} />
      </button>
      {isOpen && createPortal(
        <>
          <div 
            className="fixed inset-0 z-50" 
            onClick={handleBackdropClick}
            style={{ pointerEvents: 'auto' }}
          />
          <div 
            className="fixed bg-white rounded-md shadow-xl border z-[100] p-2"
            style={{ top: `${position.top}px`, left: `${Math.max(16, position.left)}px`, width, pointerEvents: 'auto' }}
          >
            {options.map((opt) => (
              <button
                key={opt.value}
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  onChange(opt.value);
                  onToggle();
                }}
                className="w-full text-left px-3 py-2 hover:bg-gray-100 rounded text-sm"
              >
                {opt.label}
              </button>
            ))}
          </div>
        </>,
        document.body
      )}
    </>
  );
};

export default DropdownButton;
