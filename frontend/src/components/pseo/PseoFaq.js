'use client';

import { useState } from 'react';

export default function PseoFaq({ items, titleStyle }) {
  const [open, setOpen] = useState(null);

  return (
    <div className="divide-y divide-[#e5e5e5]">
      {items.map((item, idx) => (
        <div key={idx}>
          <button
            type="button"
            onClick={() => setOpen(open === idx ? null : idx)}
            className="w-full flex items-center justify-between py-4 text-left gap-4"
          >
            <span style={{ ...titleStyle, fontSize: 15, fontWeight: 600, color: '#000' }}>
              {item.q}
            </span>
            <span
              style={{
                fontSize: 18,
                color: '#000',
                flexShrink: 0,
                transition: 'transform 0.2s',
                transform: open === idx ? 'rotate(45deg)' : 'rotate(0deg)',
                display: 'inline-block',
              }}
            >
              +
            </span>
          </button>
          {open === idx && (
            <div
              style={{
                fontSize: 14,
                color: '#646464',
                lineHeight: 1.7,
                paddingBottom: 20,
              }}
            >
              {item.a}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
