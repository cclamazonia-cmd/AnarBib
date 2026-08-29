# Message de qualification — hébergeurs VPS (Koumbit / clawd / julienth37)

> Modèle prêt à envoyer, **à adapter** au destinataire (ton + salutation). Rédigé 2026-07-04.
> But : vérifier que l'hébergeur peut faire tourner la pile (Docker + 8 Go) et connaître le prix + la
> continuité. Cf. [`SHORTLIST_vps_calcul`](SHORTLIST_vps_calcul_2026-07-04.md). **Pas encore envoyé.**
>
> ⚠️ **Corrigé le 29/08/2026, avant envoi.** Deux points du dimensionnement étaient périmés et
> partaient dans le mauvais sens : la pile fait **six** conteneurs et non dix, et surtout la phrase
> « les données sont légères — ~500 Mo — c'est la RAM qui compte » **n'est plus vraie**. Le rechiffrage
> du 20/08 a supprimé le palier de croissance du disque ; c'est exactement l'erreur déjà rectifiée
> auprès de Herbes Folles, il aurait été fâcheux de la répéter à trois autres hébergeurs. Question 2
> réécrite en conséquence.

---

Objet : **Hébergement d'une petite application web (pile Docker) — quelques questions**

Bonjour, *(clawd / julienth37 : « Salut les camarades, »)*

Nous cherchons un hébergement pour **AnarBib**, une application web **libre** au service d'un réseau de
bibliothèques libertaires (catalogue, prêts, adhésions). Nous voulons quitter notre hébergeur actuel
(états-unien) pour une infra plus **souveraine** et alignée avec nos valeurs — votre projet nous a paru
y correspondre.

Nous **administrons nous-mêmes** l'application : on cherche donc un **VPS qu'on gère** (vous fournissez la
machine, nous installons et maintenons la pile). Quelques questions pour savoir si c'est faisable chez vous :

1. **VPS root + Docker** — peut-on disposer d'un **accès root** et y faire tourner une **pile Docker de
   six conteneurs** (Supabase auto-hébergé) ?
2. **Dimensionnement** — proposez-vous une config autour de **8 Go de RAM / 4 vCPU / 40 Go de disque**,
   et à quel **tarif mensuel** ? *(La mémoire est mesurée : 358 Mo au repos, 3,4 Go de plafonds.)*
   **Sur le disque, nous préférons être clairs tout de suite** : la base et les fichiers ne pèsent
   aujourd'hui que ~600 Mo, mais nous numérisons progressivement les fonds des bibliothèques du réseau,
   à un rythme de **2 à 12 Go par an** selon le nombre de collectifs équipés. Nous cherchons donc un
   hébergement où l'espace **peut continuer à croître** — de l'ordre de 50 Go d'ici trois à cinq ans.
   Est-ce que cela vous va, et qu'est-ce que ça change pour vous ? Proposez-vous par ailleurs du
   **stockage objet séparé de la VM** ? Les numérisations s'y prêtent bien : écrites une fois, lues
   rarement.
3. **Continuité** — comment se passe le **support**, et, question importante et bienveillante : que se
   passe-t-il si vous êtes **indisponible** ou si vous **arrêtez l'activité** (astreinte, admin de secours,
   possibilité de récupérer/migrer facilement nos données) ?
4. **Accès & sauvegarde** — acceptez-vous une **clé SSH** pour l'accès, et proposez-vous des
   **snapshots/sauvegardes** côté hébergeur ? *(On gère par ailleurs nos propres sauvegardes.)*

Nous pouvons bien sûr **contribuer financièrement** à hauteur de ce que ça représente pour vous.

Merci d'avance, et bravo pour ce que vous faites.

*(AnarBib)*

---

### Aide-mémoire interne (ne pas envoyer)
- **Koumbit** : ton pro/coopératif ; leur plafond est 8 Go (leur offre « Gordo ») → demander s'il y a
  au-dessus, et acter la juridiction canadienne. Prix ~120 $CAD/mo + setup à confirmer.
- **clawd.fr** : ton camarade ; prix libre → leur demander une estimation pour cette VM précise ; ils sont
  solo (entreprise individuelle) → la Q3 (continuité) est la plus importante ici.
- **julienth37 / A-Hébergement** : ton camarade ; VPS KVM (Docker OK), mais **demander la localisation**
  (non affichée), la capacité réelle 8 Go, et la continuité (structure très petite).
- Filtre décisif = Q1+Q2 (root+Docker+8 Go). Si « non » → hors jeu, on remercie et on passe.
