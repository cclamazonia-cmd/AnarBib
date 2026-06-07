<!--
  Registre des activités de traitement — AnarBib
  Copyright (c) 2026 Xavier VAN WELDEN and AnarBib contributors.

  This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
  International License (CC-BY-SA-4.0). To view a copy of this license, visit
  https://creativecommons.org/licenses/by-sa/4.0/ or see the LICENSE-docs file
  at the root of this repository.
-->

# Registre des activités de traitement

> Document conforme à l'**article 30 du RGPD** (Règlement Général sur la Protection des Données, UE 2016/679) et à l'**article 37 de la LGPD brésilienne** (Lei Geral de Proteção de Dados, Lei nº 13.709/2018).

Ce registre documente les traitements de données personnelles effectués dans le cadre du logiciel **AnarBib**, système intégré de gestion de bibliothèques (SIGB) pour bibliothèques anarchistes et militantes.

---

## Comment lire ce document

Ce registre se compose de **deux couches** :

1. **Le template générique** — applicable à toute bibliothèque utilisant AnarBib. Chaque bibliothèque adhérente doit le **personnaliser** en remplissant les sections marquées `[À COMPLÉTER]` et le maintenir à jour localement.
2. **L'exemple rempli** (annexe A) — l'instance AnarBib opérée par Xavier VAN WELDEN, donnée à titre de référence concrète.

**Pour les bibliothèques adhérentes** : copiez ce fichier dans votre propre dépôt, remplissez les `[À COMPLÉTER]`, supprimez l'annexe A si vous le souhaitez, et committez.

---

## 1. Identification du responsable de traitement

