# Cadrage — Auto-déclaration « ajouter ma bibliothèque » sur la carte (MAP-J)

**Date :** 2026-06-18
**Statut :** 🟢 décisions tranchées (J-A…J-I) le 18/06/2026 par Xavier — prêt à implémenter (paquet CARTO-7)
**Auteur·ices :** AnarBib (session « Carte réseau 10 locales »)
**Réfs :** spec `spec-cartographie-reseau` v1.0 §5.7 + MAP-J ; REGISTRE §34 ; doctrine
PUBLIB §31 (opt-in / accès concentrique) ; MAP-E (consentement) ; modèles existants
`library_requests`, `submit-gazette-contribution`, `network_administrators`.

---

## 0. Objet

MAP-J (différé par la spec) prévoit un **parcours public « ma bibliothèque n'est pas
sur la carte, je veux l'ajouter »**, cohérent avec la nature ouverte du projet. La spec
le laisse explicitement à cadrer car il ouvre des questions de **modération** et de
**consentement**. Ce document pose les arbitrages à trancher avant tout code.

**Ce que MAP-J n'est PAS** :
- Ce n'est **pas** l'adhésion au réseau (`/solicitar-biblioteca` → `library_requests`,
  parcours institutionnel lourd avec cooptation). MAP-J est **léger** : juste faire
  apparaître un lieu sur la carte (a priori comme **« cible »** non-membre).
- Ce n'est **pas** une publication automatique : conformément à MAP-E, rien n'apparaît
  publiquement sans validation **et** opt-in.

---

## 1. Principes directeurs (hérités de MAP-E / PUBLIB)

