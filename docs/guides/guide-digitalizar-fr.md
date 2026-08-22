# Fiche — Numériser un ouvrage

> **À qui s'adresse cette fiche.** À toi qui es devant le scanner. Elle tient en
> une page et ne contient que ce qui se décide au moment de scanner : les trois
> réglages, les cinq contrôles, et le sort des fichiers.
>
> Le *pourquoi* est ailleurs, dans la décision
> `DECISION_profil_numerisation_2026-08-20`. Ici, on fait.

## La règle, en une phrase

**On capture en niveaux de gris, on livre en bitonal, on ne garde en ligne que
ce qui est livré.**

---

## 1. Avant de scanner — qu'est-ce qu'on a le droit de numériser ?

| L'ouvrage est… | Ce que tu scannes |
|---|---|
| **dans le domaine public** | tout l'ouvrage |
| **cédé par l'auteur·rice**, ou sous **licence libre** | tout l'ouvrage |
| **sous droits** | **la couverture, et rien d'autre** |

Dans le doute, **la couverture seule**. On peut toujours numériser plus tard ;
retirer un fonds entier mis en ligne à tort, beaucoup moins facilement.

> **Écris pourquoi.** Au moment du versement, le champ de justification attend
> une phrase : nom de l'auteur·rice et date de mort, référence de la licence, ou
> lien vers la cession écrite. **C'est cette phrase qui protège la bibliothèque,
> pas la case cochée.** Si tu ne sais pas quoi y écrire, c'est que le statut
> n'est pas établi — mets `sob_direitos` et demande.

---

## 2. Les trois réglages

| Ce que tu as devant toi | Réglage |
|---|---|
| Texte imprimé ordinaire | **Niveaux de gris — 300 dpi** |
| Petits corps, notes, papier jauni ou abîmé | **Niveaux de gris — 400 dpi** |
| Gravures, affiches, tracts, presse illustrée, couvertures | **Couleur — 300 dpi** |

**Jamais en noir et blanc directement.** Le scanner te le proposera — c'est
souvent son réglage d'usine. Refuse. Le passage en noir et blanc est
irréversible : un gris devenu blanc ne revient pas, et sur du papier jauni il
emporte des pages entières, les tampons et les annotations manuscrites.

Le critère pour la couleur : **la matière est-elle elle-même le document ?** Une
affiche, oui. Un chapitre de texte, non.

---

## 3. Après la capture

Le PDF versé n'est pas la capture : il en est **dérivé**, page à page — texte en
bitonal, illustrations en gris ou en couleur. Un ouvrage de 200 pages
majoritairement textuel pèse alors 8 à 15 Mo.

> **La chaîne retenue : ScanTailor Advanced, puis `img2pdf`.** Le premier
> redresse, rogne et sépare le texte des illustrations, page par page ; le
> second assemble le résultat en PDF sans le ré-encoder.
>
> Prends bien **Advanced** : « ScanTailor » désigne aussi une version
> abandonnée, qui n'a pas le mode mixte dont on a besoin ici.
>
> **Les réglages précis arriveront dans cette fiche** une fois la chaîne
> éprouvée sur dix ouvrages. D'ici là, demande à ta bibliothèque — et dans tous
> les cas, ne verse jamais les captures brutes.

Deux champs à ne pas rater au versement :

- **Statut des droits** — une liste fermée de quatre choix : *Domaine public* ·
  *Cession de droits (autorisation écrite)* · *Licence libre (CC, copyleft…)* ·
  *Sous droits — couverture seule*. Rien d'autre n'est accepté, et le champ
  **Justification des droits** juste à côté attend ta phrase.
- **Accès** — deux choix : *Public* ou *Compte actif (restreint)*. Pour une œuvre
  libre, ce doit être **Public**. Le formulaire de catalogage le propose déjà sur
  *Public* : vérifie simplement qu'il y est resté. En revanche, une ressource
  créée **hors du formulaire** (import, versement automatique) arrive en *Compte
  actif* — exactement l'inverse de ce qu'on veut d'une œuvre du domaine public.
  Si tu passes par un import, contrôle ce champ après coup.

---

## 4. Les cinq contrôles

Sur **trois pages tirées au hasard**, à l'œil, avant de verser :

1. **Aucun caractère mangé** — y compris les accents et la ponctuation fine.
2. **Tampons, ex-libris et annotations manuscrites lisibles.**
3. **Les illustrations ne sont pas passées en noir et blanc** par erreur.
4. **La page est droite et complète** — pas de marge rognée, pas de reliure
   noire qui déborde.
5. **Le texte est sélectionnable** dans un lecteur PDF : la couche OCR est là.

**Un seul point qui échoue → on refait à partir de la capture.** C'est
précisément pour ça qu'on la garde jusqu'à validation.

---

## 5. Que deviennent les fichiers de capture ?

**Ils ne montent jamais sur le serveur.** Ils restent chez toi ou à la
bibliothèque, sur un disque externe, le temps de valider la livraison.

**Ensuite, on les efface.** C'est la règle du réseau : pas d'archivage
systématique des captures.

> **Ce que ça change pour toi.** Tant que la capture existe, une livraison
> ratée se refait en dix minutes. Une fois effacée, il faut ressortir l'ouvrage
> du rayon et le re-numériser page à page. **Les cinq contrôles ci-dessus sont
> donc ta dernière chance — fais-les avant d'effacer, pas après.**

**Une exception, à toi de la reconnaître** : un ouvrage rare, fragile ou unique,
qu'on ne pourrait pas re-numériser sans risque pour l'objet. Là, garde la
capture. La règle vise le tout-venant, pas l'irremplaçable.

---

## En une phrase

Scanne en gris, refuse le noir et blanc, vérifie trois pages, garde la capture
jusqu'à ce que le PDF soit validé. Le reste s'apprend en le faisant.

---

*Document du commun AnarBib. Les versions dans les autres langues sont
traduites depuis celle-ci pour qu'elles existent tout de suite, et corrigées
ensuite par les communautés de chaque langue. Une traduction imparfaite qui
existe peut être reprise ; une traduction absente ne peut rien être.*
