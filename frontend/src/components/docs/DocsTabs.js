'use client';
import { useState } from 'react';

export default function DocsTabs({ tabs }) {
  const [active, setActive] = useState(0);
  return (
    <div>
      <div style={{ display: 'flex', borderBottom: '1px solid var(--d-border)', marginBottom: 20, gap: 0 }}>
        {tabs.map((tab, i) => (
          <button
            key={tab.label}
            onClick={() => setActive(i)}
            style={{
              padding: '8px 16px', background: 'none', border: 'none', cursor: 'pointer',
              fontSize: 14, fontWeight: active === i ? 600 : 400,
              color: active === i ? 'var(--d-accent)' : 'var(--d-muted)',
              borderBottom: active === i ? '2px solid var(--d-accent)' : '2px solid transparent',
              marginBottom: -1,
            }}
          >
            {tab.label}
          </button>
        ))}
      </div>
      <div>{tabs[active].content}</div>
    </div>
  );
}
