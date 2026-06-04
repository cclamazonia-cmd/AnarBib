# CHANTIER — Carte « ma bibliothèque » côté lecteur·rice

**Date d'ouverture :** 2026-06-04
**Statut :** 🟢 CADRAGE VALIDÉ (arbitrages §7 clos le 04/06) — prêt pour l'étape 1 (§5)
**Porteur :** Xavier (dev principal)
**Périmètre :** `AccountPage.jsx` (onglet `perfil`), backend Supabase, EF `notify-event`
**Lié à :** EA-20 / #156 (contact confidentiel coopération), TR-6 (résolution logo, audit #153), chantier-cadre Biblioteca (clos)

> ⚠️ **Noms de tables, RPC, events, composants = noms de travail.** À confirmer/aligner sur les conventions réelles au moment d'écrire chaque migration (vérifier `pg_proc`, `pg_class`, les helpers attestés).

---

## 1. Objectif & cadrage politique

Aujourd'hui le·a bibliothécaire voit ses lecteur·rices (page Painel, « gérer leitor »), mais le·a lecteur·rice n'a **aucune fenêtre symétrique** sur sa biblio. L'onglet `perfil` du compte lecteur a une large colonne droite vide.

Ce chantier ajoute, dans cette colonne, une **carte « ma bibliothèque »** :
- les coordonnées **publiques** que la biblio choisit d'exposer (adresse, e-mail, téléphone, WhatsApp…),
- son **logo** (taille moyenne, ~72×72),
- un bouton **« écrire à ma bibliothèque »** (message libre, in-système).

C'est le **miroir** de ce qu'un·e bibliothécaire voit d'un·e lecteur·rice — et un acte de transparence cohérent avec la posture du projet : la biblio se rend joignable et lisible par ses propres lecteur·rices.

---

## 2. Décisions actées (cadrage des 03–04/06)

| # | Décision | Justification |
|---|---|---|
| **D1** | Le contact lecteur·rice est une **vitrine publique opt-in, vide par défaut**, **distincte** du contact confidentiel coopération `library_contact_profiles`. | Réutiliser le confidentiel = élargir silencieusement l'audience d'une donnée → classification violée, reproche RGPD/LGPD type. Minimisation + souveraineté de la biblio + consentement du responsable de traitement. |
| **D2** | Source de la vitrine = **nouvelle table sœur `library_public_contact`** (recommandé) ; extension de `library_commons` reste l'alternative. | Une table = un niveau de confidentialité = auditable ; cohérent avec le style « une table par concern ». *(À confirmer — §8.)* |
| **D3** | Canal « écrire » = **in-système** (table message → trigger → `notify-event` → handler), pas `mailto:`. | Reste dans l'enceinte AnarBib (anti-tracking), garde la trace, i18n + mise en forme du transport. |
| **D4** | Logo lu depuis la **source data-driven** `library_commons.logo_url` / `logo_file_key` (bucket public `library-ui-assets`), **jamais** le `LIBRARY_LOGO_MAP` codé en dur de `layout/index.jsx`. Repli **texte** (nom/short_name) si absent. | Le map codé en dur est le jumeau frontend de TR-6.2b (« ni anecdotique ni négociable » : chaque biblio voit son logo, exigence fédérative). Repli texte = bon comportement TR-6.1. |

> 📌 **Item de nettoyage séparé (à backloguer) :** le `LIBRARY_LOGO_MAP` codé en dur de `src/components/layout/index.jsx` (`resolveLibraryLogo`) est à dé-hardcoder sur `library_commons.logo_url`/`logo_file_key`, comme TR-6.2b côté mail. Hors périmètre de ce chantier, mais à tracer.

---

## 3. Moitié 1 — Vitrine publique + carte lecteur

### 3.1 Modèle de données — `library_public_contact`

Une ligne par biblio. Tout champ rempli = champ affiché ; rien par défaut.

