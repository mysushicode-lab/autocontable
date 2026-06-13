"""
Constants shared across the application
"""

# PCG account mapping — catégories universelles applicables à toute entreprise
PCG_COMPTES = {
    'Achats de marchandises':        ('607000', 'Achats de marchandises'),
    'Fournitures et consommables':   ('606000', 'Fournitures et consommables'),
    'Sous-traitance':                ('611000', 'Sous-traitance générale'),
    'Équipement et outillage':       ('606310', 'Petit outillage et matériel'),
    'Énergie et locaux':             ('606110', 'Électricité, gaz, loyer'),
    'Assurances et frais':           ('616000', "Primes d'assurances et frais bancaires"),
    'Déplacements et transports':    ('625100', 'Voyages et déplacements'),
    'Informatique et communication': ('626000', 'Téléphone, internet et logiciels'),
    'Services et prestations':       ('628100', 'Services extérieurs et prestations'),
    'Formation et divers':           ('628000', 'Charges diverses de gestion'),
}

DEFAULT_COMPTE = ('608000', 'Achats divers non stockés')
TVA_COMPTE    = ('445660', 'TVA déductible — achats et services')
FOURN_COMPTE  = ('401000', 'Fournisseurs')
