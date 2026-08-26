# Audit — pile auto-hébergée minimale

> **Réécrit le 26/08/2026.** Ce document remplace `AUDIT_pile_minimale_2026-08-17`,
> référencé par `deploy/compose.yml` et `deploy/README.md` mais **qui n'a jamais
> existé dans le dépôt**. C'est le même angle mort que `genkeys.mjs` le 19/08 et
> que la chaîne de sauvegarde le 20/08 : *ce qui n'est pas dans le dépôt n'existe
> qu'une fois*, et ici il n'existait pas du tout — deux fichiers renvoyaient à une
> justification introuvable. Les vérifications ci-dessous ont donc été refaites,
> pas recopiées.

- **Objet :** justifier, service par service, la composition de la pile
  auto-hébergée de `deploy/compose.yml`.
- **Portée :** ce qui tourne dans les conteneurs. Ni la chaîne de sauvegarde
  (`deploy/ops/`), ni le déploiement du frontend.
- **Nature :** audit de *nécessité*, pas de sécurité. Il répond à « ce service
  a-t-il un consommateur ? », pas à « ce service est-il correctement durci ? ».

---

## 1. Une addition à corriger d'abord

`compose.yml` et le README annoncent « six services au lieu des douze du
docker-compose officiel ». Le compte est faux dans les deux sens, et un audit
commence par là.

Le compose officiel de Supabase déclare **treize** services : `db`, `studio`,
`kong`, `auth`, `rest`, `realtime`, `storage`, `imgproxy`, `meta`, `functions`,
`analytics`, `vector`, `supavisor`.

Cette pile en **garde cinq** — `db`, `rest`, `auth`, `storage`, `functions` — en
**retire huit**, et **ajoute Caddy** à la place de Kong. D'où six conteneurs.

La formulation juste est donc : **six conteneurs, dont cinq repris de la pile
officielle et un substitué.** Ce n'est pas un détail de présentation : « on a
enlevé la moitié » et « on a gardé cinq briques sur treize et remplacé la
passerelle » ne décrivent pas le même objet, et c'est le second qui est vrai.

---

## 2. Ce que la pile garde

| Service | Image | Plafond | Ce qui casse sans lui |
|---|---|---|---|
| `db` | `supabase/postgres` | 1 536 Mo | tout |
| `rest` | `postgrest/postgrest` | 384 Mo | le catalogue, toutes les vues `api.*` |
| `auth` | `supabase/gotrue` | 192 Mo | connexion, inscription, réinitialisation |
| `storage` | `supabase/storage-api` | 768 Mo | couvertures, portraits, PDF, EPUB, audio |
| `functions` | `supabase/edge-runtime` | 512 Mo | courriels, OAI-PMH, recherches de métadonnées |
| `caddy` | `caddy` | 128 Mo | TLS et routage — plus rien n'est joignable |

**Total des plafonds : 3 520 Mo.** C'est ce chiffre — et non une estimation —
qui fonde la demande d'une VM de 4 Go.

⚠️ **Un plafond n'est pas une consommation.** Ces valeurs bornent ce que chaque
conteneur peut prendre ; elles ne disent pas ce qu'il prend. La consommation au
repos relevée est de 358 Mo pour l'ensemble. Nous n'avons **pas** mesuré la
consommation sous charge : la pile n'a jamais tourné ailleurs que sur une
machine de répétition. Si on nous demande la charge réelle, la réponse honnête
est « elle est bornée, elle n'est pas mesurée ».

**`db` n'est pas un PostgreSQL ordinaire.** Le code utilise `vault.` et `cron.`,
fournis par l'image Supabase et non par Postgres standard. Substituer une image
vanilla casserait les secrets du Vault et les tâches planifiées.

---

## 3. Ce que la pile retire, et sur quelle preuve

### `realtime` — aucun consommateur

**Vérifié le 26/08 :** recherche de `.channel(`, `postgres_changes` et
`removeChannel` dans tout `src/` — **aucune occurrence**. Le frontend ne
s'abonne à rien ; il interroge et rafraîchit.

