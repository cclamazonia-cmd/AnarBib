# 📰 spec-gazeta-lettre-federation — Gazette (pull) & Lettre de la fédération (push)

| Champ | Valeur |
|---|---|
| **Domaine** | Face fédération — onglet `Gazeta` (renvoyé par `spec-outils-federalistes` §9). Deux objets, deux canaux. |
| **Version** | v0.1 (16 juin 2026 — cadrage : sépare l'éditorial *pull* déjà en prod du carnet de réseau *push* à construire) |
| **Statut** | 🟢 **Lot 2 + Lot 3 + 2b-bis en prod (16/06)** : opt-in (`/conta`, onglet & pill « Lettre », case signup), envoi des numéros + UI staff (`/rede`). Gazette « Rizoma » (pull) en prod. |
| **Foyer décisions** | **REGISTRE §29 `GAZ`** (GAZ-1..6) — *on cite l'ID, on ne reformule jamais ici.* Parent : **§24 `FED`** (onglet Gazeta). Anti-marketing : **`REGISTRE_TRAITEMENTS` §2.4 / §4.2 + Charte art. 4**. |
| **Dépendances entrantes** | `spec-outils-federalistes` v0.2 (§9 renvoie « bulletin de vie » + « gazette éditoriale ») · infra mail `notify-event` + Resend (`spec-migration-mail-resend`) · `profiles.consent_email_at` (transactionnel, RGPD art. 7) |
| **Dépendances sortantes** | **Fiche de traitement RGPD dédiée** pour la lettre (`REGISTRE_TRAITEMENTS` §2.6 à créer — **lot 3**) · flag de consentement `consent_lettre_at` (migration, lot 2) |
| **Préséance** | En cas de conflit : **REGISTRE §29 `GAZ`** + cette spec + backlog font foi ; cette spec décrit le design/comportement, elle ne tranche pas — elle cite. |

---

## 1. Objet & doctrine

La face fédération prévoyait un onglet `Gazeta` à **deux registres** (`spec-outils-federalistes` §9) : un **bulletin de vie** du réseau et une **gazette éditoriale**. Cette spec les **dissocie en deux objets de nature et de canal différents** (**GAZ-1**) :

- **La Gazette « Rizoma »** — objet **éditorial**, lu **en *pull*** : on vient le lire dans l'app (`/federacao/gazeta`), on le télécharge en PDF. *Déjà construit.* *(Nom officiel = **Rizoma**, tranché 16/06 ; emblème « Le Noyau » conservé.)*
- **La Lettre de la fédération** — **carnet de vie du réseau**, **poussé en *push*** dans la boîte mail. C'est le « bulletin de vie » jamais implémenté. *À construire.*

**Doctrine cardinale (la raison d'être de la séparation).** La lettre **n'est pas la gazette envoyée par mail**. Pousser le contenu éditorial complet dans les boîtes, ce serait exactement le modèle « newsletter Carrefour/Lidl » que le réseau refuse. Le différenciateur n'est pas cosmétique, il est **politique et juridique** :

- **Politiquement** : le contenu de la lettre est **du commun en train de se faire** (ce qui se trame dans la fédération), pas une vitrine ni une promotion. Texte sobre, situé, signé.
- **Juridiquement** : **`REGISTRE_TRAITEMENTS` §2.4 + Charte art. 4** posent « **aucune communication commerciale, aucune newsletter non sollicitée** ». Une lettre vers les membres relève donc du **consentement explicite** (RGPD art. 6.1.a), **pas** de l'exécution du contrat de service comme les mails transactionnels (**GAZ-5**).

## 2. État des lieux (base vérifiée le 16/06/2026)

Méthode du projet : nommer l'existant avant de concevoir.

**Construit & en prod (la Gazette)** — livré les 14-15/06, **sans décision REGISTRE enregistrée** (corrigé par §29 `GAZ`, règle #12) :

- **Données** : `gazette_issues` (numéro, statut `draft`/`published`, `cover_date`, `published_broadcast_at`), `gazette_submissions` (contributions, statut `accepted`…), `gazette_build_jobs` (état du pipeline par étapes), `gazette_submission_notification_outbox` (file d'envoi), stockage réseau par locale.
- **Vues** : `api.gazette_*_public_v1` (lecture **anon** sous RLS), vues `security_invoker = true`.
- **Pipeline mensuel** : EF `gazette-monthly-build` orchestrée par **pg_cron** (`gazette_automation_jobs`), en étapes (`start → curate (FR) → translate (1 locale/appel) → assemble_reseau → finalize`) pour tenir dans le temps d'exécution d'une EF ; cron `reconcile-gazette-dispatch` (*/5 min) relance jusqu'à `ready`. Sources : **registre éditable `gazette_sources`** (`network_staff` ajoute/retire/désactive les flux depuis le panel ; health-check `last_fetched_at`/`last_status` ; repli sur `infolibertaire.net` + `noticiasanarquistas` si vide ; migration `20260616163551`). Curation + traduction 10 locales via `claude-opus-4-8`. **Produit un BROUILLON** ; **publication manuelle** (`network_staff`, après relecture). Le pipeline est **rejouable étape par étape sur un brouillon, jamais sur un numéro paru** (22/08/2026) : `start` refuse un numéro dont le `status` n'est plus `draft` — sans quoi son upsert le repassait en brouillon et le sortait de la vue publique — et le routeur arrête proprement toute autre étape sur un numéro publié (job sorti de la file, HTTP 409) plutôt que d'en écraser le contenu ; l'assemblage de la page « Vie du réseau » ne la pose qu'une fois, quel que soit le nombre de passages. Couvert par `src/tests/gazette-monthly-build.test.js`, qui exerce l'EF transpilée hors Deno.
- **Contributions** : EF `submit-gazette-contribution` → boîte éditoriale fixe `fede@anarbib.org` ; events `gazette.contribution.received` / `gazette.draft.ready_for_review` (fan-out `network_staff`) gérés par `_shared/domain/gazette.ts`.
- **Front** : `GazetteTab.jsx` (maquette `anarbib-gazette.html`, emblème « Le Noyau », rendu en `<iframe srcdoc>` sandboxée, export PDF A4), `GazetteContributeForm.jsx`, `GazetteStaffPanel.jsx`. n°01 = juin 2026, mensuelle.
- **Diffusion mail existante** : RPC `api.fn_gazette_broadcast(issue_id)` + event `gazette.issue.published` → **avis de parution** (lien vers `/federacao/gazeta`, **pas de contenu**), **scopé staff** (cf. §6).

**Non construit (la Lettre)** : aucun flag de consentement dédié, aucune surface d'opt-in, aucun pipeline de composition/envoi de carnet de réseau, aucune fiche de traitement RGPD. Tout le §4 est à bâtir.

## 3. La Gazette « Rizoma » — registre éditorial, *pull* (existant)

**Cité ici pour mémoire** ; décision = **GAZ-2**. Rien à reconcevoir, sinon respecter la frontière avec la lettre.

- **Nature** : journal militant. Articles curés (flux anarchistes) **+ contributions acceptées** de la communauté, traduits en 10 locales.
- **Cycle** : brouillon **auto** (pg_cron) → **publication manuelle** `network_staff` après relecture. Jamais auto-publié.
- **Accès** : lecture **anon** in-app + PDF. C'est un objet qu'on **va chercher**, jamais imposé dans une boîte mail.
- **Frontière à tenir (GAZ-1)** : la gazette n'est jamais *poussée* intégralement par e-mail. Le seul mail lié à la gazette est l'**avis de parution** (§6), qui renvoie un **lien**.

## 4. La Lettre de la fédération — carnet de réseau, *push* (à construire)

Décisions cadres : **GAZ-1** (objet distinct), **GAZ-3** (contenu), **GAZ-4** (rythme), **GAZ-5** (consentement).

### 4.1 Intention

Un **carnet de bord du réseau**, court, qui dit « ce qui se trame » et arrive dans la boîte des personnes **qui l'ont demandé**. La gazette y figure comme **un élément parmi d'autres**, pas comme le cœur. C'est l'inverse exact d'un flux promotionnel : bas volume, texte premier, signé, désabonnable en un clic.

### 4.2 Contenu (GAZ-3)

Structure indicative (à figer en remplissage) — **rubriques courtes, texte sobre** :

| Rubrique | Source | Note |
|---|---|---|
| **O que se trama** (ce qui vient) | assemblées à venir (`spec-assembleias`, à venir) | dates + lien, pas le détail |
| **Novos círculos** | cercles `is_open=true` nouvellement ouverts (`circles`, FED §5) | annuaire, respect FED-7 (pas de vue de conjunto) |
| **Apelos / chamadas** | appels à contribution (gazette, entraide `Entreajuda`) | invitations, jamais injonctions |
| **A Gazeta n.º X saiu** | dernier `gazette_issues.status='published'` | **un seul** renvoi, lien vers `/federacao/gazeta` |
| **Signature** | « A coordenação / O Noyau » | la lettre est **signée**, pas anonyme |

**Interdits (garde-fous anti-« Carrefour ») :** pas de contenu éditorial complet poussé, pas de pixel de suivi / tracking (déjà désactivé, `REGISTRE_TRAITEMENTS` §4.2), pas de bannière promotionnelle, pas de fréquence élevée.

### 4.3 Composition (GAZ-3 — tranché 16/06 : hybride)

**Retenu = hybride** (calqué sur la gazette) : **brouillon auto** (rubriques pré-remplies depuis les données — nouveaux cercles, assemblées à venir, gazette parue) → **relecture, édition et envoi manuels** par `network_staff`. Réemploi exact du pattern gazette (« auto-draft, manual publish ») → cohérence + **garde-fou humain** contre le déversement automatique. *(Écartés : tout-auto sans relecture = risque « flux automatique » ; tout-manuel = charge d'animation plus lourde.)*

### 4.4 Rythme (GAZ-4 — tranché 16/06)

Découplé de la gazette : **au fil de l'eau, plafonné à un envoi mensuel maximum**. On n'envoie **que quand il y a matière** (assemblées, cercles ouverts, gazette parue) ; s'il ne se passe rien, **rien ne part** — anti-spam intrinsèque, fidèle à « lancer peu mais que ça vive ».

### 4.5 Audience & canal

- **Audience = opt-in uniquement**, **OFF par défaut** (GAZ-5). Toute personne ayant un compte (lecteur·rice incluse) peut s'abonner ; personne n'y est inscrit d'office.
- **Canal** : réemploi de l'infra existante — `notify-event` + outbox + Resend, **1 mail/destinataire**, **dans sa locale** (`preferred_language`), expéditeur `fede@anarbib.org`. Un nouveau handler `domain/*` (ou extension de `domain/gazette.ts`) + un event dédié (p.ex. `lettre.issue.sent`).

## 5. Consentement & RGPD (GAZ-5 — détail technique, build en lot 3)

> La **fiche de traitement RGPD** (`REGISTRE_TRAITEMENTS` §2.6) et l'implémentation sont **différées au lot 3**, après dégrossissage contenu/rythme. Cette section pose le modèle, pas le code.

- **Base légale = consentement** (RGPD art. 6.1.a), **distinct** du transactionnel (art. 6.1.b, fiche §2.4). Le `consent_email_at` existant **ne couvre pas** la lettre.
- **Flag dédié** : `profiles.consent_lettre_at timestamptz NULL` (NULL = non abonné·e). **Double opt-in** recommandé (clic de confirmation) pour une preuve propre.
- **Surfaces d'opt-in** : interrupteur dans `/conta` (« Recevoir la lettre de la fédération », **décoché par défaut**) + case **non cochée** à la création de compte (`criar-conta`). Registre d'adresse = tutoiement (`DOC-ADDR-1`).
- **Désabonnement 1-clic** : lien signé (token, **sans login**) dans **chaque** envoi → repasse `consent_lettre_at` à NULL + trace. Présent dans le pied de tout mail de lettre.
- **Zéro tracking** : pas de suivi d'ouverture/clic (option Resend non activée, `REGISTRE_TRAITEMENTS` §4.2).
- **Fiche §2.6 (à rédiger, lot 3)** — squelette : *Finalité* = informer de la vie de la fédération les membres qui l'ont demandé ; *Base légale* = consentement (6.1.a) ; *Personnes* = comptes abonnés ; *Données* = email, prénom, locale, horodatage de consentement ; *Sous-traitant* = Resend (déjà documenté §5) ; *Durée* = jusqu'au désabonnement ; *Droit de retrait* = désabonnement 1-clic + suppression du flag.

## 6. Garde-fou sur la diffusion existante (GAZ-6)

Le bouton « Diffuser » (`api.fn_gazette_broadcast`) **n'est pas la lettre** :

- C'est un **avis de parution opérationnel** : il envoie un **lien** vers la gazette publiée, **pas de contenu**.
- Audience = **staff (`librarian`/`coordenador`) des biblios actives + `network_staff`**, dédupliqué, respectant le kill-switch canal de la biblio (`v_library_notification_context`). Idempotent (`published_broadcast_at`). Gardé `network_staff`.
- Il **ignore `consent_email_at`** — **acceptable** tant que l'audience reste le **staff** (registre opérationnel, intérêt légitime, analogue au traitement réseau §2.5). 
- **Interdiction (GAZ-6)** : ne **jamais** réutiliser ce broadcast pour viser les **lecteur·rices** sans le modèle opt-in du §5. Le jour où la lettre touche les membres, elle passe par `consent_lettre_at`, **pas** par l'énumération staff.

## 7. i18n

Toutes les nouvelles chaînes (surfaces d'opt-in, gabarit de la lettre, libellés de désabonnement) dans les **10 locales** fixées par **`DOC-I18N-1`** (clés plates, LF sans BOM, une passe), conventions inclusives par locale. Le **contenu** d'un numéro de lettre est rédigé/traduit (comme la gazette), distinct des **libellés d'interface**. Registre d'adresse = tutoiement (`DOC-ADDR-1`).

## 8. Périmètre & lots

- **Lot 1 — cadrage (CE DOCUMENT).** ✅ Spec v0.1 + **REGISTRE §29 `GAZ`** + résolution du point ouvert FED. *(Gazette pull = déjà en prod, documentée.)*
- **Lot 1bis — dégrossissage.** ✅ Tranché 16/06 (Xavier) : **GAZ-4** = au fil de l'eau plafonné mensuel ; **GAZ-3** = hybride (brouillon auto + relecture/envoi manuel).
- **Lot 2 — opt-in.** ✅ **en prod** : `consent_lettre[_at/_pending_at]` + `lettre_consent_tokens` + outbox + dispatch ; RPC request/confirm/unsubscribe/cancel ; EFs publiques `lettre-confirm`/`lettre-unsubscribe` ; toggle `/conta` + **onglet & pill « Lettre »** (face fédération) ; 11 clés mail ×10.
- **Lot 2b-bis — case signup `criar-conta`.** ✅ **en prod** : RPC `fn_lettre_optin_for_user` (service_role, même double opt-in) + case facultative + EF register.
- **Lot 3 — RGPD + envoi.** ✅ **en prod** : fiche RGPD `REGISTRE_TRAITEMENTS §2.6` ; `lettre_issues` + RPC `fn_lettre_draft_create`/`_update`/`_send` (brouillon auto-assemblé, fan-out idempotent) ; handler `lettre.issue.sent` + 7 clés mail ×10 ; **UI staff** `LettreStaffPanel` (onglet « Lettre » de `/rede`).

## 9. Points ouverts

*(GAZ-4 rythme et GAZ-3 composition **tranchés le 16/06** — voir §4.3 / §4.4.)*

- Audience de départ : ouvrir l'opt-in à **tous les comptes** d'emblée, ou d'abord **staff/membres actifs** puis élargir ?
- Double opt-in : exigé (preuve) ou simple opt-in horodaté suffisant pour un cadre associatif ?
- Réemploi `domain/gazette.ts` (event `lettre.*`) vs nouveau `domain/lettre.ts` (lisibilité).

## 10. Prompt de reprise

> Spec v0.1 cadrée (16/06). **Gazette (pull) = en prod, documentée rétroactivement** ; **Lettre (push) = à construire**. Décisions opposables : **REGISTRE §29 `GAZ-1..6`** (point ouvert FED « rythme bulletin/gazette » résolu). **Rythme (GAZ-4) + composition (GAZ-3) tranchés (16/06)** : lettre **au fil de l'eau plafonnée mensuel**, composition **hybride** (brouillon auto + relecture/envoi manuel staff). Prochaine étape = **Lot 2** : migration `consent_lettre_at` (OFF par défaut) + surfaces opt-in `/conta` & `criar-conta` + endpoint de désabonnement signé + i18n, **sans envoi**. Puis **Lot 3** en dernier (**fiche RGPD §2.6** + pipeline d'envoi hybride). Garde-fou **GAZ-6** : le « Diffuser » existant reste **staff-only**, jamais vers les lecteur·rices sans opt-in.

---

*Fin de la spec v0.1. Décisions opposables : voir REGISTRE §29 `GAZ`. Cette spec décrit le design/comportement ; elle cite les décisions, elle ne les tranche pas.*
