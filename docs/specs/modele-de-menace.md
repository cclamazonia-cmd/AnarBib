---
Genre : référence
Statut : 🟠 en cours
Décisions : cite FED-7, FED-O2, OPAC-TAG1, CARD-A.4, ARCH-3, PRIV-2, §BG2, 2FA-1, OPS-4, NUMDIF-3, DOC-OBJ-2, DOC-GRANT-1, DOC-SILENCE-1, DOC-MSG-1, DOC-DEPLOY-1
Supersédé par : —
---

# Modèle de menace — AnarBib

- **Version :** 0.1 (16/10/2026), premier jet à relire en collectif.
- **Rôle :** dire **ce qu'on protège, contre qui, et par quels chemins**, afin de prioriser les tests de sécurité et les chantiers. Ce document n'est ni un rapport d'audit ni une liste de failles.
- **Compagnons :**
  - [`REGISTRE_decisions.md`](./REGISTRE_decisions.md), foyer des doctrines citées ici ;
  - [`../legal/INCIDENT_RESPONSE.md`](../legal/INCIDENT_RESPONSE.md) et [`../legal/REGISTRE_TRAITEMENTS.md`](../legal/REGISTRE_TRAITEMENTS.md) ;
  - [`spec-historico-retencao-lectrice.md`](./spec-historico-retencao-lectrice.md) et [`spec-pseudonymisation-bg2-14.md`](./spec-pseudonymisation-bg2-14.md).

> **Règle de publication.** Le dépôt est public (AGPL). Ce modèle peut l'être : le code est lisible par tout le monde, l'obscurité ne protège rien. En revanche, **un constat de faille non corrigée n'entre pas dans le dépôt** avant sa correction. Il circule par un canal privé du collectif, puis rejoint le backlog une fois soldé (règle CLAUDE.md n° 12).

---

## §0 — Principe : on protège des personnes, pas un serveur

Pour une bibliothèque anarchiste, la donnée la plus dangereuse n'est pas le catalogue, c'est **le lien entre une personne et ce qu'elle lit, fréquente ou organise**. Une indisponibilité de quelques heures est un désagrément. Une liste nominative de lecteur·rices ou de militant·es qui fuit peut exposer des camarades à la répression, au harcèlement ou à la violence, parfois dans des pays où le risque est vital (cf. la grille de gravité d'`INCIDENT_RESPONSE.md`, qui tient compte du contexte politique du pays).

**Ordre de priorité qui en découle :**

1. **Confidentialité** des identités et des liens (qui lit, qui est membre, qui administre).
2. **Intégrité** des comptes et des droits (personne ne se fait passer pour le staff ou l'administration).
3. **Non-détournement** : AnarBib ne doit servir ni d'arme contre des tiers ni de gouffre à quotas.
4. **Disponibilité** et **capacité de reprise**.

Ce classement prolonge des doctrines déjà actées : FED-7 (anti-panoptique), OPAC-TAG1 (pas de tag qui dise « qui a lu quoi »), refus du pistage (MAIL-Q2, GAZ-5, INV-1 à 5 de `spec-catalogue-decouverte`).

---

## §1 — Actifs

| # | Actif | Où il vit | Sensibilité |
|---|---|---|---|
| A1 | **Identités** : nom, courriel, téléphone et adresse facultatifs, genre, identité locale | `profiles`, `auth.users`, `user_library_memberships` | 🔴 critique |
| A2 | **Liens d'appartenance** : qui est membre de quelle bibliothèque, avec quel rôle | `user_library_memberships`, rôles réseau, cercles | 🔴 critique, car l'appartenance seule peut suffire à exposer |
| A3 | **Pratiques de lecture** : prêts, réservations, consultations, PEB, progression de lecture, souhaits, notes | tables `*_v2`, `reading_progress`, `user_wishlist`, `book_reading_notes` | 🔴 critique |
| A4 | **Correspondances et notes internes** | messageries lecteur·rice ↔ bibliothèque et entre bibliothèques, tâches internes, motifs de gel | 🟠 élevée |
| A5 | **Gouvernance** : votes, cooptations, retraits, journaux d'actes | tables `network_*` (pseudonymisées à l'effacement, BG2-14) | 🟠 élevée |
| A6 | **Fonds restreints** : documents numériques à diffusion limitée, archives citant des militant·es (ARCH-3) | buckets privés, URL signées | 🟠 élevée |
| A7 | **Existence de certaines bibliothèques** : lieux isolés, privés ou non publics | `libraries`, cartographie | 🟠 élevée selon le contexte local |
| A8 | **Secrets** : clés de service, secrets de webhook, sel de pseudonymisation, phrase restic, jetons CI | Vault, secrets Edge, poste du mainteneur, Dashlane, clé USB | 🔴 critique, car la clé de tout le reste |
| A9 | **Sauvegardes** | restic (Herbes Folles), copie froide hors ligne | 🔴 critique : elles contiennent A1 à A8 |
| A10 | **Chaîne de production** : dépôt Codeberg, runner CI, déploiement | Codeberg, WSL2 du mainteneur | 🔴 critique : y écrire, c'est écrire en prod |
| A11 | **Réputation d'envoi et quotas** : domaine expéditeur, quotas Supabase, Resend, LLM, services bibliographiques tiers | comptes de service | 🟡 modérée |
| A12 | **Catalogue public** | `books`, `works`, vues publiques | 🟢 faible (public par nature), mais son intégrité compte |

