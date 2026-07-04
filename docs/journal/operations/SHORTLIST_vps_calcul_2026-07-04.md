# SHORTLIST — VPS pour le calcul AnarBib (pile Supabase self-hosted)

> Branche « **le calcul ailleurs que chez HF** » de la
> [`DECISION_arbitrage`](../arbitrages/DECISION_arbitrage_migration_vps_2026-07-03.md) : un VPS **qu'on
> loue et administre**, HF gardant le rôle léger (sauvegarde + éventuel mail). Cible = faire tourner la
> pile Docker Supabase (cf. [`RUNBOOK_migration_vps`](RUNBOOK_migration_vps_2026-07-04.md)).
> Rédigé 2026-07-04.
>
> ⚠️ **Prix indicatifs** (ordre de grandeur, connaissance ~début 2026) — **à revérifier** sur les sites
> avant décision. Je peux récupérer les tarifs live si tu veux.

## Dimensionnement cible
- **RAM : 8 Go** (la pile ≈ 10 conteneurs veut 4 Go minimum, 8 Go pour respirer). C'est le poste décisif.
- **vCPU : 4.** **Disque : 40–80 Go SSD/NVMe** (données ~530 Mo, mais images Docker + volumes + marge backups pèsent quelques Go ; large = confort).
- **IP fixe + reverse DNS**, accès **SSH clé**, snapshots/backup fournisseur (bonus, ne remplace pas #BG2).

## Critères pour un projet comme AnarBib
Souveraineté **UE/hors-USA**, **RGPD**, énergie **renouvelable**, respect vie privée, prix soutenable
(~contribution mensuelle du même ordre que les 50 € évoqués).

## Comparatif (8 Go RAM / 4 vCPU, ordre de grandeur mensuel)

| Fournisseur | Pays | ~Prix/mois (8 Go) | Valeurs / notes | Pour AnarBib |
|---|---|---|---|---|
| **Hetzner** | 🇩🇪 DE | **~8 € (CAX ARM) / ~16 € (x86)** | RGPD, énergie verte revendiquée, référence de l'auto-hébergement. Le meilleur rapport perf/prix. | ✅ **Défaut pragmatique** |
| **1984 Hosting** | 🇮🇸 IS | ~15–25 € | **Très aligné militant** (Islande : hydro/géothermie, lois vie privée fortes, proche des orgs activistes). | ✅ **Meilleur fit valeurs** |
| **Infomaniak** | 🇨🇭 CH | ~20–40 € | Éthique/écologie de pointe (renouvelable, neutralité Suisse, coopératif dans l'esprit). Plus cher. | ✅ Fit valeurs, budget + |
| **Scaleway** | 🇫🇷 FR | ~15–25 € | Français, RGPD, bon écosystème cloud (groupe Iliad). | 🟡 correct |
| **OVHcloud** | 🇫🇷 FR | ~12–20 € | Français, RGPD, très répandu, VPS abordables. | 🟡 correct |

## Recommandation
- **Si le prix/perf prime** → **Hetzner** (idéalement une instance **ARM CAX21** ~8 €/mois : 4 vCPU / 8 Go, imbattable ; la pile Supabase tourne en arm64). C'est le choix le plus courant pour ce type d'auto-hébergement.
- **Si l'alignement politique prime** → **1984 Hosting** (Islande, militant, renouvelable) ou **Infomaniak** (Suisse, écologie). Un poil plus cher, mais cohérent avec l'ADN du projet — et ça reste dans l'enveloppe ~50 €/mois.

**Mon conseil** : partir sur **Hetzner CAX21 (ARM, 8 Go)** pour le rapport qualité/prix et la fiabilité, **ou 1984 Hosting** si tu préfères marquer le coup côté valeurs. Les deux sont UE/hors-USA, RGPD, renouvelable.

## Articulation avec Herbes Folles
Ce VPS **n'annule pas** le partenariat HF : HF reste le **dépôt de sauvegarde** (offsite, souverain, déjà en place) et, s'ils le souhaitent, le **relais mail**. La contribution ~50 €/mois peut se répartir (VPS + soutien HF) ou aller à HF selon ce que tu décides. Avantage : l'**uptime de l'app ne dépend plus de la disponibilité bénévole** de personne.

## Le point qui ne change pas
Quel que soit l'hôte, **quelqu'un doit exploiter la pile dans la durée** (mises à jour, monitoring, test de restauration mensuel #BG2). Sur un VPS loué, c'est **toi/l'équipe** — le fameux « facteur limitant = maturité opérationnelle » du mémo. À intégrer dans la décision au même titre que le prix.

> Prochaine étape logique une fois l'hôte choisi : verrouiller les commandes exactes des phases
> délicates du runbook (restauration `auth`/`storage`, génération des clés JWT) contre la doc Supabase
> self-hosting à jour, puis planifier un **dry-run**.
