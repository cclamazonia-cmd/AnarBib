# DÉCISION — Arbitrage de la migration Supabase → VPS

> Date : 2026-07-03. Formalise les décisions que le
> [`MEMO_migration_supabase_vers_vps_2026-06-19`](../cadrages/MEMO_migration_supabase_vers_vps_2026-06-19.md)
> laissait « recommandées mais à trancher » (§9). But : verrouiller ici tout ce
> qui est décidable **sans** attendre les camarades, et n'exposer qu'une seule
> vraie inconnue externe (le dimensionnement), déjà chiffrée.

## 0. État du préalable bloquant #BG2

Le mémo (§7) faisait de #BG2 (sauvegardes militantes) un **préalable bloquant** à
la migration. **#BG2 est désormais validé opérationnellement** (premier tir réel +
restore-test concluants, cf. suivi BG2). → **La migration n'est plus gatée par
#BG2** ; elle l'est seulement par le dimensionnement du VPS (§4 ci-dessous).

## 1. Volumétrie réelle (mesurée le 2026-07-03)

| Poste | Valeur | Source |
|---|---|---|
| Taille base Postgres | **102 Mo** | `pg_database_size` |
| Storage (16 buckets) | **~430 Mo** | `sum(storage.objects.size)` |
| Dont plus gros bucket | `anarbib-pdf-public` = 315 Mo | idem |
| Comptes `auth.users` | 15 (staging) | — |
| Version Postgres | **17.6** (majeure **17**) | `version()` |
| Extensions requises | `pg_cron`, `pg_net`, `pg_trgm`, `pgcrypto`, `uuid-ossp` | `pg_extension` |

**Total données ≈ 530 Mo.** Négligeable pour n'importe quel VPS moderne. La
contrainte se déplace entièrement sur la **RAM** (la pile self-hosted est lourde)
et sur la **maturité opérationnelle** de l'exploitant.

## 2. Décisions verrouillées ici (indépendantes des camarades)

### D1 — Stratégie **A : Supabase self-hosted (Docker)**. ✅ Décidé.
Le socle = ~150 fonctions `SECURITY DEFINER` + GoTrue + PostgREST + Storage +
Realtime + Edge Runtime + `pg_cron`/`pg_net`, en partie créé hors migrations. A
reproduit la **même** pile → le code applicatif ne change quasiment pas (adresses +
clés). B (décomposer brique par brique) multiplie les points de casse précisément
sur la partie la plus fragile.
**Condition de bascule vers B** : uniquement si le VPS ne peut pas faire tourner la
pile Docker Supabase (RAM insuffisante, cf. §4-Q3) **ou** refus politique de Docker.

### D2 — E-mails. 🔄 **ROUVERT le 2026-07-03** (était : « rester sur Resend »).
Motifs de réouverture : (1) **coût** — Resend gratuit plafonne à **100 mails/jour**,
qu'on dépassera vite ; (2) **souveraineté** — Resend est **états-unien**. On veut donc
sortir de Resend. **MAIS** le facteur décisif est la **délivrabilité** :
l'e-mail transactionnel (surtout les **réinitialisations de mot de passe**) doit
arriver, pas finir en spam. Un SMTP sur **IP fraîche** = mauvaise réputation, rejets
Gmail/Outlook, besoin PTR + SPF/DKIM/DMARC + warm-up + surveillance blocklists.
→ **Question à trancher AVEC Herbes Folles** (cf. §4-Q8) : *font-ils déjà tourner un
serveur mail réputé qu'on pourrait relayer ?*
- **Si oui** → mail chez HF (souveraineté + délivrabilité). Préféré.
- **Si non** → **ne pas** leur faire monter un SMTP à froid ; repli sur un
  **transactionnel européen** (Scaleway TEM — FR ; Infomaniak — CH), voire
  Autistici (déjà utilisé pour la visio) si pertinent. Resend gardé seulement en
  transition/dernier recours.

