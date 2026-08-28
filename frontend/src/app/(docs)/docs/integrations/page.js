import Link from 'next/link';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Intégrations', description: 'Connectez FactPilot à votre logiciel comptable pour synchroniser les écritures.' };

const TOC = [
  { id: 'overview', label: 'Vue d\'ensemble' },
  { id: 'logiciels', label: 'Logiciels supportés' },
  { id: 'modes', label: 'Modes de synchronisation' },
];

export default function IntegrationsPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Intégrations <span className="docs-badge docs-badge-pro">Pro</span></h1>
        <p className="docs-lead">Synchronisez automatiquement les écritures FactPilot vers votre logiciel comptable après chaque validation.</p>

        <h2 id="overview">Vue d'ensemble</h2>
        <p>Une fois configurée, l'intégration synchronise les écritures validées vers le logiciel comptable cible — sans copier-coller ni re-saisie. La synchronisation peut être automatique (après chaque validation) ou déclenchée manuellement.</p>

        <h2 id="logiciels">Logiciels supportés</h2>
        <ul>
          <li><Link href="/docs/integrations/sage">Sage</Link> — Sage 50, Sage 100, Sage 1000</li>
          <li><Link href="/docs/integrations/cegid">Cegid</Link> — Cegid Business, Cegid Y2</li>
          <li><Link href="/docs/integrations/quadratus">Quadratus</Link> — Q-Compta, Q-Win</li>
          <li><Link href="/docs/integrations/pennylane">Pennylane</Link> — via API OAuth</li>
          <li><Link href="/docs/integrations/acd">ACD</Link> — via fichier d'import</li>
        </ul>

        <h2 id="modes">Modes de synchronisation</h2>
        <table>
          <thead><tr><th>Mode</th><th>Description</th><th>Logiciels</th></tr></thead>
          <tbody>
            <tr><td><strong>API directe</strong></td><td>Push temps réel via l'API du logiciel</td><td>Pennylane</td></tr>
            <tr><td><strong>Fichier partagé</strong></td><td>Export vers un répertoire réseau lu par le logiciel</td><td>Sage, Cegid, Quadratus, ACD</td></tr>
          </tbody>
        </table>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
