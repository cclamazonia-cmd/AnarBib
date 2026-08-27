# CADRAGE — Inviter une bibliothèque

| | |
|---|---|
| **Genre** | Cadrage *forward* — fixe la doctrine et l'état des lieux **avant** tout code. |
| **Statut** | 🟡 **Lots 1, 2 et 3a livrés** (schéma · émettre-révoquer-lister · note scindée, nom rendu, purge). Restent le mailer et l'écran. |
| **Date** | 27 août 2026. |
| **Origine** | §6 du cadrage « Je représente une bibliothèque » (27/08) : le mécanisme de claim y était noté « à moitié construit ». Vérification faite, le diagnostic était faux mais le manque est réel — voir §3. |
| **Décisions prises** | **D1** option A, on étend `library_request_claims` (§5) · **D2** admins réseau seuls · **D3** 45 jours · **A1** le nom de la bibliothèque est montré · **A3** signature institutionnelle · **A4** note scindée en interne / mot d'accompagnement · **B** purge à 45 jours. Toutes le 27/08. **Une borne reste ouverte** : les mentions orphelines. |
| **Voisins** | `library_request_claims` · `CADRAGE_accueil_equipe_2026-06-19` (cooptation d'équipe) · `CADRAGE_onboarding_atelier_2026-06-02` · `library_request_mandate_transfers` · `lettre_consent_tokens` / `reader_card_tokens` (jetons sans compte). |

> **Note de vocabulaire.** On dit **inviter**, pas *prospecter* ni *démarcher*. La nuance n'est pas cosmétique : un pipeline de prospection produit des listes, des relances et des taux de conversion — exactement la méga-machine que la doctrine écarte. Une invitation est un **geste adressé à quelqu'un**, qui s'éteint tout seul si personne ne la saisit. Le §7 en fait une contrainte de conception, pas un vœu.

---

## 1. Objet

Permettre à la coordination de **tendre un lien** à une bibliothèque repérée, au lieu d'attendre qu'elle frappe à la porte.

Aujourd'hui, la seule entrée est l'auto-candidature : la bibliothèque découvre AnarBib, crée un compte par la voie « je représente une bibliothèque », et remplit le formulaire. Ce chemin fonctionne (et vient d'être requalifié le 27/08 pour parler aux bibliothèques déjà constituées). Il ne couvre pas le cas inverse, qui est pourtant le plus fréquent dans la vie du réseau : **on rencontre une bibliothèque à Bologne, une lectrice en mentionne une, quelqu'un connaît un fonds** — et il n'existe aucun geste pour transformer cette rencontre en une porte ouverte.

## 2. Le retournement : l'initiative change de camp, pas la doctrine

Ce qui change : **qui commence**.

Ce qui ne change **pas**, et ne doit pas :

- **Le compte reste une personne.** `library_requests.submitted_by_user_id` est `NOT NULL`, et c'est délibéré : c'est ce champ qui porte la RLS de la demande, les échanges avec la coordination, puis le mandat de coordenador·a. On n'invite pas une institution, on invite **quelqu'un à porter la demande de son collectif**. Un compte institutionnel casserait « une lectrice, une biblio », compliquerait le transfert de mandat — qui a déjà sa table d'audit `library_request_mandate_transfers` — et laisserait un objet orphelin le jour où la personne s'en va.
- **L'invitation n'est pas une admission.** Elle ouvre l'accès au formulaire, rien de plus. La demande passe ensuite par le même examen collégial que les autres. Inviter ne promet pas d'accepter, et le texte de l'invitation doit le dire.
- **Rien n'est définitif, personne ne décide seul·e.** Formule reprise telle quelle du parcours d'inscription.

## 3. Ce qui existe déjà — vérifié en base le 27/08/2026

Le §6 du cadrage précédent disait le claim « à moitié construit : `user_id` y est NOT NULL et aucune RPC ne crée de claim ». La seconde moitié de la phrase est littéralement vraie mais mène à une conclusion fausse : **pour la voie auto-candidature, la chaîne est entière et fonctionne.** C'est l'EF `register` qui insère le claim en `service_role` — pas une RPC, d'où la confusion.

| Brique | État réel |
|---|---|
| `library_request_claims` | 11 colonnes. `user_id` **NOT NULL**, `email_snapshot` NOT NULL, `claim_token_hash` NOT NULL, `expires_at` NOT NULL, `used_at` / `used_by_request_id` nullables, `metadata` jsonb, `created_by_user_id` **nullable** |
| RLS de cette table | Une seule policy, `deny_direct_access_secdef_only` (ALL). **La table n'est atteignable que par fonctions SECURITY DEFINER** — aucun `select` direct, même pour la coordination |
| `fn_hash_claim_token` | Seul le **hash** du jeton est stocké ; le jeton en clair n'existe que dans le mail |
| `fn_get_library_request_claim_context(token)` | SECDEF, **accessible à `anon`** — une personne non connectée peut valider un jeton et voir à quel e-mail il est rattaché |
| `fn_consume_library_request_claim(token, request_id)` | SECDEF, accessible à `anon`, rend la **ligne complète** du claim |
| `fn_submit_library_request_via_claim(...)` | SECDEF, accessible à `anon`. **Était cassée** (`invalid input syntax for type json`, 22P02, dès la première instruction, même avec un jeton valide) — réparée le 27/08/2026, migration `20260827100000`. Sans cette réparation ce chantier était sans objet |
| Création d'un claim | **Aucune RPC.** Seule l'EF `register` insère, en `service_role`, avec `metadata.source = 'register_signup_without_library'` et un TTL de 14 jours |
| Écran | `/solicitar-biblioteca` valide déjà un `?claim=` **sans être connecté**, et possède déjà une branche d'affichage « pas de compte + claim valide » |
| Mentions de biblios hors réseau | Les comptes `reader_orphan` déposent le nom cité dans `signup_intent_metadata.library_name_mentioned`. **Affiché uniquement à la lectrice elle-même**, dans `/conta`, où elle peut l'effacer |

**Ce qu'il faut retenir :** l'arrivée anonyme sur le formulaire est déjà à moitié construite. Ce qui manque est **en amont** — émettre l'invitation — et **au raccord** — lier le claim à un compte qui n'existe pas encore.

## 4. Ce qui bloque, précisément

1. **`library_request_claims.user_id` est `NOT NULL`.** Un claim d'invitation n'a, par construction, pas d'utilisateur au moment de son émission. C'est le verrou central.
2. **Aucune RPC ne crée de claim.** Il faut une porte d'entrée réservée, côté coordination.
3. **Il n'y a pas de révocation.** `expires_at` fait mourir un claim de vieillesse, `used_at` le consomme, mais rien n'annule une invitation partie à la mauvaise adresse.
4. **Le raccord claim → compte n'existe pas.** Puisque `submitted_by_user_id` est `NOT NULL`, la personne doit avoir un compte au moment où elle soumet. Il faut décider de l'ordre des gestes (§6) et écrire la liaison.
5. **Pas de mailer.** Une EF d'envoi, plus ses chaînes dans `mail-strings.ts` — **les 10 locales d'emblée**, la traduction n'est pas une étape ultérieure.
6. **La coordination ne voit rien.** Ni les mentions orphelines (visibles de la seule lectrice), ni les invitations en cours (la table est fermée par RLS). Tout affichage passera par une fonction SECDEF dédiée.
7. **Les deux origines doivent rester distinguables.** Les claims actuels portent `metadata.source = 'register_signup_without_library'`. Une invitation doit avoir la sienne, sinon l'audit ne pourra plus dire qui est venu de lui-même et qui a été sollicité — ce qui est précisément la distinction politique introduite ici.

## 5. La décision de forme — à trancher avant tout code

**Option A — étendre `library_request_claims`.** `user_id` devient nullable (`NULL` = invitation émise, pas encore réclamée), on ajoute une source dans `metadata` et un `revoked_at`. Une seule table, un seul cycle de vie ; tout le code de lecture et de consommation existant continue de servir, y compris la page qui sait déjà accueillir un porteur de jeton non connecté.

*Coût :* rendre une colonne nullable affaiblit une garantie aujourd'hui gratuite — il faudra une contrainte de remplacement (`user_id IS NOT NULL OR metadata->>'source' = 'invitation'`, ou l'équivalent) pour que la nullabilité reste un cas nommé et non un trou.

**Option B — une table `library_request_invitations` séparée**, calquée sur `library_team_invitations`. Le claim ne serait alors engendré qu'à l'acceptation. Plus lisible si l'on veut un jour une **ratification collégiale de l'invitation** — « on décide ensemble qui on sollicite » — puisque c'est exactement ce que fait déjà `library_team_invitations` avec ses endossements.

*Coût :* deux mécanismes à maintenir, deux cycles de vie, et la duplication du travail de jeton (hash, TTL, consommation) déjà fait.

**Recommandation : A**, sauf si la collégialité de l'invitation est jugée nécessaire dès la v1 — auquel cas B évite de la bricoler après coup.

### D1 — Décision prise le 27/08/2026 : **option A**

On étend. Ce que ça tranche par ricochet : **pas de ratification collégiale de l'invitation en v1** — c'était le seul argument qui faisait pencher vers B. La borne « collégialité » du §8 reste ouverte, mais la trancher « oui » plus tard coûtera une table, pas une retouche.

**Un écart assumé sur la forme.** Le §5 disait « une source dans `metadata` ». Le lot 1 pose une **colonne réelle** `claim_origin` (`self_signup` · `invitation`) et non une clé jsonb. Raison : la nullabilité de `user_id` ne devient un cas *nommé* que si une contrainte le dit, et une `CHECK` ne contraint pas proprement une clé jsonb — or c'est exactement le rôle qu'on lui demandait. Une colonne se contraint, s'indexe et se grep. Le défaut `self_signup` préserve la rétro-compatibilité : l'EF `register` insère sans connaître cette colonne et n'a pas à être redéployée.

**Précision utile :** `library_team_invitations.invited_user_id` est lui aussi `NOT NULL REFERENCES profiles(id)`. **Le dépôt n'a donc aucun précédent d'invitation vers quelqu'un sans compte.** Les seuls précédents de jeton-sans-compte sont `lettre_consent_tokens` (double opt-in de la Lettre) et `reader_card_tokens` — c'est de ce côté qu'il faut regarder pour la forme du jeton, pas du côté de l'accueil d'équipe.

## 6. Esquisse technique (option A)

### Lot 1 — schéma · **livré le 27/08/2026** (migration `20260827120000`)

- `user_id` devient nullable, et la garantie perdue est **remplacée** :
  `CHECK (user_id IS NOT NULL OR claim_origin = 'invitation')`. Un claim
  d'auto-candidature porte toujours son compte, exactement comme avant.
- `claim_origin` (`self_signup` par défaut) + `CHECK` sur les deux valeurs.
- Révocation : `revoked_at`, `revoked_by_user_id`, `revoked_reason`, avec
  **motif obligatoire** (doctrine « note obligatoire »).
- Une invitation est **signée** :
  `CHECK (claim_origin <> 'invitation' OR created_by_user_id IS NOT NULL)`.
- **Les deux lectures du claim ignorent désormais un claim révoqué**
  (`fn_get_library_request_claim_context`, `fn_consume_library_request_claim`).
  C'est la seule raison pour laquelle ce lot touche à du code déjà en service :
  un `revoked_at` que personne ne lit donnerait l'illusion d'avoir fermé une
  porte restée grande ouverte.
- Garde-fous : `tests/sql/invitation_claims_lot1_tests.sql` (10 tests), inscrit
  dans `ci-suites.txt`. La suite complète a été rejouée en local sur l'image
  Postgres de la CI : 25 suites vertes.

### Lot 2 — émettre, révoquer, lister · **livré le 27/08/2026** (migration `20260827170000`)

- `fn_create_library_request_invitation(email, library_name, note)` — réservée
  aux admins réseau actif·ves (D2), TTL 45 jours (D3), **rend le jeton en clair
  une seule fois**. Refuse une seconde invitation vivante pour la même adresse.
- `fn_revoke_library_request_invitation(claim_id, motif)` — motif obligatoire,
  ne touche ni aux auto-candidatures ni aux invitations abouties, idempotente.
- `fn_list_library_request_invitations(inclure_closes)` — ne rend **jamais**
  jeton ni hash ; garde dans le `where`, donc un appel non autorisé rend zéro
  ligne. États : `en_attente` · `compte_cree` · `aboutie` · `expiree` · `revoquee`.
- Droits : `authenticated` uniquement — **surtout pas `anon`**, contrairement aux
  trois RPC de lecture du claim qui, elles, doivent servir une personne sans compte.
- Garde-fous : `tests/sql/invitation_claims_lot2_tests.sql` (18 tests). Suite
  complète rejouée en local sur l'image Postgres de la CI : 27 suites vertes.

**Conséquence assumée de « le jeton ne se persiste jamais en clair » :** l'envoi
est un geste **séparé**. La RPC ne poste rien. Faire transiter le jeton par un
événement de notification l'écrirait en clair dans `team_notification_outbox`, où
il resterait. L'admin copie donc le lien et l'envoie — par le mailer quand il
existera, ou par Signal, ou de la main à la main à Bologne. C'est plus artisanal
qu'un bouton « envoyer », et c'est exactement le §7.

### Lot 3a — note scindée, nom rendu, purge · **livré le 27/08/2026** (migration `20260827200000`)

- **A1** — `fn_get_library_request_claim_context` rend désormais `library_name`
  (et `claim_origin`, et le mot d'accompagnement). Sans ça, le lien disait
  « quelqu'un vous a envoyé ceci » là où il doit dire « AnarBib invite la
  Bibliothèque X ».
- **A3** — signature **institutionnelle**. La fonction de contexte, ouverte à
  `anon`, ne rend **rien** sur l'admin émetteur ; `created_by_user_id` reste en
  base pour l'audit et n'en sort pas. Cohérent avec la doctrine du dépôt, où
  tout vote porte un `disclose_identity` explicite.
- **A4** — le champ `note` est **scindé** : `note_interne` (jamais rendue à la
  personne invitée, visible de la seule liste admin) et `mot_accompagnement`
  (écrit pour elle, destiné au mail). Un champ unique aurait servi aussi bien à
  « rencontrée à Bologne » qu'à « méfiants, y aller doucement » ; le jour où un
  écran l'aurait affiché — parce qu'il était là et ressemblait à un message —
  la fuite aurait été silencieuse. **La règle ne tient plus à la vigilance de
  qui code l'écran, elle tient au nom des colonnes.**
- **B** — purge à 45 jours après expiration ou révocation :
  `fn_purge_library_request_invitations()`, cron `anarbib-purge-invitations-expirees`
  (3 h 40, actif). Efface `email_snapshot` et les deux notes ; **la ligne
  survit** — qui a invité, quand, pour quelle bibliothèque, avec quelle issue,
  et le motif de révocation. `purged_at` horodate le geste. Ne touche ni aux
  invitations abouties (leur contact vit légitimement dans `library_requests`)
  ni aux auto-candidatures.
  Motif : `library_request_claims` est dans `deploy/bg2-known-tables.txt` mais
  **pas dans la denylist PII**, donc dans le flux de sauvegarde **long**
  (rétention 7/4/6). C'était sans conséquence tant que la table ne contenait que
  des auto-candidatures — leur e-mail duplique celui d'un compte tout juste
  créé, et `profiles` est dans la denylist. Une invitation, elle, stocke
  l'adresse d'un **tiers qui n'a rien demandé**.
- `email_snapshot` devient nullable, avec la même parade qu'au lot 1 :
  `CHECK (email_snapshot IS NOT NULL OR purged_at IS NOT NULL)`. Une ligne sans
  e-mail est une ligne purgée, jamais une ligne mal écrite.
- Garde-fous : `tests/sql/invitation_claims_lot3a_tests.sql` (15 tests). Suite
  complète rejouée en local : 28 suites vertes.

### Lots suivants — rien n'est codé

- **`fn_create_library_request_invitation(p_email, p_library_name, p_note)`** — SECDEF, réservée aux `network_administrators` actif·ves. Génère le jeton, n'en stocke que le hash, pose `user_id = NULL`, `created_by_user_id = auth.uid()`, `metadata.source = 'invitation'` + le nom de biblio pressenti. **Rend le jeton en clair une seule fois**, à l'appel — jamais relisible ensuite.
- **`fn_revoke_library_request_invitation(p_claim_id, p_motif)`** — SECDEF, même réserve. Pose `revoked_at` + motif. La doctrine « note obligatoire » du dépôt s'applique : on dit pourquoi.
- **`fn_list_library_request_invitations()`** — SECDEF, même réserve. La table étant fermée par RLS, c'est la seule façon pour la coordination de voir l'état des invitations. Ne rend **jamais** de jeton.
- **EF `notify-library-invitation`** — envoi via Resend, sur le modèle des autres mailers, chaînes dans `mail-strings.ts` dans les 10 locales.
- **Raccord.** La personne invitée arrive sur `/solicitar-biblioteca?claim=X` **sans compte**, voit de quoi il s'agit (branche déjà présente à l'écran), puis crée son compte par la voie `collective_candidate` existante — pré-remplie depuis l'invitation. Le claim se lie alors au compte créé (`user_id` passe de NULL à l'id réel) et la suite est le parcours déjà en place.
- **Ordre des gestes.** C'est le vrai point de conception : « voir puis s'inscrire puis soumettre » est le seul ordre compatible avec `submitted_by_user_id NOT NULL` sans inventer un compte fantôme. À valider à l'écran avant d'écrire le SQL.

