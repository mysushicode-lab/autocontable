# 🔐 Plan Sécurité PME Multi-Org

## Problème Critique Identifié

```
Modèle actuel:
email: unique=True GLOBALEMENT

❌ PME3@example.com chez Cabinet A
   → email existe déjà
   → PME3 NE PEUT PAS rejoindre Cabinet B avec même email
   
❌ Pas de solution pour "changer de cabinet"
❌ Email bloqué globalement
```

## Solution: Isolation Stricte par Org

### 1. **Modifier la Contrainte Email**

**AVANT:**
```python
class User:
    email = Column(String(100), nullable=True, unique=True, index=True)
    # ❌ Unique globalement
```

**APRÈS:**
```python
class User:
    email = Column(String(100), nullable=True, index=True)  # ← Pas unique
    organization_id = Column(Integer, ForeignKey('organizations.id'), nullable=False)
    
    # ✅ Unique constraint: (email, organization_id) ensemble
    __table_args__ = (
        UniqueConstraint('email', 'organization_id', name='uq_user_email_org'),
    )
```

**Résultat:**
- ✅ PME3@example.com peut exister dans Cabinet A ET Cabinet B
- ✅ Dans Cabinet A: PME3 + pme3@example.com + org_A
- ✅ Dans Cabinet B: PME3 + pme3@example.com + org_B
- ✅ MAIS pas 2 PME3@example.com dans MÊME cabinet

### 2. **Filtrages Stricts Partout**

```python
# ❌ AVANT (DANGEREUX):
user = session.query(User).filter(User.email == "pme@example.com").first()
# Peut retourner n'importe quel PME@example.com de n'importe quelle org

# ✅ APRÈS (SÉCURISÉ):
user = session.query(User).filter(
    User.email == "pme@example.com",
    User.organization_id == current_org_id  # ← TOUJOURS inclure org
).first()
```

### 3. **Vérifications Requises**

Tous les endpoints doivent vérifier:
```python
user.organization_id == current_user["organization_id"]
```

Sinon: 403 Forbidden

### 4. **Scénario: PME Rejoint 2 Cabinets**

**Timeline:**
```
T1: PME3 crée compte Cabinet A
    ├─ Email: pme3@example.com
    ├─ Org: Cabinet A
    ├─ Role: client
    └─ ClientFileId: Dossier A

T2: Admin Cabinet B invite PME3@example.com
    ├─ Crée InvitationToken (org=B, invited_email=pme3@example.com)
    ├─ PME3 reçoit lien (token=xyz)
    └─ PME3 clique lien /join?token=xyz

T3: PME3 sur /join
    ├─ Peut utiliser MÊME email (pme3@example.com)
    ├─ Crée nouveau User:
    │  ├─ Email: pme3@example.com ✓ (different org, OK)
    │  ├─ Org: Cabinet B ✓
    │  ├─ Role: client
    │  └─ ClientFileId: Dossier B
    └─ Maintenant PME3 a 2 comptes

T4: PME3 accède
    ├─ Cabinet A login: pme3@example.com → User(org_A, role=client)
    ├─ Cabinet B login: pme3@example.com → User(org_B, role=client)
    ├─ Impossible d'accéder aux 2 en même temps
    └─ Chaque session = une seule org
```

### 5. **Checkpoints de Sécurité**

#### A. Login
```python
def login(username, password):
    user = session.query(User).filter(User.username == username).first()
    # ✓ Username unique globalement (OK)
    # ✓ Pas besoin de org (username = unique key)
    
    # Mais si login par email:
    # ❌ DANGEREUX: User.email == email
    # ✅ SÉCURISÉ: Pas de login par email globally
```

#### B. Create User (Invitation)
```python
# ✅ CORRECT:
def join_from_invitation(token, username, password, name):
    invitation = session.query(InvitationToken).filter(
        InvitationToken.token == token,
        InvitationToken.used_at.is_(None),
        InvitationToken.expires_at > now()
    ).first()
    
    org_id = invitation.organization_id  # ← Org vient du token
    
    # Vérifier email pas déjà dans CETTE org
    existing = session.query(User).filter(
        User.email == invited_email,
        User.organization_id == org_id  # ← CLAU CLAU!
    ).first()
    
    if existing:
        raise 400 "Email déjà utilisé dans cette org"
    
    # Créer nouveau user dans cette org
    user = User(
        email=invited_email,
        organization_id=org_id,  # ← Lié à org
        role=CLIENT
    )
```

