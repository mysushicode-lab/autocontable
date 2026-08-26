const SLUG_KEYWORDS = {
  'cabinet-comptable':    'accounting,office,professional',
  'expert-comptable':     'accountant,finance,desk',
  'pme':                  'small,business,office',
  'artisan':              'craftsman,workshop,tools',
  'ecommerce':            'ecommerce,online,shopping',
  'immobilier':           'real,estate,building',
  'restaurant':           'restaurant,kitchen,food',
  'btp':                  'construction,building,architecture',
  'startup':              'startup,technology,laptop',
  'association':          'association,nonprofit,meeting',
  'rapprochement-bancaire':   'bank,finance,statement',
  'extraction-factures':      'invoice,document,scan',
  'export-fec':               'export,data,spreadsheet',
  'classification-factures':  'filing,document,organize',
  'audit-comptable':          'audit,compliance,paperwork',
  'gestion-fournisseurs':     'supplier,logistics,delivery',
  'conformite-2026':          'law,compliance,regulation',
  'ingestion-email':          'email,inbox,communication',
  'pennylane':     'software,comparison,analytics',
  'dext':          'receipt,expense,mobile',
  'tiime':         'accounting,cloud,technology',
  'inqom':         'automation,robot,technology',
  'receiptbank':   'receipt,bank,finance',
  'yooz':          'invoice,process,workflow',
  'conciliator':   'reconciliation,balance,ledger',
};

function slugToLock(slug) {
  let lock = 0;
  for (let i = 0; i < slug.length; i++) lock = (lock * 31 + slug.charCodeAt(i)) & 0xfff;
  return lock;
}

export function getPseoImageUrl(slugKey, width = 800, height = 400) {
  // Use local image if downloaded
  if (SLUG_KEYWORDS[slugKey]) {
    return `/pseo-images/${slugKey}.jpg`;
  }
  // Fallback: loremflickr with deterministic lock
  const keywords = 'accounting,business,finance';
  const lock = slugToLock(slugKey);
  return `https://loremflickr.com/${width}/${height}/${keywords}?lock=${lock}`;
}
