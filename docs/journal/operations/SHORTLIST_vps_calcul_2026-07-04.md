# SHORTLIST — VPS pour le calcul AnarBib (pile Supabase self-hosted)

> Branche « **le calcul ailleurs que chez HF** » de la
> [`DECISION_arbitrage`](../arbitrages/DECISION_arbitrage_migration_vps_2026-07-03.md) : un VPS **qu'on
> loue et administre**, HF gardant le rôle léger (sauvegarde + éventuel mail). Cible = faire tourner la
> pile Docker Supabase (cf. [`RUNBOOK_migration_vps`](RUNBOOK_migration_vps_2026-07-04.md)).
> Rédigé 2026-07-04, **enrichi** de fournisseurs militants proposés par Xavier.
>
> ⚠️ **Prix indicatifs** (ordre de grandeur, connaissance ~début 2026 + pages consultées le 2026-07-04)
> — **à revérifier** avant décision.
>
> ✅ **Revérifiés le 29/08/2026** (§ « Mise à jour »). Deux choses ont bougé : Hetzner a **augmenté ses
> tarifs le 15/06/2026** — le CAX21 n'est plus à 8 € — et le dimensionnement n'est plus une estimation,
> il est **mesuré**. Le cadrage de cette note (filtre root+Docker, bus-factor, juridiction,
> complémentarité avec HF) n'a pas bougé d'un pouce et reste ce qu'il faut lire en premier.

## Dimensionnement cible
- **RAM : 8 Go** (la pile ≈ 10 conteneurs veut 4 Go minimum, 8 Go pour respirer). Poste décisif.
- **vCPU : 4. Disque : 40–80 Go SSD/NVMe.** IP fixe + reverse DNS, SSH clé.

> **Mesuré depuis (29/08/2026), et la cible tient — pour de meilleures raisons.** La pile fait **six**
> conteneurs, pas dix : ni temps réel, ni transformation d'images (corrigée le 26/08, vignettes
> pré-générées), ni relais SMTP. Elle consomme **358 Mo au repos** et porte des plafonds mémoire
> explicites totalisant **3,4 Go**. Donc 4 Go *tiennent* — mais ne laissent aucune marge si tous les
> plafonds sont atteints ensemble, et l'écart 4 → 8 Go coûte **3 €/mois** chez un loueur. Sur une
> machine louée, l'arbitrage n'a pas lieu d'être : 8 Go, sans discussion.
>
> **Le disque, lui, a changé de nature.** La note de juillet le traitait comme négligeable (~500 Mo).
> Le rechiffrage du 20/08 a supprimé le palier : l'éligibilité à la numérisation intégrale porte sur
> **tout le fonds** (zéro ouvrage sans bibliothèque détentrice), pas sur le seul domaine public. Base +
> fichiers = ~600 Mo aujourd'hui (156 Mo + 453 Mo au 28/08), mais la pente est de **2 à 12 Go/an** selon
> le nombre de bibliothèques qui numérisent, sans maximum connu dans l'horizon considéré. Compter
> **~10 Go** de système et d'images Docker, **40 Go** confortables aujourd'hui, **80 Go** à cinq ans —
> ou 40 Go plus du **stockage objet** pour les scans, qui sont écrits une fois et lus rarement
> (0,008–0,016 €/Go/mois selon la redondance : 50 Go de scans = moins d'un euro par mois).
> **À demander à chaque hébergeur en lice**, au même titre que le root+Docker.

## Le filtre qui élimine la moitié du champ militant
Supabase self-hosted **exige un VPS root où l'on installe son propre Docker**. Or beaucoup
d'hébergeurs éthiques ne font que du **managé d'applications** (Nextcloud, YunoHost, LAMP) — pratique
pour du collaboratif, **inadapté** pour une pile Docker qu'on pilote. D'où la colonne « **Root+Docker ?** ».

## Comparatif

| Fournisseur | Pays | Offre ~8 Go / prix mensuel | Root+Docker ? | Valeurs | Robustesse |
|---|---|---|---|---|---|
| **Hetzner** | 🇩🇪 DE | ~~CAX21 ARM ~8 €~~ → **CX33 x86 4c/8 Go/80 Go 8,49 €** ; CAX21 ARM 10,49 € *(tarifs 29/08)* | ✅ | neutre commercial, énergie verte revendiquée | ✅✅ établi |
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

## Mise à jour du 29/08/2026 — ce qui a bougé, ce qui n'a pas bougé

**Hetzner a augmenté le 15/06/2026.** Les hausses sont très inégales selon les gammes, et elles
déplacent la recommandation à l'intérieur de la marque : CAX21 (ARM) 7,99 → **10,49 €**, CX23 3,99 →
5,49 €, CX33 6,49 → **8,49 €**, et les CPX ont pris de 144 à 172 % (CPX32 13,99 → 35,49 €). Le meilleur
rapport pour notre cible n'est donc plus l'ARM mais le **CX33 x86 — 4 vCPU / 8 Go / 80 Go / 20 To de
trafic, 8,49 € HT**, qui couvre l'horizon cinq ans disque compris.

**Les autres prix de la table datent toujours du 04/07** et n'ont pas été revérifiés : les traiter comme
des ordres de grandeur, pas comme des devis. Le seul qui compte vraiment est celui que les trois en
lice répondront eux-mêmes.

**Ce qui ne bouge pas** : le filtre root+Docker, le bus-factor, la juridiction, et l'articulation avec
Herbes Folles. Ce cadrage-là a tenu deux mois sans une ride.

**Ce que le contexte a ajouté depuis** : la caisse existe (Liberapay en ligne, premier don reçu le
27/08), donc un VPS a désormais une ligne budgétaire identifiable — ce qui n'était pas vrai en juillet.
Et le point de comparaison est net : la configuration confortable coûte **8 à 11 €/mois**, soit le
cinquième des ~50 €/mois déjà proposés à HF. **L'argent n'est pas le critère** — ce qui se décide ici,
c'est chez qui les données vivent et qui peut les relever à 3 h du matin.

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
