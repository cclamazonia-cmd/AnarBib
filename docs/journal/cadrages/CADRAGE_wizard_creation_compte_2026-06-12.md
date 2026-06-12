---
Genre : trace (cadrage de chantier) — **v0.1 (squelette à arbitrer)**
Statut : 🟡 ouvert — à arbitrer (collectif/Xavier) puis exécuter
Date : 2026-06-12
Session : Identité lecteur·rice locale (CARD-LOCAL §27) — volet transverse « canaux/welcome »
Préséance : ce document est une TRACE non-normative. Les décisions, une fois prises,
sont inscrites au REGISTRE_decisions.md (qui fait foi). Ne pas recopier une décision
ici — lier/citer plutôt (ID du REGISTRE).
Références : CARD-LOCAL-CANAL · CARD-LOCAL-STAFF · CARD-LOCAL-3 (REGISTRE §27) ;
MULTI-E.2 · MULTI-F.1 (REGISTRE §20) ; VALID-C1..C4 (REGISTRE §9) ; CARD-FLAG (REGISTRE §23) ;
DOC-ADDR-1 (tutoiement) · DOC-I18N-1 (10 locales) · DOC-NOTIF-1 (REGISTRE §0).
Dépendances : `src/pages/public/CriarContaPage.jsx` (formulaire linéaire actuel) ;
EF `supabase/functions/register/index.ts` (création + e-mail de bienvenue) ;
vue `v_libraries_for_signup` (sélection de biblio au signup).
---

# Cadrage — Wizard de création de compte (+ canaux/welcome CARD-LOCAL-CANAL)

## 1. Contexte

`CriarContaPage.jsx` est aujourd'hui un **formulaire linéaire** unique (~520 lignes) :
bandeau vitrine → sélection de biblio → champs (identité civile, contact, adresse,
mot de passe, acceptation du règlement) → submit → message de succès (toast `msg`).
La création passe par l'EF `register` (mot de passe provisoire + `public_id` +
e-mail de bienvenue). La locale du navigateur pilote la langue du mail (paquet 25.4).

Deux besoins convergent ici :

1. **Ergonomie** : le formulaire linéaire mélange des préoccupations hétérogènes
   (choix politique de biblio, données civiles, RGPD/règlement) sur un seul écran.
   Un **wizard par étapes** clarifierait le parcours et réduirait l'abandon.
2. **CARD-LOCAL-CANAL** (REGISTRE §27) : à la **création**, la personne doit
   recevoir/voir **UUID + identifiant de login + « comment marche ta biblio » +
   « tu es en attente »**. L'**identité locale** (numéro/nom) n'est **jamais**
   communiquée à la création (elle n'existe pas encore — c'est un acte staff,
   CARD-LOCAL-STAFF), mais **à la validation/attribution** (gérée par Lots 1→5,
   déjà construits).

> ⚠️ **Pourquoi un cadrage séparé.** Le wizard **redessine** ce flux. Implémenter
> le message canaux/welcome dans le formulaire linéaire actuel serait du **jetable**.
> La boussole canal (le « quoi communiquer ») est donc spécifiée **ici**, comme
> **étape de confirmation/bienvenue du wizard**, et exécutée avec lui.

## 2. Objectifs

- O1. Découper la création en **étapes** digestes (wizard), avec barre de
  progression et navigation avant/arrière, **sans régression** fonctionnelle
  (mêmes garanties que le formulaire actuel : règlement, RGPD, Turnstile, locale).
- O2. Incarner **CARD-LOCAL-CANAL** à l'étape finale (confirmation) + dans
  l'e-mail de bienvenue, de façon **conditionnée à la config biblio**.
- O3. Tutoiement (DOC-ADDR-1) et 10 locales (DOC-I18N-1) sur tous les nouveaux libellés.

## 3. Étapes proposées (hypothèse — à arbitrer)

1. **Choisir / explorer** — bandeau « explorer sans compte » (conservé) + sélection
   de bibliothèque (existant `v_libraries_for_signup`). Sortie possible sans compte.
2. **Qui es-tu** — identité civile minimale (prénom, nom), contact (e-mail, téléphone
   optionnel), langue préférée.
