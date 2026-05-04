<!--
  Procédure de réponse à incident de sécurité — AnarBib
  Copyright (c) 2026 Xavier VAN WELDEN and AnarBib contributors.

  This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
  International License (CC-BY-SA-4.0). To view a copy of this license, visit
  https://creativecommons.org/licenses/by-sa/4.0/ or see the LICENSE-docs file
  at the root of this repository.
-->

# Procédure de réponse à incident de sécurité (violation de données)

> Document conforme aux **articles 33 et 34 du RGPD** (notification à l'autorité de contrôle et communication aux personnes concernées) et à l'**article 48 de la LGPD brésilienne**.

Ce document définit la procédure à suivre en cas de **violation de données personnelles** affectant une instance AnarBib. Il est destiné aux personnes responsables de l'opération technique d'AnarBib (administrador du réseau et coordenador·a·es des bibliothèques adhérentes).

---

## 0. Qu'est-ce qu'une « violation de données » ?

Au sens de l'article 4.12 du RGPD, une violation de données est « une violation de la sécurité entraînant, de manière accidentelle ou illicite, **la destruction, la perte, l'altération, la divulgation non autorisée** de données à caractère personnel transmises, conservées ou traitées d'une autre manière, ou **l'accès non autorisé** à de telles données ».

### Exemples concrets pour AnarBib

| Situation | Violation ? |
|---|---|
| Une faille SQL injection expose la table `profiles` | **Oui** |
| Une mauvaise RLS rend des emails visibles aux mauvais·es utilisateur·rices | **Oui** |
| Un·e bibliothécaire accède par erreur à l'historique d'emprunts d'une autre biblio | **Oui** (accès non autorisé) |
| Un·e administrateur·rice perd son ordinateur portable contenant un dump de base | **Oui** (perte) |
| Une panne Supabase rend le service indisponible 4 heures | **Non** (disponibilité, pas violation) |
| Une lecteur·rice partage volontairement son mot de passe avec quelqu'un | **Non** (pas une violation au sens RGPD, mais incident de sécurité à signaler à la lecteur·rice) |
| Une fuite chez Brevo ou Supabase touchant nos données | **Oui** (le sous-traitant doit nous notifier sans délai, art. 33.2) |
| Un dépôt Codeberg public contient accidentellement un fichier `.env` avec des clés | **Potentiellement oui** — dépend de ce qui était dans le `.env` et si des données ont été extraites |

> **En cas de doute, on traite comme une violation.** La sur-déclaration est sans conséquence ; la sous-déclaration peut entraîner des sanctions.

---

## 1. Procédure en 5 étapes

### Étape 1 — Détection et constat (T0)

**Qui détecte ?** N'importe qui : un·e utilisateur·rice qui signale une anomalie, un·e bibliothécaire qui constate un comportement bizarre, un audit de sécurité, une notification de Supabase ou Brevo, une publication sur Twitter/Mastodon, un message d'un·e chercheur·euse en sécurité.

**Action immédiate** : ouvrir un ticket dans le registre interne des incidents (annexe A) avec :
- Date/heure du constat
- Personne ayant constaté
- Description factuelle (sans interprétation)
- Source de la détection

**Ne pas** :
- Modifier les logs (preuves)
- Communiquer publiquement avant qualification
- Tenter de minimiser sans analyse

### Étape 2 — Qualification (T0 → T+24h max)

**Objectif** : déterminer s'il s'agit bien d'une violation au sens RGPD, et si oui, son périmètre et sa gravité.

**Questions à se poser** :
1. **Quoi ?** Quelles données ont été affectées ? (emails, mots de passe hashés, historiques d'emprunts…)
2. **Combien ?** Combien de personnes sont concernées ? (1, 10, 100, toute la base ?)
3. **Comment ?** Quel est le mécanisme de la violation ? (bug RLS, intrusion, erreur humaine, fuite sous-traitant ?)
4. **Quand ?** Période d'exposition (ponctuelle, plusieurs jours, des mois ?)
5. **Quelle gravité pour les personnes ?** Risque de :
   - **Faible** : pas de conséquence prévisible (ex. exposition d'un identifiant public déjà visible)
   - **Modéré** : désagrément, exposition d'informations privées (ex. historique de lecture)
   - **Élevé** : risque concret pour la sécurité physique, juridique ou financière des personnes (ex. liste nominative de lecteur·rices d'ouvrages politiquement sensibles dans un contexte répressif)

> **Spécificité AnarBib.** Une violation peut avoir des conséquences disproportionnées pour les lecteur·rices de bibliothèques militantes opérant dans des contextes politiques tendus. La grille de gravité doit toujours considérer le **contexte politique du pays** où réside la lecteur·rice, pas seulement le pays d'établissement de la bibliothèque.

### Étape 3 — Confinement et remédiation (T+immédiat)

En parallèle de la qualification, mais **sans la retarder** :

- **Couper l'accès** au vecteur de la violation (révoquer une clé, fermer un endpoint, désactiver un compte compromis)
- **Préserver les preuves** (logs Supabase, logs Edge Functions, logs Brevo, captures d'écran)
- **Patcher la cause racine** dès que l'analyse le permet
- **Documenter** chaque action dans le ticket

### Étape 4 — Notification à l'autorité de contrôle (T0 → T+72h)

**L'article 33 du RGPD impose une notification dans les 72 heures** suivant la prise de connaissance de la violation, sauf si elle « n'est pas susceptible d'engendrer un risque pour les droits et libertés des personnes physiques ».

> **En pratique pour AnarBib** : sauf cas trivial (violation mineure, données non identifiantes, périmètre nul), **on notifie**. Le coût de la notification est faible ; le coût de la non-notification (sanctions art. 83) est élevé.

#### Quelle autorité ?

L'autorité du pays d'**établissement principal** de la bibliothèque adhérente. Voir le tableau du registre des traitements (section 7) :
- France : CNIL (cnil.fr → Notifier une violation)
- Italie : Garante (garanteprivacy.it)
- Espagne : AEPD (aepd.es)
- Allemagne : BfDI ou autorité du Land
- Brésil (LGPD) : ANPD (gov.br/anpd) — délai LGPD : « tempo razoável » (délai raisonnable, non chiffré, mais l'ANPD recommande de s'aligner sur le délai RGPD de 72h)

#### Que contient la notification ? (art. 33.3)

1. **Nature** de la violation : catégories et nombre approximatif de personnes concernées, catégories et nombre approximatif d'enregistrements concernés.
2. **Coordonnées** du point de contact (DPO si désigné, sinon personne référente).
3. **Conséquences probables** de la violation.
4. **Mesures prises** ou proposées pour remédier à la violation et atténuer les effets négatifs.

> Si toutes les informations ne sont pas disponibles à T+72h, **notifier quand même** avec ce qu'on a, et compléter ensuite (art. 33.4 le permet explicitement).

#### Modèle de notification (à adapter)

```
Objet : Notification de violation de données personnelles — [Nom bibliothèque]

À l'attention de [CNIL / Garante / AEPD / ANPD / autre]

Conformément à l'article 33 du RGPD [/ article 48 de la LGPD], nous vous
notifions une violation de données personnelles affectant notre instance
du logiciel AnarBib.

1. Identité du responsable de traitement
   - Nom : [À COMPLÉTER]
   - Adresse : [À COMPLÉTER]
   - Contact : [À COMPLÉTER]

2. Date et heure de la violation
   - Survenue (estimée) : [date/heure]
   - Détectée : [date/heure]
   - Notification émise : [date/heure]

3. Nature de la violation
   - Type : [confidentialité / intégrité / disponibilité]
   - Description factuelle : [À COMPLÉTER]
   - Cause racine identifiée : [À COMPLÉTER ou « en cours d'analyse »]

4. Données concernées
   - Catégories : [À COMPLÉTER : emails, mots de passe hashés, etc.]
   - Volume : [À COMPLÉTER : nombre approximatif de personnes et
     d'enregistrements]
   - Données *non* concernées : [À COMPLÉTER : ce qui a été préservé]

5. Conséquences probables
   - Évaluation du risque pour les personnes : [faible / modéré / élevé]
   - Justification : [À COMPLÉTER]

6. Mesures prises
   - Mesures techniques de confinement : [À COMPLÉTER]
   - Mesures de remédiation : [À COMPLÉTER]
   - Information des personnes concernées : [oui / non / en cours]

7. Mesures complémentaires envisagées
   - [À COMPLÉTER]

Signature, date.
```

### Étape 5 — Communication aux personnes concernées (si risque élevé, art. 34)

**Quand ?** Lorsque la violation est susceptible d'engendrer un **risque élevé** pour les droits et libertés des personnes (art. 34.1). En cas de doute, on communique : la transparence est cohérente avec les valeurs d'AnarBib.

**Comment ?** Un message clair, en français/portugais/espagnol/italien/anglais/allemand selon les locales de la bibliothèque, contenant (art. 34.2) :
- Une description de la violation en termes clairs et simples
- Le nom et les coordonnées du contact
- Les conséquences probables
- Les mesures prises ou proposées
- Les mesures que la personne peut prendre elle-même (ex. changer son mot de passe)

**Par quel canal ?**
- **Mail individuel** via Brevo (canal habituel et personnel)
- **Bannière** sur l'instance AnarBib avertissant des incidents en cours
- Pour les violations majeures : **publication sur le site, le compte Mastodon, le canal de communication public** de la bibliothèque

#### Modèle de communication aux lecteur·rices

```
Objet : Information importante concernant la sécurité de tes données

Camarade,

Nous t'informons d'un incident de sécurité ayant pu affecter tes données
personnelles dans la bibliothèque [nom].

Ce qui s'est passé : [description simple]
Quand : [période]
Quelles données peuvent avoir été concernées : [liste claire]
Quelles données *n'ont pas* été concernées : [liste rassurante si applicable]

Risque pour toi : [explication honnête, sans minimiser ni dramatiser]

Ce que nous avons fait : [mesures prises]

Ce que tu peux faire :
- [Action 1, ex. changer ton mot de passe]
- [Action 2, ex. vérifier l'historique récent de ton compte]

Nous avons notifié l'autorité de protection des données ([nom]).
Tu peux toi-même les contacter si tu le souhaites : [lien].

Pour toute question, écris-nous : [contact]

Solidairement,
L'équipe de [bibliothèque]
```

---

## 2. Cas particulier : violation chez un sous-traitant

Si **Supabase**, **Brevo** ou **Codeberg** subit une violation affectant nos données :

1. Le sous-traitant doit nous notifier « sans délai » (art. 33.2). Vérifier que cette obligation figure bien dans le DPA signé.
2. Dès réception, **nous** sommes responsables de la notification à l'autorité et aux personnes (art. 33.1) — le sous-traitant ne se substitue pas à nous.
3. Coopérer avec le sous-traitant pour l'analyse, mais ne pas attendre ses conclusions pour démarrer notre propre procédure.

---

## 3. Cas particulier : pression d'État, perquisition, demande judiciaire

> Cette section est spécifique au contexte des bibliothèques militantes.

Une **demande de communication de données par une autorité judiciaire ou policière** n'est *pas* une violation de données au sens du RGPD si elle est légalement fondée. Elle relève d'une autre logique.

**Position politique d'AnarBib** : nous n'avons pas vocation à faciliter la surveillance des lecteur·rices. La minimisation des données collectées (cf. registre §2.1) et la rétention courte (Phase 4 RGPD) constituent des protections par construction : **ce qui n'est pas collecté ne peut pas être saisi**.

**Procédure en cas de demande** :
1. Vérifier la régularité formelle de la demande (juge compétent, autorité légalement habilitée, motif).
2. Consulter un·e avocat·e si possible avant toute communication.
3. Communiquer **strictement** ce qui est demandé, rien de plus.
4. **Notifier les personnes concernées** dès que la levée du secret de l'enquête le permet.
5. Documenter dans un registre distinct des « demandes d'autorité ».

**En cas de saisie matérielle** : assumer que toutes les données présentes sur le serveur saisi sont compromises et déclencher la procédure §2.5 (communication aux personnes concernées) une fois la saisie publique.

---

## 4. Test régulier de la procédure

Cette procédure n'est utile que si elle est connue. Recommandation :

- **Une fois par an** : exercice de simulation (« tabletop ») avec les coordenador·a·es. Scénario : « une RLS a sauté, 1500 emails sont exposés depuis 48h ». On déroule la procédure pour vérifier que tout le monde sait quoi faire.
- **À chaque évolution majeure du schéma** : revue de cette procédure pour vérifier qu'elle reste applicable.
- **Avant chaque adhésion d'une nouvelle bibliothèque au réseau** : présentation de la procédure aux nouveaux·elles coordenador·a·es.

---

## Annexe A — Registre interne des incidents

> À tenir à jour dans un fichier privé (pas dans le dépôt public) ou dans un canal interne sécurisé. Format proposé :

```
## Incident #YYYY-NNN

- Date détection : YYYY-MM-DD HH:MM
- Détecté par : [nom/rôle]
- Date survenue (estimée) : 
- Description : 
- Données affectées : 
- Volume : 
- Gravité : [faible / modéré / élevé]
- Cause racine : 
- Notification autorité : [oui/non, date, référence dossier]
- Notification personnes : [oui/non, date, canal]
- Mesures de remédiation : 
- Statut : [ouvert / en cours / clôturé]
- Date clôture : 
- Leçons apprises : 
```

---

## Annexe B — Contacts d'urgence

| Rôle | Nom | Contact |
|---|---|---|
| Responsable technique principal | `[À COMPLÉTER]` | `[À COMPLÉTER]` |
| Coordenador·a de secours | `[À COMPLÉTER]` | `[À COMPLÉTER]` |
| Conseil juridique (si disponible) | `[À COMPLÉTER]` | `[À COMPLÉTER]` |
| Support Supabase (incident de sécurité) | security@supabase.io | (vérifier sur supabase.com) |
| Support Brevo (incident de sécurité) | dpo@brevo.com | (vérifier sur brevo.com) |

---

## Historique de révision

| Date | Auteur | Modification |
|---|---|---|
| `[À COMPLÉTER]` | Xavier | Création initiale de la procédure |

---

*Cette procédure est mise à disposition sous licence **Creative Commons Attribution-ShareAlike 4.0 International** (CC-BY-SA-4.0). Voir le fichier [`LICENSE-docs`](../../LICENSE-docs) à la racine du dépôt et le [README du dossier `docs/legal/`](./README.md) pour les détails. Elle peut être copiée, adaptée et republiée librement par les bibliothèques adhérentes, à condition que les adaptations soient redistribuées sous la même licence.*
