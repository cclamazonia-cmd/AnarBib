# Chantier #110 — R.6 : séquençage de la suppression de Brevo

**Document de décision**
**Date de rédaction** : 22/05/2026
**Auteur·rices** : Xavier (décision), Claude (rédaction technique)
**Statut** : plan préparatoire — exécution planifiée au **05/06/2026**, non exécuté à ce jour
**Référence** : `docs/specs/spec-migration-mail-resend.md` v0.3, §5.7 (R.6) et §8.3 (critères de clôture)

---

## 1. Objet et statut

Ce document séquence l'exécution de R.6 — la suppression de Brevo — dernier sous-paquet du chantier #110. Il est rédigé le 22/05/2026, **avant exécution**, pour que le jour J le démantèlement soit propre, ordonné et sans improvisation.

R.6 n'est pas exécuté à la date de rédaction. Il est planifié au **05/06/2026**, ce qui place un peu plus de deux semaines de coexistence stable après la bascule R.4 du 21/05 — délai conforme à la précondition de la spec v0.3 (§5.7 : « délai minimal de quelques semaines de coexistence stable depuis R.4 »).

## 2. Préconditions à vérifier le jour J

Avant de lancer la moindre étape de R.6, le 05/06, vérifier que **toutes** les conditions suivantes sont réunies. Si l'une manque, R.6 est reporté et la cause traitée d'abord.

1. **R.5 au vert.** Aucun incident Resend sur la période 21/05 → 05/06 : pas de mail en statut `failed` dans le dashboard Resend, pas d'erreur 403/422 dans les logs des Edge Functions.
2. **Indicateurs de santé corrects** (spec §8.5) : taux de bounce mensuel sous 5 %, taux de plaintes spam sous 0,1 %.
3. **Silence de Brevo maintenu** : aucun envoi Brevo (filtre `Sent` dans les logs Brevo) depuis le 21/05 20h31.
4. **Aucune mauvaise surprise** : pas d'évolution tarifaire Resend, pas d'élément justifiant de conserver Brevo en repli.
5. **Arbre git propre** : aucune modification non commitée en cours sur les transports mail.

Si tout est vert : R.6 peut être exécuté. Dans le cas contraire, reporter et tracer la raison.

## 3. Principe directeur : ordre par irréversibilité croissante

Les quatre étapes de R.6 n'ont pas le même degré de réversibilité. L'ordre d'exécution est choisi pour **garder le filet de rollback le plus longtemps possible** et ne franchir le point de non-retour qu'en dernier, une fois le reste vérifié.

- **R.6.1 (code)** — réversible par git : un `git revert` restaure `sendViaBrevo`.
- **R.6.2 et R.6.3 (secrets)** — destructif : une valeur de secret supprimée est définitivement perdue.
- **R.6.4 (compte Brevo)** — la spec recommande le standby, pas la fermeture : cette étape ne ferme rien le 05/06.

Conséquence : on exécute R.6.1 d'abord (réversible), on vérifie que tout tient sous Resend **sans** la branche Brevo dans le code, et **seulement ensuite** on supprime les secrets (R.6.2/6.3). R.6.4 se réduit à une décision administrative, sans geste destructif ce jour-là.

## 4. Séquence détaillée

### Étape préalable P.0 — sauvegarde des valeurs de secrets Brevo

**Avant toute suppression**, consigner hors-ligne (gestionnaire de mots de passe) les valeurs des secrets Brevo qui seront supprimés en R.6.2/6.3. Raison : si une régression imprévue imposait un retour à Brevo après R.6, il faut pouvoir reposer les secrets. Sans cette sauvegarde, R.6.2 rend le rollback Brevo définitivement impossible.

Secrets à sauvegarder : voir liste en R.6.2 et R.6.3 ci-dessous.

### R.6.1 — Retrait du code Brevo dans les transports

**Périmètre.** Dans chaque transport migré, supprimer la fonction `sendViaBrevo` et la branche `brevo` du dispatch. `sendEmail` devient un appel direct à `sendViaResend`. La variable `MAIL_PROVIDER` peut être conservée (valeur fixe `resend`, par cohérence) ou retirée — décision à trancher le jour J ; recommandation : la **conserver** un temps, retrait éventuel en R.7.

**Fichiers concernés** — les transports migrés en R.2 et R.3 :

- `supabase/functions/notify-event/_shared/transport/email.ts` (transport partagé, R.2)
- `supabase/functions/notify-internal-task/_shared/transport/email.ts` (copie privée, R.3.1)
- `supabase/functions/notify-mid-loan-reading/index.ts`
- `supabase/functions/notify-document-permission-request/index.ts`
- `supabase/functions/notify-network-weekly-report/index.ts`
- `supabase/functions/notify-weekly-report/index.ts`
- `supabase/functions/notify-library-request/index.ts`
- `supabase/functions/register/index.ts`

Soit huit transports. À confirmer le jour J par un `grep -rn "sendViaBrevo" supabase/functions/` : la liste des fichiers retournés doit correspondre exactement à celle ci-dessus.

**Méthode.** Un transport à la fois. Pour chacun : supprimer `sendViaBrevo`, simplifier `sendEmail`, conserver intacts `sendViaResend`, l'inlining des logos et le contrat de retour. Le `register` (cas option β) conserve sa fonction de traduction `brevoPayloadToResend` ? — **non** : une fois la branche Brevo retirée, cette traduction n'a plus d'objet ; la supprimer aussi, et faire que les sites d'appel construisent directement le format attendu, OU conserver la traduction comme simple normalisation interne. Point à trancher à la relecture du fichier le jour J.