3. **Adresse** (selon besoin biblio / cotisation) — réutilise `parseAddressText`.
4. **Règlement & consentements** — acceptation du regimento (si `has_regimento`),
   consentement e-mail, Turnstile.
5. **Confirmation / bienvenue** — voir §4 (canaux/welcome).

> Les étapes 2-4 peuvent fusionner selon l'appétit UX ; le **point dur** est l'étape 5.

## 4. Étape « confirmation / bienvenue » = CARD-LOCAL-CANAL (le cœur)

À l'issue de la création réussie, afficher (écran) **et** envoyer (e-mail de bienvenue,
EF `register`) un message qui contient, **dans cet ordre** :

| Élément | Contenu | Condition |
|---|---|---|
| **Identifiant de login** | rappel : se connecter avec **e-mail OU `public_id`** + mot de passe provisoire reçu par e-mail, à changer en Conta | toujours |
| **UUID / `public_id`** | le `public_id` retourné par l'EF (déjà capté dans `CriarContaPage` via `setPublicId`) | toujours |
| **« Comment marche ta biblio »** | — si `reader_cards_enabled` : « tu recevras une **carte** » ; sinon : pas de carte. — **identité locale** communiquée **plus tard** : par **e-mail** si `reader_validation_mode='remote'`, **au 1er passage** si `'presential'`, accès direct si `'none'` (CARD-LOCAL-3) | selon config biblio |
| **« Tu es en attente »** | si l'appartenance naît `pending_validation` (cas réseau/biblio à validation) : expliquer que la circulation s'ouvrira **après validation** par l'équipe (CARD-LOCAL-GATE / VALID) | si `pending_validation` |

> 🔑 **Donnée manquante.** `v_libraries_for_signup` n'expose actuellement **ni**
> `reader_cards_enabled` **ni** `reader_validation_mode`. Pour conditionner le
> message, **l'une des deux** :
> - **(reco)** étendre `v_libraries_for_signup` avec ces 2 colonnes (anon-lisibles,
>   déjà publiques sur `libraries`) — petite migration de vue ;
> - ou un second appel léger côté front après sélection de biblio.
>
> L'**e-mail de bienvenue** (EF `register`) a déjà accès à la config biblio côté
> serveur → y porter le « comment marche ta biblio » est direct (mail-strings ×10,
> sur le modèle de `reader_identity_assigned.*` du Lot 5).

## 5. Décisions à arbitrer (à porter au REGISTRE si besoin)

- D1. **Granularité du wizard** : 5 étapes ? fusion 2-4 ? (UX)
- D2. **Source de la config biblio** au front : étendre `v_libraries_for_signup`
  (reco) vs second appel. **Migration de vue** si extension.
- D3. **Welcome = écran seul, e-mail seul, ou les deux** ? (reco : les deux —
  l'écran est éphémère, l'e-mail reste la trace.)
- D4. Wording exact « comment marche ta biblio » selon les 4 combinaisons
  `reader_cards_enabled` × `reader_validation_mode` (matrice à rédiger, ×10 locales).
- D5. Faut-il un **vrai composant wizard** réutilisable (cf. wizard d'import existant)
  ou un state-machine local à la page ?

## 6. Articulation / non-régression

- Conserver : Turnstile, locale navigateur → langue mail, `has_regimento` gating,
  `signupIntent` (reader_pending / reader_orphan / collective_candidate),
  les 4 messages de succès actuels (`auth.create.success*`) — à **réécrire** dans
  l'étape 5, pas à supprimer brutalement.
- Réutiliser, si pertinent, le **composant wizard de l'import** (« Novo import »)
  comme référence d'UX (barre d'étapes, navigation).
- Lots CARD-LOCAL 1→5 (identité, recherche, roster, notif) sont **orthogonaux** :
  ce chantier ne les touche pas ; il complète seulement la **boussole canal** côté
  création.

## 7. Hors scope

- Refonte du back de `register` autre que l'enrichissement du mail de bienvenue.
- Toute communication d'**identité locale** à la création (interdit — acte staff).

---

*Fin du cadrage v0.1. À arbitrer (D1→D5) avant exécution. Source de vérité des
décisions : REGISTRE_decisions.md (§27 `CARD-LOCAL` pour le volet canal).*
