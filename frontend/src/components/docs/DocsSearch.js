'use client';
import { useState, useRef, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { SEARCH_INDEX } from '@/lib/docs/search';

export function DocsSearch({ placeholder = 'Rechercher…' }) {
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState(false);
  const [selected, setSelected] = useState(0);
  const wrapRef = useRef(null);
  const router = useRouter();

  const results = query.trim().length > 1
    ? SEARCH_INDEX.filter(p =>
        p.title.toLowerCase().includes(query.toLowerCase()) ||
        p.desc.toLowerCase().includes(query.toLowerCase())
      ).slice(0, 7)
    : [];

  useEffect(() => {
    setSelected(0);
    setOpen(results.length > 0);
  }, [results.length]);

  // Close on outside click
  useEffect(() => {
    const handler = (e) => { if (!wrapRef.current?.contains(e.target)) setOpen(false); };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const go = (href) => { router.push(href); setQuery(''); setOpen(false); };

  const onKey = (e) => {
    if (e.key === 'ArrowDown') { e.preventDefault(); setSelected(s => Math.min(s + 1, results.length - 1)); }
    if (e.key === 'ArrowUp')   { e.preventDefault(); setSelected(s => Math.max(s - 1, 0)); }
    if (e.key === 'Enter' && results[selected]) go(results[selected].href);
    if (e.key === 'Escape') { setOpen(false); setQuery(''); }
  };

  return (
    <div ref={wrapRef} className="docs-search-wrap">
      <input
        type="search"
        value={query}
        onChange={e => setQuery(e.target.value)}
        onKeyDown={onKey}
        onFocus={() => results.length > 0 && setOpen(true)}
        placeholder={placeholder}
        className="docs-search"
      />
      {open && (
        <div className="docs-search-dropdown">
          {results.map((r, i) => (
            <button
              key={r.href}
              className={`docs-search-item${i === selected ? ' selected' : ''}`}
              onClick={() => go(r.href)}
              onMouseEnter={() => setSelected(i)}
            >
              <span className="docs-search-title">{highlight(r.title, query)}</span>
              <span className="docs-search-desc">{r.desc}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

function highlight(text, query) {
  if (!query) return text;
  const idx = text.toLowerCase().indexOf(query.toLowerCase());
  if (idx === -1) return text;
  return (
    <>
      {text.slice(0, idx)}
      <mark style={{ background: 'var(--d-accent-bg)', color: 'inherit', borderRadius: 2 }}>
        {text.slice(idx, idx + query.length)}
      </mark>
      {text.slice(idx + query.length)}
    </>
  );
}