**Vérification.** Build + déploiement Woodpecker au vert. Puis re-test runtime d'au moins une EF par famille (a minima `register` et `notify-event`) pour confirmer que le retrait de la branche Brevo n'a rien cassé. `MAIL_PROVIDER` étant déjà à `resend`, le comportement observable doit être identique.

**Réversibilité.** Totale à ce stade : `git revert` du commit restaure `sendViaBrevo`. Le point de non-retour n'est pas encore franchi.

### R.6.2 — Suppression des secrets Brevo dans Supabase

**Périmètre.** Supprimer les secrets propres à Brevo. D'après l'inventaire `supabase secrets list` du 21/05, les candidats sont :

- `BREVO_API_KEY`
- `BREVO_API_KEY_NOTIFICATIONS`
- `BREVO_API_KEY_NOTIFY_INTERNAL_TASK`
- `BREVO_API_KEY_NOTIFY_RESERVA`
- `BREVO_API_KEY_STAGING`
- `BREVO_SENDER_EMAIL`
- `BREVO_SENDER_NAME`

**Préalable impératif.** Avant suppression, exécuter `grep -rn -i "brevo" supabase/functions/` et confirmer qu'**aucun code de production ne lit plus ces variables** (hors commentaires historiques). Si R.6.1 a été fait correctement, plus aucune lecture ne subsiste. Si un `Deno.env.get("BREVO_...")` traîne encore, le traiter avant de supprimer le secret.

**Méthode.** Suppression via `supabase secrets unset <NOM>` (ou le dashboard). Un secret à la fois, en cochant la liste.

**Réversibilité.** À partir d'ici, le rollback vers Brevo n'est plus possible sans reposer les secrets depuis la sauvegarde P.0. **C'est le point de non-retour de R.6.** Ne franchir cette étape qu'après R.6.1 vérifié et stable.

### R.6.3 — Nettoyage des variantes historiques de sender

**Périmètre.** Les variables d'environnement de sender conservées en fallback, devenues inutiles une fois Brevo retiré. Candidates : `ANARBIB_SENDER_EMAIL`, `NETWORK_SENDER_EMAIL`, `BREVO_SENDER_MAIL` (ou graphies voisines), et toute variante repérée lors de la vérification de couture sender (cf. tâche du 23/05, à rapprocher de #119).

**Préalable.** Cette étape dépend de la vérification de couture sender prévue le 23/05 : c'est elle qui établira la **liste exhaustive** des variantes existantes et de celles que le code lit encore. R.6.3 ne peut être finalisée qu'avec cette liste en main. Tant qu'une variante est lue par un transport comme fallback, ne pas la supprimer sans avoir vérifié que `SENDER_EMAIL` (la variable canonique, alignée) couvre le cas.

**Prudence.** `ANARBIB_SENDER_EMAIL` et `NETWORK_SENDER_EMAIL` ont été *alignées* (et non supprimées) en R.4 — elles pointent désormais sur `no-reply@notifications.anarbib.org`. Les supprimer est de l'hygiène, pas une urgence ; le faire seulement si la vérification du 23/05 confirme qu'aucune EF n'en dépend de façon non couverte par `SENDER_EMAIL`.

### R.6.4 — Décision sur le compte Brevo

**Recommandation de la spec** : standby quelques mois (compte gratuit, sans frais), puis fermeture. **Aucun geste destructif le 05/06.** L'étape se limite à : confirmer que le compte Brevo CCLA ne génère aucun coût (plan gratuit), et noter une échéance de fermeture définitive (indicativement, fin d'été 2026). La fermeture effective sera un acte administratif ultérieur, tracé séparément.

## 5. Critères de clôture de R.6 (spec §8.3 / §8.6)

R.6 est considéré clos quand les critères bloquants suivants sont atteints :

- **8.3.1** — `grep -r -i "brevo" supabase/functions/` ne retourne que des commentaires historiques.
- **8.3.2** — aucun secret Brevo dans le dashboard Supabase.
- **8.3.3** — registre RGPD à jour : substitution Brevo→Resend effective, mention du DPA, mention du garde-fou tracking.
- **8.3.5** — aucun coût mensuel Brevo facturé (compte `inactive` ou `closed`, dernière facture à 0 €).
- **8.3.6** — garde-fou tracking inscrit dans le manuel admin réseau.

Note : 8.3.3 et 8.3.6 sont des critères **documentaires** — ils peuvent demander une mise à jour de `docs/legal/registre-traitements.md` et du manuel admin réseau. À anticiper : R.6 n'est pas qu'un geste technique, il a un volet documentaire à ne pas oublier.

## 6. Récapitulatif de l'ordre d'exécution le 05/06

1. **P.0** — sauvegarder hors-ligne les valeurs des secrets Brevo.
2. **R.6.1** — retirer `sendViaBrevo` des 8 transports, un par un ; build + déploiement ; re-test runtime. *(réversible)*
3. Vérifier la stabilité 24-48 h si possible, ou au minimum re-tester chaque famille.
4. **R.6.2** — supprimer les secrets Brevo, après `grep` confirmant l'absence de lecture. *(point de non-retour)*
5. **R.6.3** — nettoyer les variantes de sender, selon la liste établie le 23/05.
6. **R.6.4** — acter le standby du compte Brevo, noter l'échéance de fermeture.
7. Mettre à jour les documents : registre RGPD, manuel admin réseau, fiche #110 du backlog (clôture de #110), spec v0.3 (bilan R.6).

## 7. Points ouverts à trancher le jour J

- Conserver ou retirer la variable `MAIL_PROVIDER` (recommandation : conserver, retrait en R.7).
- Sort de la fonction `brevoPayloadToResend` dans `register` (supprimer, ou conserver comme normalisation interne).
- Faut-il une fenêtre de stabilité entre R.6.1 et R.6.2 (recommandé : oui, au moins 24 h).