## 7. Le joyau : une invitation s'éteint, elle ne relance pas

C'est la contrainte qui doit survivre à toutes les autres.

**Démarcher, c'est déjà solliciter.** Une invitation non suivie d'effet ne doit produire **aucune relance automatique**. Elle expire, silencieusement. Si la coordination veut réessayer, elle réémet un geste humain — et c'est très bien que ça lui coûte quelque chose.

**Pas de liste de prospects.** `fn_list_library_request_invitations` montre les invitations **émises** — des gestes déjà posés, avec leur auteur·e et leur motif. Elle ne doit pas devenir l'ossature d'un fichier de bibliothèques à conquérir, avec statuts et taux de réponse. La différence entre les deux tient à peu de choses en base et à tout dans l'usage : le cadrage la pose ici pour qu'on puisse s'y opposer plus tard en citant ce paragraphe.

**Et les mentions orphelines ne sont pas un carnet d'adresses.** Le §4.6 note que la coordination ne les voit pas. Avant de les lui exposer, il faut regarder ce qu'on ferait : une lectrice a nommé sa bibliothèque **pour elle-même**, dans son propre formulaire d'inscription, et peut effacer la mention. En faire une liste de cibles, c'est réutiliser une donnée déclarée sur un tiers pour un usage qu'elle n'avait pas. C'est une borne ouverte, pas un acquis (§8).

