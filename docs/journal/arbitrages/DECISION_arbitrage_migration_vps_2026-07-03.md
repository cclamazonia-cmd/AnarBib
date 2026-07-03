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

### D2 — E-mails : **rester sur Resend**. ✅ Décidé.
La migration Brevo → Resend est faite (R.6, 05/06), la délivrabilité est résolue.
Garder Resend évite tout le fardeau SMTP interne (SPF/DKIM/DMARC gérés côté Resend,
pas de PTR/réputation IP à tenir). **Rien à changer côté mail** lors de la bascule.
**Condition de bascule vers SMTP interne** : seulement si une raison politique
explicite l'exige (souveraineté mail). À défaut, non.

### D3 — Frontend : **rester sur Codeberg Pages**. ✅ Décidé.
Statique, déjà en place, réduit la surface du VPS (pas de reverse-proxy front à
maintenir). Il se contente de pointer vers la nouvelle API. Seuls `VITE_SUPABASE_URL`
et `VITE_SUPABASE_ANON_KEY` changent, puis rebuild + redéploiement Pages.
**Condition de bascule vers hébergement VPS** : aucune prévue au lancement.

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

Une seule inconnue structurante : **le VPS peut-il faire tourner la pile A ?**
Tout le reste (D1–D5) est tranché. La réponse tient dans les 6 questions chiffrées
du §4, prêtes à envoyer.

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
  limitant est là, pas dans le disque.)*

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
