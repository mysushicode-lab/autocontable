export const metadata = {
  title: 'Politique de confidentialité — FactPilot',
  description: 'Politique de confidentialité et protection des données personnelles de FactPilot, conforme RGPD.',
  robots: 'index, follow',
};

export default function PolitiqueConfidentialite() {
  return (
    <div className="min-h-screen bg-white">
      <div className="max-w-4xl mx-auto px-6 py-16">
        <h1 className="text-4xl font-bold text-gray-900 mb-8">Politique de confidentialité</h1>

        <div className="prose prose-gray max-w-none">
          <p className="text-sm text-gray-500 mb-8">Dernière mise à jour : {new Date().toLocaleDateString('fr-FR', { year: 'numeric', month: 'long', day: 'numeric' })}</p>

          <section className="mb-12">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">1. Introduction</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              FactPilot, accessible à l'adresse <a href="https://factpilot.fr" className="text-blue-600 hover:underline">factpilot.fr</a>, est édité par MySushiCode.
              Nous accordons une grande importance à la protection de vos données personnelles et nous nous engageons à les traiter de manière transparente, conformément au Règlement Général sur la Protection des Données (RGPD) et à la loi Informatique et Libertés.
            </p>
          </section>

          <section className="mb-12">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">2. Responsable du traitement</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              Le responsable du traitement des données personnelles est :
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li><strong>MySushiCode</strong></li>
              <li>Email : <a href="mailto:contact@factpilot.fr" className="text-blue-600 hover:underline">contact@factpilot.fr</a></li>
              <li>Site web : <a href="https://mysushicode.fr" className="text-blue-600 hover:underline" target="_blank" rel="noopener">mysushicode.fr</a></li>
            </ul>
          </section>

          <section className="mb-12">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">3. Données collectées</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              Nous collectons les données personnelles suivantes :
            </p>

            <h3 className="text-xl font-semibold text-gray-800 mb-3 mt-6">3.1 Données d'inscription</h3>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>Nom et prénom</li>
              <li>Adresse email</li>
              <li>Nom d'utilisateur et mot de passe (chiffré)</li>
              <li>Nom de l'entreprise/cabinet</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-800 mb-3 mt-6">3.2 Données professionnelles</h3>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>Factures fournisseurs (PDF, images)</li>
              <li>Relevés bancaires</li>
              <li>Données comptables (écritures, exports FEC)</li>
              <li>Paramètres de connexion IMAP/email</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-800 mb-3 mt-6">3.3 Données de connexion OAuth</h3>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>Profil Google ou LinkedIn (nom, email, photo de profil)</li>
              <li>Uniquement si vous choisissez de vous connecter via ces services</li>
            </ul>

            <h3 className="text-xl font-semibold text-gray-800 mb-3 mt-6">3.4 Données techniques</h3>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>Adresse IP</li>
              <li>Logs de connexion</li>
              <li>Données de navigation (cookies techniques)</li>
            </ul>
          </section>

          <section className="mb-12">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">4. Finalités du traitement</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              Vos données personnelles sont traitées pour les finalités suivantes :
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>Gestion de votre compte et authentification</li>
              <li>Fourniture des services de traitement automatisé des factures</li>
              <li>Rapprochement bancaire automatique</li>
              <li>Export des données comptables (FEC)</li>
              <li>Support client et assistance technique</li>
              <li>Facturation et gestion des abonnements</li>
              <li>Amélioration de nos services (analyses anonymisées)</li>
              <li>Respect de nos obligations légales</li>
            </ul>
          </section>

          <section className="mb-12">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">5. Base légale du traitement</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              Le traitement de vos données repose sur les bases légales suivantes :
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li><strong>Exécution du contrat</strong> : pour fournir les services FactPilot</li>
              <li><strong>Consentement</strong> : pour les connexions OAuth (Google, LinkedIn)</li>
              <li><strong>Intérêt légitime</strong> : pour la sécurité et l'amélioration du service</li>
              <li><strong>Obligation légale</strong> : conservation des données comptables (Code de commerce)</li>
            </ul>
          </section>

          <section className="mb-12">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">6. Destinataires des données</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              Vos données personnelles sont destinées aux entités suivantes :
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li><strong>Personnel autorisé de MySushiCode</strong> (support, développement)</li>
              <li><strong>Hébergeur</strong> : Hetzner (Allemagne, conforme RGPD)</li>
              <li><strong>Prestataires techniques</strong> :
                <ul className="list-circle list-inside ml-6 mt-2 space-y-1">
                  <li>OpenAI (traitement IA des factures, USA - Privacy Shield)</li>
                  <li>Stripe (paiements, USA - Privacy Shield)</li>
                </ul>
              </li>
            </ul>
            <p className="text-gray-700 leading-relaxed mt-4">
              <strong>Nous ne vendons jamais vos données à des tiers.</strong>
            </p>
          </section>

          <section className="mb-12">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">7. Durée de conservation</h2>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li><strong>Données de compte</strong> : durée de l'abonnement + 3 ans après résiliation</li>
              <li><strong>Factures et données comptables</strong> : 10 ans (obligation légale)</li>
              <li><strong>Logs de connexion</strong> : 12 mois</li>
              <li><strong>Données marketing</strong> : 3 ans d'inactivité</li>
            </ul>
          </section>

          <section className="mb-12">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">8. Vos droits</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              Conformément au RGPD, vous disposez des droits suivants :
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li><strong>Droit d'accès</strong> : obtenir une copie de vos données</li>
              <li><strong>Droit de rectification</strong> : corriger vos données inexactes</li>
              <li><strong>Droit à l'effacement</strong> : supprimer votre compte et vos données</li>
              <li><strong>Droit à la portabilité</strong> : récupérer vos données dans un format structuré</li>
              <li><strong>Droit d'opposition</strong> : vous opposer à certains traitements</li>
              <li><strong>Droit de limitation</strong> : limiter le traitement de vos données</li>
            </ul>
            <p className="text-gray-700 leading-relaxed mt-4">
              Pour exercer vos droits, contactez-nous à <a href="mailto:contact@factpilot.fr" className="text-blue-600 hover:underline">contact@factpilot.fr</a> avec une preuve d'identité.
            </p>
          </section>

          <section className="mb-12">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">9. Sécurité des données</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              Nous mettons en œuvre les mesures de sécurité suivantes :
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>Chiffrement des communications (HTTPS/TLS)</li>
              <li>Chiffrement des mots de passe (bcrypt)</li>
              <li>Hébergement sécurisé en Europe (Hetzner, Allemagne)</li>
              <li>Sauvegardes quotidiennes chiffrées</li>
              <li>Accès restreint aux données (authentification 2FA pour le staff)</li>
              <li>Audit de sécurité régulier</li>
            </ul>
          </section>

          <section className="mb-12">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">10. Cookies</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              FactPilot utilise uniquement des <strong>cookies techniques strictement nécessaires</strong> au fonctionnement du service (session, authentification). Aucun cookie publicitaire ou de tracking tiers n'est utilisé.
            </p>
          </section>

          <section className="mb-12">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">11. Transferts internationaux</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              Vos données sont hébergées en Europe (Allemagne). Certains prestataires (OpenAI, Stripe) sont situés aux USA mais bénéficient de garanties appropriées (Privacy Shield, clauses contractuelles types).
            </p>
          </section>

          <section className="mb-12">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">12. Modifications</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              Nous nous réservons le droit de modifier cette politique de confidentialité. Toute modification sera communiquée par email et affichée sur cette page avec la date de mise à jour.
            </p>
          </section>

          <section className="mb-12">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">13. Réclamation</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              Si vous estimez que vos droits ne sont pas respectés, vous pouvez déposer une réclamation auprès de la CNIL :
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>CNIL - 3 Place de Fontenoy, 75007 Paris</li>
              <li>Site web : <a href="https://www.cnil.fr" className="text-blue-600 hover:underline" target="_blank" rel="noopener">cnil.fr</a></li>
              <li>Téléphone : 01 53 73 22 22</li>
            </ul>
          </section>

          <section className="mb-12">
            <h2 className="text-2xl font-semibold text-gray-900 mb-4">14. Contact</h2>
            <p className="text-gray-700 leading-relaxed mb-4">
              Pour toute question relative à cette politique de confidentialité :
            </p>
            <ul className="list-disc list-inside text-gray-700 space-y-2 ml-4">
              <li>Email : <a href="mailto:contact@factpilot.fr" className="text-blue-600 hover:underline">contact@factpilot.fr</a></li>
              <li>Site web : <a href="https://factpilot.fr" className="text-blue-600 hover:underline">factpilot.fr</a></li>
            </ul>
          </section>
        </div>
      </div>
    </div>
  );
}
