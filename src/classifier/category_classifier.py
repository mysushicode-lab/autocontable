"""
Invoice categorization
"""
import re
from typing import Optional, Dict, List


class CategoryClassifier:
    """Classify invoices into categories"""
    
    # Universal business categories (applicable to any company, any sector)
    CATEGORY_KEYWORDS = {
        'Achats de marchandises': [
            'marchandise', 'stock', 'produit', 'article', 'bien',
            'matiere premiere', 'matériaux', 'materiaux', 'composant',
            'piece', 'pieces', 'accessoire', 'consommable produit',
            'approvisionnement', 'commande fournisseur', 'livraison stock',
            'spare parts', 'goods', 'supply', 'revendeur', 'grossiste',
            'negoce', 'distribution', 'import', 'export'
        ],
        'Fournitures et consommables': [
            'fourniture', 'consommable', 'atelier', 'bureau',
            'papeterie', 'stylo', 'classeur', 'ramette', 'enveloppe',
            'chiffon', 'gant', 'masque', 'protection', 'emballage',
            'ruban', 'scotch', 'adhesif', 'etiquette', 'colle',
            'nettoyage', 'produit entretien', 'produit hygiene',
            'graisse', 'lubrifiant', 'joint', 'visserie', 'boulonnerie'
        ],
        'Sous-traitance': [
            'sous-traitance', 'sous traitance', 'sous traitant', 'prestataire',
            'service extérieur', 'service exterrieur', 'prestation',
            'expertise', 'consultant', 'conseil', 'mission',
            'freelance', 'independant', 'façonnier', 'faconnier',
            'interim', 'portage salarial', 'externalisation',
            'maintenance externe', 'depannage', 'intervention technique'
        ],
        'Équipement et outillage': [
            'outil', 'outillage', 'equipement', 'machine', 'appareil',
            'materiel', 'instrument', 'dispositif', 'systeme',
            'mobilier', 'meuble', 'bureau', 'rangement', 'etagere',
            'ordinateur', 'serveur', 'scanner', 'imprimante', 'ecran',
            'projecteur', 'lampe', 'eclairage', 'aspiration', 'aspirateur',
            'verin', 'presse', 'etabli', 'pont', 'elevateur', 'crique'
        ],
        'Énergie et locaux': [
            'électricité', 'electricite', 'edf', 'engie', 'gaz', 'eau',
            'chauffage', 'climatisation', 'ventilation',
            'loyer', 'bail', 'immobilier', 'locataire',
            'charges', 'copropriete', 'taxe fonciere', 'foncier',
            'assurance batiment', 'entretien local', 'menage',
            'déchets', 'dechetterie', 'recyclage',
            'securite', 'alarme', 'surveillance', 'gardiennage'
        ],
        'Assurances et frais': [
            'assurance', 'rc pro', 'responsabilite civile',
            'mutuelle', 'prevoyance', 'retraite', 'urssaf', 'cotisation',
            'expert comptable', 'commissaire aux comptes',
            'avocat', 'notaire', 'huissier', 'courtier',
            'frais bancaire', 'interet', 'emprunt', 'credit', 'leasing',
            'credit bail', 'location longue duree', 'lld',
            'protection juridique', 'assurance pro'
        ],
        'Déplacements et transports': [
            'carburant', 'essence', 'diesel', 'gpl', 'station service',
            'peage', 'autoroute', 'parking', 'taxi', 'uber', 'bolt',
            'location voiture', 'location utilitaire', 'utilitaire',
            'camion', 'camionnette', 'transport',
            'train', 'sncf', 'bus', 'avion', 'hotel', 'restaurant',
            'repas', 'deplacement', 'mission', 'livraison',
            'remboursement km', 'indemnite kilometrique'
        ],
        'Informatique et communication': [
            'telephone', 'mobile', 'forfait', 'sfr', 'orange', 'bouygues',
            'free', 'internet', 'fibre', 'adsl', 'box', 'communication',
            'ordinateur', 'pc', 'portable', 'tablette',
            'logiciel', 'programme', 'application', 'abonnement',
            'saas', 'cloud', 'hebergement', 'nom de domaine', 'site web',
            'crm', 'erp', 'facturation', 'referencement', 'cybersecurite'
        ],
        'Services et prestations': [
            'conseil', 'audit', 'etude', 'analyse', 'rapport',
            'formation externe', 'coaching', 'accompagnement',
            'communication', 'marketing', 'publicite', 'impression',
            'graphisme', 'design', 'agence', 'redaction',
            'nettoyage', 'entretien', 'maintenance', 'reparation',
            'installation', 'livraison', 'coursier', 'expedition'
        ],
        'Formation et divers': [
            'formation', 'stage', 'certification', 'qualification',
            'bts', 'formation professionnelle', 'cpf',
            'congres', 'salon', 'conference', 'seminaire',
            'adhesion', 'syndicat', 'chambre metiers', 'chambre commerce',
            'cci', 'bureau veritas', 'document', 'imprimerie', 'papeterie'
        ]
    }
    
    def __init__(self):
        self.categories = list(self.CATEGORY_KEYWORDS.keys())
    
    def classify(self, invoice_data: Dict) -> Optional[str]:
        """
        Classify invoice into category based on content
        
        Args:
            invoice_data: Dictionary with extracted invoice data
            
        Returns:
            Category name or None
        """
        # Get text to analyze
        text = ""
        
        if invoice_data.get('supplier_name'):
            text += invoice_data['supplier_name'].lower() + " "
        
        if invoice_data.get('raw_text'):
            text += invoice_data['raw_text'].lower() + " "
        
        if invoice_data.get('email_subject'):
            text += invoice_data['email_subject'].lower() + " "
        
        # Score each category
        category_scores = {}
        for category, keywords in self.CATEGORY_KEYWORDS.items():
            score = 0
            for keyword in keywords:
                if keyword in text:
                    score += 1
            category_scores[category] = score
        
        # Return category with highest score
        max_score = max(category_scores.values())
        if max_score > 0:
            for category, score in category_scores.items():
                if score == max_score:
                    return category
        
        return None
    
    def set_custom_categories(self, categories: Dict[str, List[str]]):
        """
        Set custom category keywords
        
        Args:
            categories: Dictionary mapping category names to keyword lists
        """
        self.CATEGORY_KEYWORDS.update(categories)
        self.categories = list(self.CATEGORY_KEYWORDS.keys())