*Coût du retrait :* nul aujourd'hui. Le jour où une page voudrait se mettre à
jour toute seule — une file de prêts, un tableau de bord partagé — il faudra le
réintroduire. C'est un choix réversible.

### `imgproxy` — plus aucune transformation demandée

**Le cas qui justifie de refaire cet audit plutôt que de le recopier.** La ligne
du README disait « aucune transformation d'image demandée à Storage ». Elle
était **fausse au moment où elle a été écrite** : depuis le 17/06/2026, la grille
du catalogue appelait `/storage/v1/render/image/`. Sur une instance montée depuis
ce dépôt, elle aurait affiché des images cassées au premier démarrage — et c'est
probablement ce qui s'est passé pendant la répétition des 17-18/08, sans que ce
soit relevé.

Elle est devenue vraie le **26/08/2026** : les vignettes sont désormais
pré-générées et servies comme des fichiers ordinaires (`src/lib/coverThumbs.js`,
`scripts/backfill-cover-thumbs.py`), et les transformations d'images sont
**désactivées au niveau du projet** — tout appel à `render/image` répond
`403 FeatureNotEnabled`. Vérifié en ligne : 296 vignettes pour 296 originaux,
zéro appel résiduel dans le catalogue public.

*Coût du retrait :* nul, et la désactivation côté projet en fait une garantie
plutôt qu'une convention.

### `studio` — administration par migrations

L'administration passe par les migrations versionnées (179 au 26/08) et par
`psql`. Studio est une interface de développement.

*Coût du retrait, et il est réel :* **aucune interface web pour inspecter la
base** sur une instance auto-hébergée. Qui exploite la machine a besoin de
`psql` et de savoir s'en servir. C'est acceptable pour une personne qui écrit
déjà les migrations ; ça ne l'est pas si l'exploitation doit passer à quelqu'un
d'autre en urgence. À dire tel quel plutôt qu'à minimiser.

### `meta` — n'existe que pour Studio

`postgres-meta` est l'API que Studio interroge. **Vérifié :** aucun autre
consommateur dans `src/`, `supabase/` ou `deploy/`. Sans Studio, il n'a personne
à servir.

*Coût du retrait :* nul, par construction — il tombe avec Studio.

### `analytics` (Logflare) et `vector` — les journaux vont à journald

`vector` collecte les journaux des conteneurs pour les pousser vers `analytics`.
Sans `analytics`, `vector` n'a pas de destination. Les journaux restent
accessibles par `docker logs` et `journalctl`.

*Coût du retrait, et il est réel aussi :* **pas d'explorateur de journaux**, donc
pas de recherche dans l'historique, pas de graphiques, pas d'alerte sur motif.
Le diagnostic se fait à la main. C'est une perte de confort qui devient une perte
d'information le jour d'un incident intermittent.

### `kong` — remplacé, pas supprimé

Caddy assure le routage de la passerelle API. **Vérifié dans `deploy/Caddyfile` :**
les quatre préfixes sont servis — `/auth/v1/*` → `auth:9999`, `/rest/v1/*` →
`rest:3000`, `/storage/v1/*` → `storage:5000`, `/functions/v1/*` →
`functions:9000`. Caddy apporte en plus le TLS automatique, que Kong n'assure pas
dans le compose officiel.

*Coût du retrait :* on perd les greffons de Kong. Un en particulier a déjà
manqué : la **limitation de débit sur OAI-PMH** n'est pas en place, et la
directive prévue venait d'un greffon absent de l'image Caddy utilisée. C'est au
backlog, et c'est une conséquence directe de ce choix — à connaître avant de
promettre un débit borné.

### `supavisor` — pooler sans objet à cette échelle

`supavisor` mutualise les connexions Postgres pour des clients externes
nombreux. Ici, le seul client permanent est PostgREST, qui tient son propre pool.
La chaîne de sauvegarde se connecte au *pooler infogéré du cloud*
(`aws-1-sa-east-1.pooler.supabase.com`, `deploy/ops/anarbib-bg2.sh:43`), pas à un
supavisor auto-hébergé : elle n'en dépend donc pas.

