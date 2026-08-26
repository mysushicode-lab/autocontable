import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUTPUT_DIR = path.join(__dirname, '..', 'public', 'pseo-images');

// Read API key from env or arg
const ACCESS_KEY = process.env.UNSPLASH_ACCESS_KEY || process.argv[2];
if (!ACCESS_KEY) {
  console.error('Missing UNSPLASH_ACCESS_KEY. Add it to .env.local or pass as argument.');
  process.exit(1);
}

// Precise search queries per slug — French + English for best results
const SLUG_QUERIES = {
  'cabinet-comptable':        'accounting office professional',
  'expert-comptable':         'accountant finance expert',
  'pme':                      'small business office team',
  'artisan':                  'craftsman workshop artisan',
  'ecommerce':                'ecommerce online shopping laptop',
  'immobilier':               'real estate building property',
  'restaurant':               'restaurant kitchen chef food',
  'btp':                      'construction building site',
  'startup':                  'startup tech office modern',
  'association':              'nonprofit team meeting volunteers',
  'rapprochement-bancaire':   'bank statement finance reconciliation',
  'extraction-factures':      'invoice document scanning paper',
  'export-fec':               'spreadsheet data export computer',
  'classification-factures':  'filing documents organized archive',
  'audit-comptable':          'audit compliance business report',
  'gestion-fournisseurs':     'supplier warehouse logistics delivery',
  'conformite-2026':          'law compliance regulation legal',
  'ingestion-email':          'email inbox computer communication',
  'pennylane':                'accounting software dashboard analytics',
  'dext':                     'receipt expense mobile scan',
  'tiime':                    'cloud technology SaaS dashboard',
  'inqom':                    'automation AI robot technology',
  'receiptbank':              'receipt bank finance document',
  'yooz':                     'invoice workflow process automation',
  'conciliator':              'ledger balance accounting numbers',
};

async function searchUnsplash(query) {
  const url = `https://api.unsplash.com/search/photos?query=${encodeURIComponent(query)}&per_page=1&orientation=landscape&client_id=${ACCESS_KEY}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Unsplash API error: ${res.status}`);
  const data = await res.json();
  if (!data.results?.length) throw new Error(`No results for "${query}"`);
  return data.results[0].urls.regular;
}

async function downloadImage(url, dest) {
  const res = await fetch(url, { redirect: 'follow' });
  if (!res.ok) throw new Error(`Download failed: ${res.status}`);
  const buffer = await res.arrayBuffer();
  fs.writeFileSync(dest, Buffer.from(buffer));
}

async function main() {
  if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  const slugs = Object.keys(SLUG_QUERIES);
  console.log(`Downloading ${slugs.length} images from Unsplash...\n`);

  for (const slug of slugs) {
    const dest = path.join(OUTPUT_DIR, `${slug}.jpg`);
    if (fs.existsSync(dest) && fs.statSync(dest).size > 0) {
      console.log(`  skip  ${slug}.jpg`);
      continue;
    }

    const query = SLUG_QUERIES[slug];
    try {
      const imageUrl = await searchUnsplash(query);
      await downloadImage(imageUrl, dest);
      console.log(`  ok    ${slug}.jpg  [${query}]`);
    } catch (err) {
      console.error(`  fail  ${slug}: ${err.message}`);
    }

    // Respect Unsplash rate limit (50 req/h = ~1 req/72s, but demo apps get more)
    await new Promise((r) => setTimeout(r, 300));
  }

  console.log('\nDone!');
}

main();
