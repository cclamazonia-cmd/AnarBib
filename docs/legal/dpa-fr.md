# Accord de Traitement de Données (DPA)

**Entre AnarBib (sous-traitant) et la bibliothèque adhérente (responsable de traitement)**

---

## Préambule

Cet accord est signé entre le projet **AnarBib** et la bibliothèque
adhérente désignée à l'article 12. Il s'inscrit dans un cadre
politique et juridique spécifique qu'il importe d'expliciter avant
de détailler les articles.

**Conformité au RGPD/LGPD comme outil de protection.** Les
bibliothèques militantes anarchistes opèrent dans des contextes où
la surveillance d'État, la répression policière et judiciaire, ou
la curiosité hostile d'acteurs économiques peuvent viser
directement les lecteur·rices. La conformité au Règlement Général
sur la Protection des Données européen (RGPD) et à la Loi Générale
de Protection des Données brésilienne (LGPD) n'est pas, dans ce
contexte, un alignement néolibéral : c'est un usage tactique du
droit pour protéger qui nous confie ses données personnelles. Les
obligations décrites dans cet accord (minimisation, sécurité, refus
de transfert sans fondement) constituent un arsenal juridique
mobilisable en cas de demande abusive d'une autorité.

**Cohérence avec l'éthique anarchiste.** Le principe de minimisation
des données (RGPD article 5(1)(c)) coïncide avec le souci anarchiste
de ne pas accumuler d'informations sur les personnes. Nous ne
collectons ni ne conservons rien au-delà du strictement nécessaire
au fonctionnement de la bibliothèque. Les durées de rétention
courtes, le refus de vente ou de communication à des tiers, la
transparence sur nos sous-traitants : tout cela est à la fois
conforme au droit et fidèle à notre culture politique.

**Engagement mutuel dans un cadre fédératif.** AnarBib n'est pas une
entreprise qui vend un service à des client·es. C'est un réseau
fédératif de bibliothèques autonomes qui partagent une
infrastructure technique. Ce DPA n'est pas un contrat commercial :
c'est un acte d'engagement mutuel entre le collectif AnarBib (qui
assume la responsabilité technique et la protection des données) et
chaque bibliothèque adhérente (qui garde le contrôle politique de
ses données et de sa gouvernance). Chaque partie reste autonome.
Cet accord formalise les responsabilités respectives dans le cadre
du traitement technique qu'AnarBib opère pour le compte de la
bibliothèque.

---

## Article 1 — Objet

La bibliothèque adhérente confie à AnarBib le traitement technique
de certaines données personnelles nécessaires au fonctionnement de
son système intégré de gestion bibliothécaire (SIGB), selon les
conditions décrites dans le présent accord.

AnarBib agit en tant que **sous-traitant** au sens de l'article 28
du RGPD et de l'article 39 de la LGPD. La bibliothèque adhérente
est le **responsable de traitement** et reste souveraine quant aux
décisions concernant ses données.

## Article 2 — Durée

Le présent accord entre en vigueur à la date de signature et reste
valable tant que la bibliothèque adhérente utilise l'infrastructure
AnarBib.

La bibliothèque adhérente peut résilier cet accord à tout moment
sans pénalité, par notification courriel à contato@anarbib.org.
AnarBib peut résilier moyennant un préavis de 90 jours et procédera
selon l'article 10 du présent accord pour le sort des données.

## Article 3 — Définitions

Aux fins du présent accord, les définitions du RGPD (article 4) et
de la LGPD (article 5) s'appliquent. En particulier :

- **Données personnelles** : toute information se rapportant à une
  personne physique identifiée ou identifiable.
- **Traitement** : toute opération effectuée sur des données
  personnelles (collecte, enregistrement, conservation,
  modification, consultation, communication, suppression, etc.).
- **Responsable de traitement** : la personne ou entité qui
  détermine les finalités et les moyens du traitement — dans cet
  accord, la bibliothèque adhérente.
- **Sous-traitant** : la personne ou entité qui traite les données
  personnelles pour le compte du responsable — dans cet accord,
  AnarBib.
- **Personne concernée** : la personne physique à laquelle les
  données personnelles se rapportent (dans la bibliothèque :
  lecteur·rices, bibliothécaires, coordinateur·rices).

## Article 4 — Description du traitement

### 4.1 Catégories de données traitées

- Identité : prénom, nom, courriel, téléphone (optionnel), genre
  (optionnel), adresse (optionnelle)
- Identifiants techniques : ID interne, ID public, langue préférée
- Données de circulation : emprunts, réservations, consultations
  sur place (avec leur historique)
