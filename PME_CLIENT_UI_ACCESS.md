# UI d'Accès PME/Client - Vue d'Ensemble

## Accès du Client (PME)

Quand une PME se connecte via le lien d'invitation (ou avec ses identifiants après signup), elle voit une interface **très limitée et spécialisée** comparée aux admins et comptables.

### 1. **Menu Latéral (Sidebar)**

Le client voit **SEULEMENT** un item dans le menu:
```
✓ Mon Espace (client uniquement)
✗ Portefeuille (admin/comptable)
✗ Tableau de bord (admin/comptable)
✗ Factures (admin/comptable)
✗ Rapprochement (admin/comptable)
✗ Connecteur (admin/comptable)
✗ Référence (admin/comptable)
✗ Rapports (admin/comptable)
✗ Analytics (admin/comptable)
✗ Journal d'audit (admin uniquement)
```

### 2. **Page Mon Espace (/portal)**

C'est la **seule page accessible** aux clients. Elle contient:

#### A. **Dashboard Simplifié**
```
┌─────────────────────────────────────────┐
│ Mon Espace - Nom du Dossier             │
└─────────────────────────────────────────┘

📊 Statistiques:
  • Total Factures: X
  • Rapprochées: Y
  • En Attente: Z
  • Non Rapprochées: W

📄 Dernières Factures:
  ├─ Facture 001 - 1 500,00€ - Rapprochée ✓
  ├─ Facture 002 - 2 300,00€ - En attente ⏱
  ├─ Facture 003 - 800,00€ - Non rapprochée ✗
  └─ ...

📤 Upload de Factures:
  └─ Drag & Drop ou Sélectionnez des fichiers
```

#### B. **Fonctionnalités**
- ✅ **Voir les statistiques** du dossier (factures, rapprochements)
- ✅ **Consulter les factures** (lecture seule si permission `read_only`)
- ✅ **Télécharger les factures** (PDF, CSV)
- ✅ **Uploader des factures** (via drag-drop ou file picker)
- ✅ **Voir le statut** des factures (rapprochées, en attente, non rapprochées)
- ❌ **PAS accès** aux configurations
- ❌ **PAS accès** aux rapprochements (backend)
- ❌ **PAS accès** aux connecteurs
- ❌ **PAS accès** aux paramètres
- ❌ **PAS accès** aux autres dossiers

### 3. **Contrôle d'Accès Backend**

Les PME sont protégées par plusieurs mécanismes:

#### **API `/client/summary` (Mon Espace)**
```python
# Clients sont restreints à LEUR dossier uniquement
if role == "client":
    user = session.query(User).get(current_user["id"])
    client_file_id = user.client_file_id  # Auto-set lors du signup
    # PAS d'accès aux autres dossiers
```

#### **API `/client/invoices` (Liste des factures)**
```python
# Fetch uniquement les factures du dossier assigné
invoices = session.query(Invoice).filter(
    Invoice.client_file_id == client_file_id,  # Le dossier du client
    Invoice.organization_id == org_id
)
```

#### **Permissions sur Lecture/Écriture**
```
Permission Level | Can Read | Can Write | Can Edit
─────────────────┼──────────┼───────────┼──────────
read_only        |    ✓     |     ✗     |    ✗
read_write       |    ✓     |     ✓     |    ✓
admin            |    ✓     |     ✓     |    ✓
```

### 4. **Flux de Données pour une PME**

```
┌─────────────────────────────────────────────┐
│  PME clique sur lien d'invitation           │
│  http://localhost:3000/join?token=xyz...    │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│  Page /join - Signup Form                   │
│  - Email (pré-rempli)                       │
│  - Nom                                       │
│  - Nom d'utilisateur                        │
│  - Mot de passe                             │
│  - OU Boutons OAuth (Google/LinkedIn)       │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│  Backend crée:                              │
│  • User (role=CLIENT, org=cabinet)          │
│  • DossierPermission (permission_level)     │
│  Retourne: access_token                     │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│  Frontend redirect → /portfolio             │
│  (grâce à oauth-callback)                   │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│  PME voit SEULEMENT "Mon Espace"            │
│  (la barre latérale cache tout le reste)    │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│  PME navigue sur /portal                    │
│  • Voir stats du dossier                    │
│  • Uploader des factures                    │
│  • Voir l'historique                        │
└─────────────────────────────────────────────┘
```

### 5. **Comparaison: Admin vs PME**