```sql
-- Migration (squelette — appliquée par Woodpecker, JAMAIS collée dans SQL Editor)
CREATE TABLE IF NOT EXISTS public.library_public_contact (
  library_id      uuid PRIMARY KEY REFERENCES public.libraries(id) ON DELETE CASCADE,
  public_email    text,
  public_phone    text,            -- format E.164, cohérent avec le reste
  public_whatsapp text,
  public_address  text,            -- adresse de retrait/visite, en clair
  public_note     text,            -- ex. horaires d'ouverture, consigne d'accès
  updated_at      timestamptz NOT NULL DEFAULT now(),
  updated_by      uuid REFERENCES public.profiles(id)
);

ALTER TABLE public.library_public_contact ENABLE ROW LEVEL SECURITY;
-- (jamais DISABLE RLS — doctrine)
```

> Pas de `contact_name`/`contact_role` ici : la vitrine lecteur n'a pas vocation à nommer une personne (minimisation). Si besoin plus tard, ajout additif.

### 3.2 RLS

| Opération | Politique | Doctrine |
|---|---|---|
| `SELECT` | membre **actif** de la biblio (`user_library_memberships.status='active'`) **+** staff. **Pas `anon`.** | Lecture simple protégée RLS → `from()` autorisé (RPC v3). Minimisation : pas d'exposition publique large par défaut. *(membres-only vs public = §8)* |
| `INSERT`/`UPDATE` | **interdit en direct** → passe par RPC `upsert_library_public_contact`. | Action DB (write + validation) → RPC obligatoire. |

Policy SELECT (squelette) :

```sql
CREATE POLICY library_public_contact_select_member ON public.library_public_contact
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.library_id = library_public_contact.library_id
      AND m.user_id = auth.uid()
      AND m.status = 'active'
  ));
```

### 3.3 RPC d'écriture — `upsert_library_public_contact`

- `SECURITY INVOKER` ; garde de droit **coordination** (`user_can_manage_library` — éditer la façade publique engage la biblio) ; upsert `ON CONFLICT (library_id)`.
- REVOKE/GRANT doctrine :

```sql
REVOKE EXECUTE ON FUNCTION public.upsert_library_public_contact(uuid, jsonb)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT  EXECUTE ON FUNCTION public.upsert_library_public_contact(uuid, jsonb)
  TO authenticated;
```

- Bloc `DO` de vérification RLS en fin de migration (`SET LOCAL ROLE` + `SET LOCAL "request.jwt.claims"`, wrap `EXCEPTION WHEN insufficient_privilege`).
- `NOTIFY pgrst, 'reload schema';` en fin de migration.

### 3.4 Éditeur staff

- **Où :** `BibliotecaPage.jsx`, onglet `identity` (ou `comms`), **juste à côté** de `LibraryContactProfileSection` — pour rendre visible la distinction « contact réseau confidentiel » vs « contact public lecteur·rices ».
- **Composant :** `LibraryPublicContactSection.jsx` (calque structurel sur `LibraryContactProfileSection`).
- **Accès :** coordOnly.
- **Ergonomie :** bouton **« copier depuis le contact réseau »** qui pré-remplit les champs depuis `library_contact_profiles` (lecture coord) **sans fusionner les données** (deux classifications restent séparées) — la coordination valide ensuite ce qu'elle expose vraiment.
- Lecture : `from('library_public_contact')` ; écriture : `rpc('upsert_library_public_contact', …)`.

### 3.5 Carte lecteur — `MyLibraryContactCard.jsx`

- **Où :** `AccountPage.jsx`, onglet `perfil`, colonne droite (carte *sticky* alignée en haut). Biblio courante = `useLibrary().libraryId` (pas de sélecteur — doctrine ancrage géographique mono-biblio).
- **Lecture :** `from('library_public_contact').eq('library_id', libraryId).maybeSingle()` **+** `from('library_commons').select('logo_url, logo_file_key, name, short_name').eq('library_id', libraryId)` pour le logo et le repli texte.
- **Logo :** ~72×72, carré arrondi.
  - `src` = `logo_url` si présent ; sinon dérivé de `logo_file_key` via `https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/library-ui-assets/…` ;
  - `onError` → bascule repli texte (comme le topbar) ;
  - si aucun logo → repli texte (`short_name` ou initiales du `name`).
