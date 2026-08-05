export const NAV_LINKS = [
  { href: '#features',      label: 'Fonctionnalités' },
  { href: '#testimonials',  label: 'Témoignages' },
  { href: '#pricing',       label: 'Tarifs' },
  { href: '#faq',           label: 'FAQ' },
];

export const FEATURES = [
  {
    title: 'Les factures arrivent déjà classées',
    description: "Vos clients envoient un PDF ou une photo. FactPilot extrait automatiquement : montant HT/TTC, TVA, date, fournisseur. Classification intelligente par secteur. Zéro saisie manuelle, zéro erreur.",
    image: '/facture-preview.png',
  },
  {
    title: 'Rapprochement bancaire en 30 secondes',
    description: "Importez les relevés de n'importe quelle banque française. Chaque facture se rapproche toute seule avec la transaction. Les impayés remontent immédiatement. Audit trail complet.",
    image: '/rapprochement-preview.png',
  },
  {
    title: 'Dossier client prêt instantanément',
    description: "Export FEC normé, grand livre, journal. Tout est tracé, catégorisé, rapproché. Vos clients reçoivent un dossier audité. Conforme réforme 2026.",
    image: '/portfolio-preview.png',
  },
];

export const TOOLS = [
  {
    title: 'Ingestion email ou WhatsApp',
    description: "Vos clients envoient des factures par email ou WhatsApp. FactPilot les récupère automatiquement, les traite et les ajoute au dossier. Zéro manipulation manuelle.",
    image: '/export-contable.png',
  },
  {
    title: 'Extraction IA multiformat',
    description: "PDF, photo, scan flou ou manuscrit — FactPilot extrait numéro, date, montant HT/TTC, TVA, fournisseur en 30 secondes. 95%+ de précision même sur documents dégradés.",
    image: '/scheduler-automatique.png',
  },
  {
    title: 'Rapprochement et audit trail',
    description: "Chaque facture rapprochée automatique avec le relevé bancaire. Impayés, anomalies détectées immédiatement. Export audit-ready avec traçabilité complète.",
    image: '/analytics.png',
  },
];

export const STATS = [
  { value: '120h+',    label: 'Économisées par mois', icon: 'clock' },
  { value: '+200',     label: 'PME et cabinets équipés', icon: 'users' },
  { value: '95%+',     label: 'De rapprochement correct', icon: 'target' },
  { value: 'Sept. 2026', label: 'Conforme avant la deadline', icon: 'zap' },
];
