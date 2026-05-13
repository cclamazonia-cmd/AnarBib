# spec-migration-mail-resend.md — Migration du provider mail Brevo → Resend

**Version** : v0.1
**Date** : 13/05/2026
**Statut** : projet, à valider avant ouverture de chantier
**Périmètre** : 9 Edge Functions Supabase + transport mail partagé
**Auteur·rices** : Xavier (rédaction politique), Claude (rédaction technique)

---

## §1 — Motivation politique et technique

### 1.1 Incident fondateur du 12 mai 2026

La session du 12 mai 2026, consacrée à la fermeture du chantier d'inscription sans bibliothèque rattachée (paquet 25), a fait émerger en conditions réelles un dysfonctionnement qui a coûté plusieurs heures de diagnostic et qui révèle une incompatibilité structurelle entre Brevo et la cohérence politique d'AnarBib.

Au cours du test grandeur nature, un usager équipé d'un VPN à filtrage DNS anti-tracking voyait le bouton CTA du mail de bienvenue mener vers une URL anormale, perçue à l'écran comme un lien vers `proton.me`. Le diagnostic, conduit jusqu'à 22h ce soir-là, a mis en cause trois facteurs superposés : une confusion visuelle du champ Reply-To dans Thunderbird, un secret Supabase obsolète qui pointait encore vers un vestige GitHub Pages, et — c'est le point qui motive cette spec — **le blocage au niveau DNS du domaine `sendibt3.com` par le VPN de l'usager**.

`sendibt3.com` est le nouveau domaine de tracking de Brevo. Tous les liens des CTAs envoyés via Brevo sont systématiquement réécrits pour passer par ce domaine de tracking avant redirection vers leur destination réelle. Pour un usager dont le VPN bloque les domaines de tracking connus — comportement attendu d'un VPN libertaire orienté vie privée — le bouton CTA devient matériellement inaccessible. Le lien est cassé non par défaillance d'AnarBib, mais par le passage forcé via un domaine tiers qui a précisément la fonction qu'AnarBib refuse politiquement.

### 1.2 Le problème opérationnel : la réécriture forcée des CTAs

Le mécanisme de Brevo n'est pas configurable au niveau d'un envoi unitaire. La réécriture des URLs vers `sendibt3.com` est appliquée à tous les liens de tous les mails sortants, indépendamment de leur contenu, de leur destinataire, ou de la nature de la notification. Une vérification dans le dashboard Brevo le 12 mai 2026 a confirmé qu'il n'existe **pas d'option de désactivation globale du link tracking** dans l'interface de configuration du compte ; les options disponibles permettent au mieux d'agir sur certaines campagnes marketing, pas sur l'ensemble du transactionnel.

Le coût opérationnel se mesure sur trois plans. D'abord, le diagnostic d'un CTA cassé est extrêmement difficile pour un mainteneur : l'URL visible dans le mail n'est pas l'URL d'AnarBib, et il faut plusieurs niveaux d'investigation (visualisation source du mail, désactivation du VPN, vérification du secret Supabase, etc.) avant de comprendre que le problème ne vient pas du code. Ensuite, l'expérience est dégradée silencieusement pour une fraction non négligeable des usagers militants, dont les outils anti-tracking sont — par cohérence politique avec ce qu'AnarBib veut offrir — précisément ceux qui bloquent `sendibt3.com`. Enfin, les archives mail des usagers conservent des liens qui pointent vers un domaine tiers à durée de vie courte : un mail conservé plusieurs mois peut contenir un CTA qui ne fonctionne plus, même quand l'usager n'est pas équipé de VPN.

Le projet a déjà rencontré une variante de ce problème sur les images des mails : Brevo réécrit également toutes les `<img src="...">` pour les faire passer par son CDN tracker. Le code-base contient depuis le 6 mai 2026 un module `_shared/mail/inline-images.ts` qui inline en base64 les logos hébergés sur Supabase Storage juste avant l'envoi, précisément pour contourner cette réécriture. Cette contre-mesure fonctionne mais elle est emblématique : elle nous oblige à patcher localement les effets d'un comportement provider qui contredit la doctrine du projet.

### 1.3 Le problème politique : le tracking imposé à l'insu des destinataires

Au-delà de la difficulté opérationnelle, le passage forcé des CTAs par un domaine de tracking pose un problème politique direct. Pour un projet libertaire, faire transiter les engagements des lectrices avec leurs mails par un dispositif de tracking, sans consentement explicite et sans possibilité de désactivation, est une incohérence éthique.

Le bilan de session du 12 mai 2026, §3.2, formule cette tension sans détour : *« AnarBib, projet libertaire, fait passer ses mails par un service qui pister tous les clics par défaut. Pour un usager équipé d'un anti-tracker, le bouton du mail devient inaccessible. Pour les autres, leur engagement avec le mail est traqué à leur insu. »*

Cette incohérence est aggravée par la nature des notifications concernées. Les mails d'AnarBib ne sont pas marketing : ce sont des notifications transactionnelles liées à des actes politiques (création d'une bibliothèque dans le réseau, cooptation d'un·e administrateur·rice, suspension d'un compte staff, alerte de retrait collectif). Tracker les clics des destinataires sur ces mails revient à enregistrer des signaux comportementaux sur des actes militants — ce qui contredit frontalement l'horizon politique pour lequel le SIGB existe.

### 1.4 Pourquoi Resend, et sous quelles conditions

La décision de migrer vers Resend, prise dans une session ultérieure au bilan du 12 mai, repose sur quatre éléments factuels.

Premier élément : **le tracking est désactivé par défaut sur Resend, au niveau du domaine**. La documentation Resend l'affirme explicitement et de manière redondante sur deux pages distinctes (`resend.com/docs/dashboard/domains/tracking` et `resend.com/blog/introducing-custom-tracking-domain`) : *« Open and click tracking is disabled by default for all domains. »* Le mécanisme d'activation passe par la création explicite, dans le dashboard et dans les DNS, d'un sous-sous-domaine de tracking (par exemple `links.notifications.anarbib.org`) dont le CNAME pointe vers l'infrastructure Resend. Tant que ce sous-sous-domaine n'existe pas dans la zone DNS chez OVH, Resend n'a matériellement pas la capacité de faire passer les liens par un domaine de tracking, et aucun pixel d'open n'est inséré dans les mails.

Le sous-domaine `notifications.anarbib.org` est déjà vérifié dans Resend depuis le 7 mai 2026 (status `Verified`, region eu-west-1 Ireland, provider DNS OVH). SPF, DKIM et DMARC sont validés. Aucun tracking subdomain n'est créé. L'état actuel correspond donc déjà à la doctrine cible.

Deuxième élément : **le compte Resend est déjà ouvert au nom du CCLA** (Centro de Cultura Libertária da Amazônia), porteur juridique de la BLMF et donc d'AnarBib. Pas de démarche administrative ni d'engagement contractuel nouveau à conduire.

Troisième élément : **le pricing est compatible avec le volume du projet** (3 000 mails/mois en plan gratuit, largement supérieur au volume actuel et anticipé sur les douze prochains mois) et **l'API est minimaliste**, ce qui facilite la rédaction du wrapper neutre décrit en §4.

Quatrième élément, et c'est le compromis assumé : **les serveurs Resend sont hébergés aux États-Unis** (eu-west-1 Ireland pour la region de notre domaine vérifié, mais l'entreprise est américaine). Cet arbitrage est explicitement compatible avec la doctrine RGPD du projet, qui n'est pas « UE-only » mais « pas-GAFAM », et qui assume déjà la résidence sa-east-1 (São Paulo) pour Supabase via le DPA signé le 04/05/2026 (référence TFXNN-HUMKJ-3WKP8-MZMYW) et les clauses CCT 2021/914 module 2 (controller-to-processor) effectives. La doctrine RGPD Phase 6 du projet pose que la légalité du traitement repose sur les CCT et l'absence d'engagement avec un GAFAM, pas sur la résidence géographique stricte des données.

### 1.5 La précaution UX qui justifie la spec

Un point mérite d'être noté explicitement parce qu'il a été identifié pendant la phase de cadrage de cette migration : **l'interface Resend de configuration du tracking subdomain est ergonomiquement piégeuse**. La page `/domains/<id>/tracking` du dashboard arrive dans un état où la case `Enable click tracking` est pré-cochée par défaut, alors même que la doc affirme — à juste titre — que le tracking est désactivé par défaut au niveau du domaine.

Cette contradiction apparente s'explique : la case ne prend effet qu'au moment où l'utilisateur·rice valide « Add domain » en ayant renseigné un sous-sous-domaine et ajouté le CNAME chez OVH. Tant que la page n'est pas validée intégralement, aucun tracking n'est activé. Mais le risque humain est réel : un·e admin réseau du CCLA qui entrerait sur cette page par curiosité, par mauvaise compréhension de l'interface, ou en pensant « configurer la délivrabilité », pourrait valider l'activation sans s'en rendre compte.

La doctrine cible est donc plus précise qu'un simple « tracking off par défaut » : c'est **interdiction politique de valider cette page, même partiellement, même par curiosité**. Cette interdiction est inscrite comme garde-fou opérationnel au §6 de la présente spec, et fera l'objet d'une mention dans le manuel admin réseau d'AnarBib (chantier ultérieur).

### 1.6 Articulation avec la doctrine du projet

Cette migration s'inscrit dans la continuité directe de plusieurs doctrines déjà arrêtées dans le projet, qu'elle ne modifie pas mais qu'elle applique :

- **Doctrine RGPD Phase 6** (acquis 04-05/05/2026) : le projet assume une stack non-GAFAM avec sous-traitants explicitement listés dans `docs/legal/registre-traitements.md` et couverts par les clauses CCT 2021/914 module 2. La migration ajoute Resend à cette liste en substitution de Brevo (cf. §7.1 ci-dessous).
- **Ligne rouge v13 sur la sécurité** : *« aucun durcissement de sécurité sans lecture du dump à jour »*, et sa précision opérationnelle v13.5 : *« tout paquet créant une vue ou une RPC doit s'achever par un get_advisors security, et appliquer un correctif si nouveau ERROR ou WARN apparaît. »* La présente migration ne crée ni vue ni RPC, mais le principe méthodologique (vérification finale automatisée) s'applique : la spec prévoit en §6 un test runtime systématique des 9 EF avant clôture du chantier.
- **Doctrine procédurale du chantier linter** (récap 11-12/05/2026, §3.1) : *« un fix à la fois, validation entre chaque ».* Cette migration touche au transport mail commun à 9 fonctions critiques de la chaîne de notifications. Toute régression silencieuse coûterait cher en confiance utilisateur·rice. La séquence en paquets (§5) applique strictement ce principe.

La spec ne propose donc aucune doctrine nouvelle. Elle applique la doctrine existante à un chantier de migration provider, en tirant les conséquences opérationnelles de deux constats : (a) Brevo a montré, par un incident concret, qu'il est structurellement incompatible avec la doctrine ; (b) Resend permet de tenir la doctrine, à condition de poser un garde-fou opérationnel sur l'UX de configuration du tracking.

---

## §2 — État existant et cartographie technique

### 2.1 Inventaire des Edge Functions concernées

Le projet AnarBib expose actuellement 18 Edge Functions actives sur le projet Supabase `uflwmikiyjfnikiphtcp`. Neuf d'entre elles envoient des mails via Brevo. Elles sont listées ci-dessous, avec leur architecture mail (transport partagé `_shared/transport/email.ts` ou implémentation inlinée), leur version courante au 13/05/2026, et leur déclencheur (cron, trigger DB, appel utilisateur·rice).