```
Fonctionnalité              Admin    Comptable    PME/Client
────────────────────────────────────────────────────────────
Voir tous les dossiers      ✓        ✓           ✗
Créer dossiers              ✓        ✓           ✗
Éditer dossiers             ✓        ✓           ✗
Supprimer dossiers          ✓        ✗           ✗
Gérer utilisateurs          ✓        ✗           ✗
Inviter PME                 ✓        ✗           ✗
Voir factures               ✓        ✓           ✓ (du sien)
Rapprocher factures         ✓        ✓           ✗
Voir rapprochements         ✓        ✓           ✗
Uploader factures           ✓        ✓           ✓
Voir statistiques           ✓        ✓           ✓ (du sien)
Configurer connecteurs      ✓        ✗           ✗
Voir journal d'audit        ✓        ✗           ✗
Accéder à plusieurs dossiers ✓       ✓           ✗ (1 seul)
```

### 6. **Isolation des Données**

#### **Au niveau Database**
```sql
-- Les PME ne voient QUE leur dossier
SELECT * FROM invoices 
WHERE client_file_id = user.client_file_id  -- Autorisé
  AND organization_id = user.organization_id

-- Tentative d'accès à un autre dossier
SELECT * FROM invoices 
WHERE client_file_id = 999  -- REJETÉ par le backend
  AND organization_id = user.organization_id
```

#### **Au niveau API**
- Chaque requête client vérifie: `user.client_file_id == requested_file_id`
- Si mismatch → 403 Forbidden

#### **Au niveau Frontend**
- Le menu latéral masque tous les items sauf "Mon Espace"
- Les routes directs (ex: `/dashboard`) redirigent vers `/portal`
- Plus efficace + meilleure UX

### 7. **Sécurité & Permissions**

#### **Vérification Multi-niveaux**

```python
# Dans /client_portal.py
def _get_client_file_id(current_user, session):
    role = current_user.get("role")
    if role == "client":
        # Niveau 1: Vérifier le rôle
        user = session.query(User).get(current_user["id"])
        
        # Niveau 2: Vérifier que le user a bien un client_file_id
        if not user or not user.client_file_id:
            raise HTTPException(403, "Aucun dossier associé")
        
        # Niveau 3: Retourner SEULEMENT ce dossier
        return user.client_file_id
```

#### **Permission Levels dans DossierPermission**

```python
# Si PM a permission_level = "read_only":
- PUT /client/invoices → 403 (lecture seule)
- GET /client/invoices → 200 OK

# Si PME a permission_level = "read_write":
- PUT /client/invoices → 200 OK
- GET /client/invoices → 200 OK
```

### 8. **Exemple: Tentative d'Accès Non-Autorisé**

```javascript
// PME essaie d'accéder au dashboard
fetch('/api/invoices/list', {
  headers: { Authorization: `Bearer ${token}` }
})

// ❌ Backend répond:
{
  "detail": "Admin requis",
  "status_code": 403
}

// Le composant Dashboard.js filtre aussi:
if (user?.role !== 'admin' && user?.role !== 'accountant') {
  return <Redirect to="/portal" />
}
```

## Résumé: Qu'est-ce qu'une PME Peut Faire?

✅ **PEUT:**
- Se connecter avec ses identifiants
- Voir les stats de son dossier (total factures, rapprochées, etc)
- Consulter la liste de ses factures
- Uploader des factures
- Voir le statut des factures (rapprochée, en attente, non rapprochée)
- Télécharger les données
- Se déconnecter

❌ **NE PEUT PAS:**
- Voir d'autres dossiers
- Accéder au dashboard principal
- Voir les rapprochements (backend)
- Configurer les connecteurs
- Accéder aux paramètres
- Voir le journal d'audit
- Gérer les utilisateurs
- Créer/éditer des dossiers
- Utiliser les rapports/analytics
- Accéder aux endpoints admin

## Notes sur les Permissions `read_only` vs `read_write`

Actuellement, l'implémentation PME utilise surtout **l'upload** et **la lecture**.

Cas d'usage pour différences:
- **read_only**: PME peut voir les factures, télécharger, mais PAS uploader
- **read_write**: PME peut voir, télécharger ET uploader des factures

Cela se concrétise par:
```python
# Dans client_portal.py - /upload endpoint
if permission_level == "read_only":
    raise HTTPException(403, "Permission insuffisante")

if permission_level == "read_write":
    # Allow upload
```

## Évolution Future

Possibilités pour améliorer l'accès PME:
1. **Dashboard PME amélioré** - Plus de visualisations/statistiques
2. **Communication bidirectionnelle** - Messagerie entre PME et cabinet
3. **Notifications** - Alertes si factures non rapprochées
4. **Export personnalisé** - Rapports spécifiques PME
5. **QR codes** - Scanner pour factures physiques
6. **Mobile app** - Interface simplifiée mobile