- Adhésion : statut de cotisation, dates, montants payés
- Notifications : messages reçus dans l'application
- Liste de souhaits : livres marqués par le·la lecteur·rice

### 4.2 Catégories de personnes concernées

- Lecteur·rices adhérent·es de la bibliothèque
- Bibliothécaires et coordinateur·rices de la bibliothèque
- Personnes faisant une demande d'adhésion sans être encore
  adhérentes

### 4.3 Finalités

- Gestion de la circulation des documents (emprunts, réservations,
  retours)
- Communication opérationnelle avec les lecteur·rices (rappels, avis)
- Gestion associative (cotisations, adhésions)
- Statistiques internes anonymes pour le fonctionnement de la
  bibliothèque

### 4.4 Durées de conservation

Conformément au principe de minimisation, les durées par défaut du
réseau AnarBib sont :

- Historique des emprunts terminés : 24 mois
- Historique des réservations terminées : 12 mois
- Historique des consultations sur place terminées : 12 mois
- Notifications lues : 90 jours
- Profil et données d'inscription : tant que le compte de la
  personne existe

La bibliothèque adhérente peut adopter des durées plus courtes (ou
plus longues, par décision collective justifiée) via la page de
configuration de sa bibliothèque. Les durées en vigueur sont
publiées dans la politique de confidentialité publique.

## Article 5 — Obligations d'AnarBib (sous-traitant)

AnarBib s'engage à :

### 5.1 Traiter les données uniquement sur instruction documentée

AnarBib ne traite les données personnelles que pour les finalités
décrites à l'article 4 et selon les configurations que la
bibliothèque définit dans son interface de gestion. AnarBib n'utilise
pas ces données pour des finalités propres.

### 5.2 Garantir la confidentialité du personnel impliqué

Les personnes qui accèdent aux données personnelles pour le compte
d'AnarBib (en particulier le développeur principal, Xavier
Van Welden) s'engagent par principe à respecter la confidentialité.
Aucun accès aux données d'une bibliothèque spécifique n'est effectué
sans nécessité technique documentée.

### 5.3 Mettre en œuvre des mesures de sécurité appropriées

AnarBib met en œuvre les mesures techniques et organisationnelles
suivantes :

- Chiffrement en transit (TLS) pour toutes les communications
- Hashing des mots de passe (bcrypt via Supabase Auth)
- Contrôle d'accès par lignes (Row Level Security PostgreSQL)
- Principe de minimisation appliqué par conception
- Audit périodique des politiques de sécurité

### 5.4 Communiquer les sous-traitants ultérieurs

AnarBib utilise les sous-traitants ultérieurs listés à l'article 7.
Tout ajout sera notifié à la bibliothèque par courriel avec un
préavis de 30 jours. La bibliothèque peut s'opposer à l'ajout par
écrit ; en cas d'opposition persistante, le présent accord pourra
être résilié à l'initiative de la bibliothèque.

### 5.5 Assister la bibliothèque

AnarBib assiste la bibliothèque adhérente pour :

- Répondre aux demandes d'exercice de droits des personnes
  concernées (accès, rectification, suppression, portabilité)
- Respecter les obligations de sécurité (article 32 RGPD)
- Notifier une éventuelle violation de données (articles 33 et 34
  RGPD)

La bibliothèque peut s'appuyer sur les outils intégrés (page « Mon
compte » des lecteur·rices, export RGPD au format JSON+CSV,
suppression de compte directe) qu'AnarBib maintient à disposition.

### 5.6 Notifier les violations de données

En cas de violation de données personnelles, AnarBib notifie la
bibliothèque adhérente sans retard indu et au plus tard dans un
délai de 72 heures après constatation. La notification décrit la
nature de la violation, les catégories et le nombre approximatif
de personnes et de données concernées, les mesures prises ou
proposées, et les points de contact.

Le document INCIDENT_RESPONSE.md publié dans le dépôt AnarBib
détaille la procédure opérationnelle.

### 5.7 Restituer ou supprimer les données en fin de contrat

Conformément à l'article 10 du présent accord.

## Article 6 — Obligations de la bibliothèque (responsable)

La bibliothèque adhérente s'engage à :

### 6.1 Garantir la légalité des traitements

La bibliothèque vérifie que chaque traitement qu'elle confie à
AnarBib repose sur une base légale valable (consentement, exécution
contractuelle, intérêt légitime, etc.).

### 6.2 Informer les personnes concernées

La bibliothèque s'assure que les lecteur·rices sont informé·es du
traitement de leurs données personnelles. La politique de
confidentialité commune AnarBib (accessible à /privacidade) et la
section spécifique éventuellement publiée par la bibliothèque
constituent le support d'information. La bibliothèque peut compléter
librement cette information par ses propres moyens.

