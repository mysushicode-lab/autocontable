import fs from 'fs';
import path from 'path';
import { parseCsv } from './pseo-csv';
import { buildAllPages } from './pseo-core';

let _pages = null;

function getConfig() {
  const csvPath = path.join(process.cwd(), 'src', 'data', 'pseo', 'keywords.csv');
  const keywordsCsv = fs.readFileSync(csvPath, 'utf-8');
  const rows = parseCsv(keywordsCsv);

  return {
    kinds: [
      {
        kind: 'industry',
        pathTemplate: '/comptabilite/[slug_key]',
        titleTemplate: 'Comptabilité [slug_key_label] : Économisez 20h/mois de saisie',
        descTemplate:
          'Automatisez votre comptabilité [slug_key_label] avec l\'IA. Extraction factures instantanée, rapprochement en 30s, FEC conforme 2026. Essai gratuit sans CB.',
        rows: rows.filter((r) => r.kind === 'industry'),
        indexable: true,
      },
      {
        kind: 'use-case',
        pathTemplate: '/cas-usage/[slug_key]',
        titleTemplate: '[slug_key_label] : Automatisé en 60 Minutes | FactPilot',
        descTemplate:
          'Transformez votre [slug_key_label]. Moins d\'erreurs, zéro ressaisie, conformité garantie. Découvrez comment FactPilot divise par 4 votre temps comptable.',
        rows: rows.filter((r) => r.kind === 'use-case'),
        indexable: true,
      },
      {
        kind: 'comparison',
        pathTemplate: '/compare/factpilot-vs-[slug_key]',
        titleTemplate: 'FactPilot vs [slug_key_label] : Prix, IA & Conformité 2026',
        descTemplate:
          'Comparez FactPilot et [slug_key_label] : extraction IA, rapidité, tarifs transparents, conformité réforme. Tableau comparatif complet et retours clients vérifiés.',
        rows: rows.filter((r) => r.kind === 'comparison'),
        indexable: true,
      },
    ],
  };
}

export function getAllPseoPages() {
  if (!_pages) {
    _pages = buildAllPages(getConfig());
  }
  return _pages;
}

export function getPseoPage(slug) {
  return getAllPseoPages().find((p) => p.slug === slug) || null;
}

export function getPseoPagesByKind(kind) {
  return getAllPseoPages().filter((p) => p.kind === kind);
}