### D3 — Frontend. 🔄 **ROUVERT le 2026-07-03** — penche vers **Herbes Folles**.
(était : « rester sur Codeberg Pages ».) Motif : **Codeberg s'est révélé instable**
sur la durée. Le front est un **build statique** (quelques Mo) → le servir depuis le
reverse-proxy du VPS (Caddy/Traefik, déjà nécessaire pour l'API) est **quasi gratuit
en ressources et sans risque** (rien à voir avec l'e-mail). Ça supprime la dépendance
Codeberg et consolide tout au même endroit. → **Recommandé : héberger le front chez
HF** ; seul ajout = un domaine + TLS pour `app.anarbib.org` (qu'on a de toute façon
pour l'API). Question posée à HF (§4-Q7).

### D6 — Partenariat financé (~50 €/mois). 🆕 **Piste ouverte le 2026-07-03**.
Proposer une **contribution mensuelle (~50 €)** à Herbes Folles pour héberger
l'ensemble. Ça soutient le collectif **et** ça renforce directement la réponse à la
préoccupation Q6 (**qui maintient/teste la restauration dans la durée ?**) : un
hébergement rémunéré est plus soutenable qu'un bénévolat pur.

### D4 — Auth / JWT : **migrer `auth.users` fidèlement + ROTATER le secret JWT**. ✅ Décidé.
- Les **hash de mots de passe** vivent dans `auth.users` → on migre ce schéma tel
  quel : **personne ne perd son compte ni son mot de passe**.
- Le **secret JWT GoTrue** est **régénéré** sur le VPS (bonne hygiène de rotation à
  la bascule). Conséquence : les **sessions actives sont invalidées → chaque
  personne se reconnecte une fois** (friction minime, 15 comptes aujourd'hui).
- Régénérer le secret implique de **regénérer les clés `anon` / `service_role`**
  (dérivées du secret) et de les reporter dans le front + les Edge Functions — ce
  qui est de toute façon nécessaire (piège mémo §5.5).
**Pourquoi pas préserver le secret ?** Préserver éviterait la reconnexion unique,
mais rotater est plus sain (on ne traîne pas un secret exporté) et le coût côté
utilisateur est négligeable à cette échelle.

### D5 — Storage backend self-hosted : **backend fichier local** (pas S3). ✅ Décidé.
430 Mo → le backend disque local du service Storage suffit largement ; pas de
dépendance S3 externe. La sauvegarde du Storage (#BG2) copie ces fichiers physiques.

## 3. Ce qui reste explicitement OUVERT (dépend des camarades)

Depuis la réouverture D2/D3/D6 (03/07), trois inconnues dépendent de HF, toutes dans
les questions du §4 :
1. **Le VPS peut-il faire tourner la pile A ?** (RAM — Q1, décisif A vs B).
2. **HF fait-il du mail réputé qu'on peut relayer ?** (Q8, décide D2).
3. **HF peut-il servir le front statique ?** (Q7, quasi acquis, confirme D3).
Le socle technique (D1 stratégie A, D4 auth, D5 storage) reste tranché.

## 4. Questions chiffrées à envoyer à Herbes Folles

Formulées pour des réponses **oui/non/valeur**, avec le besoin réel en regard.

- **Q1 — RAM.** La pile Supabase self-hosted (Postgres + GoTrue + PostgREST +
  Storage + Kong + Realtime + Edge Runtime + Studio + imgproxy + meta) demande
  **≥ 4 Go de RAM réalistes, 8 Go confortables**. Combien de RAM le VPS peut-il
  allouer durablement à AnarBib ? *(C'est LE point qui décide A vs B.)*
- **Q2 — Docker.** Docker + Docker Compose sont-ils disponibles / autorisés sur la
  machine ?
- **Q3 — Postgres 17.** Peut-on faire tourner **Postgres majeure 17** (via l'image
  `supabase/postgres`) ? *(La base source est en 17.6 ; un dump vers une majeure
  différente peut coincer.)*
- **Q4 — Disque.** Les données sont petites (**base ~102 Mo + Storage ~430 Mo**),
  mais **les images Docker + les volumes + la marge de sauvegardes** pèsent
  plusieurs Go. Peut-on compter sur **≥ 20 Go** dédiés ?
- **Q5 — Accès.** Accès **SSH par clé** (pas mot de passe) : identifiant, port,
  ajout de notre clé publique ? *(Même modèle que la clé BG2 déjà en place.)*
- **Q6 — Exploitation durable.** **Qui**, côté structure, lance/surveille la pile
  et **teste la restauration chaque mois** ? *(Le mémo §7 est net : le facteur
  limitant est là, pas dans le disque.)* → adossé à la contribution ~50 €/mois (D6).
- **Q7 — Frontend statique (D3).** Peut-on **servir un site statique** (build
  React/Vite, quelques Mo) depuis votre reverse-proxy, avec un domaine + TLS pour
  `app.anarbib.org` ? *(Remplacerait Codeberg Pages, jugé instable.)*
- **Q8 — E-mail (D2).** Faites-vous tourner un **serveur mail / relais SMTP** qu'on
  pourrait utiliser pour envoyer les mails d'AnarBib (depuis `@anarbib.org`) ? Si
  oui, quelle **réputation d'envoi** (IP déjà chaude, PTR/reverse-DNS, SPF/DKIM/DMARC
  gérables) ? *(Si non : on ne vous demande pas de monter un SMTP à froid — on
  prendra un transactionnel européen. La délivrabilité prime.)*

## 5. Séquence une fois le VPS confirmé (rappel, non exécutable ici)

Inchangée vs mémo §4 : préparer la pile (PG17) → `pg_dump` (rôles + `auth` +
`storage` + extensions) → transfert → restaurer → migrer les fichiers Storage →
redéployer les 43 Edge Functions + re-saisir les secrets (cf.
[`.env.example`](../../../.env.example)) → réactiver `pg_cron` en **corrigeant les
URL** des Edge Functions → repointer le front (nouvelles URL/clés, rebuild) → **DNS
en dernier**, réversible. Les deux instances tournent en parallèle jusqu'à
validation (dry-run : connexion + catalogue + un mail + un cron).

> Prochain livrable naturel quand le VPS est confirmé : transformer le mémo + cette
> décision en **runbook d'exécution daté** (commandes exactes).
