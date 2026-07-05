# SHORTLIST — VPS pour le calcul AnarBib (pile Supabase self-hosted)

> Branche « **le calcul ailleurs que chez HF** » de la
> [`DECISION_arbitrage`](../arbitrages/DECISION_arbitrage_migration_vps_2026-07-03.md) : un VPS **qu'on
> loue et administre**, HF gardant le rôle léger (sauvegarde + éventuel mail). Cible = faire tourner la
> pile Docker Supabase (cf. [`RUNBOOK_migration_vps`](RUNBOOK_migration_vps_2026-07-04.md)).
> Rédigé 2026-07-04, **enrichi** de fournisseurs militants proposés par Xavier.
>
> ⚠️ **Prix indicatifs** (ordre de grandeur, connaissance ~début 2026 + pages consultées le 2026-07-04)
> — **à revérifier** avant décision.

## Dimensionnement cible
- **RAM : 8 Go** (la pile ≈ 10 conteneurs veut 4 Go minimum, 8 Go pour respirer). Poste décisif.
- **vCPU : 4. Disque : 40–80 Go SSD/NVMe.** IP fixe + reverse DNS, SSH clé.

## Le filtre qui élimine la moitié du champ militant
Supabase self-hosted **exige un VPS root où l'on installe son propre Docker**. Or beaucoup
d'hébergeurs éthiques ne font que du **managé d'applications** (Nextcloud, YunoHost, LAMP) — pratique
pour du collaboratif, **inadapté** pour une pile Docker qu'on pilote. D'où la colonne « **Root+Docker ?** ».

## Comparatif

| Fournisseur | Pays | Offre ~8 Go / prix mensuel | Root+Docker ? | Valeurs | Robustesse |
|---|---|---|---|---|---|
| **Hetzner** | 🇩🇪 DE | CAX21 ARM 4c/8 Go ~**8 €** ; x86 ~16 € | ✅ | neutre commercial, énergie verte revendiquée | ✅✅ établi |
| **Koumbit** | 🇨🇦 CA | 4c/8 Go/240 Go ~**80 €** (120 $CAD) + ~100 $ setup ; **8 Go = plafond** | ✅ (root Debian) | ✅✅✅ **coopérative de travail militante** (~20 ans) | ✅ **équipe, établie** |
| **1984 Hosting** | 🇮🇸 IS | ~15–25 € | ✅ | ✅✅ militant, Islande renouvelable, vie privée | ✅ établi |
| **Infomaniak** | 🇨🇭 CH | ~20–40 € | ✅ | ✅✅ écologie/Suisse, coopératif dans l'esprit | ✅ établi |
| **clawd.fr** | 🇫🇷 FR | prix libre (VM à chiffrer) | ⚠️ à confirmer | ✅✅✅ **CHATONS**, libre, prix libre | 🟡 **solo** (entreprise individuelle) |
| **julienth37 / A-Hébergement** | ? | VPS **KVM**, base 512 Mo + 2 €/Go → ~**25–30 €** pour 8 Go | ✅ (KVM) capacité à confirmer | ✅✅ « associatif/coopératif », libre | 🟡 **très petit/informel**, pas de SLA/localisation |
| **Scaleway** | 🇫🇷 FR | ~15–25 € | ✅ | 🟡 FR/RGPD (groupe Iliad) | ✅ établi |
| **OVHcloud** | 🇫🇷 FR | ~12–20 € | ✅ | 🟡 FR/RGPD | ✅ établi |
| **Numéricoop** | 🇫🇷 FR | managé **YunoHost** ~119–196 € | ❌ **catalogue d'apps, pas Docker brut** | ✅✅ SCOP (Coopaname), renouvelable | ✅ mais mauvais modèle pour nous |
| **Zaclys** (loca-lamp) | 🇫🇷 FR | hébergement **LAMP** ~13–40 € | ❌ **app managé, pas root Docker** | ✅✅ assoc CHATONS | — offre inadaptée |

## Synthèse : un curseur valeurs ↔ fiabilité, avec un bon point d'équilibre

- **Robuste + neutre** → **Hetzner** (~8-16 €, UE, très fiable ; CAX21 ARM = imbattable). Défaut pragmatique.
- **Robuste + militant** → **Koumbit** (vraie **coopérative avec une équipe**, établie — pas le bus-factor=1 des hébergeurs solo). Le meilleur équilibre valeurs × fiabilité de tout le lot.
- **Militant max, capacité fragile** → **clawd.fr / julienth37 / (Herbes Folles)** : structures **solo/minuscules**, alignées à fond mais avec un vrai risque de disponibilité/continuité. À qualifier au cas par cas.
- **Hors jeu pour ce besoin** (tels que liés) : **Numéricoop** (YunoHost managé), **Zaclys loca-lamp** (LAMP). Éventuelle offre « VPS nu » à demander, sinon non.

### Bémols à garder en tête
- **Koumbit** : juridiction **canadienne** (Five Eyes, hors UE) — à peser pour un réseau franco-brésilien soucieux de souveraineté ; **8 Go = leur maximum** (zéro marge pour grandir) ; prix en CAD.
- **Souveraineté UE en critère fort** → Koumbit sort ; le duo de tête redevient **Hetzner (fiabilité)** vs **clawd.fr (valeurs, mais solo)**.

## Recommandation
- **Fiabilité d'abord** → **Hetzner CAX21 (ARM, 8 Go, ~8 €)**.
- **Militant + assez robuste, si le Canada passe** → **Koumbit**.
- **Militant à tout prix, œil ouvert sur le bus-factor** → **clawd.fr** (CHATONS français) après confirmation Docker + 8 Go.

## Articulation avec Herbes Folles
Ce VPS **n'annule pas** le partenariat HF : HF reste le **dépôt de sauvegarde** (offsite, souverain,
déjà en place) et, s'ils le souhaitent, le **relais mail**. La contribution ~50 €/mois peut se répartir
(VPS + soutien HF). Avantage : l'**uptime de l'app ne dépend plus de la disponibilité bénévole** de personne.

## Le point qui ne change pas
Quel que soit l'hôte, **quelqu'un doit exploiter la pile dans la durée** (mises à jour, monitoring, test
de restauration mensuel #BG2). Sur un VPS loué, c'est **toi/l'équipe** — le « facteur limitant = maturité
opérationnelle » du mémo. À intégrer dans la décision au même titre que le prix.

## À demander aux 3 en lice (Koumbit / clawd / julienth37)
1. **VPS root avec Docker** — pile de ~10 conteneurs autorisée ?
2. **RAM/CPU/disque** — offre **≥ 8 Go / 4 vCPU / ~40-80 Go** ? à quel prix réel ?
3. **Continuité** — fiabilité infra, délai de support, et **que se passe-t-il si l'exploitant est indisponible / arrête** (admin de secours, chemin de sortie) ?
