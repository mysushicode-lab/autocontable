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
        titleTemplate: 'Comptabilité automatisée pour [slug_key_label]',
        descTemplate:
          'Autocontable automatise les factures et le rapprochement bancaire pour les [slug_key_label]. Extraction IA, export FEC, conforme 2026.',
        rows: rows.filter((r) => r.kind === 'industry'),
        indexable: true,
      },
      {
        kind: 'use-case',
        pathTemplate: '/cas-usage/[slug_key]',
        titleTemplate: '[slug_key_label] — Autocontable',
        descTemplate:
          '[slug_key_label] automatisé avec Autocontable. Gagnez du temps, réduisez les erreurs.',
        rows: rows.filter((r) => r.kind === 'use-case'),
        indexable: true,
      },
      {
        kind: 'comparison',
        pathTemplate: '/compare/autocontable-vs-[slug_key]',
        titleTemplate: 'Autocontable vs [slug_key_label] : Fonctionnalités, Tarifs & Avis',
        descTemplate:
          'Comparaison détaillée Autocontable vs [slug_key_label]. Découvrez les différences en fonctionnalités, tarifs et support.',
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