### 6.3 Donner des instructions légitimes

La bibliothèque ne donnera pas à AnarBib d'instructions qui
contreviendraient à la réglementation applicable. AnarBib peut
légitimement refuser d'exécuter une instruction manifestement
illégale et le signalera par écrit.

## Article 7 — Sous-traitants ultérieurs

La bibliothèque adhérente autorise AnarBib à recourir aux
sous-traitants ultérieurs suivants :

| Sous-traitant | Fonction | Localisation | Statut |
|---|---|---|---|
| **Supabase Inc.** | Base de données, authentification, stockage, edge functions | AWS São Paulo (sa-east-1) | DPA spécifique signé (réf TFXNN-HUMKJ-3WKP8-MZMYW, CCT 2021/914 module 2) |
| **Sendinblue (Brevo)** | Envoi de courriels transactionnels | UE (France) | DPA standard Brevo |
| **Codeberg e.V.** | Hébergement du frontend (Codeberg Pages) | UE (Allemagne) | Ne traite pas de données personnelles (frontend statique) |

Toute modification de cette liste sera notifiée selon l'article 5.4.

## Article 8 — Transferts hors UE/Brésil

La localisation principale des données est AWS São Paulo (Brésil),
ce qui ne constitue pas un transfert hors Brésil au sens de la LGPD.

Pour les bibliothèques établies dans l'UE, la localisation
brésilienne constitue un transfert hors UE. Ce transfert est
encadré par les Clauses Contractuelles Types (CCT 2021/914 module 2)
signées avec Supabase, qui constituent une garantie adéquate au
sens de l'article 46(2)(c) du RGPD.

Brevo et Codeberg sont établis dans l'UE.

## Article 9 — Audit

La bibliothèque adhérente peut demander une fois par an un audit ou
une inspection des mesures prises par AnarBib en application du
présent accord. Les modalités sont définies d'un commun accord avec
au moins 30 jours de préavis.

AnarBib met à disposition de la bibliothèque :

- Le présent accord
- Le document REGISTRE_TRAITEMENTS.md (registre des traitements)
- Le document INCIDENT_RESPONSE.md (procédure d'incident)
- Le code source (audit par conception, projet open source)

## Article 10 — Sort des données en fin de contrat

À la fin du présent accord (résiliation par l'une ou l'autre
partie, ou arrêt d'utilisation du service par la bibliothèque),
AnarBib procédera, selon le choix de la bibliothèque exprimé par
écrit :

**Option A — Restitution** : AnarBib fournit à la bibliothèque un
export complet des données au format structuré (JSON+CSV) dans un
délai maximum de 30 jours.

**Option B — Suppression** : AnarBib procède à la suppression de
toutes les données de la bibliothèque dans un délai maximum de 30
jours, et fournit une attestation de suppression.

En cas d'absence de manifestation de la bibliothèque dans les 30
jours suivant la fin du contrat, l'option B (suppression) s'applique
par défaut.

Les sauvegardes techniques contenant éventuellement ces données
sont remplacées par rotation dans un délai maximum de 90 jours
après la suppression principale.

## Article 11 — Résolution des litiges

En cas de divergence d'interprétation ou d'application du présent
accord, les parties s'engagent à rechercher prioritairement une
solution amiable par médiation. Si la médiation échoue, chaque
partie garde sa liberté de recourir aux voies légales applicables
dans sa juridiction.

Aucune clause d'arbitrage commercial n'est prévue. Le présent
accord ne constitue pas une renonciation aux droits de la
bibliothèque ou des personnes concernées prévus par le droit
applicable.

## Article 12 — Signature

**Bibliothèque adhérente (responsable de traitement) :**

- Nom : ____________________________________________
- Slug AnarBib : ____________________________________
- Adresse : ________________________________________
- Courriel de contact : _____________________________
- Personne(s) signataire(s) (coordinateur·rices) :

  - ______________________________________ (nom, fonction)
  - ______________________________________ (nom, fonction)

- Lieu et date : ____________________________________
- Signature(s) :

**AnarBib (sous-traitant) :**

- Représenté par : Xavier Van Welden, développeur principal et
  administrateur
- Courriel : contato@anarbib.org
- Lieu et date : ____________________________________
- Signature :

---

*Ce document constitue l'Accord de Traitement de Données au titre
de l'article 28 du RGPD et de l'article 39 de la LGPD. Version 1.0
— 4 mai 2026. Document élaboré collectivement, distribué sous
licence CC-BY-SA-4.0.*
