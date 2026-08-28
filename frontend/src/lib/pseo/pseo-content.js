/**
 * FactPilot — PSEO Content Generator
 *
 * Generates structured content for programmatic SEO pages.
 * Page kinds: 'industry' | 'use-case' | 'comparison'
 *
 * Usage:
 *   import { getPseoContent } from '@/lib/pseo/pseo-content';
 *   const content = getPseoContent(page);
 */

// ---------------------------------------------------------------------------
// Shared data
// ---------------------------------------------------------------------------

const STATS_INDUSTRY_USECASE = [
  { value: '120h',    label: 'récupérées/mois' },
  { value: '95%+',   label: 'taux extraction' },
  { value: '60 min', label: 'opérationnel' },
  { value: '0',      label: 'ressaisie' },
];

const STATS_COMPARISON = [
  { value: '120h',    label: 'récupérées/mois' },
  { value: '95%+',   label: 'taux extraction IA' },
  { value: '60 min', label: 'opérationnel' },
  { value: '0€',     label: 'migration' },
];

/**
 * Seven-row comparison table.
 * FactPilot = all true.
 * Competitor = false on all rows except "Rapprochement bancaire auto".
 */
const COMPARISON_TABLE = [
  { feature: 'Extraction IA de factures',        factpilot: true, competitor: false },
  { feature: 'Lecture scans dégradés',           factpilot: true, competitor: false },
  { feature: 'Rapprochement bancaire auto',      factpilot: true, competitor: true  },
  { feature: 'Export FEC normé',                 factpilot: true, competitor: false },
  { feature: 'Compatible Factur-X 2026',         factpilot: true, competitor: false },
  { feature: 'Intégration Sage/Cegid/Quadratus', factpilot: true, competitor: false },
  { feature: 'Sans migration requise',           factpilot: true, competitor: false },
];

// ---------------------------------------------------------------------------
// Private generators
// ---------------------------------------------------------------------------

/**
 * Content for 'industry' pages.
 * @param {string} label  — e.g. "cabinet comptable", "e-commerce"
 */