- **Champs :** n'afficher **que** les champs `library_public_contact` non vides. Si la table est vide (biblio n'a rien publié) → **carte minimale jamais masquée** : logo + nom + bouton « écrire » (décision 04/06). La carte reste un point de contact même sans coordonnées publiées.
- **Bouton « écrire à ma bibliothèque »** → ouvre `WriteToLibraryDialog` (§4.7).

### 3.6 i18n React (namespace `account.mylib.*`, 8 locales)

`title`, `address`, `email`, `phone`, `whatsapp`, `note`, `writeButton`, `noPublicContact` (repli), `logoAlt`. Plus les clés du dialog (§4.7).

---

## 4. Moitié 2 — Canal « écrire à ma bibliothèque » in-système

Pattern retenu : **table message (= trace) + colonne de statut d'envoi + trigger → `notify-event` → handler reader+staff.** Hybride propre entre le pattern circulation (trigger-direct) et le pattern outbox (statut d'envoi).

### 4.1 Modèle de données — `reader_library_messages`

```sql
CREATE TABLE IF NOT EXISTS public.reader_library_messages (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id   uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  sender_id    uuid NOT NULL REFERENCES public.profiles(id),
  subject      text,
  body         text NOT NULL CHECK (length(body) BETWEEN 1 AND 4000),
  mail_status  text NOT NULL DEFAULT 'pending'
               CHECK (mail_status IN ('pending','sent','failed','skipped')),
  created_at   timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.reader_library_messages ENABLE ROW LEVEL SECURITY;
```

- SELECT : l'expéditeur·rice voit ses propres messages ; staff de la biblio voit les messages reçus *(à arbitrer si on veut une boîte de réception staff — sinon le mail suffit en v1)*.
- INSERT : via RPC uniquement.

### 4.2 RPC d'envoi — `fn_reader_send_message_to_library`

- `SECURITY INVOKER` ; valide : membre **actif** de `library_id` ; `body` non vide ; **anti-spam** (ex. ≤ 3 messages / 24 h / lecteur·rice / biblio — seuil §8). Le contrôle anti-spam lit les propres lignes de l'appelant·e → OK sous INVOKER.
- INSERT la ligne, retourne son `id`.
- REVOKE/GRANT doctrine (FROM PUBLIC, anon, authenticated, service_role ; GRANT authenticated) + bloc DO + `NOTIFY pgrst`.

### 4.3 Trigger de dispatch

```sql
-- AFTER INSERT sur reader_library_messages :
-- pg_net.http_post vers notify-event avec
--   { event_type: 'reader_message_sent', record_id: NEW.id,
--     payload: { library_id: NEW.library_id, sender_id: NEW.sender_id } }
```

