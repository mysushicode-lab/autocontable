# 🔐 Qu'est-ce qu'une PME voit sur l'interface?

## Réponse Courte

Une PME voit **UNIQUEMENT** sa page "Mon Espace" (`/portal`).

```
Menu PME:
✓ Mon Espace ← SEUL accès

Menu ADMIN/COMPTABLE:
✗ Portefeuille
✗ Tableau de bord
✗ Factures
✗ Rapprochement
✗ Connecteur
✗ Référence
✗ Rapports
✗ Analytics
✗ Journal d'audit
```

## Sur "Mon Espace" (`/portal`), la PME voit:

### 📊 Statistiques du Dossier
- **Total Factures**: X
- **Rapprochées**: Y ✓
- **En Attente**: Z ⏱
- **Non Rapprochées**: W ✗

### 📄 Historique des 10 Dernières Factures
```
Facture 001  | 1 500,00€ | Rapprochée ✓
Facture 002  | 2 300,00€ | En attente ⏱
Facture 003  | 800,00€   | Non rapprochée ✗
...
```

### 📤 Zone d'Upload
- Drag & Drop de fichiers PDF/Excel
- Ou clic pour sélectionner des fichiers
- Résultat: Factures traitées auto-magiquement

## Sécurité: Ce qu'une PME NE Peut PAS faire

❌ **Ne voit PAS**:
- Les autres dossiers du cabinet
- Les configurations/paramètres
- Les rapprochements (backend)
- Le journal d'audit
- Les factures des autres clients
- Les connecteurs

❌ **Ne peut PAS**:
- Accéder au dashboard principal
- Éditer/créer des dossiers
- Inviter d'autres utilisateurs
- Modifier les paramètres
- Voir les rapports globaux
- Accéder aux analytics

❌ **Impossible Techniquement**:
- Contourner l'UI (API vérifie le rôle)
- Voir les autres dossiers (DB filtre par client_file_id)
- Hack du token (36 chars, expirant, single-use)

## Deux Types de PME

### PME avec permission `read_only`
```
✓ Voir les factures
✓ Télécharger les factures
✓ Voir les statistiques
✗ Uploader des factures
✗ Éditer des factures
```

### PME avec permission `read_write`
```
✓ Voir les factures
✓ Télécharger les factures
✓ Voir les statistiques
✓ Uploader des factures
✓ Éditer/Commenter les factures
```

## Flux de Connexion PME

```
1. PME reçoit email avec lien
   http://localhost:3000/join?token=xyz...

2. PME clique le lien
   ↓
   Page /join avec 3 options:
   a) Créer compte (username/password)
   b) Google
   c) LinkedIn

3. PME s'inscrit/connecte
   ↓
   Backend crée USER (rôle=CLIENT) dans org du cabinet

4. PME redirect → /portal
   ↓
   Voit UNIQUEMENT "Mon Espace"
   Barre latérale masque les autres menus
```

## Table: Admin vs PME vs Comptable

```
Fonctionnalité                Admin    Comptable    PME
────────────────────────────────────────────────────────
Créer dossier                 ✓        ✗           ✗
Modifier dossier              ✓        ✓           ✗
Supprimer dossier             ✓        ✗           ✗
Voir tous les dossiers        ✓        ✓           ✗
Voir son dossier              ✓        ✓           ✓
Inviter PME                   ✓        ✗           ✗
Gérer utilisateurs            ✓        ✗           ✗
Voir factures                 ✓        ✓           ✓
Uploader factures             ✓        ✓           ✓*
Rapprocher factures           ✓        ✓           ✗
Voir rapprochements           ✓        ✓           ✗
Configurer connecteurs        ✓        ✗           ✗
Voir journal d'audit          ✓        ✗           ✗
Voir statistiques             ✓        ✓           ✓
Télécharger données           ✓        ✓           ✓

* Dépend de permission_level
```

## Isolation des Données

**Backend vérifie à chaque requête:**
```python
if user.role == "client":
    # Client peut SEULEMENT accéder son dossier
    if requested_file_id != user.client_file_id:
        return 403 Forbidden  # Accès refusé!
```

**Exemple:**
```
PME1 essaie voir factures de PME2:
GET /api/client/invoices?client_file_id=999

❌ Backend:
{
  "error": "Vous n'avez pas accès à ce dossier",
  "status": 403
}
```

## Cas d'Usage PME Type

### Matin: PME Consulte Stats
```
PME1 se connecte → /portal
  - Voit: Total 50 factures, 48 rapprochées, 2 en attente
  - Consulte les dernières factures
  - Télécharge rapport PDF
```

### Midi: PME Upload Facture
```
PME2 reçoit facture du fournisseur
PME2 → /portal → Zone upload
PME2 Drag & Drop le PDF
  - Système traite la facture auto
  - Facture apparaît dans l'historique
  - Comptable du cabinet la voit en attente de rapprochement
```

### Soir: Admin Gérer PME
```
Admin va Portfolio
  - Voit les 5 PME invitées
  - Peut révoquer accès à l'une d'elles
  - Peut voir qui a uploade quoi
```

## Sécurité Pratique

**PME NE PEUT PAS:**

1. ❌ Accéder `/dashboard` directement
   ```
   Frontend le redirige → /portal
   API le rejette: 403
   ```

2. ❌ Modifier le token pour accéder autre dossier
   ```
   Token est lié à InvitationToken
   InvitationToken est lié à UN dossier
   Impossible de changer
   ```

3. ❌ Réutiliser un token
   ```
   Token marqué "used" après 1ère utilisation
   2e tentative: "Token already used"
   ```

4. ❌ Utiliser un vieux token
   ```
   Token expire 7 jours après création
   Après: "Token expired"
   ```

5. ❌ Inventer un token
   ```
   32 chars random cryptographique
   Chance de deviner: 1 sur 10^48
   ```

## Résumé: PME = Interface Limitée Intentionnelle

✅ Accès contrôlé: 1 dossier seulement
✅ Permissions granulaires: read_only vs read_write
✅ Sécurité: Token expirant, single-use, cryptographique
✅ Isolation: Niveau DB, API, Frontend
✅ UX simple: Menu masque options non disponibles
✅ Audit: Cabinet voit qui upload quoi quand

**C'est par design, pas un bug!** 🔒