function getIndustryContent(label) {
  return {
    category: 'Secteur',
    categoryColor: '#466cf3',
    readingTime: '5 min',
    sections: [
      {
        heading: `Pourquoi automatiser la comptabilité ${label}`,
        body: `Le secteur ${label} génère un volume de documents comptables en constante augmentation : factures fournisseurs, notes de frais, avoirs et relevés bancaires s'accumulent chaque mois dans des formats hétérogènes. Les équipes comptables consacrent en moyenne 40 % de leur temps à des tâches de saisie manuelle, au détriment des missions à forte valeur ajoutée comme le conseil ou l'analyse financière. Face aux exigences réglementaires croissantes — notamment la réforme Factur-X prévue pour 2026 — les acteurs du secteur ${label} n'ont plus le luxe d'attendre pour moderniser leurs processus. L'automatisation comptable n'est plus un avantage concurrentiel optionnel : c'est une nécessité opérationnelle.`,
        bullets: [
          `Volume documentaire élevé et formats variés spécifiques au secteur ${label}`,
          "Risque d'erreurs de saisie manuelle avec impact direct sur la clôture mensuelle",
          'Délais de rapprochement bancaire incompatibles avec les besoins de pilotage trésorerie',
          'Conformité réglementaire (FEC, TVA, Factur-X) de plus en plus contraignante et contrôlée',
          'Pression sur les marges : chaque heure gagnée sur la saisie se reporte sur le conseil',
        ],
      },
      {
        heading: `FactPilot pour ${label} : ce qui change`,
        body: `FactPilot a été conçu pour répondre aux spécificités documentaires du secteur ${label}, en combinant reconnaissance optique de caractères (OCR) avancée et moteurs d'IA entraînés sur des millions de documents français. Dès la première connexion, le logiciel lit automatiquement vos factures — même scannées en basse résolution — et les réconcilie avec vos flux bancaires sans intervention humaine. L'intégration native avec Sage, Cegid et Quadratus garantit une adoption immédiate par vos équipes, sans migration de données ni coût caché. En moins de 60 minutes, votre cabinet ou service comptable est opérationnel et traite ses premiers documents avec un taux d'extraction supérieur à 95 %.`,
        bullets: [
          'Lecture intelligente des factures PDF, photo et scan basse qualité',
          `Catégorisation automatique adaptée aux codes analytiques du secteur ${label}`,
          "Rapprochement bancaire instantané sur l'ensemble de vos flux entrants et sortants",
          "Export FEC certifié conforme aux exigences de l'administration fiscale française",
          "Génération de factures Factur-X 2026 dès aujourd'hui pour anticiper l'obligation légale",
          'Connexion sécurisée à votre logiciel existant : zéro migration, zéro risque, zéro formation',
        ],
        sub: [
          {
            heading: 'Extraction et classification automatique',
            body: `FactPilot lit tous les formats de documents rencontrés dans le secteur ${label} — PDFs natifs, scans dégradés, photos smartphone, pièces jointes WhatsApp. Le moteur OCR combiné à l'IA extrait fournisseur, SIRET, montants HT/TVA/TTC, date et numéro de facture avec un taux de précision supérieur à 95 %, sans aucun gabarit à configurer.`,
          },
          {
            heading: 'Rapprochement bancaire en temps réel',
            body: `Dès qu'un relevé bancaire est importé, FactPilot associe automatiquement chaque transaction aux factures correspondantes. Les impayés remontent seuls dans le tableau de bord, et la traçabilité complète est disponible pour n'importe quel contrôle fiscal — sans travail manuel supplémentaire de la part de vos équipes.`,
          },
          {
            heading: 'Intégration sans migration avec vos logiciels',
            body: `FactPilot se connecte nativement à Sage, Cegid, Quadratus, Pennylane et ACD. Les écritures validées sont poussées automatiquement dans votre logiciel comptable, au format attendu, sans ressaisie ni double vérification. La mise en route prend 60 minutes et ne nécessite aucune intervention de votre équipe informatique.`,
          },
        ],
      },
      {
        heading: `Comment déployer FactPilot dans votre structure ${label}`,
        bullets: [
          'Créez votre compte — essai gratuit 14 jours, aucune carte bancaire requise',
          'Connectez votre logiciel comptable — Sage, Cegid ou Quadratus en quelques clics',
          'Configurez votre adresse de dépôt email — vos fournisseurs envoient directement leurs factures',
          'Importez vos relevés bancaires — le rapprochement IA démarre automatiquement',
          'Exportez votre FEC — conforme DGFiP, prêt pour tout contrôle fiscal',
        ],
      },
      {
        heading: 'Résultats mesurables',
        body: `Les cabinets et entreprises du secteur ${label} ayant adopté FactPilot constatent des gains immédiatement quantifiables sur leurs indicateurs opérationnels. La réduction du temps de saisie libère les collaborateurs pour des tâches à plus forte valeur ajoutée, améliorant à la fois la satisfaction des équipes et la qualité du service rendu aux clients. Les erreurs de rapprochement bancaire disparaissent quasi intégralement, ce qui réduit les délais de clôture mensuelle et améliore la visibilité sur la trésorerie en temps réel. Ces résultats sont atteints sans changement d'organisation ni interruption d'activité, grâce à une mise en route en 60 minutes chrono.`,
        stats: STATS_INDUSTRY_USECASE,
      },
    ],
    faq: [
      {
        q: `FactPilot est-il adapté aux spécificités comptables du secteur ${label} ?`,
        a: `Oui. FactPilot a été entraîné sur des documents réels issus de nombreux secteurs d'activité, dont ${label}. Ses modèles d'extraction reconnaissent les formats de factures, les intitulés de postes et les codes analytiques propres à ce secteur, ce qui garantit un taux de précision supérieur à 95 % dès les premiers traitements, sans configuration manuelle préalable.`,
      },
      {
        q: `Combien de temps faut-il pour déployer FactPilot dans une structure ${label} ?`,
        a: `La mise en route prend moins de 60 minutes. FactPilot se connecte à votre logiciel comptable existant (Sage, Cegid, Quadratus…) via une intégration native, sans migration de données ni interruption d'activité. Votre équipe peut commencer à traiter des documents le jour même de l'activation, avec un accompagnement disponible si nécessaire.`,
      },
      {
        q: `FactPilot est-il conforme aux obligations fiscales françaises pour le secteur ${label} ?`,
        a: `Absolument. FactPilot génère des exports FEC (Fichier des Écritures Comptables) certifiés conformes aux exigences de la DGFiP, et prend déjà en charge la norme Factur-X 2026. Votre structure ${label} est ainsi protégée en cas de contrôle fiscal et préparée à l'obligation légale de facturation électronique sans aucun développement supplémentaire.`,
      },
    ],
  };
}

