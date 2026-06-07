# spec-migration-mail-resend.md — Migration du provider mail Brevo → Resend

**Version** : v0.6
**Date** : 08/06/2026 (révision de la v0.5 du 05/06/2026 ; v0.1–v0.3 archivées sous `docs/specs/archive/spec-migration-mail-resend-v0.{1,2,3}.md`)
**Statut** : **terminé et clos** — R.1 à R.5 (21/05 → 05/06), R.6 (retrait de Brevo) le 05/06, hygiène R.7 le 08/06/2026. Chantier #110 clos, critère documentaire 8.3.6 levé (cf. changelog v0.6).
**Périmètre** : 8 Edge Functions Supabase porteuses d'envoi mail + transport mail partagé
**Auteur·rices** : Xavier (rédaction politique), Claude (rédaction technique)

---

## Changelog v0.5 → v0.6

La v0.6 acte l'exécution du chantier d'hygiène **R.7** (post-migration, hors #110), le 08/06/2026, et la levée du dernier critère documentaire 8.3.6.

1. **R.7 exécuté (hygiène, sans changement fonctionnel — iso-comportement).**
   - **Item 1 — `MAIL_PROVIDER`** : secret supprimé côté Supabase ; le code ne le lisait plus depuis R.6. Commentaires d'en-tête des 8 transports actualisés.
   - **Item 2 — variables de sender** : cascades `ANARBIB_*`/`NETWORK_*`/`LIBRARY_SENDER_NAME` harmonisées sur le couple canonique `SENDER_EMAIL`/`SENDER_NAME` dans 6 Edge Functions. Iso-comportement vérifié par comparaison des digests SHA-256 (toutes les variantes valaient déjà `no-reply@notifications.anarbib.org` / `AnarBib`). Les **5 secrets redondants** ont été retirés après déploiement vert. `register` bascule son expéditeur de `ANARBIB_SENDER_EMAIL` vers `SENDER_EMAIL` (+ gate `MISSING_ENV`) ; `notify-network-weekly-report` abandonne la précédence `NETWORK_SENDER_*`.
   - **Item 3 — `register`** : les 3 sites d'appel construisent désormais un payload Resend natif (`{ from, to:[email…], reply_to, subject, html }`) ; la fonction de traduction `brevoPayloadToResend` est supprimée. **Plus aucune trace de Brevo dans le code de `register`.**

2. **Critère 8.3.6 levé.** Le guide de gouvernance (manuel admin réseau) a reçu un encart garde-fou anti-tracking (envoi via Resend, suivi ouvertures/clics désactivé) et a été traduit dans les **10 langues** du réseau (`.md` + `.docx`, `docs/governance/`).

**Bilan global du chantier.** Plus aucune trace de Brevo (code et secrets) ; variables de sender rationalisées sur un couple canonique unique. **13 secrets nettoyés** au total : 7 Brevo (R.6.2) + `MAIL_PROVIDER` (R.7) + 5 sender redondants (R.7). Le chantier #110 et son hygiène R.7 sont entièrement clos.

---

## Changelog v0.4 → v0.5

La v0.5 acte la **clôture du chantier #110** : la migration Brevo → Resend est terminée et Brevo est retiré du code et des secrets.

1. **R.4 (bascule) et R.5 (surveillance) clos.** `MAIL_PROVIDER` passé à `resend` le 21/05/2026 ; aucun envoi Brevo depuis le 21/05 20h31. Coexistence stable du 21/05 au 05/06 (Resend en statut 200, aucun mail `failed`).

2. **R.6 (retrait de Brevo) clos le 05/06/2026.**
   - **R.6.1** — code Brevo retiré des 8 transports + 2 `env.ts` partagés (`sendViaBrevo`, dispatch `MAIL_PROVIDER`, lectures `BREVO_*`, coquille `BREVO_SENDER_MAIL`). `sendEmail()` appelle directement `sendViaResend()`. Conservés : `sendViaResend`, inlining base64 des logos, contrats de retour, secret `MAIL_PROVIDER` (retrait reporté à R.7). Déployé, runtime confirmé (notify + register reçus via Resend).
   - **R.6.2** — 7 secrets `BREVO_*` supprimés (`BREVO_API_KEY`, `_NOTIFICATIONS`, `_NOTIFY_INTERNAL_TASK`, `_NOTIFY_RESERVA`, `_STAGING`, `BREVO_SENDER_EMAIL`, `BREVO_SENDER_NAME`). Point de non-retour franchi après sauvegarde hors-ligne (P.0). Fallbacks sender (`SENDER_EMAIL`/`ANARBIB_SENDER_EMAIL`/`NETWORK_SENDER_EMAIL`) conservés et alignés.
   - **R.6.3** — couture sender confirmée saine, aucune suppression supplémentaire.
   - **R.6.4** — compte Brevo en standby (gratuit, sans coût) ; fermeture définitive indicative fin été 2026.
   - **Gate dur** : `register` exige désormais `RESEND_API_KEY` pour démarrer (remplace l'ancien gate Brevo).
   - **Cas `register`** : `brevoPayloadToResend` (traduction du payload pivot) **conservée** comme normalisation interne — sa suppression (réécriture des 3 sites d'appel) relève de R.7.

3. **Volet documentaire.** DPA porté en v1.1 dans **10 langues** (ajout ca, el, eo, nl) ; registre des traitements mis à jour (Brevo → Resend, DPA Resend, garde-fou tracking désactivé).

4. **Reste pour R.7** (hygiène, hors #110) : retrait du secret `MAIL_PROVIDER`, rationalisation des variables de sender, réécriture des 3 sites `register` + suppression de `brevoPayloadToResend`, nettoyage des commentaires « brevo » historiques.

**Critères de clôture (§8.3)** : 8.3.1 (grep brevo = commentaires historiques) ✅ ; 8.3.2 (aucun secret Brevo) ✅ ; 8.3.3 (registre RGPD) ✅ ; 8.3.5 (aucun coût Brevo) ✅ (constat) ; 8.3.6 (garde-fou tracking dans le manuel admin réseau) — **en attente** de la mise à jour du manuel.

---

## Changelog v0.3 → v0.4

La v0.4 corrige une dérive de la doctrine de déploiement, en l'alignant sur le registre des décisions (foyer **DOC-DEPLOY-1/2/3**). Un seul point.

1. **Doctrine de déploiement des Edge Functions (§5.3, §5.4, §6.6 Règle 2).** La v0.3 généralisait à tort la CLI `supabase functions deploy` à *toutes* les EF du chantier. La doctrine canonique du registre est : `git push` → Woodpecker (`deploy-edge-functions`) pour le cas général, l'outil MCP `deploy_edge_function` restant proscrit ; `notify-event` est la **seule** exception déployée à la main en CLI (`--no-verify-jwt`, bundle >150 ko) ; `register` est la seule EF à conserver `verify_jwt`. R.3 ayant été clos le 21/05 *avant* canonisation de cette doctrine, son bilan d'exécution (§5.4) conserve la trace du déploiement CLI historique — cette voie n'est plus la doctrine pour tout nouveau travail. Les §5.3, §5.4 et §6.6 Règle 2 sont corrigés en conséquence ; le foyer doctrinal est désormais le registre, la spec ne faisant que le référencer (anti-drift).

---

## Changelog v0.2 → v0.3

La v0.3 révise la v0.2 à la lumière de l'exécution des sous-paquets R.1, R.2 et R.3, conduite et close le 21/05/2026. Trois points.

1. **Correction de la couture R.1 ↔ R.3 (§5.2).** La v0.2, en R.1.3, affirmait que `no-reply@notifications.anarbib.org` était « compatible avec Brevo (variante du domaine `anarbib.org` déjà vérifié) » et pouvait donc être posé dès R.1 sans précaution. C'est faux : un **sous-domaine** n'hérite pas de la vérification d'expéditeur du domaine parent — chez Brevo comme chez tout fournisseur, un sous-domaine d'envoi doit être authentifié séparément. Pendant R.3, le provider actif est encore Brevo ; or `SENDER_EMAIL` avait basculé en R.1 vers un sous-domaine non authentifié côté Brevo, et Brevo rejetait l'expéditeur (« sender not valid »). Incident constaté au premier test runtime de R.3 le 21/05, résolu en authentifiant le sous-domaine côté Brevo. La v0.3 corrige R.1.3 et ajoute une étape R.1.6 dédiée. Doctrine introduite : pendant toute la période de coexistence des deux providers, le sous-domaine d'envoi doit être authentifié chez **les deux**, pas seulement chez le provider cible.

2. **Bilan d'exécution de R.3 (§5.4).** R.3 est clos. Un bloc de bilan est ajouté en fin de §5.4 : les sept transports autonomes (la v0.2 en comptait « six » plus `register` traité à part — soit sept au total) ont adopté le wrapper `sendEmail` ; les sept extractions ont été propres au sens de §4.3, donc aucune dette n'est reportée au chantier d'hygiène R.7 ; six EF ont été testées en runtime, la septième (`notify-document-permission-request`) ayant son test reporté à R.4 pour une raison documentée.

3. **Annexe A2.** Une note est ajoutée à l'état des secrets : la bascule de `SENDER_EMAIL` en R.1 a une dépendance DNS (authentification du sous-domaine) qui n'était pas explicitée ; et le secret `WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK` a été rotaté le 21/05 pendant R.3.

---

## Changelog v0.1 → v0.2

La v0.2 révise la v0.1 sur neuf points, à la lumière de huit jours d'évolution du projet (clôture du chantier profils d'adoption #98 le 19/05, chantier-cadre Biblioteca en cours, GLB v15, backlog du 21/05) et d'une cartographie fraîche du dossier `supabase/functions/` au 21/05.

1. **Cartographie corrigée (§2).** Le périmètre réel est de 8 Edge Functions porteuses d'envoi mail, pas 9 : `mail-i18n-test` est un endpoint de test du dictionnaire i18n, pas un émetteur. L'architecture de `notify-event` est désormais entièrement mutualisée : `notify-event/index.ts` est le seul fichier propre à l'EF, toute la logique vit dans `supabase/functions/_shared/`. Les handlers de domaine sont dans `_shared/domain/*.ts` (et non `handlers/*.ts` comme l'indiquait la v0.1).

2. **Lien avec le chantier-cadre Biblioteca (§1.7, §7).** L'étape 8 du chantier-cadre Biblioteca — écarts EA-13, EA-14, EA-19, qui portent sur des mails — est en attente de cette migration. La v0.2 inscrit cette dépendance aval explicitement.

3. **Inversion de la séquence (§5).** La v0.1 plaçait l'alignement architectural des EF (M.0) avant la bascule de provider. La v0.2 inverse : la bascule fonctionnelle Brevo → Resend est conduite d'abord, l'alignement architectural devient un chantier d'hygiène ultérieur et non bloquant. Raison : débloquer l'étape 8 Biblioteca rapidement, en cohérence avec la doctrine de fermeture des chantiers du GLB v15 et avec le cadrage « mode pragma » du backlog du 21/05.

4. **Renumérotation.** La v0.1 parlait de « paquet 28 ». La v0.2 adopte la nomenclature du backlog du 21/05 : ce chantier est l'item #110, avec des sous-paquets internes nommés R.1, R.2, etc.

5. **Doctrine d'implémentation renforcée (§6.6).** Les règles de déploiement du projet — migrations SQL par fichier horodaté commité, jamais via l'outil MCP `apply_migration` ; déploiement de `notify-event` par CLI `supabase functions deploy`, jamais via l'outil MCP `deploy_edge_function` ; pas de branche Supabase de développement — sont désormais une section ferme et non une mention incidente.

6. **Vérification TLS (§5, préalables).** Le dashboard Resend expose un réglage TLS (mode « Opportunistic TLS » par défaut). La v0.2 inscrit une micro-vérification de ce réglage dans les préalables.

7. **`notify-internal-task` reclassé (§2).** La v0.1 le croyait aligné sur le transport partagé. La cartographie du 21/05 montre qu'il embarque sa propre copie de `_shared/transport/email.ts` dans son bundle. Il est reclassé parmi les EF à transport autonome.

8. **Estimation révisée (§5).** La v0.1 annonçait dix semaines. La v0.2 distingue deux temps : la bascule fonctionnelle (3 à 4 jours de travail effectif, cohérent avec le backlog) et l'alignement architectural ultérieur (chantier d'hygiène séparé, non chiffré en urgence).

9. **Références mises à jour.** GLB v13 → v15 ; backlog v5/v6 → v9 du 21/05.

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
- **Ligne rouge v13 sur la sécurité** : *« aucun durcissement de sécurité sans lecture du dump à jour »*, et sa précision opérationnelle v13.5 : *« tout paquet créant une vue ou une RPC doit s'achever par un get_advisors security, et appliquer un correctif si nouveau ERROR ou WARN apparaît. »* La présente migration ne crée ni vue ni RPC, mais le principe méthodologique (vérification finale automatisée) s'applique : la spec prévoit en §6 un test runtime systématique des 8 EF avant clôture du chantier.
- **Doctrine procédurale du chantier linter** (récap 11-12/05/2026, §3.1) : *« un fix à la fois, validation entre chaque ».* Cette migration touche au transport mail commun à des fonctions critiques de la chaîne de notifications. Toute régression silencieuse coûterait cher en confiance utilisateur·rice. La séquence en paquets (§5) applique strictement ce principe.

La spec ne propose donc aucune doctrine nouvelle. Elle applique la doctrine existante à un chantier de migration provider, en tirant les conséquences opérationnelles de deux constats : (a) Brevo a montré, par un incident concret, qu'il est structurellement incompatible avec la doctrine ; (b) Resend permet de tenir la doctrine, à condition de poser un garde-fou opérationnel sur l'UX de configuration du tracking.

### 1.7 Lien avec le chantier-cadre Biblioteca

Cette migration n'est pas un chantier isolé : elle conditionne l'avancement du chantier-cadre Biblioteca, en cours au 21/05/2026. Ce chantier-cadre traite une série d'écarts numérotés EA-xx, et son étape 8 regroupe trois écarts — **EA-13, EA-14 et EA-19** — qui portent tous sur des mails.

Tant que la chaîne mail repose sur Brevo, traiter EA-13/14/19 reviendrait à investir du travail sur une couche de transport vouée à être remplacée. L'ordre rationnel est donc : conduire d'abord la bascule de provider (le présent chantier #110), puis traiter l'étape 8 du chantier-cadre Biblioteca sur la couche mail neuve. La v0.2 acte cette dépendance et la reflète dans le séquencement du §5 — la bascule fonctionnelle est volontairement placée en tête de chantier, avant tout travail d'hygiène architecturale, précisément pour débloquer l'étape 8 au plus tôt.

Cette dépendance est aussi la raison du « mode pragma » retenu pour ce chantier (cf. §5) : l'objectif premier n'est pas la perfection architecturale de la couche mail, mais sa bascule fonctionnelle correcte et rapide, pour que le chantier-cadre Biblioteca puisse reprendre sa séquence.

---

## §2 — État existant et cartographie technique

Cette section reflète l'état du dossier `supabase/functions/` au 21/05/2026, établi par lecture directe du code en dépôt. Elle corrige plusieurs constats de la v0.1, qui datait du 13/05 et reposait sur une cartographie partielle.

### 2.1 Inventaire des Edge Functions porteuses d'envoi mail

Le dépôt contient dix-huit Edge Functions. Huit d'entre elles émettent des mails. Une neuvième, `mail-i18n-test`, manipule le dictionnaire i18n mais n'envoie rien : elle est hors périmètre. La v0.1 la comptait à tort, d'où le passage de « 9 EF » à « 8 EF » dans la v0.2.

Les huit Edge Functions porteuses d'envoi mail :

| EF | Rôle | Transport mail |
|---|---|---|
| `notify-event` | Dispatcher central : réservations, emprunts, consultations, profils de bibliothèque, équipe, réseau | Partagé — `_shared/transport/email.ts` |
| `notify-internal-task` | Notifications de tâches internes (Painel) | Autonome — copie privée du transport dans son bundle |
| `notify-library-request` | Notification d'une demande institutionnelle de bibliothèque | Inliné dans `index.ts` |
| `notify-weekly-report` | Rapport hebdomadaire d'activité par bibliothèque | Inliné dans `index.ts` |
| `notify-network-weekly-report` | Rapport hebdomadaire au niveau réseau | Inliné dans `index.ts` |
| `notify-mid-loan-reading` | Message en milieu d'emprunt | Inliné dans `index.ts` |
| `notify-document-permission-request` | Notification d'une demande d'accès à une ressource numérique restreinte | Inliné dans `index.ts` |
| `register` | Création de compte lecteur·rice et mail de bienvenue | Inliné dans `index.ts` |

Toutes appellent l'endpoint Brevo `https://api.brevo.com/v3/smtp/email` et lisent la clé `BREVO_API_KEY_NOTIFICATIONS`. Les sept Edge Functions `notify-*` ont `verify_jwt` désactivé : elles sont déclenchées par des webhooks Postgres ou des crons, protégés par un secret de webhook (`WEBHOOK_SECRET_*`), pas par un JWT. `register` fait exception : appelée directement depuis le frontend, elle a `verify_jwt` activé.

### 2.2 État de l'architecture mail — sept transports physiques distincts

La v0.1 décrivait une architecture « hybride » avec deux EF alignées sur un transport partagé et sept inlinées. La cartographie du 21/05 corrige ce constat sur deux points.

**Premier point — `notify-event` est désormais entièrement mutualisé.** Le dossier `notify-event/` ne contient plus qu'un seul fichier propre, `index.ts`. Toute la logique — résolution de contexte, rendu HTML, i18n, transport, handlers de domaine — vit dans `supabase/functions/_shared/`. L'arborescence partagée pertinente au 21/05 :

```
supabase/functions/_shared/
├── transport/email.ts          ← le transport Brevo partagé (sendBrevoEmail, safeSendEmail…)
├── mail/
│   ├── layout.ts                ← renderEmail()
│   └── inline-images.ts         ← contre-mesure logos Brevo
├── i18n/mail-strings.ts         ← dictionnaire 6 locales
├── domain/                      ← handlers de domaine (et non handlers/ comme en v0.1)
│   ├── reservas.ts
│   ├── emprestimos.ts
│   ├── consultas.ts
│   ├── profiles.ts
│   ├── library_profile.ts
│   ├── team.ts
│   ├── network.ts
│   └── legacy.ts
├── context/                     ← library-mail-routing.ts, policies.ts, etc.
├── data/                        ← consultas.ts, emprestimos.ts, reservas.ts
├── core/                        ← env.ts, dispatch.ts, webhook.ts, types.ts
└── shared/                      ← branding.ts, format.ts, events.ts, payload.ts
```

Tous les handlers `_shared/domain/*.ts` consomment `_shared/transport/email.ts`. Pour toute la galaxie `notify-event`, **le transport bascule en un seul point** : la fonction `sendBrevoEmail` de `_shared/transport/email.ts`.

**Deuxième point — `notify-internal-task` n'est pas aligné.** La v0.1 le rangeait parmi les EF déjà alignées sur le transport partagé. En réalité, son bundle embarque sa propre copie de l'arborescence `_shared/`, dont un `_shared/transport/email.ts` privé et un handler `_shared/handlers/internal-task.ts`. C'est une duplication de code, pas une mutualisation. Il est donc reclassé parmi les EF à transport autonome.

**Décompte réel des transports Brevo physiques à traiter — sept :**

1. `_shared/transport/email.ts` (partagé par toute la galaxie `notify-event`)
2. `notify-internal-task/_shared/transport/email.ts` (copie privée)
3. `notify-library-request/index.ts` (inliné)
4. `notify-weekly-report/index.ts` (inliné)
5. `notify-network-weekly-report/index.ts` (inliné)
6. `notify-mid-loan-reading/index.ts` (inliné)
7. `notify-document-permission-request/index.ts` (inliné)
8. `register/index.ts` (inliné)

Soit huit fichiers, sept implémentations distinctes (les deux premiers partagent le même code source mais dans deux bundles séparés). C'est ce décompte qui dimensionne l'effort de la bascule (§5).

### 2.3 Le transport partagé actuel

Le fichier `_shared/transport/email.ts` expose aujourd'hui les fonctions suivantes, consommées par tous les handlers `_shared/domain/*` :

- `sendBrevoEmail(opts)` — appel HTTP brut vers `api.brevo.com/v3/smtp/email`. C'est le point d'application unique de la bascule pour la galaxie `notify-event`.
- `safeSendEmail(target, subject, html, text, label, context)` — wrapper défensif : vérifie le `transportDisabledReason` du contexte, valide l'adresse, inline les logos via `inlineLogosInHtml`, appelle `sendBrevoEmail`, retourne un résultat structuré `{ok, label, email, response?}` ou `{ok:false, …, skipped?, reason?}`.
- `skippedEmailResult(label, reason, email)` — formatage uniforme d'un envoi sauté.
- `userTargetFromProfile(p)` / `adminTarget(ctx)` — résolution des destinataires.
- `sendAdminNotification(opts)` — mail de copie à la coordination, via `renderEmail` + `safeSendEmail`.

La signature de `safeSendEmail` est le contrat stable que consomment les handlers. La bascule devra le préserver à l'identique pour ne pas toucher au code de domaine. Les six autres transports (les inlinés et la copie de `notify-internal-task`) n'exposent pas tous ce contrat : ils seront, eux, refondus lors de l'alignement architectural (chantier d'hygiène ultérieur, cf. §5).

### 2.4 Inventaire des secrets et variables d'environnement

Le module `_shared/core/env.ts` lit les variables avec des cascades de fallback historiques :

- `BREVO_API_KEY_NOTIFICATIONS` — clé API Brevo. Disparaît à terme.
- `SENDER_EMAIL`, avec fallback sur `ANARBIB_SENDER_EMAIL`, `NETWORK_SENDER_EMAIL`, `BREVO_SENDER_MAIL` — adresse d'expéditeur. Valeur cible : `no-reply@notifications.anarbib.org`.
- `SENDER_NAME`, avec fallback sur `ANARBIB_SENDER_NAME`, `NETWORK_SENDER_NAME`, `BREVO_SENDER_NAME`, `LIBRARY_SENDER_NAME` — nom d'expéditeur. Valeur par défaut `Biblioteca da rede AnarBib`, indépendante du provider.

Les EF inlinées peuvent lire d'autres variantes (par exemple `register` lit sa propre clé). Un inventaire exhaustif par EF est à dresser au sous-paquet d'audit (cf. §5). La migration ajoute un seul secret : `RESEND_API_KEY`. Les secrets `WEBHOOK_SECRET_*` (sécurisation des webhooks Postgres → EF) sont sans rapport avec le provider mail et restent inchangés.

### 2.5 Architecture côté DB — pas de tracking persistant

Le projet n'enregistre nulle part les états d'envoi des mails (succès, échec, bounce). Le système est en « fire-and-forget » assumé : `team_notification_outbox` enregistre les événements à notifier (un INSERT par event, lu par `notify-event` via le trigger de fan-out `trg_team_outbox_dispatch`), mais aucun résultat d'envoi n'est réinjecté en base. Aucune table de bounces, d'ouvertures ou de clics n'existe. Aucun webhook entrant n'est configuré pour recevoir ces signaux depuis Brevo.

Conséquence pour la migration : aucune logique applicative ne dépend de signaux de tracking. La bascule ne demande aucune adaptation côté base de données.

### 2.6 Architecture côté frontend — aucune dépendance directe

Le frontend n'appelle jamais l'API Brevo. Les seules interactions frontend / mail passent par l'EF `register` (qui retourne des booléens d'envoi) et par les actions DB qui insèrent dans `team_notification_outbox`. Aucun composant ne référence Brevo ni ne consomme de webhook. La migration n'a aucun impact frontend, hormis un test de fumée après bascule.

### 2.7 Synthèse de l'état existant

Trois constats cadrent la suite :

**Premier constat.** La galaxie `notify-event` — la plus grosse part du trafic mail, et celle qui porte les notifications de réservation, emprunt, consultation, équipe et réseau — bascule en **un seul point** : `_shared/transport/email.ts`. C'est ce qui rend une bascule rapide réaliste.

**Deuxième constat.** Sept autres fichiers de transport (la copie privée de `notify-internal-task` et les six inlinés) devront aussi basculer. Deux stratégies sont possibles et sont arbitrées au §5 : soit les aligner d'abord sur le transport partagé puis basculer (approche v0.1), soit basculer chaque transport sur place puis aligner plus tard (approche v0.2). La v0.2 retient la seconde.

**Troisième constat.** Le projet n'a aucune dépendance persistante au tracking mail, ni en base ni en frontend. La migration est donc une opération de couche transport pure, sans effet sur la logique métier.


## §3 — Questions politiques tranchées

Six questions ont émergé du cadrage de cette migration. Quatre sont tranchées dans la présente spec, deux restent partiellement ouvertes et seront refermées au cours de l'exécution. Chaque question est présentée avec son énoncé, ses options envisagées, et l'arbitrage retenu avec son rationale.

### 3.1 Q1 — Faut-il aligner les transports avant la bascule, ou basculer chaque transport sur place ?

**Énoncé.** Sept transports Brevo physiques coexistent (cf. §2.2) : le transport partagé de la galaxie `notify-event`, la copie privée de `notify-internal-task`, et cinq transports inlinés dans des EF `notify-*` ou dans `register`. Deux options pour la migration : (a) aligner d'abord tous les transports autonomes sur le transport partagé `_shared/transport/email.ts`, puis ne basculer qu'un seul fichier ; (b) basculer chaque transport sur place — Brevo → Resend là où il se trouve — et reporter l'alignement architectural à un chantier d'hygiène ultérieur.

**Options envisagées :**
- *Option a — Aligner d'abord, basculer ensuite.* C'était l'arbitrage de la v0.1. Bascule finale triviale (un seul fichier), mais précédée d'un refactor lourd de sept transports : plusieurs jours de travail avant que le premier mail ne parte de Resend.
- *Option b — Basculer chaque transport sur place, aligner plus tard.* La bascule fonctionnelle est conduite en premier, transport par transport. L'alignement architectural (faire converger les sept transports vers un seul) devient un chantier d'hygiène distinct, non bloquant, planifiable plus tard.

**Arbitrage retenu : option b. C'est le changement de doctrine central de la v0.2 par rapport à la v0.1.** Trois raisons.

Première raison — la dépendance Biblioteca. L'étape 8 du chantier-cadre Biblioteca (écarts EA-13, EA-14, EA-19) attend la couche mail neuve (cf. §1.7). L'option a retarderait ce déblocage de plusieurs jours de refactor préalable. L'option b fait partir les mails de Resend au plus tôt.

Deuxième raison — la doctrine du GLB v15. Le GLB v15 insiste sur la fermeture des chantiers ouverts plutôt que sur l'ouverture de nouveaux paliers, et formule explicitement : « pas de confusion entre montée du parc Edge Functions et fermeture de la refonte mails ». Faire un gros refactor architectural au milieu d'une migration de provider, c'est précisément mélanger deux chantiers. L'option b les sépare nettement : d'abord la migration de provider (le sujet politique), ensuite l'hygiène architecturale (un sujet technique distinct).

Troisième raison — le risque maîtrisé. L'objection de la v0.1 à l'option b était le risque de régression silencieuse pendant la coexistence Brevo/Resend. Mais ce risque est faible et borné : la bascule sur place se fait transport par transport, chacun testé immédiatement après bascule ; et le wrapper `MAIL_PROVIDER` (cf. §4) permet un retour arrière par variable d'environnement. La coexistence transitoire de quelques jours entre transports déjà basculés et transports encore sur Brevo n'a pas d'effet de bord : chaque mail est envoyé par un seul provider, déterminé par le transport qui le porte.

**Conséquence sur la spec.** La séquence du §5 commence par la bascule fonctionnelle (sous-paquets R.1 à R.5), transport par transport. L'alignement architectural — faire converger les sept transports vers `_shared/transport/email.ts` — est décrit en §5 comme un chantier d'hygiène ultérieur (R.7), explicitement hors du chemin critique et non chiffré en urgence.

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
- *Option b — Inspecter le dashboard Brevo et débrancher si présent.* Étape de cadrage en R.1.

**Arbitrage retenu : option b.** La vérification est triviale (une page du dashboard Brevo à inspecter visuellement) et elle ferme proprement un doute. Si un webhook est trouvé, il sera débranché. Si aucun n'est trouvé, le constat sera consigné en annexe A2 de la spec.

**Conséquence sur la spec.** Le sous-paquet de préalables R.1 inclut une étape « audit dashboard Brevo » qui couvre : (i) inventaire des webhooks définis ; (ii) vérification que la « link tracking » est bien active globalement (pour documentation de l'état avant migration) ; (iii) recensement de toute configuration spécifique qui devrait être restaurée ailleurs après la bascule. Le compte Brevo n'est **pas supprimé** à la fin de la migration ; il reste actif en standby comme provider de repli (cf. R.6).

### 3.4 Q4 — Stratégie de test : staging dédié ou test en production avec mode test ?

**Énoncé.** Comment valider la bascule sans risquer la production ? Trois stratégies sont envisageables : (a) créer un environnement de staging complet (branche Supabase + frontend de staging) pour tester la bascule à blanc ; (b) tester en production avec un mode test (variable `MAIL_PROVIDER=resend` activable d'abord uniquement pour quelques EF, en parallèle avec Brevo qui continue à recevoir les requêtes pour les autres EF) ; (c) tester en production avec bascule complète et rollback préparé en cas de problème.

**Options envisagées :**
- *Option a — Staging dédié.* Le plus sûr en théorie, mais le projet ne dispose pas d'un staging complet de bout en bout. Créer un staging entièrement représentatif (avec ses propres secrets, son propre domaine vérifié dans Resend, son propre frontend déployé) serait un chantier dans le chantier.
- *Option b — Mode test parallèle.* Le wrapper `sendEmail(payload, opts)` du §4 supporterait un dispatch par EF via une variable `MAIL_PROVIDER_<EF_NAME>` (par exemple `MAIL_PROVIDER_REGISTER=resend` pendant que `MAIL_PROVIDER=brevo` reste le défaut). Permet de tester en production sur une EF à faible volume avant de basculer les autres.
- *Option c — Bascule complète avec rollback.* Le wrapper supporte une bascule globale via `MAIL_PROVIDER`. Si problème détecté, on rebascule en `brevo` en une seconde et on diagnostique.

**Arbitrage retenu : option b puis option c.** La bascule transport par transport (b) est la méthode même de la séquence R.2 à R.5 : chaque transport bascule indépendamment, et l'ordre commence par les transports à faible enjeu. Le wrapper `MAIL_PROVIDER` (cf. §4) rend chaque bascule réversible. Une fois tous les transports basculés et observés, l'état stable est atteint (c) : Resend partout, Brevo conservé en repli quelques semaines. Cette stratégie évite le coût d'un staging dédié et teste réellement en conditions de production, en commençant par des destinataires internes (comptes du CCLA).

**Conséquence sur la spec.** Le wrapper `sendEmail` exposé en §4 lit la variable `MAIL_PROVIDER` (valeurs `brevo` ou `resend`). La bascule transport par transport (§5) consiste, pour chaque transport, à le faire pointer sur le wrapper plutôt que directement sur Brevo, puis à positionner `MAIL_PROVIDER=resend`. Le retour arrière se fait en repassant la variable à `brevo`.

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

**Arbitrage retenu : option b.** Trois raisons. Première raison : le domaine `notifications.anarbib.org` est déjà vérifié dans Resend depuis le 07/05/2026, sans aucune action DNS supplémentaire à conduire. Cela rend le sous-paquet de préalables R.1 plus rapide. Deuxième raison : la forme `no-reply@` énonce clairement la nature transactionnelle, ce qui est conforme à la réalité (la réponse à ces mails est dirigée vers le `replyTo` configuré par bibliothèque dans `library_email_identity`, pas vers le sender). Troisième raison : la rupture de continuité visible avec l'ancien sender est compensée par un *préavis* (cf. §7.3 sur la communication aux coordinations locales) et par un *en-tête prominent* dans les premiers mails post-bascule rappelant le changement.

**Conséquence sur la spec.** La variable `SENDER_EMAIL` est mise à `no-reply@notifications.anarbib.org` au sous-paquet R.1. La variable `SENDER_NAME` reste `Biblioteca da rede AnarBib` (ou la valeur dérivée du contexte par bibliothèque, cf. `_shared/context/library-mail-routing.ts`). Une note de migration est envoyée aux coordinations locales actives lors du sous-paquet de surveillance R.5 (cf. annexe A5).

### 3.7 Synthèse des questions tranchées

| Q | Question | Arbitrage | Statut |
|---|---|---|---|
| Q1 | Aligner les transports d'abord, ou basculer chaque transport sur place ? | Basculer sur place (R.2 à R.5), aligner plus tard (R.7, hors chemin critique) | Tranchée — inversion v0.2 |
| Q2 | Doctrine tracking | Garde-fou doctrinal (§6.4 + annexe A6) | Tranchée |
| Q3 | Webhooks bounces Brevo existants | Audit dashboard en R.1 (annexe A2) | Tranchée (audit à faire) |
| Q4 | Stratégie de test | Bascule transport par transport puis état stable, sans staging dédié | Tranchée |
| Q5 | Rétention logs | Conservation des deux sources (Resend + Supabase) | Tranchée |
| Q6 | Sender visible | `no-reply@notifications.anarbib.org` | Tranchée |

---

## §4 — Architecture cible

L'architecture cible se résume en une formule : **un wrapper de transport neutre, qui choisit le provider par variable d'environnement, et que chaque transport adopte au moment où il bascule**. Le code applicatif — handlers de domaine, rendu HTML, i18n, contextes de bibliothèque — reste strictement inchangé. Seul le transport bascule.

La v0.2 dissocie deux notions que la v0.1 confondait. La v0.1 supposait un état terminal unique où les sept transports auraient convergé vers un seul fichier *avant* la bascule. La v0.2 sépare : (1) l'architecture du wrapper, décrite ici, est adoptée transport par transport au fil de la bascule ; (2) la convergence des sept transports vers un fichier unique est un objectif d'hygiène ultérieur (chantier R.7, §5), souhaitable mais non requis pour que la migration fonctionne.

Cette §4 décrit le wrapper, sa signature, le dispatch et les contrats de retour. Elle ne décrit pas la procédure de mise en place, qui est en §5.

### 4.1 Principe directeur : un wrapper neutre, deux implémentations

Le wrapper de transport est une fonction `sendEmail(...)` qui ne mentionne ni Brevo ni Resend : elle parle uniquement de mail. La sélection du provider est interne et s'opère via la variable d'environnement `MAIL_PROVIDER` (valeurs admises : `brevo`, `resend` ; défaut : `brevo`).

Le code qui appelle `sendEmail(...)` n'a pas besoin de savoir quel provider est en jeu. Cette neutralité permet :

- La bascule d'un transport en modifiant une variable d'environnement, sans nouvelle modification de code une fois le wrapper en place.
- Le retour arrière en moins d'une minute si un incident est détecté après bascule (cf. annexe A4) : repasser `MAIL_PROVIDER` à `brevo`.
- La coexistence sereine pendant la période de bascule progressive : tant que tous les transports n'ont pas adopté le wrapper, ceux qui l'ont adopté obéissent à `MAIL_PROVIDER`, les autres restent sur leur appel Brevo direct. Aucun mail n'est envoyé deux fois ni perdu : chaque mail passe par exactement un transport.
- La suppression future de Brevo (chantier R.6) en retirant l'implémentation `sendViaBrevo` et la branche correspondante du dispatch.

Le wrapper existe en deux implémentations internes : `sendViaBrevo` (le code Brevo actuel, déplacé tel quel) et `sendViaResend` (nouvelle, décrite en §4.4). Le wrapper `sendEmail` choisit l'une ou l'autre selon `MAIL_PROVIDER`.

### 4.2 Le point d'adoption : le transport partagé `notify-event`

La galaxie `notify-event` consomme un transport unique, `_shared/transport/email.ts`. C'est le premier et le plus important point d'adoption du wrapper, parce qu'il couvre en une fois toutes les notifications de réservation, emprunt, consultation, équipe et réseau.

Le transport partagé expose aujourd'hui (cf. §2.3) les fonctions `sendBrevoEmail`, `safeSendEmail`, `skippedEmailResult`, `userTargetFromProfile`, `adminTarget`, `sendAdminNotification`. L'adoption du wrapper consiste à :

- introduire `sendEmail(opts)` comme point d'envoi neutre interne au module ;
- y déplacer le corps actuel de `sendBrevoEmail` sous le nom `sendViaBrevo`, sans en changer une ligne de logique ;
- y ajouter `sendViaResend` ;
- faire que `safeSendEmail` appelle `sendEmail` au lieu de `sendBrevoEmail` directement.

**La signature de `safeSendEmail` ne change pas.** C'est le contrat que consomment tous les handlers `_shared/domain/*`. Le préserver à l'identique garantit qu'aucun fichier de domaine n'est touché par la bascule. C'est ce qui rend la bascule de toute la galaxie `notify-event` peu risquée : un seul fichier modifié, `_shared/transport/email.ts`, et un comportement inchangé tant que `MAIL_PROVIDER` vaut `brevo`.

### 4.3 Les six autres transports

Les six autres transports (la copie privée de `notify-internal-task` et les cinq inlinés dans `notify-library-request`, `notify-weekly-report`, `notify-network-weekly-report`, `notify-mid-loan-reading`, `notify-document-permission-request`, `register`) adoptent le même wrapper, mais chacun dans son propre fichier, au moment où il bascule.

Deux cas de figure :

- **`notify-internal-task`** embarque une copie de `_shared/transport/email.ts`. L'adoption du wrapper y est identique à celle du transport partagé : même modification, dans le fichier de sa copie.
- **Les cinq transports inlinés** n'ont pas de fonction de transport isolée : l'appel `fetch` vers Brevo est au milieu du corps de l'EF. Pour ceux-là, l'adoption du wrapper consiste à extraire l'appel dans une petite fonction locale calquée sur `sendEmail`, ou — plus simplement pour les EF les plus petites — à remplacer directement le bloc `fetch` Brevo par un `fetch` conditionnel selon `MAIL_PROVIDER`.

Pour ces cinq EF, la règle de décision est la suivante. **Par défaut, on extrait une fonction de transport propre** calquée sur `sendEmail`, parce que le projet privilégie les chantiers propres et qu'une fonction isolée est testable et relisible. **L'exception** — remplacement du bloc `fetch` sur place par une bifurcation conditionnelle — n'est admise que si l'extraction propre exige un effort disproportionné : par exemple lorsque l'appel Brevo est fortement entrelacé avec la logique de l'EF (variables locales nombreuses, construction du corps de mail dispersée) au point que l'extraction reviendrait à refactoriser l'EF entière. Dans ce cas, le bloc conditionnel est retenu, et la dette correspondante est explicitement notée comme item à solder lors du chantier d'alignement R.7. Le §5 applique cette règle EF par EF et documente le choix retenu pour chacune.

Le principe directeur reste minimal : faire en sorte que chaque transport respecte `MAIL_PROVIDER`, sans imposer dès maintenant la convergence vers un fichier unique.

**La convergence vers un fichier unique** — faire que les sept transports n'en forment plus qu'un, le `_shared/transport/email.ts` partagé — reste l'objectif d'hygiène à terme. Elle est décrite comme chantier R.7 (§5), hors du chemin critique. Tant qu'elle n'est pas faite, la duplication subsiste : c'est une dette assumée, le prix de la rapidité de bascule, et elle est explicitement documentée comme telle.

### 4.4 Dispatch interne et implémentation Resend

Le dispatch est une simple bifurcation :

```
fonction sendEmail(opts):
    si MAIL_PROVIDER == "resend":  retourner sendViaResend(opts)
    sinon:                         retourner sendViaBrevo(opts)
```

Le défaut est `brevo` : tant que la variable n'est pas explicitement positionnée à `resend`, le comportement reste celui de la production actuelle. La bascule d'un transport consiste à positionner `MAIL_PROVIDER=resend` dans les Edge Function Secrets — étant entendu que la variable est globale au projet Supabase, donc qu'elle agit sur tous les transports ayant adopté le wrapper en même temps (cf. §5 pour la conséquence sur l'ordre de bascule).

`sendViaBrevo` est le code Brevo actuel, déplacé sans modification : appel `POST https://api.brevo.com/v3/smtp/email`, en-tête `api-key`, corps avec `sender`, `to`, `replyTo`, `subject`, `htmlContent`, `textContent`.

`sendViaResend` est nouvelle. Elle appelle `POST https://api.resend.com/emails`, en-tête `Authorization: Bearer <RESEND_API_KEY>`, avec un corps adapté au format Resend. Les correspondances de champs sont les suivantes :

| Champ logique | Brevo | Resend |
|---|---|---|
| Authentification | en-tête `api-key: <clé>` | en-tête `Authorization: Bearer <clé>` |
| Expéditeur | `sender: {name, email}` | `from: "Nom <email>"` |
| Destinataire | `to: [{email, name}]` | `to: ["email"]` |
| Réponse | `replyTo: {email, name}` | `reply_to: "Nom <email>"` |
| Sujet | `subject` | `subject` |
| Corps HTML | `htmlContent` | `html` |
| Corps texte | `textContent` | `text` |

Aucune de ces différences n'est visible hors de `sendViaResend` : le wrapper les absorbe. Les helpers de résolution de destinataires et de routing par bibliothèque (`resolveMailRouting`, `adminTarget`, `userTargetFromProfile`) sont communs aux deux implémentations et ne changent pas.

### 4.5 Le module `inline-images.ts`

Le module `_shared/mail/inline-images.ts` inline en base64 les logos hébergés sur Supabase Storage, pour contourner la réécriture des images par Brevo (cf. §1.2). Sous Resend, sans tracking subdomain configuré (cf. §3.2), cette réécriture n'a pas lieu.

La v0.2 conserve l'inlining inconditionnellement, dans les deux implémentations. Raison : l'inlining base64 garantit que les logos restent visibles dans les archives mail des destinataires sur le long terme, indépendamment du provider et de la durée de vie des URLs Supabase Storage. C'est une propriété d'archivage utile en soi, sans coût notable. Le module est donc appelé aussi bien par `sendViaBrevo` que par `sendViaResend`.

### 4.6 Le cas `register`

`register` cumule deux particularités : un transport Brevo inliné, et un système de rendu HTML propre (palette, polices et structure de mail spécifiques, distincts du `renderEmail` partagé de `_shared/mail/layout.ts`).

La v0.1 traitait les deux en une fois : bascule du transport **et** refonte du rendu pour aligner `register` sur `renderEmail`. La v0.2, fidèle à sa logique de séparation des chantiers, dissocie :

- **Dans le périmètre de la migration #110** : seul le transport de `register` bascule. L'appel Brevo inliné adopte le wrapper `MAIL_PROVIDER`. Le rendu HTML propre de `register` est conservé tel quel. Objectif : que le mail de bienvenue parte de Resend, sans rien changer d'autre.
- **Hors périmètre de la migration #110** : la refonte du rendu de `register` pour le faire converger vers `renderEmail` est un travail d'hygiène, à rattacher soit au chantier d'alignement R.7, soit au chantier-cadre Biblioteca s'il touche aux mails de `register`. Elle n'est pas traitée ici.

Cette dissociation est cohérente avec l'inversion actée en Q1 : on ne mélange pas une migration de provider avec une refonte de rendu. **Point d'attention pour le sous-paquet `register` (§5)** : `register` a `verify_jwt` activé. Le déploiement CLI devra préserver ce réglage — un déploiement sans le flag adéquat le réinitialiserait, ce qui exposerait l'EF.

### 4.7 Variables d'environnement

Quatre variables sont liées au transport mail dans l'architecture cible.

| Variable | Statut | Valeur cible |
|---|---|---|
| `MAIL_PROVIDER` | Nouvelle | `brevo` au départ, puis `resend` |
| `RESEND_API_KEY` | Nouvelle | clé API Resend, scope domaine `notifications.anarbib.org` |
| `SENDER_EMAIL` | Existante, modifiée en R.1 | `no-reply@notifications.anarbib.org` |
| `BREVO_API_KEY_NOTIFICATIONS` | Existante, conservée jusqu'à R.6 | inchangée tant que Brevo est provider de repli |

`SENDER_NAME` reste inchangée (`Biblioteca da rede AnarBib`, indépendante du provider). Les variantes historiques de variables (`ANARBIB_SENDER_EMAIL`, `NETWORK_SENDER_EMAIL`, `BREVO_SENDER_MAIL`, etc., cf. §2.4) sont conservées en fallback pendant toute la migration et nettoyées au chantier R.6, après la période de coexistence. Les secrets `WEBHOOK_SECRET_*` sont sans rapport avec le provider mail et ne sont pas touchés.

### 4.8 Schéma de flux cible

Pour un mail typique — une notification de réservation, par exemple — le flux après adoption du wrapper est :

```
Frontend AnarBib (React)
    │  appel RPC
    ▼
PostgreSQL (Supabase)
    │  INSERT team_notification_outbox
    │  trigger trg_team_outbox_dispatch
    │  appel webhook
    ▼
Edge Function notify-event  (index.ts)
    │  handler _shared/domain/reservas.ts
    │  rendu via _shared/mail/layout.ts
    │  safeSendEmail(...)  →  sendEmail(opts)
    │                          │
    │                          ├─ MAIL_PROVIDER=brevo  → sendViaBrevo  → api.brevo.com
    │                          └─ MAIL_PROVIDER=resend → sendViaResend → api.resend.com
    ▼
Destinataire — lecteur·rice + copie coordination
```

Le seul point de bifurcation est le dispatch interne de `sendEmail`. Tout le reste — résolution de contexte, rendu HTML, policies de désactivation, inlining des logos, contrats de retour — est commun aux deux providers. C'est cette propriété qui rend la migration réversible par variable d'environnement, transport par transport.
---

## §5 — Séquence de paquets

La migration #110 se déroule en sept sous-paquets nommés R.1 à R.7. La logique générale, conforme à l'inversion actée en Q1 (§3.1), est : préparer Resend, puis basculer transport par transport en commençant par le plus structurant, puis surveiller, puis nettoyer Brevo — l'alignement architectural des transports venant en dernier, hors du chemin critique.

**Estimation.** Les sous-paquets R.1 à R.5 — la bascule fonctionnelle proprement dite — représentent 3 à 4 jours de travail effectif, conformément au cadrage « mode pragma » du backlog du 21/05. R.6 (suppression de Brevo) est différé de plusieurs semaines après R.5. R.7 (alignement architectural) est un chantier d'hygiène distinct, non chiffré en urgence, planifiable indépendamment.

**Rappel de contrainte.** La variable `MAIL_PROVIDER` est globale au projet Supabase. Dès qu'elle passe à `resend`, tous les transports ayant adopté le wrapper basculent ensemble. La séquence ci-dessous en tient compte : on adopte le wrapper dans tous les transports d'abord (R.2, R.3), en laissant `MAIL_PROVIDER` à `brevo`, et c'est seulement en R.4 qu'on bascule la variable. Il n'y a donc pas de bascule transport par transport au sens d'un changement de provider échelonné par EF ; il y a une adoption échelonnée du wrapper, puis une bascule unique de la variable. C'est plus sûr : au moment où la variable bascule, tous les transports sont déjà prêts et testés en mode `brevo`.

### 5.1 Vue d'ensemble

| Sous-paquet | Objet | Durée | Risque |
|---|---|---|---|
| R.1 | Préalables Resend (secret, sender, audit Brevo, TLS, garde-fou tracking) | 0,5 j | Faible |
| R.2 | Adoption du wrapper dans le transport partagé `notify-event` + ajout `sendViaResend` | 1 j | Faible |
| R.3 | Adoption du wrapper dans les six autres transports | 1 à 1,5 j | Moyen |
| R.4 | Bascule de `MAIL_PROVIDER` à `resend` + validation immédiate | 0,25 j | Moyen |
| R.5 | Surveillance, note aux coordinations, corrections | 2 sem (charge légère) | Faible |
| R.6 | Suppression de Brevo (code, secrets, compte) | 0,5 j | Faible |
| R.7 | Alignement architectural des transports (hygiène, hors chemin critique) | non chiffré | Faible |

### 5.2 R.1 — Préalables Resend

**Objectif.** Mettre Resend en état de recevoir le trafic, sans encore l'activer.

**Préconditions.** Aucune. R.1 peut démarrer dès validation de la spec.

| Étape | Périmètre |
|---|---|
| R.1.1 | Audit du dashboard Brevo : inventaire des webhooks sortants définis (cf. Q3) ; débrancher tout webhook pointant vers une URL obsolète ; relevé de l'état du link tracking pour traçabilité. Compte rendu en annexe A2. |
| R.1.2 | Création du secret `RESEND_API_KEY` dans les Edge Function Secrets Supabase. Clé générée dans le compte Resend du CCLA, scope limité au domaine `notifications.anarbib.org`. Vérifier que la clé ne donne accès à aucun autre domaine. |
| R.1.3 | Mise à jour de `SENDER_EMAIL` à `no-reply@notifications.anarbib.org`. **Attention — corrigé en v0.3 :** `notifications.anarbib.org` est un **sous-domaine**, et un sous-domaine n'hérite **pas** de la vérification d'expéditeur du domaine parent `anarbib.org`. Il doit être authentifié séparément chez chaque provider. Cette valeur peut être posée dès R.1, mais elle n'est effectivement utilisable que sur un provider où le sous-domaine est authentifié. Comme R.2 et R.3 s'exécutent avec Brevo encore actif, l'authentification du sous-domaine **côté Brevo** est un préalable — voir R.1.6. Le sous-domaine doit rester authentifié des deux côtés pendant toute la coexistence des providers. |
| R.1.4 | Vérification du réglage TLS dans le dashboard Resend. Le dashboard expose un mode « Opportunistic TLS » par défaut ; vérifier s'il existe un mode strict (TLS obligatoire) et, le cas échéant, le préférer — un projet libertaire a intérêt à la connexion chiffrée garantie plutôt qu'opportuniste. Si seul le mode opportuniste est disponible, le consigner sans en faire un bloquant. |
| R.1.5 | Vérification du garde-fou tracking : capture de la page `/domains/<id>/tracking` du dashboard Resend pour l'annexe A6. Confirmer qu'aucun tracking subdomain n'est créé. Ne pas valider cette page (cf. §6.4). |
| R.1.6 | **Authentification du sous-domaine `notifications.anarbib.org` côté Brevo** (ajouté en v0.3). Tant que Brevo est le provider actif (toute la durée de R.2, R.3 et jusqu'à la bascule R.4), le sous-domaine d'envoi doit y être authentifié, faute de quoi Brevo rejette l'expéditeur (« sender not valid »). Authentification par pose de quatre enregistrements DNS dans la zone OVH de `anarbib.org` : un enregistrement TXT de code de vérification Brevo sur `notifications`, deux CNAME DKIM (`brevo1._domainkey.notifications`, `brevo2._domainkey.notifications`), un TXT DMARC sur `_dmarc.notifications`. Option « Authenticate yourself » retenue, sans donner d'accès délégué à OVH (cohérence politique). Vérifier le passage au vert côté Brevo. Le sous-domaine étant par ailleurs configuré côté Resend (fait le 07/05, cf. R.1 préalables), il est dès lors authentifié chez les deux providers — état requis pour la coexistence. |

**Critère de succès.** `RESEND_API_KEY` présent et testable par un `curl` direct vers `api.resend.com/emails` (envoi d'un mail de test vers une adresse du CCLA, réception confirmée) ; compte rendu d'audit Brevo rédigé ; réglage TLS consigné ; capture tracking archivée ; sous-domaine `notifications.anarbib.org` authentifié et au vert côté Brevo comme côté Resend.

### 5.3 R.2 — Adoption du wrapper dans le transport partagé `notify-event`

**Objectif.** Doter `_shared/transport/email.ts` du wrapper `sendEmail` et de l'implémentation `sendViaResend`, sans changer le comportement en production (`MAIL_PROVIDER` reste `brevo`).

**Préconditions.** R.1 close.

| Étape | Périmètre |
|---|---|
| R.2.1 | Dans `_shared/transport/email.ts` : renommer le corps actuel de `sendBrevoEmail` en `sendViaBrevo` (déplacement de code, aucune modification de logique). |
| R.2.2 | Ajouter `sendViaResend` dans le même module : appel `POST api.resend.com/emails`, format Resend (cf. tableau §4.4), appel à `inlineLogosInHtml` conservé. |
| R.2.3 | Ajouter `sendEmail(opts)` : dispatch sur `MAIL_PROVIDER`, défaut `brevo`. Faire que `safeSendEmail` appelle `sendEmail` au lieu de l'ancien `sendBrevoEmail`. La signature de `safeSendEmail` ne change pas. |
| R.2.4 | Test runtime, `MAIL_PROVIDER` non défini (donc `brevo`) : déclencher un mail via `notify-event` (par exemple une réservation de test), vérifier que le comportement et le rendu sont strictement identiques à avant. |
| R.2.5 | Test runtime local, `MAIL_PROVIDER=resend` : via `supabase functions serve` en local, vérifier que `sendViaResend` envoie correctement et que le mail arrive. |

**Déploiement.** `notify-event` est l'exception CLI de la doctrine (cf. §6.6 Règle 2, foyer **DOC-DEPLOY-2**) : déployée à la main par `supabase functions deploy notify-event --no-verify-jwt`, jamais par l'outil MCP. Une fois le bundle `_shared` inclus, elle dépasse 150 ko, volume incompatible avec le déploiement automatisé.

**Critère de succès.** `notify-event` déployé avec le wrapper en place ; en production `MAIL_PROVIDER` reste `brevo` et le comportement est inchangé ; `sendViaResend` est validée en local.

### 5.4 R.3 — Adoption du wrapper dans les six autres transports

**Objectif.** Doter les six transports restants du même wrapper, toujours sans basculer `MAIL_PROVIDER`.

**Préconditions.** R.2 close (le wrapper de référence existe et sert de modèle).

Les six transports concernés : la copie privée de `notify-internal-task`, et les transports inlinés de `notify-library-request`, `notify-weekly-report`, `notify-network-weekly-report`, `notify-mid-loan-reading`, `notify-document-permission-request`, `register`.

| Étape | Périmètre |
|---|---|
| R.3.1 | `notify-internal-task` : sa copie de `_shared/transport/email.ts` reçoit le même traitement qu'en R.2 (renommage `sendViaBrevo`, ajout `sendViaResend` et `sendEmail`). |
| R.3.2 | Les cinq EF à transport inliné : pour chacune, application de la règle de décision de §4.3 — extraction d'une fonction de transport propre par défaut, bloc conditionnel sur place seulement si l'extraction est disproportionnée. Le choix retenu pour chaque EF est consigné dans le commit correspondant. |
| R.3.3 | Cas `register` : seul le transport bascule (adoption du wrapper). Le rendu HTML propre de `register` est conservé tel quel (cf. §4.6). **Au déploiement, préserver `verify_jwt` activé** : le déploiement CLI doit passer le flag adéquat, faute de quoi l'EF serait exposée. |
| R.3.4 | Test runtime pour chaque EF, `MAIL_PROVIDER` non défini (`brevo`) : déclencher le mail correspondant, vérifier le comportement inchangé. La procédure de test par EF est détaillée en annexe A3. |

**Déploiement.** Doctrine forward (corrigée v0.4, foyer **DOC-DEPLOY-1/2**) : les EF se déploient via `git push` → Woodpecker (`deploy-edge-functions`), `notify-event` étant la seule exception CLI. Un commit par EF, conformément à la doctrine « un fix à la fois ». *(Note historique : R.3, clos le 21/05 avant canonisation de la doctrine, a été déployé en CLI `supabase functions deploy <nom>` — voir le bilan d'exécution ci-dessous ; cette voie n'est plus la doctrine pour tout nouveau travail.)*

**Risque.** Moyen — c'est l'étape qui touche le plus de fichiers. Mitigation : un commit et un test runtime par EF, dans l'ordre du moins critique au plus critique (suggestion : `notify-mid-loan-reading`, `notify-document-permission-request`, `notify-network-weekly-report`, `notify-weekly-report`, `notify-library-request`, `notify-internal-task`, `register` en dernier car porteuse du `verify_jwt`).

**Critère de succès.** Les six transports ont adopté le wrapper ; en production `MAIL_PROVIDER` est toujours `brevo` et tous les mails partent encore de Brevo, comportement inchangé ; chaque EF a été testée individuellement.

**Bilan d'exécution — R.3 clos le 21/05/2026 (ajouté en v0.3).** Les sept transports autonomes ont adopté le wrapper neutre `sendEmail` dispatchant par `MAIL_PROVIDER` : `notify-mid-loan-reading`, `notify-document-permission-request`, `notify-network-weekly-report`, `notify-weekly-report`, `notify-library-request`, `notify-internal-task` (copie privée du transport, cas R.3.1), `register` (cas R.3.3). La v0.2 comptait « six transports » plus `register` traité à part ; le total réel de transports autonomes traités est donc de sept.

Décision §4.3 pour chacun : **extraction propre** dans les sept cas — la fonction de transport a été isolée puis dédoublée en `sendViaBrevo` / `sendViaResend`, sans jamais recourir au bloc conditionnel sur place. **Aucune dette n'est donc reportée au chantier d'hygiène R.7.** Deux cas ont demandé une attention particulière, traités sans déroger à l'extraction propre : `notify-library-request` et `register` inlinent les logos — l'appel à `inlineLogosInHtml` a été factorisé une seule fois dans le wrapper, en amont du dispatch, commun aux deux providers (conforme à §4.5) ; `register` construit ses payloads au format Brevo natif sur trois sites d'appel — conformément à §4.6 (seul le transport bascule), les trois sites n'ont pas été réécrits, le payload Brevo sert de format d'entrée pivot et `sendViaResend` le traduit vers le format Resend par une fonction pure isolée.

Six des sept EF ont été testées en runtime avec `MAIL_PROVIDER` non défini (donc Brevo) : mail reçu, comportement et rendu inchangés. La septième, `notify-document-permission-request`, a son test runtime **reporté à R.4** : la table `library_contact_profiles` est vide pour les bibliothèques concernées, tous les envois retomberaient en `skipped` sans atteindre le transport. La non-régression est établie par preuve de lecture (le transport y était déjà isolé avant R.3, l'extraction n'a donc rien réécrit de risqué) ; le test deviendra exerçable en R.4. Pour `register`, la vérification que `verify_jwt` reste activé après déploiement (exigée par R.3.3) a été faite et confirmée : appel sans JWT rejeté en 401.

Couture découverte en cours d'exécution : voir le changelog v0.2 → v0.3, point 1, et la correction de R.1.3 / l'ajout de R.1.6.

### 5.5 R.4 — Bascule de `MAIL_PROVIDER`

**Objectif.** Activer Resend pour l'ensemble des transports en une opération.

**Préconditions.** R.2 et R.3 closes — tous les transports ont adopté le wrapper.

| Étape | Périmètre |
|---|---|
| R.4.1 | Vérifications préalables : tous les secrets en place, `RESEND_API_KEY` valide, dashboard Resend accessible, procédure de rollback (annexe A4) relue. Choisir une fenêtre temporelle calme et rester disponible 2 heures après la bascule. |
| R.4.2 | Passer `MAIL_PROVIDER` à `resend` dans les Edge Function Secrets du dashboard Supabase. La variable étant globale, tous les transports basculent ensemble. Aucun redéploiement de code n'est nécessaire — les EF lisent la variable au prochain invoke. |
| R.4.3 | Validation immédiate : déclencher un mail de chaque grande famille — un signup (`register`), une notification de réservation (`notify-event`), une notification d'emprunt, un rapport hebdomadaire — et vérifier réception, rendu, en-têtes SPF/DKIM/DMARC, et apparition dans le dashboard Resend avec statut `delivered`. |
| R.4.4 | Vérifier dans le dashboard Brevo l'absence de tout nouvel envoi après la bascule. |

**Critère de succès.** Tous les types de mails partent de Resend ; aucune erreur dans les logs Edge Function dans les 2 heures ; rollback disponible et compris.

**Rollback.** En cas d'échec d'un critère, repasser `MAIL_PROVIDER` à `brevo` (annexe A4). Effet immédiat. Diagnostic à froid ensuite.

### 5.6 R.5 — Surveillance et corrections

**Objectif.** Observer le comportement réel sur deux semaines, corriger les écarts, préparer la décision de suppression de Brevo.

**Préconditions.** R.4 close.

| Étape | Périmètre |
|---|---|
| R.5.1 | Note de migration aux coordinations locales actives (BLMF, BTL) : annonce du changement de sender vers `no-reply@notifications.anarbib.org`, invitation à l'ajouter aux contacts. Texte indicatif en annexe A5. Note envoyée depuis le nouveau sender — premier test grandeur nature. |
| R.5.2 | Surveillance hebdomadaire légère : consultation du dashboard Resend (statuts d'envoi, bounces, plaintes) et des logs Edge Function. Écoute des retours des coordinations. |
| R.5.3 | Correction au cas par cas des écarts détectés : bounces sur adresses obsolètes, éventuelles plaintes spam, ajustements de rendu. |
| R.5.4 | Bilan à deux semaines : décision d'ouvrir ou non R.6. |

**Critère de succès.** Aucun incident bloquant sur deux semaines ; volume de bounces et de plaintes comparable ou inférieur à l'observé sous Brevo.

### 5.7 R.6 — Suppression de Brevo

**Objectif.** Retirer Brevo du code et de la configuration.

**Préconditions.** R.5 close, bilan favorable, délai minimal de quelques semaines de coexistence stable depuis R.4, et absence d'élément (incident Resend, évolution tarifaire) qui justifierait de conserver Brevo en repli.

| Étape | Périmètre |
|---|---|
| R.6.1 | Dans chaque transport : suppression de `sendViaBrevo` et de la branche `brevo` du dispatch. `sendEmail` devient un appel direct à `sendViaResend`. La variable `MAIL_PROVIDER` peut être conservée par cohérence (valeur fixe `resend`) ou retirée. |
| R.6.2 | Suppression des secrets Brevo dans Supabase : `BREVO_API_KEY_NOTIFICATIONS` et toute variante. Vérifier qu'aucun code ne les lit plus. |
| R.6.3 | Nettoyage des variantes historiques de variables d'environnement conservées en fallback (`ANARBIB_SENDER_EMAIL`, `NETWORK_SENDER_EMAIL`, `BREVO_SENDER_MAIL`, etc.). |
| R.6.4 | Décision sur le compte Brevo lui-même : conservation en standby (compte gratuit, sans frais) pour une période transitoire, ou fermeture. Recommandation par défaut : standby quelques mois, puis fermeture. |

**Critère de succès.** Aucune référence à Brevo dans le code de production hors commentaires historiques ; aucun secret Brevo dans Supabase ; tous les mails partent de Resend.

### 5.8 R.7 — Alignement architectural des transports (hygiène)

**Objectif.** Faire converger les sept transports vers le seul `_shared/transport/email.ts` partagé, en supprimant les copies et les transports inlinés. C'est l'objectif que la v0.1 plaçait en tête de chantier (sous le nom M.0) et que la v0.2 déplace en fin de séquence.

**Statut.** Chantier d'hygiène, hors du chemin critique de la migration. La migration #110 est fonctionnellement terminée à la fin de R.6 : tous les mails partent de Resend. R.7 ne change rien au comportement ; il réduit la dette de duplication.

**Préconditions.** R.6 close (inutile d'aligner des transports qui contiennent encore du code Brevo).

**Périmètre indicatif.** Faire pointer `notify-internal-task` et les cinq EF anciennement inlinées vers le `_shared/transport/email.ts` partagé ; supprimer la copie privée de `notify-internal-task` et les fonctions de transport locales ; dédupliquer les éventuelles copies de `inline-images.ts`. Si l'un des transports inlinés a été basculé en R.3 par un bloc conditionnel sur place (exception de §4.3) plutôt que par extraction propre, c'est en R.7 que la dette correspondante est soldée.

**Articulation avec le chantier-cadre Biblioteca.** Si le chantier-cadre Biblioteca (étape 8, EA-13/14/19) conduit à retoucher certains de ces transports ou le rendu de `register`, R.7 peut être fusionné ou coordonné avec lui plutôt que mené séparément. Cette décision est laissée au moment de la planification, en fonction de l'ordre réel des chantiers.

**Estimation.** Non chiffrée en urgence. À cadrer au moment où R.7 est planifié.

### 5.9 Synthèse temporelle

La bascule fonctionnelle — R.1 à R.4 — représente 3 à 4 jours de travail effectif, à conduire sur une à deux semaines selon la cadence. R.5 ajoute deux semaines calendaires de surveillance à charge légère. R.6 est une demi-journée, après quelques semaines de coexistence. R.7 est un chantier d'hygiène ultérieur, sans échéance.

Le jalon qui débloque l'étape 8 du chantier-cadre Biblioteca (EA-13/14/19) est la fin de R.4 : à partir de là, la couche mail tourne sur Resend et le chantier-cadre peut reprendre sa séquence sur une base stable. Il n'est pas nécessaire d'attendre R.6 ni R.7 pour cela.

La séquence peut être suspendue proprement entre deux sous-paquets : après R.1, après R.2, ou après R.4. Seule la paire R.2+R.3 gagne à être conduite d'affilée, puisque c'est R.3 qui complète l'adoption du wrapper commencée en R.2, et qu'il vaut mieux ne pas laisser longtemps le parc de transports dans un état mixte (certains avec wrapper, d'autres sans) même si cet état mixte est, en soi, sans danger.

---

## §6 — Tests, hardenings et garde-fous opérationnels

Cette section consolide les vérifications, hardenings et garde-fous qui encadrent le chantier. Elle distingue quatre niveaux : les tests runtime à conduire pendant les sous-paquets (§6.1) ; le garde-fou doctrinal sur le tracking Resend (§6.4) ; les hardenings techniques inscrits dans le code (§6.5) ; et la doctrine d'implémentation, c'est-à-dire les règles de déploiement non négociables du projet (§6.6).

### 6.1 Tests runtime par sous-paquet

Chaque sous-paquet se conclut par un test runtime qui valide son livrable, en application de la précision opérationnelle v13.5 : tout paquet doit s'achever par une vérification finale.

**R.1 — Test des préalables.** Test direct de l'API Resend par `curl`, sans passer par le code AnarBib :

```
curl -X POST https://api.resend.com/emails \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"from":"AnarBib <no-reply@notifications.anarbib.org>",
       "to":["<adresse-test-CCLA>"],
       "subject":"Test R.1",
       "html":"<p>Test R.1</p>","text":"Test R.1"}'
```

Réception confirmée + réponse `200` avec un `id` = préalables validés.

**R.2 — Test du wrapper sur `notify-event`.** Deux tests. D'abord `MAIL_PROVIDER` non défini (donc `brevo`) : déclencher une notification de réservation, vérifier que rendu et livraison sont strictement identiques à l'avant-R.2. Ensuite, en local via `supabase functions serve` avec `MAIL_PROVIDER=resend` : vérifier que `sendViaResend` envoie et que le mail arrive.

**R.3 — Test de chaque transport.** Pour chacune des six EF, `MAIL_PROVIDER` restant à `brevo` : déclencher le mail correspondant et vérifier le comportement inchangé. La procédure détaillée par EF est en annexe A3. Le test de `register` inclut une vérification que `verify_jwt` est toujours actif après déploiement.

**R.4 — Test post-bascule.** Dans l'heure suivant le passage de `MAIL_PROVIDER` à `resend`, déclencher au minimum : un signup (`register`), une notification de réservation, une notification d'emprunt, un rapport hebdomadaire. Pour chacun, vérifier réception, rendu, en-têtes SPF/DKIM/DMARC, et présence dans le dashboard Resend avec statut `delivered`. Vérifier en parallèle l'absence de tout nouvel envoi dans le dashboard Brevo.

**R.5 — Observation.** Pas de test actif : consultation hebdomadaire du dashboard Resend et des logs Edge Function, écoute des coordinations.

**R.6 — Test post-suppression Brevo.** Après retrait de `sendViaBrevo` et des secrets Brevo : déclencher un mail de chaque type, vérifier qu'aucune régression n'a été introduite par la simplification.

**R.7 — Test post-alignement.** Après convergence des transports : déclencher un mail de chaque EF, vérifier que le comportement est inchangé et que `grep -r "api.brevo.com"` ne retourne plus aucune occurrence active.

### 6.2 Test du transport partagé comme référence

Le risque principal de R.2 et R.3 est la régression silencieuse : un transport qui, après adoption du wrapper, n'envoie plus exactement comme avant. La parade est une comparaison avant/après systématique.

Avant de toucher un transport, on capture le comportement de référence : un mail de test déclenché, son rendu observé dans au moins deux clients (un client lourd type Thunderbird, un webmail type Gmail), ses en-têtes relevés. Après adoption du wrapper, `MAIL_PROVIDER` toujours à `brevo`, on rejoue exactement le même test : le résultat doit être identique au bit près côté rendu. Toute différence est une régression à corriger avant de continuer.

Cette comparaison vaut pour les huit fichiers de transport. Elle est d'autant plus importante pour les cinq EF anciennement inlinées, où l'extraction de la fonction de transport (cf. §4.3) manipule du code qui n'avait jamais été isolé.

### 6.3 Vérification automatique en fin de sous-paquet

La doctrine du chantier linter impose, pour les migrations DB, un bloc `DO` de vérification automatique en fin de transaction. Le présent chantier ne contient pas de migration DB ; le principe se transpose en test runtime auto-bloquant : un test qui, s'il échoue, interdit de clore le sous-paquet et de passer au suivant.

Concrètement, pour chaque sous-paquet de R.2 et R.3, le test runtime de §6.1 est la condition de clôture. Un transport dont le test de non-régression échoue n'est pas considéré comme livré, quel que soit l'état du code. La discipline est la même que pour les blocs `DO` SQL : la vérification n'est pas optionnelle et son échec bloque.

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

Une vérification programmatique périodique est envisageable (cf. Q2 §3.2, option c). Elle consisterait en un cron `pg_cron` hebdomadaire qui appelle `GET https://api.resend.com/domains/<id>` et alerte par mail si `click_tracking` ou `open_tracking` passent à `true`. Cette option n'est pas mise en place dans le périmètre de la présente migration. Elle est inscrite au backlog comme item à activer uniquement si un futur incident révèle que le garde-fou doctrinal n'a pas suffi.

### 6.5 Hardenings techniques

Plusieurs hardenings sont inscrits dans le code du wrapper pour prévenir les régressions silencieuses et faciliter le diagnostic.

**H.1 — Logging structuré du provider effectif.** Le wrapper `sendEmail` logue, à chaque appel, la valeur effective de `MAIL_PROVIDER` et le `label` du mail. En cas d'incident, cela permet de savoir immédiatement quel provider a été utilisé, sans avoir à inspecter les appels HTTP.

**H.2 — Validation défensive de `MAIL_PROVIDER`.** `sendEmail` n'accepte que `brevo` ou `resend` (comparaison insensible à la casse, valeur découpée des espaces). Toute autre valeur — typiquement une typo dans le dashboard Supabase — déclenche un avertissement loggé et un repli sur `brevo`. L'EF ne plante pas, mais le log signale le problème sans ambiguïté.

**H.3 — Test de fumée au démarrage.** Au démarrage à froid d'une EF mail, une vérification confirme que le secret du provider courant est présent. Si `MAIL_PROVIDER=resend` mais que `RESEND_API_KEY` est absent ou vide, l'EF logue un avertissement explicite dès le démarrage, ce qui évite le scénario silencieux d'un mail qui échoue en authentification et n'est diagnostiqué que sur signalement.

**H.4 — Conservation de l'inlining des logos.** Décidée en §4.5, la conservation de `inline-images.ts` sous Resend a aussi valeur de hardening : si Resend modifiait un jour son comportement par défaut sur les images, les archives mail seraient déjà protégées par l'inlining base64.

**H.5 — Conservation de Brevo en repli jusqu'à R.6.** Pendant toute la période R.4 + R.5, le compte Brevo reste actif, le secret `BREVO_API_KEY_NOTIFICATIONS` reste en place, et `sendViaBrevo` reste dans le code. C'est ce qui rend le rollback `MAIL_PROVIDER=brevo` instantané. Brevo n'est retiré qu'en R.6, après la période de coexistence stable.

### 6.6 Doctrine d'implémentation — règles de déploiement non négociables

Cette sous-section est une nouveauté de la v0.2. La v0.1 mentionnait ces règles de manière incidente ; la v0.2 en fait une section ferme, parce que le chantier #110 touche `notify-event` et, à terme, des migrations, et que ce sont précisément les terrains où ces règles s'appliquent.

**Règle 1 — Migrations SQL : fichier horodaté commité, jamais l'outil MCP `apply_migration`.** Toute migration de base de données est écrite dans un fichier horodaté du dossier de migrations, committée, et appliquée par Woodpecker via `db push`. L'outil MCP `apply_migration` est proscrit : il horodate la migration au moment de l'appel, ce qui crée un décalage avec l'ordre des fichiers committés et fait échouer le CI. Le présent chantier ne prévoit pas de migration DB, mais la règle est rappelée car elle est absolue et vaut pour tout travail connexe.

**Règle 2 — Déploiement des Edge Functions : `git push` → Woodpecker ; `notify-event` est la seule exception CLI.** (Foyer : **DOC-DEPLOY-1/2** au registre des décisions.) Cas général : déploiement par le pipeline Woodpecker (`deploy-edge-functions`) au `git push` ; l'outil MCP `deploy_edge_function` reste proscrit. **Seule** exception : `notify-event`, qui une fois le bundle `_shared/` inclus dépasse 150 ko — volume incompatible avec le déploiement automatisé — et se déploie donc à la main par la CLI `supabase functions deploy notify-event --no-verify-jwt`. Pour `register`, le déploiement doit au contraire préserver `verify_jwt` activé (cf. §4.6) : c'est la seule EF à le conserver. *(Correction v0.4 : la v0.3 généralisait à tort la CLI à toutes les EF ; R.3 a historiquement été déployé en CLI avant canonisation, cf. §5.4.)*

**Règle 3 — Pas de branche Supabase de développement.** Le flux du projet est Codeberg plus Woodpecker. On ne crée pas de branche Supabase de dev, et on ne recourt pas à un merge de branche Supabase. L'outil MCP `merge_branch` n'a pas d'usage dans ce chantier. Toute évolution passe par un commit sur le dépôt git et le pipeline Woodpecker.

**Règle 4 — Un fix à la fois.** Chaque sous-paquet R.x — et, à l'intérieur de R.3, chaque EF — est committé séparément, déployé séparément, testé séparément avant de passer au suivant. Pas de regroupement de plusieurs sous-paquets dans un commit unique, même s'ils paraissent connexes. Cette discipline permet, en cas de régression, d'isoler exactement la modification fautive.

**Règle 5 — Validation runtime avant clôture.** Un sous-paquet n'est clos qu'après un test runtime conforme à §6.1. Un commit qui compile n'est pas un sous-paquet livré : la livraison suppose la vérification du comportement réel.

Ces cinq règles ne sont pas propres au chantier #110 : ce sont des règles permanentes du projet AnarBib. Elles sont rappelées ici parce qu'une migration de couche mail est exactement le genre de chantier où la tentation d'un raccourci — appliquer une migration vite via MCP, déployer `notify-event` via l'outil intégré — est la plus forte. La spec acte qu'aucun de ces raccourcis n'est pris.

### 6.7 Critères de succès cumulés du chantier

À la clôture de R.6, les critères de succès cumulés sont les suivants :

1. **Tous les mails partent de Resend.** Vérifiable par le dashboard Resend (présence des envois) et le dashboard Brevo (absence de nouvel envoi).
2. **Aucune référence active à Brevo dans le code.** Vérifiable par `grep -r -i "brevo"` sur le dossier des fonctions : ne doivent rester que des commentaires historiques.
3. **Aucun secret Brevo dans Supabase.** Vérifiable dans le dashboard Edge Function Secrets.
4. **Aucune régression de délivrabilité.** Volume de bounces et de plaintes comparable ou inférieur à l'observé sous Brevo, sur la période d'observation R.5.
5. **Garde-fou tracking inscrit.** Dans la spec, dans le registre RGPD, et — au chantier ultérieur dédié — dans le manuel admin réseau.
6. **Page de tracking Resend jamais validée.** Vérifiable visuellement dans le dashboard Resend : la section tracking du domaine `notifications.anarbib.org` reste à l'état non configuré.

Le critère 2 admet une réserve tant que R.7 n'est pas fait : si un transport a été basculé en R.3 par un bloc conditionnel sur place (exception de §4.3), il contient encore une branche `brevo` jusqu'à R.6. Après R.6, la branche `brevo` disparaît de tous les transports ; après R.7, la duplication structurelle elle-même disparaît. Le critère 2 s'entend donc « à la clôture de R.6 », l'alignement R.7 étant un raffinement d'hygiène et non une condition de succès de la migration.

---

## §7 — Impacts collatéraux

La migration touche au transport mail uniquement, mais ce transport est référencé dans plusieurs documents et configurations annexes du projet. Cette section recense les impacts à traiter au cours du chantier ou en suivi immédiat, par domaine.

### 7.1 Documentation RGPD — registre des traitements

Le projet maintient depuis la Phase 6 RGPD (acquis 04-05/05/2026) un registre des traitements à `docs/legal/registre-traitements.md`. Ce document liste les sous-traitants au sens de l'article 28 du RGPD et les bases légales associées. Brevo y figure actuellement comme sous-traitant de l'envoi de notifications transactionnelles. La migration impose plusieurs modifications.

**Modifications à apporter au registre :**

1. **Substitution Brevo → Resend dans la liste des sous-traitants**, avec mise à jour des champs : raison sociale (Resend Inc., Delaware, États-Unis), finalité (envoi de notifications transactionnelles), catégories de données traitées (adresses mail des destinataires, contenu des mails, métadonnées d'envoi), durée de conservation (30 jours pour les logs côté Resend, vs 30 jours côté Brevo — pas de changement net pour les destinataires), base légale (exécution du service, art. 6(1)(b) RGPD pour les comptes ouverts, intérêt légitime art. 6(1)(f) pour les copies admin).

2. **Mention explicite de la résidence géographique** : Resend est une entreprise américaine, hébergement principal en Europe (region eu-west-1 Ireland pour le domaine `notifications.anarbib.org`, ce qui couvre la majorité des envois). La spec note que cette résidence US assumée s'inscrit dans la doctrine déjà arrêtée du projet (cf. §1.4), où Supabase est en sa-east-1 São Paulo, et où la légalité repose sur les CCT 2021/914 module 2 (controller-to-processor) et non sur une résidence UE stricte.

3. **Mention du DPA Resend** : Resend met à disposition un Data Processing Agreement standardisé sur leur site, accessible publiquement à `https://resend.com/legal/dpa`. La date de prise d'effet du DPA pour le compte CCLA est à enregistrer (équivalent du TFXNN-HUMKJ-3WKP8-MZMYW que le projet a pour Supabase). À conduire en R.1 ou R.6 selon la disponibilité.

4. **Mention du garde-fou tracking** : ajout dans le registre d'une note explicative sur la configuration `notifications.anarbib.org` chez Resend, précisant que le tracking est désactivé et que cette désactivation est doctrinalement protégée par interdiction de validation de la page `/domains/<id>/tracking` du dashboard. Cette note vaut comme **engagement de minimisation des données** au sens de l'article 5(1)(c) RGPD.

5. **Suppression de la mention `inline-images.ts`** comme contre-mesure tracking : sous Resend, le module reste actif (cf. §4.5) mais sa raison d'être change de contre-mesure défensive à garantie d'archivage. Le registre est mis à jour en conséquence.

**Calendrier.** Modification du registre conduite en R.4 (jour de la bascule effective) ou immédiatement après. Le registre est un document politique : sa mise à jour ne peut pas attendre R.6. Une version intermédiaire peut être inscrite en R.1 avec mention « migration en cours » si la coordination réseau le souhaite.

### 7.2 Documentation RGPD — politique de confidentialité publique

Le projet n'a pas encore publié de politique de confidentialité destinée aux destinataires des mails. C'est un item du backlog RGPD identifié en mai 2026 mais non traité au stade actuel. La présente migration ne crée pas l'obligation, mais elle est l'occasion d'inscrire la liste des sous-traitants dans une formulation accessible.

**Recommandation.** Profiter de la bascule pour publier une première version courte de la politique de confidentialité sur `https://anarbib.org/confidentialite` (ou équivalent sur le site statique du projet), mentionnant : (i) que les notifications transactionnelles transitent par Resend ; (ii) que le tracking d'ouverture et de clic est désactivé sur le domaine d'envoi ; (iii) que les destinataires peuvent demander suppression de leurs données par contact à `anarbib@proton.me`.

Cette publication n'est pas un sous-paquet de la migration mais un item de backlog que la migration **rend prioritaire**. Recommandation : score backlog 8 à 10 (priorité moyenne-haute), à activer dans le mois suivant R.4.

### 7.3 Communication aux coordinations locales

La bascule effective en R.4 change le sender visible des mails (`no-reply@notifications.anarbib.org` au lieu de `anarbib@anarbib.org`). Ce changement est mineur en apparence mais peut avoir deux effets opérationnels :

- **Marquage en spam** : un destinataire dont le client mail avait appris à reconnaître l'ancien sender peut classer en spam le premier mail issu du nouveau sender. Risque limité dans le temps (le client mail apprend rapidement) mais réel pour la première semaine post-bascule.
- **Confusion sur la légitimité** : un destinataire qui reçoit un mail depuis un sender qu'il ne reconnaît pas peut hésiter sur son authenticité, surtout s'il s'agit d'un mail à enjeu (cooptation, suspension, retrait collectif).

**Note de migration aux coordinations locales (cf. annexe A5).** Une note courte est envoyée en R.5 aux coordinations BLMF et BTL, annonçant le changement de sender. Le contenu de la note couvre : (i) le motif politique de la migration (rappel synthétique du tracking imposé par Brevo) ; (ii) le nouveau sender et l'invitation à l'ajouter aux contacts pour éviter le marquage spam ; (iii) le contact en cas de mail manquant ou suspect.

Cette note est rédigée en pt-BR (langue principale des coordinations actives) et traduite en fr/es/en/it/de pour archivage. Le contenu indicatif est en annexe A5.

**Calendrier.** Envoi en R.5, peu après la bascule effective de R.4. La note est elle-même envoyée depuis le nouveau sender — c'est un test de cohérence du dispositif.

### 7.4 Impacts sur le frontend AnarBib

Comme noté en §2.5, le frontend n'a aucune dépendance directe à Brevo. La seule interaction frontend / mail passe par les booléens retournés par l'EF `register` (`email_usuaria_enviado`, `library_notification_enviada`, `admin_notification_enviada`). Ces booléens restent strictement identiques après la migration : ils ne dépendent pas du provider.

**Aucune modification frontend n'est nécessaire** au titre de la migration. Le seul test frontend à conduire est un test de fumée en R.4 : signup en navigation privée → réception du mail welcome → clic sur le CTA → arrivée sur `/solicitar-biblioteca` en cas de signup sans biblio. Ce test couvre simultanément la chaîne backend (register → Resend → boîte mail) et frontend (CTA → route → page rendue).

**Note opérationnelle.** Le test de fumée frontend en R.4 doit utiliser un compte de test (par exemple `anarbib+test-m4@proton.me`) qui n'a jamais été créé auparavant. Sans cette précaution, le signup peut échouer avec `EMAIL_ALREADY_EXISTS`, ce qui masque le vrai test.

### 7.5 Impacts sur la configuration Supabase

La migration ajoute, modifie ou supprime plusieurs secrets dans les Edge Function Secrets du dashboard Supabase. Le résumé est synthétisé dans le tableau de l'annexe A2. Trois opérations principales :

- **Ajout** : `RESEND_API_KEY` et `MAIL_PROVIDER` (en R.1 et R.2).
- **Modification** : `SENDER_EMAIL` (en R.1, de `anarbib@anarbib.org` vers `no-reply@notifications.anarbib.org`).
- **Suppression** (en R.6) : `BREVO_API_KEY_NOTIFICATIONS`, `BREVO_API_KEY`, et leurs variantes historiques (`BREVO_API_KEY_STAGING`, `ANARBIB_SENDER_EMAIL`, `NETWORK_SENDER_EMAIL`, `BREVO_SENDER_MAIL`, etc.).

Les secrets liés aux webhooks Postgres-EF (`WEBHOOK_SECRET_NOTIFY_EVENT`, `WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK`, etc.) restent inchangés — ils n'ont aucun rapport avec le provider mail.

### 7.6 Impacts sur les archives mail des destinataires

Les destinataires qui auront archivé des mails AnarBib avant la migration verront, dans leurs archives, des liens CTA qui pointent vers le domaine de tracking Brevo (`sendibt3.com` ou variantes). Ces liens ont une durée de vie limitée côté Brevo : à terme, ils retourneront probablement un 404 ou une page d'erreur, ce qui rendra les vieux mails partiellement cassés.

**Aucune action corrective possible** côté AnarBib : les mails archivés sont chez les destinataires, pas chez nous. Ce point n'est mentionné ici que pour traçabilité : il s'agit d'une externalité de la décision initiale d'utiliser Brevo, qui pourrait justifier rétrospectivement la migration auprès des destinataires sceptiques (« vos vieux mails AnarBib vont casser à cause de Brevo, c'est pour ça qu'on bascule »).

Les mails envoyés après la migration auront, eux, des CTAs pointant directement vers `https://app.anarbib.org/...` sans intermédiaire de tracking. Leur durée de vie sera celle du domaine `app.anarbib.org` lui-même, c'est-à-dire la durée de vie du projet.

### 7.7 Impacts sur les tests internes et la documentation technique

Plusieurs documents internes mentionnent Brevo de manière incidente. Liste indicative des emplacements à vérifier et mettre à jour en R.6 ou immédiatement après :

- `docs/decisions/BUG_LOGOS_BREVO_TRACKER_2026-05-06.md` : ce document explique le rationale du module `_shared/mail/inline-images.ts`. Il reste pertinent comme archive historique et n'a pas besoin d'être supprimé. Une note de clôture peut être ajoutée en R.6 : « contre-mesure rendue inutile par la migration Resend, conservée pour archivage durable des logos ».
- Les éventuels READMEs des EF qui mentionneraient Brevo dans leur description. À grep en R.6.
- Le `docs/specs/spec-administrateur-reseau.md` (v0.3 du 11/05/2026) mentionne probablement Brevo dans la section sur les notifications de cooptation. À vérifier et mettre à jour.
- Les commit messages historiques mentionnant Brevo ne sont pas modifiables et restent en l'état.

Cette vérification est inscrite comme sous-tâche de R.6 (cf. §5.7).

### 7.8 Synthèse des impacts collatéraux

| Domaine | Impact | Calendrier | Sous-paquet |
|---|---|---|---|
| Registre des traitements RGPD | Substitution Brevo→Resend, mention DPA, garde-fou tracking | R.4 ou immédiatement après | R.4 / hors-paquet |
| Politique de confidentialité publique | Création (item de backlog rendu prioritaire) | Mois suivant R.4 | Hors présent chantier |
| Communication coordinations locales | Note de migration en pt-BR + 5 langues archivées | R.5 | R.5.1 |
| Frontend AnarBib | Aucune modification, test de fumée seulement | R.4 | R.4.3 |
| Configuration Supabase (secrets) | Ajout, modification, suppression progressive | R.1, R.4, R.6 | R.1, R.4, R.6 |
| Archives mail des destinataires | Aucune action corrective possible | — | — |
| Documentation technique interne | Mise à jour mentions Brevo dans /docs | R.6 | R.6 |
| Chantier-cadre Biblioteca étape 8 | Déblocage de EA-13 / EA-14 / EA-19 | À la fin de R.4 | cf. §7.9 |

### 7.9 Déblocage du chantier-cadre Biblioteca

Cette migration n'est pas seulement un chantier autonome : elle est, dans la planification du 21/05, le verrou de l'étape 8 du chantier-cadre Biblioteca. Cette étape regroupe trois écarts — EA-13, EA-14, EA-19 — qui portent sur des mails et qui ne peuvent être traités proprement que sur une couche de transport stabilisée.

L'impact est un impact de séquencement, pas de code : le chantier #110 ne modifie rien dans le périmètre de EA-13/14/19, mais il conditionne le moment où ce périmètre devient traitable. Le jalon précis est la fin de R.4 — la bascule effective de `MAIL_PROVIDER`. À partir de ce moment, la couche mail tourne sur Resend, et l'étape 8 du chantier-cadre peut reprendre sans risquer d'investir du travail sur une couche Brevo vouée au remplacement.

Il n'est pas nécessaire d'attendre R.6 (suppression de Brevo) ni R.7 (alignement architectural) pour débloquer l'étape 8 : dès R.4, la couche est fonctionnellement sur Resend. R.5 (surveillance) peut se dérouler en parallèle du début de l'étape 8 Biblioteca. La seule réserve : si l'étape 8 conduit à retoucher le rendu de `register` ou certains transports, mieux vaut coordonner ce travail avec R.7 (cf. §5.8) plutôt que de le mener deux fois.

---

## §8 — Critères de succès

Cette section consolide les critères de succès du chantier à plusieurs horizons temporels. Le §6.7 liste les critères techniques cumulés à clôture de R.6. La présente §8 étend cette lecture en distinguant les critères immédiats (vérifiables dans la journée de R.4), à court terme (période R.5), à moyen terme (6 mois post-R.6), et politiques (vérifiables sur la durée du projet). Chaque critère est formulé pour être vérifiable : il existe une procédure ou une observation permettant de dire « atteint » ou « non atteint » sans ambiguïté.

### 8.1 Critères immédiats — vérifiables en R.4

Ces critères doivent être atteints dans les 2 à 3 heures suivant la bascule (R.4.2). S'ils ne le sont pas, la procédure de rollback (annexe A4) est déclenchée sans hésitation.

| # | Critère | Procédure de vérification | Statut attendu |
|---|---|---|---|
| 8.1.1 | Le signup test envoie un mail de bienvenue via Resend | Signup en navigation privée avec compte de test ; vérifier réception ; vérifier dans dashboard Resend que le mail apparaît avec status `delivered` | Atteint |
| 8.1.2 | Le mail de bienvenue est rendu à l'identique de l'avant-bascule | Comparer le rendu reçu avec la capture de référence prise avant R.3 (cf. §6.2) ; tester sur Thunderbird et Gmail | Atteint |
| 8.1.3 | Une notification de réservation est envoyée via Resend | Créer une réservation test sur staging ou prod ; vérifier réception lecteur+admin ; vérifier dashboard Resend | Atteint |
| 8.1.4 | Une notification weekly est envoyée via Resend | Déclencher manuellement le cron weekly-report ; vérifier réception ; vérifier dashboard Resend | Atteint |
| 8.1.5 | Aucun mail ne part par erreur via Brevo | Consulter dashboard Brevo dans les 2h post-R.4 : il doit montrer 0 envoi sur cette période | Atteint |
| 8.1.6 | Les en-têtes SPF, DKIM, DMARC du mail reçu sont valides | Sur un mail reçu, ouvrir "show original" / "voir l'original" ; vérifier que les trois en-têtes passent (status `pass`) | Atteint |
| 8.1.7 | Le sender visible est bien `no-reply@notifications.anarbib.org` | Lecture du champ `From:` d'un mail reçu | Atteint |
| 8.1.8 | Le reply-to est correctement configuré selon la bibliothèque source | Sur un mail venant d'une biblio ayant `delivery_mode='platform_shared_local_reply'`, vérifier que le `Reply-To:` pointe vers l'email local | Atteint |
| 8.1.9 | Aucune erreur dans les logs Edge Function dans les 2h post-bascule | Consultation des logs Supabase pour les 8 EF mail | Atteint |

**Décision si un critère immédiat n'est pas atteint.** Si l'un quelconque des critères 8.1.1 à 8.1.9 échoue, la procédure de rollback (annexe A4) est exécutée immédiatement. Le diagnostic se fait ensuite à froid. Aucune tolérance sur cette liste : la fenêtre de R.4 est conçue précisément pour permettre ce rollback rapide.

### 8.2 Critères à court terme — vérifiables pendant R.5

Ces critères sont observés pendant les 2 semaines de surveillance post-bascule. Ils peuvent tolérer des incidents isolés tant que la tendance générale est conforme.

| # | Critère | Procédure de vérification | Tolérance |
|---|---|---|---|
| 8.2.1 | Aucune régression sur la délivrabilité | Comparer le taux de bounces sous Resend (visible dashboard Resend) avec le taux observé sous Brevo dans les 2 semaines précédentes | Évaluation qualitative — pas de baseline chiffrée |
| 8.2.2 | Aucune plainte de spam-marking | Écoute passive des retours coordinations locales ; consultation des éventuels rapports de complaints côté Resend | 0 plainte acceptable, 1-2 plaintes à investiguer mais pas bloquantes |
| 8.2.3 | Tous les types de mails sont envoyés au moins une fois sur la période | Audit du dashboard Resend à J+7 puis J+14 ; vérification de la présence d'au moins un mail pour chaque type (welcome, réservation, emprunt, weekly, library-request) | Couverture complète attendue à J+14 |
| 8.2.4 | Le compte Brevo reste à 0 envoi | Consultation dashboard Brevo à J+7 et J+14 | 0 envoi attendu (sauf erreur de configuration à corriger immédiatement) |
| 8.2.5 | Aucune validation accidentelle de la page tracking Resend | Vérification visuelle de la page `/domains/<id>/tracking` à J+7 et J+14 | État "non configuré" maintenu |
| 8.2.6 | Aucun incident de cold start | Consultation des logs Edge Function : pas d'erreurs `RESEND_API_KEY missing` ou équivalent au cold start | Atteint |

**Bilan à J+14 (sous-paquet R.5.4).** Si tous les critères sont atteints, la transition vers R.6 est ouverte (après le délai de coexistence stable prévu en §5.7). Si un critère n'est pas atteint, le bilan documente le problème et propose soit un correctif, soit un report de R.6.

### 8.3 Critères à moyen terme — vérifiables à 6 mois post-R.6

Ces critères s'évaluent à long terme et déclenchent un post-mortem partiel si non atteints.

| # | Critère | Procédure de vérification | Conséquence si non atteint |
|---|---|---|---|
| 8.3.1 | Aucune référence à Brevo dans le code de production | `grep -r -i "brevo" supabase/functions/` ne retourne que des commentaires historiques de date >= R.6 | Sous-paquet de nettoyage |
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

**Critère 8.4.5 — réflexion ouverte.** Ce critère vise la cohérence visuelle à long terme. Au moment de la clôture de #110, cette cohérence n'est pas encore complète : `register` conserve son rendu HTML propre (cf. §4.6, refonte hors périmètre). Le critère 8.4.5 s'entend donc comme une orientation : à mesure que les chantiers ultérieurs (R.7, ou le chantier-cadre Biblioteca) touchent aux mails, ils font converger les rendus vers `_shared/mail/layout.ts`, et tout nouveau template introduit passe par ce module plutôt que par un système de rendu parallèle. La cohérence visuelle complète est un objectif de fin de R.7, pas un critère de succès de la migration #110 elle-même.

### 8.5 Indicateurs de surveillance continue

Au-delà des critères ponctuels, trois indicateurs sont à suivre en continu après R.6 pour détecter toute dérive.

**Indicateur 8.5.1 — volume mensuel d'envois.** À consulter dans le dashboard Resend chaque début de mois. Sert à vérifier que le projet reste sous la limite du plan gratuit Resend (3 000 mails/mois) ou, le cas échéant, justifie un upgrade. Volume actuel projeté : ~200-500 mails/mois selon le rythme d'activité de la BLMF et de la BTL, large marge.

**Indicateur 8.5.2 — taux de bounces par mois.** À consulter dans le dashboard Resend. Un taux supérieur à 5% sur un mois donné mérite investigation : nettoyage de la base de données pour les adresses obsolètes, vérification SPF/DKIM/DMARC, ou contact direct avec Resend.

**Indicateur 8.5.3 — taux de plaintes spam par mois.** À consulter dans le dashboard Resend. Un taux supérieur à 0,1% (1 plainte pour 1000 envois) signale un problème de réputation à diagnostiquer. Vérifier que les destinataires n'ont pas révoqué leur consentement, que le contenu ne déclenche pas les filtres antispam, etc.

Ces trois indicateurs ne constituent pas des critères de succès au sens strict (ils ne sont pas datés et n'ont pas de seuil bloquant pour la clôture du chantier), mais ils sont à surveiller comme indicateurs de santé du dispositif sur la durée.

### 8.6 Synthèse hiérarchisée

Pour faciliter la relecture, voici une hiérarchisation des critères par impact :

**Bloquants pour la clôture de R.4 :** 8.1.1 à 8.1.9 (9 critères immédiats).
**Bloquants pour la clôture de R.5 :** 8.2.1, 8.2.3, 8.2.4, 8.2.5 (4 critères court terme).
**Bloquants pour la clôture de R.6 :** 8.3.1, 8.3.2, 8.3.3, 8.3.5, 8.3.6 (5 critères moyen terme).
**Non bloquants mais à suivre :** 8.2.2, 8.2.6, 8.3.4, et indicateurs 8.5.1 à 8.5.3.
**Politiques (durée projet) :** 8.4.1 à 8.4.5.

Si tous les critères bloquants sont atteints en temps et en heure, le chantier est considéré comme réussi. Si l'un des critères non bloquants n'est pas atteint, il est noté en bilan de session mais ne remet pas en cause la clôture du chantier.

---

## §9 — Risques

Cette section recense les risques identifiés pour le chantier, par catégorie (technique, opérationnel, politique, externe), avec une évaluation qualitative de probabilité et d'impact, et la mitigation prévue.

Les risques sont numérotés **RQ-1 à RQ-15** — préfixe `RQ` pour « risque », distinct du préfixe `R` des sous-paquets de la séquence (§5), afin d'éviter toute confusion de lecture.

L'évaluation utilise une échelle à trois niveaux (faible, moyen, élevé) pour la probabilité et l'impact. Aucun chiffrage statistique n'est tenté : ces évaluations sont indicatives et orientées vers la prise de décision.

### 9.1 Risques techniques

**RQ-1 — Régression de rendu lors de l'adoption du wrapper.**
Probabilité : moyenne. Impact : moyen.
L'adoption du wrapper `sendEmail` dans un transport (R.2, R.3) déplace ou réorganise du code d'envoi. Le risque est qu'un transport, après adoption, n'envoie plus exactement comme avant — différence de rendu HTML, en-tête manquant, perte du `reply_to`. Le risque est plus élevé pour les cinq transports anciennement inlinés, dont le code d'envoi n'avait jamais été isolé.
**Mitigation.** Comparaison avant/après systématique (procédure §6.2) : capture du rendu de référence dans deux clients mail avant de toucher un transport, et rejeu du même test après adoption du wrapper, `MAIL_PROVIDER` restant à `brevo`. Toute différence est traitée comme une régression bloquante avant de continuer. Discipline « un fix à la fois » (§6.6) pour isoler la cause.

**RQ-2 — Incompatibilité d'un en-tête entre Brevo et Resend non détectée en test.**
Probabilité : faible. Impact : élevé.
Brevo et Resend acceptent des formats différents pour `from`, `to`, `reply_to` (cf. §4.4). Si un cas limite n'est pas couvert par `sendViaResend` — un destinataire avec un caractère spécial dans le nom, un `reply_to` de forme inhabituelle — des mails peuvent être rejetés silencieusement par Resend après R.4.
**Mitigation.** Tests runtime exhaustifs en R.2, R.3 et R.4, incluant des destinataires avec accents, ponctuation et noms composés. Surveillance du dashboard Resend pendant R.5 : un mail rejeté y apparaît avec statut `failed` et un message d'erreur précis. Rollback rapide possible si un motif de rejet est détecté.

**RQ-3 — Régression introduite par l'extraction d'un transport inliné.**
Probabilité : moyenne. Impact : moyen.
En R.3, les cinq transports inlinés sont, par défaut, extraits dans une fonction propre (cf. §4.3). L'extraction manipule du code entrelacé avec la logique de l'EF : une variable locale oubliée, un fragment de construction du corps de mail laissé en place, et le mail part incomplet ou mal formé.
**Mitigation.** Règle de décision de §4.3 : extraction propre par défaut, bloc conditionnel sur place si l'extraction est disproportionnée — ce qui limite le risque aux cas réellement extractibles proprement. Un commit et un test runtime par EF (§6.1, R.3.4). Comparaison avant/après (§6.2). Hardening H.1 (logging du provider) pour le diagnostic.

**RQ-4 — Échec silencieux de l'inlining base64 des logos.**
Probabilité : faible. Impact : faible.
Le module `inline-images.ts` est conservé sous Resend (§4.5). Si l'inlining échoue — Supabase Storage momentanément indisponible — le code est défensif : il renvoie l'URL d'origine et le mail part quand même. Les logos restent visibles, mais sans la protection d'archivage long terme.
**Mitigation.** Comportement défensif déjà en place dans `inline-images.ts`. Surveillance des logs Edge Function pour les avertissements d'échec d'inlining. C'est une dégradation gracieuse acceptable, sans action corrective immédiate requise.

**RQ-5 — Variable `MAIL_PROVIDER` mal positionnée.**
Probabilité : faible. Impact : élevé.
Une typo dans le dashboard Supabase (`Resend` avec majuscule, `resnd`) ferait que le wrapper applique son repli. Tant que Brevo existe, le repli est Brevo — sans gravité. Après R.6, Brevo supprimé, un repli sur une branche `brevo` inexistante ferait échouer tous les mails.
**Mitigation.** Hardening H.2 (validation défensive de `MAIL_PROVIDER`, avertissement loggé sur valeur inconnue). Hardening H.3 (test de fumée au démarrage, détection de l'absence du secret du provider courant). Test runtime post-R.6 (§6.1) pour valider le fonctionnement après suppression de Brevo.

### 9.2 Risques opérationnels

**RQ-6 — Bascule R.4 conduite dans une fenêtre temporelle inadéquate.**
Probabilité : faible. Impact : moyen.
Si R.4 est exécutée en période de forte activité, un incident de bascule toucherait plus de monde. Conduite hors présence, un incident détecté tard fragiliserait la confiance.
**Mitigation.** §5.5 inscrit la conduite de R.4 en fenêtre calme avec présence en ligne deux heures après la bascule. R.4.1 inclut une vérification préalable de l'absence d'activité en cours.

**RQ-7 — Rollback R.4 non exécuté à temps.**
Probabilité : faible. Impact : élevé.
La procédure de rollback (annexe A4) est simple, mais suppose une présence réactive. Un incident détecté six heures après la bascule retarde d'autant le rollback.
**Mitigation.** Présence en ligne deux heures post-bascule (§5.5). Tests immédiats 8.1.1 à 8.1.9 couvrant les principaux types de mails dans l'heure suivant la bascule. Rollback effectif en moins d'une minute une fois décidé. Conservation de Brevo en repli (H.5) qui rend le rollback réversible jusqu'à R.6.

**RQ-8 — Confusion sur les variantes historiques de variables d'environnement.**
Probabilité : moyenne. Impact : faible.
Les variantes `ANARBIB_SENDER_EMAIL`, `NETWORK_SENDER_EMAIL`, `BREVO_SENDER_MAIL`, etc., sont conservées en fallback pendant la migration (§4.7). Une modification opportuniste de l'une d'elles peut passer inaperçue, la cascade de fallback n'étant pas intuitive.
**Mitigation.** Nettoyage de ces variantes inscrit en R.6.3. Pendant la migration, toute modification d'une variable sender se fait sur la variable principale (`SENDER_EMAIL`), pas sur une variante. Discipline documentée en annexe A2.

**RQ-9 — Pipeline Woodpecker indisponible pendant le chantier.**
Probabilité : faible. Impact : moyen.
Le déploiement des Edge Functions passe par la CLI `supabase functions deploy`. Une indisponibilité de Codeberg ou Woodpecker n'empêche pas ce déploiement, mais bloque l'application d'éventuelles migrations.
**Mitigation.** Le chantier #110 ne comporte pas de migration DB ; le déploiement des EF par CLL est autonome vis-à-vis de Woodpecker. Si Woodpecker est indisponible, le chantier peut continuer sur sa partie Edge Functions et attendre le rétablissement pour tout ce qui passerait par le pipeline.

### 9.3 Risques politiques

**RQ-10 — Validation accidentelle de la page tracking Resend.**
Probabilité : faible mais non nulle. Impact : élevé politiquement.
Le garde-fou doctrinal (§3.2, §6.4) repose sur la discipline humaine : ne jamais valider la page `/domains/<id>/tracking`. Le risque est qu'un·e admin réseau futur·e la valide par curiosité ou méconnaissance.
**Mitigation.** Garde-fou inscrit à quatre niveaux : spec, manuel admin réseau (chantier ultérieur), annexe A6 (capture annotée), registre RGPD. Option de vérification programmatique inscrite au backlog, activable en cas d'incident. La validation, si elle survenait, serait techniquement réversible (suppression du tracking subdomain) ; le risque réel tient à la fenêtre pendant laquelle le tracking aurait été actif.

**RQ-11 — Perception négative de la migration par les destinataires.**
Probabilité : faible. Impact : faible.
Le changement de sender (`no-reply@notifications.anarbib.org` au lieu de `anarbib@anarbib.org`) peut être perçu comme une dépersonnalisation ou un signe d'instabilité.
**Mitigation.** Note de migration claire aux coordinations locales en R.5 (§7.3, annexe A5), en pt-BR et traductions, explicitant le motif politique et valorisant la cohérence éthique du choix Resend comme signe de sérieux, pas d'instabilité.

**RQ-12 — Pression future pour réactiver le tracking au nom de l'efficacité.**
Probabilité : faible. Impact : élevé politiquement.
Une demande peut émerger à terme pour mesurer le taux d'ouverture des mails, sous une apparence pragmatique et bienveillante, en contradiction avec la doctrine.
**Mitigation.** Doctrine inscrite dans le registre RGPD comme engagement de minimisation des données, ce qui lui donne une valeur opposable. Garde-fou doublé : principe (§6.4) et dispositif technique (configuration Resend non validée). Toute modification doit faire l'objet d'une décision politique tracée (critère 8.4.4). La présente spec est un document de référence à mobiliser dans cette discussion.

### 9.4 Risques externes

**RQ-13 — Resend modifie unilatéralement son comportement de tracking.**
Probabilité : faible. Impact : élevé.
Resend pourrait à terme imposer une forme de tracking par défaut, ou réécrire les URLs sans option de désactivation.
**Mitigation.** Surveillance des annonces Resend en routine légère post-R.6. Le wrapper `sendEmail` permet, le cas échéant, de basculer vers un troisième provider en quelques jours, par la même mécanique que la présente migration. Le compte Brevo peut être réactivé s'il est encore en standby.

**RQ-14 — Resend introduit des frais ou réduit le plan gratuit.**
Probabilité : moyenne sur le moyen terme. Impact : moyen.
Le plan gratuit Resend couvre largement le volume actuel, mais l'éditeur peut réduire ce volume ou imposer des frais. Le projet n'a pas de revenus pour absorber un coût récurrent significatif.
**Mitigation.** Surveillance mensuelle via l'indicateur 8.5.1. Si une évolution tarifaire intervient : soit accepter un coût modeste sur décision de coordination réseau, soit migrer vers une alternative (Postmark, Mailgun, ou auto-hébergement Postfix sur le serveur OVH du CCLA), inscrite en backlog à activer en cas de nécessité.

**RQ-15 — Indisponibilité prolongée de Resend.**
Probabilité : faible. Impact : moyen à élevé selon la durée.
Une panne majeure de Resend empêcherait tout envoi. Les EF retourneraient des résultats d'échec sans planter — le code est défensif.
**Mitigation.** Conservation de Brevo en repli pendant R.4 à R.6, qui permet un rollback rapide via `MAIL_PROVIDER=brevo`. Surveillance des incidents via `status.resend.com`. Communication d'urgence aux coordinations si une panne dépasse deux heures sur des notifications critiques.

### 9.5 Synthèse des risques

| # | Risque | Probabilité | Impact | Résiduel | Mitigation principale |
|---|---|---|---|---|---|
| RQ-1 | Régression de rendu à l'adoption du wrapper | Moyenne | Moyen | Modéré | Comparaison avant/après §6.2 |
| RQ-2 | Incompatibilité en-tête Brevo/Resend non testée | Faible | Élevé | Modéré | Tests exhaustifs + surveillance dashboard R.5 |
| RQ-3 | Régression à l'extraction d'un transport inliné | Moyenne | Moyen | Modéré | Règle §4.3 + un commit/test par EF |
| RQ-4 | Échec inlining base64 logos | Faible | Faible | Faible | Comportement défensif déjà en place |
| RQ-5 | `MAIL_PROVIDER` mal positionnée | Faible | Élevé | Modéré | H.2 + H.3 + test post-R.6 |
| RQ-6 | Fenêtre temporelle inadéquate pour R.4 | Faible | Moyen | Faible | Fenêtre calme validée en R.4.1 |
| RQ-7 | Rollback non exécuté à temps | Faible | Élevé | Modéré | Présence 2h post-bascule + tests immédiats |
| RQ-8 | Confusion variantes historiques de variables | Moyenne | Faible | Faible | Discipline + nettoyage R.6.3 |
| RQ-9 | Pipeline Woodpecker indisponible | Faible | Moyen | Faible | Déploiement EF par CLI, autonome |
| RQ-10 | Validation accidentelle page tracking | Faible | Élevé politiquement | Modéré | Garde-fou inscrit à 4 niveaux |
| RQ-11 | Perception négative de la migration | Faible | Faible | Faible | Note de migration en R.5 |
| RQ-12 | Pression future pour réactiver tracking | Faible | Élevé politiquement | Modéré | Inscription registre RGPD + critère 8.4.4 |
| RQ-13 | Resend modifie son comportement tracking | Faible | Élevé | Modéré | Surveillance annonces + wrapper extensible |
| RQ-14 | Resend introduit frais / réduit plan gratuit | Moyenne (moyen terme) | Moyen | Modéré | Surveillance 8.5.1 + alternatives en backlog |
| RQ-15 | Indisponibilité prolongée de Resend | Faible | Moyen-élevé selon durée | Modéré | Repli Brevo + surveillance status.resend.com |

**Analyse synthétique.** Aucun risque n'a une probabilité élevée. Les risques à impact élevé (RQ-2, RQ-5, RQ-7, RQ-10, RQ-12, RQ-13) ont tous une probabilité faible et des mitigations en place. Les risques à probabilité moyenne (RQ-1, RQ-3, RQ-8, RQ-14) ont un impact contenu. Le profil de risque général du chantier est **modéré**.

Trois risques méritent une vigilance au-delà du chantier : RQ-10 (validation accidentelle du tracking, vigilance permanente), RQ-12 (pression doctrinale future, vigilance politique sur la durée), RQ-14 (modèle économique Resend, vigilance à moyen terme). Ces trois-là justifient les indicateurs de surveillance continue (§8.5) et la conservation de cette spec comme référence active après clôture.

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

**État avant chantier (pré-R.1) :**

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

**État après R.1 (préalables Resend) :**

| Variable | Valeur | Statut |
|---|---|---|
| `RESEND_API_KEY` | `re_<token>` | **Nouveau** |
| `SENDER_EMAIL` | `no-reply@notifications.anarbib.org` | **Modifié** |
| `BREVO_API_KEY_NOTIFICATIONS` | inchangé | Actif (encore utilisé) |
| `BREVO_API_KEY` | inchangé | Actif (encore utilisé par `register`) |
| Autres variables | inchangées | — |

> **Note v0.3 — dépendance DNS de `SENDER_EMAIL`.** La bascule de `SENDER_EMAIL` vers `no-reply@notifications.anarbib.org` n'est pas qu'un changement de variable : `notifications.anarbib.org` est un sous-domaine, qui doit être authentifié séparément chez chaque provider (la vérification du domaine parent `anarbib.org` ne descend pas aux sous-domaines). Tant que Brevo reste actif (R.2, R.3, jusqu'à R.4), le sous-domaine doit être authentifié côté Brevo — voir l'étape R.1.6. Authentification posée le 21/05 (4 enregistrements DNS dans la zone OVH : TXT de code Brevo, 2 CNAME DKIM, TXT DMARC). Côté Resend, le sous-domaine est configuré depuis le 07/05.

> **Note v0.3 — rotation de `WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK`.** Pendant l'exécution de R.3 le 21/05, ce secret a été rotaté : l'ancienne valeur était introuvable (écart constaté par comparaison de digest SHA-256 lors du test runtime de `notify-internal-task`), une nouvelle valeur de 32 octets en base64 a été générée et posée via `supabase secrets set`. Conséquence à traiter hors de ce chantier : le webhook Postgres qui déclenche `notify-internal-task` envoie encore l'ancienne valeur ; il devra être mis en cohérence avec la nouvelle avant toute mise en service réelle des notifications de tâches internes. Suivi au backlog, item #119 (audit des secrets).

**État après R.2 et R.3 (wrapper adopté dans tous les transports) :**

| Variable | Valeur | Statut |
|---|---|---|
| `MAIL_PROVIDER` | non défini (= défaut `brevo`) | Pas encore positionné |
| `RESEND_API_KEY` | `re_<token>` | Actif (mais non utilisé tant que `MAIL_PROVIDER=brevo`) |
| Autres variables | inchangées | — |

**État au moment de R.4 (bascule) :**

| Variable | Valeur | Statut |
|---|---|---|
| `MAIL_PROVIDER` | `brevo` (ou non défini) | Globale, défaut Brevo |
| `MAIL_PROVIDER_NOTIFY_INTERNAL_TASK` | `resend` | **Override temporaire** |
| Autres variables | inchangées | — |

**État après R.4 (Resend actif, Brevo en repli) :**

| Variable | Valeur | Statut |
|---|---|---|
| `MAIL_PROVIDER` | `resend` | **Modifié** |
| `MAIL_PROVIDER_NOTIFY_INTERNAL_TASK` | non défini | **Supprimé** (couvert par la globale) |
| `BREVO_API_KEY_NOTIFICATIONS` | inchangé | Standby (code existe, non appelé) |
| `BREVO_API_KEY` | inchangé | Standby (code existe, non appelé) |
| Autres variables | inchangées | — |

**État final après R.6 (suppression Brevo) :**

| Variable | Valeur | Statut |
|---|---|---|
| `MAIL_PROVIDER` | `resend` (ou supprimée si simplification) | Final |
| `RESEND_API_KEY` | `re_<token>` | Actif |
| `BREVO_API_KEY_NOTIFICATIONS`, `BREVO_API_KEY`, `BREVO_API_KEY_STAGING` | — | **Supprimés** |
| Variantes historiques (`ANARBIB_SENDER_EMAIL`, etc.) | — | **Supprimées** |
| `SENDER_EMAIL` | `no-reply@notifications.anarbib.org` | Final |
| `SENDER_NAME`, `ADMIN_EMAIL`, `ADMIN_NAME`, et habillage | inchangés | Final |
| `WEBHOOK_SECRET_*` | inchangés | Inchangés |

**Compte rendu de l'audit Brevo (sous-paquet R.1.1).**
À remplir au moment de l'exécution de R.1.1 :

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

Procédure de test manuel pour chaque EF mail, à exécuter lors des sous-paquets R.3 (test de chaque transport, `MAIL_PROVIDER=brevo`) et R.4 (test post-bascule, `MAIL_PROVIDER=resend`). L'objectif est de couvrir les huit EF mail avec le minimum de tests pertinents.

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
Conditions : EF actuellement dormante. Test à conduire uniquement si le contexte le permet ; sinon, simple inspection du transport basculé, sans test runtime.

**T.9 — `notify-mid-loan-reading` (déclenchement manuel).**
Conditions : emprunt actif à mi-vie.
Procédure : déclencher manuellement l'EF via `supabase functions invoke notify-mid-loan-reading --data '{"loan_id": "<uuid>"}'`. Vérifier réception du mail.

**T.10 — `notify-document-permission-request`.**
Conditions : ressource numérique à accès restreint, demande de permission soumise.
Procédure : soumettre une demande de permission depuis le frontend. Vérifier réception du mail côté admin/coord.

**Critère de validation global.** Les dix tests T.1 à T.10 (ou ceux qui sont conduibles selon le contexte) doivent retourner :
- Réception du mail dans la boîte de test, sender = `no-reply@notifications.anarbib.org`.
- Rendu visuel identique à la capture de référence prise avant bascule (cf. §6.2), pour toutes les EF y compris `register` dont le rendu propre est conservé.
- Apparition dans le dashboard du provider courant (Brevo en R.3, Resend en R.4) avec statut `delivered`.
- Pas d'erreurs dans les logs Edge Function correspondants.

### A4 — Procédure de rollback express

Cette procédure est conçue pour être exécutée en moins d'une minute, sans accès au code source. Elle permet de revenir intégralement à l'état pré-R.4 (Brevo actif) si un incident critique est détecté dans la période R.4–R.5.

**Préconditions du rollback :**

- Au moins un critère immédiat (8.1.1 à 8.1.9) n'est pas atteint, ou un incident manifeste est observé dans l'heure post-R.4.
- Le compte Brevo est toujours actif (acquis tant que R.6 n'a pas eu lieu).
- Le secret `BREVO_API_KEY_NOTIFICATIONS` est toujours présent dans le dashboard Supabase.

**Étape 1 — Décision de rollback.**
La décision se prend sans hésitation dès qu'un critère immédiat échoue. Pas de tentative de diagnostic en urgence : le diagnostic se fera à froid après rollback. Le rollback est l'option par défaut en cas de doute, pas l'exception.

**Étape 2 — Modification de la variable `MAIL_PROVIDER`.**
Connexion au dashboard Supabase : `https://supabase.com/dashboard/project/uflwmikiyjfnikiphtcp/settings/functions`. Section Edge Function Secrets. Modifier la valeur de `MAIL_PROVIDER` de `resend` à `brevo`. Sauvegarder. La modification est propagée immédiatement aux EF (pas de redémarrage nécessaire, lecture au prochain invoke).

**Étape 3 — Vérification immédiate.**
Déclencher un mail de test depuis n'importe quelle EF (le plus simple : signup test ou notification de réservation). Vérifier que le mail arrive depuis Brevo (apparition dans le dashboard Brevo). Vérifier que le sender visible est cohérent avec la configuration Brevo en cours (probablement `no-reply@notifications.anarbib.org` si la variable `SENDER_EMAIL` a été modifiée en R.1, ou `anarbib@anarbib.org` si pas encore modifiée).

**Étape 4 — Communication.**
Si la coordination locale (BLMF, BTL) avait été notifiée du changement de sender en R.5, envoyer une note rapide expliquant le rollback temporaire et la prochaine fenêtre de re-bascule envisagée.

**Étape 5 — Diagnostic à froid.**
Une fois le rollback effectif, conduire le diagnostic à tête reposée. Consulter les logs Edge Function Supabase pour identifier l'incident. Consulter le dashboard Resend pour les éventuels mails en échec côté provider. Documenter le diagnostic dans un commentaire sur le commit de R.4 ou dans une note de session.

**Étape 6 — Préparer la re-bascule.**
Une fois le diagnostic posé, préparer une nouvelle tentative de R.4 corrigée. La fenêtre temporelle suivante peut être planifiée 24 à 48 heures après le rollback, le temps de valider les correctifs en local.

**Durée totale du rollback : moins d'une minute pour l'étape 2, environ 5 minutes pour l'étape 3.**

**Annulation du rollback (re-bascule vers Resend) :**
La même procédure inverse — passer `MAIL_PROVIDER` de `brevo` à `resend` — permet de re-basculer sans difficulté une fois les correctifs en place.

### A5 — Note de migration aux coordinations locales

Texte indicatif de la note à envoyer aux coordinations actives (BLMF, BTL) en R.5, peu après la bascule effective de R.4. Le mail est envoyé depuis le nouveau sender comme premier test grandeur nature.

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

**Versions es, en, it, de :** structurellement identiques, à traduire en s'inspirant des conventions militantes définies dans `_shared/i18n/mail-strings.ts` (es neutre argentin avec « -e », en épicène, it /a/e, de Genderstern). Le texte traduit est archivé dans `docs/specs/notes-migration/resend-bascule/` au moment de R.5 pour permettre une diffusion ciblée en cas d'élargissement futur du réseau à d'autres coordinations.

### A6 — Capture annotée de la page tracking Resend

Cette annexe documente visuellement la page `https://resend.com/domains/<id>/tracking` qui est l'objet du garde-fou doctrinal (§6.4). La capture sert de référence pédagogique pour tout·e admin·istratrice réseau, présent·e ou future·e, qui aurait l'occasion d'accéder au dashboard Resend du CCLA.

**Capture de référence à archiver dans `docs/specs/captures/resend-tracking-page/` :**

La capture doit être prise en R.1.5, avec annotations textuelles ajoutées par-dessus. Elle représente la page de configuration "New tracking subdomain" du dashboard Resend telle qu'elle apparaît par défaut à un·e utilisateur·rice qui n'a pas encore validé de tracking subdomain.

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

Cette annexe est un cadre pour le bilan de session à rédiger en clôture de R.5 puis en clôture de R.6. Elle reprend la structure des bilans de session AnarBib existants (cf. `AnarBib_Bilan_session_2026-05-12.docx`).

**Cadre indicatif pour le bilan R.5 (à J+14 post-bascule) :**

```
AnarBib — Bilan de migration mail Brevo → Resend
Phase : R.5 close, ouverture R.6 conditionnelle

1. Synthèse exécutive
   - Date de R.4 : ___
   - Bilan de la période R.5 : ___
   - Incidents notables : [liste ou "aucun"]
   - Décision sur R.6 : [ouverture immédiate / report / autre]

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

**Cadre indicatif pour le bilan R.6 (clôture finale) :**

```
AnarBib — Bilan de clôture migration Brevo → Resend
Phase : R.6 close, chantier complet

1. Synthèse exécutive
   - Date d'ouverture du chantier : ___
   - Date de clôture (R.6) : ___
   - Durée totale : ___
   - Bilan général : ___

2. Critères de succès cumulés (§8.6)
   - Bloquants R.4 : [tous atteints / liste écarts]
   - Bloquants R.5 : [tous atteints / liste écarts]
   - Bloquants R.6 : [tous atteints / liste écarts]
   - Politiques (durée projet) : [état au moment du bilan]

3. Récapitulatif des paquets livrés
   - R.1 à R.7 : [chacun avec durée réelle, écart vs estimation, incidents]

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

Cette spec v0.2 cadre la migration du provider mail Brevo vers Resend en intégrant trois dimensions : technique (wrapper de transport neutre, dispatch par variable d'environnement, tests de non-régression), politique (doctrine no-tracking, garde-fou doctrinal, cohérence libertaire), et procédurale (séquence R.1 à R.7, validation runtime, rollback préparé, règles de déploiement non négociables).

Elle est conçue comme un document **opposable et reproductible** : opposable en ce qu'elle sert de référence en cas de discussion future sur la doctrine tracking ou sur la conduite du chantier ; reproductible en ce qu'elle peut être transmise à d'autres collectifs libertaires conduisant une migration similaire.

Le changement central de la v0.2 par rapport à la v0.1 est l'inversion de séquence : la bascule fonctionnelle (R.1 à R.4) précède l'alignement architectural (R.7), au lieu de le suivre. Ce choix répond à une contrainte concrète — débloquer l'étape 8 du chantier-cadre Biblioteca (écarts EA-13, EA-14, EA-19) — et à une doctrine — celle du GLB v15, qui demande de fermer les chantiers sans les mélanger. La migration #110 est fonctionnellement terminée à la fin de R.6 ; R.7 est un raffinement d'hygiène ultérieur.

La séquence R.1 à R.7 est explicite et peut être suspendue proprement entre sous-paquets (§5.9). Le jalon qui débloque le chantier-cadre Biblioteca est la fin de R.4.

La présente spec est versionnée v0.2. Elle passe en v1.0 à l'ouverture effective de R.1, sous réserve de validation par la coordination réseau du CCLA. Toute évolution ultérieure fera l'objet de versions intermédiaires avec changelog en tête de document, selon la convention déjà appliquée pour le passage v0.1 → v0.2.

---

**Fin de la spec v0.2.**
