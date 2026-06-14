export const NAV_LINKS = [
  { href: '#features',      label: 'Fonctionnalités' },
  { href: '#testimonials',  label: 'Témoignages' },
  { href: '#pricing',       label: 'Tarifs' },
  { href: '#faq',           label: 'FAQ' },
];

export const TRUSTED_BY = ['Comptalia', 'Fiducial', 'Cerfrance', 'Exco'];

export const FEATURES = [
  {
    title: 'Lecture de factures sans saisie',
    description: "PDF, email, photo ou Factur-X — l'IA extrait fournisseur, montant, TVA et date en moins de 5 secondes. Même les scans flous passent.",
    image: '/facture-preview.png',
  },
  {
    title: 'Un mois de rapprochement bancaire en 10 minutes',
    description: "Importez votre relevé, l'IA fait les correspondances. Chaque écart est signalé. Ce qui prenait une journée ne demande plus qu'un clic de validation.",
    image: '/rapprochement-preview.png',
  },
  {
    title: 'Portefeuille clients en temps réel',
    description: "Tous vos dossiers en un coup d'œil : à jour, en attente, pièces manquantes. Alertes automatiques avant les deadlines. Zéro surprise le jour J.",
    image: '/portfolio-preview.png',
  },
];

export const TOOLS = [
  {
    title: 'Exports comptables prêts à l\'emploi',
    description: 'Grand Livre, Balance, Journal des Achats avec numéros de compte PCG — générés en un clic, exportables en CSV, Excel ou ZIP. Vos dossiers sont prêts à être transmis directement.',
    image: '/export-contable.png',
  },
  {
    title: 'Scheduler automatique 24/7',
    description: 'Connectez votre boîte mail une fois. Le scheduler récupère, lit et classe chaque facture automatiquement — même la nuit, même le week-end. Zéro action manuelle.',
    image: '/scheduler-automatique.png',
  },
  {
    title: 'Analytics & tableau de bord',
    description: 'Suivez vos dossiers en temps réel : taux de rapprochement, factures en attente, fournisseurs récurrents. Tout ce qu\'il faut pour piloter votre cabinet sans chercher.',
    image: '/analytics.png',
  },
];

export const STATS = [
  { value: '40h',   label: 'Récupérées par cabinet / mois', icon: 'clock' },
  { value: '+500',  label: 'Cabinets utilisateurs',          icon: 'users' },
  { value: '98%',   label: "Précision de l'IA",              icon: 'target' },
  { value: '10min', label: 'Pour rapprocher un dossier complet', icon: 'zap' },
];