/**
 * Content for 'use-case' pages.
 * @param {string} label  — e.g. "automatisation saisie", "rapprochement bancaire"
 */
function getUseCaseContent(label) {
  return {
    category: "Cas d'usage",
    categoryColor: '#10b981',
    readingTime: '4 min',
    sections: [
      {
        heading: `${label} : le défi quotidien des cabinets`,
        body: `La ${label} est l'une des tâches les plus chronophages des services comptables et des cabinets : elle mobilise des collaborateurs qualifiés sur des opérations répétitives à faible valeur ajoutée, tout en générant un risque d'erreur non négligeable. Les volumes traités augmentent chaque année avec la digitalisation des échanges fournisseurs, sans que les effectifs dédiés ne progressent proportionnellement. Résultat : les clôtures s'allongent, les anomalies se multiplient et les équipes accumulent du retard sur des missions à plus fort impact. Automatiser la ${label} est aujourd'hui la première étape incontournable de toute transformation numérique comptable.`,
        bullets: [
          `Volumes en hausse constante rendant la ${label} manuelle insoutenable à terme`,
          "Erreurs de saisie dont la détection tardive retarde les clôtures et fausse les reportings",
          'Dépendance à des collaborateurs spécialisés mobilisés sur des tâches sans valeur ajoutée',
          'Hétérogénéité des formats documentaires (PDF natif, scan, photo smartphone, email)',
          'Délais de traitement incompatibles avec les besoins de pilotage financier en temps réel',
        ],
      },
      {
        heading: `Comment FactPilot automatise ${label}`,
        body: `FactPilot transforme la ${label} en un processus entièrement automatisé, depuis la réception du document jusqu'à l'écriture comptable validée dans votre logiciel. Le moteur d'IA extrait les données clés — montants, TVA, IBAN, dates, références fournisseur — avec une précision supérieure à 95 %, même sur des scans de mauvaise qualité ou des formats non standardisés. Chaque pièce traitée est immédiatement réconciliée avec les flux bancaires correspondants, éliminant les opérations de rapprochement manuel. L'intégration directe avec Sage, Cegid ou Quadratus garantit que chaque écriture générée respecte votre plan de comptes et vos règles d'imputation sans aucune ressaisie.`,
        bullets: [
          `Ingestion automatique des documents déclenchant la ${label} sans action humaine`,
          'Extraction IA des données structurées avec contrôle de cohérence et détection des doublons',
          "Rapprochement bancaire en temps réel sur l'ensemble des flux entrants et sortants",
          "Proposition d'imputation comptable basée sur l'historique et les règles métier définies",
          'Validation en un clic pour les cas conformes, signalement ciblé des seules anomalies',
          'Export automatique vers votre logiciel comptable sans double saisie ni retraitement',
        ],
        sub: [
          {
            heading: 'Réception multicanal des documents',
            body: `FactPilot accepte les documents liés à la ${label} par tous les canaux : email (adresse de dépôt dédiée), WhatsApp, upload manuel ou API. Chaque pièce est traitée dans les secondes qui suivent sa réception, quel que soit son format ou sa qualité de numérisation.`,
          },
          {
            heading: 'Validation intelligente et contrôle qualité',
            body: `Le moteur IA de FactPilot détecte automatiquement les doublons, les montants incohérents et les informations manquantes. Seules les anomalies réelles sont remontées pour validation humaine — les cas conformes sont traités et exportés sans intervention, ce qui réduit drastiquement le temps consacré à la ${label}.`,
          },
        ],
      },
      {
        heading: `Démarrer avec FactPilot pour ${label}`,
        bullets: [
          "Créez votre compte — essai 14 jours gratuit, opérationnel en 60 minutes",
          "Connectez votre logiciel comptable — Sage, Cegid ou Quadratus nativement",
          "Configurez vos règles métier — plan de comptes, codes analytiques, seuils de validation",
          "Importez vos premiers documents — FactPilot traite et classe automatiquement",
          "Exportez en FEC ou vers votre logiciel — sans ressaisie ni double vérification",
        ],
      },
      {
        heading: 'Résultats concrets',
        body: `Les équipes qui ont automatisé leur ${label} avec FactPilot rapportent des gains de productivité immédiats et mesurables, sans période de transition longue ni coût de formation élevé. La suppression de la ressaisie manuelle élimine la principale source d'erreurs, ce qui réduit les délais de clôture mensuelle et améliore la fiabilité des reportings transmis aux dirigeants. Les collaborateurs libérés de ces tâches répétitives se concentrent sur l'analyse, le conseil et la relation client — les missions pour lesquelles leur expertise est réellement indispensable et facturable.`,
        stats: STATS_INDUSTRY_USECASE,
      },
    ],
    faq: [
      {
        q: `FactPilot peut-il prendre en charge tous les formats de documents pour ${label} ?`,
        a: `Oui. FactPilot traite les PDF natifs, les scans (y compris basse résolution), les photos prises avec un smartphone et les pièces jointes reçues par email. Son moteur OCR combiné à l'IA garantit une extraction fiable quelle que soit la qualité du document source, couvrant ainsi l'intégralité des cas rencontrés dans la pratique quotidienne de la ${label}.`,
      },
      {
        q: `Faut-il paramétrer FactPilot pour chaque type de document rencontré dans ${label} ?`,
        a: `Non. FactPilot apprend automatiquement à partir des documents que vous lui soumettez et s'adapte à votre plan de comptes sans configuration manuelle préalable. Pour les cas particuliers, vous pouvez définir des règles métier spécifiques via une interface no-code accessible à tous vos collaborateurs, sans intervention de l'équipe technique.`,
      },
      {
        q: `Comment FactPilot s'intègre-t-il à notre logiciel actuel pour automatiser ${label} ?`,
        a: `FactPilot propose des connecteurs natifs pour Sage, Cegid et Quadratus, ainsi qu'une API REST pour toute intégration sur mesure. La connexion se fait en lecture/écriture sécurisée, sans migration de données ni interruption de service. Vous continuez à travailler dans votre environnement habituel ; FactPilot s'y greffe de manière transparente pour automatiser la ${label} sans perturber vos processus existants.`,
      },
    ],
  };
}

