# DECISION — Profil de numérisation du réseau AnarBib

> **Pourquoi ce document existe.** Le même corpus pèse **11 Go ou 200 Go** selon
> le profil de numérisation retenu — un facteur vingt. Et le réglage par défaut
> de tous les scanners du commerce est la couleur. Sans règle écrite, la
> première personne équipée scannera en couleur, et à cinq cents ouvrages on ne
> revient pas en arrière sans tout refaire.
>
> Rédigé le 2026-08-20, en préparation de l'appel Herbes Folles. Chiffrage :
> [`CHANTIER_hebergement_souverainete`](../../../docs/journal/) §5.
> Aucun scanner n'est encore en service dans le réseau : **c'est le bon moment.**

## La règle, en une phrase

**On capture en niveaux de gris, on livre en bitonal, on ne garde en ligne que
ce qui est livré.**

---

## 1. Ce qu'on numérise, et ce qu'on ne numérise pas

| Statut de l'ouvrage | Ce qui est versé |
|---|---|
| **Domaine public** | Numérisation intégrale, accès public |
| **Droits cédés par l'auteur·rice** | Numérisation intégrale, accès selon la cession |
| **Sous droits** | **La couverture seule**, rien d'autre |

Sur ~9000 ouvrages du réseau, on estime **10 à 25 %** dans le domaine public.
Le reste ne reçoit qu'une couverture — quelques centaines de kilo-octets par
notice, soit ~2 Go pour la totalité du fonds.

### Le vocabulaire des droits doit être contrôlé — dès maintenant

`book_digital_resources.rights_status` est aujourd'hui un **champ texte libre**.
Sur dix-huit ressources déjà versées, il porte **trois graphies** :

```
Domínio público                  7
livre_de_direitos               10
Direitos concedidos pelo autor   1
```

Deux concepts, trois écritures, et pas de langue commune. À dix-huit c'est sans
conséquence ; à mille cinq cents, aucun filtre, aucun export et aucune
vérification juridique ne sera fiable. **À figer avant la première campagne** —
quatre valeurs suffisent :

| Valeur | Sens |
|---|---|
| `dominio_publico` | Durée de protection expirée |
| `cessao_autoral` | Cession écrite obtenue, à joindre au dossier |
| `licenca_livre` | Publié sous licence libre (CC, copyleft…) |
| `sob_direitos` | Sous droits — couverture seule |

Et une colonne libre séparée pour la **justification** (nom, date de mort,
référence de la licence, lien vers la cession).

> ⚠️ **Ceci n'est pas un avis juridique.** Au Brésil, la durée de protection est
> de 70 ans après la mort de l'auteur·rice (loi 9.610/1998) ; la règle diffère
> selon les pays, et les œuvres anonymes, collectives, posthumes ou traduites
> ont leurs propres régimes — une traduction porte ses propres droits, même si
> l'original est libre. **Chaque bibliothèque tranche pour son fonds**, et écrit
> pourquoi. C'est la justification écrite qui protège, pas le classement.

---

## 2. La capture — en niveaux de gris, jamais en bitonal

**On ne scanne jamais directement en noir et blanc.** Le seuillage est
destructeur et irréversible : une fois qu'un gris est devenu blanc, il ne
revient pas. Un mauvais seuil mange les caractères fins, les tampons, les
annotations manuscrites — et sur du papier jauni, ce qui arrive souvent, il
mange des pages entières.

| Cas | Réglage de capture |
|---|---|
| Texte imprimé ordinaire | **Niveaux de gris, 300 dpi** |
| Petits corps, notes, papier abîmé | **Niveaux de gris, 400 dpi** |
| Gravures, affiches, tracts, presse illustrée, couvertures | **Couleur, 300 dpi** |

Le critère pour la couleur : **la matière est-elle elle-même le document ?**
Une affiche, oui. Un chapitre de texte, non.

---

## 3. La livraison — bitonal pour le texte, gris ou couleur pour le reste

Le PDF versé dans AnarBib est **dérivé** de la capture, page par page :