| Champ | Valeur |
|---|---|
| **Responsable de traitement** | Xavier VAN WELDEN (personne physique, art. 4.7 RGPD) |
| **Statut juridique** | Personne physique opérant un projet militant non-commercial sans personnalité juridique formelle. AnarBib est porté à titre individuel ; les bibliothèques adhérentes utilisatrices restent responsables de traitement pour leurs propres données. |
| **Adresse postale (publique)** | Dunkerque, France |
| **Adresse postale complète** | Communiquée à l'autorité de contrôle (CNIL) sur demande. Conservée dans la version privée du registre, conformément à l'art. 30.4 RGPD qui n'impose pas la publication intégrale. |
| **Contact pour les questions de données personnelles** | contato@anarbib.org |
| **Autorité de contrôle compétente** | Commission Nationale de l'Informatique et des Libertés (CNIL), 3 Place de Fontenoy, TSA 80715, 75334 Paris Cedex 07, France — www.cnil.fr |
| **Délégué à la protection des données (DPO)** | Non désigné. La désignation n'est pas obligatoire au sens de l'art. 37 RGPD (AnarBib n'est ni autorité publique, ni traitement à grande échelle de données sensibles, ni profilage systématique). |
| **Date de dernière mise à jour du registre** | 5 juin 2026 |

> **Note politique.** AnarBib n'a pas vocation à exiger une personnalité juridique formelle des bibliothèques adhérentes. Un collectif informel reste néanmoins responsable de traitement au sens RGPD dès lors qu'il opère un système de gestion de comptes lecteur·rices. La désignation d'au moins une personne contact est donc obligatoire, même sans structure formelle.

---

## 2. Finalités de traitement

AnarBib effectue **cinq traitements** distincts. Chacun est documenté ci-dessous selon la nomenclature article 30.

### 2.1 — Gestion des comptes lecteur·rices

| Champ | Valeur |
|---|---|
| **Finalité** | Permettre à une personne d'emprunter, réserver et consulter les ouvrages de la bibliothèque |
| **Base légale (art. 6 RGPD)** | Exécution d'un contrat (art. 6.1.b) — la relation lecteur·rice ↔ bibliothèque |
| **Personnes concernées** | Lecteur·rices inscrit·es à la bibliothèque |
| **Données collectées** | Email, identifiant (login), mot de passe (hashé via bcrypt par Supabase Auth), prénom (optionnel), pseudonyme (optionnel) |
| **Données *non* collectées** | Date de naissance, adresse postale, numéro de téléphone, profession, nationalité, genre, données bancaires |
| **Durée de conservation** | Tant que le compte est actif. Suppression sur demande de la lecteur·rice (auto-service, fonction `delete_user_account`). Suppression automatique des comptes inactifs après `[À COMPLÉTER : durée choisie par la bibliothèque, ex. 24 mois sans connexion]` |
| **Destinataires internes** | Bibliothécaires et coordenador·a·es de la bibliothèque (rôles `librarian` et `coordenador`) |
| **Destinataires externes** | Aucun |
| **Transferts hors UE** | Voir section 6 |

### 2.2 — Gestion des emprunts

| Champ | Valeur |
|---|---|
| **Finalité** | Tracer les ouvrages prêtés pour assurer leur retour, calculer les retards éventuels, gérer la circulation du fonds |
| **Base légale** | Exécution d'un contrat (art. 6.1.b) |
| **Personnes concernées** | Lecteur·rices ayant emprunté un exemplaire |
| **Données collectées** | Identifiant lecteur·rice, identifiant exemplaire, date d'emprunt, date de retour prévue, date de retour effective |
| **Durée de conservation** | Emprunts en cours : pour la durée du prêt. Emprunts terminés : `[À COMPLÉTER : durée choisie par la bibliothèque entre 6 et 24 mois, voir job de rétention automatique]`. Au-delà, suppression automatique. |
| **Destinataires internes** | Bibliothécaires et coordenador·a·es ; la lecteur·rice elle-même pour son propre historique |
| **Destinataires externes** | Aucun |

### 2.3 — Gestion des réservations

| Champ | Valeur |
|---|---|
| **Finalité** | Permettre à une lecteur·rice de réserver un ouvrage non disponible et la prévenir lorsqu'il devient disponible |
| **Base légale** | Exécution d'un contrat (art. 6.1.b) |
| **Personnes concernées** | Lecteur·rices ayant effectué une réservation |
| **Données collectées** | Identifiant lecteur·rice, identifiant ouvrage, date de réservation, statut du workflow |
| **Durée de conservation** | Réservation active : jusqu'à retrait ou annulation. Réservations clôturées : alignées sur la durée des emprunts terminés (cf. 2.2) |
| **Destinataires** | Identiques à 2.2 |

### 2.4 — Communication transactionnelle (mails de workflow)

| Champ | Valeur |
|---|---|
| **Finalité** | Notifier la lecteur·rice des événements liés à ses emprunts et réservations (disponibilité, retrait, retard, retour effectif) |
| **Base légale** | Exécution d'un contrat (art. 6.1.b) — ces mails sont nécessaires au service, ce ne sont **pas** des mails marketing |
| **Personnes concernées** | Lecteur·rices destinataires d'un événement de workflow |
| **Données collectées** | Email, prénom (pour personnalisation), contenu de la notification |
| **Sous-traitant** | Resend (Plus Five Five, Inc.), siège 2261 Market Street #5039, San Francisco, CA 94114, États-Unis. Voir section 5. Le transfert vers les États-Unis qui en résulte est documenté en section 6. |
| **Durée de conservation côté Resend** | Les métadonnées d'envoi et logs sont conservés par Resend pour la durée du contrat. En cas de résiliation du compte, Resend supprime les données dans un délai de 90 jours (DPA Resend, Exhibit A). |
| **Suivi des ouvertures (tracking)** | **Désactivé.** Resend permet en option un suivi des ouvertures et des clics (qui collecterait adresse IP, localisation, appareil, client mail du·de la destinataire). Cette option n'est **pas activée** sur l'instance AnarBib. Voir la note politique en section 4.2. |
| **Destinataires** | Lecteur·rice destinataire ; aucune copie à des tiers |
| **Pas de marketing, jamais** | Conforme à l'article 4 de la Charte AnarBib : aucune communication commerciale, aucune newsletter non sollicitée. |

### 2.5 — Administration du réseau AnarBib

| Champ | Valeur |
|---|---|
| **Finalité** | Permettre la circulation des ouvrages entre bibliothèques adhérentes du réseau (rôle `administrador`, cross-bibliothèque) |
| **Base légale** | Intérêt légitime (art. 6.1.f) — fonctionnement coopératif du réseau |
| **Personnes concernées** | Lecteur·rices ayant explicitement adhéré à plusieurs bibliothèques (multi-membership) |
| **Données collectées** | Identifiant lecteur·rice, liste des bibliothèques où la personne est membre, statut de validation physique |
| **Durée de conservation** | Tant que la lecteur·rice est membre d'au moins deux bibliothèques |
| **Destinataires internes** | Coordenador·a·es des bibliothèques concernées ; administrador AnarBib (rôle réseau) |
| **Destinataires externes** | Aucun |
| **Note** | La validation physique inter-bibliothèque suppose un partage volontaire d'identité entre bibliothèques du réseau. Cette adhésion est explicite (pas implicite) et révocable à tout moment. |

---

## 3. Droits des personnes concernées

Toute lecteur·rice peut, à tout moment, exercer les droits suivants :

| Droit | Article RGPD | Mise en œuvre dans AnarBib |
|---|---|---|
| **Accès** | Art. 15 | Page `/conta` : profil, emprunts en cours, historique, réservations, paramètres |
| **Rectification** | Art. 16 | Édition libre du profil par la lecteur·rice |
| **Effacement (oubli)** | Art. 17 | Bouton « Supprimer mon compte » sur `/conta`, fonction `delete_user_account` (suppression cryptographique des données associées) |
| **Portabilité** | Art. 20 | Bouton « Télécharger mes données » sur `/conta`, formats JSON et CSV au choix *(en cours d'implémentation — Phase 3 RGPD)* |
| **Opposition** | Art. 21 | Sans objet pour les traitements basés sur l'exécution du contrat (2.1–2.4). Pour le traitement basé sur l'intérêt légitime (2.5), la lecteur·rice peut quitter le multi-membership à tout moment. |
| **Limitation** | Art. 18 | Sur demande écrite à `[contato@anarbib.org]`, traitement gelé pendant l'instruction |
| **Réclamation** | Art. 77 | Auprès de l'autorité de contrôle nationale (voir section 7) |

---

## 4. Mesures techniques et organisationnelles (art. 32 RGPD)

### 4.1 Mesures techniques

- **Chiffrement en transit** : HTTPS obligatoire sur toutes les communications client/serveur (Codeberg Pages, Supabase API, API Resend). Resend impose TLS 1.3 ou supérieur sur tous ses échanges.
- **Hashage des mots de passe** : bcrypt via Supabase Auth (jamais stockés en clair, jamais récupérables).
- **Cloisonnement par RLS** : Row Level Security PostgreSQL sur toutes les tables contenant des données personnelles (cf. annexe technique B). Vérifié et durci en mai 2026 (cf. RLS security overhaul, 02/05/2026).
- **Cloisonnement anonyme/authentifié** : les données personnelles ne sont jamais exposées aux requêtes anonymes (matérialisé par les vues `mv_books_catalog_list_v1` *vs* `mv_books_catalog_list_network_v1`).
- **Sauvegardes** : assurées par Supabase (Point-in-Time Recovery sur l'offre payante). Conservation des sauvegardes : selon politique Supabase.

### 4.2 Mesures organisationnelles

- **Modèle à 4 rôles** : `reader` (lecteur·rice), `librarian` (bibliothécaire), `coordenador` (coordination locale), `administrador` (réseau). Principe de moindre privilège.
- **Validation physique** : l'élévation au rôle `librarian+` nécessite une validation physique par un·e coordenador·a, empêchant l'auto-promotion.
- **Code source ouvert** : le code d'AnarBib est public (Codeberg + miroir GitHub), permettant l'audit indépendant des traitements.
- **Pas d'analytics tiers** : aucun Google Analytics, aucun pixel Facebook, aucun tracker comportemental.
- **Prestataire mail choisi pour son respect de la vie privée** : le service d'envoi de mails transactionnels est assuré par Resend, dont le suivi des ouvertures et des clics est **désactivé par défaut** et n'est pas activé sur l'instance AnarBib. Ce choix est délibéré et politique : il garantit qu'aucune adresse IP, localisation ni empreinte technique des lecteur·rices n'est collectée à l'occasion de l'envoi des notifications. Il prolonge l'engagement de non-pistage énoncé ci-dessus, jusque dans la couche de communication par courriel.

### 4.3 Mesures non encore implémentées (transparence)

Ce registre est honnête sur ce qui reste à faire (feuille de route 2026) :

- Rate limiting sur l'Edge Function de login (en cours).
- Turnstile / CAPTCHA anti-bot sur l'inscription (en cours).
- Job de rétention automatique des emprunts terminés (Phase 4 RGPD).
- Politique de confidentialité multilingue par bibliothèque (Phase 2 RGPD).

---

## 5. Sous-traitants (art. 28 RGPD)

### 5.1 Sous-traitants directs

| Sous-traitant | Rôle | Localisation des serveurs | DPA signé | Note |
|---|---|---|---|---|
| **Supabase Inc.** | Hébergement base de données + Auth + Edge Functions | Région `sa-east-1` (São Paulo, Brésil) — voir section 6 | **Oui — 4 mai 2026** (réf. document `TFXNN-HUMKJ-3WKP8-MZMYW`, version DPA du 5 août 2025, CCT 2021/914 module 2 controller-to-processor) | Loi applicable au DPA : Irlande. Supabase Inc. siège à Singapour, structure UE en Irlande. |
| **Codeberg e.V.** | Hébergement du frontend (Codeberg Pages) | Allemagne (UE) | DPA implicite via les CGU | Association allemande à but non lucratif, alignée sur le RGPD par construction. |
| **Resend** (Plus Five Five, Inc.) | Envoi des mails transactionnels | États-Unis (San Francisco, CA) — voir section 6 | **Oui** — DPA Resend (mise à jour du 31 décembre 2025), accepté à l'ouverture du compte. Intègre les CCT 2021/914 module 2 controller-to-processor. | Société états-unienne. Conforme RGPD ; certifiée **EU-U.S. Data Privacy Framework** auprès du Département du Commerce des États-Unis. Conforme **SOC 2 Type II**. Suivi des ouvertures désactivé (cf. §2.4 et §4.2). DPA accessible sur resend.com/legal/dpa. |
| **GitHub Inc.** | Miroir secondaire du dépôt (sans données personnelles) | États-Unis | Sans objet | Le miroir GitHub ne contient **aucune** donnée personnelle de lecteur·rice — uniquement le code source public. Pas de transfert RGPD-significatif. |

### 5.2 Sous-processeurs ultérieurs significatifs (chaîne Supabase)

Le DPA Supabase signé liste 22 sous-processeurs ultérieurs en Schedule 3. La liste suivante est filtrée pour ne retenir que ceux **susceptibles de toucher des données personnelles d'AnarBib** :

| Sous-processeur ultérieur | Rôle | Localisation | Note politique |
|---|---|---|---|
| **Amazon Web Services Inc.** | Hébergement physique réel de l'instance Supabase sa-east-1 | AWS São Paulo (Brésil) | C'est l'hébergeur sous-jacent réel : « Supabase sa-east-1 » = AWS São Paulo opéré pour Supabase. Couvert par les mêmes CCT 2021/914. |
| **Cloudflare Inc.** | CDN / edge network | Global | Trafic chiffré TLS de bout en bout. Pas de stockage durable. |
| **Functional Software Inc. (Sentry)** | Monitoring d'erreurs | États-Unis | Peut contenir des fragments de données dans les stacks d'erreurs. À surveiller : configurer Sentry pour scrubber les PII (`beforeSend` hook). |
| **OpenAI LLC** | Traitement de langage naturel (fonctionnalités IA Supabase) | États-Unis | **Point sensible.** OpenAI ne touche les données AnarBib que si les fonctionnalités IA de Supabase (AI Assistant SQL, embeddings) sont **explicitement activées** dans le projet. Configuration AnarBib : **désactivées** (à vérifier régulièrement dans le dashboard Supabase). |

> **Vérification recommandée trimestriellement** : Supabase peut modifier la liste des sous-processeurs avec préavis de 30 jours (DPA §6.5). Vérifier la liste à jour sur supabase.com/legal/dpa et en cas de changement non acceptable, exercer le droit d'objection (DPA §6.5–6.6).

### 5.3 Action requise pour les bibliothèques adhérentes

Si une bibliothèque adhère au réseau AnarBib et utilise l'instance hébergée par Xavier, la chaîne de sous-traitance devient :

```
Bibliothèque adhérente (responsable de traitement)
   └─ Xavier VAN WELDEN (sous-traitant — opérateur AnarBib)
        └─ Supabase Inc. (sous-processeur ultérieur)
             └─ AWS, OpenAI (le cas échéant), etc. (sous-processeurs ultérieurs²)
```

Cette adhésion suppose la signature d'un **DPA entre la bibliothèque et Xavier** (modèle multilingue à fournir, Phase 5 de la feuille de route RGPD AnarBib).

---

## 6. Transferts hors Union européenne (art. 44–49 RGPD)

L'architecture d'AnarBib implique **deux transferts de données personnelles hors de l'Union européenne**, vers deux sous-traitants distincts. Chacun est documenté ci-dessous avec sa base juridique. Aucun de ces deux pays de destination ne bénéficie, à la date de ce registre, d'une décision d'adéquation générale de la Commission européenne au sens de l'article 45 RGPD ; les deux transferts reposent donc sur les garanties appropriées prévues par l'article 46.

### 6.1 — Transfert vers le Brésil (hébergement de la base de données — Supabase)

L'instance Supabase d'AnarBib est hébergée dans la région **`sa-east-1` (São Paulo, Brésil)**, opérée techniquement par AWS. Y transitent et y sont stockées l'ensemble des données personnelles des lecteur·rices (comptes, emprunts, réservations).

**Base juridique du transfert** : Clauses Contractuelles Types adoptées par la Commission européenne (décision **2021/914**, **module 2 controller-to-processor**), incluses dans le **DPA Supabase signé le 4 mai 2026** (référence document `TFXNN-HUMKJ-3WKP8-MZMYW`, version DPA du 5 août 2025).

**Garanties complémentaires** :
- Le Brésil dispose de sa propre loi de protection des données, la **LGPD** (Lei Geral de Proteção de Dados, Lei nº 13.709/2018), structurellement très proche du RGPD.
- Supabase Inc. engage sa responsabilité européenne via ses CCT (loi applicable au DPA : Irlande).

### 6.2 — Transfert vers les États-Unis (envoi des mails transactionnels — Resend)

Depuis la migration du service de mail (mai 2026), les notifications transactionnelles sont envoyées via **Resend (Plus Five Five, Inc.)**, société établie à San Francisco, États-Unis. Le transfert porte sur les données strictement nécessaires à l'envoi : adresse email du·de la destinataire, prénom, contenu de la notification, et les métadonnées d'envoi associées. Conformément à la documentation de Resend, ces métadonnées et logs sont stockés aux États-Unis, quelle que soit la région d'envoi retenue.

**Base juridique du transfert** : le transfert repose sur une **double garantie**.
- **Clauses Contractuelles Types** : les transferts hors-EEE prévus par le **DPA Resend** (mise à jour du 31 décembre 2025) sont effectués en vertu des CCT **2021/914**, **module 2 controller-to-processor** — soit le même fondement que pour le transfert Supabase. La loi applicable est le droit irlandais.
- **EU-U.S. Data Privacy Framework** : Resend est par ailleurs **certifiée auprès du Département du Commerce des États-Unis** au titre du cadre EU-U.S. Data Privacy Framework, et soumise à ce titre aux pouvoirs de contrôle de la Federal Trade Commission.

**Garanties complémentaires** :
- Aucune donnée sensible n'est transférée (les notifications portent sur des événements de circulation de documents).
- Le suivi des ouvertures et des clics, qui collecterait des données techniques supplémentaires sur les destinataires (adresse IP, localisation, appareil), est une option **désactivée** sur l'instance AnarBib (cf. §2.4 et §4.2).
- En cas de résiliation du compte, Resend supprime les données dans un délai de 90 jours.
- Le DPA Resend prévoit que, en cas de demande d'accès émanant d'une autorité publique, Resend s'efforce de rediriger l'autorité vers le responsable de traitement et notifie ce dernier, sauf interdiction légale.

### 6.3 — Sous-processeurs ultérieurs aux États-Unis (chaîne Supabase)

Indépendamment des deux transferts ci-dessus, certains sous-processeurs ultérieurs de Supabase sont établis aux États-Unis (cf. §5.2 : Sentry, et OpenAI si les fonctionnalités IA étaient activées — elles ne le sont pas). Leur exposition aux données personnelles d'AnarBib est limitée par configuration et fait l'objet d'une vérification périodique.

### 6.4 — Évolution prévue

Une migration de l'hébergement de la base de données vers une région européenne (`eu-west-1` ou `eu-central-1`) est **à l'étude**. La décision sera arbitrée avant l'élargissement du réseau au-delà de la bibliothèque pilote et de BLMF. Une telle migration supprimerait le transfert décrit en §6.1, mais pas celui décrit en §6.2 (le stockage des métadonnées d'envoi par Resend reste aux États-Unis quelle que soit la région d'envoi choisie).

> **Pour les bibliothèques adhérentes** : si vous opérez votre propre instance Supabase, mentionnez ici **votre** région d'hébergement. Si elle est en UE, adaptez la section 6.1 en conséquence. Si vous utilisez l'instance hébergée par Xavier, les sections 6.1 à 6.3 s'appliquent telles quelles.

---

## 7. Autorités de contrôle compétentes

Selon la juridiction de la bibliothèque adhérente :

| Pays | Autorité | Site |
|---|---|---|
| France | CNIL — Commission Nationale de l'Informatique et des Libertés | cnil.fr |
| Italie | Garante per la protezione dei dati personali | garanteprivacy.it |
| Espagne | AEPD — Agencia Española de Protección de Datos | aepd.es |
| Portugal | CNPD — Comissão Nacional de Proteção de Dados | cnpd.pt |
| Allemagne | BfDI — Bundesbeauftragte für den Datenschutz und die Informationsfreiheit (+ autorités des Länder) | bfdi.bund.de |
| Belgique | APD — Autorité de Protection des Données | autoriteprotectiondonnees.be |
| Brésil | ANPD — Autoridade Nacional de Proteção de Dados | gov.br/anpd |

Une réclamation peut toujours être déposée auprès de l'autorité du pays de résidence de la lecteur·rice, indépendamment du pays d'établissement de la bibliothèque.

---

## Annexe A — Exemple rempli : instance opérée par Xavier VAN WELDEN

> Cette annexe sert de référence concrète pour les bibliothèques adhérentes. Elle documente la situation de l'instance « pilote » d'AnarBib.

| Champ | Valeur |
|---|---|
| Responsable de traitement | Xavier VAN WELDEN (personne physique) |
| Adresse publique | Dunkerque, France |
| Contact RGPD | contato@anarbib.org |
| Hébergement DB | Supabase, région `sa-east-1` (São Paulo, Brésil) — AWS sous-jacent — transitoire |
| Hébergement frontend | Codeberg Pages (primaire) + GitHub Pages (miroir secondaire) |
| Mail transactionnel | Resend (Plus Five Five, Inc.), États-Unis — transfert encadré CCT 2021/914 module 2 + EU-U.S. Data Privacy Framework |
| DPO | Non désigné (non requis par l'art. 37 RGPD) |
| Bibliothèques opérées | Bibliothèque pilote (CCLA-portée, BLMF) |
| DPA Supabase | Signé le 4 mai 2026 (réf. TFXNN-HUMKJ-3WKP8-MZMYW) |
| Date de mise en service | 2026 (bêta restreinte ; ouverture réseau prévue après le rassemblement FICEDL de Bologne, septembre 2026) |

---

## Annexe B — Inventaire technique des tables contenant des données personnelles

> Cette annexe est destinée aux personnes effectuant un audit technique. Elle reflète l'état du schéma au **4 mai 2026** et doit être tenue à jour à chaque migration de schéma touchant des données personnelles.

### Tables à données personnelles identifiantes

| Table | Colonnes sensibles | Rôles avec accès lecture (RLS) | Rôles avec accès écriture |
|---|---|---|---|
| `auth.users` (Supabase) | `email`, `encrypted_password`, `last_sign_in_at` | Service role uniquement | Service role uniquement |
| `public.profiles` | `email`, `username`, `display_name`, `must_change_password` | self + librarian+ de la biblio d'inscription | self + librarian+ de la biblio d'inscription |
| `public.emprestimos` | `user_id`, `data_emprestimo`, `data_devolucao_prevista`, `data_devolucao_efetiva` | self + librarian+ de la biblio | librarian+ de la biblio |
| `public.reservas` | `user_id`, `data_reserva`, `status_workflow` | self + librarian+ de la biblio | self (création/annulation), librarian+ (workflow) |
| `public.library_memberships` | `user_id`, `library_id`, `validated_at`, `validated_by` | self + librarian+ des biblios concernées | librarian+ uniquement (pas d'auto-validation) |

### Tables à données pseudonymisables / non personnelles

`livros`, `exemplares`, `autores`, `editoras`, `colecoes`, `tags`, `library_commons` — pas de donnée personnelle directe ; jointures possibles via `emprestimos.user_id` traitées dans les RLS.

### Vues et fonctions exposant des données personnelles

| Objet | Rôle d'exposition | Note |
|---|---|---|
| `api.libraries_public_v1` | Anonyme | Aucune donnée personnelle exposée (uniquement métadonnées biblio) |
| `mv_books_catalog_list_v1` | Anonyme | Catalogue public, **aucune** donnée d'emprunt |
| `mv_books_catalog_list_network_v1` | Authentifié réseau | Catalogue réseau, **aucune** donnée d'emprunt nominative |
| `api.search_catalog_v1` | Anonyme + authentifié | `SECURITY DEFINER` justifié (audit en cours) |

---

## Historique de révision

| Date | Auteur | Modification |
|---|---|---|
| 2026-05-04 | Xavier VAN WELDEN | Création initiale du registre. Intégration des informations du DPA Supabase signé le 4 mai 2026 (réf. TFXNN-HUMKJ-3WKP8-MZMYW). |
| 2026-06-05 | Xavier VAN WELDEN | Migration du sous-traitant mail : Brevo (UE) remplacé par Resend (Plus Five Five, Inc., États-Unis). Mise à jour des §2.4, §4.1, §5.1 et de l'annexe A. Ajout en §4.2 d'une note sur le choix d'un prestataire mail sans suivi des ouvertures. Réécriture de la §6 : documentation de deux transferts hors-UE distincts (Brésil/Supabase et États-Unis/Resend), le second encadré par les CCT 2021/914 module 2 et la certification EU-U.S. Data Privacy Framework de Resend. |

---

*Ce registre est mis à disposition sous licence **Creative Commons Attribution-ShareAlike 4.0 International** (CC-BY-SA-4.0). Voir le fichier [`LICENSE-docs`](../../LICENSE-docs) à la racine du dépôt et le [README du dossier `docs/legal/`](./README.md) pour les détails. Les bibliothèques adhérentes sont explicitement encouragées à copier, adapter et republier ce document, à condition d'en maintenir l'exactitude factuelle vis-à-vis de leur propre instance et de redistribuer leurs adaptations sous la même licence.*
