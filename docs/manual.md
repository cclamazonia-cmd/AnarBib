# AnarBib — Manuel d'utilisation
## Réseau de bibliothèques libertaires

*Version 1.1 — Septembre 2026*

---

## 1. Premiers pas

### Se connecter
Rendez-vous sur l'URL de votre instance AnarBib et cliquez sur **Entrar** (ou le bouton de connexion dans la langue de votre interface). Saisissez votre e-mail et votre mot de passe.

### Changer la langue
Le sélecteur de langue se trouve en haut à droite de chaque page (🇧🇷🇵🇹 / 🇫🇷 / 🇪🇸 / 🇬🇧 / 🇮🇹 / 🇩🇪 / 🇳🇱 / 🇬🇷 / Català / Esperanto). Le choix est sauvegardé localement.

### Chercher dans le catalogue
Le **Catalogue** présente une ligne par œuvre, dans la langue de votre interface quand le titre a été traduit : l'auteur·rice, le titre, le nombre d'éditions et les bibliothèques qui la détiennent.
1. Cliquez sur **Voir les éditions** (le « + » de la ligne) : chaque édition apparaît en dessous, avec sa vignette, son éditeur et son année. Les tomes d'une œuvre en plusieurs volumes sont numérotés et triés.
2. Cliquez sur **Exemplaires par bibliothèque** : la disponibilité s'affiche bibliothèque par bibliothèque. Si vous êtes connecté·e, « votre bibliothèque » est signalée ; ce qui est disponible ailleurs mais pas pour vous est dit tel quel.
3. Le bouton **Liste plate** revient à une ligne par édition ; le choix est mémorisé.

---

## 2. Lecteur·rice — Mon compte

### Réserver un document
1. Cherchez le document dans le **Catalogue**
2. Cliquez sur sa fiche
3. Si le document est disponible, cliquez sur **Réserver un emprunt**
4. Vous pouvez aussi aller dans l'onglet **Réservations** de votre compte et saisir la référence locale

### Suivre ses emprunts
L'onglet **Emprunts en cours** affiche vos emprunts actifs avec :
- La date de sortie et l'échéance
- Un bouton **Renouveler** (si le renouvellement est autorisé)
- L'indication de retard éventuel

### Renouveler un emprunt
Cliquez sur **Renouveler** dans la liste de vos emprunts. Le renouvellement peut être refusé si :
- L'emprunt a déjà été renouvelé une fois
- L'emprunt est en retard
- Un·e autre lecteur·rice a réservé le même document

### Bandeau d'état du compte
En haut de la page **Mon compte**, un bandeau coloré indique l'état de votre compte :
- ✓ **Vert** : Compte actif, tout va bien
- ⚠ **Orange** : Attention (emprunt en retard, mot de passe à changer)
- ⛔ **Rouge** : Compte restreint (contactez votre bibliothèque)

### Historique
L'onglet **Historique** liste vos anciennes réservations et emprunts. Vous pouvez cliquer sur le titre pour voir la fiche du document, et **Masquer** les entrées que vous ne souhaitez plus voir.

---

## 3. Bibliothécaire — Tableau de bord

### Travail du jour
Le tableau de bord génère automatiquement les tâches prioritaires :
- Retrait planifié aujourd'hui
- Nouvelles réservations à traiter
- Réservations prêtes pour retrait
- Emprunts en retard
- Retours prévus aujourd'hui
- Consultations sur place à traiter

### Gérer les réservations
L'onglet **Réservations** permet de :
- Sélectionner plusieurs réservations (cases à cocher)
- Appliquer une étape en lot (préparer, planifier le retrait, confirmer)
- Annuler des réservations

### Gérer les emprunts
- **Créer un emprunt** : saisir l'ID ou l'e-mail du lecteur + les références locales
- **Retour total** : saisir l'ID de l'emprunt
- **Retour partiel** : saisir les IDs des exemplaires individuels
- **Emprunts groupés** : vue synthétique par emprunt

### Gérer un·e lecteur·rice
L'onglet **Gérer lecteur·rice** permet de :
- Rechercher par ID public, e-mail ou nom
- Modifier le profil (nom, e-mail, téléphone, genre, adresse)
- **Restreindre l'accès** (avec motif : non-restitution, etc.)
- **Lever la restriction**

---

## 4. Catalogage

