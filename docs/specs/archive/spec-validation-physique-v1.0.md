# Spec — Validation physique des comptes lecteur·rice

**Statut** : Cadrée le 03/05/2026, en attente d'implémentation
**Cible** : Bologna FICEDL, septembre 2026
**Auteur·rices** : Xavier (spec et arbitrages) + Claude (rédaction)

---

## Sommaire

1. [Contexte et objectif](#1-contexte-et-objectif)
2. [Modèle conceptuel](#2-modèle-conceptuel)
3. [Schéma DB](#3-schéma-db)
4. [Helpers RLS](#4-helpers-rls)
5. [Workflows](#5-workflows)
6. [Notifications mail](#6-notifications-mail)
7. [Affichage de la règle](#7-affichage-de-la-règle)
8. [Migration de l'existant](#8-migration-de-lexistant)
9. [Cas particuliers](#9-cas-particuliers)
10. [Checklist d'implémentation](#10-checklist-dimplémentation)
11. [Tests d'acceptation](#11-tests-dacceptation)

---

## 1. Contexte et objectif

### Contexte

AnarBib est une plateforme SIGB qui accueille un réseau de bibliothèques militantes anarchistes. Toute personne peut s'inscrire en ligne sur le SIGB en choisissant une bibliothèque d'attache, ce qui crée un compte lecteur·rice.

Sans précaution supplémentaire, ce mécanisme permet à n'importe quel·le visiteur·euse, y compris des intrus·es potentiel·les (services de renseignement, militant·es de l'extrême droite, journalistes mal intentionné·es, etc.), d'accéder aux catalogues des bibliothèques du réseau, ce qui peut révéler des informations sensibles sur les pratiques de lecture militante d'un mouvement.

### Objectif

Permettre à chaque bibliothèque de **choisir son mode d'accueil** :

- **Mode `open`** : confiance par défaut. Une fois le compte créé et l'email confirmé, le lecteur·rice a accès aux catalogues public et réseau. C'est le mode adapté aux bibliothèques publiques/peu exposées.

- **Mode `manual_validation`** : sécurité par défaut. Le compte est créé en ligne mais reste « en attente » jusqu'à une **rencontre physique** entre le lecteur·rice et un·e bibliothécaire de la biblio d'inscription. C'est le mode adapté aux bibliothèques exposées (locaux fragiles, contexte politique tendu, fonds sensibles).

La **validation physique faite par une biblio vaut pour tout le réseau AnarBib** : un lecteur·rice validé·e à BLMF peut accéder aux catalogues de toutes les biblios `network` d'AnarBib, sans avoir à se présenter physiquement à chacune d'entre elles. Le pacte de circulation est implicite entre biblios du réseau qui se reconnaissent mutuellement.

### Principe directeur

> Sécurité par défaut, ouverture sur choix explicite, transparence pour le user.

---

## 2. Modèle conceptuel

### États possibles d'un compte

Un compte lecteur·rice peut être dans 4 états, déterminés par 3 attributs orthogonaux :

| Email confirmé | `physically_validated_at` | `is_restricted` | État global | Accès |
|---|---|---|---|---|
| ❌ | quelconque | quelconque | **Email non confirmé** | Écran bloquant |
| ✅ | NULL | false | **En attente de validation** | Écran d'attente, pas de navigation lecteur |
| ✅ | NOT NULL | false | **Actif** | Accès complet selon mode/visibilité |
| ✅ | NOT NULL | true | **Suspendu** | Lecture seule, actions désactivées |

### Sémantique de visibilité

Pour un compte donné, la visibilité du catalogue d'une bibliothèque dépend du `visibility_level` de cette bibliothèque :

| visibility_level | Anonyme | User non-validé | User validé |
|---|---|---|---|
| `public` | ✅ | ✅ | ✅ |
| `network` | ❌ | ❌ | ✅ |
| `private` | ❌ | ✅ ssi membre | ✅ ssi membre |

**Note importante** : un user en attente (non encore validé) inscrit dans une biblio `private` n'a même pas accès à sa propre biblio. C'est cohérent — la biblio `private` ne souhaite pas exposer ses contenus tant qu'elle n'a pas validé physiquement.

### Modes de la biblio

Chaque bibliothèque a un attribut `network_access_mode` ∈ {`open`, `manual_validation`} :

- **`open`** : auto-validation à l'inscription. À la création du compte, `physically_validated_at = NOW()` est posé automatiquement par trigger. Aucune action humaine requise.

- **`manual_validation`** : validation déclenchée explicitement par un·e bibliothécaire (`librarian` ou plus) lors de la rencontre physique. `physically_validated_at` reste `NULL` jusqu'à cette action.

Le mode peut être **changé à tout moment** par le coordenador (ou plus haut). Le changement n'invalide pas les validations existantes (rétro-compatibilité).

### Hiérarchie des rôles concernés

| Rôle | Action sur validation physique |
|---|---|
| `reader` | Aucune (cible de l'action) |
| `librarian` | Peut valider, peut révoquer |
| `coordenador` | Peut valider, peut révoquer, peut changer le mode de la biblio |
| `administrador` (AnarBib) | Toutes les actions |

---

## 3. Schéma DB

### Modifications à `public.profiles`

Trois nouvelles colonnes :

```sql
ALTER TABLE public.profiles
  ADD COLUMN physically_validated_at timestamptz NULL,
  ADD COLUMN physically_validated_by_user_id uuid NULL REFERENCES public.profiles(id),
  ADD COLUMN physical_validation_note text NULL;

COMMENT ON COLUMN public.profiles.physically_validated_at IS
  'Date de validation physique du compte. NULL = en attente. Posée automatiquement à l''inscription si la biblio est en mode open, posée manuellement par un·e librarian+ en mode manual_validation.';

COMMENT ON COLUMN public.profiles.physically_validated_by_user_id IS
  'User qui a effectué la validation. NULL pour validation automatique (mode open) ou auto-migration de l''existant. NOT NULL pour validation manuelle.';

COMMENT ON COLUMN public.profiles.physical_validation_note IS
  'Note libre saisie par le librarian au moment de la validation (contexte, lieu, particularités). Optionnel.';
```

### Modifications à `public.libraries`

Une nouvelle colonne :

```sql
ALTER TABLE public.libraries
  ADD COLUMN network_access_mode text NOT NULL DEFAULT 'manual_validation' 
    CHECK (network_access_mode IN ('open', 'manual_validation')),
  ADD COLUMN access_rule_text_override text NULL;

COMMENT ON COLUMN public.libraries.network_access_mode IS
  'Mode d''accueil des nouveaux comptes : open = auto-validation à l''inscription, manual_validation = validation physique requise par un·e librarian+ avant accès au réseau.';

COMMENT ON COLUMN public.libraries.access_rule_text_override IS
  'Texte personnalisé décrivant la politique d''accès de la biblio. Si NULL, le texte par défaut généré par AnarBib selon le mode est utilisé. Permet d''ajouter horaires, contexte, précisions.';
```

**Note** : `DEFAULT 'manual_validation'` pour les NOUVELLES biblios (sécurité par défaut). Les biblios existantes auront leur valeur posée à `'open'` par la migration de l'existant (cf. section 8).

### Nouvelle table d'audit `public.profile_validation_log`

Pour conserver l'historique des validations et révocations :

```sql
CREATE TABLE public.profile_validation_log (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  action text NOT NULL CHECK (action IN ('validated', 'revoked', 'auto_validated', 'migrated_grandfather')),
  performed_by_user_id uuid NULL REFERENCES public.profiles(id),
  reason text NULL,
  note text NULL,
  performed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_profile_validation_log_user_id ON public.profile_validation_log(user_id);
CREATE INDEX idx_profile_validation_log_performed_at ON public.profile_validation_log(performed_at DESC);

COMMENT ON TABLE public.profile_validation_log IS
  'Journal d''audit de toutes les actions de validation/révocation physique sur les comptes. Conservé même après suppression des comptes pour traçabilité (mais purgé si user_id supprimé via CASCADE — à reconsidérer si besoin RGPD plus strict).';
```

**Action codes** :
- `validated` : validation manuelle par un·e librarian+
- `revoked` : révocation par un·e librarian+ (raison obligatoire)
- `auto_validated` : auto-validation à l'inscription en mode `open`
- `migrated_grandfather` : validation automatique des comptes existants lors du déploiement initial de la feature

### Trigger d'auto-validation à l'inscription

```sql
CREATE OR REPLACE FUNCTION public.fn_auto_validate_on_open_signup()
RETURNS TRIGGER AS $$
DECLARE
  v_mode text;
BEGIN
  -- Récupérer le mode de la biblio d'inscription
  SELECT network_access_mode INTO v_mode
  FROM public.libraries
  WHERE id = NEW.default_library_id;

  -- En mode open, auto-validation
  IF v_mode = 'open' THEN
    NEW.physically_validated_at := NOW();
    NEW.physically_validated_by_user_id := NULL; -- automatique = pas d'auteur
    
    -- Log l'action (sera fait après INSERT via un trigger AFTER, voir plus bas)
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_auto_validate_on_open_signup
BEFORE INSERT ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.fn_auto_validate_on_open_signup();
```

Et un trigger AFTER pour journaliser :

```sql
CREATE OR REPLACE FUNCTION public.fn_log_auto_validation()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.physically_validated_at IS NOT NULL AND NEW.physically_validated_by_user_id IS NULL THEN
    INSERT INTO public.profile_validation_log(user_id, action, performed_at)
    VALUES (NEW.id, 'auto_validated', NEW.physically_validated_at);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_log_auto_validation
AFTER INSERT ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.fn_log_auto_validation();
```

### Contraintes d'intégrité

```sql
-- Cohérence : si physically_validated_by_user_id NOT NULL, alors physically_validated_at NOT NULL
ALTER TABLE public.profiles
  ADD CONSTRAINT chk_validation_consistency 
  CHECK (
    (physically_validated_by_user_id IS NULL) 
    OR (physically_validated_at IS NOT NULL)
  );
```

---

## 4. Helpers RLS

### Mise à jour de `fn_current_user_is_in_network()`

L'helper existant écrit le 02/05/2026 doit être enrichi :

```sql
CREATE OR REPLACE FUNCTION public.fn_current_user_is_in_network()
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    INNER JOIN public.user_library_memberships ulm ON ulm.user_id = p.id
    WHERE p.id = auth.uid()
      AND p.physically_validated_at IS NOT NULL  -- nouveau check
      AND ulm.is_active = true
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;
```

**Sémantique** : un user est considéré « membre du réseau » si **et seulement si** son compte a été validé physiquement (par sa biblio en mode `manual_validation`, ou auto-validé en mode `open`) ET qu'il a au moins une membership active.

### Nouveau helper : `fn_current_user_is_pending()`

Utile pour le frontend qui doit afficher l'écran d'attente :

```sql
CREATE OR REPLACE FUNCTION public.fn_current_user_is_pending()
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.physically_validated_at IS NULL
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;
```

### Mise à jour de `fn_library_visible_to_caller(uuid)`

Pour cohérence, mais peu de changement :

```sql
CREATE OR REPLACE FUNCTION public.fn_library_visible_to_caller(p_library_id uuid)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.libraries l
    WHERE l.id = p_library_id
      AND l.is_active = true
      AND (
        l.visibility_level = 'public'
        OR (l.visibility_level = 'network' AND public.fn_current_user_is_in_network())
        OR (l.visibility_level = 'private' AND public.fn_current_user_is_member_of(l.id))
      )
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;
```

Pas de changement structurel — juste que `fn_current_user_is_in_network()` retourne maintenant `false` pour les users non-validés, ce qui les exclut des biblios `network`. Symétrie maintenue.

### Nouveau check : `fn_current_user_is_member_of()` requiert validation ?

Question subtile : un user en attente, membre d'une biblio `private`, voit-il les contenus de SA biblio `private` ?

Spec retenue (cf. section 2) : **non**. Tant que pas validé, accès limité au catalogue public. Donc :

```sql
CREATE OR REPLACE FUNCTION public.fn_current_user_is_member_of(p_library_id uuid)
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    INNER JOIN public.user_library_memberships ulm ON ulm.user_id = p.id
    WHERE p.id = auth.uid()
      AND p.physically_validated_at IS NOT NULL  -- nouveau check
      AND ulm.is_active = true
      AND ulm.library_id = p_library_id
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER;
```

---

## 5. Workflows

### Workflow A — Inscription d'un nouveau compte (mode `open`)

```
1. User va sur /criar-conta
2. Sélectionne biblio (BLMF, en mode open)
3. Voit la règle d'accès affichée : "Accès immédiat après confirmation de l'email"
4. Saisit ses informations (email, mot de passe, identité)
5. Clic Submit
   → Trigger BEFORE INSERT pose physically_validated_at = NOW()
   → Trigger AFTER INSERT log 'auto_validated'
6. Mail Supabase Auth de confirmation envoyé
7. Mail AnarBib "Bienvenue à BLMF" envoyé (variante mode open)
8. User clique le lien de confirmation dans l'email
9. Email confirmé → user peut se connecter
10. Connexion → accès complet au catalogue public + BLMF + réseau
```

### Workflow B — Inscription d'un nouveau compte (mode `manual_validation`)

```
1. User va sur /criar-conta
2. Sélectionne biblio (BLMF, en mode manual_validation)
3. Voit la règle d'accès affichée : "Compte créé puis validation à effectuer en personne"
4. Saisit ses informations
5. Clic Submit
   → Pas de trigger d'auto-validation (physically_validated_at reste NULL)
6. Mail Supabase Auth de confirmation envoyé
7. Mail AnarBib "Bienvenue à BLMF — compte en attente de validation" envoyé
   (variante mode manual_validation, avec instructions : adresse, horaires si dans manifeste)
8. User clique le lien de confirmation dans l'email
9. Email confirmé → user peut se connecter
10. Connexion → écran d'attente : "Ton compte est en attente de validation par BLMF.
    Viens nous rencontrer à [adresse] [horaires]. À bientôt !"
11. (Plus tard) User vient à la biblio
12. Librarian BLMF se connecte, va dans /painel onglet "Comptes en attente"
13. Voit la fiche du user, clique "Valider physiquement"
14. Modal de confirmation avec champ note optionnel
15. Confirme
    → physically_validated_at = NOW()
    → physically_validated_by_user_id = id du librarian
    → physical_validation_note = note saisie (ou NULL)
    → Insert dans profile_validation_log avec action='validated'
16. Mail AnarBib "Ton compte est validé" envoyé
17. User se reconnecte → accès complet
```

### Workflow C — Révocation d'une validation

```
1. Librarian découvre une raison de révoquer (erreur d'identité, fraude, etc.)
2. Va sur la fiche du user dans /painel ou /biblioteca
3. Clique "Révoquer la validation"
4. Modal avec champ raison OBLIGATOIRE + note optionnelle
5. Confirme
   → physically_validated_at = NULL
   → physically_validated_by_user_id reset à NULL
   → physical_validation_note reset à NULL
   → Insert dans profile_validation_log avec action='revoked', reason=raison saisie
6. Mail AnarBib "Ton accès a été révoqué" envoyé au user (avec raison transmise)
7. User à sa prochaine connexion → écran d'attente
```

### Workflow D — Changement de mode de la biblio

```
1. Coordenador BLMF va dans /biblioteca onglet "Paramètres généraux"
2. Voit le toggle "Mode d'accueil" : open ↔ manual_validation
3. Bascule
4. Modal de confirmation : 
   "Cette action change la politique d'accès au catalogue de [Biblio].
    Les comptes déjà validés conservent leur statut.
    Les futures inscriptions suivront le nouveau mode.
    Confirmer ?"
5. Confirme
   → libraries.network_access_mode mis à jour
6. (Optionnel) Mise à jour automatique du texte de règle visible publiquement (si pas d'override)
```

---

## 6. Notifications mail

### 4 nouveaux templates de mail

À ajouter à `mail-strings.ts` (cf. session du 02/05/2026 sur l'audit i18n).

| Clé | Déclencheur | Audience |
|---|---|---|
| `welcome.openMode.*` | Inscription en biblio mode `open` | User |
| `welcome.manualMode.*` | Inscription en biblio mode `manual_validation` | User |
| `validation.confirmed.*` | Validation manuelle par un·e librarian | User |
| `validation.revoked.*` | Révocation d'une validation | User |

### Clés à ajouter dans `mail-strings.ts`

Soit ~16 clés × 6 locales = **~96 traductions militantes** :

```
welcome.openMode.sub          → Sujet
welcome.openMode.intro        → Salutation/intro
welcome.openMode.body         → Corps explicatif
welcome.openMode.cta          → Phrase d'invitation
welcome.manualMode.sub
welcome.manualMode.intro
welcome.manualMode.body
welcome.manualMode.cta
validation.confirmed.sub
validation.confirmed.intro
validation.confirmed.body
validation.confirmed.cta
validation.revoked.sub
validation.revoked.intro
validation.revoked.body
validation.revoked.reasonLabel  → Label "Raison" pour afficher la raison transmise
```

### Exemples de contenu (pt-BR)

**`welcome.openMode.sub`** : `Bem-vinde à {libraryName}!`
**`welcome.openMode.intro`** : `Olá, {firstName}!`
**`welcome.openMode.body`** : `Sua conta foi criada com sucesso. Você já pode explorar o catálogo de {libraryName} e o catálogo do réseau AnarBib.`
**`welcome.openMode.cta`** : `Acesse sua conta para começar.`

**`welcome.manualMode.sub`** : `Bem-vinde à {libraryName} — conta em validação`
**`welcome.manualMode.intro`** : `Olá, {firstName}!`
**`welcome.manualMode.body`** : `Sua conta foi criada na biblioteca {libraryName}. Para finalizar a inscrição e ter acesso ao catálogo do réseau, é necessário um encontro presencial com un·a bibliotecárie.`
**`welcome.manualMode.cta`** : `Venha nos visitar em {libraryAddress} {libraryHoursIfAvailable}.`

**`validation.confirmed.sub`** : `Sua conta foi validada!`
**`validation.confirmed.intro`** : `Olá, {firstName}!`
**`validation.confirmed.body`** : `A {libraryName} validou sua conta. Você agora tem acesso completo ao catálogo do réseau AnarBib.`
**`validation.confirmed.cta`** : `Boa leitura!`

**`validation.revoked.sub`** : `Acesso revogado`
**`validation.revoked.intro`** : `Olá, {firstName}.`
**`validation.revoked.body`** : `A validação da sua conta na biblioteca {libraryName} foi revogada.`
**`validation.revoked.reasonLabel`** : `Motivo: {reason}`
**`validation.revoked.cta`** : `Entre em contato com a biblioteca para mais informações.`

(Les autres locales suivent les conventions militantes de la charte AnarBib : tutoiement fr, point médian, neutre argentin es, Genderstern de, jamais camerata it, jamais Compas non traduit de.)

---

## 7. Affichage de la règle

### Onglet "Paramètres généraux" de `/biblioteca`

Pour le **coordenador** seulement, accessible en édition :

```
┌─ Mode d'accueil ─────────────────────────────────────┐
│                                                      │
│ ○ Ouvert                                             │
│   Toute personne qui s'inscrit en ligne accède       │
│   immédiatement au catalogue (public + réseau).      │
│                                                      │
│ ● Validation manuelle                                │
│   Une rencontre physique avec un·e bibliothécaire    │
│   est requise pour donner accès au catalogue réseau. │
│                                                      │
│ [ Sauvegarder ]                                      │
└──────────────────────────────────────────────────────┘
```

### Onglet "Règlement et circulation" de `/biblioteca`

Pour le **coordenador**, vue éditable :

```
┌─ Politique d'accès au catalogue ────────────────────┐
│                                                      │
│ Texte par défaut (selon votre mode) :                │
│ ┌──────────────────────────────────────────────────┐ │
│ │ À BLMF, l'inscription en ligne crée un compte    │ │
│ │ qui devra être validé lors d'une rencontre       │ │
│ │ physique avec un·e bibliothécaire avant d'avoir  │ │
│ │ accès aux catalogues du réseau AnarBib.          │ │
│ └──────────────────────────────────────────────────┘ │
│                                                      │
│ Personnaliser ce texte :                             │
│ ┌──────────────────────────────────────────────────┐ │
│ │ [ Champ libre, vide par défaut ]                 │ │
│ └──────────────────────────────────────────────────┘ │
│                                                      │
│ [ Sauvegarder ]                                      │
└──────────────────────────────────────────────────────┘
```

Si le champ libre est vide → texte par défaut affiché publiquement.
Si le champ libre est rempli → ce texte remplace le défaut.

### Affichage public de la règle

**Sur la page d'accueil de la biblio** (`/biblioteca/blmf` ou similaire), section permanente :

```
┌─ Politique d'accueil ────────────────────────────────┐
│                                                      │
│ [Texte de la règle, default ou personnalisé]         │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**Sur `/criar-conta`**, après sélection de la biblio :

```
┌─ Tu t'inscris à BLMF ────────────────────────────────┐
│                                                      │
│ ⚠ Cette bibliothèque demande une validation          │
│ physique avant l'accès au catalogue réseau :         │
│                                                      │
│ [Texte de la règle]                                  │
│                                                      │
│ En continuant, tu acceptes ce mode de fonctionnement.│
│                                                      │
│ [ Continuer ] [ Choisir une autre bibliothèque ]    │
└──────────────────────────────────────────────────────┘
```

### Textes par défaut par mode et locale

À traduire dans les 6 locales en suivant les conventions militantes.

**Mode `open` — pt-BR** : `Em {libraryName}, você pode se inscrever online e acessar imediatamente o catálogo do réseau AnarBib. Não há validação presencial necessária.`

**Mode `manual_validation` — pt-BR** : `Em {libraryName}, a inscrição online cria uma conta com acesso ao catálogo público apenas. Para acessar o catálogo do réseau (outras bibliotecas libertárias do AnarBib), é necessário um encontro presencial com un·a bibliotecárie de {libraryName}.`

(idem fr, es, en, it, de selon conventions de la charte i18n d'AnarBib)

---

## 8. Migration de l'existant

### Ordre de déploiement

1. **Phase préparation (non-breaking)** : ajout des nouvelles colonnes/tables avec valeurs par défaut sûres
2. **Phase grandfathering** : marquage des comptes existants comme validés
3. **Phase mode** : choix du mode pour les biblios existantes
4. **Phase activation** : helpers RLS mis à jour

### Migration SQL

```sql
BEGIN;

-- 1. Ajouter les colonnes (mode par défaut = manual_validation pour NOUVELLES biblios)
ALTER TABLE public.libraries
  ADD COLUMN network_access_mode text NOT NULL DEFAULT 'manual_validation' 
    CHECK (network_access_mode IN ('open', 'manual_validation')),
  ADD COLUMN access_rule_text_override text NULL;

ALTER TABLE public.profiles
  ADD COLUMN physically_validated_at timestamptz NULL,
  ADD COLUMN physically_validated_by_user_id uuid NULL REFERENCES public.profiles(id),
  ADD COLUMN physical_validation_note text NULL;

-- 2. Conserver le mode 'open' implicite des biblios existantes
UPDATE public.libraries SET network_access_mode = 'open';
-- (Toutes les biblios déjà existantes basculent en open par défaut, car
-- elles fonctionnaient déjà en confiance avant la feature.)

-- 3. Grandfathering des comptes existants
UPDATE public.profiles 
SET physically_validated_at = NOW(),
    physically_validated_by_user_id = NULL  -- migration automatique = pas d'auteur
WHERE physically_validated_at IS NULL;

-- 4. Logger toutes les migrations grandfather
INSERT INTO public.profile_validation_log(user_id, action, performed_at)
SELECT id, 'migrated_grandfather', NOW()
FROM public.profiles;

-- 5. Création des triggers et helpers (cf. sections 3 et 4)
-- ...

-- 6. Mise à jour des helpers RLS (cf. section 4)
-- ...

COMMIT;
```

### Communication aux biblios existantes

Une fois le déploiement effectué :
- **Mail** envoyé aux coordenadores BLMF / BTL / FRT pour les informer de la nouvelle feature
- Lien vers documentation expliquant comment basculer en `manual_validation` si souhaité
- Mention que les comptes existants ne sont pas affectés

---

## 9. Cas particuliers

### 9.1 — Biblio qui devient inactive

Voir la spec migration de compte (à venir). En résumé : les comptes en attente d'une biblio inactive doivent pouvoir être transférés vers une autre biblio active.

### 9.2 — User suspendu (`is_restricted = true`) déjà validé

La suspension est **orthogonale** à la validation. Un user suspendu reste validé, mais ne peut pas effectuer d'actions (réservation, emprunt). La suspension peut être levée sans toucher à `physically_validated_at`.

### 9.3 — User qui change d'email

Sans impact sur `physically_validated_at`. La validation porte sur l'identité de la personne, pas sur son email.

### 9.4 — Coordenador qui valide son propre compte

Cas marginal mais possible. À gérer comme une action standard, mais idéalement journalisée avec une note "auto-validation par coordenador" pour audit.

### 9.5 — Biblio qui passe de `manual_validation` à `open`

**Effet** : les nouveaux comptes seront auto-validés. Les comptes en attente existants restent en attente jusqu'à action manuelle d'un librarian. Le coordenador peut faire une **action en lot** "valider tous les comptes en attente" si souhaité (à confirmer dans l'implémentation).

### 9.6 — Biblio qui passe de `open` à `manual_validation`

**Effet** : les nouveaux comptes nécessiteront validation manuelle. Les comptes déjà validés (auto ou manuel) ne sont pas affectés. Pas d'invalidation rétroactive.

### 9.7 — Validation d'un user pas encore connecté (jamais venu sur le SIGB après inscription)

Pas de blocage. Le librarian peut valider un user en attente même si ce user ne s'est pas reconnecté depuis l'inscription. À sa prochaine connexion, il aura accès direct sans écran d'attente.

---

## 10. Checklist d'implémentation

### Phase 1 — Schéma DB (1-2h)

- [ ] Migration SQL `2026_05_XX_validation_physique_schema.sql`
  - [ ] ALTER TABLE profiles : 3 colonnes
  - [ ] ALTER TABLE libraries : 2 colonnes
  - [ ] CREATE TABLE profile_validation_log
  - [ ] Trigger BEFORE INSERT auto-validation
  - [ ] Trigger AFTER INSERT log auto-validation
  - [ ] Contrainte chk_validation_consistency
- [ ] Migration de l'existant (cf. section 8)
- [ ] Tests SQL : insertions de test pour valider les triggers

### Phase 2 — Helpers RLS (30 min)

- [ ] Mise à jour `fn_current_user_is_in_network()` (vérifier validation)
- [ ] Création `fn_current_user_is_pending()`
- [ ] Mise à jour `fn_current_user_is_member_of()` (vérifier validation)
- [ ] Tests : matrice de visibilité par état (anon, validé, en attente, suspendu)

### Phase 3 — Frontend (1 jour ~8h)

- [ ] Composant `<PendingAccountScreen>` à afficher quand `fn_current_user_is_pending()`
- [ ] Bannière jaune sur `/conta` si en attente
- [ ] Page `/biblioteca` onglet "Paramètres généraux" : toggle mode d'accueil
- [ ] Page `/biblioteca` onglet "Règlement et circulation" : champ override
- [ ] Page `/biblioteca/blmf` (publique) : section politique d'accès
- [ ] Page `/criar-conta` : afficher la règle après sélection biblio
- [ ] Page `/painel` : nouvelle vue "Comptes en attente"
- [ ] Fiche utilisateur·rice (admin) : bouton "Valider physiquement" + modal
- [ ] Fiche utilisateur·rice (admin) : bouton "Révoquer" + modal raison
- [ ] Routing/guards : empêcher la navigation lecteur·rice si en attente

### Phase 4 — Backend Edge Functions (2h)

- [ ] Mise à jour de `notify-event` pour gérer les nouveaux events
  - `welcome_open` (auto-déclenché à l'inscription mode open)
  - `welcome_manual` (auto-déclenché à l'inscription mode manual)
  - `validation_confirmed` (déclenché par action librarian)
  - `validation_revoked` (déclenché par action librarian)
- [ ] RPC `api.validate_user_physically(user_id, note)` 
- [ ] RPC `api.revoke_user_validation(user_id, reason, note)`

### Phase 5 — Mails i18n (3-4h)

- [ ] Ajouter ~16 nouvelles clés dans `mail-strings.ts`
- [ ] Traductions militantes dans les 6 locales
- [ ] Tests Deno mail-strings.test.ts mis à jour
- [ ] Déploiement de la fonction `notify-event`

### Phase 6 — Tests d'acceptation (cf. section 11)

- [ ] Workflow A complet (mode open)
- [ ] Workflow B complet (mode manual_validation)
- [ ] Workflow C (révocation)
- [ ] Workflow D (changement de mode)
- [ ] Cas particuliers (9.1 à 9.7)

**Estimation totale : 2-3 jours de travail effectif** (étalés sur 1-2 semaines selon disponibilité).

---

## 11. Tests d'acceptation

À valider avant de considérer la feature production-ready.

### Tests fonctionnels

- [ ] **T1** : User crée un compte sur biblio `open`, confirme email → accès complet immédiat
- [ ] **T2** : User crée un compte sur biblio `manual_validation`, confirme email → écran d'attente
- [ ] **T3** : Librarian valide un compte en attente → user voit accès complet
- [ ] **T4** : Librarian révoque une validation avec raison → user reçoit mail avec raison + écran d'attente à la reconnexion
- [ ] **T5** : Coordenador change le mode de la biblio → nouveaux comptes suivent le nouveau mode, anciens préservés
- [ ] **T6** : User en attente tente d'accéder à `/livro/X` d'un livre `network` → redirection / écran d'attente
- [ ] **T7** : Comptes existants après migration sont validés et fonctionnels
- [ ] **T8** : Toutes les biblios existantes sont en mode `open` après migration
- [ ] **T9** : Bouton "Valider tous les comptes en attente" en lot fonctionne (si implémenté)

### Tests RLS / sécurité

- [ ] **S1** : User en attente ne peut PAS lire `mv_books_catalog_list_network_v1`
- [ ] **S2** : User en attente PEUT lire `mv_books_catalog_list_v1` (public uniquement)
- [ ] **S3** : User en attente sur biblio `private` ne peut PAS voir le contenu de sa biblio
- [ ] **S4** : User validé peut lire toutes les biblios `network`
- [ ] **S5** : `api.libraries_public_v1` retourne uniquement les biblios visibles selon les helpers
- [ ] **S6** : Anon ne peut JAMAIS voir les biblios `network` ni les `private`

### Tests UI / UX

- [ ] **U1** : Écran d'attente affiche le bon message + adresse de la biblio si renseignée
- [ ] **U2** : Bannière jaune sur `/conta` apparaît si en attente, disparaît après validation
- [ ] **U3** : Modal de confirmation de validation/révocation a les bons libellés en 6 locales
- [ ] **U4** : Texte de règle s'affiche correctement (default vs override) dans toutes les pages publiques
- [ ] **U5** : Page `/criar-conta` affiche la règle de la biblio sélectionnée avant submit

### Tests mails

- [ ] **M1** : Mail "Bienvenue mode open" arrive dans la bonne locale, avec bon contenu
- [ ] **M2** : Mail "Bienvenue mode manual" arrive dans la bonne locale, avec instructions claires
- [ ] **M3** : Mail "Validation confirmée" arrive après action librarian
- [ ] **M4** : Mail "Validation révoquée" arrive avec la raison transmise
- [ ] **M5** : Aucun mot proscrit (camerata it, Compas de) n'apparaît dans les nouveaux templates

### Tests audit / journalisation

- [ ] **L1** : Inscription mode open insère un log `auto_validated`
- [ ] **L2** : Validation manuelle insère un log `validated` avec performed_by_user_id
- [ ] **L3** : Révocation insère un log `revoked` avec reason
- [ ] **L4** : Migration grandfather insère des logs `migrated_grandfather` pour tous les comptes existants
- [ ] **L5** : `SELECT * FROM profile_validation_log WHERE user_id = X` montre l'historique complet pour un user donné

---

## Annexes

### A — Glossaire

- **Validation physique** : action explicite d'un·e bibliothécaire (`librarian` ou plus) pour confirmer qu'une rencontre physique a eu lieu avec un·e lecteur·rice de sa biblio.
- **Auto-validation** : pose automatique de `physically_validated_at = NOW()` à l'inscription pour les biblios en mode `open`.
- **Compte en attente** : `physically_validated_at IS NULL`, accès limité au catalogue public uniquement.
- **Grandfathering** : pratique consistant à valider automatiquement les comptes existants lors du déploiement de la feature, sans demander de validation rétroactive.

### B — Liens vers décisions

- Mode par défaut nouvelles biblios : `manual_validation` (sécurité par défaut)
- Mode des biblios existantes après migration : `open` (préserve le comportement actuel)
- Une seule colonne `physically_validated_at` (pas deux flags séparés)
- Compte en attente = écran d'attente, pas blocage du login
- Révocation autorisée à `librarian` (avec journal d'audit)

### C — Decisions à prendre lors de l'implémentation

- [ ] Faut-il un bouton "Valider en lot" pour qu'une biblio qui passe en mode `open` puisse mass-valider ses comptes en attente ?
- [ ] Le coordenador qui se valide lui-même a-t-il besoin d'une note spéciale ? (À journaliser comme cas atypique.)
- [ ] Faut-il une notification au coordenador quand un nouveau compte est en attente sur sa biblio ? (Mail récapitulatif quotidien ?)
- [ ] L'écran d'attente doit-il afficher un compteur "Tu attends depuis X jours" ?

---

**Spec close. Prochaine étape : spec migration de compte.**