## 8. Bornes ouvertes

- ~~**Qui peut inviter ?**~~ **D2, tranchée le 27/08 : les `network_administrators` actif·ves, et personne d'autre.** L'ouverture aux coordenador·as était conditionnée à la réutilisation d'un vote à majorité qualifiée (67 %) supposé « déjà plus ou moins en place ». **Il n'existe pas** — voir la borne suivante, qui est ce que la vérification a appris.
- **Collégialité — la borne s'est déplacée.** Toute la gouvernance *réseau* d'AnarBib fonctionne à l'**unanimité avec veto**, jamais à la majorité : cooptation d'un·e admin (un seul `opposed` = rejet immédiat), retrait collectif (unanimité des autres actif·ves, quorum ≥ 2), et évaluation d'une demande d'adhésion — dont le commentaire de `library_request_votes` dit explicitement « unanimité, symétrique aux votes de cooptation ». Le seul `majority` du dépôt est **local à une bibliothèque** (`fn_propose_library_profile_change`, `(staff_actif / 2) + 1`) et c'est une majorité **simple**. Introduire du 67 % ne serait donc pas une réutilisation mais une **nouveauté doctrinale** : on remplacerait un droit de veto — anti-majoritaire par construction, ce qui est le choix politique du réseau — par une règle où une minorité peut être mise en minorité. Ça ne se décide pas dans une migration.
- ~~**Durée de vie.**~~ **D3, tranchée le 27/08 : 45 jours.** Une bibliothèque sollicitée sans préavis doit avoir le temps d'en parler en assemblée.
- **Une seule invitation vivante par adresse** — posé par défaut dans le lot 2 (réinviter une adresse sans réponse, c'est le glissement vers la relance qu'écarte le §7 ; révoquer d'abord oblige à dire pourquoi). Révisable si ça se révèle trop raide.
- ~~**Ce que voit la personne invitée.**~~ **Tranchée le 27/08 (lot 3a) :** le nom de la bibliothèque **oui** (A1) ; la signature est **institutionnelle**, « la coordination du réseau », jamais nominative (A3) ; la note de l'émetteur est **scindée** pour qu'aucune note interne ne puisse fuir vers elle (A4). L'adresse destinataire, elle, n'était pas une décision : `fn_get_library_request_claim_context` la rendait déjà et est ouverte à `anon` — quiconque détient le lien voit l'adresse. Constaté, assumé.
- ~~**Trace d'une invitation expirée ou révoquée.**~~ **Tranchée le 27/08 (lot 3a) : purge à 45 jours**, la ligne survit pour l'audit, l'e-mail et les notes disparaissent.
- **Exposition des mentions orphelines** (§7) — **seule borne encore ouverte.** À savoir avant d'en décider : l'app dit déjà à la lectrice, au moment où elle saisit le nom, que « le nom que tu indiques aide la coordination à connaître les bibliothèques encore hors du réseau », et lui dit dans `/conta` que « cette information n'est lisible que par l'équipe qui administre le réseau » — assortie d'un bouton d'effacement. Le *principe* d'une lecture par la coordination est donc déjà annoncé, et personne ne l'a pourtant jamais implémentée. Ce qui n'est **pas** annoncé, c'est le passage du **savoir** au **contacter**. Trois questions distinctes en découlent : (1) expose-t-on la mention ? (2) si oui, faut-il un consentement explicite au *contact* (une case à l'inscription), la déclaration actuelle ne couvrant que la connaissance ? (3) la liste montre-t-elle **qui** a cité la bibliothèque, ou seulement la bibliothèque ? La (3) est la plus lourde : elle sépare « voici des bibliothèques hors réseau » de « voici qui fréquente quelle bibliothèque hors réseau ». Et quoi qu'on décide, l'implémentation devra être une **vue** et jamais une copie, sinon l'effacement par la lectrice ne se propage pas et sa faculté de retrait devient fictive.

## 9. Précédents AnarBib mobilisés

`library_request_claims` + ses trois RPC SECDEF (chaîne éprouvée, réparée le 27/08) · `lettre_consent_tokens` / `reader_card_tokens` (jeton opaque, hash stocké, pas de compte requis) · `library_team_invitations` + `library_team_invitation_ratifications` (`CADRAGE_accueil_equipe_2026-06-19` — modèle de collégialité, **mais exige un compte existant**) · `library_request_mandate_transfers` (le mandat est transférable, donc le compte-personne n'est pas un cul-de-sac) · doctrine « note obligatoire » pour les motifs · doctrine « traduire tout de suite » pour les 10 locales · `CADRAGE_onboarding_atelier_2026-06-02` (la suite du parcours, une fois la demande acceptée).

---

*Cadrage forward produit le 27/08/2026, à la suite du chantier « je représente une bibliothèque ». Les faits du §3 sont vérifiés en base ce jour-là ; la fonctionnalité reste non construite et la décision de forme du §5 n'est pas prise.*
