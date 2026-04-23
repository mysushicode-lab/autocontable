"""
Invoice categorization
"""
import re
from typing import Optional, Dict, List


class CategoryClassifier:
    """Classify invoices into categories"""
    
    # Carrosserie auto specific categories (French)
    CATEGORY_KEYWORDS = {
        'Pièces détachées': [
            'pièce', 'pieces', 'piece', 'catalyseur', 'echappement', 'frein', 
            'plaquette', 'disque', 'amortisseur', 'pare-brise', 'retro', 'optique',
            'parechoc', 'pare-choc', 'feu arriere', 'feux', 'phare', 'batterie',
            'pneu', 'pneumatique', 'jante', 'roue', 'alternateur', 'demarreur',
            'radiateur', 'ventilateur', 'filtre', 'huile', 'carrosserie piece',
            'autodoc', 'oscaro', 'norauto', 'feu vert', 'euromaster',
            'pieces auto', 'piece auto', 'tuning', 'garage', 'mister auto',
            'pieces detachees', 'recambio', 'rechange', 'spare parts'
        ],
        'Peinture et vernis': [
            'peinture', 'vernis', 'apprêt', 'appret', 'couche', 'melange', 
            'melangeur', 'teinte', 'colorant', 'base', 'clear', 'vernis',
            'axalta', 'cromax', 'glasurit', 'lesonal', 'sikkens', 'ppg',
            'spies hecker', 'standox', 'basf', 'paint', 'refinish',
            'pistolet', 'compresseur', 'cabine', 'aerographe',
            'diluant', 'durcisseur', 'solvant', 'ponçage', 'abrasif',
            'papier abrasif', 'disque abrasif', 'polissage', 'polish'
        ],
        'Fournitures atelier': [
            'fourniture', 'consommable', 'atelier', 'chiffon', 'essuie',
            'masque', 'gant', 'protection', 'produit nettoyage', 'degoudron',
            'antigravillon', 'graisse', 'lubrifiant', 'colle', 'mastic',
            'body filler', 'mastiquer', 'joint', 'jointure', 'soudure',
            'point de soudure', 'soudeur', 'meulage', 'ponceuse', 'meule',
            'disque flap', 'bouchon', 'ruban', 'scotch', 'adhesif',
            'bache', 'film', 'protection film', 'cache', 'papier kraft'
        ],
        'Sous-traitance': [
            'sous-traitance', 'sous traitance', 'sous traitant', 'prestataire',
            'service extérieur', 'prestation', 'expert', 'expertise',
            'devis expert', 'remorquage', 'depannage', 'depanneur',
            'location remorque', 'transport vehicule', 'convoyage',
            'machine à laver', 'nettoyage', 'pressing', 'remise en etat',
            'preparation technique', 'controle technique', 'ct',
            'geometrie', 'parallélisme', 'alignement', 'pneu service',
            'montage pneu', 'equilibrage', 'climatisation', 'recharge clim'
        ],
        'Équipement et outillage': [
            'outil', 'outillage', 'equipement', 'machine', 'appareil',
            'soudeuse', 'pointeuse', 'débosselage', 'debosseleur',
            'marteau', 'dolly', 'marteau dolly', 'extracteur', 'arrache',
            'verin', 'presse', 'etabli', 'servante', 'servante mobile',
            'chassis', 'elevateur', 'pont', 'pont elevateur', 'crique',
            'verin hydraulique', 'banc redresseur', 'centreuse',
            'ordinateur', 'diagnostic', 'valise', 'scanner',
            'projecteur', 'lampe', 'eclairage', 'aspiration', 'aspirateur'
        ],
        'Énergie et locaux': [
            'électricité', 'electricite', 'edf', 'engie', 'gaz', 'eau',
            'chauffage', 'climatisation', 'ventilation', 'atelier',
            'loyer', 'bail', 'immobilier', 'proprietaire', 'locataire',
            ' charges', 'copropriete', 'taxe fonciere', 'foncier',
            'assurance local', 'assurance batiment', 'dommage ouvrage',
            'entretien local', 'menage', 'nettoyage', 'déchets', 'dechetterie',
            'recyclage', 'environnement', 'securite', 'alarme', 'surveillance'
        ],
        'Assurances et frais': [
            'assurance', 'assurance pro', 'rc pro', 'responsabilite civile',
            'assurance decennale', 'dommage', 'protection juridique',
            'mutuelle', 'prevoyance', 'retraite', 'urssaf', 'cotisation',
            'comptable', 'expert comptable', 'commissaire aux comptes',
            'avocat', 'notaire', 'huissier', 'courtier', 'banque',
            'frais bancaire', 'interet', 'emprunt', 'credit', 'leasing',
            'credit bail', 'location longue duree', 'lld'
        ],
        'Déplacements et véhicules': [
            'carburant', 'essence', 'diesel', 'gpl', 'station service',
            'total', 'shell', 'bp', 'elan', 'avia', 'super u',
            'peage', 'autoroute', 'parking', 'taxi', 'uber', 'bolt',
            'location voiture', 'location utilitaire', 'utilitaire',
            'camion', 'camionnette', 'vehicule service', 'vs',
            'remboursement km', 'indemnite kilometrique', 'transport',
            'train', 'sncf', 'bus', 'avion', 'hotel', 'restaurant',
            'repas', 'deplacement', 'mission', 'client', 'livraison'
        ],
        'Informatique et communication': [
            'telephone', 'mobile', 'forfait', 'sfr', 'orange', 'bouygues',
            'free', 'internet', 'fibre', 'adsl', 'box', 'communication',
            'ordinateur', 'pc', 'portable', 'imprimante', 'scanner',
            'logiciel', 'programme', 'application', 'gestion',
            'comptabilite', 'facturation', 'devis', 'planning',
            'site web', 'hebergement', 'nom de domaine', 'referencement',
            'crm', 'erp', 'garage management system', 'gestion atelier'
        ],
        'Formation et divers': [
            'formation', 'stage', 'certification', 'qualification',
            'cqp', 'cap', 'bts', 'formation professionnelle',
            'congres', 'salon', 'equip auto', 'automechanika',
            'serbotec', 'saga', 'motortec', 'expoprotection',
            'adhesion', 'syndicat', 'chambre metiers', 'cma',
            'chambre commerce', 'cci', 'bureau veritas', 'gipa',
            'carte grise', 'document', 'imprimerie', 'papeterie'
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