/**
 * Content for 'comparison' pages.
 * @param {string} label    — e.g. "Pennylane", "Sage", "QuickBooks"
 * @param {string} slugKey  — e.g. "pennylane", "sage"
 */
function getComparisonContent(label, slugKey) {
  return {
    category: 'Comparatif',
    categoryColor: '#8b5cf6',
    readingTime: '6 min',
    sections: [
      {
        heading: `FactPilot vs ${label} : vue d'ensemble`,
        body: `Choisir son logiciel de comptabilité automatisée est une décision structurante pour un cabinet ou un service financier : elle engage les équipes sur plusieurs années et conditionne directement la qualité des données produites. FactPilot et ${label} s'adressent tous deux aux professionnels de la comptabilité, mais avec des philosophies très différentes en matière d'extraction documentaire, de conformité réglementaire et de facilité d'adoption. Là où ${label} a construit sa notoriété sur des fonctionnalités généralistes, FactPilot a fait le choix d'une spécialisation totale sur l'automatisation comptable française — FEC certifié, Factur-X 2026, intégrations natives Sage/Cegid/Quadratus — pour maximiser la précision et minimiser le temps de déploiement. Ce comparatif détaillé vous permet d'évaluer les deux solutions sur les critères qui comptent vraiment pour votre activité.`,
        bullets: [
          "FactPilot : spécialiste de l'automatisation comptable conçu pour le marché français",
          `${label} : solution généraliste avec fonctionnalités comptables intégrées`,
          'Extraction IA de documents : précision et robustesse sur scans dégradés',
          'Conformité réglementaire : export FEC certifié et Factur-X 2026 natif',
          'Intégrations : Sage, Cegid, Quadratus sans migration ni coût additionnel',
          `Mise en route : FactPilot opérationnel en 60 minutes, ${label} en plusieurs semaines`,
        ],
      },
      {
        heading: 'Comparaison des fonctionnalités clés',
        body: `Le tableau ci-dessous présente une analyse fonctionnelle objective des deux solutions sur les sept critères déterminants pour l'automatisation comptable en France. Ces critères ont été sélectionnés sur la base des besoins les plus fréquemment exprimés par les cabinets d'expertise comptable et les directions financières lors de leurs évaluations logicielles. La conformité réglementaire et la qualité de l'extraction documentaire apparaissent systématiquement en tête des priorités, bien avant le prix ou la notoriété de la marque.`,
        comparison: COMPARISON_TABLE,
      },
      {
        heading: `Pourquoi choisir FactPilot plutôt que ${label}`,
        body: `Au-delà du tableau de fonctionnalités, le choix entre FactPilot et ${label} se joue sur trois dimensions pratiques : la rapidité de mise en œuvre, le coût total de possession et la sérénité réglementaire. FactPilot est opérationnel en 60 minutes sans migration, ce qui signifie aucun risque de perte de données et aucune interruption d'activité pendant la transition. Son positionnement exclusif sur la comptabilité française lui permet d'intégrer nativement les contraintes FEC et Factur-X que ${label} ne couvre pas en standard. Avec 120 heures récupérées chaque mois, un taux d'extraction IA supérieur à 95 % et une migration à 0 €, le retour sur investissement est mesurable dès le premier mois d'utilisation.`,
        stats: STATS_COMPARISON,
      },
    ],
    faq: [
      {
        q: `FactPilot est-il vraiment meilleur que ${label} pour l'extraction de factures ?`,
        a: `Sur ce critère spécifique, oui. FactPilot a été conçu exclusivement pour l'extraction de documents comptables français, avec un moteur d'IA entraîné sur des millions de factures, avoirs et relevés bancaires du marché français. Il atteint un taux d'extraction supérieur à 95 %, y compris sur des scans dégradés, là où ${label} s'appuie sur une reconnaissance documentaire généraliste moins précise pour les cas complexes rencontrés en pratique.`,
      },
      {
        q: `Peut-on passer de ${label} à FactPilot sans perdre ses données historiques ?`,
        a: `La transition depuis ${label} ne nécessite aucun transfert de données : FactPilot se connecte à votre logiciel comptable de référence (Sage, Cegid, Quadratus) en lecture/écriture et reprend le traitement des nouveaux documents immédiatement. Vos données historiques restent disponibles dans votre environnement actuel, et aucune reprise manuelle n'est requise pour démarrer — la migration est littéralement à 0 €.`,
      },
      {
        q: `${label} prend-il en charge la norme Factur-X 2026 comme FactPilot ?`,
        a: `À ce jour, ${label} ne propose pas de prise en charge native de la norme Factur-X 2026 dans son offre standard. FactPilot intègre nativement la génération et la lecture de factures Factur-X, ce qui permet à vos clients et fournisseurs d'être prêts pour l'obligation légale de facturation électronique sans développement supplémentaire ni module additionnel payant.`,
      },
    ],
  };
}