| EF | Version | Architecture | Déclencheur | Rôle |
|---|---|---|---|---|
| `notify-event` | v170 | Transport partagé | Trigger DB `trg_team_outbox_dispatch` via vault `WEBHOOK_SECRET_NOTIFY_EVENT` | Dispatcher central de notifications transactionnelles (réservations, emprunts, profils, team, network) |
| `notify-internal-task` | v151 | Transport partagé | Trigger DB sur `painel_internal_tasks` via vault `WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK` | Notifications de tâches internes Painel (invitations, rappels, événements task-level) |
| `register` | v194 | **Inliné, design système propre** | Appel direct frontend (CriarContaPage) | Création de compte lecteur·rice + envoi mail de bienvenue + mail interne biblio + mail admin |
| `notify-library-request` | v149 | Inliné | Trigger DB `trg_library_requests_notify` → `fn_enqueue_library_request_notification` via `pg_net` | Notification à la coordination réseau d'une demande institutionnelle de bibliothèque |
| `notify-weekly-report` | v142 | À inspecter en M.0 | Cron `pg_cron` hebdomadaire | Rapport hebdomadaire d'activité par bibliothèque |
| `notify-network-weekly-report` | v140 | À inspecter en M.0 | Cron `pg_cron` hebdomadaire (dormant) | Rapport hebdomadaire d'activité au niveau réseau (en attente paquets E/F admin réseau) |
| `notify-mid-loan-reading` | v132 | À inspecter en M.0 | Cron `pg_cron` quotidien | Messages en milieu d'emprunt (suggestion de lecture, encouragement) |
| `notify-document-permission-request` | v131 | À inspecter en M.0 | Trigger DB sur demandes de permission sur ressources numériques | Notification d'une demande d'accès à un document avec droits restreints |
| `notify-interlibrary-loan` | v130 | À inspecter en M.0 | Trigger DB sur demandes de prêt inter-bibliothèques | Notification de prêt inter-bibliothèques (chantier #10 fédération, partiellement activé) |

Les neuf fonctions partagent quatre traits techniques : (a) elles appellent toutes l'endpoint `https://api.brevo.com/v3/smtp/email` ; (b) elles utilisent toutes le secret `BREVO_API_KEY_NOTIFICATIONS` (ou ses variantes par familles fonctionnelles, cf. §2.3) ; (c) elles envoient depuis le sender configuré dans la variable `SENDER_EMAIL` (`anarbib@anarbib.org` actuellement) ; (d) elles sont toutes verify_jwt=false sauf `register`, qui exige un JWT parce qu'elle est appelée directement depuis le frontend.

Les sept autres EF actives (`read-pdf`, `bn_isbn_lookup`, `probe-partner-catalog`, `process-partner-catalog-import`, `read-digital-asset`, `catalog_metadata_lookup`, `fetch-url-metadata`, `login`, `mail-i18n-test`) n'envoient pas de mails et restent hors périmètre de cette migration.

### 2.2 État de l'architecture mail — hybride à clarifier

Deux EF — `notify-event` et `notify-internal-task` — utilisent un transport mail partagé propre situé dans `supabase/functions/<ef>/_shared/transport/email.ts`. Ce module expose une API stable :

- `sendBrevoEmail(opts)` — appel HTTP vers `api.brevo.com/v3/smtp/email`, le point d'application unique de la bascule provider.
- `safeSendEmail(target, subject, html, text, label, context)` — wrapper défensif qui gère les cas d'envoi désactivé (`transport_disabled_reason`), les emails vides ou invalides, et retourne un résultat structuré `{ok, label, email, response?, error?, skipped?, reason?}`.
- `skippedEmailResult(label, reason, email?)` — formatage uniforme des résultats d'envoi sautés (par exemple si `task_alerts_enabled=false`).
- `userTargetFromProfile(profile)`, `adminTarget(context)` — résolution des destinataires depuis un profil ou un contexte de bibliothèque.
- `sendAdminNotification(opts)` — envoi du mail interne d'audit/copie à la coordination locale.

Cette architecture est l'aboutissement d'un chantier de refactorisation des mails (paquet 6 du 5 mai 2026) qui a aligné `notify-event` et son corollaire `notify-internal-task` sur une structure homogène : `handlers/*.ts` par domaine (réservations, emprunts, profils, team, legacy, internal-task), `_shared/i18n/mail-strings.ts` comme dictionnaire à 6 locales, `_shared/mail/layout.ts` pour le rendu HTML, `_shared/mail/inline-images.ts` pour la contre-mesure logos Brevo, et `_shared/transport/email.ts` comme point unique d'envoi.

Les sept autres EF mail dupliquent partiellement ce pattern. Deux cas sont déjà clairs :

- **`notify-library-request`** : appel direct à `fetch('https://api.brevo.com/v3/smtp/email', ...)` à l'intérieur du handler principal. Le module `_shared/mail/inline-images.ts` y est dupliqué (le bug logos Brevo est corrigé localement mais sans factorisation cross-EF). Pas de wrapper `safeSendEmail`. Pas de fonction `skippedEmailResult`. Format `{requested, apiAccepted, status, responseText}` propre à cette EF.

- **`register`** : architecture inlinée *et* spécifique au cas d'usage. Cette EF expose son propre système de rendu HTML avec un design système distinct (constantes `MAIL_BRAND` avec palette rouge/noir AnarBib, fonts Arial Black / Trebuchet MS, mail shell `buildMailShell`, builders `buildUserMail` et `buildInternalMail`). Le mail de bienvenue produit visuellement est donc très différent des mails issus de `notify-event` (qui utilisent un rendu en carte sombre). La fonction `sendBrevoEmail` y est inlinée localement, avec son propre format de retour, et le helper `inlineLogosInHtml` y est appelé manuellement juste avant le `fetch`. La fonction utilise également `_shared/i18n/mail-strings.ts` (factorisation déjà acquise) et `_shared/mail/inline-images.ts` (factorisation à partir des duplications précédentes). Cette spécificité visuelle est abandonnée en M.0 au profit d'un alignement complet sur `_shared/mail/layout.ts` — cf. §4.6 pour le rationale détaillé.

Les cinq autres EF inlinées (`notify-weekly-report`, `notify-network-weekly-report`, `notify-mid-loan-reading`, `notify-document-permission-request`, `notify-interlibrary-loan`) ont été créées à des moments différents du projet et leur degré d'alignement avec le pattern partagé n'a pas encore été inspecté en détail. Le paquet M.0 (cf. §5) prévoit cette inspection comme première étape du chantier.

### 2.3 Inventaire des secrets et variables d'environnement Brevo

Les variables d'environnement liées au transport mail sont multiples, par accumulation historique. Le module `_shared/core/env.ts` de `notify-internal-task` documente le fallback en cascade entre plusieurs noms par variable. La doctrine de la migration consistera à n'en conserver qu'un seul nom par fonction, en supprimant les alias historiques.

Variables actuellement utilisées :

- **`BREVO_API_KEY_NOTIFICATIONS`** : clé d'API Brevo principale, utilisée par `notify-event`, `notify-internal-task` et probablement la majorité des EF inlinées. Cette variable disparaît intégralement après la migration.
- **`BREVO_API_KEY`** : clé d'API Brevo utilisée spécifiquement par `register` (avec fallback sur `BREVO_API_KEY_STAGING`). Disparaît également.
- **`SENDER_EMAIL`**, **`SENDER_NAME`** : sender visible des mails. Le sender bascule de `anarbib@anarbib.org` vers `no-reply@notifications.anarbib.org` (cf. §1.4 et §4).
- **`ADMIN_EMAIL`**, **`ADMIN_NAME`** : destinataire des copies admin (coordination réseau actuellement, `anarbib@proton.me`). Conservé tel quel — Resend n'impose aucune contrainte sur les destinataires.
- **`BRAND_NAME`**, **`FOOTER_TEXT`**, **`LOGO_URL`**, **`REGIMENTO_URL`**, **`LIBRARIAN_PHONE`** : variables d'habillage des mails, indépendantes du provider. Conservées sans modification.

Les secrets `WEBHOOK_SECRET_NOTIFY_EVENT`, `WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK`, et leurs équivalents pour les autres EF, sont des secrets de **sécurisation des webhooks entre Postgres et les Edge Functions** (vérification de l'en-tête `x-webhook-secret` reçu par l'EF), pas des secrets liés au provider mail. Ils sont conservés tels quels.

La migration ajoutera **un seul nouveau secret** : `RESEND_API_KEY` (cf. §4).

### 2.4 Architecture côté DB — pas de tracking persistant

Une question utile pour cadrer la spec est : **AnarBib enregistre-t-il quelque part les états d'envoi des mails (success, failure, bounce) côté DB ?**

L'inspection de la base montre que la réponse est : **non, pas de tracking persistant des envois mail**. Le système actuel fonctionne sur un mode "fire-and-forget" assumé. Plus précisément :

- La table `team_notification_outbox` enregistre les **événements à notifier** (un INSERT par event), pas les résultats d'envoi. Elle est lue par `notify-event` qui se charge ensuite du dispatching ; le résultat d'envoi est seulement loggé via `console.log` côté Edge Function et n'est pas réinjecté dans la base.
- La table `library_membership_audit` enregistre les **événements politiques** (admissions, retraits, suspensions), pas les envois mail correspondants.
- Le module `internal_task_notification_queue` (cf. `data/internal-tasks.ts`) fait exception : c'est une vraie queue avec status, retry count, dernière erreur. Elle est utilisée uniquement pour les invitations de tâches Painel, et son fonctionnement reste inchangé après la migration (le provider est encapsulé en aval du queueing).
- Aucune table de bounces, d'ouvertures, ou de clics n'existe dans le schéma. Le projet ne consomme pas ces signaux, et n'a aucun webhook entrant configuré pour les recevoir depuis Brevo.

**Question Q3 de la spec — webhooks bounces Brevo** : le dashboard Brevo expose une fonctionnalité de webhooks sortants (bounces, opens, clicks) mais le projet n'en a aucun configuré activement. Vérification à conduire en M.1 (cf. §5) en se connectant au dashboard Brevo. Si un webhook bounces y est défini sans être consommé côté code, il sera simplement débranché. Si aucun n'est défini, rien à faire.

Cette absence de tracking persistant est en soi un constat politique : AnarBib ne suit pas les engagements de ses destinataires avec les mails, ne tient pas de statistiques d'ouverture, et ne déclenche aucun comportement métier en fonction de signaux d'ouverture ou de clic. C'est conforme à la doctrine et facilite la migration : il n'y a aucune logique applicative dépendant de signaux de tracking à migrer.

### 2.5 Architecture côté frontend — aucune dépendance directe

Le frontend React (`app.anarbib.org`) n'appelle jamais directement l'API Brevo. Les seules interactions frontend / mail passent par :

- Un appel à l'EF `register` lors de la création de compte (POST avec les champs personnels), qui retourne `{ok, public_id, email_usuaria_enviado, internal_notification_enviada, ...}`.
- Des actions DB (`fn_v2_create_emprestimo_by_holdings`, `fn_v2_create_consulta_local_by_holdings`, etc.) qui insèrent dans `team_notification_outbox`, lequel déclenche le trigger `trg_team_outbox_dispatch` qui appelle `notify-event` via vault.
- Un appel à l'EF `notify-library-request` (indirectement, via le trigger DB sur `library_requests`) lors de la soumission d'une demande institutionnelle.

Aucun composant frontend ne référence Brevo, ne consomme de webhook Brevo, ni n'affiche d'état "mail envoyé" basé sur autre chose que les booléens renvoyés par `register`. La migration n'aura donc **aucun impact sur le frontend**, à l'exception d'un éventuel test de fumée à effectuer après bascule (cf. §6).

### 2.6 Synthèse de l'état existant

Trois constats opérationnels résument l'état des lieux et cadrent la suite de la spec :

**Premier constat.** L'architecture mail du projet est **hybride** : deux EF déjà alignées sur un transport partagé propre, sept EF qui inlinent leur propre `sendBrevoEmail`. Le paquet M.0 d'alignement préalable (cf. §5) ramène l'ensemble à un seul point d'application avant la bascule effective. Cette étape est jugée prioritaire sur une bascule provider-par-provider EF-par-EF, parce qu'elle rend la bascule subséquente triviale (un seul fichier à modifier) et qu'elle nettoie une dette architecturale qui n'aurait pas été traitée autrement.

**Deuxième constat.** Le projet n'a **aucune dépendance persistante** au tracking mail. Pas de stockage de bounces, pas de signaux d'ouverture remontant en DB, pas de comportement frontend dépendant de signaux Brevo. La migration ne demandera donc aucune adaptation côté logique métier, seulement côté transport.

**Troisième constat.** Le **cas `register` est singulier** et fait l'objet d'un arbitrage explicite en §4.6. Le mail de bienvenue, premier contact d'une lectrice avec AnarBib, a aujourd'hui un rendu HTML distinct des autres mails. La spec acte l'alignement complet de ce rendu sur `_shared/mail/layout.ts` au moment de M.0, transport et rendu compris. La spécificité visuelle actuelle (palette rouge/noir, fonts dédiées, `buildMailShell`) est abandonnée. Le rationale est détaillé en §4.6.

---

## §3 — Questions politiques tranchées

Six questions ont émergé du cadrage de cette migration. Quatre sont tranchées dans la présente spec, deux restent partiellement ouvertes et seront refermées au cours de l'exécution. Chaque question est présentée avec son énoncé, ses options envisagées, et l'arbitrage retenu avec son rationale.

### 3.1 Q1 — Faut-il aligner les EF inlinées avant la bascule, ou basculer EF-par-EF ?

**Énoncé.** Sept des neuf EF mail (cf. §2.1) inlinent leur propre appel à `api.brevo.com`. Deux options sont possibles pour la migration : (a) aligner ces sept EF sur le transport partagé `_shared/transport/email.ts` avant la bascule provider, puis ne toucher qu'à ce fichier au moment de la bascule ; (b) faire la bascule provider-par-provider, EF par EF, en touchant le moins de code possible et en acceptant que chaque EF garde son architecture actuelle.

**Options envisagées :**
- *Option a — Aligner d'abord, basculer ensuite.* Chantier plus long en M.0 (refacto de sept EF), mais bascule subséquente triviale (un seul fichier modifié). Refermerait une dette architecturale qui ne sera traitée autrement.
- *Option b — Bascule provider-par-provider.* Chantier plus court par paquet, mais sept paquets distincts à conduire en série, et la dette architecturale reste en place après la migration.

**Arbitrage retenu : option a.** Trois raisons. Première raison : la dette architecturale identifiée en §2 (sept EF qui dupliquent un pattern d'appel HTTP, parfois avec leurs propres copies du module `inline-images.ts`) ne sera traitée nulle part ailleurs si elle n'est pas traitée à cette occasion. La pression de la migration est l'opportunité pratique pour le faire. Deuxième raison : la bascule provider-par-provider multiplie les risques de régression silencieuse entre EF (par exemple, une EF qui reste sur Brevo pendant que les autres sont passées sur Resend, et qui se met soudain à envoyer depuis un domaine non-vérifié côté SPF). Concentrer la bascule en un point unique réduit ce risque. Troisième raison, doctrinale : la procédure « un fix à la fois » du chantier linter (récap §3.1) s'applique plus rigoureusement quand le périmètre de chaque fix est précisément cerné. L'alignement architectural et la bascule provider sont deux fix distincts qu'il est plus sain de séquencer.

**Conséquence sur la spec.** La séquence des paquets (§5) commence par M.0 — alignement préalable des sept EF inlinées sur `_shared/transport/email.ts`. La bascule provider effective intervient ensuite en M.2 (refactor du transport pour exposer un dispatch `MAIL_PROVIDER=brevo|resend`) et en M.4 (passage de la variable en production).

### 3.2 Q2 — Tracking : désactivation programmée ou garde-fou doctrinal ?

**Énoncé.** Resend désactive le tracking par défaut au niveau d'un domaine vérifié (cf. §1.4). Cependant, la page de configuration du tracking subdomain dans le dashboard arrive avec la case `Enable click tracking` pré-cochée par défaut (cf. §1.5). Faut-il (a) accepter cet état par défaut comme suffisant ; (b) inscrire un garde-fou opérationnel formel ; (c) prévoir une vérification programmatique périodique via l'API Resend pour s'assurer que le tracking reste désactivé ?

**Options envisagées :**
- *Option a — Confiance dans l'état par défaut.* Simple, mais ne protège pas contre un acte humain involontaire sur le dashboard.
- *Option b — Garde-fou doctrinal inscrit dans la spec.* Documente formellement l'interdiction et la rend opposable à toute future intervention sur le dashboard, mais n'a aucun effet contraignant technique.
- *Option c — Vérification programmatique périodique.* Appel à l'endpoint `GET /domains/{id}` de l'API Resend dans un cron Supabase qui alerte si `click_tracking` ou `open_tracking` passent à `true`. Robuste, mais charge de code à maintenir, et complexité opérationnelle pour un risque qui reste humain et hypothétique.

**Arbitrage retenu : option b, avec ouverture conditionnelle sur c.** Le garde-fou doctrinal est inscrit dans la présente spec (§6.4 ci-dessous), dans le manuel admin réseau d'AnarBib (chantier ultérieur), et dans une annexe visuelle de la spec (capture annotée de la page tracking subdomain, cf. annexe A6 en §10). La vérification programmatique de l'option c n'est pas mise en place dans le périmètre de cette migration ; elle est inscrite au backlog comme item à score faible, à activer uniquement si un futur incident révèle que le garde-fou doctrinal n'a pas suffi. La doctrine de « pas de chantier nouveau ouvert au prétexte que le système est encore observé seul » (ligne rouge v13.5) s'applique : le coût opérationnel d'un cron de surveillance n'est justifié que par un incident avéré.

**Conséquence sur la spec.** Le §6 inscrit le garde-fou doctrinal comme suit : *« Aucun·e admin·istratrice du CCLA, présent·e ou futur·e, ne valide la page `https://resend.com/domains/<id>/tracking`, même partiellement, même par curiosité. La page existe dans le dashboard mais elle est hors de la zone d'intervention admissible pour AnarBib. »* L'annexe A6 fournit une capture annotée de cette page.

### 3.3 Q3 — Webhooks bounces Brevo existants : à investiguer

**Énoncé.** Brevo expose une fonctionnalité de webhooks sortants pour signaler les bounces, les ouvertures, les clics, etc. Le projet AnarBib n'a pas de table de bounces côté DB (cf. §2.4), donc rien ne consomme activement ces signaux dans le code. Mais cela ne signifie pas qu'aucun webhook n'est configuré côté Brevo — il pourrait y en avoir un défini dans le dashboard qui pointe vers une URL obsolète ou inactive.

**Options envisagées :**
- *Option a — Présumer l'absence et ne rien faire.* Acceptable si vérifié, dangereux sinon (un webhook qui pointe vers une URL inexistante pourrait être un signal de fuite minime).
- *Option b — Inspecter le dashboard Brevo et débrancher si présent.* Étape de cadrage en M.1.

**Arbitrage retenu : option b.** La vérification est triviale (une page du dashboard Brevo à inspecter visuellement) et elle ferme proprement un doute. Si un webhook est trouvé, il sera débranché. Si aucun n'est trouvé, le constat sera consigné en annexe A2 de la spec.

**Conséquence sur la spec.** Le paquet M.1 inclut une étape « audit dashboard Brevo » qui couvre : (i) inventaire des webhooks définis ; (ii) vérification que la « link tracking » est bien active globalement (pour documentation de l'état avant migration) ; (iii) recensement de toute configuration spécifique qui devrait être restaurée ailleurs après la bascule. Le compte Brevo n'est **pas supprimé** à la fin de la migration ; il reste actif en standby comme provider de fallback (cf. M.6).

### 3.4 Q4 — Stratégie de test : staging dédié ou test en production avec mode test ?

**Énoncé.** Comment valider la bascule sans risquer la production ? Trois stratégies sont envisageables : (a) créer un environnement de staging complet (branche Supabase + frontend de staging) pour tester la bascule à blanc ; (b) tester en production avec un mode test (variable `MAIL_PROVIDER=resend` activable d'abord uniquement pour quelques EF, en parallèle avec Brevo qui continue à recevoir les requêtes pour les autres EF) ; (c) tester en production avec bascule complète et rollback préparé en cas de problème.

**Options envisagées :**
- *Option a — Staging dédié.* Le plus sûr en théorie, mais le projet ne dispose pas d'un staging complet de bout en bout. Créer un staging entièrement représentatif (avec ses propres secrets, son propre domaine vérifié dans Resend, son propre frontend déployé) serait un chantier dans le chantier.
- *Option b — Mode test parallèle.* Le wrapper `sendEmail(payload, opts)` du §4 supporterait un dispatch par EF via une variable `MAIL_PROVIDER_<EF_NAME>` (par exemple `MAIL_PROVIDER_REGISTER=resend` pendant que `MAIL_PROVIDER=brevo` reste le défaut). Permet de tester en production sur une EF à faible volume avant de basculer les autres.
- *Option c — Bascule complète avec rollback.* Le wrapper supporte une bascule globale via `MAIL_PROVIDER`. Si problème détecté, on rebascule en `brevo` en une seconde et on diagnostique.

**Arbitrage retenu : option b puis option c.** Le mode test parallèle (b) est utilisé en M.3 pour valider la bascule sur les EF à faible volume et à faible enjeu (typiquement `notify-internal-task` qui n'est pas critique pour le parcours utilisateur). Une fois la confiance acquise sur deux ou trois EF, la bascule globale (c) est appliquée en M.4 avec rollback préparé. Cette stratégie a deux avantages : elle évite le coût d'un staging dédié (qui resterait à maintenir après la migration), et elle teste réellement en conditions de production avec de vrais destinataires consentants (les comptes admin du CCLA pour les premiers tests, puis ouverture progressive).

**Conséquence sur la spec.** Le wrapper `sendEmail` exposé en §4 supporte deux variables d'environnement : `MAIL_PROVIDER` (global, défaut `brevo` jusqu'en M.4) et un éventuel override par EF (`MAIL_PROVIDER_<EF>`) si une bascule fine est nécessaire en M.3. En pratique, l'override par EF est documenté comme outil de diagnostic, pas comme état stable.

### 3.5 Q5 — Rétention des logs : Resend dashboard ou Supabase ?

**Énoncé.** Resend conserve dans son dashboard 30 jours de logs d'envoi (status, destinataires, body éventuel selon la configuration). Côté Supabase, les logs Edge Function ont une rétention par défaut de 7 jours sur le plan actuel. La question pratique : où chercher en cas d'incident, et faut-il dupliquer ?

**Options envisagées :**
- *Option a — Conserver les logs uniquement dans Resend.* Suffisant pour 30 jours, suffit pour la majorité des incidents qui se diagnostiquent dans les jours qui suivent.
- *Option b — Conserver les logs uniquement dans Supabase.* Plus court (7 jours), mais permet une corrélation directe avec les logs des autres EF et des triggers DB. Inconvénient : les destinataires des mails n'apparaissent pas en clair dans les logs Supabase actuels (les EF font des `console.log` mais pas systématiques).
- *Option c — Conserver dans les deux.* Pas de coût supplémentaire (les deux sont disponibles par défaut), permet de croiser les sources.

**Arbitrage retenu : option c, sans modification.** Les deux sources de logs continuent à fonctionner sans intervention. Le dashboard Resend devient la source principale pour les questions « ce mail a-t-il été envoyé ? a-t-il bouncé ? est-il en attente ? » (questions provider-side). Les logs Supabase restent la source principale pour les questions « l'EF a-t-elle été appelée ? a-t-elle décidé de skipper l'envoi ? quelle policy était active ? » (questions code-side). Aucun stockage applicatif des logs en DB n'est ajouté.

**Conséquence sur la spec.** La procédure d'audit post-bascule (§6) précise les deux sources à consulter et la procédure de corrélation. Le manuel admin réseau (chantier ultérieur) référencera également ces deux sources.

### 3.6 Q6 — Sender visible : conservation de `anarbib@anarbib.org` ou bascule sur `no-reply@notifications.anarbib.org` ?

**Énoncé.** Le sender Brevo actuel est `anarbib@anarbib.org`, qui transite par le domaine `anarbib.org` validé dans Brevo. Le domaine vérifié dans Resend est `notifications.anarbib.org`, pas `anarbib.org`. Trois options : (a) conserver `anarbib@anarbib.org` côté Resend, ce qui exige de vérifier également `anarbib.org` dans Resend (procédure DNS supplémentaire chez OVH) ; (b) basculer le sender sur `no-reply@notifications.anarbib.org` (réutilisation du domaine déjà vérifié, pas de DNS supplémentaire) ; (c) prendre une troisième forme, par exemple `notifications@anarbib.org`.

**Options envisagées :**
- *Option a — Conserver `anarbib@anarbib.org`.* Préserve la continuité visible pour les destinataires habituels. Coût : ajouter SPF/DKIM/DMARC pour Resend sur `anarbib.org`, ce qui demande des modifications DNS chez OVH qui peuvent prendre du temps à propager. Risque mineur : un mail qui mentionne `anarbib@anarbib.org` comme destination de réponse peut prêter à confusion avec un usage que `anarbib@anarbib.org` n'a pas effectivement (le reply-to des mails est piloté indépendamment côté `library_email_identity`).
- *Option b — `no-reply@notifications.anarbib.org`.* Sender immédiatement utilisable (domaine déjà vérifié le 07/05/2026). Petite rupture visible pour les destinataires habituels qui pourraient marquer comme spam. La forme `no-reply@` est claire sur la nature transactionnelle du mail.
- *Option c — `notifications@anarbib.org`.* Idem option a sur les contraintes DNS, mais avec une forme plus parlante que `anarbib@`. Pas d'argument fort par rapport à b.

**Arbitrage retenu : option b.** Trois raisons. Première raison : le domaine `notifications.anarbib.org` est déjà vérifié dans Resend depuis le 07/05/2026, sans aucune action DNS supplémentaire à conduire. Cela rend M.1 plus rapide. Deuxième raison : la forme `no-reply@` énonce clairement la nature transactionnelle, ce qui est conforme à la réalité (la réponse à ces mails est dirigée vers le `replyTo` configuré par bibliothèque dans `library_email_identity`, pas vers le sender). Troisième raison : la rupture de continuité visible avec l'ancien sender est compensée par un *préavis* (cf. §7.3 sur la communication aux coordinations locales) et par un *en-tête prominent* dans les premiers mails post-bascule rappelant le changement.

**Conséquence sur la spec.** La variable `SENDER_EMAIL` est mise à `no-reply@notifications.anarbib.org` en M.1. La variable `SENDER_NAME` reste `Biblioteca da rede AnarBib` (ou la valeur dérivée du contexte par bibliothèque, cf. `_shared/context/library-mail-routing.ts`). Une note de migration est envoyée aux coordinations locales actives en M.5 (cf. annexe A5).

### 3.7 Synthèse des questions tranchées

| Q | Question | Arbitrage | Statut |
|---|---|---|---|
| Q1 | Alignement préalable ou bascule EF-par-EF ? | Alignement préalable (M.0) | Tranchée |
| Q2 | Doctrine tracking | Garde-fou doctrinal (§6.4 + annexe A6) | Tranchée |
| Q3 | Webhooks bounces Brevo existants | Audit dashboard en M.1 (annexe A2) | Tranchée (audit à faire) |
| Q4 | Stratégie de test | Mode test parallèle (M.3) puis bascule globale (M.4) | Tranchée |
| Q5 | Rétention logs | Conservation des deux sources (Resend + Supabase) | Tranchée |
| Q6 | Sender visible | `no-reply@notifications.anarbib.org` | Tranchée |

---

## §4 — Architecture cible

L'architecture cible se résume en une formule : **un seul point d'application provider, dispatché par variable d'environnement, et conservé tel quel pendant toute la période de coexistence Brevo/Resend**. Le code applicatif (handlers de domaine, rendu HTML, i18n, contextes de bibliothèque) reste strictement inchangé. Seul le transport bascule.

Cette §4 décrit la structure du wrapper, la signature des fonctions, le dispatch, l'organisation des fichiers, et les contrats de retour. Elle ne décrit pas la procédure de mise en place — celle-ci est en §5.

### 4.1 Principe directeur : un wrapper neutre, deux implémentations

Le module `supabase/functions/_shared/transport/email.ts` expose une **API stable** consommée par tous les handlers de domaine. Cette API ne mentionne ni Brevo, ni Resend — elle parle uniquement de mail. La sélection du provider est interne au module et s'opère via la variable d'environnement `MAIL_PROVIDER` (valeurs admises : `brevo`, `resend` ; défaut : `brevo` jusqu'en M.4, puis `resend` à partir de M.4).

Le code qui appelle `sendEmail(...)` ne sait pas, et n'a pas besoin de savoir, quel provider est en jeu. Cette neutralité permet :

- La bascule globale en modifiant une seule variable d'environnement, sans redéploiement de code (M.4).
- Le rollback express en moins d'une minute si un incident est détecté après bascule (cf. annexe A4).
- La coexistence transitoire pendant la période de vérification (M.5) : si un problème est détecté côté Resend pour une EF spécifique, la variable globale peut être ramenée à `brevo` sans toucher au code.
- La suppression future de Brevo à terme (M.6) en supprimant simplement l'implémentation `sendViaBrevo` et la branche correspondante du dispatcher.

### 4.2 Signature de l'API publique

Le module `_shared/transport/email.ts` après refactor expose les fonctions suivantes :

```typescript
// Type de la cible (destinataire)
interface MailTarget {
  email: string;
  name?: string;
}

// Type du résultat d'envoi (uniforme entre providers)
type SendResult =
  | { ok: true; label: string; email: string; provider: 'brevo' | 'resend'; providerMessageId?: string }
  | { ok: false; label: string; email?: string; provider: 'brevo' | 'resend'; error: string }
  | { ok: false; label: string; email?: string; skipped: true; reason: string };

// Options d'envoi (héritées du contrat actuel)
interface SendEmailOptions {
  target: MailTarget;
  subject: string;
  html: string;
  text: string;
  label?: string;                       // par défaut "email" (utilisé pour les logs)
  context?: LibraryNotificationContext; // contexte de routing par bibliothèque
}

// Point d'entrée principal — dispatch interne sur MAIL_PROVIDER
export async function sendEmail(opts: SendEmailOptions): Promise<SendResult>;

// Wrapper défensif (héritage de safeSendEmail actuel)
export async function safeSendEmail(
  target: MailTarget | null,
  subject: string,
  html: string,
  text: string,
  label?: string,
  context?: LibraryNotificationContext
): Promise<SendResult>;

// Helpers de cible (inchangés)
export function userTargetFromProfile(profile: ProfileRow): MailTarget | null;
export function adminTarget(context: LibraryNotificationContext): MailTarget | null;

// Mail admin (inchangé côté API, dispatché côté implémentation)
export async function sendAdminNotification(opts: {
  subject: string;
  title: string;
  introHtml: string;
  details?: Array<{ label: string; value: string }>;
  context: LibraryNotificationContext;
}): Promise<SendResult>;

// Résultat de skip uniforme (inchangé)
export function skippedEmailResult(
  label: string,
  reason: string,
  email?: string
): SendResult;
```

Trois points méritent d'être notés :

**Premier point.** La signature de `safeSendEmail` reste strictement identique à l'actuelle (cf. `notify-internal-task/_shared/transport/email.ts`). Les handlers de domaine n'ont à modifier ni leurs imports, ni leurs appels. La refactorisation est invisible côté code applicatif.

**Deuxième point.** Le type `SendResult` est désormais uniformisé entre providers : tout résultat de succès retourne `{ok: true, provider, providerMessageId?}`. Le champ `providerMessageId` est l'identifiant retourné par Brevo (`messageId` dans le body de réponse) ou par Resend (`id` dans le body de réponse), normalisé sous un nom unique pour faciliter la corrélation avec les dashboards. Côté Brevo, c'est `<24-char-hex>@smtp-relay.brevo.com` ; côté Resend, c'est un UUID préfixé.

**Troisième point.** La fonction `sendBrevoEmail` actuellement exportée disparaît de l'API publique. Elle existe encore en interne (cf. §4.4 ci-dessous) comme implémentation du provider, mais elle n'est plus importable depuis les handlers. Tout appel direct est remplacé par `sendEmail(...)`. C'est la condition qui rend la bascule en M.4 réellement triviale : à ce moment-là, plus aucun handler ne référence `sendBrevoEmail`.

### 4.3 Organisation des fichiers après refactor

Aujourd'hui le code mail vit dans trois EF avec degrés d'alignement variables. Après M.0 et M.2, l'organisation cible est la suivante (les sept EF inlinées sont alignées sur `notify-event` et `notify-internal-task`) :

```
supabase/functions/
├── _shared/                               # PARTAGÉ entre toutes les EF mail
│   ├── transport/
│   │   ├── email.ts                       # API publique (sendEmail, safeSendEmail, ...)
│   │   ├── email_brevo.ts                 # Implémentation Brevo (sendViaBrevo)
│   │   └── email_resend.ts                # NOUVEAU — implémentation Resend (sendViaResend)
│   ├── mail/
│   │   ├── layout.ts                      # renderEmail() — rendu HTML générique
│   │   └── inline-images.ts               # Contre-mesure logos (conservée pour Brevo,
│   │                                      #   inactive sous Resend mais inoffensive —
│   │                                      #   cf. §4.5 ci-dessous)
│   ├── i18n/
│   │   └── mail-strings.ts                # Dictionnaire 6 locales (inchangé)
│   ├── context/
│   │   ├── library-notification-context.ts
│   │   ├── library-mail-routing.ts
│   │   └── policies.ts
│   ├── shared/
│   │   ├── branding.ts
│   │   └── format.ts
│   └── core/
│       └── env.ts                         # Variables d'environnement
│
├── notify-event/                          # Importe _shared/transport/email.ts
├── notify-internal-task/                  # Idem
├── notify-library-request/                # Aligné en M.0
├── notify-weekly-report/                  # Aligné en M.0
├── notify-network-weekly-report/          # Aligné en M.0
├── notify-mid-loan-reading/               # Aligné en M.0
├── notify-document-permission-request/    # Aligné en M.0
├── notify-interlibrary-loan/              # Aligné en M.0
└── register/                              # Cas spécifique — cf. §4.6
```

L'arborescence `_shared` au niveau supabase/functions/ est déjà utilisée par `notify-event` et `notify-internal-task`. Le chantier M.0 consiste à pointer les sept autres EF sur ces mêmes chemins partagés, en supprimant les duplications locales (notamment le `inline-images.ts` dupliqué dans `notify-library-request`).

### 4.4 Dispatch interne du wrapper

L'implémentation de `sendEmail` est strictement dispatch :

```typescript
// _shared/transport/email.ts (extrait)

import { sendViaBrevo } from './email_brevo.ts';
import { sendViaResend } from './email_resend.ts';

const MAIL_PROVIDER = (Deno.env.get('MAIL_PROVIDER') || 'brevo').trim().toLowerCase();

export async function sendEmail(opts: SendEmailOptions): Promise<SendResult> {
  switch (MAIL_PROVIDER) {
    case 'resend':
      return await sendViaResend(opts);
    case 'brevo':
    default:
      return await sendViaBrevo(opts);
  }
}
```

Le `default` est volontairement aligné sur Brevo : tant que la variable n'est pas explicitement positionnée, le comportement reste celui de la production actuelle. La bascule en M.4 consiste à passer `MAIL_PROVIDER=resend` dans les Edge Function Secrets du dashboard Supabase.

Les deux implémentations `sendViaBrevo` et `sendViaResend` partagent la même signature `(opts: SendEmailOptions) => Promise<SendResult>` et la même responsabilité : prendre les options, appeler l'API HTTP du provider, retourner un `SendResult` uniforme. Aucune logique métier dans ces fichiers.

L'implémentation Brevo reprend strictement le code actuel de `_shared/transport/email.ts` de `notify-event`, en remplaçant le retour custom par le retour uniforme `SendResult` :

```typescript
// _shared/transport/email_brevo.ts (extrait)

const BREVO_KEY = Deno.env.get('BREVO_API_KEY_NOTIFICATIONS');

export async function sendViaBrevo(opts: SendEmailOptions): Promise<SendResult> {
  // ... [code identique à l'actuel sendBrevoEmail, avec inlineLogosInHtml,
  //      résolution du routing via library-mail-routing.ts, etc.]
  // Retour adapté au format SendResult.
}
```

L'implémentation Resend est nouvelle. Elle prend la même forme :

```typescript
// _shared/transport/email_resend.ts (extrait — schéma indicatif)

const RESEND_KEY = Deno.env.get('RESEND_API_KEY');

export async function sendViaResend(opts: SendEmailOptions): Promise<SendResult> {
  const routing = resolveMailRouting(opts.context);
  const target = opts.target;
  
  // Validation défensive identique à Brevo
  if (!target?.email || !isValidEmail(target.email)) {
    return skippedEmailResult(opts.label || 'email', 'invalid_email', target?.email);
  }
  
  const replyTo = routing.replyToEmail
    ? routing.replyToName
      ? `${routing.replyToName} <${routing.replyToEmail}>`
      : routing.replyToEmail
    : undefined;
  
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: `${routing.senderName} <${routing.senderEmail}>`,
      to: [target.email],
      subject: opts.subject,
      html: opts.html,
      text: opts.text,
      ...(replyTo ? { reply_to: replyTo } : {}),
    }),
  });
  
  const body = await response.json().catch(() => null);
  
  if (!response.ok) {
    return {
      ok: false,
      label: opts.label || 'email',
      email: target.email,
      provider: 'resend',
      error: `Resend HTTP ${response.status}: ${JSON.stringify(body)}`,
    };
  }
  
  return {
    ok: true,
    label: opts.label || 'email',
    email: target.email,
    provider: 'resend',
    providerMessageId: body?.id,
  };
}
```

Cinq différences techniques avec Brevo méritent d'être notées :

| Point | Brevo | Resend |
|---|---|---|
| Endpoint | `POST /v3/smtp/email` | `POST /emails` |
| Authentification | Header `api-key: <key>` | Header `Authorization: Bearer <key>` |
| Format `from` | Objet `{name, email}` | String `Name <email>` |
| Format `to` | Tableau d'objets `[{email, name?}]` | Tableau de strings `[email]` |
| Format `reply_to` | Objet `{name, email}` | String `Name <email>` |

Aucune de ces différences n'est exposée à l'API publique. Elles sont absorbées par `sendViaResend`.

### 4.5 Que devient `inline-images.ts` après bascule ?

Le module `_shared/mail/inline-images.ts` a été créé en mai 2026 (paquet 6 / commit du 06/05/2026) pour contourner la réécriture forcée des images par Brevo (cf. §1.2). Sous Resend, cette contre-mesure devient sans objet : Resend ne réécrit pas les balises `<img src=...>` par défaut, à condition de ne pas créer de tracking subdomain (cf. §3.2 — garde-fou doctrinal).

Deux options sont envisageables :

- *Option a — Désactivation conditionnelle.* `inline-images.ts` est appelé uniquement dans `sendViaBrevo`, pas dans `sendViaResend`. Code mort sous Resend.
- *Option b — Conservation inconditionnelle.* `inline-images.ts` est appelé dans les deux providers. Sous Resend, il inline les logos sans bénéfice fonctionnel particulier, mais sans dommage non plus.

**Arbitrage retenu : option b.** L'inline base64 des logos n'a aucun coût opérationnel notable (les logos sont en cache après le premier envoi, taille modeste), et la conservation inconditionnelle garantit que **les archives mail des destinataires conservent leurs logos durablement**, indépendamment du fait que le provider soit Brevo ou Resend, du fait que le bucket Supabase Storage change d'URL un jour, ou de tout autre événement de durée de vie longue. C'est une propriété d'archivage indépendante du tracking. Conservation inconditionnelle, donc.

### 4.6 Le cas `register` — alignement complet, refonte visuelle incluse

Comme noté en §2.2 et §2.6, `register` dispose actuellement de son propre système de rendu HTML (`buildMailShell`, `MAIL_BRAND` rouge/noir, fonts Arial Black / Trebuchet MS, builders `buildUserMail` et `buildInternalMail`) qui produit un mail de bienvenue visuellement distinct des autres mails du projet. Ce design système avait été conçu pour donner au mail de bienvenue une charge symbolique de premier contact.

**La présente spec acte que cette spécificité visuelle est abandonnée en M.0**, au profit d'un alignement complet sur le rendu en carte sombre de `_shared/mail/layout.ts` (`renderEmail`) utilisé par toutes les autres EF mail du projet.

**Trois raisons à cet arbitrage.**

Première raison, architecturale. La dette identifiée en §2 (sept EF qui dupliquent le pattern d'envoi) inclut, dans le cas de `register`, une duplication doublement structurelle : non seulement la fonction `sendBrevoEmail` est inlinée, mais c'est aussi un système de rendu HTML entier qui vit en parallèle de `_shared/mail/layout.ts`. Aligner uniquement le transport en M.0 et laisser le rendu à un chantier ultérieur reviendrait à reporter à plus tard la moitié du travail, exactement le scénario que la procédure « un fix à la fois » (récap chantier linter §3.1) cherche à éviter. La doctrine retenue en Q1 (§3.1 de la présente spec) — *« aligner d'abord, basculer ensuite »* — s'applique à la totalité de l'alignement, pas seulement au transport.

Deuxième raison, doctrinale. Le rendu en carte sombre de `renderEmail` n'est pas une dégradation par rapport au design rouge/noir de `register`. C'est le rendu **utilisé pour tous les autres mails du projet**, y compris les mails de cooptation, de retrait collectif, et de notifications transactionnelles. Si ce rendu suffit pour porter ces communications-là, il suffit aussi pour porter le mail de bienvenue. La cohérence visuelle complète de la chaîne de notifications a une valeur propre : un destinataire reconnaît immédiatement un mail AnarBib, indépendamment de la nature de l'événement notifié.

Troisième raison, pratique. Le rendu actuel de `register` repose sur des dépendances qui ne sont pas factorisées (palette de couleurs, fonts, builders de cartes d'info, builders de boutons d'action). Ces dépendances seraient à dupliquer ou à factoriser au moment où une autre EF aurait besoin d'un look similaire. Dans la pratique, aucune autre EF n'a manifesté ce besoin depuis avril 2026. Le coût de maintenance de cette spécificité ne se justifie pas par un usage prévu.

**Conséquences concrètes du M.0 pour `register` :**

- La fonction `sendBrevoEmail` actuellement inlinée dans `register/index.ts` est supprimée et remplacée par des appels à `sendEmail(...)` depuis `_shared/transport/email.ts`.
- Les builders `buildMailShell`, `buildUserMail`, `buildInternalMail` sont supprimés.
- Les constantes `MAIL_BRAND` (palette, fonts) sont supprimées.
- Le rendu du mail de bienvenue passe par `renderEmail({preheader, title, greeting, introHtml, details, footerHtml, context})` de `_shared/mail/layout.ts`, comme tous les autres mails du projet.
- Le contenu sémantique (les clés i18n `welcome.title`, `welcome.subject`, `welcome.context.standard`, `welcome.context.initial`, `welcome.publicIdLabel`, `welcome.tempPasswordLabel`, `welcome.libraryRequest.cta`, etc.) est préservé tel quel. La refonte porte sur le contenant visuel, pas sur le contenu textuel.
- Le bouton d'action « Iniciar solicitação da biblioteca » (cas signup_without_library) doit conserver son caractère prominent. Si `renderEmail` ne supporte pas nativement un encart d'action avec bouton, une extension mineure de `_shared/mail/layout.ts` est inscrite en sous-paquet M.0.X pour ajouter un paramètre `actionButton?: {href, label}` au contrat de `renderEmail`. Cette extension bénéficie aussi aux autres EF qui pourraient en avoir besoin à terme (par exemple un mail de cooptation avec lien direct vers le vote).
- L'inline base64 des logos (`inlineLogosInHtml`) reste actif et est appelé désormais à l'intérieur de `sendViaBrevo` (cf. §4.5), plus directement dans `register/index.ts`.

**Risque résiduel et mitigation.** Le seul risque opérationnel est qu'un destinataire habitué à recevoir le mail de bienvenue dans son design rouge/noir trouve la version en carte sombre moins reconnaissable comme « mail AnarBib de bienvenue ». Ce risque est faible : (i) le volume actuel de nouveaux signups est limité (quelques par semaine), donc peu de destinataires sont concernés ; (ii) le sujet du mail (`Cadastro criado — <displayName>` ou `Cadastro inicial criado — <displayName>`) reste immédiatement identifiable ; (iii) le logo AnarBib reste prominent dans le rendu en carte sombre, garantissant la reconnaissance visuelle immédiate.

### 4.7 Variables d'environnement après refactor

Cinq variables d'environnement sont liées au transport mail après refactor. Trois sont nouvelles, deux existent déjà sous une autre forme.

| Variable | Statut | Valeur |
|---|---|---|
| `MAIL_PROVIDER` | **Nouveau** | `brevo` jusqu'en M.4, `resend` après |
| `RESEND_API_KEY` | **Nouveau** | clé API du compte CCLA chez Resend |
| `BREVO_API_KEY_NOTIFICATIONS` | Existant, conservé jusqu'en M.6 | clé API actuelle |
| `SENDER_EMAIL` | Existant, modifié en M.1 | `no-reply@notifications.anarbib.org` (au lieu de `anarbib@anarbib.org`) |
| `SENDER_NAME` | Existant, inchangé | `Biblioteca da rede AnarBib` (dérivé du contexte par bibliothèque) |

Les variables d'habillage (`BRAND_NAME`, `FOOTER_TEXT`, `LOGO_URL`, `REGIMENTO_URL`, `LIBRARIAN_PHONE`, `ADMIN_EMAIL`, `ADMIN_NAME`) restent strictement inchangées : elles sont indépendantes du provider.

Les variantes historiques (par exemple `ANARBIB_SENDER_EMAIL`, `NETWORK_SENDER_EMAIL`, `BREVO_SENDER_MAIL`, `BLMF_ADMIN_EMAIL`, etc.) sont **conservées en fallback** par le module `_shared/core/env.ts` pendant la période de migration, pour ne pas exiger un nettoyage de la configuration Supabase en même temps que la bascule provider. Elles seront nettoyées en M.6, après six semaines de coexistence stable.

### 4.8 Schéma de flux après refactor

Le flux d'un mail typique, par exemple lors d'une nouvelle réservation, se résume après refactor à :

```
Frontend AnarBib (React)
    │
    │ POST RPC api.create_reservation_v2(...)
    ▼
PostgreSQL (Supabase)
    │
    │ INSERT INTO team_notification_outbox
    │ TRIGGER trg_team_outbox_dispatch
    │
    │ pg_net.http_post(notify-event, payload, webhook_secret)
    ▼
Edge Function notify-event
    │
    │ handler reservas.ts
    │ resolveLibraryNotificationContext()
    │ renderEmail() — HTML+text via _shared/mail/layout.ts
    │
    │ safeSendEmail(target, subject, html, text, label, ctx)
    │   └── sendEmail(opts)
    │         └── switch (MAIL_PROVIDER):
    │             ├── 'brevo' → sendViaBrevo(opts)
    │             │              └── inlineLogosInHtml(html)
    │             │              └── fetch api.brevo.com/v3/smtp/email
    │             └── 'resend' → sendViaResend(opts)
    │                            └── inlineLogosInHtml(html)
    │                            └── fetch api.resend.com/emails
    ▼
Destinataire — lecteur·rice + admin local + admin réseau
```

Le seul **point de bifurcation** est le `switch` dans `sendEmail`. Tout le reste — résolution du contexte, rendu HTML, gestion des policies de désactivation, contre-mesure logos, retours uniformes — est partagé entre les deux providers. C'est cette propriété qui rend la migration **réversible par variable d'environnement**, et qui justifie l'effort d'alignement préalable de M.0.

---

## §5 — Séquence de paquets

La migration se déroule en sept paquets numérotés M.0 à M.6, conduits en série. La numérotation suit la convention AnarBib : ce chantier prendra place dans la chronologie du projet après les paquets 26 (bascule INVOKER 17 vues, prioritaire selon le point d'étape v13.5) et 27 (Phase 3 consultations, prioritaire également). Le présent chantier devient donc le paquet 28 dans la numérotation globale du projet, avec sous-paquets 28.0 à 28.6 ; pour la lisibilité de cette spec, ils sont nommés M.0 à M.6 en interne au document.

Estimation globale : entre 8 et 12 jours étalés sur deux à trois semaines, dont la moitié concentrée sur M.0 (alignement préalable des sept EF) et le reste réparti entre M.1, M.2, M.3 et M.5. M.4 (bascule effective) dure quelques minutes. M.6 (suppression de Brevo) est différé de six semaines minimum après M.5.

### 5.1 Vue d'ensemble

| Paquet | Objet | Durée estimée | Risque | Dépendances |
|---|---|---|---|---|
| M.0 | Alignement des 7 EF inlinées sur `_shared/transport/email.ts` + refonte visuelle `register` | 4-5 j | Moyen | Aucune |
| M.1 | Préalables Resend : sender, secret, audit dashboard Brevo, vérification garde-fou tracking | 0,5 j | Faible | M.0 closed |
| M.2 | Refactor du transport pour exposer `MAIL_PROVIDER`, ajout `sendViaResend` | 1 j | Faible | M.0, M.1 closed |
| M.3 | Bascule en mode test parallèle sur `notify-internal-task` | 1-2 j | Moyen | M.2 closed |
| M.4 | Bascule globale `MAIL_PROVIDER=resend` en production | 0,25 j | Moyen-élevé | M.3 validée |
| M.5 | Surveillance + corrections en 2 semaines de coexistence | 2 sem | Faible | M.4 closed |
| M.6 | Suppression de Brevo (code, secrets, compte) | 0,5 j | Faible | 6 sem après M.5 sans incident |

### 5.2 M.0 — Alignement préalable des 7 EF inlinées

**Objectif.** Refermer la dette architecturale identifiée en §2 en alignant toutes les EF mail sur le transport partagé `_shared/transport/email.ts`. À la fin de ce paquet, aucune EF n'inline plus son propre appel à `api.brevo.com`, et le mail de bienvenue de `register` utilise `renderEmail` de `_shared/mail/layout.ts` (lecture A actée en §4.6).

**Préconditions.** Aucune. Ce paquet peut démarrer immédiatement après validation de la présente spec.

**Sous-paquets.**

| Sous-paquet | Périmètre | Durée | Risque |
|---|---|---|---|
| M.0.1 | Extension de `_shared/mail/layout.ts` : ajout du paramètre `actionButton?: {href, label}` à `renderEmail`. Ce paramètre rend possible le CTA prominent du mail de bienvenue (cas `signup_without_library`) et bénéficiera à d'autres mails futurs (cooptation avec lien direct, etc.). | 0,5 j | Faible |
| M.0.2 | Alignement de `notify-library-request` : suppression de `sendBrevoEmail` inliné, suppression de la copie locale de `inline-images.ts`, import depuis `_shared/transport/email.ts`, retours uniformisés sur `SendResult`. Tests runtime via création manuelle d'une demande de bibliothèque sur staging local. | 0,5 j | Faible |
| M.0.3 | Alignement de `notify-weekly-report` et `notify-network-weekly-report` (traités ensemble car structure similaire). Inspection préalable du pattern actuel, suppression des sendBrevoEmail inlinés, alignement sur `_shared/transport/email.ts`. Tests runtime via déclenchement manuel du cron en staging. | 0,75 j | Faible |
| M.0.4 | Alignement de `notify-mid-loan-reading`. Inspection préalable, alignement, tests runtime via création d'un emprunt à mi-vie en staging. | 0,5 j | Faible |
| M.0.5 | Alignement de `notify-document-permission-request` et `notify-interlibrary-loan` (traités ensemble car ces deux EF appartiennent au chantier #10 fédération, partiellement activé). Inspection préalable, alignement, tests runtime via simulation des triggers correspondants. | 0,75 j | Faible |
| M.0.6 | Refonte du rendu de `register` : suppression de `buildMailShell`, `buildUserMail`, `buildInternalMail`, `MAIL_BRAND`. Remplacement par appels à `renderEmail` de `_shared/mail/layout.ts` avec le paramètre `actionButton` ajouté en M.0.1. Suppression de `sendBrevoEmail` inliné, import depuis `_shared/transport/email.ts`. Préservation intégrale des clés i18n existantes (`welcome.title`, `welcome.subject`, etc.). Tests runtime via signup en navigation privée sur staging local, vérification visuelle du rendu côté Thunderbird et Gmail. | 1,5 j | Moyen (refonte visuelle, nécessite validation manuelle multi-locales) |
| M.0.7 | Tests runtime end-to-end : déclenchement d'un mail par chaque EF, vérification que tous passent par `sendEmail`, que les résultats sont au format `SendResult`, que les logs Edge Function ne mentionnent plus d'appel direct à `sendBrevoEmail`. Vérification visuelle du rendu sur les 6 locales pour le mail de bienvenue refondu. | 0,5 j | Faible |

**Durée totale.** 4 à 5 jours selon la disponibilité de tests runtime sur staging local. M.0.6 est le sous-paquet le plus risqué — il vaut mieux le conduire dans une session reposée et avec un compte de test à portée de main.

**Critère de succès.** À la fin de M.0 : (i) `grep -r "api.brevo.com" supabase/functions/` ne retourne qu'une seule occurrence, dans `_shared/transport/email_brevo.ts` (préparé pour M.2) ou directement dans `_shared/transport/email.ts` (avant M.2) ; (ii) `grep -r "MAIL_BRAND" supabase/functions/` ne retourne plus aucune occurrence ; (iii) tous les mails déclenchés en test runtime sur staging passent par `sendEmail` et retournent `SendResult`.

**Méthode de livraison.** Chaque sous-paquet est un commit séparé, poussé vers Codeberg, déployé via Woodpecker. Pas de migration DB dans ce paquet (purement Edge Functions). Conformément à la doctrine établie en §6.6 du point d'étape v13.5 (« privilégier le commit + push vers Woodpecker plutôt que `apply_migration` via MCP »), aucun déploiement manuel n'est effectué via MCP. Côté Edge Functions, le déploiement passe par `supabase functions deploy <name>` en ligne de commande, ou par le pipeline Woodpecker une fois l'auto-deploy EF inscrit (cf. backlog technique).

### 5.3 M.1 — Préalables Resend

**Objectif.** Préparer Resend pour la bascule sans encore l'activer. Vérifier que tout est en place côté provider, côté secrets, côté garde-fous.

**Préconditions.** M.0 closed.

**Sous-paquets.**

| Sous-paquet | Périmètre | Durée | Risque |
|---|---|---|---|
| M.1.1 | Audit du dashboard Brevo : (i) inventaire des webhooks sortants définis (cf. Q3 §3.3) — débrancher tout webhook existant pointant vers une URL obsolète ; (ii) vérification que la link tracking est bien active globalement (état avant migration, pour traçabilité) ; (iii) recensement des configurations spécifiques qui devraient être restaurées ailleurs après bascule. Compte rendu écrit en annexe A2. | 0,25 j | Faible |
| M.1.2 | Création du secret `RESEND_API_KEY` dans les Edge Function Secrets du dashboard Supabase. La clé API est générée dans le compte Resend du CCLA, scope « sending domain `notifications.anarbib.org` only ». Validation que la clé ne donne accès à aucun autre domaine. | 0,1 j | Faible |
| M.1.3 | Mise à jour de la variable `SENDER_EMAIL` à `no-reply@notifications.anarbib.org` (cf. Q6 §3.6). Cette modification prend effet immédiatement pour les appels à Brevo en cours — Brevo accepte ce sender puisque `anarbib.org` est vérifié et que `notifications.anarbib.org` est une variante du même domaine. Si Brevo refuse, fallback temporaire sur `anarbib@anarbib.org` jusqu'à M.4. | 0,1 j | Faible (test préalable nécessaire) |
| M.1.4 | Vérification opérationnelle du garde-fou tracking : connexion au dashboard Resend, capture d'écran de la page `/domains/<id>/tracking` à inscrire en annexe A6 de cette spec. Validation visuelle que la case `Enable click tracking` est pré-cochée mais que la page n'a jamais été validée (champ Subdomain vide, pas de CNAME dans DNS OVH côté `links.notifications.anarbib.org`). | 0,1 j | Faible |

**Durée totale.** 0,5 j.

**Critère de succès.** (i) `RESEND_API_KEY` présent dans les secrets Supabase et testable via curl direct vers `api.resend.com/emails` ; (ii) compte rendu de l'audit Brevo rédigé ; (iii) garde-fou tracking documenté en annexe A6 avec capture.

### 5.4 M.2 — Refactor du transport, ajout `sendViaResend`

**Objectif.** Mettre en place le wrapper dispatch décrit en §4. Le code est en place mais inactif (la variable `MAIL_PROVIDER` n'est pas encore définie, ou définie à `brevo`).

**Préconditions.** M.0 et M.1 closed.

**Sous-paquets.**

| Sous-paquet | Périmètre | Durée | Risque |
|---|---|---|---|
| M.2.1 | Extraction de `sendBrevoEmail` (actuellement dans `_shared/transport/email.ts`) vers un nouveau fichier `_shared/transport/email_brevo.ts`. Renommage en `sendViaBrevo`. Adaptation du retour pour `SendResult` (ajout du champ `provider: 'brevo'` et `providerMessageId`). | 0,25 j | Faible |
| M.2.2 | Création de `_shared/transport/email_resend.ts` avec la fonction `sendViaResend`. Implémentation conforme au schéma indicatif §4.4. Appel à `inlineLogosInHtml` (conservation inconditionnelle, cf. §4.5). | 0,5 j | Faible |
| M.2.3 | Modification de `_shared/transport/email.ts` pour exposer `sendEmail` avec dispatch sur `MAIL_PROVIDER`. La fonction `sendBrevoEmail` exportée publiquement disparaît. La fonction `safeSendEmail` est adaptée pour appeler `sendEmail` au lieu de `sendBrevoEmail`. La signature reste identique. | 0,25 j | Faible |
| M.2.4 | Test runtime : envoi d'un mail de test avec `MAIL_PROVIDER` non-défini (défaut `brevo`), vérification que le comportement est strictement identique à avant. Aucune régression visuelle, aucune régression fonctionnelle. | 0,25 j | Faible |

**Durée totale.** 1 j.

**Critère de succès.** Le code de dispatch est en place, l'implémentation Resend existe et est testable en local via `MAIL_PROVIDER=resend supabase functions serve notify-event`. En production, `MAIL_PROVIDER` reste à `brevo` (ou non-défini = défaut `brevo`), aucune bascule effective n'a eu lieu.

### 5.5 M.3 — Bascule en mode test parallèle sur `notify-internal-task`

**Objectif.** Tester la bascule effective sur une EF à faible enjeu, sans toucher au reste de la production. La cible choisie est `notify-internal-task` parce qu'elle est : (i) à faible volume (notifications de tâches Painel uniquement) ; (ii) à faible enjeu (un mail manqué ne casse pas de parcours utilisateur·rice critique) ; (iii) déjà alignée sur le transport partagé depuis avant M.0, donc bien comprise.

**Préconditions.** M.2 closed.

**Sous-paquets.**

| Sous-paquet | Périmètre | Durée | Risque |
|---|---|---|---|
| M.3.1 | Modification du module `_shared/transport/email.ts` pour supporter un override par EF : la variable `MAIL_PROVIDER_<EF_NAME>` (par exemple `MAIL_PROVIDER_NOTIFY_INTERNAL_TASK=resend`) prend précédence sur la variable globale `MAIL_PROVIDER`. Si l'override n'est pas défini, fallback sur la globale, puis sur `brevo`. | 0,25 j | Faible |
| M.3.2 | Mise en place de l'override en production : ajout de `MAIL_PROVIDER_NOTIFY_INTERNAL_TASK=resend` dans les Edge Function Secrets. La globale `MAIL_PROVIDER` reste à `brevo`. Donc toutes les EF continuent à passer par Brevo sauf `notify-internal-task` qui bascule sur Resend. | 0,1 j | Moyen |
| M.3.3 | Test runtime : création manuelle d'une tâche interne avec invitation à un destinataire de test (compte admin du CCLA). Vérification que le mail arrive bien, qu'il est rendu correctement, qu'il apparaît dans le dashboard Resend. Vérification croisée que les autres EF continuent à passer par Brevo (vérification dans le dashboard Brevo). | 0,5 j | Moyen (rendu visuel à valider, headers à vérifier) |
| M.3.4 | Période d'observation de 3 à 5 jours en conditions réelles. Les invitations de tâches Painel partent depuis Resend, les autres mails depuis Brevo. Aucune action de la coordination si tout fonctionne. Alerte si signal de bounce ou de spam-marking inattendu côté Resend. | 3-5 j | Faible (surveillance passive) |

**Durée totale.** 1 à 2 j de travail actif + 3 à 5 j d'observation.

**Critère de succès.** Au moins une invitation de tâche reçue depuis Resend dans la boîte d'un destinataire de test, correctement rendue, sans alerte de spam, et apparaissant dans le dashboard Resend avec status `delivered`. Aucune régression sur les autres EF.

**Décision de poursuite.** Si tout est conforme, on enchaîne sur M.4. Si une régression visuelle ou fonctionnelle est détectée, on diagnostique et on corrige avant M.4, en utilisant l'override sur d'autres EF si nécessaire pour reproduire le bug en conditions parallèles.

### 5.6 M.4 — Bascule globale

**Objectif.** Activer `MAIL_PROVIDER=resend` globalement. À ce moment, l'ensemble des 9 EF mail bascule sur Resend.

**Préconditions.** M.3 validée avec au moins 3 jours d'observation sans incident.

**Sous-paquets.**

| Sous-paquet | Périmètre | Durée | Risque |
|---|---|---|---|
| M.4.1 | Vérification finale du contexte : tous les secrets en place, Resend dashboard accessible, rollback préparé (procédure A4 lue et comprise), fenêtre temporelle propice (hors heure de pointe, présence en ligne pendant 2 heures suivant la bascule). | 0,1 j | — |
| M.4.2 | Modification du secret `MAIL_PROVIDER` de `brevo` (ou non-défini) à `resend` dans les Edge Function Secrets du dashboard Supabase. Suppression du secret override `MAIL_PROVIDER_NOTIFY_INTERNAL_TASK` puisque la globale couvre désormais le cas. | 0,01 j (en secondes) | Moyen-élevé |
| M.4.3 | Validation immédiate : déclenchement manuel d'un mail de chaque type (welcome via signup test, notification réservation via création test, notification weekly via cron trigger manuel). Vérification que chacun arrive bien depuis Resend, est rendu correctement, et apparaît dans le dashboard Resend. | 1 h | Moyen |
| M.4.4 | Communication aux coordinations locales actives (BLMF + BTL) : envoi d'une note technique courte (cf. annexe A5) annonçant que les mails AnarBib partent désormais depuis `no-reply@notifications.anarbib.org` et invitant à ajouter ce sender aux contacts pour éviter le marquage en spam. | 0,1 j | Faible |

**Durée totale.** 0,25 j, étalée sur 2 à 3 heures avec présence en ligne pour réagir.

**Critère de succès.** Tous les types de mails AnarBib partent désormais depuis Resend. Aucune régression visible dans la journée suivant la bascule. Rollback disponible et préparé en cas d'incident.

**Procédure de rollback.** Décrite en annexe A4. Résumé : modifier `MAIL_PROVIDER` à `brevo` dans les Edge Function Secrets. Effet immédiat sur les EF (pas de redémarrage nécessaire). Diagnostic à conduire ensuite à froid.

### 5.7 M.5 — Surveillance et corrections

**Objectif.** Observer le comportement en conditions réelles pendant 2 semaines, corriger les éventuelles régressions, accumuler les données pour la décision M.6 (suppression de Brevo).

**Préconditions.** M.4 closed.

**Sous-paquets.**

| Sous-paquet | Périmètre | Durée | Risque |
|---|---|---|---|
| M.5.1 | Mise en place d'une routine d'observation hebdomadaire : (i) consultation du dashboard Resend pour vérifier les status d'envoi (delivered, bounced, complained) ; (ii) consultation des logs Edge Function Supabase pour vérifier l'absence d'erreurs récurrentes ; (iii) écoute des retours des coordinations locales BLMF et BTL sur la réception des mails et leur classement éventuel en spam. | 2 sem (charge légère, ~1h/sem) | Faible |
| M.5.2 | Si bounces remontent : analyse au cas par cas. Bounces hard sur des adresses obsolètes : nettoyage manuel côté `profiles`. Bounces soft : observation, pas d'action immédiate. | Variable | Faible |
| M.5.3 | Si plaintes spam : revue des en-têtes du mail incriminé, vérification SPF/DKIM/DMARC côté Resend, ajustement éventuel du sender name ou du subject. | Variable | Moyen |
| M.5.4 | Bilan écrit à 2 semaines : annexe A7 de la spec, ou si jamais cela n'apparaît pas justifié, simple note en commentaire de commit clôturant M.5. Décision : conditionner ou non la transition vers M.6. | 0,1 j | — |

**Durée totale.** 2 semaines calendaires, charge légère.

**Critère de succès.** Aucun incident bloquant. Volume de bounces et de plaintes spam comparable ou inférieur à ce qu'on observait sous Brevo (pas de baseline chiffrée disponible, donc évaluation qualitative).

### 5.8 M.6 — Suppression de Brevo

**Objectif.** Soldée l'architecture multi-provider en supprimant l'implémentation Brevo. À la fin de ce paquet, Resend est le seul provider présent dans le code et dans la configuration.

**Préconditions.** M.5 closed avec bilan favorable. Minimum 6 semaines de coexistence stable depuis M.4. Pas de décision politique en cours qui pourrait nécessiter un rollback rapide vers Brevo (par exemple, annonce d'un incident majeur côté Resend, ou évolution du modèle économique Resend qui remettrait en cause le choix).

**Sous-paquets.**

| Sous-paquet | Périmètre | Durée | Risque |
|---|---|---|---|
| M.6.1 | Suppression du fichier `_shared/transport/email_brevo.ts`. Simplification de `_shared/transport/email.ts` : la fonction `sendEmail` devient un alias direct de `sendViaResend`, la variable `MAIL_PROVIDER` n'a plus de raison d'être (mais peut être conservée pour cohérence symbolique avec valeur fixée à `resend`). | 0,25 j | Faible |
| M.6.2 | Suppression de l'inline-images appelé dans le pipeline Resend (cf. §4.5 — la conservation inconditionnelle décidée en M.0 était une assurance pendant la période de coexistence ; à terme, sous Resend seul, l'inlining n'a plus de raison d'être). Décision à reconsidérer en M.6 : peut être conservée à titre d'archivage robuste, ou supprimée pour économiser le fetch des logos. | 0,1 j | Faible (décision à trancher) |
| M.6.3 | Suppression des secrets Brevo dans le dashboard Supabase : `BREVO_API_KEY_NOTIFICATIONS`, `BREVO_API_KEY`, et toutes leurs variantes historiques (`BREVO_API_KEY_STAGING`, etc.). Vérification que plus aucun code ne lit ces variables. | 0,1 j | Faible |
| M.6.4 | Nettoyage des variantes historiques de variables d'environnement conservées en fallback pendant la migration (`ANARBIB_SENDER_EMAIL`, `NETWORK_SENDER_EMAIL`, `BREVO_SENDER_MAIL`, `BLMF_ADMIN_EMAIL`, etc.). Simplification de `_shared/core/env.ts`. | 0,1 j | Faible |
| M.6.5 | Décision sur le compte Brevo : (i) suppression complète si le projet est sûr de ne jamais y revenir ; (ii) conservation en standby (compte gratuit, pas de frais) au cas où une bascule de retour serait nécessaire. Recommandation par défaut : conservation en standby pendant 6 mois supplémentaires, puis suppression. | 0,05 j | — |

**Durée totale.** 0,5 j.

**Critère de succès.** Code mono-provider Resend, configuration nettoyée, aucune trace de Brevo dans le repo. Le compte Brevo reste éventuellement en standby pour une période transitoire.

### 5.9 Synthèse temporelle

L'ensemble du chantier s'étale sur **environ 10 semaines** entre l'ouverture de M.0 et la clôture de M.6, avec une concentration de l'effort sur les 2 à 3 premières semaines (M.0 + M.1 + M.2 + M.3 + M.4) et une longue période d'observation passive (M.5, 2 semaines) suivie d'une suspension volontaire (4 semaines minimum avant M.6).

| Semaine | Activité dominante |
|---|---|
| S1 | M.0 sous-paquets M.0.1 à M.0.4 |
| S2 | M.0 sous-paquets M.0.5 à M.0.7, début M.1 |
| S3 | Fin M.1, M.2, M.3 (mise en place et début observation) |
| S4 | Fin M.3 (observation), M.4 (bascule), début M.5 |
| S5 à S6 | M.5 (surveillance passive) |
| S7 à S10 | Suspension volontaire avant M.6 |
| S11 | M.6 (suppression Brevo) |

Cette temporalité est compatible avec la doctrine de cadence v13.5 : un seul chantier majeur à la fois, validation par session, pas de précipitation vers M.4 si M.3 montre la moindre anomalie. Si le projet a d'autres priorités stratégiques (par exemple les paquets E et F du chantier admin réseau, items #81 et #82 du backlog v6), le chantier Resend peut être suspendu à la fin de M.0 ou de M.1 et repris ultérieurement sans dette.

---

## §6 — Tests, hardenings et garde-fous opérationnels

Cette section consolide les vérifications, tests automatisés et garde-fous opérationnels qui encadrent le chantier. Elle distingue trois niveaux : (1) les tests unitaires et runtime à conduire pendant les paquets ; (2) les garde-fous techniques inscrits dans le code ; (3) les garde-fous doctrinaux inscrits dans la spec et reportés dans le manuel admin réseau.

### 6.1 Tests runtime obligatoires par paquet

Chaque paquet se conclut par un ensemble de tests runtime qui valident son livrable. Ces tests ne sont pas optionnels : ils correspondent à l'application de la précision opérationnelle v13.5 (*« tout paquet doit s'achever par une vérification finale »*) au chantier mail.

**M.0 — Tests d'alignement.** Pour chaque sous-paquet M.0.X, conduite d'un test runtime spécifique à l'EF alignée. Modèle :

- Pour les EF déclenchées par trigger DB : insertion manuelle dans la table source, vérification que le trigger appelle l'EF et que le mail arrive. Vérification que le mail conserve son rendu visuel (capture comparée avant/après refacto).
- Pour les EF déclenchées par cron : déclenchement manuel via `SELECT cron.schedule(...)` ou appel direct de la fonction via `supabase functions invoke <name>`. Vérification de l'envoi.
- Pour `register` : signup complet en navigation privée sur staging local, vérification de la réception du mail de bienvenue dans Thunderbird et Gmail, vérification du rendu sur les 6 locales (pt-BR, fr, es, en, it, de).

Sous-paquet M.0.7 dédié à un test end-to-end : déclenchement d'au moins un mail par chaque EF, et vérification que la grep `api.brevo.com` retourne strictement une seule occurrence dans le code post-refacto.

**M.1 — Tests préalables Resend.** Test direct de l'API Resend via curl :

```bash
curl -X POST 'https://api.resend.com/emails' \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "from": "AnarBib <no-reply@notifications.anarbib.org>",
    "to": ["destinataire-de-test@example.org"],
    "subject": "Test M.1 — préalables Resend",
    "html": "<p>Test M.1.</p>",
    "text": "Test M.1."
  }'
```

Vérification : réception du mail, status 200 retourné par l'API, présence d'un `id` UUID dans le body. Si la réception échoue (bounce, SPF, etc.), diagnostic via le dashboard Resend avant de poursuivre.

**M.2 — Tests de dispatch.** Test que `sendEmail` avec `MAIL_PROVIDER` non-défini se comporte comme `sendBrevoEmail` (référence pré-refacto). Comparaison : (i) déclenchement d'un mail de test via une EF quelconque ; (ii) vérification du rendu et de la livraison côté destinataire ; (iii) vérification du retour `SendResult` côté logs Edge Function.

Test en local de `MAIL_PROVIDER=resend` via `supabase functions serve` avec variable d'environnement positionnée temporairement. Vérification que le mail part bien vers Resend (apparition dans le dashboard Resend).

**M.3 — Tests de bascule partielle.** Création d'une tâche interne avec invitation, vérification que :
- Le mail part bien depuis Resend (visible dans dashboard Resend, invisible dans dashboard Brevo).
- Le rendu est conforme à ce qu'on observe sur les autres EF restées sous Brevo (cohérence du look).
- Les en-têtes du mail reçu mentionnent bien `notifications.anarbib.org` comme domaine sender et passent SPF/DKIM/DMARC (vérification via "show original" / "voir l'original" dans Gmail ou Thunderbird).

**M.4 — Tests post-bascule globale.** Test immédiat avec un mail de chaque type. La liste minimale (à conduire dans l'heure suivant la bascule) :
- 1 signup test → vérifier la réception du mail welcome.
- 1 réservation test → vérifier la réception des mails leitor + admin.
- 1 emprunt test → vérifier la réception des mails leitor + admin.
- 1 demande de bibliothèque test → vérifier la réception du mail admin réseau.
- Déclenchement manuel d'un rapport hebdomadaire → vérifier la réception.

**M.5 — Tests d'observation.** Pas de test actif, mais consultation hebdomadaire des deux sources de logs (dashboard Resend + logs Edge Function Supabase) et écoute des retours des coordinations locales.

**M.6 — Tests post-suppression Brevo.** Après suppression du fichier `_shared/transport/email_brevo.ts` : test d'envoi de chaque type de mail, vérification qu'aucune régression n'a été introduite par la simplification.

### 6.2 Tests anti-régression visuelle pour la refonte `register`

Le sous-paquet M.0.6 (refonte du rendu de `register`) est le plus exposé au risque de régression visuelle. La refonte abandonne le design système rouge/noir au profit du rendu en carte sombre de `_shared/mail/layout.ts`. Ce changement doit être validé visuellement sur les 6 locales et sur les principaux clients mail.

**Procédure de test anti-régression visuelle :**

1. Avant refacto : capture d'écran du rendu actuel du mail de bienvenue sur les 6 locales, dans Thunderbird (mode HTML), dans Gmail (web), et dans la messagerie iOS Mail si possible. Ces captures sont archivées dans `docs/specs/captures/register-avant-refacto/` (sous-dossier dédié, non versionné dans le code de prod).
2. Après refacto : mêmes captures, archivées dans `docs/specs/captures/register-apres-refacto/`.
3. Comparaison côte à côte. Vérification que :
   - Le titre `welcome.title` (ou `welcome.title.initial` pour signup sans biblio) est rendu correctement.
   - Le bouton d'action `welcome.libraryRequest.cta` (cas signup sans biblio) est prominent et cliquable.
   - Les cartes d'information (ID public, mot de passe provisoire) sont lisibles et bien contrastées sur fond sombre.
   - Le logo AnarBib est présent et bien rendu (vérification de l'inlining base64 via `inlineLogosInHtml`).
   - Les 6 locales rendent du texte sans débordement, sans bug d'encodage, sans clé i18n brute (`welcome.title` qui serait affichée littéralement, par exemple).

Cette procédure n'est pas automatisée — elle nécessite un œil humain. Elle est documentée pour que tout futur·e contributeur·rice qui voudrait toucher au rendu mail puisse refaire la même vérification.

### 6.3 DO blocks de vérification automatique

La doctrine du chantier linter (récap §3.3) impose, pour toute migration touchant à la sécurité, un DO block de vérification automatique en fin de transaction. Le présent chantier ne contient pas de migration DB (purement Edge Functions), donc les DO blocks ne s'appliquent pas directement. Mais le principe se transpose en **tests runtime auto-bloquants** en fin de chaque sous-paquet.

Modèle de test runtime auto-bloquant pour `notify-internal-task` (sous-paquet M.0.X correspondant) :

```typescript
// Test runtime exécuté en CI ou en local avant déploiement
// Ne pas inclure dans le runtime de production.

import { sendEmail, type SendResult } from './_shared/transport/email.ts';

async function testNotifyInternalTaskAligned(): Promise<void> {
  // Test 1 : sendEmail retourne SendResult avec champ provider
  const result: SendResult = await sendEmail({
    target: { email: 'test@example.invalid' },
    subject: 'Test alignement M.0',
    html: '<p>Test</p>',
    text: 'Test',
    label: 'test_alignment',
  });
  
  if (!('provider' in result)) {
    throw new Error('FAIL: SendResult should include provider field');
  }
  
  // Test 2 : grep dans le code source — aucune référence directe à api.brevo.com
  //         (vérifié manuellement avant commit, pas en runtime)
  
  // Test 3 : aucun import de sendBrevoEmail depuis l'EF alignée
  //         (vérifié par TypeScript à la compilation)
}
```

Ces tests ne s'exécutent pas en production. Ils s'exécutent localement avant push, ou en CI Woodpecker si une étape de tests Edge Function est ajoutée au pipeline (cf. backlog technique). La discipline est la même que pour les DO blocks SQL : un test qui échoue bloque le déploiement.

### 6.4 Garde-fou doctrinal — tracking Resend

Le garde-fou doctrinal de la migration, énoncé en §1.5 et tranché en §3.2 (Q2), est inscrit ici sous sa forme formelle. Il sera également reporté dans le manuel admin réseau d'AnarBib (chantier ultérieur) et dans l'annexe A6 (capture annotée).

**Formulation formelle du garde-fou :**

> Aucun·e administrateur·rice du CCLA, présent·e ou futur·e, ne valide la page `https://resend.com/domains/<id>/tracking` dans le dashboard Resend, même partiellement, même par curiosité. La page existe dans le dashboard mais elle est hors de la zone d'intervention admissible pour AnarBib. Cette interdiction tient pour les deux raisons suivantes : (1) la validation de cette page crée un sous-sous-domaine de tracking (`links.notifications.anarbib.org` par défaut) qui réintroduit la réécriture des URLs des CTAs, exactement le comportement de Brevo que la présente migration vise à abandonner ; (2) l'interface de cette page est ergonomiquement piégeuse — la case `Enable click tracking` y est pré-cochée par défaut, et il suffit de renseigner un nom de sous-sous-domaine pour activer le tracking sans s'en rendre compte. Toute modification de cette doctrine relève d'une décision politique au niveau de la coordination réseau, pas d'une intervention technique unilatérale.

**Mécanismes de support du garde-fou :**

- Inscription dans la présente spec (§1.5, §3.2, §6.4).
- Annexe A6 : capture annotée de la page tracking subdomain, avec les zones piégeuses signalées.
- Inscription dans le manuel admin réseau d'AnarBib (chantier ultérieur, item de backlog).
- Inscription dans la doctrine RGPD du registre des traitements (`docs/legal/registre-traitements.md`, mention du sous-traitant Resend avec note sur la configuration tracking).

**Mécanisme de vérification possible (option, non retenue au stade de la spec) :**

Une vérification programmatique périodique est envisageable (cf. Q2 §3.2, option c). Elle consisterait en un cron pg_cron hebdomadaire qui appelle `GET https://api.resend.com/domains/<id>` et alerte par mail si `click_tracking` ou `open_tracking` passent à `true`. Cette option n'est pas mise en place dans le périmètre de la présente migration, conformément à la doctrine *« pas de chantier nouveau ouvert au prétexte que le système est encore observé seul »* (ligne rouge v13.5). Elle est inscrite au backlog comme item à activer uniquement si un futur incident révèle que le garde-fou doctrinal n'a pas suffi.

### 6.5 Hardenings techniques

Au-delà du garde-fou doctrinal, plusieurs hardenings techniques sont inscrits dans le code refactorisé pour prévenir les régressions silencieuses ou faciliter le diagnostic.

**H.1 — Logging structuré du provider effectif.** Le module `_shared/transport/email.ts` log au début de chaque appel à `sendEmail` la valeur effective de `MAIL_PROVIDER` lue dans l'environnement, ainsi que toute valeur d'override par EF. Format de log :

```json
{
  "event": "send_email_dispatch",
  "provider": "resend",
  "override_source": "MAIL_PROVIDER_NOTIFY_INTERNAL_TASK",
  "label": "task_invitation",
  "ef": "notify-internal-task"
}
```

Cela permet, en cas d'incident, de retrouver immédiatement quelle EF a basculé sur quel provider à quel moment, sans avoir à grep dans les logs des appels HTTP eux-mêmes.

**H.2 — Validation défensive de `MAIL_PROVIDER`.** La fonction `sendEmail` rejette toute valeur de `MAIL_PROVIDER` autre que `brevo` ou `resend` (insensible à la casse, trimmée). Si une valeur inconnue est lue (par exemple suite à une typo dans le dashboard Supabase), un avertissement est loggé et le fallback `brevo` est appliqué. L'EF ne plante pas, mais le log signale clairement le problème.

```typescript
const VALID_PROVIDERS = new Set(['brevo', 'resend']);
const raw = (Deno.env.get('MAIL_PROVIDER') || 'brevo').trim().toLowerCase();
const provider = VALID_PROVIDERS.has(raw) ? raw : 'brevo';
if (raw !== provider) {
  console.warn(`[transport] unknown MAIL_PROVIDER="${raw}", falling back to brevo`);
}
```

**H.3 — Test de fumée au démarrage de chaque EF.** Au cold start d'une EF mail, un petit test de fumée vérifie que le secret du provider courant est bien défini. Si `MAIL_PROVIDER=resend` mais `RESEND_API_KEY` absent ou vide, l'EF log un avertissement explicite au démarrage. Cela évite le scénario silencieux où le mail est tenté, échoue avec une erreur d'authentification, et n'est diagnostiqué que sur la base d'un signalement utilisateur·rice.

**H.4 — Conservation de l'inline-images sous Resend.** Décidée en §4.5, cette conservation a aussi un rôle de harden : si Resend modifiait à terme son comportement par défaut et se mettait à réécrire les images (ce qui serait une rupture contractuelle de leur part, mais reste théoriquement possible), nos archives mail seraient déjà protégées par l'inlining base64. C'est une garantie d'archivage indépendante du contrat actuel.

**H.5 — Conservation du compte Brevo en standby jusqu'en M.6.** Pendant toute la période M.4 + M.5 (au minimum 2 semaines), le compte Brevo reste actif. Le secret `BREVO_API_KEY_NOTIFICATIONS` reste dans les Edge Function Secrets. L'implémentation `sendViaBrevo` reste dans le code. Cela rend le rollback `MAIL_PROVIDER=brevo` réellement instantané (modification d'une seule variable dans le dashboard Supabase, propagation immédiate aux EF). Cf. annexe A4 pour la procédure détaillée.

### 6.6 Garde-fou doctrinal sur la procédure de migration

Trois principes méthodologiques s'appliquent strictement à la conduite du chantier, et sont rappelés ici pour mémoire :

- **Un fix à la fois (récap chantier linter §3.1).** Chaque sous-paquet M.X.Y est commité séparément, déployé séparément, testé séparément avant de passer au suivant. Pas de regroupement de plusieurs sous-paquets dans un seul commit, même s'ils paraissent connexes. Cette discipline permet, en cas de régression détectée, d'isoler exactement quelle modification l'a introduite.
- **Jamais d'`apply_migration` via MCP sur ce projet (récap §6.6 du point d'étape v13.5).** Aucune migration DB de toute façon dans le présent chantier, mais la doctrine s'étend à la philosophie générale : pas de bypass du pipeline Woodpecker. Les Edge Functions sont déployées via `supabase functions deploy <name>` en ligne de commande locale, ou via le pipeline Woodpecker une fois l'auto-deploy EF inscrit (item de backlog).
- **Validation runtime systématique avant clôture de paquet.** Chaque sous-paquet est clos uniquement après vérification runtime conforme aux protocoles de §6.1. Pas de fermeture théorique sur la base d'un commit qui compile.

### 6.7 Critères de succès cumulés du chantier

À la clôture de M.6, les critères de succès cumulés du chantier sont les suivants :

1. **Aucune référence à Brevo dans le code de production.** Vérifiable par `grep -r -i "brevo" supabase/functions/` qui ne doit retourner que des commentaires historiques (« migré depuis Brevo le DD/MM/YYYY »), pas du code actif.
2. **Aucune référence à Brevo dans les secrets Supabase.** Vérifiable dans le dashboard Supabase, section Edge Function Secrets.
3. **Cohérence visuelle de tous les mails AnarBib.** Tous les mails passent par `renderEmail` de `_shared/mail/layout.ts`. Capture comparée avant/après M.0.6 pour le mail de bienvenue archivée en annexe.
4. **Aucune régression de délivrabilité.** Pas plus de bounces ou de plaintes spam que sous Brevo (évaluation qualitative sur 6 semaines).
5. **Garde-fou tracking inscrit.** En annexe A6 de la spec, dans le manuel admin réseau (chantier ultérieur), et dans le registre des traitements RGPD.
6. **Page `https://resend.com/domains/<id>/tracking` jamais validée.** Vérifiable visuellement dans le dashboard Resend à tout moment : la section "Tracking" du domaine `notifications.anarbib.org` reste à l'état "non configuré".

Si l'un de ces critères n'est pas atteint à 6 mois post-M.6, le chantier est considéré comme partiellement raté et un post-mortem est conduit pour identifier ce qui a manqué.

---

## §7 — Impacts collatéraux

La migration touche au transport mail uniquement, mais ce transport est référencé dans plusieurs documents et configurations annexes du projet. Cette section recense les impacts à traiter au cours du chantier ou en suivi immédiat, par domaine.

### 7.1 Documentation RGPD — registre des traitements

Le projet maintient depuis la Phase 6 RGPD (acquis 04-05/05/2026) un registre des traitements à `docs/legal/registre-traitements.md`. Ce document liste les sous-traitants au sens de l'article 28 du RGPD et les bases légales associées. Brevo y figure actuellement comme sous-traitant de l'envoi de notifications transactionnelles. La migration impose plusieurs modifications.

**Modifications à apporter au registre :**

1. **Substitution Brevo → Resend dans la liste des sous-traitants**, avec mise à jour des champs : raison sociale (Resend Inc., Delaware, États-Unis), finalité (envoi de notifications transactionnelles), catégories de données traitées (adresses mail des destinataires, contenu des mails, métadonnées d'envoi), durée de conservation (30 jours pour les logs côté Resend, vs 30 jours côté Brevo — pas de changement net pour les destinataires), base légale (exécution du service, art. 6(1)(b) RGPD pour les comptes ouverts, intérêt légitime art. 6(1)(f) pour les copies admin).

2. **Mention explicite de la résidence géographique** : Resend est une entreprise américaine, hébergement principal en Europe (region eu-west-1 Ireland pour le domaine `notifications.anarbib.org`, ce qui couvre la majorité des envois). La spec note que cette résidence US assumée s'inscrit dans la doctrine déjà arrêtée du projet (cf. §1.4), où Supabase est en sa-east-1 São Paulo, et où la légalité repose sur les CCT 2021/914 module 2 (controller-to-processor) et non sur une résidence UE stricte.

3. **Mention du DPA Resend** : Resend met à disposition un Data Processing Agreement standardisé sur leur site, accessible publiquement à `https://resend.com/legal/dpa`. La date de prise d'effet du DPA pour le compte CCLA est à enregistrer (équivalent du TFXNN-HUMKJ-3WKP8-MZMYW que le projet a pour Supabase). À conduire en M.1 ou M.6 selon la disponibilité.

4. **Mention du garde-fou tracking** : ajout dans le registre d'une note explicative sur la configuration `notifications.anarbib.org` chez Resend, précisant que le tracking est désactivé et que cette désactivation est doctrinalement protégée par interdiction de validation de la page `/domains/<id>/tracking` du dashboard. Cette note vaut comme **engagement de minimisation des données** au sens de l'article 5(1)(c) RGPD.

5. **Suppression de la mention `inline-images.ts`** comme contre-mesure tracking : sous Resend, le module reste actif (cf. §4.5) mais sa raison d'être change de contre-mesure défensive à garantie d'archivage. Le registre est mis à jour en conséquence.

**Calendrier.** Modification du registre conduite en M.4 (jour de la bascule effective) ou immédiatement après. Le registre est un document politique : sa mise à jour ne peut pas attendre M.6. Une version intermédiaire peut être inscrite en M.1 avec mention « migration en cours » si la coordination réseau le souhaite.

### 7.2 Documentation RGPD — politique de confidentialité publique

Le projet n'a pas encore publié de politique de confidentialité destinée aux destinataires des mails. C'est un item du backlog RGPD identifié en mai 2026 mais non traité au stade actuel. La présente migration ne crée pas l'obligation, mais elle est l'occasion d'inscrire la liste des sous-traitants dans une formulation accessible.

**Recommandation.** Profiter de la bascule pour publier une première version courte de la politique de confidentialité sur `https://anarbib.org/confidentialite` (ou équivalent sur le site statique du projet), mentionnant : (i) que les notifications transactionnelles transitent par Resend ; (ii) que le tracking d'ouverture et de clic est désactivé sur le domaine d'envoi ; (iii) que les destinataires peuvent demander suppression de leurs données par contact à `anarbib@proton.me`.

Cette publication n'est pas un sous-paquet de la migration mais un item de backlog que la migration **rend prioritaire**. Recommandation : score backlog 8 à 10 (priorité moyenne-haute), à activer dans le mois suivant M.4.

### 7.3 Communication aux coordinations locales

La bascule effective en M.4 change le sender visible des mails (`no-reply@notifications.anarbib.org` au lieu de `anarbib@anarbib.org`). Ce changement est mineur en apparence mais peut avoir deux effets opérationnels :

- **Marquage en spam** : un destinataire dont le client mail avait appris à reconnaître l'ancien sender peut classer en spam le premier mail issu du nouveau sender. Risque limité dans le temps (le client mail apprend rapidement) mais réel pour la première semaine post-bascule.
- **Confusion sur la légitimité** : un destinataire qui reçoit un mail depuis un sender qu'il ne reconnaît pas peut hésiter sur son authenticité, surtout s'il s'agit d'un mail à enjeu (cooptation, suspension, retrait collectif).

**Note de migration aux coordinations locales (cf. annexe A5).** Une note courte est envoyée en M.4 aux coordinations BLMF et BTL, annonçant le changement de sender. Le contenu de la note couvre : (i) le motif politique de la migration (rappel synthétique du tracking imposé par Brevo) ; (ii) le nouveau sender et l'invitation à l'ajouter aux contacts pour éviter le marquage spam ; (iii) le contact en cas de mail manquant ou suspect.

Cette note est rédigée en pt-BR (langue principale des coordinations actives) et traduite en fr/es/en/it/de pour archivage. Le contenu indicatif est en annexe A5.

**Calendrier.** Envoi en M.4 immédiatement après la bascule effective. La note est elle-même envoyée depuis le nouveau sender — c'est un test de cohérence du dispositif.

### 7.4 Impacts sur le frontend AnarBib

Comme noté en §2.5, le frontend n'a aucune dépendance directe à Brevo. La seule interaction frontend / mail passe par les booléens retournés par l'EF `register` (`email_usuaria_enviado`, `library_notification_enviada`, `admin_notification_enviada`). Ces booléens restent strictement identiques après la migration : ils ne dépendent pas du provider.

**Aucune modification frontend n'est nécessaire** au titre de la migration. Le seul test frontend à conduire est un test de fumée en M.4 : signup en navigation privée → réception du mail welcome → clic sur le CTA → arrivée sur `/solicitar-biblioteca` en cas de signup sans biblio. Ce test couvre simultanément la chaîne backend (register → Resend → boîte mail) et frontend (CTA → route → page rendue).

**Note opérationnelle.** Le test de fumée frontend en M.4 doit utiliser un compte de test (par exemple `anarbib+test-m4@proton.me`) qui n'a jamais été créé auparavant. Sans cette précaution, le signup peut échouer avec `EMAIL_ALREADY_EXISTS`, ce qui masque le vrai test.

### 7.5 Impacts sur la configuration Supabase

La migration ajoute, modifie ou supprime plusieurs secrets dans les Edge Function Secrets du dashboard Supabase. Le résumé est synthétisé dans le tableau de l'annexe A2. Trois opérations principales :

- **Ajout** : `RESEND_API_KEY`, `MAIL_PROVIDER` (et éventuellement `MAIL_PROVIDER_NOTIFY_INTERNAL_TASK` temporairement en M.3).
- **Modification** : `SENDER_EMAIL` (en M.1, de `anarbib@anarbib.org` vers `no-reply@notifications.anarbib.org`).
- **Suppression** (en M.6) : `BREVO_API_KEY_NOTIFICATIONS`, `BREVO_API_KEY`, et leurs variantes historiques (`BREVO_API_KEY_STAGING`, `ANARBIB_SENDER_EMAIL`, `NETWORK_SENDER_EMAIL`, `BREVO_SENDER_MAIL`, etc.).

Les secrets liés aux webhooks Postgres-EF (`WEBHOOK_SECRET_NOTIFY_EVENT`, `WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK`, etc.) restent inchangés — ils n'ont aucun rapport avec le provider mail.

### 7.6 Impacts sur les archives mail des destinataires

Les destinataires qui auront archivé des mails AnarBib avant la migration verront, dans leurs archives, des liens CTA qui pointent vers le domaine de tracking Brevo (`sendibt3.com` ou variantes). Ces liens ont une durée de vie limitée côté Brevo : à terme, ils retourneront probablement un 404 ou une page d'erreur, ce qui rendra les vieux mails partiellement cassés.

**Aucune action corrective possible** côté AnarBib : les mails archivés sont chez les destinataires, pas chez nous. Ce point n'est mentionné ici que pour traçabilité : il s'agit d'une externalité de la décision initiale d'utiliser Brevo, qui pourrait justifier rétrospectivement la migration auprès des destinataires sceptiques (« vos vieux mails AnarBib vont casser à cause de Brevo, c'est pour ça qu'on bascule »).

Les mails envoyés après la migration auront, eux, des CTAs pointant directement vers `https://app.anarbib.org/...` sans intermédiaire de tracking. Leur durée de vie sera celle du domaine `app.anarbib.org` lui-même, c'est-à-dire la durée de vie du projet.

### 7.7 Impacts sur les tests internes et la documentation technique

Plusieurs documents internes mentionnent Brevo de manière incidente. Liste indicative des emplacements à vérifier et mettre à jour en M.6 ou immédiatement après :

- `docs/decisions/BUG_LOGOS_BREVO_TRACKER_2026-05-06.md` : ce document explique le rationale du module `_shared/mail/inline-images.ts`. Il reste pertinent comme archive historique et n'a pas besoin d'être supprimé. Une note de clôture peut être ajoutée en M.6 : « contre-mesure rendue inutile par la migration Resend, conservée pour archivage durable des logos ».
- Les éventuels READMEs des EF qui mentionneraient Brevo dans leur description. À grep en M.6.
- Le `docs/specs/spec-administrateur-reseau.md` (v0.3 du 11/05/2026) mentionne probablement Brevo dans la section sur les notifications de cooptation. À vérifier et mettre à jour.
- Les commit messages historiques mentionnant Brevo ne sont pas modifiables et restent en l'état.

Cette vérification est inscrite comme sous-tâche de M.6 (cf. §5.8).

### 7.8 Synthèse des impacts collatéraux

| Domaine | Impact | Calendrier | Sous-paquet |
|---|---|---|---|
| Registre des traitements RGPD | Substitution Brevo→Resend, mention DPA, garde-fou tracking | M.4 ou immédiatement après | M.4.4 ou hors-paquet |
| Politique de confidentialité publique | Création (item de backlog rendu prioritaire) | Mois suivant M.4 | Hors présent chantier |
| Communication coordinations locales | Note de migration en pt-BR + 5 langues archivées | M.4 | M.4.4 |
| Frontend AnarBib | Aucune modification, test de fumée seulement | M.4 | M.4.3 |
| Configuration Supabase (secrets) | Ajout, modification, suppression progressive | M.1, M.4, M.6 | M.1.2, M.4.2, M.6.3 |
| Archives mail des destinataires | Aucune action corrective possible | — | — |
| Documentation technique interne | Mise à jour mentions Brevo dans /docs | M.6 | M.6 |

---

## §8 — Critères de succès

Cette section consolide les critères de succès du chantier à plusieurs horizons temporels et selon plusieurs dimensions. Le §6.7 listait les critères techniques cumulés à clôture de M.6. La présente §8 étend cette lecture en distinguant les critères immédiats (vérifiables dans la journée de M.4), à court terme (1-2 semaines, période M.5), à moyen terme (6 mois post-M.6), et politiques (vérifiables sur la durée du projet). Chaque critère est formulé pour être vérifiable, c'est-à-dire qu'il existe une procédure ou une observation qui permet de dire « atteint » ou « non atteint » sans ambiguïté.

### 8.1 Critères immédiats — vérifiables en M.4

Ces critères doivent être atteints dans les 2 à 3 heures suivant la bascule globale (M.4.2). S'ils ne le sont pas, la procédure de rollback (annexe A4) est déclenchée sans hésitation.

| # | Critère | Procédure de vérification | Statut attendu |
|---|---|---|---|
| 8.1.1 | Le signup test envoie un mail de bienvenue via Resend | Signup en navigation privée avec compte de test ; vérifier réception ; vérifier dans dashboard Resend que le mail apparaît avec status `delivered` | Atteint |
| 8.1.2 | Le mail de bienvenue est rendu correctement après refonte (M.0.6) | Comparer le rendu reçu avec les captures de référence post-refonte (`docs/specs/captures/register-apres-refacto/`) ; tester sur Thunderbird et Gmail | Atteint |
| 8.1.3 | Une notification de réservation est envoyée via Resend | Créer une réservation test sur staging ou prod ; vérifier réception lecteur+admin ; vérifier dashboard Resend | Atteint |
| 8.1.4 | Une notification weekly est envoyée via Resend | Déclencher manuellement le cron weekly-report ; vérifier réception ; vérifier dashboard Resend | Atteint |
| 8.1.5 | Aucun mail ne part par erreur via Brevo | Consulter dashboard Brevo dans les 2h post-M.4 : il doit montrer 0 envoi sur cette période | Atteint |
| 8.1.6 | Les en-têtes SPF, DKIM, DMARC du mail reçu sont valides | Sur un mail reçu, ouvrir "show original" / "voir l'original" ; vérifier que les trois en-têtes passent (status `pass`) | Atteint |
| 8.1.7 | Le sender visible est bien `no-reply@notifications.anarbib.org` | Lecture du champ `From:` d'un mail reçu | Atteint |
| 8.1.8 | Le reply-to est correctement configuré selon la bibliothèque source | Sur un mail venant d'une biblio ayant `delivery_mode='platform_shared_local_reply'`, vérifier que le `Reply-To:` pointe vers l'email local | Atteint |
| 8.1.9 | Aucune erreur dans les logs Edge Function dans les 2h post-bascule | Consultation des logs Supabase pour les 9 EF mail | Atteint |

**Décision si un critère immédiat n'est pas atteint.** Si l'un quelconque des critères 8.1.1 à 8.1.9 échoue, la procédure de rollback (annexe A4) est exécutée immédiatement. Le diagnostic se fait ensuite à froid. Aucune tolérance sur cette liste : la fenêtre de M.4 est conçue précisément pour permettre ce rollback rapide.

### 8.2 Critères à court terme — vérifiables pendant M.5

Ces critères sont observés pendant les 2 semaines de surveillance post-bascule. Ils peuvent tolérer des incidents isolés tant que la tendance générale est conforme.

| # | Critère | Procédure de vérification | Tolérance |
|---|---|---|---|
| 8.2.1 | Aucune régression sur la délivrabilité | Comparer le taux de bounces sous Resend (visible dashboard Resend) avec le taux observé sous Brevo dans les 2 semaines précédentes | Évaluation qualitative — pas de baseline chiffrée |
| 8.2.2 | Aucune plainte de spam-marking | Écoute passive des retours coordinations locales ; consultation des éventuels rapports de complaints côté Resend | 0 plainte acceptable, 1-2 plaintes à investiguer mais pas bloquantes |
| 8.2.3 | Tous les types de mails sont envoyés au moins une fois sur la période | Audit du dashboard Resend à J+7 puis J+14 ; vérification de la présence d'au moins un mail pour chaque type (welcome, réservation, emprunt, weekly, library-request) | Couverture complète attendue à J+14 |
| 8.2.4 | Le compte Brevo reste à 0 envoi | Consultation dashboard Brevo à J+7 et J+14 | 0 envoi attendu (sauf erreur de configuration à corriger immédiatement) |
| 8.2.5 | Aucune validation accidentelle de la page tracking Resend | Vérification visuelle de la page `/domains/<id>/tracking` à J+7 et J+14 | État "non configuré" maintenu |
| 8.2.6 | Aucun incident de cold start | Consultation des logs Edge Function : pas d'erreurs `RESEND_API_KEY missing` ou équivalent au cold start | Atteint |

**Bilan à J+14 (sous-paquet M.5.4).** Si tous les critères sont atteints, la transition vers M.6 est ouverte (avec suspension volontaire de 4 semaines minimum avant clôture). Si un critère n'est pas atteint, le bilan documente le problème et propose soit un correctif (sous-paquet ad hoc), soit un report de M.6.

### 8.3 Critères à moyen terme — vérifiables à 6 mois post-M.6

Ces critères s'évaluent à long terme et déclenchent un post-mortem partiel si non atteints.

| # | Critère | Procédure de vérification | Conséquence si non atteint |
|---|---|---|---|
| 8.3.1 | Aucune référence à Brevo dans le code de production | `grep -r -i "brevo" supabase/functions/` ne retourne que des commentaires historiques de date >= M.6 | Sous-paquet de nettoyage |
| 8.3.2 | Aucun secret Brevo dans Supabase | Audit visuel du dashboard Edge Function Secrets | Suppression manuelle |
| 8.3.3 | Le registre RGPD est à jour | Lecture de `docs/legal/registre-traitements.md` : substitution Brevo→Resend effective, mention du DPA, mention du garde-fou tracking | Sous-paquet documentation |
| 8.3.4 | La politique de confidentialité publique est en ligne (recommandation §7.2) | Visite de `https://anarbib.org/confidentialite` ou équivalent | Item de backlog réactivé |
| 8.3.5 | Aucun coût mensuel Brevo ne reste facturé | Vérification du compte CCLA chez Brevo : status `inactive` ou `closed`, dernière facture à 0 € | Action administrative auprès de Brevo |
| 8.3.6 | Le garde-fou tracking est inscrit dans le manuel admin réseau | Lecture de `docs/manuel-admin-reseau.md` (chantier ultérieur) : section dédiée à la doctrine tracking Resend | Sous-paquet documentation |

### 8.4 Critères politiques — vérifiables sur la durée du projet

Ces critères ne sont pas datés. Ils décrivent l'état politique stable que la migration doit instaurer et qui doit tenir aussi longtemps qu'AnarBib utilise Resend.

| # | Critère | Procédure de vérification |
|---|---|---|
| 8.4.1 | La page `https://resend.com/domains/<id>/tracking` reste à l'état "non configuré" | Vérification visuelle à toute occasion d'intervention sur le dashboard Resend |
| 8.4.2 | Aucun cas de marquage spam systémique des mails AnarBib chez les principaux fournisseurs (Gmail, Outlook, ProtonMail) | Tests périodiques d'envoi vers des comptes-tests sur chacun de ces fournisseurs |
| 8.4.3 | Tout futur·e admin réseau du CCLA est informé·e du garde-fou tracking lors de sa cooptation | Inscription dans la procédure de cooptation (cf. spec admin-reseau v0.3) |
| 8.4.4 | Aucune décision unilatérale de réactivation du tracking n'est prise | Toute décision de modification de la doctrine doit relever d'une décision politique au niveau de la coordination réseau, traçable dans `network_admin_cross_library_actions_log` |
| 8.4.5 | La cohérence visuelle des mails AnarBib est maintenue | Tout nouveau template mail introduit dans le projet passe par `_shared/mail/layout.ts`, sans réintroduire de système de rendu parallèle |

**Critère 8.4.5 — réflexion ouverte.** Ce critère cherche à éviter que le projet reproduise dans le futur la situation pré-M.0 (une EF, en l'occurrence `register`, qui aurait son propre système de rendu HTML). Si un besoin futur exige un rendu visuel différent (par exemple un mail de campagne ou de communication militante distincte des notifications transactionnelles), la doctrine sera réexaminée à ce moment-là, et le rendu spécifique devra être factorisé dans `_shared/mail/templates/<nom>.ts` plutôt qu'inliné dans une EF.

### 8.5 Indicateurs de surveillance continue

Au-delà des critères ponctuels, trois indicateurs sont à suivre en continu après M.6 pour détecter toute dérive.

**Indicateur 8.5.1 — volume mensuel d'envois.** À consulter dans le dashboard Resend chaque début de mois. Sert à vérifier que le projet reste sous la limite du plan gratuit Resend (3 000 mails/mois) ou, le cas échéant, justifie un upgrade. Volume actuel projeté : ~200-500 mails/mois selon le rythme d'activité de la BLMF et de la BTL, large marge.

**Indicateur 8.5.2 — taux de bounces par mois.** À consulter dans le dashboard Resend. Un taux supérieur à 5% sur un mois donné mérite investigation : nettoyage de la base de données pour les adresses obsolètes, vérification SPF/DKIM/DMARC, ou contact direct avec Resend.

**Indicateur 8.5.3 — taux de plaintes spam par mois.** À consulter dans le dashboard Resend. Un taux supérieur à 0,1% (1 plainte pour 1000 envois) signale un problème de réputation à diagnostiquer. Vérifier que les destinataires n'ont pas révoqué leur consentement, que le contenu ne déclenche pas les filtres antispam, etc.

Ces trois indicateurs ne constituent pas des critères de succès au sens strict (ils ne sont pas datés et n'ont pas de seuil bloquant pour la clôture du chantier), mais ils sont à surveiller comme indicateurs de santé du dispositif sur la durée.

### 8.6 Synthèse hiérarchisée

Pour faciliter la relecture, voici une hiérarchisation des critères par impact :

**Bloquants pour la clôture de M.4 :** 8.1.1 à 8.1.9 (9 critères immédiats).
**Bloquants pour la clôture de M.5 :** 8.2.1, 8.2.3, 8.2.4, 8.2.5 (4 critères court terme).
**Bloquants pour la clôture de M.6 :** 8.3.1, 8.3.2, 8.3.3, 8.3.5, 8.3.6 (5 critères moyen terme).
**Non bloquants mais à suivre :** 8.2.2, 8.2.6, 8.3.4, et indicateurs 8.5.1 à 8.5.3.
**Politiques (durée projet) :** 8.4.1 à 8.4.5.

Si tous les critères bloquants sont atteints en temps et en heure, le chantier est considéré comme réussi. Si l'un des critères non bloquants n'est pas atteint, il est noté en bilan de session mais ne remet pas en cause la clôture du chantier.

---

## §9 — Risques

Cette section recense les risques identifiés pour le chantier, par catégorie (technique, opérationnel, politique, externe), avec évaluation qualitative de leur probabilité et de leur impact, et description de la mitigation prévue. Chaque risque est référencé R.N pour faciliter le suivi en bilan de chantier.

L'évaluation utilise une échelle simple à trois niveaux (faible, moyen, élevé) pour la probabilité et l'impact. Le produit des deux donne un risque résiduel qualitatif. Aucun chiffrage statistique n'est tenté : ces évaluations sont indicatives et orientées vers la prise de décision.

### 9.1 Risques techniques

**R.1 — Régression visuelle du mail de bienvenue après refonte M.0.6.**
Probabilité : moyenne. Impact : moyen.
La refonte du rendu `register` abandonne le design système rouge/noir au profit de la carte sombre de `_shared/mail/layout.ts`. Le risque est qu'un destinataire ne reconnaisse plus immédiatement le mail comme "mail AnarBib de bienvenue" et le classe en spam ou en non-lu.
**Mitigation.** Tests anti-régression visuelle systématiques sur 6 locales × 3 clients mail (procédure §6.2). Comparaison avant/après archivée dans `docs/specs/captures/`. Si la régression est jugée trop forte au test, le sous-paquet M.0.6 peut être étendu pour ajouter une primitive `_shared/mail/layout.ts` qui rapproche le rendu du look précédent (par exemple un mode "welcome" avec accent rouge plus marqué). Coût marginal limité.

**R.2 — Incompatibilité d'un en-tête entre Brevo et Resend non détectée en test.**
Probabilité : faible. Impact : élevé.
Les deux providers acceptent des formats légèrement différents pour `from`, `to`, `reply_to` (cf. §4.4). Si un cas limite n'est pas couvert par `sendViaResend` (par exemple un destinataire avec un caractère spécial dans le nom, ou un `replyTo` avec format particulier), des mails peuvent être rejetés silencieusement par Resend après M.4.
**Mitigation.** Tests runtime exhaustifs en M.0.7 et M.4.3 incluant des destinataires avec accents, ponctuation, et noms multipart. Conservation du dashboard Resend en surveillance pendant M.5 — un mail rejeté apparaît dans le dashboard avec status `failed` et le message d'erreur précis. Rollback rapide possible si un pattern de rejet est détecté.

**R.3 — Bug introduit par la suppression de fonctions inlinées en M.0.**
Probabilité : moyenne. Impact : moyen.
Les sept EF refactorisées en M.0 contiennent chacune leur propre code d'envoi. La factorisation vers `_shared/transport/email.ts` peut introduire des régressions si une particularité locale n'est pas reproduite par le wrapper partagé (par exemple, un format de retour spécifique attendu par le code appelant).
**Mitigation.** Tests runtime systématiques sous-paquet par sous-paquet en M.0. Discipline "un fix à la fois" (§6.6) qui permet d'identifier précisément la régression. Hardening H.1 (logging structuré du provider) qui facilite le diagnostic post-incident.

**R.4 — Échec silencieux de l'inlining base64 des logos sous Resend.**
Probabilité : faible. Impact : faible.
Le module `inline-images.ts` est conservé sous Resend (§4.5) comme garantie d'archivage. Si pour une raison inattendue (Supabase Storage indisponible, par exemple) l'inlining échoue, le code est défensif : il renvoie l'URL originale et le mail part quand même. Les logos restent visibles côté client mail, mais sans la protection d'archivage.
**Mitigation.** Comportement défensif déjà inscrit dans `inline-images.ts` (cf. paquet 6 du 06/05/2026). Surveillance des logs Edge Function pour détecter les warnings `[inline-image] fetch ... failed`. Aucune action corrective immédiate requise — c'est une dégradation gracieuse acceptable.

**R.5 — Variable `MAIL_PROVIDER` mal positionnée en production.**
Probabilité : faible. Impact : élevé.
Une typo dans le dashboard Supabase (par exemple `MAIL_PROVIDER=Resend` avec majuscule, ou `MAIL_PROVIDER=resnd`) ferait que le wrapper retombe sur le fallback `brevo` après M.6 (quand `BREVO_API_KEY_NOTIFICATIONS` aura été supprimée). Tous les mails échoueraient silencieusement.
**Mitigation.** Hardening H.2 (validation défensive de `MAIL_PROVIDER`) qui log un avertissement explicite si la valeur est inconnue. Hardening H.3 (test de fumée au cold start) qui détecte l'absence du secret du provider courant. Tests runtime post-M.6 prévus en §6.1 pour valider que tout fonctionne après suppression de Brevo.

### 9.2 Risques opérationnels

**R.6 — Bascule M.4 conduite dans une fenêtre temporelle inadéquate.**
Probabilité : faible. Impact : moyen.
Si M.4 est exécutée à un moment de forte activité (créations de comptes en série, campagne de cooptation, etc.), un incident lors de la bascule aurait un impact plus large. À l'inverse, hors heures de présence, un incident détecté trop tard fragiliserait la confiance.
**Mitigation.** §5.6 inscrit la conduite de M.4 en fenêtre temporelle propice (« hors heure de pointe, présence en ligne pendant 2 heures suivant la bascule »). Décision concrète : M.4.1 inclut une vérification préalable de l'absence d'activité utilisateur·rice en cours, et un calendrier validé entre la·le mainteneur·euse et la coordination réseau.

**R.7 — Rollback M.4 non exécuté à temps en cas d'incident.**
Probabilité : faible. Impact : élevé.
La procédure de rollback (annexe A4) est simple — modifier une variable dans le dashboard Supabase — mais elle suppose que la·le mainteneur·euse soit présent·e et réactif·ve. Si un incident est détecté tard (par exemple par un signalement utilisateur·rice 6 heures après la bascule), le rollback aura été retardé d'autant.
**Mitigation.** Présence en ligne pendant 2 heures post-bascule (cf. §5.6 et R.6). Tests immédiats au critère 8.1.1 à 8.1.9 qui couvrent les principaux types de mails dans l'heure suivant la bascule. Rollback effectif en moins d'une minute une fois décidé. La conservation de Brevo en standby (H.5) rend le rollback réversible jusqu'à M.6.

**R.8 — Confusion sur les variantes historiques de variables d'environnement.**
Probabilité : moyenne. Impact : faible.
Les variantes `ANARBIB_SENDER_EMAIL`, `NETWORK_SENDER_EMAIL`, `BREVO_SENDER_MAIL`, `BLMF_ADMIN_EMAIL`, etc., sont conservées en fallback pendant la migration (§4.7). Le risque est qu'une modification opportuniste de l'une d'elles dans le dashboard Supabase passe inaperçue, parce que le code utilise une cascade de fallback dont l'ordre n'est pas immédiatement intuitif.
**Mitigation.** Le nettoyage de ces variantes est inscrit en M.6.4. Pendant la migration, toute modification d'une variable sender ou admin doit être faite sur la variable principale (`SENDER_EMAIL`, `ADMIN_EMAIL`), pas sur une variante historique. Discipline documentée en annexe A2.

**R.9 — Pipeline Woodpecker indisponible pendant le chantier.**
Probabilité : faible. Impact : moyen.
Le déploiement des Edge Functions passe actuellement par `supabase functions deploy <name>` en ligne de commande locale, ou par le pipeline Woodpecker une fois l'auto-deploy EF inscrit. Si Codeberg ou Woodpecker connaît une indisponibilité pendant le chantier, le déploiement bascule en manuel via CLI Supabase.
**Mitigation.** La CLI Supabase v2.98.1 est pinnée et fonctionnelle. Aucun déploiement ne dépend exclusivement de Woodpecker. La doctrine §6.6 du point d'étape v13.5 (« privilégier le commit + push vers Woodpecker plutôt que `apply_migration` via MCP ») reste valide mais ne crée pas de dépendance bloquante.

### 9.3 Risques politiques

**R.10 — Validation accidentelle de la page tracking Resend.**
Probabilité : faible mais non nulle. Impact : élevé politiquement.
Le garde-fou doctrinal (§3.2, §6.4) repose sur la discipline humaine : ne jamais valider la page `/domains/<id>/tracking` du dashboard Resend. Le risque est qu'un·e admin réseau futur·e, par curiosité, par méconnaissance de la doctrine, ou par malveillance, valide cette page et active le tracking.
**Mitigation.** Inscription dans la spec (§1.5, §3.2, §6.4), dans le manuel admin réseau (chantier ultérieur), dans l'annexe A6 (capture annotée), dans le registre RGPD. Option de vérification programmatique (cron qui interroge l'API Resend) inscrite au backlog, activable si un incident révèle que le garde-fou doctrinal n'a pas suffi (cf. §3.2 option c). À noter que cette validation, si elle survenait, **serait techniquement réversible** : il suffirait de supprimer le tracking subdomain dans le dashboard pour revenir à l'état nominal. Le risque politique tient à la fenêtre temporelle pendant laquelle le tracking aurait été actif et aux mails envoyés pendant cette fenêtre.

**R.11 — Perception négative de la migration par les destinataires.**
Probabilité : faible. Impact : faible.
Certains destinataires peuvent ne pas comprendre le changement de sender, le percevoir comme un signe de manque de stabilité du projet, ou interpréter le passage d'un sender personnalisé (`anarbib@anarbib.org`) à un sender générique (`no-reply@notifications.anarbib.org`) comme une dépersonnalisation.
**Mitigation.** Note de migration claire envoyée aux coordinations locales en M.4 (cf. §7.3 et annexe A5). Cette note est rédigée en pt-BR avec traductions, explicite le motif politique (refus du tracking imposé par Brevo), et invite à ajouter le nouveau sender aux contacts. La cohérence éthique du choix Resend par rapport à Brevo est valorisée comme argument de stabilité du projet, pas d'instabilité.

**R.12 — Pression future pour réactiver le tracking au nom de l'efficacité.**
Probabilité : faible. Impact : élevé politiquement.
Il est possible qu'à terme, une demande émerge — par exemple lors d'une rencontre annuelle, ou suite à un retour de coordination locale — pour mesurer le taux d'ouverture des mails afin "d'évaluer l'efficacité des communications". Ce type de demande peut paraître pragmatique et bienveillante mais elle contredit la doctrine actuelle.
**Mitigation.** La doctrine est inscrite dans le registre RGPD comme engagement de minimisation des données, ce qui lui donne une valeur opposable au-delà de la simple convention interne. Le garde-fou est doublé : il existe à la fois comme principe (§6.4) et comme dispositif technique (configuration Resend non validée). Toute modification ne peut être unilatérale et doit faire l'objet d'une décision politique tracée (cf. critère 8.4.4). Cette spec elle-même est un document de référence à mobiliser dans cette discussion future.

### 9.4 Risques externes

**R.13 — Resend modifie unilatéralement son comportement de tracking.**
Probabilité : faible. Impact : élevé.
Bien que Resend documente actuellement que le tracking est désactivé par défaut, l'entreprise pourrait à terme modifier cette doctrine — par exemple imposer une forme de tracking minimal pour tous les domaines, ou réécrire les URLs côté infrastructure sans option de désactivation. Ce serait une rupture contractuelle implicite du choix actuel.
**Mitigation.** Surveillance des annonces Resend (newsletter, changelog) inscrite en routine légère post-M.6. Si une telle évolution survient, le wrapper `sendEmail` permet de basculer vers un troisième provider en quelques jours (introduction d'un `sendViaXxx`, mise à jour de `MAIL_PROVIDER`, transition similaire à la présente migration). Le compte Brevo peut également être réactivé si la décision se fait dans la fenêtre de standby (cf. §5.8 M.6.5).

**R.14 — Resend introduit des frais ou réduit le plan gratuit.**
Probabilité : moyenne sur le moyen terme. Impact : moyen.
Le plan gratuit Resend (3 000 mails/mois) couvre largement le volume actuel. Mais l'éditeur peut à terme réduire ce volume, imposer des frais, ou modifier les conditions d'usage. Le projet n'a pas de revenus pour absorber un coût mensuel récurrent significatif.
**Mitigation.** Surveillance mensuelle des conditions d'usage via l'indicateur 8.5.1 (volume mensuel d'envois). Si une évolution tarifaire intervient, deux options : (i) accepter le coût si modeste (quelques dollars par mois) avec décision politique de coordination réseau ; (ii) migrer vers une alternative — Postmark, Mailgun, ou self-hosted via Postfix sur le serveur OVH du CCLA. Cette dernière option est inscrite en backlog technique à score faible, activable uniquement en cas de nécessité.

**R.15 — Indisponibilité prolongée de Resend.**
Probabilité : faible. Impact : moyen à élevé selon durée.
Une panne majeure de Resend pendant plusieurs heures empêcherait l'envoi de tous les mails AnarBib. Les EF retourneraient des résultats `{ok: false, error: ...}` à chaque tentative, mais ne planteraient pas — le code est défensif.
**Mitigation.** Conservation du compte Brevo en standby pendant la période M.4 à M.6 (au moins 6 semaines, recommandation 6 mois post-M.6 cf. §5.8) qui permet un rollback rapide via `MAIL_PROVIDER=brevo`. Surveillance des incidents Resend via `status.resend.com`. Communication d'urgence aux coordinations si une panne dépasse 2 heures sur des notifications critiques (suspensions team, retraits collectifs).

### 9.5 Synthèse des risques

| # | Risque | Probabilité | Impact | Risque résiduel | Mitigation principale |
|---|---|---|---|---|---|
| R.1 | Régression visuelle mail de bienvenue | Moyenne | Moyen | Modéré | Tests §6.2 + extension possible de `_shared/mail/layout.ts` |
| R.2 | Incompatibilité en-tête Brevo/Resend non testée | Faible | Élevé | Modéré | Tests exhaustifs + surveillance dashboard M.5 |
| R.3 | Bug introduit par refacto M.0 | Moyenne | Moyen | Modéré | Discipline "un fix à la fois" + H.1 |
| R.4 | Échec inlining base64 logos | Faible | Faible | Faible | Comportement défensif déjà en place |
| R.5 | `MAIL_PROVIDER` mal positionnée | Faible | Élevé | Modéré | H.2 + H.3 + tests post-M.6 |
| R.6 | Fenêtre temporelle inadéquate pour M.4 | Faible | Moyen | Faible | Calendrier validé en M.4.1 |
| R.7 | Rollback non exécuté à temps | Faible | Élevé | Modéré | Présence 2h post-bascule + tests immédiats |
| R.8 | Confusion variantes historiques de variables | Moyenne | Faible | Faible | Discipline + nettoyage M.6.4 |
| R.9 | Pipeline Woodpecker indisponible | Faible | Moyen | Faible | Fallback CLI Supabase v2.98.1 |
| R.10 | Validation accidentelle page tracking | Faible | Élevé politiquement | Modéré | Garde-fou inscrit à 4 niveaux + option vérif programmatique |
| R.11 | Perception négative de la migration | Faible | Faible | Faible | Note de migration en M.4 |
| R.12 | Pression future pour réactiver tracking | Faible | Élevé politiquement | Modéré | Inscription registre RGPD + critère 8.4.4 |
| R.13 | Resend modifie son comportement tracking | Faible | Élevé | Modéré | Surveillance annonces + wrapper extensible |
| R.14 | Resend introduit frais / réduit plan gratuit | Moyenne (moyen terme) | Moyen | Modéré | Surveillance 8.5.1 + alternatives en backlog |
| R.15 | Indisponibilité prolongée de Resend | Faible | Moyen-élevé selon durée | Modéré | Standby Brevo + surveillance status.resend.com |

**Analyse synthétique.** Aucun risque n'apparaît avec une probabilité élevée. Les risques à impact élevé (R.2, R.5, R.7, R.10, R.12, R.13) ont tous une probabilité faible et des mitigations en place. Les risques à probabilité moyenne (R.1, R.3, R.8, R.14) ont tous un impact contenu. Le profil de risque général du chantier est **modéré**, avec des mitigations clairement identifiées pour chaque risque significatif.

Trois risques méritent une vigilance particulière au-delà du chantier lui-même : R.10 (validation accidentelle du tracking, vigilance permanente requise), R.12 (pression future doctrinale, vigilance politique sur la durée du projet), R.14 (modèle économique Resend, vigilance sur le moyen terme). Ces trois risques justifient à eux seuls les indicateurs de surveillance continue inscrits en §8.5 et la conservation du document spec comme référence active après clôture du chantier.

---

## §10 — Annexes

Cette section consolide les pièces opérationnelles de référence du chantier. Chaque annexe est conçue pour être consultable indépendamment du reste de la spec, et pour rester utile bien au-delà de la clôture du chantier — en particulier les annexes A4 (rollback), A5 (communication coordinations), A6 (capture annotée tracking) qui ont vocation à devenir des références durables.

### A1 — Mapping des payloads Brevo ↔ Resend

Tableau de conversion des champs de l'API Brevo vers ceux de l'API Resend, pour faciliter la lecture du code `sendViaResend` et le diagnostic en cas d'incident.

**Endpoints et authentification.**

| Aspect | Brevo | Resend |
|---|---|---|
| Endpoint | `POST https://api.brevo.com/v3/smtp/email` | `POST https://api.resend.com/emails` |
| Authentification | Header `api-key: <key>` | Header `Authorization: Bearer <key>` |
| Content-Type | `application/json` | `application/json` |
| Code succès | 201 Created | 200 OK |
| Body succès | `{"messageId": "<24-char-hex>@smtp-relay.brevo.com"}` | `{"id": "<UUID>"}` |

**Mapping des champs payload.**

| Champ logique | Brevo | Resend |
|---|---|---|
| Sender | `sender: {name: "X", email: "x@y.org"}` | `from: "X <x@y.org>"` |
| Destinataire principal | `to: [{email: "x@y.org", name: "X"}]` | `to: ["x@y.org"]` (array de strings) |
| Reply-to | `replyTo: {email: "x@y.org", name: "X"}` | `reply_to: "X <x@y.org>"` |
| Sujet | `subject: "..."` | `subject: "..."` |
| HTML | `htmlContent: "..."` | `html: "..."` |
| Texte | `textContent: "..."` | `text: "..."` |
| CC | `cc: [{email: "..."}]` | `cc: ["..."]` |
| BCC | `bcc: [{email: "..."}]` | `bcc: ["..."]` |
| Headers custom | `headers: {"X-Custom": "value"}` | `headers: {"X-Custom": "value"}` |

**Champs non utilisés par AnarBib mais documentés pour mémoire :**

- Brevo permet de spécifier un `templateId` pour utiliser des templates hébergés côté Brevo. AnarBib n'utilise pas cette fonctionnalité (les templates sont rendus localement par `_shared/mail/layout.ts`). Aucun équivalent direct côté Resend, ce qui ne pose pas de problème.
- Brevo permet de spécifier des `params` pour interpolation côté Brevo. AnarBib n'utilise pas cette fonctionnalité (interpolation locale via `tMail` dans `_shared/i18n/mail-strings.ts`). Aucun équivalent direct côté Resend, ce qui ne pose pas de problème.
- Brevo expose un champ `tags` pour catégoriser les envois. Resend a aussi un champ `tags`. AnarBib n'utilise ni l'un ni l'autre.
- Brevo expose `attachment` pour les pièces jointes (max 8 Mo). Resend expose `attachments` (max 40 Mo). AnarBib n'a aucun cas d'usage avec pièces jointes au stade actuel.

**Mapping des erreurs typiques.**

| Cas | Code HTTP Brevo | Code HTTP Resend | Action |
|---|---|---|---|
| Clé API invalide | 401 + `{"message": "Key not found"}` | 401 + `{"name": "validation_error", "message": "API key is invalid"}` | Vérifier secret `RESEND_API_KEY` ou `BREVO_API_KEY_NOTIFICATIONS` |
| Sender non vérifié | 400 + `{"message": "Sender ... is not valid"}` | 403 + `{"name": "validation_error", "message": "domain not verified"}` | Vérifier dashboard du provider concerné |
| Destinataire invalide | 400 + `{"message": "Invalid recipient"}` | 422 + `{"name": "validation_error", "message": "to: ..."}` | Validation côté `isValidEmail` avant appel |
| Rate limit | 429 + `{"message": "rate limit exceeded"}` | 429 + `{"name": "rate_limit_exceeded"}` | Retry avec backoff (non implémenté au stade actuel) |
| Erreur serveur provider | 500-503 | 500-503 | Log + retour `{ok: false, ...}`, pas de retry automatique |

### A2 — Secrets et variables d'environnement

État cible des secrets dans les Edge Function Secrets du dashboard Supabase, à différents moments du chantier.

**État avant chantier (pré-M.0) :**

| Variable | Valeur | Statut |
|---|---|---|
| `BREVO_API_KEY_NOTIFICATIONS` | `xkeysib-<hash>` | Actif |
| `BREVO_API_KEY` | `xkeysib-<hash>` (utilisée par `register`) | Actif |
| `SENDER_EMAIL` | `anarbib@anarbib.org` | Actif |
| `SENDER_NAME` | `Biblioteca da rede AnarBib` | Actif |
| `ADMIN_EMAIL` | `anarbib@proton.me` | Actif |
| `ADMIN_NAME` | `Equipe AnarBib` (ou variante) | Actif |
| `BRAND_NAME`, `FOOTER_TEXT`, `LOGO_URL`, `REGIMENTO_URL`, `LIBRARIAN_PHONE` | Valeurs d'habillage | Inchangés |
| `WEBHOOK_SECRET_NOTIFY_EVENT` | `<hash>` | Inchangé |
| `WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK` | `<hash>` | Inchangé |
| Autres `WEBHOOK_SECRET_*` | `<hash>` | Inchangés |
| Variantes historiques (`ANARBIB_SENDER_EMAIL`, `NETWORK_SENDER_EMAIL`, `BREVO_SENDER_MAIL`, `BLMF_ADMIN_EMAIL`, etc.) | Valeurs résiduelles | Conservées en fallback |

**État après M.1 (préalables Resend) :**

| Variable | Valeur | Statut |
|---|---|---|
| `RESEND_API_KEY` | `re_<token>` | **Nouveau** |
| `SENDER_EMAIL` | `no-reply@notifications.anarbib.org` | **Modifié** |
| `BREVO_API_KEY_NOTIFICATIONS` | inchangé | Actif (encore utilisé) |
| `BREVO_API_KEY` | inchangé | Actif (encore utilisé par `register`) |
| Autres variables | inchangées | — |

**État après M.2 (refactor transport) :**

| Variable | Valeur | Statut |
|---|---|---|
| `MAIL_PROVIDER` | non défini (= défaut `brevo`) | Pas encore positionné |
| `RESEND_API_KEY` | `re_<token>` | Actif (mais non utilisé tant que `MAIL_PROVIDER=brevo`) |
| Autres variables | inchangées | — |

**État pendant M.3 (test parallèle) :**

| Variable | Valeur | Statut |
|---|---|---|
| `MAIL_PROVIDER` | `brevo` (ou non défini) | Globale, défaut Brevo |
| `MAIL_PROVIDER_NOTIFY_INTERNAL_TASK` | `resend` | **Override temporaire** |
| Autres variables | inchangées | — |

**État après M.4 (bascule globale) :**

| Variable | Valeur | Statut |
|---|---|---|
| `MAIL_PROVIDER` | `resend` | **Modifié** |
| `MAIL_PROVIDER_NOTIFY_INTERNAL_TASK` | non défini | **Supprimé** (couvert par la globale) |
| `BREVO_API_KEY_NOTIFICATIONS` | inchangé | Standby (code existe, non appelé) |
| `BREVO_API_KEY` | inchangé | Standby (code existe, non appelé) |
| Autres variables | inchangées | — |

**État final après M.6 (suppression Brevo) :**

| Variable | Valeur | Statut |
|---|---|---|
| `MAIL_PROVIDER` | `resend` (ou supprimée si simplification) | Final |
| `RESEND_API_KEY` | `re_<token>` | Actif |
| `BREVO_API_KEY_NOTIFICATIONS`, `BREVO_API_KEY`, `BREVO_API_KEY_STAGING` | — | **Supprimés** |
| Variantes historiques (`ANARBIB_SENDER_EMAIL`, etc.) | — | **Supprimées** |
| `SENDER_EMAIL` | `no-reply@notifications.anarbib.org` | Final |
| `SENDER_NAME`, `ADMIN_EMAIL`, `ADMIN_NAME`, et habillage | inchangés | Final |
| `WEBHOOK_SECRET_*` | inchangés | Inchangés |

**Compte rendu de l'audit Brevo (sous-paquet M.1.1).**
À remplir au moment de l'exécution de M.1.1 :

```
Date de l'audit : __/__/2026
Auditeur : Xavier
Webhooks sortants configurés côté Brevo : [oui/non]
  Si oui, URLs : ___
  Si oui, action prise : ___
Link tracking actif globalement côté Brevo : [oui/non]
Open tracking actif globalement côté Brevo : [oui/non]
Configurations spécifiques à restaurer ailleurs après bascule : [aucune / liste]
```

### A3 — Procédure de test manuel par EF

Procédure de test manuel pour chaque EF mail, à exécuter en M.0.7 puis en M.4.3 (test post-bascule). L'objectif est de couvrir l'ensemble des EF avec le minimum de tests pertinents.

**T.1 — `register` (mail de bienvenue).**
Conditions : compte de test inutilisé (par exemple `anarbib+test-m4@proton.me`).
Procédure : signup en navigation privée sur `https://app.anarbib.org/criar-conta` avec sélection d'une biblio existante. Vérifier réception du mail welcome dans la boîte du compte test. Vérifier rendu visuel sur Thunderbird et Gmail. Vérifier que le sender est `no-reply@notifications.anarbib.org`. Vérifier que le mail est traduit dans la locale du compte (langue détectée par le frontend).
Variante : refaire le test avec `signup_without_library=true` en sélectionnant "Je ne trouve pas ma bibliothèque" pour vérifier le rendu avec le CTA vers `/solicitar-biblioteca`.

**T.2 — `notify-event` réservation.**
Conditions : compte test connecté, biblio sélectionnée, livre disponible.
Procédure : créer une réservation depuis le frontend. Vérifier réception du mail leitor (sender `no-reply@notifications.anarbib.org`, sujet correct, rendu carte sombre). Vérifier réception de la copie admin sur `anarbib@proton.me`.

**T.3 — `notify-event` emprunt (création).**
Conditions : compte test connecté, biblio sélectionnée, livre disponible, intervention staff côté Painel pour créer l'emprunt.
Procédure : créer un emprunt manuel depuis le Painel. Vérifier réception du mail leitor + copie admin.

**T.4 — `notify-event` workflow réservation (slot proposé par biblio).**
Conditions : réservation T.2 existante, intervention staff pour proposer un créneau de retrait.
Procédure : depuis le Painel, proposer un créneau pour la réservation. Vérifier réception du mail leitor avec le créneau, et de la copie admin.

**T.5 — `notify-internal-task` invitation.**
Conditions : compte staff connecté, panel Painel internal tasks accessible.
Procédure : créer une tâche interne avec invitation à un email de test. Vérifier réception du mail invitation.

**T.6 — `notify-library-request`.**
Conditions : compte sans biblio rattachée, claim token valide.
Procédure : soumettre une demande de bibliothèque depuis `/solicitar-biblioteca`. Vérifier réception du mail accusé de réception côté demandeur, et du mail notification côté admin réseau (`anarbib@proton.me`).

**T.7 — `notify-weekly-report` (déclenchement manuel).**
Conditions : accès à la base via SQL Editor (rôle authenticated suffit avec helpers, ou postgres pour bypass).
Procédure : déclencher manuellement la fonction `SELECT cron_run_weekly_report();` (ou équivalent selon la fonction réelle). Vérifier réception du rapport hebdomadaire dans la boîte admin.

**T.8 — `notify-network-weekly-report` (déclenchement manuel).**
Conditions : EF activée (actuellement dormant en attendant paquets E/F admin réseau). Test à conduire uniquement si le contexte le permet ; sinon, simple inspection du code aligné en M.0 sans test runtime.

**T.9 — `notify-mid-loan-reading` (déclenchement manuel).**
Conditions : emprunt actif à mi-vie.
Procédure : déclencher manuellement l'EF via `supabase functions invoke notify-mid-loan-reading --data '{"loan_id": "<uuid>"}'`. Vérifier réception du mail.

**T.10 — `notify-document-permission-request`.**
Conditions : ressource numérique à accès restreint, demande de permission soumise.
Procédure : soumettre une demande de permission depuis le frontend. Vérifier réception du mail côté admin/coord.

**T.11 — `notify-interlibrary-loan`.**
Conditions : prêt inter-bibliothèques (chantier #10, partiellement activé).
Procédure : à conduire uniquement si le contexte le permet ; sinon inspection du code aligné en M.0.

**Critère de validation global.** Les 11 tests T.1 à T.11 (ou ceux qui sont conduibles selon le contexte) doivent retourner :
- Réception du mail dans la boîte de test, sender = `no-reply@notifications.anarbib.org`.
- Rendu visuel conforme aux captures de référence (post-refonte pour `register`, identique à avant pour les autres EF).
- Apparition dans le dashboard du provider courant (Brevo en pré-M.4, Resend en post-M.4) avec status `delivered`.
- Pas d'erreurs dans les logs Edge Function correspondants.

### A4 — Procédure de rollback express

Cette procédure est conçue pour être exécutée en moins d'une minute, sans accès au code source. Elle permet de revenir intégralement à l'état pré-M.4 (Brevo actif) si un incident critique est détecté dans la période M.4–M.5.

**Préconditions du rollback :**

- Au moins un critère immédiat (8.1.1 à 8.1.9) n'est pas atteint, ou un incident manifeste est observé dans l'heure post-M.4.
- Le compte Brevo est toujours actif (acquis tant que M.6 n'a pas eu lieu).
- Le secret `BREVO_API_KEY_NOTIFICATIONS` est toujours présent dans le dashboard Supabase.

**Étape 1 — Décision de rollback.**
La décision se prend sans hésitation dès qu'un critère immédiat échoue. Pas de tentative de diagnostic en urgence : le diagnostic se fera à froid après rollback. Le rollback est l'option par défaut en cas de doute, pas l'exception.

**Étape 2 — Modification de la variable `MAIL_PROVIDER`.**
Connexion au dashboard Supabase : `https://supabase.com/dashboard/project/uflwmikiyjfnikiphtcp/settings/functions`. Section Edge Function Secrets. Modifier la valeur de `MAIL_PROVIDER` de `resend` à `brevo`. Sauvegarder. La modification est propagée immédiatement aux EF (pas de redémarrage nécessaire, lecture au prochain invoke).

**Étape 3 — Vérification immédiate.**
Déclencher un mail de test depuis n'importe quelle EF (le plus simple : signup test ou notification de réservation). Vérifier que le mail arrive depuis Brevo (apparition dans le dashboard Brevo). Vérifier que le sender visible est cohérent avec la configuration Brevo en cours (probablement `no-reply@notifications.anarbib.org` si la variable `SENDER_EMAIL` a été modifiée en M.1, ou `anarbib@anarbib.org` si pas encore modifiée).

**Étape 4 — Communication.**
Si la coordination locale (BLMF, BTL) avait été notifiée du changement de sender en M.4, envoyer une note rapide expliquant le rollback temporaire et la prochaine fenêtre de re-bascule envisagée.

**Étape 5 — Diagnostic à froid.**
Une fois le rollback effectif, conduire le diagnostic à tête reposée. Consulter les logs Edge Function Supabase pour identifier l'incident. Consulter le dashboard Resend pour les éventuels mails en échec côté provider. Documenter le diagnostic dans un commentaire sur le commit de M.4 ou dans une note de session.

**Étape 6 — Préparer la re-bascule.**
Une fois le diagnostic posé, préparer une nouvelle tentative de M.4 corrigée. La fenêtre temporelle suivante peut être planifiée 24 à 48 heures après le rollback, le temps de valider les correctifs en local.

**Durée totale du rollback : moins d'une minute pour l'étape 2, environ 5 minutes pour l'étape 3.**

**Annulation du rollback (re-bascule vers Resend) :**
La même procédure inverse — passer `MAIL_PROVIDER` de `brevo` à `resend` — permet de re-basculer sans difficulté une fois les correctifs en place.

### A5 — Note de migration aux coordinations locales

Texte indicatif de la note à envoyer aux coordinations actives (BLMF, BTL) en M.4 après la bascule effective. Le mail est envoyé depuis le nouveau sender comme premier test grandeur nature.

**Version pt-BR (principale) :**

```
Sujet : Mudança técnica nos e-mails do AnarBib — informação para a coordenação

Caras compas,

Esta mensagem é para informar de uma mudança técnica que entrou em vigor
hoje no AnarBib: os e-mails enviados pela plataforma (notificações de
empréstimo, reserva, cooptação, etc.) passam agora pelo serviço Resend em
vez do anterior Brevo.

Por que esta mudança? Porque Brevo impunha um sistema de rastreamento
automático em todos os links dos e-mails, redirecionando-os por um domínio
intermediário (sendibt3.com) antes do destino real. Isto criava dois
problemas: (1) os links eram bloqueados pelos VPNs anti-rastreamento de
algumas compas, (2) era incoerente com a doutrina libertária do AnarBib
de não rastrear seus destinatári(o/a/e)s.

Resend permite enviar e-mails sem rastreamento. A configuração foi
validada para que nenhum rastreamento de abertura ou de clique seja
ativado. Esta escolha está documentada e protegida na nossa spec técnica.

Em concreto, para a coordenação:

  - Os e-mails do AnarBib agora partem de "no-reply@notifications.anarbib.org"
    em vez de "anarbib@anarbib.org". Recomendamos adicionar este novo
    remetente aos contatos para evitar o classificamento em spam nos
    primeiros dias.

  - A resposta aos e-mails continua funcionando normalmente. O endereço
    de resposta é configurado por biblioteca conforme as preferências locais.

  - Em caso de e-mail não recebido ou suspeito, escreva para anarbib@proton.me.

Esta mudança não tem impacto sobre os parcours de cadastro, empréstimo,
reserva, ou qualquer outra funcionalidade do AnarBib. É puramente técnica
nos bastidores.

Saudações libertárias,
A equipe técnica AnarBib
```

**Version fr (archivage) :**

```
Sujet : Changement technique pour les e-mails AnarBib — info coordination

Bonjour les compas,

Ce message t'informe d'un changement technique entré en vigueur aujourd'hui
sur AnarBib : les e-mails envoyés par la plateforme (notifications d'emprunt,
réservation, cooptation, etc.) passent désormais par le service Resend au lieu
du précédent Brevo.

Pourquoi ce changement ? Parce que Brevo imposait un système de tracking
automatique sur tous les liens des e-mails, en les redirigeant via un domaine
intermédiaire (sendibt3.com) avant la destination réelle. Cela posait deux
problèmes : (1) les liens étaient bloqués par les VPN anti-tracking de
certain·es compas, (2) c'était incohérent avec la doctrine libertaire d'AnarBib
de ne pas tracker ses destinataires.

Resend permet d'envoyer des e-mails sans tracking. La configuration a été
validée pour qu'aucun tracking d'ouverture ou de clic ne soit activé. Ce choix
est documenté et protégé dans notre spec technique.

Concrètement, pour la coordination :

  - Les e-mails AnarBib partent désormais de "no-reply@notifications.anarbib.org"
    au lieu de "anarbib@anarbib.org". Nous recommandons d'ajouter ce nouvel
    expéditeur aux contacts pour éviter un classement en spam les premiers jours.

  - La réponse aux e-mails fonctionne toujours normalement. L'adresse de réponse
    est configurée par bibliothèque selon les préférences locales.

  - En cas d'e-mail non reçu ou suspect, écrire à anarbib@proton.me.

Ce changement n'a aucun impact sur les parcours d'inscription, d'emprunt, de
réservation, ou toute autre fonctionnalité d'AnarBib. C'est purement technique
en coulisses.

Salutations libertaires,
L'équipe technique AnarBib
```

**Versions es, en, it, de :** structurellement identiques, à traduire en s'inspirant des conventions militantes définies dans `_shared/i18n/mail-strings.ts` (es neutre argentin avec « -e », en épicène, it /a/e, de Genderstern). Le texte traduit est archivé dans `docs/specs/notes-migration/M4-bascule-resend/` au moment de M.4 pour permettre une diffusion ciblée en cas d'élargissement futur du réseau à d'autres coordinations.

### A6 — Capture annotée de la page tracking Resend

Cette annexe documente visuellement la page `https://resend.com/domains/<id>/tracking` qui est l'objet du garde-fou doctrinal (§6.4). La capture sert de référence pédagogique pour tout·e admin·istratrice réseau, présent·e ou future·e, qui aurait l'occasion d'accéder au dashboard Resend du CCLA.

**Capture de référence à archiver dans `docs/specs/captures/resend-tracking-page/` :**

La capture doit être prise en M.1.4, avec annotations textuelles ajoutées par-dessus. Elle représente la page de configuration "New tracking subdomain" du dashboard Resend telle qu'elle apparaît par défaut à un·e utilisateur·rice qui n'a pas encore validé de tracking subdomain.

**Annotations à apposer sur la capture :**

1. **Champ "Subdomain"** (à gauche, avec placeholder `links`) :
   *« Ce champ est volontairement laissé vide. Le remplir et valider créerait un sous-sous-domaine de tracking et activerait le tracking de clic et/ou d'ouverture. »*

2. **Case "Enable click tracking"** (cochée par défaut) :
   *« Cette case est pré-cochée par défaut par Resend. C'est une particularité ergonomique trompeuse : tant que la page n'est pas validée, la case n'a aucun effet. Mais si quelqu'un valide la page, le tracking de clic devient actif. »*

3. **Case "Enable open tracking"** (décochée par défaut) :
   *« Cette case est décochée par défaut. Même garde-fou que la précédente : tant que la page n'est pas validée, l'état de cette case n'a aucun effet. »*

4. **Bouton "Add domain"** (en bas de la page) :
   *« Ce bouton ne doit jamais être cliqué dans le dashboard Resend du CCLA. C'est le geste qui transforme la configuration affichée à l'écran en configuration effective. Tant qu'il n'est pas cliqué, le tracking reste désactivé au niveau du domaine, comme documenté par Resend. »*

5. **Section "DNS Record"** (en bas, masquée tant que rien n'est validé) :
   *« Cette section apparaîtrait après validation pour fournir un CNAME à ajouter chez OVH. La doctrine du CCLA est de ne jamais ajouter un tel CNAME dans la zone DNS de notifications.anarbib.org. Sans CNAME, Resend n'a pas l'infrastructure pour faire passer les liens par un domaine de tracking. »*

**Légende globale à inscrire en bas de la capture :**

*« État par défaut de la page de configuration du tracking subdomain dans le dashboard Resend. La doctrine AnarBib est que cette page ne doit jamais être validée. Capture prise le __/__/2026, à archiver dans docs/specs/captures/resend-tracking-page/. »*

**Procédure de mise à jour de la capture.**
Si Resend modifie l'apparence de cette page (refonte de design, ajout de nouveaux champs, etc.), la capture doit être mise à jour pour refléter l'état actuel. Cette mise à jour est inscrite comme item de backlog technique récurrent (vérification semestrielle minimale, ou à chaque évolution majeure de Resend).

### A7 — Bilan de session (à remplir en clôture de chantier)

Cette annexe est un cadre pour le bilan de session à rédiger en clôture de M.5 puis en clôture de M.6. Elle reprend la structure des bilans de session AnarBib existants (cf. `AnarBib_Bilan_session_2026-05-12.docx`).

**Cadre indicatif pour le bilan M.5 (à J+14 post-bascule) :**

```
AnarBib — Bilan de migration mail Brevo → Resend
Phase : M.5 close, ouverture M.6 conditionnelle

1. Synthèse exécutive
   - Date de M.4 : ___
   - Bilan de la période M.5 : ___
   - Incidents notables : [liste ou "aucun"]
   - Décision sur M.6 : [ouverture immédiate / report / autre]

2. Critères de succès vérifiés
   - 8.1.1 à 8.1.9 : [atteint / non atteint, détails]
   - 8.2.1 à 8.2.6 : [atteint / non atteint, détails]

3. Volume et qualité d'envoi (dashboard Resend J+14)
   - Mails envoyés : ___
   - Taux de delivery : ___
   - Taux de bounces : ___
   - Plaintes spam : ___

4. Retours coordinations locales
   - BLMF : ___
   - BTL : ___

5. Leçons techniques pour la suite
   - ___

6. Prochaines étapes
   - ___
```

**Cadre indicatif pour le bilan M.6 (clôture finale) :**

```
AnarBib — Bilan de clôture migration Brevo → Resend
Phase : M.6 close, chantier complet

1. Synthèse exécutive
   - Date d'ouverture du chantier : ___
   - Date de clôture (M.6) : ___
   - Durée totale : ___
   - Bilan général : ___

2. Critères de succès cumulés (§8.6)
   - Bloquants M.4 : [tous atteints / liste écarts]
   - Bloquants M.5 : [tous atteints / liste écarts]
   - Bloquants M.6 : [tous atteints / liste écarts]
   - Politiques (durée projet) : [état au moment du bilan]

3. Récapitulatif des paquets livrés
   - M.0 à M.6 : [chacun avec durée réelle, écart vs estimation, incidents]

4. Évolutions documentaires
   - Registre RGPD mis à jour : [date]
   - Politique de confidentialité publiée : [date ou "en cours"]
   - Manuel admin réseau enrichi du garde-fou tracking : [date ou "en cours"]

5. État final du code et de la configuration
   - Brevo entièrement supprimé du code : [oui / non, détails]
   - Brevo entièrement supprimé des secrets : [oui / non, détails]
   - Compte Brevo : [supprimé / en standby jusqu'à __/__/____]

6. Leçons consignées pour les futurs chantiers similaires
   - ___

7. Items de backlog générés
   - ___
```

---

## Conclusion

Cette spec v0.1 a pour ambition de cadrer intégralement la migration du provider mail Brevo vers Resend, en intégrant simultanément la dimension technique (refactor architectural, dispatch wrapper, tests), la dimension politique (doctrine no-tracking, garde-fou doctrinal, cohérence libertaire), et la dimension procédurale (séquence de paquets, méthode de validation, rollback préparé).

Elle est conçue pour être un document **opposable et reproductible** : opposable au sens où elle servira de référence en cas de discussion future sur la doctrine tracking ou sur la conduite du chantier ; reproductible au sens où elle pourrait être transmise à d'autres collectifs libertaires souhaitant conduire une migration similaire sur leur propre infrastructure.

La séquence M.0 à M.6 est explicite, datable à la fonction près, et compatible avec la doctrine de cadence du projet telle que formulée dans le point d'étape v13.5 (un seul chantier majeur à la fois, ralentissement de cadence accepté en phase de précision, pas de chantier nouveau ouvert au prétexte que le système est encore observé seul). Sa conduite peut être suspendue entre paquets sans dette.

La présente spec sera versionnée v0.1 jusqu'à validation finale par la coordination réseau du CCLA, puis v1.0 au moment de l'ouverture effective de M.0. Toute évolution post-v1.0 fera l'objet de versions intermédiaires (v1.1, v1.2, etc.) avec changelog inscrit en tête du document.

---

**Fin de la spec v0.1.**