---

## §2 — Adversaires

| # | Adversaire | Objectif probable | Moyens supposés |
|---|---|---|---|
| ADV1 | **Robots opportunistes** | spam, comptes jetables, abus de quotas, recherche de clés exposées | volume, automatisation, outils génériques |
| ADV2 | **Curieux·se hostile ou doxxeur·se** (dont l'extrême droite) | obtenir des noms, lieux, listes de membres pour exposer ou harceler | temps, outils publics, lecture du code (public), création de comptes |
| ADV3 | **Infiltration ou capture interne** | un compte légitime (lecteur·rice, staff, coordination) qui abuse de ses droits, ou une tentative de prise de contrôle d'une bibliothèque ou du réseau | accès authentifié, ingénierie sociale, cooptation (cf. GOUV-*, « police idéologique intra-mouvement » de FED-7) |
| ADV4 | **État et justice** | réquisition, saisie, surveillance | réquisition auprès des hébergeurs (CLOUD Act pour Supabase/AWS et Resend), saisie de matériel, contrainte légale sur une personne |
| ADV5 | **Compromission de la chaîne d'outils** | écrire dans le code ou la base, voler des secrets | compromission du poste du mainteneur, d'un compte forge, d'une dépendance npm ou Deno, d'une action CI |
| ADV6 | **Partenaire ou source externe piégé·e, même involontairement** | injecter du contenu actif ou malformé | notices moissonnées (OAI), imports de catalogues, fichiers EPUB/PDF versés, flux RSS de la gazette |
| ADV7 | **Accident et panne** | — | erreur humaine, migration ratée, hébergeur indisponible, sauvegarde corrompue, perte d'un poste |

ADV7 n'est pas un attaquant, mais il produit les mêmes effets (perte, indisponibilité) et partage les mêmes remèdes (reprise, sauvegardes). Il figure ici pour cette raison.

---

## §3 — Surface d'exposition (vue d'ensemble)

- **Front public** (Codeberg Pages) : code lisible par tous ; la **clé publiable Supabase est publique par construction**. Tout ce qui est accordé au rôle `anon` est donc joignable depuis Internet sans compte.
- **API PostgREST et RPC** : la RLS et les gardes internes des fonctions `SECURITY DEFINER` sont la vraie frontière (DOC-OBJ-2, DOC-GRANT-1).
- **Fonctions Edge** : `verify_jwt` ne protège rien (constat du 13/10, B43/B44). Chaque fonction porte sa propre garde : secret de tâche, session réelle, admin réseau, ou Altcha et limitation de débit pour les fonctions publiques par nature. La liste est fermée et tenue par un test.
- **Stockage** : buckets publics et privés, lecture des fonds restreints par URL signée à durée courte.
- **Appels sortants** : services bibliographiques, courriel, LLM, géocodage auto-hébergé, moissonnage. Certains suivent des URL saisies par des tiers.
- **Contenus importés** et affichés dans l'interface (ADV6).
- **Hors application** : comptes Codeberg et Supabase, runner CI, poste du mainteneur, sauvegardes, domaines et DNS (cf. OPS-10).

---

## §4 — Scénarios

Chaque scénario donne l'enchaînement redouté, les **protections déjà en place** (avec leur doctrine), et ce qu'il faut **vérifier en test**. La gravité combine l'impact sur les personnes et la vraisemblance.

### S1 — Lecture anonyme de données personnelles — ADV1, ADV2 — 🔴

- **Redouté :** sans compte, avec la seule clé publique, obtenir des identités, des appartenances ou l'existence de bibliothèques non publiques.
- **En place :**
  - DOC-OBJ-2 et DOC-GRANT-1 : une fonction naît fermée à `anon`.
  - Tables de données personnelles en refus total explicite (`MATRICE_rls_deny_all`).
  - Audit `AUDIT_execute_anon_2026-08-30` et tests T9, T10 et T12 sur la liste des fonctions ouvertes à `anon`.
- **À vérifier :** inventaire exhaustif de ce que `anon` peut lire et exécuter **en production** (pas seulement dans les migrations : DOC-GRANT-2 et 3 rappellent que rejeu et prod divergent), y compris les politiques Storage posées hors dépôt.

### S2 — Cloisonnement brisé entre bibliothèques ou entre rôles — ADV2, ADV3 — 🔴

- **Redouté :** un compte légitime d'une bibliothèque lit ou modifie les données d'une autre, ou un compte lecteur·rice obtient des données réservées au staff.
- **En place :**
  - RLS par `library_id`, helpers de visibilité (`fn_visible_library_ids`, B32).
  - Audit `AUDIT_execute_authenticated_2026-09-01` (B14).
  - DOC-SILENCE-1 (pas de refus muet).
- **À vérifier :**
  - matrice de tests par rôle (anon, lecteur·rice A, staff A, coordination A, admin réseau) contre les données de B ;
  - les fonctions `SECURITY DEFINER` qui prennent un identifiant en paramètre ;
  - les **oracles d'existence**, c'est-à-dire un refus qui varie selon que l'objet existe (DOC-MSG-1).

### S3 — Prise de contrôle d'un compte — ADV1, ADV2, ADV3 — 🔴 pour le staff ou l'admin réseau, 🟠 sinon

- **Redouté :** deviner, réinitialiser ou voler l'accès d'un compte, surtout d'un compte à privilèges.
- **En place :**
  - limitation de débit par empreinte d'IP et de courriel, avec échec fermé (B25, B26) ;
  - réponses génériques et plancher de durée (AR-1 à 4) ;
  - Altcha auto-hébergé à l'inscription ;
  - TOTP (2FA-1, B42), obligatoire pour les équipes au 01/01/2027 ;
  - sessions staff en `sessionStorage` et déconnexion après inactivité.
- **À vérifier :**
  - robustesse des secrets générés côté serveur ;
  - politique de mot de passe effective côté serveur ;
  - comportement de la 2FA en cas d'erreur (doit échouer fermé) ;
  - énumération de comptes par les écarts de réponse ;
  - la généralisation de la 2FA (aujourd'hui très peu de comptes l'ont activée).

### S4 — Abus par un compte légitime — ADV3 — 🟠

- **Redouté :** un membre du staff ou de l'administration réseau utilise ses droits pour constituer un fichier (« qui lit quoi », « qui est où »), ou pour capturer une bibliothèque ou le réseau.
- **En place :**
  - FED-7 (pas de vue agrégée du tissu relationnel) ;
  - FED-6 (vue staff limitée) ;
  - gouvernance collégiale et cooptation (GOUV-*) ;
  - journaux d'actes.
- **À vérifier et décider :**
  - **le périmètre de lecture de l'admin réseau**, qui traverse l'isolation par construction : est-ce voulu partout ?
  - FED-O2 (journaliser les consultations de compte par le staff) reste ouvert ;
  - qui lit les journaux, et pour quoi faire (sans en faire un instrument de surveillance) ?

> C'est le scénario où le politique prime le plus sur le technique : la réponse est d'abord une question de gouvernance (qui a quels droits, sous quel contrôle collectif). L'outil ne fait que l'appliquer.

### S5 — Réquisition, saisie, contrainte — ADV4 — 🔴

- **Redouté :** les données sont obtenues par voie légale ou par la force, auprès d'un hébergeur, d'un·e sous-traitant·e ou d'une personne.
- **En place :**
  - rétention bornée et purge hebdomadaire ;
  - maîtrise de son historique par la lectrice (`spec-historico-retencao-lectrice`) ;
  - pseudonymisation à l'effacement (BG2-14) ;
  - carte-lecteur à jeton opaque (CARD-TOKEN), dont la génération reste un choix de la personne (CARD-A.4) ;
  - procédure §3 d'`INCIDENT_RESPONSE.md` ;
  - chantier d'auto-hébergement (I2) pour sortir du périmètre CLOUD Act.
- **À vérifier et décider :**
  - **tout ce qui n'est jamais purgé** est réquisitionnable : PEB, messageries, journaux d'audit, progression de lecture. Faut-il des durées ?
  - les sauvegardes allongent la durée de vie réelle des données : cohérence entre la rétention annoncée et BG2 ;
  - sous-traitants à jour dans le registre des traitements (Herbes Folles et Rumi absents ; Resend aux États-Unis) ;
  - minimisation : ne pas collecter ce qui ne sert pas (téléphone, adresse, genre).

### S6 — Compromission de la chaîne de production ou des secrets — ADV5 — 🔴

- **Redouté :** la prise du poste du mainteneur, d'un compte Codeberg ou Supabase, d'une dépendance ou d'une action CI donne l'écriture en production et l'accès aux secrets, donc à tout.
- **En place :**
  - la CI est la seule voie de déploiement (DOC-DEPLOY-1) ;
  - rotation des secrets (01/09) et coffre (Dashlane, Vault, clé USB hors ligne) ;
  - clés legacy désactivées (B18, B19, B20) ;
  - interdiction de tout secret dans le dépôt.
- **Points de fragilité connus (backlog) :**
  - A3 : le runner CI tourne sur le poste du mainteneur ;
  - A1 : trop peu d'administrateur·rices ;
  - BG2-AUTO-3 : clé SSH de sauvegarde sans phrase de passe, arbitrage assumé ;
  - BG2-15 : le flux long de sauvegarde contient les secrets du Vault en clair.
- **À vérifier :**
  - 2FA sur tous les comptes de forge et d'hébergeur ;
  - portée et durée des jetons CI ;
  - épinglage et intégrité des dépendances et des outils téléchargés en CI ;
  - historique git exempt de secrets.

### S7 — Contenu externe piégé — ADV6 — 🟠

- **Redouté :** une notice moissonnée, un fichier versé ou un flux externe exécute du code dans le navigateur d'un membre du staff (vol de session), ou fait faire au serveur des requêtes vers des cibles internes.
- **En place :**
  - garde des appels sortants (B45, `adresse-sortante.ts`) sur une partie des fonctions ;
  - `react-markdown` sans HTML brut ;
  - en-têtes de sécurité prévus dans la pile auto-hébergée.
- **À vérifier :**
  - tous les chemins où du contenu tiers est rendu dans l'interface, avec ou sans assainissement ;
  - toutes les fonctions qui suivent une URL saisie par quelqu'un, avec ou sans garde ;
  - l'absence de politique CSP sur le front.

### S8 — AnarBib détourné en arme ou en gouffre — ADV1 — 🟠

- **Redouté :**
  - les formulaires publics servent à envoyer des courriels à des tiers, ce qui grille la réputation d'envoi ;
  - les relais vers des services tiers sont abusés (quotas, clé AcoustID, IP du projet) ;
  - les fonctions coûteuses, notamment les LLM, sont déclenchées en boucle ;
  - le stockage est rempli.
- **En place :** limitation de débit partagée (`rate-limit.ts`), Altcha, garde de session réelle sur les relais (B44), double opt-in de la Lettre.
- **À vérifier :** pour **chaque** point d'entrée public, le coût unitaire et la présence d'un frein (Altcha ou débit) ; les quotas des fournisseurs et leur comportement au dépassement.

### S9 — Épuisement et indisponibilité — ADV1, ADV7 — 🟡

- **Redouté :** saturation des quotas Supabase (mise en pause possible selon le forfait), requêtes anonymes coûteuses, panne d'hébergeur.
- **En place :** sonde de santé (OPS-3, qui tombe avec Supabase), domaines de repli (OPS-10).
- **À vérifier :**
  - bornes de pagination côté serveur ;
  - coût des recherches anonymes ;
  - plan B en cas de pause du projet ;
  - une sonde externe (prévue dans le PLAN Dell Latitude).

### S10 — Perte de données et reprise — ADV7, ADV5 — 🟠

- **Redouté :** effacement accidentel ou malveillant, ou migration destructrice, sans pouvoir revenir en arrière.
- **En place :**
  - BG2 (trois flux restic chiffrés, copie froide hors ligne, témoin de vie, test de restauration I29 et I30) ;
  - runbook de restauration.
- **À vérifier :**
  - exercice de restauration complet chronométré ;
  - dépendance de la reprise à un seul poste et à une seule personne (listes PII et secrets hors dépôt) ;
  - politiques Storage non versionnées, donc non reconstructibles.

---

## §5 — Synthèse des risques résiduels prioritaires

Ce sont des **thèmes**, sans détails d'exploitation. Le détail technique va au canal privé (cf. règle de publication en tête).

1. **Concentration humaine et matérielle** : une personne et un poste portent la CI, les secrets, les sauvegardes et l'administration. C'est le premier risque, et il est structurel (A1, A3).
2. **Périmètre de l'admin réseau** : par construction, il voit au travers des bibliothèques. À borner en gouvernance (S4).
3. **Données jamais purgées**, et sauvegardes qui prolongent les données purgées (S5).
4. **Contenu tiers rendu sans politique d'ensemble** (assainissement, CSP, garde des appels sortants) (S7).
5. **Adoption de la 2FA** encore marginale avant l'échéance du 01/01/2027 (S3).
6. **Écart dépôt ↔ production** (politiques Storage manuelles, privilèges) : ce qu'on teste sur une copie n'est pas forcément ce qui tourne (S1, S10).
7. **Registre des traitements et procédure d'incident périmés** : sous-traitants, PITR, Brevo, contacts d'urgence `[À COMPLÉTER]`.

---

## §6 — Suite : du modèle aux tests

| Phase | Contenu | Où | Couvre |
|---|---|---|---|
| 1 — Statique | Lecture du code et des migrations, advisors Supabase, dépendances, secrets dans l'historique | dépôt, sans toucher à la prod | S1, S2, S3, S6, S7, S8 |
| 2 — Dynamique sur copie | Pile Supabase locale, données fictives de deux bibliothèques, suite `tests/security/` par rôle, à terme en CI | WSL, jamais la prod | S1, S2, S3, S7, S8, S9 |
| 3 — Prod, lecture seule | Inventaire de ce que `anon` voit réellement, à faible débit, **sur accord explicite** | prod | S1 |
| Hors code | Exercice de restauration, revue des comptes et de la 2FA, mise à jour du registre des traitements et d'`INCIDENT_RESPONSE`, revue collective de S4 | collectif | S4, S5, S6, S10 |

**Ce qu'on ne fait pas :** pas de test de charge contre la production ni contre Codeberg Pages, une infrastructure associative partagée qu'on ne saturera pas pour se rassurer.

**Tenue du document :** le relire à chaque nouveau point d'entrée public, nouveau sous-traitant ou changement de gouvernance, et au minimum une fois par an avec l'exercice d'incident.