1. **Consentement d'abord.** On privilégie l'**auto-déclaration de SA PROPRE
   bibliothèque** par le collectif lui-même. Signaler la bibliothèque **d'autrui** est
   sensible (un tiers n'a rien demandé) → au mieux une **suggestion sans contact**, à
   modérer avec prudence, voire à **interdire au lancement**.
2. **Rien de public sans double porte.** Une soumission ne devient visible qu'après
   (a) **validation** par la coordination **et** (b) **opt-in** explicite `statut_public`.
3. **Pas de fuite de contact.** Les coordonnées (N2 : adresse/email/tél) restent privées
   tant que `contact_public` n'est pas activé par le collectif (accès concentrique MAP-E).
4. **Anti-tracking.** Aucune dépendance tierce qui fuiterait la soumission (INV-5).

---

## 2. Décisions à trancher

| Réf | Question | Options | Reco |
|---|---|---|---|
| **J-A** | Qui peut soumettre ? | (a) Anonyme + anti-bot ; (b) compte AnarBib requis | **(a)** anonyme + Turnstile — bas seuil, cohérent projet ouvert ; la modération est le vrai filtre |
| **J-B** | Périmètre | (a) **sa** biblio uniquement ; (b) aussi signaler un tiers | **(a)** au lancement (consentement) ; (b) plus tard, en « suggestion sans contact » seulement |
| **J-C** | Stockage | (a) table de staging dédiée `cartography_submissions` ; (b) ligne directe dans `cartography_entries` avec un état `pending` | **(a)** staging séparé (sépare le non-vérifié du curé ; modèle `library_requests`) |
| **J-D** | Devenir à l'approbation | crée une fiche `cartography_entries` `statut_anarbib='cible'`, `statut_public=FALSE`, `contact_public=FALSE` | idem reco (jamais public d'office) |
| **J-E** | Modération | qui = `network_administrators` ; écran dédié (file d'attente approuver/refuser) | idem |
| **J-F** | Anti-abus | Turnstile (déjà dans le projet : `@marsidev/react-turnstile`) + rate-limit côté Edge Function (modèle `auth_rate_limits` / `submit-gazette-contribution`) | idem |
| **J-G** | Géolocalisation | (a) le soumetteur **pose un point** sur une mini-carte (clic) ; (b) il saisit juste ville/pays, la coordo place le point | **(a)+(b)** : pin approximatif par le soumetteur, **affiné par la coordo** via le picker GPS déjà livré (CARTO-6). **Pas de géocodage** (Nominatim non requis) |
| **J-H** | Notification coordo | file `*_notification_outbox` → `notify-event` → `fede@anarbib.org` (modèle Gazette/Lettre) | idem |
| **J-I** | Champs collectés | nom, ville, pays, catégorie, langue(s) du fonds, site (option), contact (option, privé), notes ; + position (pin) | minimal ; pas d'obligation de contact |

> **✅ Décisions actées (18/06/2026, Xavier) — toutes les recommandations retenues :**
> J-A anonyme + Turnstile · J-B sa propre biblio uniquement · J-C table de staging
> dédiée · J-D fiche « cible » non publique (jamais public d'office) · J-E coordination
> réseau (`network_administrators`) uniquement · J-F Turnstile + rate-limit · J-G pin
> posé par le soumetteur, affiné par la coordo (pas de Nominatim) · J-H notification
> e-mail → `fede@anarbib.org` · J-I jeu de champs minimal, contact optionnel.

---

## 3. Architecture proposée (sous réserve des arbitrages)

```
[Form public /cartografia/ajouter]  (anon + Turnstile)
        │  POST (nom, ville, pays, catégorie, langues, site?, contact?, notes, lat/lon approx)
        ▼
[Edge Function publique  submit-cartography-entry]   (verify_jwt=false, service_role)
   - vérifie Turnstile + rate-limit (IP)
   - INSERT public.cartography_submissions (status='pending')
   - INSERT cartography_submission_notification_outbox  → notify-event → fede@anarbib.org
        ▼
[File de modération]  (écran coordination, RBAC network_administrators)
   - approuver → RPC api.fn_cartography_submission_approve(id)
        → crée public.cartography_entries (statut_anarbib='cible', statut_public=FALSE)
        → status='approved'
   - refuser  → RPC api.fn_cartography_submission_reject(id, motif)  (status='rejected', mémoire conservée)
        ▼
[Fiche dans la carte]  invisible au public tant que statut_public=FALSE
   - le collectif (si membre, plus tard) peut opter-in ; sinon reste « cible » non publique
```

### Schéma indicatif (table de staging)

```sql
CREATE TABLE public.cartography_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected')),
  -- payload soumis (mêmes champs que cartography_entries, en N1 + contacts optionnels)
  name text, city text, country text, categorie text, langue_fonds text[],
  site_url text, contact text, notes text, notes_locale text,
  lat numeric(9,5), lon numeric(9,5),
  -- traçabilité
  submitter_note text,                  -- « c'est ma biblio », message libre
  source_ip_hash text,                  -- anti-abus (haché, jamais l'IP en clair)
  created_at timestamptz NOT NULL DEFAULT now(),
  reviewed_by uuid REFERENCES auth.users(id),
  reviewed_at timestamptz,
  review_note text,                     -- motif de refus / commentaire
  created_entry_id uuid REFERENCES public.cartography_entries(id) ON DELETE SET NULL
);
-- RLS verrouillée (Scénario C) : écriture par l'Edge Function (service_role) ;
-- lecture/modération via RPC SECDEF gardées fn_caller_is_network_admin().
```

> Note i18n : la soumission est mono-langue (la langue du collectif) + `notes_locale`,
> comme à l'import. La traduction dans les 10 locales est un enrichissement ultérieur
> (la coordo ou le collectif via l'UI d'édition CARTO-5).

---

## 4. Réutilisation de l'existant

- **Anti-bot** : `@marsidev/react-turnstile` est déjà une dépendance (login/inscription).
- **Edge Function publique rate-limitée** : `submit-gazette-contribution` est le **patron
  exact** (service_role, Turnstile, outbox + `notify-event`).
- **File de notification** : `*_notification_outbox` + dispatcher `notify-event` (Gazette/Lettre).
- **RBAC modération** : `network_administrators` + `fn_caller_is_network_admin()`.
- **Placement GPS** : le picker clic/glisser livré (CARTO-6, modale d'édition) sert à
  affiner le point à l'approbation — **aucun Nominatim requis**.

---

## 5. Questions ouvertes (pour la coordination / une AG)

1. **Suggestion de tiers (J-B)** : autorise-t-on un jour à signaler une biblio qu'on ne
   gère pas ? Si oui, sous quelle forme (pin de ville sans contact, mention « à confirmer
   par le collectif ») et avec quelle vérification ?
2. **Seuil de confiance** : une soumission auto-déclarée devient-elle « cible » ou
   directement « partenaire » si le collectif le demande ? (Reco : toujours « cible »
   jusqu'à décision réseau.)
3. **Anti-doublon** : à l'arrivée d'une soumission, proposer un rapprochement avec les
   fiches existantes (même ville + nom proche) pour éviter les doublons.
4. **Rétention** : combien de temps conserve-t-on les soumissions `rejected` (mémoire) ?
5. **Lien d'entrée** : où expose-t-on le bouton « Ajouter ma bibliothèque » ? (Reco : sur
   `/cartografia`, discret, + mention dans la comm' réseau.)

---

## 6. Récapitulatif

MAP-J est **réalisable sans nouvelle infrastructure** (pas de Nominatim, tout le socle
existe). Le cœur est une **table de staging + une Edge Function publique anti-abus + un
écran de modération coordination**, le tout aligné sur le **consentement** (auto-déclaration,
jamais public d'office). Arbitrages **J-A…J-I tranchés le 18/06** (toutes les recommandations
retenues — cf. encadré §2).

**Prochaine étape** : implémenter le paquet `CARTO-7` (staging `cartography_submissions` +
EF publique `submit-cartography-entry` [Turnstile + rate-limit] + RPC modération SECDEF
gardées `fn_caller_is_network_admin` + écran coordination + formulaire public `/cartografia/ajouter`
avec pin clic). Les questions ouvertes §5 (suggestion de tiers, anti-doublon, rétention) restent
à instruire en cours de route ou en AG.
