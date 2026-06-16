# Guide — Scan et QR Code dans AnarBib

> **À qui s'adresse ce guide.** À toute camarade de bibliothèque qui veut utiliser
> l'appareil photo de son téléphone (ou de son ordinateur) pour gagner du temps :
> identifier un·e lecteur·rice par sa carte, récupérer les données d'un livre via
> son code-barres, ou vérifier le fonds. Rédigé à la demande — et pour le **commun**
> du réseau.
>
> **Esprit.** Rien ici ne te surveille ni ne t'évalue. La lecture des codes se fait
> **100 % sur ton appareil** : aucune image de la caméra ne sort de chez toi. Ces
> outils sont là pour te donner de l'autonomie, pas pour t'enchaîner. Si quelque
> chose ne fonctionne pas, **le catalogue n'est jamais abîmé** — dans le pire des
> cas, il suffit de saisir à la main.
>
> Partie du **commun de savoirs** de l'entraide (voir le cadrage « l'entraide au
> catalogage »). Ce guide est écrit par la communauté linguistique : si tu veux une
> version dans une autre langue, elle se construit en parallèle, pas par traduction
> descendante.

---

## Ce que l'on peut scanner

AnarBib dispose d'**un seul lecteur de caméra**, réutilisé à trois endroits :

| Où | Ce que l'on scanne | Pour quoi faire |
|---|---|---|
| **Tableau de bord › Gérer lecteur·rice** | QR de la **carte de lecteur·rice** | Identifier la personne en un instant |
| **Catalogage** (fiche du livre) | **code-barres ISBN** | Récupérer titre/auteur·rice automatiquement |
| **Tableau de bord › Inventaire** | QR des **étiquettes d'exemplaire** | Vérifier le fonds (récolement) |

Dans tous les cas : la caméra s'ouvre dans AnarBib, lit le code, et c'est tout. Pas
besoin d'installer la moindre application. Si tu le souhaites, tu peux **ajouter
AnarBib à l'écran d'accueil** de ton téléphone (menu du navigateur › « Ajouter à
l'écran d'accueil ») : il s'ouvre en plein écran comme une appli, tout en restant
le site.

---

## 1. Carte de lecteur·rice

**Qui crée la carte :** le·la lecteur·rice lui-même·elle-même, depuis son compte
(`/conta`), dès lors que la bibliothèque a activé la fonctionnalité. Il·elle génère
un QR Code et peut le télécharger en PNG ou en PDF. Le QR ne contient qu'un
**code opaque** — aucun nom, aucune donnée personnelle à l'intérieur.

**Comment tu l'utilises, au comptoir :**

1. Va dans **Tableau de bord › Gérer lecteur·rice**.
2. Clique sur **« Scanner la carte »** et pointe la caméra vers le QR de la carte.
3. AnarBib résout le code et affiche **qui est** la personne (et si une restriction
   est active). Prêt·e à prêter, à retourner un ouvrage, etc.

> **« Carte non reconnue » ?** C'est presque toujours une **ancienne carte**.
> Lorsqu'une personne génère une nouvelle carte, la précédente est **révoquée**
> (mesure de sécurité). Demande-lui de générer/télécharger sa carte actuelle.
> Depuis le 15/06, le système lui-même affiche « carte remplacée, veuillez en générer
> une nouvelle » dans ce cas.

---

## 2. Scanner l'ISBN lors du catalogage

Quand tu enregistres un livre qui possède un code-barres (ISBN), tu peux éviter de
tout saisir à la main :

1. Dans la fiche du livre (catalogage), ouvre le panneau de **recherche de
   métadonnées**.
2. Clique sur **« Scanner l'ISBN »** et pointe vers le **code-barres** situé en
   quatrième de couverture.
3. Le numéro s'inscrit tout seul dans le champ ISBN et AnarBib **récupère les
   données** (titre, auteur·rice…) depuis les sources publiques. Tu vérifies et
   ajustes — le catalogue est le tien.

