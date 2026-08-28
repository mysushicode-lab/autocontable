const ICONS = {
  info:    'M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
  warning: 'M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z',
  tip:     'M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
  success: 'M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
  danger:  'M12 9v3.75m0 3.75h.008v.008H12v-.008zm0-13.5C6.477 3 2 7.477 2 12s4.477 9 10 9 10-4.477 10-9S17.523 3 12 3z',
};

export default function DocsNote({ children, type = 'info' }) {
  return (
    <div className={`docs-callout docs-callout-${type}`}>
      <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5} className="docs-callout-icon">
        <path strokeLinecap="round" strokeLinejoin="round" d={ICONS[type]} />
      </svg>
      <div>{children}</div>
    </div>
  );
}