// ---------------------------------------------------------------------------
// Public API — only export
// ---------------------------------------------------------------------------

/**
 * Generate structured PSEO content for a FactPilot page.
 *
 * @param {{
 *   kind: 'industry' | 'use-case' | 'comparison',
 *   data: { slug_key_label: string, slug_key: string },
 *   keyword: string,
 *   title: string,
 *   description: string,
 * }} page
 *
 * @returns {{
 *   category: string,
 *   categoryColor: string,
 *   readingTime: string,
 *   sections: Array<{
 *     heading: string,
 *     body: string,
 *     bullets?: string[],
 *     stats?: Array<{ value: string, label: string }>,
 *     comparison?: Array<{ feature: string, factpilot: boolean, competitor: boolean }>,
 *   }>,
 *   faq: Array<{ q: string, a: string }>,
 * }}
 */
export function getPseoContent(page) {
  const { kind, data } = page;
  const label = data.slug_key_label;
  const slugKey = data.slug_key;

  switch (kind) {
    case 'industry':
      return getIndustryContent(label);
    case 'use-case':
      return getUseCaseContent(label);
    case 'comparison':
      return getComparisonContent(label, slugKey);
    default:
      throw new Error(
        `Unknown PSEO page kind: "${kind}". Expected 'industry', 'use-case', or 'comparison'.`
      );
  }
}