- **page de texte pur** → bitonal, compression **CCITT G4** ou **JBIG2**,
  ~30 à 60 ko la page ;
- **page illustrée** → on conserve les niveaux de gris ou la couleur,
  ~200 ko à 1 Mo la page.

Un ouvrage de 200 pages majoritairement textuel pèse ainsi **8 à 15 Mo**.
C'est ce que font les grandes bibliothèques numériques, et c'est parfaitement
lisible à l'écran comme à l'impression.

---

## 4. Ce qu'on garde, et ce qu'on ne met pas en ligne

C'est la question qui décide du coût réel.

- **Le PDF livré** part sur le serveur. C'est lui, et lui seul, qui compte dans
  le dimensionnement de l'hébergement.
- **Les images de capture** (les gris à 300 dpi) **ne montent pas sur le
  serveur.** Elles restent chez la bibliothèque, sur un disque externe, le temps
  de valider la livraison — puis au choix : archivées hors ligne, ou effacées.

Les conserver en ligne multiplierait le coût par six sans bénéfice pour qui
consulte. Une bibliothèque qui tient à garder ses fichiers de capture le fait
chez elle, à sa charge : c'est un choix légitime, mais qui n'engage pas
l'hébergement du réseau.

---

## 5. La couche de texte (OCR)

L'OCR tourne **dans le navigateur**, via `tesseract.js` déjà vendorisé
(`public/vendor/tesseract/`). Il ne coûte rien au serveur, et aucun document ne
sort du poste de la personne qui numérise — ce qui est cohérent avec la doctrine
anti-pistage.

La couche de texte ajoute **quelques pour cent** au poids du PDF. Elle est
indispensable : sans elle, un document numérisé n'est pas cherchable, et un
fonds qu'on ne peut pas fouiller n'est consulté par personne.

L'OCR sur du bitonal bien seuillé donne d'aussi bons résultats que sur du gris.
Ce n'est donc pas un argument pour alourdir la livraison.

---

## 6. Où ça atterrit dans AnarBib

| Champ | Domaine public | Sous droits |
|---|---|---|
| `storage_bucket` | `anarbib-pdf-public` | `covers` (couverture seule) |
| `resource_type` | `pdf_publico` | — |
| `access_scope` | `publico` | — |
| `rights_status` | `dominio_publico` / `cessao_autoral` / `licenca_livre` | `sob_direitos` |
| `mime_type` | `application/pdf` | — |

Rappel : `access_scope` vaut `conta_ativa` **par défaut** en base. Pour un
document du domaine public, il faut le poser explicitement à `publico`, sinon il
reste réservé aux comptes actifs — ce qui n'a aucun sens pour une œuvre libre,
et prive le catalogue public de ce qu'il a de plus précieux à montrer.

---

## 7. Contrôle avant versement

Cinq points, à l'œil, sur trois pages tirées au hasard :

1. Aucun caractère mangé par le seuillage, y compris les accents et la
   ponctuation fine.
2. Les tampons, ex-libris et annotations manuscrites sont lisibles.
3. Les illustrations n'ont pas été passées en bitonal par erreur.
4. La page est droite et complète — pas de marge rognée, pas de reliure noire
   qui déborde.
5. Le texte est sélectionnable dans un lecteur PDF (la couche OCR est là).

Si un seul de ces points échoue, **on refait à partir de la capture** — c'est
précisément pour ça qu'on la garde jusqu'à validation.

---

## 8. Ce que ça pèse, et ce qu'on a annoncé

| Poste | Volume |
|---|---|
| Numérisation du domaine public (900 à 2250 ouvrages) | **11 à 27 Go** |
| Couvertures de tout le reste du fonds | ~2 Go |
| Base et fichiers actuels | 450 Mo |
| **Plafond, marge comprise** | **~30 Go** |

**La pente** : elle est bornée par la vitesse de numérisation humaine, pas par
la taille des fonds. Une personne assidue traite un ouvrage par jour ouvré, soit
**~3 Go par an**. Trois bibliothèques équipées, une dizaine de Go par an. Trois
à cinq ans pour atteindre le plafond.

