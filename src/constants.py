"""
Constants shared across the application
"""

# PCG account mapping for carrosserie auto
PCG_COMPTES = {
    'Pièces détachées':              ('607100', 'Achats marchandises — pièces auto'),
    'Peinture et vernis':            ('607200', 'Achats — peinture et vernis'),
    'Fournitures atelier':           ('606400', 'Fournitures atelier et consommables'),
    'Sous-traitance':                ('611000', 'Sous-traitance générale'),
    'Équipement et outillage':       ('606310', 'Petit outillage'),
    'Énergie et locaux':             ('606110', 'Électricité, gaz, loyer'),
    'Assurances et frais':           ('616000', "Primes d'assurances"),
    'Déplacements et véhicules':     ('625100', 'Voyages et déplacements'),
    'Informatique et communication': ('626000', 'Téléphone et internet'),
    'Formation et divers':           ('628000', 'Charges diverses de gestion'),
}

DEFAULT_COMPTE = ('608000', 'Achats divers non stockés')
TVA_COMPTE    = ('445660', 'TVA déductible — achats et services')
FOURN_COMPTE  = ('401000', 'Fournisseurs')
