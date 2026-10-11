# Réimporter son catalogue PMB — le premier réimport

*Pour la coordination d'une bibliothèque qui a déjà importé son catalogue PMB dans AnarBib et qui dépose un nouvel export (H21, 11/10/2026). Éprouvé de bout en bout sur des exports produits par PMB 8.1 lui-même : `tests/sql/h21_bout_en_bout_tests.sql`.*

Un réimport ne recrée rien de ce qui est déjà là : il **reconnaît** chaque notice et chaque exemplaire, **montre** ce que PMB a changé depuis l'import précédent, et te laisse décider. Rien n'est écrit au catalogue sans passer par la révision du lot.

## 1. Avant de déposer

- **Le même PMB, la même source.** Dépose le fichier depuis **Importations**, avec la source de ton catalogue propre — celle du premier import. C'est par elle qu'AnarBib reconnaît tes notices (le numéro de notice PMB, 001) et tes exemplaires (le code-barres, 995 $f, et l'identifiant interne de PMB, 996 $9).
- **L'export de PMB tel quel.** Administration > Import/Export > Export, format **UNIMARC ISO2709**, exemplaires inclus. Ne retouche pas le fichier.
- **« Ce fichier est un export complet de mon catalogue ».** Coche-la **seulement** si l'export contient tous tes exemplaires, sans filtre (ni par section, ni par statut, ni par localisation). Sans elle, aucun retrait n'est proposé. Elle ne se change plus après l'envoi : dans le doute, ne coche pas.

## 2. Ce que montre chaque verdict

**La ligne** (colonne Correspondance) :
- « Déjà importée » : la notice est reconnue. « Notice plus détenue par ta bibliothèque » : elle a été réattribuée ou ton fonds n'existe plus — rejette la ligne si tu ne veux pas la reprendre.
- « Nouveauté » : une notice que PMB a créée depuis le premier import.
- Une notice absente du fichier n'est jamais supprimée d'AnarBib.

**Les champs** (« Voir le détail champ par champ » : ce qu'avait l'import précédent / ce qu'a AnarBib / ce que dit le fichier) :
- « Changé dans le fichier seulement » : « Préparer la mise à jour » le reprendra.
- « Changé dans AnarBib seulement (gardé) » : ta retouche reste.
- « Conflit (signalé, jamais appliqué) » : changé des deux côtés ; la valeur d'AnarBib reste, à toi de trancher à la main.
- « Effacé par la source (montré, jamais appliqué) » : un champ que PMB a vidé n'est jamais vidé dans AnarBib.
- Les responsabilités changées sont montrées, jamais appliquées.

**Les exemplaires du fichier** :
- « nouveau » : un brouillon d'exemplaire ; « déjà là » : rien à faire.
- « sans code-barres », « déplacé dans PMB… », « réétiqueté dans PMB… », « code repris… » : signalés, **rien n'est changé** — à vérifier et, s'il le faut, à corriger à la main.
- « parti chez … » : l'exemplaire a été réattribué à une autre bibliothèque du réseau (il y garde son code et son identifiant PMB) ; AnarBib ne le recrée jamais chez toi, ne le met pas à jour, ne le retire pas. Une ligne dont tous les exemplaires sont déjà là ou partis ailleurs n'apporte rien : « Rapprocher » la rejette d'office.
- La cote et la note se comparent comme les champs d'une notice.

**Les retraits** (« Exemplaires sortis du fichier ») :
- « disparu du fichier » : proposable au retrait ; « disparu mais engagé » (en prêt, réservé, en prêt entre bibliothèques, en consultation) : jamais proposé ; « disparu, un brouillon en cours » : attend le brouillon.
- Les exemplaires d'une notice absente du fichier sont comptés à part, jamais proposés.
- **Le seuil** : plus de 10 % des exemplaires de la source ET au moins 20 disparus — rien n'est proposé tant que tu n'as pas confirmé « c'est bien un export complet ». Un export tronqué se voit ainsi avant de coûter quoi que ce soit.
- « retiré, réapparu : levée » : un exemplaire retiré revenu dans PMB.

**Les notices partagées** avec une autre bibliothèque ne sont jamais réécrites par un réimport : chaque changement du fichier devient une **divergence**, que chaque bibliothèque qui détient la notice voit au **Catalogage** (« Divergences à traiter ») et qu'elle applique ou écarte, champ par champ.

## 3. L'ordre des gestes

À l'ouverture du run, la comparaison se calcule. Coche ensuite les lignes et :

1. **Rapprocher** les lignes « Déjà importée » : les exemplaires « nouveau » deviennent des brouillons ; une ligne qui n'apporte rien est rejetée d'office.
2. **Créer** les brouillons des « Nouveauté ».
3. **Préparer la mise à jour** : un brouillon par notice que ta bibliothèque est seule à détenir, avec les seuls champs changés dans le fichier ; un brouillon par exemplaire dont la cote ou la note a changé dans le fichier.
4. **Proposer les retraits** (et les levées), depuis le panneau des retraits.
5. **Rejeter** ce que tu ne reprends pas.

Tous ces brouillons vont dans **un seul lot**, celui du run. Demande ensuite sa révision.

## 4. Ce qui passe en révision

Tout : les notices nouvelles et leurs exemplaires, les exemplaires ajoutés, les mises à jour de notices et d'exemplaires, les retraits et les levées. L'administration du réseau approuve ; tu publies le lot. Le rapport de révision dit ce qui est appliqué, ce qui est seulement montré, les exemplaires écartés et pourquoi, les disparus engagés et le seuil.

## 5. Ce qui n'est jamais automatique

- Aucune notice, aucun exemplaire n'est **supprimé** : un retrait (« sorti du catalogue d'origine ») est réversible et passe par la révision.
- Aucun **conflit** n'est écrasé ; aucun effacement, aucune responsabilité n'est appliqué.
- Une notice **partagée** n'est jamais réécrite.
- Un exemplaire **en prêt, réservé ou en consultation** n'est jamais proposé au retrait ; la circulation n'est jamais touchée.
- Un exemplaire **déplacé, réétiqueté, sans code ou au code repris** n'est jamais modifié.
- Un exemplaire **parti chez une autre bibliothèque** n'est jamais recréé chez toi.
- Réimporter le même fichier une seconde fois ne crée rien de nouveau : seuls les signaux déjà vus reviennent.

La version en portugais du Brésil : [guide-reimport-pmb-pt-BR.md](guide-reimport-pmb-pt-BR.md).
