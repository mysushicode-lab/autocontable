import DocsShell from '@/components/docs/DocsShell';

export const metadata = {
  title: { template: '%s — FactPilot Docs', default: 'Documentation — FactPilot' },
};

const DOCS_CSS = `
/* Tokens */
.docs-root {
  --d-bg: #ffffff;
  --d-sidebar-bg: #f8f9fa;
  --d-card-bg: #ffffff;
  --d-card-header: #fafafa;
  --d-border: #e5e7eb;
  --d-text: #111827;
  --d-text-soft: #444;
  --d-muted: #6b7280;
  --d-accent: #466cf3;
  --d-accent-bg: rgba(70,108,243,0.08);
  --d-hover: rgba(0,0,0,0.04);
  --d-code-bg: #f1f3f9;
  --d-code-color: #c0392b;
  --d-sidebar-w: 280px;
  --d-toc-w: 210px;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}
/* Dark mode */
.docs-root.dark {
  --d-bg: #0f1117;
  --d-sidebar-bg: #1a1c23;
  --d-card-bg: #1e2029;
  --d-card-header: #22242d;
  --d-border: #2d2f3a;
  --d-text: #f9fafb;
  --d-text-soft: #d1d5db;
  --d-muted: #9ca3af;
  --d-code-bg: #1e2029;
  --d-code-color: #f87171;
  --d-hover: rgba(255,255,255,0.04);
  --d-accent-bg: rgba(70,108,243,0.15);
}

/* Layout */
.docs-root { min-height: 100vh; background: var(--d-bg); color: var(--d-text); }
.docs-header {
  position: fixed; top: 0; left: 0; right: 0; height: 60px; z-index: 50;
  background: var(--d-sidebar-bg); border-bottom: 1px solid var(--d-border);
  display: flex; align-items: center; padding: 0 16px; gap: 12px;
}
.docs-sidebar {
  position: fixed; top: 0; bottom: 0; left: 0; width: var(--d-sidebar-w);
  background: var(--d-sidebar-bg); border-right: 1px solid var(--d-border);
  overflow-y: auto; z-index: 40; transition: transform 0.25s ease;
}
.docs-main { padding-top: 60px; min-height: 100vh; }

@media (min-width: 1024px) {
  .docs-main { padding-left: var(--d-sidebar-w); }
  .docs-sidebar { transform: translateX(0) !important; top: 60px; height: calc(100vh - 60px); }
  .docs-overlay { display: none !important; }
  .docs-hamburger { display: none !important; }
  .docs-sidebar-logo { display: block; }
}
@media (max-width: 1023px) {
  .docs-sidebar { transform: translateX(-100%); top: 60px; }
  .docs-sidebar.open { transform: translateX(0); box-shadow: 4px 0 20px rgba(0,0,0,0.15); }
  .docs-sidebar-logo { display: none; }
}
.docs-overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 39; }
.docs-overlay.visible { display: block; }
.docs-header-logo { text-decoration: none; display: flex; align-items: center; }
.docs-header-logo img { height: 28px; width: auto; }
.docs-hamburger { background: none; border: none; cursor: pointer; color: var(--d-text); display: flex; padding: 4px; font-size: 22px; }
.docs-darkmode-btn { background: none; border: none; cursor: pointer; color: var(--d-muted); display: flex; padding: 4px; flex-shrink: 0; }
.docs-search-center { flex: 1; display: flex; justify-content: center; }
.docs-sidebar nav { padding-bottom: 24px; }

/* Sidebar nav */
.docs-section-label {
  display: block; font-size: 11px; font-weight: 700;
  text-transform: uppercase; letter-spacing: 0.07em;
  color: var(--d-muted); padding: 16px 20px 6px; user-select: none;
}
.docs-nav-link {
  display: block; padding: 6px 20px; font-size: 13.5px;
  color: var(--d-text-soft); text-decoration: none; margin: 1px 0;
  transition: color 0.1s, background 0.1s;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.docs-nav-link:hover { color: var(--d-text); background: var(--d-hover); }
.docs-nav-link.active { color: var(--d-accent); font-weight: 600; background: var(--d-accent-bg); }
.docs-nav-link-folder { display: flex; align-items: center; justify-content: space-between; }
.docs-nav-chevron { flex-shrink: 0; opacity: 0.4; }
.docs-nav-sub { margin: 2px 0 4px 24px; border-left: 1px solid var(--d-border); }
.docs-nav-sub-link {
  display: block; padding: 4px 14px; font-size: 12.5px;
  color: var(--d-text); text-decoration: none;
  border-left: 2px solid transparent; margin-left: -1px;
  transition: background 0.1s;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.docs-nav-sub-link:hover { background: var(--d-hover); }
.docs-nav-sub-link.active { font-weight: 600; border-left-color: var(--d-text); }

/* Card (existing) */
.docs-card { background: var(--d-card-bg); border: 1px solid var(--d-border); border-radius: 8px; margin-bottom: 20px; overflow: hidden; }
.docs-card-header { padding: 18px 24px; border-bottom: 1px solid var(--d-border); background: var(--d-card-header); }
.docs-card-header h2 { margin: 0; font-size: 18px; font-weight: 600; color: var(--d-text); scroll-margin-top: 80px; }
.docs-card-body { padding: 24px; }

/* Callouts */
.docs-callout { display: flex; gap: 8px; align-items: flex-start; padding: 10px 14px; border-radius: 4px; margin: 12px 0; font-size: 14px; line-height: 1.6; }
.docs-callout-icon { flex-shrink: 0; margin-top: 1px; }
.docs-callout-info  { background: #eff3fe; border-left: 3px solid var(--d-accent); color: #1e40af; }
.docs-callout-warning { background: #fffbeb; border-left: 3px solid #f59e0b; color: #78350f; }
.docs-callout-tip,
.docs-callout-success { background: #f0fdf4; border-left: 3px solid #22c55e; color: #14532d; }
.docs-callout-danger  { background: #fef2f2; border-left: 3px solid #ef4444; color: #991b1b; }
/* Legacy .docs-note — alias of callout-info */
.docs-note { background: #eff3fe; border-left: 3px solid var(--d-accent); padding: 10px 14px; border-radius: 4px; margin: 12px 0; color: #1e40af; font-size: 14px; display: flex; gap: 8px; align-items: flex-start; }
.docs-root.dark .docs-note,
.docs-root.dark .docs-callout-info { background: rgba(70,108,243,0.12); color: #93c5fd; }

/* Prose (new pages) */
.docs-page { display: flex; max-width: 1040px; margin: 0 auto; }
.docs-prose { flex: 1; min-width: 0; padding: 40px 44px 80px; }
.docs-prose h1 { font-size: 27px; font-weight: 700; line-height: 1.3; color: var(--d-text); margin: 0 0 8px; letter-spacing: -0.02em; }
.docs-integration-title { display: flex; align-items: center; gap: 12px; }
.docs-integration-title img { height: 22px; width: auto; object-fit: contain; }
.docs-lead { font-size: 15px; color: var(--d-muted); margin: 0 0 36px; line-height: 1.6; }
.docs-prose h2 { font-size: 17px; font-weight: 600; color: var(--d-text); margin: 36px 0 12px; padding-top: 36px; border-top: 1px solid var(--d-border); scroll-margin-top: 80px; }
.docs-prose h2:first-of-type { margin-top: 0; padding-top: 0; border-top: none; }
.docs-prose h3 { font-size: 14px; font-weight: 600; margin: 20px 0 6px; }
.docs-prose p { font-size: 14px; line-height: 1.75; color: var(--d-text-soft); margin: 0 0 14px; }
.docs-prose ul, .docs-prose ol { padding-left: 22px; margin: 0 0 14px; }
.docs-prose li { font-size: 14px; line-height: 1.9; color: var(--d-text-soft); }
.docs-prose li + li { margin-top: 2px; }
.docs-prose strong { color: var(--d-text); font-weight: 600; }
.docs-prose code { font-family: 'Fira Code', monospace; font-size: 12px; background: var(--d-code-bg); border-radius: 3px; padding: 1px 5px; color: var(--d-code-color); }
.docs-prose a { color: var(--d-accent); text-decoration: none; }
.docs-prose a:hover { text-decoration: underline; }
.docs-pre { background: var(--d-code-bg); border-radius: 6px; padding: 12px 16px; font-size: 13px; overflow: auto; margin: 0 0 14px; position: relative; }
.docs-prose table { width: 100%; border-collapse: collapse; font-size: 13px; margin: 0 0 20px; }
.docs-prose th { text-align: left; padding: 8px 12px; background: var(--d-card-header); border-bottom: 1px solid var(--d-border); font-weight: 600; font-size: 11px; text-transform: uppercase; letter-spacing: 0.05em; color: var(--d-muted); }
.docs-prose td { padding: 8px 12px; border-bottom: 1px solid var(--d-border); color: var(--d-text-soft); }
.docs-prose tr:last-child td { border-bottom: none; }

/* Badges */
.docs-badge { display: inline-block; font-size: 10px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; padding: 2px 6px; border-radius: 20px; vertical-align: middle; margin-left: 6px; }
.docs-badge-starter { background: #dbeafe; color: #1d4ed8; }
.docs-badge-pro     { background: #ede9fe; color: #6d28d9; }
.docs-badge-reseau  { background: #fce7f3; color: #be185d; }

/* TOC */
.docs-toc { width: var(--d-toc-w); flex-shrink: 0; position: sticky; top: 60px; height: calc(100vh - 60px); overflow-y: auto; padding: 40px 20px 40px 0; border-left: 1px solid var(--d-border); }
.docs-toc-title { font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.08em; color: var(--d-muted); margin-bottom: 10px; padding-left: 12px; }
.docs-toc-link { display: block; font-size: 12.5px; color: var(--d-muted); padding: 4px 12px; text-decoration: none; border-left: 2px solid transparent; transition: color 0.1s, border-color 0.1s; }
.docs-toc-link:hover { color: var(--d-text); border-left-color: var(--d-border); }
.docs-toc-link.active { color: var(--d-accent); border-left-color: var(--d-accent); }
@media (max-width: 1280px) { .docs-toc { display: none; } }

/* Copy button */
.docs-copy-btn { position: absolute; top: 8px; right: 8px; background: #313e4e; color: #fff; border: 1px solid rgba(255,255,255,0.12); font-size: 11px; font-weight: 500; padding: 3px 8px; border-radius: 4px; cursor: pointer; opacity: 0; transition: opacity 0.15s; }
.docs-card-body pre:hover .docs-copy-btn,
.docs-prose pre:hover .docs-copy-btn { opacity: 1; }
.docs-copy-btn--done { background: #22543d; }

/* Prev/Next */
.docs-pager-divider { border: none; border-top: 1px solid var(--d-border); margin: 0; }
.docs-nav-pager { display: flex; justify-content: flex-start; gap: 8px; max-width: 720px; margin: 0 auto; padding: 20px 44px 48px; }
.docs-pager-btn { display: flex; align-items: center; gap: 10px; padding: 10px 16px; border: 1px solid var(--d-border); border-radius: 6px; text-decoration: none; color: var(--d-text-soft); transition: border-color 0.15s, color 0.15s; }
.docs-pager-btn:hover { border-color: var(--d-accent); color: var(--d-accent); }
.docs-pager-title { font-size: 13px; font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

/* Back to top */
.docs-back-top { position: fixed; bottom: 24px; right: 24px; z-index: 99; width: 36px; height: 36px; border-radius: 50%; background: var(--d-text); color: var(--d-bg); border: none; cursor: pointer; display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 8px rgba(0,0,0,0.15); transition: background 0.15s, transform 0.15s; }
.docs-back-top:hover { background: var(--d-accent); transform: translateY(-2px); }

/* Search */
.docs-search-wrap { position: relative; flex: 1; max-width: 300px; }
.docs-search { width: 100%; height: 34px; border: 1px solid var(--d-border); border-radius: 6px; padding: 0 12px; background: var(--d-bg); color: var(--d-text); font-size: 13px; outline: none; box-sizing: border-box; }
.docs-search:focus { border-color: var(--d-accent); box-shadow: 0 0 0 2px var(--d-accent-bg); }
.docs-search-dropdown {
  position: absolute; top: calc(100% + 6px); left: 0; right: 0; z-index: 200;
  background: var(--d-sidebar-bg); border: 1px solid var(--d-border);
  border-radius: 8px; box-shadow: 0 8px 24px rgba(0,0,0,0.12);
  overflow: hidden;
}
.docs-search-item {
  display: flex; flex-direction: column; gap: 2px; width: 100%; text-align: left;
  padding: 10px 14px; background: none; border: none; border-bottom: 1px solid var(--d-border);
  cursor: pointer; transition: background 0.1s;
}
.docs-search-item:last-child { border-bottom: none; }
.docs-search-item:hover, .docs-search-item.selected { background: var(--d-hover); }
.docs-search-title { font-size: 13px; font-weight: 500; color: var(--d-text); }
.docs-search-desc { font-size: 12px; color: var(--d-muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
@media (max-width: 640px) { .docs-search-wrap { display: none; } }

/* Mobile */
@media (max-width: 640px) {
  .docs-prose { padding: 24px 20px 56px; }
  .docs-prose h1 { font-size: 22px; }
  .docs-prose table { display: block; overflow-x: auto; }
  .docs-nav-pager { flex-direction: column; padding: 16px 20px 40px; }
  .docs-pager-btn { justify-content: center; }
  .docs-back-top { bottom: 16px; right: 16px; width: 32px; height: 32px; }
  .docs-nav-link { padding: 8px 20px; }
}
`;

export default function DocsLayout({ children }) {
  return (
    <>
      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/remixicon@4.3.0/fonts/remixicon.css" />
      <style dangerouslySetInnerHTML={{ __html: DOCS_CSS }} />
      <DocsShell>{children}</DocsShell>
    </>
  );
}
