'use client';
import { useEffect, useRef, useState } from 'react';

export function DocsToc({ items }) {
  const [active, setActive] = useState(items[0]?.id ?? '');
  const clicking = useRef(false);
  const timer = useRef();

  useEffect(() => {
    if (items.length === 0) return;
    const OFFSET = 60 + 28; // header 60px + buffer

    const update = () => {
      if (clicking.current) return;

      const atBottom = window.scrollY + window.innerHeight >= document.documentElement.scrollHeight - 40;
      if (atBottom) {
        setActive(items[items.length - 1]?.id ?? '');
        return;
      }

      const scrollY = window.scrollY + OFFSET;
      let current = items[0]?.id ?? '';
      for (const { id } of items) {
        const el = document.getElementById(id);
        if (el && el.getBoundingClientRect().top + window.scrollY <= scrollY) current = id;
      }
      setActive(current);
    };

    window.addEventListener('scroll', update, { passive: true });
    update();
    return () => window.removeEventListener('scroll', update);
  }, [items]);

  const handleClick = (id) => {
    setActive(id);
    clicking.current = true;
    clearTimeout(timer.current);
    timer.current = setTimeout(() => { clicking.current = false; }, 800);
  };

  return (
    <aside className="docs-toc">
      <div className="docs-toc-title">Sur cette page</div>
      {items.map(item => (
        <a
          key={item.id}
          href={`#${item.id}`}
          onClick={() => handleClick(item.id)}
          className={`docs-toc-link${active === item.id ? ' active' : ''}`}
        >
          {item.label}
        </a>
      ))}
    </aside>
  );
}
