import DocsShell from '@/components/docs/DocsShell';

export const metadata = {
  title: { template: '%s — FactPilot Docs', default: 'Documentation — FactPilot' },
};

const DOCS_CSS = `
/* Docs color tokens */
.docs-root {
  --d-bg: #f8f9fa;
  --d-sidebar-bg: #ffffff;
  --d-card-bg: #ffffff;
  --d-card-header: #fafafa;
  --d-border: #e5e7eb;
  --d-text: #111827;
  --d-muted: #6b7280;
  --d-accent: #466cf3;
  --d-sidebar-w: 280px;
}
.docs-root.dark {
  --d-bg: #0f1117;
  --d-sidebar-bg: #1a1c23;
  --d-card-bg: #1e2029;
  --d-card-header: #22242d;
  --d-border: #2d2f3a;
  --d-text: #f9fafb;
  --d-muted: #9ca3af;
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
  overflow-y: auto; z-index: 40;
  transition: transform 0.25s ease;
}
.docs-main {
  padding-top: 60px;
  min-height: 100vh;
}
/* Desktop: sidebar always visible */
@media (min-width: 1024px) {
  .docs-main { padding-left: var(--d-sidebar-w); }
  .docs-sidebar { transform: translateX(0) !important; top: 60px; height: calc(100vh - 60px); }
  .docs-overlay { display: none !important; }
  /* Logo always in header, never in sidebar */
  .docs-hamburger { display: none !important; }
  .docs-sidebar-logo { display: block; }
}
/* Mobile: sidebar hidden off-screen */
@media (max-width: 1023px) {
  .docs-sidebar { transform: translateX(-100%); top: 60px; }
  .docs-sidebar.open { transform: translateX(0); box-shadow: 4px 0 20px rgba(0,0,0,0.15); }
  .docs-sidebar-logo { display: none; }
}
/* Overlay */
.docs-overlay {
  display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.5); z-index: 39;
}
.docs-overlay.visible { display: block; }
/* Nav link active */
.docs-nav-link.active { color: #111827 !important; font-weight: 600; border-left-color: var(--d-accent) !important; }
.docs-nav-link:hover { color: #111827 !important; }
/* Card */
.docs-card {
  background: var(--d-card-bg); border: 1px solid var(--d-border); border-radius: 8px;
  margin-bottom: 20px; overflow: hidden;
}
.docs-card-header {
  padding: 18px 24px; border-bottom: 1px solid var(--d-border);
  background: var(--d-card-header);
}
.docs-card-header h2 { margin: 0; font-size: 18px; font-weight: 600; color: var(--d-text); }
.docs-card-body { padding: 24px; }
/* Note callout */
.docs-note {
  background: #eff3fe; border-left: 3px solid var(--d-accent);
  padding: 10px 14px; border-radius: 4px; margin: 12px 0;
  color: #1e40af; font-size: 14px; display: flex; gap: 8px; align-items: flex-start;
}
.dark .docs-note { background: rgba(70,108,243,0.12); color: #93c5fd; }
/* Search */
.docs-search {
  flex: 1; max-width: 300px; height: 34px;
  border: 1px solid var(--d-border); border-radius: 6px;
  padding: 0 12px; background: var(--d-bg); color: var(--d-text); font-size: 13px;
  outline: none;
}
@media (max-width: 640px) { .docs-search { display: none; } }
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
