export const DOC_NAV = [
  {
    key: 'start',
    label: 'Démarrage',
    items: [
      { href: '/docs', label: 'Introduction' },
      { href: '/docs/installation', label: 'Installation' },
      { href: '/docs/configuration', label: 'Configuration' },
    ],
  },
  {
    key: 'features',
    label: 'Fonctionnalités',
    items: [
      { href: '/docs/portefeuille', label: 'Portefeuille' },
      { href: '/docs/factures', label: 'Factures' },
      {
        href: '/docs/rapprochement',
        label: 'Rapprochement',
        items: [
          { href: '/docs/rapprochement/transactions', label: 'Transactions' },
          { href: '/docs/rapprochement/ia', label: 'IA automatique' },
          { href: '/docs/rapprochement/manuel', label: 'Manuel' },
        ],
      },
      {
        href: '/docs/integrations',
        label: 'Intégrations',
        items: [
          { href: '/docs/integrations/sage', label: 'Sage' },
          { href: '/docs/integrations/cegid', label: 'Cegid' },
          { href: '/docs/integrations/quadratus', label: 'Quadratus' },
          { href: '/docs/integrations/pennylane', label: 'Pennylane' },
          { href: '/docs/integrations/acd', label: 'ACD' },
        ],
      },
      { href: '/docs/rapports', label: 'Rapports & Exports' },
      { href: '/docs/analytics', label: 'Analytics' },
      { href: '/docs/parametres', label: 'Paramètres' },
    ],
  },
  {
    key: 'api',
    label: 'API',
    items: [
      {
        href: '/docs/api',
        label: 'API',
        items: [
          { href: '/docs/api/authentication', label: 'Authentification' },
          { href: '/docs/api/invoices', label: 'Factures' },
          { href: '/docs/api/reconciliation', label: 'Rapprochement' },
          { href: '/docs/api/fec-export', label: 'Export FEC' },
        ],
      },
    ],
  },
  {
    key: 'other',
    label: 'Autres',
    items: [
      { href: '/docs/changelog', label: 'Changelog' },
    ],
  },
  {
    key: 'legal',
    label: 'Légal',
    items: [
      { href: '/docs/mentions-legales', label: 'Mentions légales' },
      { href: '/docs/politique-confidentialite', label: 'Confidentialité' },
      { href: '/docs/cgu', label: 'CGU' },
    ],
  },
];