Fonction trigger `SECURITY DEFINER` + `search_path` figé (elle fait l'`http_post`), REVOKE doctrine.

### 4.4 Handler EF — `_shared/domain/reader-message.ts`

Calque sur le pattern **reader + copie staff** (cf. `reservas.ts` / `consultas.ts`) :
- relit le message par `record_id`, charge le profil expéditeur·rice et le `ctx` biblio ;
- **destinataire biblio** = `adminTarget(ctx)` (mécanisme existant des copies staff — pas de nouveau plumbing de destinataire) ; locale = `libLocale` ;
- **confirmation au lecteur·rice** (recommandé, §8) : mail « ton message a bien été transmis » ; locale = `preferred_language` ;
- met à jour `reader_library_messages.mail_status` (`sent`/`failed`) ;
- garde défensive : si pas de destinataire résolu → `mail_status='skipped'`, repli texte propre (jamais d'en-tête amputé — leçon TR-6.1).

### 4.5 Routing `dispatch.ts`

Une branche, avant le `else` final :
```typescript
if (event.startsWith("reader_message")) return await handleReaderMessageEvent(recordId);
```
> ⚠️ **Leçon 141.2.D :** ajouter un event = vérifier **le trigger DB, le dispatch, ET toute fonction de normalisation** côté handler (type `CON_WE_MAP`/`events.ts`). Si `reader_message_sent` passe par une normalisation, l'y inscrire.

### 4.6 `mail-strings.ts` (clés `rmsg.*`)

- Préfixe `rmsg.*` (calque `res.*`/`con.*`). Clés : `rmsg.staff.sub`, `rmsg.staff.intro`, `rmsg.reader.sub`, `rmsg.reader.intro`, `rmsg.body_label`…
- **C'est un fichier TS, pas JSON** : script Node `.cjs`, **escapes Unicode** (`\u00E7`, `\u00E0`…) pour garantir l'UTF-8, `deno check` après.
- **9 locales OBLIGATOIRES par clé** (vérifié 04/06 sur le fichier) : `pt-BR, fr, es, en, it, de, ca, eo, nl`. Le type `Record<SupportedMailLocale, string>` est strict → **`deno check` plante si une seule locale manque**. Attention au **`nl` (néerlandais)** : présent dans `mail-strings.ts` mais **absent des 8 locales React** — d'où l'asymétrie clés mail `rmsg.*` = **9 locales** vs clés React `account.mylib.*` = **8 locales**.
- *(Le commentaire d'en-tête du fichier dit encore « 6 locales » : stale depuis le 02/05, à rectifier un jour — cosmétique.)*
- Si `actionBox` (CTA « voir mon compte ») : forme **`{ kind, title, ctaUrl, ctaLabel }`** — lire `layout.ts:20-28` avant de le consommer (le squelette `network.ts` montre l'ancienne forme `{kind,label,url}` = piège).

### 4.7 Composer frontend — `WriteToLibraryDialog.jsx`

- Modal : `subject` (optionnel) + `body` (obligatoire, compteur). `rpc('fn_reader_send_message_to_library', …)`. Feedback succès/erreur. i18n `account.mylib.write.*` (8 locales).

---

## 5. Séquençage

M1 d'abord (valeur visible, risque bas, pas de mail), M2 ensuite. La carte héberge les deux mais le bouton « écrire » peut être masqué/désactivé tant que M2 n'est pas livré.

| Étape | Contenu | Dépend de |
|---|---|---|
| **1** | Migration `library_public_contact` (table + RLS + RPC upsert + DO + NOTIFY) | — |
| **2** | Éditeur staff `LibraryPublicContactSection` + bouton « copier du contact réseau » | Étape 1 |
| **3** | Carte lecteur `MyLibraryContactCard` (coordonnées + logo + repli texte) | Étape 1 (données) |
| **4** | Migration `reader_library_messages` (table + RLS + RPC envoi + trigger dispatch) | — |
| **5** | Handler `reader-message.ts` + routing dispatch + `mail-strings` `rmsg.*` | Étape 4 |
| **6** | Composer `WriteToLibraryDialog` + branchement bouton carte | Étapes 3, 4, 5 |

---

## 6. Doctrine & pièges (rappels durs)

- **Migrations** = fichiers SQL **horodatés** dans `supabase/migrations/`, appliqués par **Woodpecker** (`supabase db push --linked`). **Jamais** collées dans SQL Editor avant push. **Jamais** `apply_migration` MCP. MCP `execute_sql` = **lecture/inspection seule**.
- **RPC v3** : `from()` pour les lectures protégées RLS ; **RPC** pour tout write/validation.
- **REVOKE** fonctions privées : `FROM PUBLIC, anon, authenticated, service_role` puis `GRANT … TO authenticated`.
- Tables `public.*` : **ENABLE RLS + policy** (jamais DISABLE).
- **DO-block** de vérif RLS : `SET LOCAL ROLE` **+** `SET LOCAL "request.jwt.claims"` ; wrap `EXCEPTION WHEN insufficient_privilege`.
- `NOTIFY pgrst, 'reload schema';` en fin de migration.
- **`notify-event`** (>150 Ko) : déploiement **CLI uniquement**, **`--no-verify-jwt` obligatoire**, puis **vérifier l'incrément de version** (`supabase functions list`) — la CLI repasse `verify_jwt:true` par défaut (bug 401 silencieux d'avril 2026).
- CLI Supabase **pinnée** dans `.woodpecker.yml`.
- Commit discipline : **une modif logique = un commit**, **`npm run build`** garde-fou avant push, **`git status --short`** entre add et commit, messages commit **ASCII pur** (mojibake CP1252 en PS5), **dual-push** Codeberg + GitHub. Ne jamais croire « fait » sans `Get-Item`/`Select-String`.

---

## 7. Arbitrages tranchés (04/06) — toutes questions closes ✅

1. **D2** — ✅ **table sœur `library_public_contact`** (pas d'extension `library_commons`).
2. **SELECT vitrine** — ✅ **membres actifs only** (minimisation ; pas de lecture `anon`).
3. **Confirmation au lecteur·rice** sur « écrire » — ✅ **oui** (boucle fermée).
4. **Anti-spam** — ✅ **≤ 3 / 24 h / lecteur·rice / biblio**.
5. **Édition vitrine** — ✅ **coordOnly** (`user_can_manage_library`).
6. **Carte vide** — ✅ **jamais masquée** : logo + nom + bouton « écrire » même sans coordonnées publiées (cf. §3.5).
7. **`mail-strings`** — ✅ **9 locales** obligatoires par clé (`pt-BR, fr, es, en, it, de, ca, eo, nl`) ; type strict, `nl` absent de l'UI React (cf. §4.6).

---

## 8. Séquence migration/git type (réutilisable par étape)

```powershell
# Depuis anarbib-app. Créer le fichier de migration horodaté au timestamp REEL.
$ts = Get-Date -Format "yyyyMMddHHmmss"
$mig = "supabase/migrations/${ts}_library_public_contact.sql"
# (rédiger le SQL dans $mig — table + RLS + RPC + DO + NOTIFY)

npm run build                      # garde-fou
git status --short                 # verifier ?? / M
git add supabase/migrations/$mig
git status --short
git commit -m "feat: library_public_contact table RLS and upsert RPC"   # ASCII pur
git push origin main               # dual-push (remotes configures)

git fetch origin
git log --oneline origin/main -5   # etat reel du remote
# Woodpecker applique la migration (supabase db push --linked).
```

Pour `notify-event` (étape 5), après modif du handler/dispatch :
```powershell
supabase functions deploy notify-event --no-verify-jwt
supabase functions list            # verifier l'increment de version
```

---

## 9. Prompt de reprise

> Reprise du chantier **carte « ma bibliothèque » côté lecteur**. Cadrage validé le 2026-06-04 (doc `CHANTIER_carte_ma_bibliotheque_lecteur_2026-06-04.md`). Décisions actées D1–D4 (§2) : vitrine **publique opt-in** `library_public_contact` distincte du confidentiel `library_contact_profiles` ; canal « écrire » **in-système** (`reader_library_messages` → trigger → `notify-event` → `reader-message.ts`) ; logo lu sur `library_commons.logo_url`/`logo_file_key` (jamais le map codé en dur), repli texte. Avant de coder : trancher les questions ouvertes §7. Commencer par l'étape 1 (§5) : migration `library_public_contact`. Respecter la doctrine §6 (Woodpecker, RPC v3, REVOKE, DO-block, NOTIFY pgrst, notify-event --no-verify-jwt, commits ASCII + dual-push).
