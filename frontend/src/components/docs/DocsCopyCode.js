'use client';
import { useEffect } from 'react';
import { usePathname } from 'next/navigation';

export function DocsCopyCode() {
  const pathname = usePathname();

  useEffect(() => {
    const blocks = document.querySelectorAll('.docs-prose pre, .docs-card-body pre');

    blocks.forEach(pre => {
      if (pre.querySelector('.docs-copy-btn')) return;
      pre.style.position = 'relative';

      const btn = document.createElement('button');
      btn.className = 'docs-copy-btn';
      btn.textContent = 'Copier';

      btn.addEventListener('click', () => {
        const text = pre.querySelector('code')?.innerText ?? pre.textContent ?? '';
        navigator.clipboard.writeText(text).then(
          () => {
            btn.textContent = 'Copié !';
            btn.classList.add('docs-copy-btn--done');
            setTimeout(() => { btn.textContent = 'Copier'; btn.classList.remove('docs-copy-btn--done'); }, 2000);
          },
          () => { btn.textContent = 'Erreur'; setTimeout(() => { btn.textContent = 'Copier'; }, 2000); }
        );
      });

      pre.appendChild(btn);
    });
  }, [pathname]);

  return null;
}