> **Conseil matériel.** Le code-barres est plus « exigeant » que le QR. **Le
> téléphone lit généralement bien mieux** que la webcam d'un ordinateur de bureau
> (mise au point et résolution). Si la webcam ne capte pas, n'insiste pas : saisis
> l'ISBN à la main — ça revient au même.

---

## 3. Inventaire du fonds (récolement)

Vérifier, exemplaire par exemplaire, ce qui se trouve réellement en rayon —
en comparant avec ce que le système croit que la bibliothèque possède.

**Avant de commencer :** les étiquettes des exemplaires doivent comporter un **QR
Code**. Imprime les étiquettes avec QR depuis **Catalogage › Étiquettes** (une
option « Inclure les QR codes » est disponible). Chaque QR pointe vers l'exemplaire.

**Déroulement de l'inventaire :**

1. Va dans **Tableau de bord › Inventaire** (visible pour les rôles *librarian* et
   *coordinateur·rice*).
2. **« Démarrer un récolement »** — ouvre une session et affiche le nombre
   d'exemplaires que la bibliothèque possède.
3. La caméra reste ouverte : **passe les exemplaires les uns après les autres**, QR
   après QR. À chaque lecture, un **bip** retentit et le compteur monte. Inutile de
   fermer et rouvrir la caméra entre deux livres.
   - ✓ vert = exemplaire du fonds, comptabilisé.
   - « Déjà lu » = tu l'avais déjà passé (sans souci, il n'est pas compté deux fois).
   - ⚠ « Hors fonds » = un exemplaire qui **n'appartient pas** à cette bibliothèque
     (intrus).
4. Si un QR est abîmé, tu peux **saisir à la main** (URL de l'étiquette ou numéro
   de l'exemplaire).
5. **« Terminer et voir le rapport »** — ferme la session et affiche :
   - **Présents** (scannés et appartenant au fonds),
   - **Manquants** (au fonds, mais non scannés → à rechercher / à désaffecter),
   - **Intrus** (scannés, mais d'une autre bibliothèque / inconnus).
6. Exporte le résultat en **CSV** (pour tableur) ou en **PDF** (pour imprimer la
   liste des manquants et partir les chercher dans les rayons).

> **Mettre en pause et reprendre.** Grand inventaire ? Tu peux t'arrêter en chemin.
> Si tu quittes en cours de route, la session reste **en cours** et apparaît dans
> « Sessions en cours » pour **reprendre** là où tu t'es arrêté·e.

---

## Questions pratiques

**Dois-je installer quelque chose ?** Non. C'est le site lui-même. En option,
« Ajouter à l'écran d'accueil » pour l'ouvrir comme une appli.

**Ça fonctionne dans mon navigateur ?** Oui. Sous Chrome/Android, AnarBib utilise
le lecteur natif (plus rapide). Sous **Brave**, **iOS/Safari** et **Firefox**, il
charge automatiquement un lecteur alternatif — donc **ça fonctionne aussi** sur ces
navigateurs. Si un message « lecture incompatible » apparaît lors du scan d'un ISBN,
rafraîchis la page : le lecteur alternatif se charge tout seul.

**La caméra ne s'ouvre pas.** Vérifie si tu as accordé la **permission d'accès à la
caméra** au site (cadenas dans la barre d'adresse). Le navigateur ne libère la
caméra qu'en **HTTPS** — `app.anarbib.org` l'est déjà.

**Vie privée.** Le décodage est **local**. L'image de la caméra **n'est envoyée à
aucun serveur**. Le QR de la carte ne contient qu'un code opaque ; le QR de
l'étiquette ne contient que l'adresse de l'exemplaire. Les fonds sensibles (BTL et
assimilés) restent protégés par les mêmes règles qu'à l'ordinaire.

---

## En une phrase

La caméra est **une main tendue** pour t'épargner la saisie et la vérification —
pas une obligation. Utilise-la quand elle t'aide ; ignore-la quand elle ne sert à
rien. Et si ça coince, le clavier est toujours là.

---

*Document du commun AnarBib. Améliorations et versions dans d'autres langues sont
les bienvenues, rédigées en parallèle par la communauté de chaque langue.*
