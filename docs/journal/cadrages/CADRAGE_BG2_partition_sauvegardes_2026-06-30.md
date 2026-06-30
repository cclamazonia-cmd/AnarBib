---
Genre : trace
Statut : 🔵 historique
Décisions : incarne BG2-1..BG2-14 (versées au REGISTRE §BG2) ; cite l'engagement §8.1 de `spec-historico-retencao-lectrice`, USER-EMAIL-1 (`profiles.email` miroir de `auth.users.email`)
Supersédé par : REGISTRE §BG2 (doctrine) ; l'inventaire de partition §3–§5 reste annexe d'implémentation jusqu'à une `spec-sauvegarde`
---

> ⚠️ **Document de travail — historique.** La doctrine (BG2-1..BG2-14) a gradué au **REGISTRE §BG2** : pour les décisions, c'est le registre qui fait foi. L'**inventaire de partition** (§3–§5) reste ici comme annexe d'implémentation de référence jusqu'à une éventuelle `spec-sauvegarde`.

# CADRAGE #BG2 — Partition des données pour la sauvegarde hors-fournisseur

- **Date** : 30 juin 2026
- **Objet** : doctrine de rétention et inventaire de partition pour la stratégie de sauvegarde militante (#BG2), sur la base de l'espace SFTP obtenu chez Herbes Folles (Lille).
- **Méthode** : inventaire réel du schéma de production (`uflwmikiyjfnikiphtcp`) par inspection lecture seule, le 30/06/2026.

---

## 1. Contexte & cadre

#BG2 sort les données du seul périmètre Supabase/AWS (CLOUD Act) vers une copie chiffrée hors-site. La **stratégie retenue est le découplage par sensibilité** (« solution 2 ») : deux flux de sauvegarde aux politiques de rétention distinctes, plutôt qu'un backup monolithique.

Le verrou doctrinal vient de `spec-historico-retencao-lectrice` §8.1 : la CCLA s'engage à **ne pas conserver de backup applicatif au-delà de la rétention Supabase standard**. Or une rétention longue (grand-père/père/fils, 6 mois) sur *toutes* les données contredirait cet engagement pour les données personnelles.

**Fait de calibrage** (vérifié 30/06/2026) : le projet tourne sur **plan Pro, sans add-on PITR** (PITR `DISABLED` sur la page Add-ons). La rétention Supabase standard est donc de **7 jours** de backups quotidiens — et non « ~30 jours » comme l'écrivait la « conséquence honnête » du §8.1, qui visait la fourchette haute. **Le §8.1 est à corriger** : « ~30 jours » → « 7 jours (rétention Pro) ».

Rappel structurant issu de l'inspection : **le Storage Supabase n'est couvert par aucun backup natif** (l'encadré du dashboard le confirme : « Storage objects are not included »). Le flux Storage de #BG2 n'est donc pas un confort mais la **seule** sauvegarde existante pour cette moitié des données (et le plus gros volume, ~430 Mo).

---

## 2. Doctrine de partition (décisions à verser au registre, §BG2)

**BG2-1 — Deux flux, pas un.** La sauvegarde est scindée en un *flux court* et un *flux long*, aux rétentions distinctes, plutôt qu'une copie unique.

**BG2-2 — Borne du flux court = 7 jours.** Le flux court s'aligne sur la rétention Supabase standard (Pro, 7 j) : `restic forget --keep-daily 7`, rien au-delà. L'engagement §8.1 est ainsi tenu *à la lettre*, sans réécriture de la promesse faite à la lectrice. Corollaire : corriger « ~30 jours » → « 7 jours » dans `spec-historico-retencao-lectrice` §8.1.

**BG2-3 — Le critère de partition n'est pas « lectrice vs staff », c'est « donnée personnelle effaçable vs acte de gouvernance collectif ».** Une même personne relève des deux : son profil est effaçable (court) ; les décisions collectives qu'elle a posées appartiennent au commun (long).

**BG2-4 — Le staff bénéficie du même régime que la lectrice pour ses données personnelles.** Un rôle est une fonction déléguée et révocable, pas un statut séparé. Le staff étant d'abord composé de lecteur·rices, ses données personnelles (profil, emprunts, réservations, etc.) suivent le régime court — ce qui est déjà le cas, le classement ne regardant pas le rôle.

**BG2-5 — Les actes de gouvernance vont en flux long, immuables, mais l'acteur·rice est pseudonymisé·e à l'effacement.** Cooptations, votes, validations, exclusions sont une mémoire collective auditable (cf. `network_administrators` = journal de cooptation immuable). On ne les détruit pas ; à l'effacement d'une personne, ses identifiants dans ces actes (`user_id`, `display_name`) deviennent un identifiant opaque (« ancien·ne membre »). L'acte survit, la personne disparaît.

**BG2-6 — Les contributeur·rices externes (tiers sans compte) → flux court.** Les personnes qui soumettent un point de carte ou une source de gazette sans avoir de compte n'ont pas le rôle militant assumé du staff ; le droit à l'effacement leur est pleinement dû. Rétention bornée.

**BG2-7 — Les coordonnées institutionnelles de bibliothèque → flux long.** Données d'organisation (config), à conserver, en notant qu'elles peuvent abriter l'email personnel d'un·e bénévole.

**BG2-8 — Règles de rattachement.** Les tables-filles suivent leur parent (les détails d'un emprunt sont aussi sensibles que l'emprunt). Les métadonnées Storage suivent leur bucket. Le Storage n'étant pas couvert par Supabase, son flux est la seule sauvegarde.

**BG2-9 — Hygiène base.** Le schéma `ingest` est du staging d'import (transitoire → hors backup ou court). Le schéma **`backup_2026_05_07`** (6 tables) est une vieille copie figée qui dort en production, hors de toute doctrine de rétention : **à purger** (chantier distinct).

---

## 3. Inventaire — FLUX COURT (7 j)

Liste positive exhaustive. Tout ce qui n'y figure pas (et n'est pas un acte de gouvernance, §4) tombe en flux long par défaut.

**Compte & identité lectrice**
`profiles` (email/nom/téléphone/adresse/consentements — la table centrale, cf. USER-EMAIL-1), `user_library_memberships`, `user_notification_preferences`, `user_notifications`, `user_history_retention_preferences`, `user_wishlist`, `reading_progress`.

**Circulation (parent + filles)**
`emprestimos_v2` (+ `emprestimo_itens_v2`) ; `reservas_v2` (+ `reserva_linhas_v2`, `reserva_item_workflow_v2`) ; `consultas_locais_v2` (+ `consulta_linhas_v2`, `consulta_item_workflow_v2`).

**Adhésion & carte**
`membership_payments`, `membership_expiry_notifications`, `reader_membership_events`, `reader_card_tokens`.

**Consentements & messages**
`reader_partnership_consent`, `reader_library_messages`, `lettre_consent_tokens`, `loan_midpoint_message_log`.

**Contributeur·rices externes (BG2-6)**
`cartography_submissions`, `gazette_submissions`.

**Schéma `auth`** — intégral (emails, hashes bcrypt).

**Storage** — bucket `anarbib-carte-rede`.

---

## 4. Inventaire — ACTES DE GOUVERNANCE (flux long, immuables, pseudonymisés à l'effacement — BG2-5)

`network_administrators`, `network_staff`, `network_contributors`, `network_reviewers`, `network_administrator_audit`, `network_administrator_cooptation_proposals`, `network_administrator_cooptation_votes`, `network_admin_collective_removal_proposals`, `network_admin_collective_removal_votes`, `network_admin_cross_library_actions_log`, `library_membership_audit`, `library_team_invitations`, `library_team_invitation_ratifications`, `assembleia_facilitators`, `painel_internal_tasks`.

**Porteur·ses de projet de bibliothèque** (futur·es staff, alignés sur le régime staff) : `library_requests` (+ `library_request_claims`, `library_request_mandate_transfers`, `library_request_comments`, `library_request_messages`, `library_request_votes`, `library_request_invitations`, `library_request_notification_events`). Les `email_snapshot` / `contact_*` y sont pseudonymisés à l'effacement.

---

## 5. Inventaire — FLUX LONG (non-PII, profondeur libre)

Par défaut, **tout le reste**. Principaux clusters :

- **Catalogue** : `books`, `works`, `work_expressions`, `exemplares`, `book_*`, `authors`, `author_*`, `publishers`, `audio_*`, tous les `*_draft*`.
- **Autorités / thésaurus** : `subjects`, `subject_relations`, `authority_proposal*`, `ficedl_thesaurus_terms`.
- **Référentiels** : tous les `catalog_ref_*`, `catalog_partners*`, `catalog_audit_log`, `catalog_batches`.
- **Config bibliothèque** : `libraries`, `library_themes*`, `library_circulation_policy_*`, `library_membership_rules`, `library_*_policies`, `library_notification_profiles`, `library_opening_hours`, `library_retention_policies`, `library_service_state`, `library_constitution_progress`, `library_document_governance`, `library_regulation_documents`, `library_profile_*`, `library_unarchive_log`.
- **Coordonnées institutionnelles (BG2-7)** : `library_commons`, `library_contact_profiles`, `library_public_contact`, `library_email_identity`, `library_mail_channels`.
- **Réseau / cercles** : `circles`, `circle_*`, `oai_opening_*`.
- **Partenariats** : `library_partnerships`, `partnership_rights`, `partnership_break_log`, `partner_source_*`.
- **Édition** : `gazette_issues*`, `gazette_sources`, `gazette_build_jobs`, `lettre_issues*`.
- **PEB structurel** : `interlibrary_loans_v2`, `interlibrary_loan_items_v2`, `interlibrary_loan_status_transitions`, `interlibrary_loan_events`, `ill_digital_share*`. (`coordination_contact_*` et `actor_user_id` pseudonymisés à l'effacement.)
- **Cartographie publiée** : `cartography_entries` (voir §6), `cartography_submission_notification_outbox`.
- **Documents / récolement / import** : `document_permission_requests`, `digital_assets`, `recolement_*`, `merge_log`, `fonds_export_runs`, `import_*`.
- **Outboxes & technique** (transitoires → court ou exclu) : `*_notification_outbox`, `painel_internal_task_*`, `painel_recurring_task_rules`, `painel_task_suggestion_catalog`, `auth_rate_limits`.
- **Storage** : buckets de couvertures/capas/portraits/thèmes/logos.

---

## 6. Points résiduels — tranchés (30/06/2026)

Les cinq points ouverts sont arbitrés après inspection des tables concernées. Ils deviennent BG2-10 à BG2-14.

**BG2-10 — Tables mixtes → flux long, pseudonymisation bilatérale.** `membership_validation_log`, `reader_membership_events`, `library_membership_audit` lient un acte staff à un sujet lectrice. Traitées comme actes de gouvernance (flux long, immuables) ; à l'effacement de *l'une ou l'autre* des personnes mentionnées (acteur·rice staff **ou** sujet lectrice), son identifiant est pseudonymisé. La ligne ne disparaît pas, elle se désidentifie du côté effacé — l'audit (« une validation a eu lieu le tel jour ») survit.

**BG2-11 — Entraide → flux court.** `entraide_help_requests`, `entraide_help_offers` portent un·e auteur·rice + un contenu libre (`subject`, `body`, `message`). Expression personnelle, pas acte de gouvernance : régime des données personnelles (court), conformément à BG2-3/BG2-4.

**BG2-12 — `cartography_entries` → flux long.** L'inspection révèle une table de *lieux* (bibliothèques/collectifs) avec un drapeau `contact_public` gérant la visibilité des `email`/`tel`/`adresse`. Coordonnée institutionnelle (BG2-7), pas une PII lectrice. À distinguer de `cartography_submissions` (la personne qui *soumet*), qui reste en flux court (BG2-6).

**BG2-13 — Schéma `ingest` → flux long.** L'inspection montre de la machinerie d'import de catalogue partenaire (OAI harvesting, staging rows, runs) : données bibliographiques + traçabilité staff (`created_by`/`requested_by`, pseudonymisables), aucune PII lectrice. Pas « transitoire à exclure » mais donnée d'import légitime → flux long. Optimisation possible : `ingest.partner_catalog_staging_rows` (volumineux, brut) exclu s'il est purgé après transformation en drafts.

**BG2-14 — Mécanisme de pseudonymisation & d'effacement.** Deux dispositifs articulés :
- *Pseudonymisation (base vivante)* : à l'effacement d'une personne, une fonction réécrit ses identifiants (`user_id`/`*_user_id`, `display_name`, `email_snapshot`) dans la liste fermée des tables de gouvernance par un **jeton aléatoire stable par personne**, sans table de correspondance conservée → irréversible (les actes d'un·e même ancien·ne membre restent chaînés entre eux, sans être reliables à l'identité réelle).
- *Journal d'effacement minimal* (`erasure_log` : `user_id` + `erased_at`, **rien d'autre**), rejoué après toute restauration de backup — re-DELETE des lignes du flux court, re-pseudonymisation du flux long de gouvernance. Sa rétention couvre la profondeur du flux long. Garantit que ni le flux court ni le flux long ne *réintroduisent* durablement une personne effacée, quelle que soit l'ancienneté du backup restauré.

---

## 7. Traduction opérationnelle (restic)

- **Deux dépôts restic distincts**, chiffrés (clé détenue par AnarBib, jamais par l'hôte), backend SFTP Herbes Folles (`bricolage.herbesfolles.org`, login `anarbib`, répertoire inscriptible `data/` hors docroot web — obtenu le 30/06/2026) :
  - dépôt **court** : `forget --keep-daily 7` ;
  - dépôt **long** : politique grand-père/père/fils (p. ex. `--keep-daily 7 --keep-weekly 4 --keep-monthly 6`).
- **Périmètre des dumps** : un dump base « non-PII + gouvernance » (autonome, restaurable seul) et un dump « PII » (schéma `auth` + tables court §3) ; plus les deux flux Storage correspondants.
- **Ordre de restauration** : non-PII d'abord, PII par-dessus (FK croisées : la circulation pointe vers les notices *et* vers les lectrices).
- **Cible authentification** : le dépôt en écriture hors docroot web est obtenu (`bricolage.herbesfolles.org:data/`, 30/06/2026) ; reste à basculer du mot de passe vers la **clé SSH** (cf. §7 du cadrage sauvegardes : « clé SSH, pas de mot de passe »).

---

*Fin du cadrage. Les décisions BG2-1..BG2-9 sont prêtes à graduer au REGISTRE §BG2 ; ce document recevra alors le tampon « document de travail — historique ».*