#### C. Get User Data
```python
# ❌ DANGEREUX:
def get_user_profile(user_id):
    user = session.query(User).get(user_id)
    return user

# ✅ SÉCURISÉ:
def get_user_profile(user_id, current_user):
    user = session.query(User).filter(
        User.id == user_id,
        User.organization_id == current_user["organization_id"]  # ← ALWAYS!
    ).first()
    
    if not user:
        raise 403 "Utilisateur introuvable"
    
    return user
```

#### D. Update User
```python
# ❌ DANGEREUX:
def update_user(user_id, name):
    user = session.query(User).get(user_id)
    user.name = name
    session.commit()

# ✅ SÉCURISÉ:
def update_user(user_id, name, current_user):
    user = session.query(User).filter(
        User.id == user_id,
        User.organization_id == current_user["organization_id"]
    ).first()
    
    if not user:
        raise 403
    
    user.name = name
    session.commit()
```

### 6. **Checklist Implémentation**

- [ ] Modifier User model: email unique par org (pas globalement)
- [ ] Migration DB: créer contrainte UniqueConstraint(email, org_id)
- [ ] Audit ALL endpoints: ajouter org_id verification
- [ ] Test: PME avec 2 orgs (création OK, login OK, accès filtré)
- [ ] Test: Impossible d'accéder à user d'autre org
- [ ] Test: Impossible d'accéder à dossier d'autre org
- [ ] Documentation: Comment PME rejoint 2nd org

### 7. **Endpoints à Vérifier**

```
Auth:
  /register          ← Force org de user (création)
  /login             ← OK (username unique globalement)
  /join-from-invitation ← ✅ Already org-specific
  /oauth callbacks   ← Must force org
  /change-email      ← Must verify not in SAME org
  /change-username   ← OK (global unique)

Users:
  GET /users         ← Only users in CURRENT org
  GET /users/:id     ← Verify belongs to org
  PUT /users/:id     ← Verify belongs to org
  DELETE /users/:id  ← Verify belongs to org

Permissions:
  GET /dossier/:id   ← Verify dossier in org
  POST /grant        ← Verify all in org
  POST /invite       ← ✅ Already org-specific
  POST /revoke       ← Verify all in org

Data (invoices, etc):
  GET /invoices      ← Filter by org_id
  POST /invoices     ← Force org_id
  GET /dossiers      ← Filter by org_id
  GET /analytics     ← Filter by org_id
```

### 8. **Exemple Test**

```python
# Test: PME joins 2 orgs with same email
def test_pme_multiple_orgs():
    # Cabinet A
    token_a = create_invitation("pme@example.com", Cabinet A)
    pme_a = join_from_invitation(token_a, "pme", "pass", "PME")
    assert pme_a.email == "pme@example.com"
    assert pme_a.organization_id == Cabinet_A.id
    
    # Cabinet B (DIFFERENT ORG)
    token_b = create_invitation("pme@example.com", Cabinet B)
    pme_b = join_from_invitation(token_b, "pme_2", "pass", "PME")
    assert pme_b.email == "pme@example.com"
    assert pme_b.organization_id == Cabinet_B.id
    
    # Deux comptes différents, même email, ORG différentes ✓
    assert pme_a.id != pme_b.id
    
    # PME_A ne peut PAS accéder données B
    invoices_a = get_invoices(pme_a)  # ✓ Voit factures A
    invoices_b = get_invoices(pme_b)  # ✓ Voit factures B
    assert invoices_a != invoices_b
```

### 9. **Migration DB Nécessaire**

```sql
-- Avant: email unique globalement
ALTER TABLE users DROP CONSTRAINT users_email_key;

-- Après: unique (email, organization_id)
ALTER TABLE users ADD CONSTRAINT uq_user_email_org 
  UNIQUE (email, organization_id);

-- Vérifier que pas 2 users même email même org
DELETE FROM users u1 
WHERE EXISTS (
  SELECT 1 FROM users u2 
  WHERE u1.email = u2.email 
  AND u1.organization_id = u2.organization_id
  AND u1.id > u2.id
);
```

### 10. **Résumé Sécurité**

```
AVANT (❌ DANGEREUX):
├─ Email unique globalement
├─ PME ne peut PAS rejoindre 2 orgs
├─ Endpoints supposent org implicite
└─ Accès cross-org possible

APRÈS (✅ SÉCURISÉ):
├─ Email unique par org seulement
├─ PME peut créer compte dans 2 orgs
├─ Invitation token = org-specific
├─ Tous endpoints vérifient org_id
└─ Cross-org access = 403 Forbidden
```

## Action Items

1. **FIX MODEL**: Modifier User.email constraint
2. **FIX ENDPOINTS**: Ajouter org_id checks partout
3. **TEST**: Vérifier isolation org stricte
4. **MIGRATION**: Créer script DB
5. **DOCUMENT**: Expliquer multi-org pour PME
