export default function DocsNote({ children }) {
  return (
    <div className="docs-note">
      <i className="ri-information-line" style={{ flexShrink: 0, marginTop: 1 }} />
      <span>{children}</span>
    </div>
  );
}
