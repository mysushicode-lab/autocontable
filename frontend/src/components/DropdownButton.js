import React, { useState, useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { ChevronDown } from 'lucide-react';

const DropdownButton = ({ label, value, options, onChange, isOpen, onToggle, buttonRef, width = '150px' }) => {
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
        className="px-3 py-2 bg-white rounded-md border hover:bg-gray-50 flex items-center gap-2 focus:ring-1 focus:ring-blue-500 outline-none text-sm"
      >
        {selectedLabel}
        <ChevronDown className="w-4 h-4" />
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