Annoncé à Herbes Folles le 20/08 : **20 Go pour démarrer, jusqu'à 50 Go sur
trois à cinq ans.**

---

## 9. Ce qui reste à décider

- [x] **Figer le vocabulaire de `rights_status`** et migrer les ressources
      existantes. ✅ Fait le 20/08 — migration `20260820235000`, liste fermée à
      quatre valeurs, colonne de justification, liste fermée au formulaire.
      Vérifié en production : **44 lignes** normalisées sur les deux tables
      (18 + 26 — il y en avait plus que les dix-huit annoncées, les brouillons
      comptent aussi), marqueur « a verificar » posé sur les **28** ambiguës.
- [x] **Choisir l'outil de dérivation** (capture gris → PDF bitonal mixte).
      ✅ Tranché le 20/08 : **ScanTailor Advanced**, puis **`img2pdf`**.

      *Le nom du fork compte.* « ScanTailor » désigne trois logiciels :
      l'original, abandonné ; **Advanced**, le fork vivant, seul à porter le
      mode de sortie **mixte** (texte bitonal et illustrations en gris dans la
      même page) ; et *Universal*, un autre fork. C'est *Advanced* qui est
      retenu — écrire « ScanTailor » tout court garantit que quelqu'un
      installera l'abandonné.

      *Pourquoi cette chaîne.* ScanTailor Advanced couvre la géométrie et la
      segmentation avec une interface graphique montrable à une personne
      bénévole ; `img2pdf` assemble ses sorties **sans les ré-encoder**, donc
      sans perte ajoutée. `unpaper` et ImageMagick ne segmentent pas — il
      faudrait écrire soi-même la logique texte/illustration.

      *Ce qui est écarté, et pourquoi.* **OCRmyPDF** serait le candidat
      naturel, mais il refait l'OCR que §5 confie déjà au navigateur : doublon
      de traitement, et sortie du modèle « rien ne quitte le poste ».

      ⚠️ *Une contrainte de compression, pas de confort.* **Le mode « lossy »
      de JBIG2 est à proscrire.** Il compresse en repérant des glyphes
      semblables et en n'en gardant qu'un exemplaire — et il lui arrive de
      confondre deux caractères et de les **remplacer** l'un par l'autre. C'est
      le défaut qui a fait scandale sur des photocopieurs Xerox en 2013, des
      chiffres changeant silencieusement dans des documents scannés. Sur un
      fonds militant où les dates et les noms font la valeur du document, un
      fichier qui ment sans prévenir est pire qu'un fichier lourd.
      **CCITT G4, ou JBIG2 générique sans appariement de symboles.**
      (Le lecteur d'AnarBib sait décoder le JBIG2 : `public/vendor/pdfjs/web/wasm/jbig2.wasm`.)

      **Reste l'épreuve sur dix ouvrages** — elle ne remet plus le choix en
      cause, elle fixe les réglages et vérifie le seul point non acquis : que
      la sortie mixte, assemblée, tienne les 8 à 15 Mo du §3 sans abîmer le
      texte. C'est de ce chiffre que dépend tout le dimensionnement du §8.
- [x] **Écrire la fiche pratique d'une page** pour les personnes qui scannent.
      ✅ Fait le 20/08 — `docs/guides/guide-digitalizar-fr.md` et `-pt-BR.md`,
      exposée dans les Communs de l'app (carte « Numériser un ouvrage »), les
      huit autres langues retombant sur le fr. La chaîne de dérivation y est
      laissée **en réservé** tant que l'outil n'est pas choisi : la fiche
      renvoie à la bibliothèque plutôt que de recommander une commande que
      personne n'a éprouvée.
- [ ] **Trancher le sort des captures** : archivage hors ligne systématique, ou
      effacement après validation ? La question appartient à chaque
      bibliothèque, mais la réponse doit être écrite quelque part.