*Coût du retrait :* nul à la charge actuelle. **Ce qui le ferait revenir :** des
connexions directes nombreuses — un second front, des scripts externes, une
instance qui expose Postgres à des tiers. Le goulot mesuré sur l'instance
infogérée est d'ailleurs le pool PostgREST, pas le nombre de connexions
Postgres : c'est de ce côté qu'il faudra regarder en premier, pas du côté d'un
pooler.

---

## 4. Ce qui forcerait à réintégrer un service

| Si un jour… | Alors il faut |
|---|---|
| une page doit se mettre à jour sans rechargement | `realtime` |
| le catalogue redemande des images redimensionnées à la volée | `imgproxy` |
| l'exploitation passe à quelqu'un qui n'écrit pas de SQL | `studio` + `meta` |
| il faut chercher dans l'historique des journaux, ou alerter sur motif | `analytics` + `vector` |
| des clients externes se connectent directement à Postgres | `supavisor` |

Aucune de ces cinq lignes n'est hypothétique au point d'être écartée. Elles sont
simplement **fausses aujourd'hui**, et c'est la seule chose qu'un audit peut
constater.

---

## 5. Limites de cet audit

- **Il constate des absences de consommateur, pas des absences de besoin.**
  « Aucune occurrence de `.channel(` » prouve que le frontend actuel n'utilise
  pas le temps réel ; ça ne prouve pas qu'on n'en voudra jamais.
- **Il porte sur le dépôt au 26/08/2026.** Chaque chiffre cité (179 migrations,
  296 vignettes, quatre routes Caddy) vieillira. Ce sont les *vérifications* qui
  doivent être rejouées, pas les nombres qui doivent être crus.
- **Il ne dit rien de la sécurité.** Retirer six services réduit la surface
  d'attaque, ce qui est un effet secondaire heureux et non une démonstration.
  Le durcissement des fonctions à privilèges élevés est un chantier distinct.
- **La pile n'a jamais tourné en production.** Elle a été reconstruite de bout
  en bout depuis le dépôt seul, deux fois, le 21/08 — c'est un fait solide, mais
  ce n'est pas de l'exploitation. Tout ce qui touche à la charge relève de
  l'estimation.

---

## 6. Rejouer les vérifications

Chacune tient en une commande, et c'est ce qui rend cet audit vérifiable plutôt
que déclaratif.

```bash
# Le compte de six, depuis le compose lui-même — pas depuis un commentaire.
# Les deux fichiers d'environnement sont gitignorés (ils portent les secrets) :
# des valeurs factices suffisent à valider la structure.
docker compose --env-file <env-factice> -f deploy/compose.yml config \
  | grep -E '^  [a-z_-]+:$'

# realtime : aucun abonnement dans le frontend
grep -rn '\.channel(\|postgres_changes\|removeChannel' src/

# imgproxy : aucune transformation demandée
grep -rn 'render/image' src/ supabase/
curl -sI 'https://<ref>.supabase.co/storage/v1/render/image/public/covers/x.jpg'
#   -> 403 FeatureNotEnabled attendu

# meta : aucun consommateur hors Studio
grep -rniE 'postgres-meta|pg_meta' src/ supabase/ deploy/

# kong : les quatre routes reprises par Caddy
grep -nE 'handle_path|reverse_proxy' deploy/Caddyfile
```

Au 26/08/2026, `docker compose config` sort en 0 et déclare : `auth`, `caddy`,
`db`, `functions`, `rest`, `storage`. Six, et les mêmes que le tableau du §2.

---

## 7. Liens

- Pile : [`deploy/compose.yml`](../../../deploy/compose.yml) ·
  [`deploy/Caddyfile`](../../../deploy/Caddyfile) ·
  [`deploy/README.md`](../../../deploy/README.md)
- Sauvegardes : [`deploy/ops/README.md`](../../../deploy/ops/README.md)
- Restauration :
  [`RUNBOOK_restauration_BG2_2026-07-01`](../operations/RUNBOOK_restauration_BG2_2026-07-01.md)
- Vignettes et fin des transformations : `src/lib/coverThumbs.js`,
  `scripts/backfill-cover-thumbs.py`
