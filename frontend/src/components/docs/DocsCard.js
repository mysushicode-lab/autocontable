export default function DocsCard({ id, title, children }) {
  return (
    <div id={id} className="docs-card">
      <div className="docs-card-header"><h2>{title}</h2></div>
      <div className="docs-card-body">{children}</div>
    </div>
  );
}