### Créer une fiche document
1. Aller dans **Catalogage** > onglet **Document**
2. Sélectionner le **type de matériel** (Livre, Périodique, Tract, Audio, etc.)
3. Remplir les champs (le mode Simple montre l'essentiel, le mode Complet tous les champs)
4. Utiliser **Rechercher métadonnées** pour pré-remplir via ISBN
5. **Enregistrer le brouillon**

### Œuvre, éditions et tomes
Une œuvre réunit toutes les éditions d'un même texte. Dans la fiche d'un document, le bloc **Œuvre** permet de :
- **Rattacher à une autre œuvre** : chercher l'œuvre par son titre, puis **Rattacher**. L'œuvre quittée disparaît si elle reste vide.
- **Titres par langue** : un titre par langue d'interface. Les titres marqués « traduction automatique — corrige-moi » ont été proposés par la machine : relisez-les et cliquez **Enregistrer** pour les confirmer.
- **Titre uniforme** : le titre de référence de l'œuvre, écrit dans la langue d'origine de l'œuvre elle-même, pas dans celle d'une traduction.
- **Tome / volume** : le numéro du tome quand l'œuvre est en plusieurs volumes. Les tomes restent dans une seule œuvre.

### Assistant de dédoublonnage : œuvres scindées et volumes
Dans l'**Assistant de dédoublonnage** (Catalogage), deux onglets complètent les doublons de notices :
- **Œuvres scindées** : deux œuvres qui semblent être le même texte. **Fusionner dans « … »** les réunit ; **Garder séparées** mémorise la décision et la paire ne revient pas.
- **Volumes** : des notices qui semblent être les tomes d'une même œuvre. Cochez **Réunir cette notice** pour chaque tome retenu, saisissez son numéro, puis validez ; un groupe réglé ne revient plus.

Aucune fusion et aucun numéro de tome ne sont posés par la machine : chaque geste est le vôtre.

### Types de documents et champs spécialisés
Chaque type de document affiche des champs adaptés :
- **Périodique** : volume, numéro, fascicule, périodicité, ISSN
- **Tract** : campagne, organisation émettrice, date approximative, format physique
- **Audio** : durée, support, format technique, participant·es
- **Audiovisuel** : durée, réalisation, sous-titres
- **Ressource numérique** : URL, condition d'accès, restriction
- **Dossier** : portée, période, organisations, contexte politique

### Traduire les biographies d'auteurs
Dans l'onglet **Auteur·rice**, quand vous éditez un auteur publié :
1. Ouvrez le panneau **Traductions de la biographie**
2. Saisissez la biographie dans chaque langue souhaitée
3. Cliquez **Enregistrer les traductions**

### Imprimer des étiquettes
Dans l'onglet **Indexation**, sous le formulaire d'exemplaire :
1. Filtrez et sélectionnez les exemplaires
2. Cliquez **Imprimer X étiquette(s)**
3. Un document A4 s'ouvre avec 21 étiquettes par page (7×3)

---

## 5. Administration

### Gestion de la bibliothèque
La page **Bibliothèque** permet de configurer :
- Identité (nom, ville, contact)
- Communications (e-mails, modes d'envoi, types de notification)
- Règlement (upload PDF, règles de circulation)
- Équipe, échanges inter-bibliothèques, rapports

### Gestion du réseau
La page **Réseau** (accessible aux coordinateurs et administrateurs) permet de :
- Voir la vue d'ensemble (stats globales)
- Gérer les demandes de bibliothèques
- Administrer les membres du réseau
- Promouvoir des administrateurs

---

## 6. Langues disponibles

L'interface est disponible en 10 langues :
- 🇧🇷🇵🇹 Português (langue de référence)
- 🇫🇷 Français
- 🇪🇸 Castellano
- 🇬🇧 English
- 🇮🇹 Italiano
- 🇩🇪 Deutsch
- 🇳🇱 Nederlands
- 🇬🇷 Ελληνικά
- Català
- Esperanto

Les biographies d'auteurs peuvent être traduites indépendamment dans chaque langue.

Les titres des œuvres sont pré-traduits automatiquement dans les dix langues ; ils portent la mention « corrige-moi » jusqu'à relecture par une personne.

---

*AnarBib — Réseau de bibliothèques libertaires*
*Logiciel libre pour la gestion coopérative du savoir militant*
