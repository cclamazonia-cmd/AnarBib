# spec-profils-bibliotheque.md

**Spécification : profils d'adoption d'AnarBib par bibliothèque**

| Champ | Valeur |
|---|---|
| Version | v0.3 |
| Date | 13 mai 2026 |
| Statut | Spec opérationnelle, prête à committer. Inclut les clarifications sur l'archivage et la gouvernance des transitions. |
| Historique | v0.1 (13 mai, doctrine + cartographie) → v0.2 (13 mai, plan de paquets, arbitrages Q1-Q3) → v0.3 (13 mai, raffinements archivage paquet D + doctrine transitions par vote §4.5) |
| Auteur·rice | Xavier + Claude |
| Spec parente | aucune |
| Specs en interaction forte | `spec-administrateur-reseau.md` v0.3, `spec-gouvernance-roles.md`, `spec-onboarding-biblioteca.md` |
| Lecture préalable recommandée | Grand Livre Blanc v13 §3-4 ; Dossier d'ouverture catalogação v2 §1-3 |

---

## 1. Préambule — pourquoi cette spec existe

AnarBib s'est construit depuis le départ comme un système complet : une bibliothèque qui rejoint la plateforme hérite implicitement d'un OPAC public, d'un SIGB de circulation, d'une gouvernance interne formalisée par rôles, et d'une inscription dans un réseau d'athénées libertaires. Cette globalité est une force de l'outil, mais elle constitue aussi une promesse politique implicite : *pour exister dans AnarBib, il faut vouloir tout ce qu'AnarBib propose.*

Cette promesse n'est pas tenable. Le tissu réel des bibliothèques militantes anarchistes francophones, lusophones, hispanophones, italophones et germanophones connaît des collectifs très divers :

- des athénées avec quatre cents brochures et deux compas qui cataloguent à temps perdu, sans système de prêt formalisé ;
- des bibliothèques collectives avec deux cents leitoras·es inscrit·es, un système de cotisations, des permanences régulières, mais une méfiance vis-à-vis de toute fédération extérieure ;
- des collectifs d'archives, des éditeurs militants, des groupes de recherche qui veulent contribuer à un catalogue commun sans gérer aucune circulation locale ;
- et bien sûr les bibliothèques qui veulent tout, qui sont aujourd'hui le cas d'usage majoritaire d'AnarBib.

Imposer le même outil dans la même configuration à ces quatre publics, c'est soit exclure les trois premiers de fait, soit leur infliger une interface inadaptée et un sentiment permanent d'être "en retard" sur un modèle vers lequel ils n'ont aucun désir de tendre.

La présente spec pose une doctrine pour résoudre cette tension : **chaque bibliothèque choisit explicitement, à son adhésion, ce qu'elle prend d'AnarBib, sur quatre axes orthogonaux et activables indépendamment.**

## 2. Doctrine — les quatre axes

### 2.1 Principes structurants

Quatre principes guident la conception de cette spec :

**P1 — Souveraineté.** Chaque bibliothèque garde la maîtrise de ce qu'elle active dans AnarBib. L'outil s'adapte à ses pratiques existantes, pas l'inverse.

**P2 — Visibilité.** Les choix d'une bibliothèque sont visibles dans son painel et lisibles depuis l'extérieur (pour les axes qui ont une portée publique). Pas de configuration cachée, pas de surprise.

**P3 — Réversibilité encadrée.** Toute transition entre profils est possible mais explicitement définie. Certaines transitions sont triviales, d'autres exigent une procédure d'archivage ou de validation collective. Aucune n'est un piège irréversible.

**P4 — Pas de modèle "complet" sacralisé.** Une bibliothèque qui reste en mode minimal pendant dix ans est une bibliothèque légitime. AnarBib ne hiérarchise pas les profils.

### 2.2 Les quatre axes

| Axe | Question politique | Valeurs |
|---|---|---|
| `catalog_mode` | Que fait-on du catalogue ? | `local_only`, `network_published` |
| `circulation_mode` | Y a-t-il une circulation formalisée ? | `off`, `informal`, `full_sigb` |
| `network_mode` | Comment se situer dans le réseau ? | `isolated`, `observer`, `federated` |
| `governance_mode` | Comment se gouverne le collectif ? | `informal`, `staff_roles`, `full_governance` |

### 2.3 catalog_mode

L'axe le plus structurant. Toute bibliothèque dans AnarBib a un catalogue — c'est la condition d'existence dans l'outil. Mais ce catalogue peut être strictement local ou publié dans le réseau.

**`local_only`** — La bibliothèque catalogue son fonds, le rend cherchable pour ses leitoras·es et son équipe, mais n'expose rien au-delà. Aucune notice ne remonte dans le catalogue réseau, aucune autorité ne contribue aux autorités fédérées. La bibliothèque peut importer depuis le réseau (selon `network_mode`) sans rien y publier.

**`network_published`** — Le catalogue de la bibliothèque est publié dans le catalogue commun d'AnarBib. Les notices sont visibles dans le portail réseau, les autorités contribuent au référentiel partagé, la bibliothèque apparaît comme source dans les recherches. C'est le mode "contribution".

Note : la valeur `off` initialement envisagée a été écartée. Une bibliothèque sans aucun catalogue dans AnarBib n'a pas de raison d'être inscrite dans AnarBib.

### 2.4 circulation_mode

L'axe le plus polarisant pour les petites bibliothèques. Il détermine si le SIGB transactionnel d'AnarBib (prêts, retours, réservations, consultations, leitoras·es, cotisations, rappels mail) est activé ou non.

**`off`** — Aucune circulation. La bibliothèque n'a pas de leitoras·es inscrit·es au sens AnarBib, pas de prêts, pas de réservations, pas de cotisations, pas de rappels. L'OPAC peut éventuellement afficher des informations de localisation et de consultation sur place, mais aucune transaction n'est tracée.

**`informal`** — Mode intermédiaire. La bibliothèque peut inscrire des leitoras·es, suivre des prêts simples sans politique formelle (durée, renouvellements, blocages), sans système de cotisations, sans rappels mail automatiques. C'est un cahier d'emprunt numérique, pas un SIGB.

**`full_sigb`** — Le SIGB complet. Politiques de circulation par bibliothèque, règles de prêt par profil de leitora·e, cotisations, rappels J-5/J-3/Hoje/J+1/J+7/J+30, réservations workflow complet, consultations locales, restrictions, etc. C'est le mode actuel implicite.

### 2.5 network_mode

L'axe qui détermine la place de la bibliothèque dans le tissu fédératif anarchiste.

**`isolated`** — La bibliothèque ne voit pas le réseau et n'est pas vue par lui. Son OPAC peut être public sur le web, mais elle n'apparaît pas dans le portail réseau d'AnarBib et ne voit pas les autres bibliothèques fédérées dans son interface. Mode "souveraineté complète".

**`observer`** — La bibliothèque voit le catalogue réseau et peut importer depuis lui, mais ne publie rien et n'apparaît pas dans la liste des bibliothèques fédérées. Mode "j'observe avant de m'engager" ou "je consomme sans contribuer".

**`federated`** — La bibliothèque est pleinement fédérée. Elle voit le réseau, est visible dans le réseau, et participera (quand le chantier sera ouvert) aux fonctions inter-bibs : prêts inter-bibliothèques, mutualisation de fonds, échanges d'autorités, etc.

Note : `network_mode = federated` n'exige pas `catalog_mode = network_published`. Une bibliothèque peut être fédérée pour les fonctions de coopération sans exposer son catalogue. Inversement, `catalog_mode = network_published` exige au minimum `network_mode = observer` (impossible de publier dans un réseau qu'on ignore).

### 2.6 governance_mode

L'axe interne. Il détermine quelle machinerie de gouvernance est active dans le painel de la bibliothèque.

**`informal`** — Pas de rôles différenciés. Toutes les personnes inscrites comme staff de la bibliothèque peuvent tout faire. Pas de workflow de cooptation, pas d'audit log, pas de votes. Mode adapté aux petits collectifs en confiance directe.

**`staff_roles`** — Distinction `librarian` / `coordenador` / `administrador` activée, avec les permissions différenciées qui en découlent. Pas de workflow formel de cooptation : un·e administrador·a peut promouvoir / dégrader directement les membres. Mode intermédiaire pour collectifs structurés sans formalisme.

**`full_governance`** — Tout : rôles différenciés, cooptation par unanimité, dégradations par vote, audit log immutable, durées de carence, etc. C'est le mode prévu par `spec-gouvernance-roles.md`. Adapté aux gros collectifs où la traçabilité politique des décisions est importante.

### 2.7 Profils-types

Pour rendre la configuration tangible à l'inscription, trois profils-types sont proposés (avec un double-libellé pour le premier afin de couvrir deux publics qui partagent la même configuration technique mais ont des identités politiques distinctes). Chaque profil est un point dans l'espace à quatre dimensions ; les bibliothèques peuvent partir d'un profil et ajuster chaque axe individuellement.

| Profil | catalog | circulation | network | governance | Public-cible |
|---|---|---|---|---|---|
| **A — Athénée OPAC** *ou* **C — Collectif contributeur** | `network_published` | `off` | `federated` | `informal` | A : petits athénées qui veulent visibilité et contribution sans gestion de prêts. C : collectifs d'archives, éditeurs militants, groupes de recherche qui contribuent au catalogue sans avoir de circulation locale. |
| **B — Bibliothèque souveraine** | `local_only` | `full_sigb` | `isolated` ou `observer` | `staff_roles` ou `full_governance` | Bibliothèques collectives qui veulent un SIGB sérieux sans fédération de leur catalogue |
| **D — Bibliothèque complète** | `network_published` | `full_sigb` | `federated` | `full_governance` | Bibliothèques collectives qui veulent tout (cas actuel implicite de BLMF/BTL) |

Note : les profils A et C produisent la même configuration sur les quatre axes et ne sont pas distinguables techniquement. Ils sont présentés comme deux boutons distincts à l'inscription parce qu'un athénée militant et un collectif d'édition ne se reconnaissent pas dans la même formule politique, même si l'outil fonctionnera identiquement pour eux. L'auto-désignation politique est tracée via le champ `profile_template_chosen` (`A` ou `C`) à des fins statistiques, mais n'a aucun effet fonctionnel.

### 2.8 Combinaisons interdites

Toutes les combinaisons sur les quatre axes ne sont pas valides. Les contraintes suivantes doivent être vérifiées par invariant DB :

| Contrainte | Justification |
|---|---|
| `catalog_mode = network_published` ⇒ `network_mode ∈ {observer, federated}` | On ne peut pas publier dans un réseau qu'on ignore |
| `circulation_mode = full_sigb` ⇒ `governance_mode ∈ {staff_roles, full_governance}` | Le SIGB complet repose sur les distinctions de rôles (librarian peut prêter, coordenador peut configurer policies, etc.) |

Toutes les autres combinaisons sont valides, y compris les contre-intuitives :
- `catalog_mode = local_only` + `network_mode = federated` = participation aux échanges inter-bibs sans exposer son catalogue, légitime pour une biblio en phase d'observation ;
- `circulation_mode = off` + `governance_mode = full_governance` = collectif d'archives ou éditeur militant qui veut une gouvernance formalisée pour ses décisions de catalogage et de publication réseau, sans avoir besoin de circulation locale.

## 3. Cartographie technique — impact sur l'existant

Cette section inventorie les composants d'AnarBib aujourd'hui en production qui devront être adaptés pour porter les quatre axes. Elle n'est pas exhaustive — le plan de paquets en v0.2 affinera cet inventaire — mais elle donne la mesure du chantier.

### 3.1 Tables et colonnes à créer/modifier

**Table `libraries`** — ajout de quatre colonnes :

```sql
ALTER TABLE public.libraries
  ADD COLUMN catalog_mode text NOT NULL DEFAULT 'network_published'
    CHECK (catalog_mode IN ('local_only', 'network_published')),
  ADD COLUMN circulation_mode text NOT NULL DEFAULT 'full_sigb'
    CHECK (circulation_mode IN ('off', 'informal', 'full_sigb')),
  ADD COLUMN network_mode text NOT NULL DEFAULT 'federated'
    CHECK (network_mode IN ('isolated', 'observer', 'federated')),
  ADD COLUMN governance_mode text NOT NULL DEFAULT 'full_governance'
    CHECK (governance_mode IN ('informal', 'staff_roles', 'full_governance'));

ALTER TABLE public.libraries
  ADD CONSTRAINT chk_catalog_published_requires_network
    CHECK (catalog_mode <> 'network_published' OR network_mode IN ('observer', 'federated')),
  ADD CONSTRAINT chk_full_sigb_requires_roles
    CHECK (circulation_mode <> 'full_sigb' OR governance_mode IN ('staff_roles', 'full_governance'));
```

Le défaut sur les colonnes (`network_published, full_sigb, federated, full_governance`) correspond au comportement actuel implicite. Toute biblio existante au moment de la migration hérite donc du profil D (bibliothèque complète), ce qui préserve la continuité d'exploitation.

**Table `library_profile_history`** — nouvelle table pour tracer les transitions :

```sql
CREATE TABLE public.library_profile_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  axis text NOT NULL CHECK (axis IN ('catalog_mode','circulation_mode','network_mode','governance_mode')),
  old_value text NOT NULL,
  new_value text NOT NULL,
  changed_by uuid REFERENCES auth.users(id),
  changed_at timestamptz NOT NULL DEFAULT now(),
  motivation text,
  CONSTRAINT chk_distinct_values CHECK (old_value <> new_value)
);
```

Table immutable (RLS readonly, INSERT via SECURITY DEFINER uniquement, pas d'UPDATE ni de DELETE). Sert d'audit pour les transitions et de source de vérité pour l'évolution politique d'une bibliothèque dans le temps.

**Table `library_signup_requests`** (existante, à étendre) — ajout de quatre colonnes miroir pour porter le choix de profil dès la demande :

```sql
ALTER TABLE public.library_signup_requests
  ADD COLUMN requested_catalog_mode text,
  ADD COLUMN requested_circulation_mode text,
  ADD COLUMN requested_network_mode text,
  ADD COLUMN requested_governance_mode text;
```

Sans contrainte CHECK ici, parce qu'une demande peut être incomplète ; la validation se fait à l'acceptation.

### 3.2 Helpers DB à créer

```sql
-- Lecture simple
CREATE OR REPLACE FUNCTION public.fn_library_catalog_mode(p_library_id uuid)
  RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS
$$ SELECT catalog_mode FROM public.libraries WHERE id = p_library_id $$;

CREATE OR REPLACE FUNCTION public.fn_library_circulation_mode(p_library_id uuid)
  RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS
$$ SELECT circulation_mode FROM public.libraries WHERE id = p_library_id $$;

-- (idem pour network_mode et governance_mode)

-- Prédicats logiques
CREATE OR REPLACE FUNCTION public.fn_library_has_circulation(p_library_id uuid)
  RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS
$$ SELECT circulation_mode <> 'off' FROM public.libraries WHERE id = p_library_id $$;

CREATE OR REPLACE FUNCTION public.fn_library_has_full_sigb(p_library_id uuid)
  RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS
$$ SELECT circulation_mode = 'full_sigb' FROM public.libraries WHERE id = p_library_id $$;

CREATE OR REPLACE FUNCTION public.fn_library_publishes_catalog(p_library_id uuid)
  RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS
$$ SELECT catalog_mode = 'network_published' FROM public.libraries WHERE id = p_library_id $$;

CREATE OR REPLACE FUNCTION public.fn_library_is_federated(p_library_id uuid)
  RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS
$$ SELECT network_mode = 'federated' FROM public.libraries WHERE id = p_library_id $$;

CREATE OR REPLACE FUNCTION public.fn_library_uses_governance(p_library_id uuid)
  RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS
$$ SELECT governance_mode = 'full_governance' FROM public.libraries WHERE id = p_library_id $$;
```

Ces helpers sont préférables à l'inlining direct des colonnes dans chaque RLS / RPC pour deux raisons : centraliser la sémantique (modification d'une seule fonction si la doctrine évolue) et permettre le caching côté backend si une couche de cache est introduite ultérieurement.

Tous les helpers `STABLE SECURITY DEFINER` doivent être `GRANT EXECUTE TO anon, authenticated` pour rester utilisables dans les RLS de tables anon-readable (cf. doctrine "anon = REVOKE par défaut + whitelist documentée" déjà en vigueur, mais helpers utilisés en RLS sont une exception explicite).

### 3.3 RLS impactées (recensement non exhaustif)

Le recensement précis sera fait en v0.2. Voici les familles concernées :

| Famille | Tables types | Impact attendu |
|---|---|---|
| Circulation | `emprestimos`, `emprestimo_itens`, `reservas`, `reserva_itens`, `consultas`, `consulta_itens` | Toutes ces tables ne doivent contenir aucune ligne pour une biblio en `circulation_mode = off`. RLS de SELECT/INSERT/UPDATE à conditionner par `fn_library_has_circulation(library_id)`. Triggers BEFORE INSERT pour rejeter les écritures sur biblios sans circulation. |
| Cotisations | `cotisations`, `cotisation_payments` (si existant) | Conditionnées par `fn_library_has_full_sigb()`. `circulation_mode = informal` n'active pas les cotisations. |
| Rappels et notifications de circulation | `library_notification_policies`, jobs pg_cron de rappel | Les rappels J-5/J-3/Hoje/J+1/etc. ne doivent pas être déclenchés pour les biblios en `circulation_mode ∈ {off, informal}`. À conditionner dans `handleEmprestimoV2Reminder`. |
| Catalogue réseau | `books`, `book_holdings`, `exemplares`, `mv_books_catalog_list_network_v1` | Les notices d'une biblio en `catalog_mode = local_only` ne doivent pas remonter dans la vue matérialisée réseau ni dans le catalogue public. RLS de SELECT à conditionner par `fn_library_publishes_catalog(library_id)`. |
| Visibilité réseau | `api.libraries_public_v1`, `api.network_overview`, vue publique des bibliothèques fédérées | Une biblio en `network_mode = isolated` ne doit apparaître dans aucune vue publique réseau. Helper `fn_library_visible_to_caller` à étendre. |
| Gouvernance | `user_library_memberships`, `library_membership_audit`, `team_notification_outbox` | Workflows de cooptation et de dégradation par vote actifs uniquement si `governance_mode = full_governance`. Mode `staff_roles` autorise des mutations directes ; mode `informal` n'active pas la table de memberships (ou la maintient avec un seul rôle générique). |

Estimation grossière : **15 à 25 RLS** à conditionner sur ces axes, sur les 108 policies RLS recensées au backend (~15-23% du corpus RLS). L'ordre de grandeur est cohérent avec un chantier transversal de taille moyenne.

### 3.4 Vues et vues matérialisées impactées

| Vue | Impact |
|---|---|
| `api.libraries_public_v1` | Filtre supplémentaire `network_mode <> 'isolated'`. Helper `fn_library_visible_to_caller` à mettre à jour. |
| `api.network_overview` | Idem. |
| `mv_books_catalog_list_v1` | Inchangée (catalogue local par biblio, lu en interne). |
| `mv_books_catalog_list_network_v1` | Filtre supplémentaire `catalog_mode = 'network_published'` à la construction. Refresh à déclencher lors d'un changement de `catalog_mode`. |
| `api.library_circulation_stats` | Doit retourner des stats vides ou nulles pour une biblio en `circulation_mode = off`, plutôt qu'une absence de ligne (pour ne pas casser le frontend qui s'attend à recevoir un objet). |

### 3.5 RPC et Edge Functions impactées

| RPC / EF | Impact |
|---|---|
| `fn_submit_library_request` | Ajout des quatre paramètres de profil. Validation des combinaisons. |
| `fn_create_library_from_request` | Application des quatre profils à la création de la biblio. |
| `fn_create_emprestimo_v2`, `fn_create_reserva_v2`, `fn_create_consulta_*` | Vérifier `fn_library_has_circulation()` avant toute action, retourner erreur explicite si `off`. |
| `fn_renew_my_loan` | Idem. |
| `fn_my_account_status` | Adapter la lecture aux biblios sans circulation (l'usager voit alors un état "bibliothèque sans prêts" plutôt qu'un compteur de prêts à zéro). |
| Edge Function `notify-event` handlers `emprestimo.*`, `reserva.*`, `consulta.*` | NOOP si la biblio cible est en `circulation_mode = off`. À implémenter dans le routage `dispatch.ts`. |
| Edge Function `notify-event` handler `team.*` | Mode `informal` : NOOP (pas de notifications de gouvernance). Mode `staff_roles` : notifications simplifiées (pas de cooptation). Mode `full_governance` : comportement actuel complet. |
| Job pg_cron `expire_solicitada`, `detect_no_show`, etc. | Skip les biblios en `circulation_mode ∈ {off, informal}`. |
| Job pg_cron `inactive_cleanup`, `pending_removal_complete` | Skip les biblios en `governance_mode = informal`. |
| Edge Function `notify-cross-library-digest` (à venir, paquet F admin réseau) | Lit uniquement les biblios en `network_mode = federated`. |

### 3.6 Frontend impacté

| Page / composant | Impact |
|---|---|
| `BibliotecaSetupPage` (création/édition) | Ajout d'un sélecteur de profil avec quatre boutons (A/B/C/D) + détail accordéon par axe. |
| `PainelPage` (sidebar / navigation) | Masquage conditionnel des onglets Empréstimos, Reservas, Consultas, Leitoras·es, Cotisações selon `circulation_mode`. Masquage des onglets Rede, Imports selon `network_mode`. Masquage de la section Cooptação selon `governance_mode`. |
| `LibraryProfileBadge` (nouveau composant) | Affichage compact du profil dans l'en-tête du painel et sur la page publique de la biblio (si applicable). |
| `LibraryProfileEditPage` (nouveau) | Page dédiée aux transitions de profil, accessible aux `administrador·as` (ou tous staff si `governance_mode = informal`). |
| `BookDetailPage` (livro) | Si toutes les biblios qui possèdent le livre sont en `circulation_mode = off`, masquer le bouton "Réserver" et afficher seulement les informations de consultation sur place. |
| `AccountPage` (conta) | Pour un usager de biblio en `circulation_mode = off`, la page se réduit aux préférences personnelles (langue, mot de passe) — pas d'onglet "Mes prêts", pas de "Mes réservations". |
| `LibraryRequestForm` (criar-conta sans biblio puis demande de création) | Inclure le sélecteur de profil. |
| `SignupChooseLibraryPage` | Afficher le profil de chaque biblio listée pour que l'usager comprenne dans quoi il s'inscrit (ex. "Cette bibliothèque ne pratique pas le prêt formalisé"). |

### 3.7 i18n

L'ajout des quatre axes implique l'ajout de chaînes dans les 6 locales (`pt-BR`, `fr`, `es`, `en`, `it`, `de`). Estimation grossière :

- 4 axes × 3 valeurs en moyenne = 12 libellés de valeurs ;
- 4 axes × 1 nom = 4 libellés d'axes ;
- 4 profils-types × (nom + description) = 8 chaînes ;
- diverses chaînes de UI conditionnelle (messages d'absence de circulation, etc.) : ~20 chaînes ;
- chaînes de transition (motivations, confirmations) : ~10 chaînes.

Total estimé : **~50 chaînes × 6 locales = ~300 ajouts i18n**. Ordre de grandeur cohérent avec un chantier UX moyen.

## 4. Doctrine des transitions — réflexion technique engagée

Cette section traite la Q3 arbitrée plus haut : *quelles transitions entre profils sont autorisées, et avec quelles précautions ?*

C'est la partie la plus délicate de la spec, parce que c'est là que la doctrine politique rencontre l'existant transactionnel. Une transition de profil n'est pas seulement un changement de configuration : pour certains axes, elle peut invalider des données réelles (prêts en cours, notices publiées sur le réseau, votes de cooptation en attente).

Le principe directeur est le suivant : **toute transition qui peut détruire ou rendre incohérentes des données existantes exige une procédure explicite, jamais une bascule silencieuse.**

### 4.1 Typologie des transitions

J'identifie quatre familles de transitions, par ordre croissant de risque :

**Type 1 — Élargissement.** La bibliothèque active quelque chose qu'elle n'avait pas. Aucune donnée n'est détruite ; il s'agit seulement d'ouvrir des fonctionnalités.

*Exemples :* `circulation_mode: off → informal`, `network_mode: isolated → observer`, `governance_mode: informal → staff_roles`.

*Procédure :* simple bascule, validation `administrador·a` (ou staff si `informal`), entrée dans `library_profile_history`, notification interne aux membres. Pas de carence, pas d'archivage.

**Type 2 — Approfondissement.** La bibliothèque passe d'un mode intermédiaire à un mode complet. Là encore, aucune donnée n'est détruite, mais l'activation peut révéler des configurations manquantes (ex. activer `full_sigb` exige des policies de circulation, des règles de prêt par profil de leitora·e, qui peuvent ne pas exister).

*Exemples :* `circulation_mode: informal → full_sigb`, `governance_mode: staff_roles → full_governance`.

*Procédure :* bascule + checklist de pré-requis. Si les policies de circulation par défaut sont absentes, AnarBib les crée à partir d'un template par défaut (configurable ensuite). Notification aux membres. Pas de carence.

**Type 3 — Rétractation douce.** La bibliothèque revient à un mode plus restreint, sans destruction de données existantes mais avec masquage.

*Exemples :* `network_mode: federated → observer`, `network_mode: observer → isolated`, `catalog_mode: network_published → local_only`.

*Procédure :* bascule + carence courte (24h annoncée publiquement, pour permettre aux partenaires fédérés de prendre connaissance du changement) + refresh des vues matérialisées réseau. Les notices publiées restent en base, mais sont retirées du catalogue réseau et de la vue publique. Si la biblio revient à `network_published` ultérieurement, elles réapparaissent automatiquement — c'est une bascule de visibilité, pas un effacement.

Question subsidiaire pour Xavier : que devient-on des **emprunts inter-bibs en cours** (chantier futur) si une biblio passe `network_mode: federated → observer` ? Probablement : carence longue (le temps que les emprunts en cours soient retournés) ou refus pur de la transition tant qu'il existe des emprunts inter-bibs ouverts. À cadrer quand le chantier inter-bibs ouvrira.

**Type 4 — Rétractation dure.** La bibliothèque désactive un axe qui contenait des transactions actives. C'est le cas le plus délicat.

*Exemple critique :* `circulation_mode: full_sigb → off` alors qu'il existe des prêts en cours, des réservations actives, des consultations ouvertes, un historique de cotisations.

*Trois options possibles, par ordre de douceur :*

| Option | Description | Avantages | Inconvénients |
|---|---|---|---|
| **Stricte** | Refuser la transition tant qu'il existe des transactions actives (prêts en cours, réservations non clôturées, consultations en cours). La biblio doit clôturer manuellement avant de basculer. | Cohérence forte, pas de surprise. | Frustrant pour une biblio qui veut juste "arrêter de gérer ça". |
| **Archivage** | Bascule possible à tout moment ; les transactions actives sont marquées `archived = true` et deviennent invisibles dans les UI courantes, mais conservées en base pour audit. L'historique reste consultable via une page dédiée. | Permet la transition à tout moment, préserve la mémoire. | Complexité de l'archivage : toutes les tables transactionnelles doivent supporter un état archived. |
| **Migration explicite** | Bascule via une procédure formelle ("Voulez-vous archiver les 12 prêts en cours et les 3 réservations actives ?") avec confirmation typée du nom de la bibliothèque. Effets clairement listés avant validation. | Compromis acceptable, force la conscience de l'acte. | Charge UX. |

**Ma recommandation : l'option "migration explicite".** Elle préserve la souveraineté de la biblio (elle peut revenir en arrière même avec des transactions ouvertes) tout en exigeant une conscience claire de ce que la transition implique. L'option "stricte" peut être adoptée comme variante pour `governance_mode: full_governance → informal` quand il existe des votes de cooptation en cours (refuser la transition tant que les votes ne sont pas clôturés, parce qu'archiver un vote en cours est politiquement plus discutable qu'archiver un prêt).

### 4.2 Matrice des transitions

Le tableau ci-dessous classifie les transitions par axe et par type. **Les procédures de validation détaillées (qui peut initier, qui doit voter, quelle carence) sont définies en §4.5** en fonction du `governance_mode` de la biblio au moment de la transition. **Le gel des jobs pendant les carences est défini en §4.6.**

| De → Vers | Type | Note spécifique |
|---|---|---|
| **catalog_mode** | | |
| `local_only → network_published` | 1 | Refresh mv_network à l'effectivité |
| `network_published → local_only` | 3 | Refresh mv_network à l'expiration de la carence |
| **circulation_mode** | | |
| `off → informal` | 1 | — |
| `off → full_sigb` | 2 | Checklist policies de circulation (créées par défaut depuis template) |
| `informal → full_sigb` | 2 | Checklist policies de circulation |
| `informal → off` | 3 | Peu de données à archiver (pas de cotisations en `informal`) |
| `full_sigb → informal` | 4 | Archivage des cotisations en cours + restrictions ; les prêts simples restent ; rappels mail désactivés |
| `full_sigb → off` | 4 | Archivage complet (cf. paquet D §9.4) |
| **network_mode** | | |
| `isolated → observer` | 1 | — |
| `observer → federated` | 1 | Ne publie pas le catalogue tant que `catalog_mode = local_only` |
| `isolated → federated` | 1 | Saut autorisé |
| `federated → observer` | 3 | Refresh mv_network à l'expiration de la carence |
| `observer → isolated` | 3 | — |
| `federated → isolated` | 3 | À l'ouverture du chantier inter-bibs : vérifier l'absence d'emprunts inter-bibs ouverts |
| **governance_mode** | | |
| `informal → staff_roles` | 2 | Attribution des rôles aux membres existants (par défaut `librarian` à tous, sauf l'initiateur·rice de la transition qui devient `administrador`) |
| `staff_roles → full_governance` | 2 | Activation des workflows de cooptation et audit log |
| `informal → full_governance` | 2 | Double attribution (rôles + workflows) |
| `full_governance → staff_roles` | 4 | Refusé si propositions en cours (cf. §4.5.7) |
| `staff_roles → informal` | 4 | **Cas particulier §4.5.6** : carence longue 7j, collège élargi admins+coords |
| `full_governance → informal` | 4 | Refusé si propositions en cours ; en pratique passage en deux temps via `staff_roles` |

### 4.3 Contraintes systémiques pendant les transitions

Quelques garde-fous techniques :

- Toute transition doit être enveloppée dans une **transaction DB** avec rollback en cas d'erreur. Pas de bascule partielle.
- Toute transition de type 3 ou 4 doit déclencher une **notification mail aux administrador·as** de la bibliothèque, avec un délai de protestation de 48h (pendant lequel un·e autre administrador·a peut révoquer la transition).
- Pour `governance_mode = full_governance`, les transitions de type 4 doivent exiger **unanimité des administrador·as actif·ves de la biblio** (cohérent avec la doctrine de cooptation).
- L'historique de transitions doit être visible publiquement pour les axes `catalog_mode` et `network_mode` (les axes qui ont une portée extérieure), et visible seulement aux membres pour `circulation_mode` et `governance_mode` (les axes internes).

### 4.4 Le profil par défaut à la migration des biblios existantes

Au moment de déployer la spec, les bibliothèques existantes (BLMF, BTL, et la troisième) recevront automatiquement le profil D (tout activé), parce que c'est leur état actuel implicite.

**Arbitrage Q3 (13 mai 2026) :** afficher un bandeau d'information non bloquant dans le painel des biblios existantes pendant 30 jours après le déploiement, invitant à passer en revue les axes. Une biblio peut ignorer le bandeau ; sa configuration reste D ; pas de pénalité. Cette décision est portée par le paquet G (cf. §9.7).

### 4.5 Doctrine de gouvernance des transitions

Les transitions de profil sont des actes politiques. Selon le `governance_mode` actuel de la biblio et le type de transition, la procédure de validation diffère. Cette sous-section pose la doctrine précise, en cohérence avec mais distincte de la doctrine D.6 de cooptation des admins réseau.

**Pourquoi une doctrine distincte de D.6 ?** D.6 concerne l'entrée/sortie d'une personne dans le rôle d'admin réseau (acte politique fort, conséquences durables, target identifiable). Une transition de profil concerne la configuration d'un collectif (acte politique également, mais sur un objet et non une personne, et avec des conséquences techniques généralement réversibles). La doctrine sœur ci-dessous reprend les principes structurants de D.6 (proposition, vote, motivation, carence) mais avec des paramètres allégés.

**4.5.1 Transitions de type 1 et 2 (élargissement, approfondissement) :**

Indépendamment du `governance_mode`, ces transitions sont effectives immédiatement et n'exigent pas de vote. Justification : elles ne détruisent aucune donnée et ne réduisent aucune capacité.
- En `governance_mode = informal` : tout membre staff peut initier.
- En `governance_mode = staff_roles` ou `full_governance` : seul·es les administrador·as et coordenador·as peuvent initier.
- Trace : INSERT immédiat dans `library_profile_history`. Notification aux membres staff de la biblio.

**4.5.2 Transitions de type 3 (rétractation douce) :**

Carence 24h, révocable pendant la carence par tout administrador·a (ou tout membre staff en `informal`).
- En `governance_mode = informal` : initiation par tout membre staff. Pendant 24h, tout autre membre staff peut révoquer.
- En `governance_mode = staff_roles` ou `full_governance` : initiation par tout administrador·a. Pendant 24h, tout autre administrador·a peut révoquer.
- Trace : INSERT dans `library_profile_history` à l'initiation avec `status = 'pending'`, UPDATE en `status = 'completed'` après expiration de la carence (ou `status = 'cancelled'` si révocation).
- Notifications : mail aux administrador·as à l'initiation, mail à tous les membres staff à la complétion ou à la révocation.

**4.5.3 Transitions de type 4 (rétractation dure) en `governance_mode = informal` :**

Pas de vote formel, mais délai de protestation de 48h pendant lequel tout membre staff peut révoquer.
- Motivation ≥ 50 chars obligatoire.
- L'archivage des transactions actives n'est exécuté qu'à l'expiration de la carence (gel pendant 48h, cf. §4.6).
- Si révocation pendant la carence : annulation totale, aucune donnée touchée.
- Justification politique : `informal` veut dire "confiance directe", mais le délai de protestation préserve les autres membres d'une décision unilatérale aux conséquences fortes.

**4.5.4 Transitions de type 4 (rétractation dure) en `governance_mode = staff_roles` :**

Le mode `staff_roles` distingue les rôles sans formaliser de votes. Une transition de type 4 est initiée par un·e administrador·a et confirmée par majorité simple des administrador·as et coordenador·as (et non unanimité). Carence 48h post-confirmation, révocable.
- Motivation ≥ 50 chars obligatoire.
- Si la biblio n'a qu'un·e seul·e administrador·a + coordenador·a, "majorité simple" = les deux d'accord. Si elle a 3 admins + 1 coord, 3 sur 4 suffisent.
- Justification : `staff_roles` privilégie l'efficacité, l'unanimité serait disproportionnée pour ce mode.

**4.5.5 Transitions de type 4 (rétractation dure) en `governance_mode = full_governance` :**

Doctrine sœur de D.6, allégée :
- proposition par un·e seul·e administrador·a ;
- motivation ≥ 50 chars obligatoire ;
- vote des autres administrador·as de la biblio ;
- unanimité requise pour exécution (pas de rationale against requise — c'est une question de configuration, pas de personne) ;
- carence 48h après atteinte de l'unanimité (et non 7j comme en D.6, parce que la transition est techniquement réversible, contrairement à la sortie d'un·e admin réseau) ;
- expiration de la proposition à 30 jours sans unanimité ;
- pas de quorum minimum (taille de biblio variable).
- Trace dans `library_profile_proposals` et `library_profile_votes` (tables symétriques à celles de D.6, créées au paquet B).

**4.5.6 Cas particulier : transition `staff_roles → informal` (perte des rôles).**

Cette transition de type 4 supprime la distinction qui sert à sa propre validation. Doctrine spécifique :
- initiée par un·e administrador·a ;
- unanimité des administrador·as **et** coordenador·as de la biblio (élargissement du collège pour reconnaître l'importance politique de la perte de gouvernance) ;
- carence longue de 7 jours après atteinte de l'unanimité (et non 48h) ;
- expiration de la proposition à 30 jours.
- Pendant la carence 7j, l'état reste `staff_roles` et toute action de gouvernance reste possible.
- À l'expiration, bascule effective et tous les membres existants conservent leur statut "staff" sans distinction de rôle.

**4.5.7 Cas particulier : transition `full_governance → staff_roles` ou `informal`.**

Si des `library_profile_proposals` (ou des propositions de cooptation D.6 ouvertes au niveau biblio, le cas échéant) sont en cours, la transition est **refusée** tant que ces propositions ne sont pas closes (acceptées, rejetées ou expirées). Justification : archiver un vote politique en cours est plus discutable qu'archiver un prêt.

### 4.6 Gel des jobs pendant la carence

**Doctrine "gel complet"** : pendant une fenêtre de carence d'une transition de type 3 ou 4, tous les jobs pg_cron qui auraient pu modifier l'état des transactions concernées **skip cette bibliothèque**.

Cas concrets :
- transition `circulation_mode: full_sigb → off` en carence : les jobs `expire_solicitada`, `detect_no_show`, `handleEmprestimoV2Reminder` (J-5/J-3/Hoje/J+1/J+7/J+30) skip cette biblio pendant 48h ;
- transition `governance_mode: full_governance → staff_roles` en carence : les jobs `pending_removal_complete` et `inactive_cleanup` skip les membres de cette biblio pendant 48h ;
- transition `catalog_mode: network_published → local_only` en carence 24h : le refresh de `mv_books_catalog_list_network_v1` est différé jusqu'à l'expiration.

**Conséquences politiques assumées :**
- pendant la carence, la biblio est "en délibération" sur sa propre configuration ;
- les notifications attendues (rappels J-3 par exemple) ne partent pas pendant cette fenêtre ;
- si la transition est révoquée, l'état est cohérent mais quelques événements automatiques ont été suspendus pendant 48h ;
- ce gel ne s'applique **pas** aux actions humaines : un·e librarian peut continuer à enregistrer un retour pendant la carence, par exemple. Seuls les automatismes sont gelés.

**Alternative écartée :** la "continuité simulée" (jobs tournent, état change, mais notifications muettes) a été écartée parce qu'elle produit un état hybride difficile à comprendre pour les usager·es (un prêt qui passe en `overdue` sans notification mail crée de la confusion). L'alternative "snapshot complet" a été écartée pour son coût d'implémentation.

## 5. Onboarding — refonte du formulaire de demande

L'arbitrage Q4 prévoit un choix explicite à l'inscription. Voici la structure proposée :

### 5.1 Écran 1 — Choix du profil-type

Quatre cartes-boutons (A, C, B, D — dans cet ordre pour mettre en valeur les profils légers en premier), équivalentes visuellement, avec pour chacune :

- un nom court (ex. "Athénée OPAC", "Collectif contributeur") ;
- une description en 2-3 phrases du public-cible ;
- la liste des fonctionnalités activées, en gras pour celles qui distinguent ce profil ;
- un bouton "Choisir ce profil".

Les boutons A et C mènent à la même configuration technique, mais sont présentés distinctement (avec leurs intitulés et descriptions propres) pour permettre l'auto-désignation politique. Le choix entre A et C est tracé dans `profile_template_chosen`.

Plus un cinquième bouton, plus discret mais bien visible : *"Je veux configurer chaque axe en détail"*.

### 5.2 Écran 2 — Configuration détaillée (optionnelle)

Si la personne a cliqué sur "configurer en détail" (ou si elle revient pour ajuster après avoir choisi un profil), un écran avec quatre sections empilées, une par axe.

Chaque section présente l'axe avec :

- une question politique en titre (ex. "Comment se gouverne votre collectif ?") ;
- chaque valeur en option radio, avec sa description complète ;
- les implications de chaque valeur (ex. "Cette option active les workflows de cooptation par unanimité") ;
- les contraintes croisées éventuelles (ex. "Cette valeur n'est compatible qu'avec `governance_mode = staff_roles` ou `full_governance`" — affichée dynamiquement si l'utilisateur·rice tente une combinaison interdite).

### 5.3 Écran 3 — Confirmation et soumission

Récapitulatif des choix sur les quatre axes, en langage politique (pas en valeurs techniques). Bouton "Soumettre la demande".

### 5.4 Champs ajoutés dans `library_signup_requests`

Les quatre `requested_*_mode` listés en §3.1, plus le champ `profile_template_chosen` (`A`/`B`/`C`/`D` ou `custom`) pour traçabilité statistique et auto-désignation politique. Ce champ est purement informatif et n'a pas de portée fonctionnelle après création de la bibliothèque, mais il permet d'analyser dans le temps quels publics adoptent AnarBib.

## 6. Invariants à préserver

Cette spec s'inscrit dans la doctrine du Grand Livre Blanc v13. Les invariants suivants sont à respecter strictement :

**I1 — Continuité d'exploitation.** Le déploiement de la spec ne doit pas casser les 3 biblios en production. Les défauts sur les colonnes nouvelles correspondent à l'état actuel implicite.

**I2 — Réversibilité des migrations.** Toutes les migrations DB doivent être réversibles (DROP CONSTRAINT, DROP COLUMN avec sauvegarde du contenu). Pas de migration destructive.

**I3 — Cohérence par helpers.** Toute logique métier dépendant des axes doit passer par les helpers `fn_library_*_mode()` ou les prédicats `fn_library_has_*()` / `fn_library_publishes_*()`. Pas d'inlining direct des colonnes dans les RLS ou les RPC.

**I4 — Audit immutable.** Toute transition est tracée dans `library_profile_history`, sans possibilité d'UPDATE ni de DELETE.

**I5 — Souveraineté locale.** Aucune transition ne peut être imposée à une bibliothèque depuis l'extérieur. Même les `network_administrator·ices` ne peuvent pas modifier les modes d'une bibliothèque sans son consentement (cohérent avec la doctrine admin réseau).

**I6 — i18n complète.** Tous les libellés nouveaux doivent être fournis dans les 6 locales avant déploiement.

**I7 — Pas de modèle "complet" sacralisé.** L'UX ne doit jamais suggérer qu'un profil est "meilleur" qu'un autre. Pas de checklist "activez ceci pour compléter votre bibliothèque". Pas de score de complétude.

## 7. Interdits

**X1 — Ne pas faire de toggle UI sans backing DB.** Toute fonctionnalité conditionnée par un mode doit être conditionnée à la fois dans l'UI et dans les RLS / RPC. Pas de "masquage cosmétique" sans invariant DB.

**X2 — Ne pas autoriser de transitions silencieuses.** Toute transition doit passer par `fn_propose_library_profile_change(p_library_id, p_axis, p_new_value, p_motivation)` (qui peut soit exécuter directement, soit créer un proposal à voter selon le `governance_mode`), et toute exécution finale passe par `fn_execute_library_profile_change(p_proposal_id)` qui logge dans `library_profile_history`. Pas de modification directe des colonnes `*_mode` autorisée hors de ces fonctions.

**X3 — Ne pas mélanger les axes.** Chaque axe a sa propre sémantique et son propre cycle de transition. Pas de fonction `fn_propose_library_profile_change_full(p_library_id, p_new_profile_template)` qui ferait basculer les quatre axes d'un coup — chaque axe se transitionne individuellement, même si l'UI peut proposer des "templates de transition" qui appellent quatre fois la fonction unitaire.

**X4 — Ne pas confondre `informal` et `off`.** Pour `circulation_mode`, ces deux valeurs sont distinctes : `off` = pas de circulation du tout ; `informal` = circulation light. Les RLS et l'UI doivent les distinguer.

**X5 — Ne pas réintroduire le profil D comme défaut implicite.** Après mise en place de la spec, l'inscription sans choix explicite de profil est interdite. Le formulaire doit forcer un choix.

## 8. Critères d'acceptation pour la spec doctrinale

La spec (sections §1 à §7) est considérée comme adoptée si :

- les quatre axes et leurs valeurs sont validés sans amendement majeur ;
- les profils-types A/B/C/D (avec la fusion A/C au plan technique) sont validés ;
- les combinaisons interdites sont validées ;
- la matrice des transitions §4.2 est validée ;
- le choix de l'option "migration explicite" pour les transitions de type 4 est validé ;
- la cartographie technique §3 est jugée suffisamment précise pour engager les paquets ci-dessous.

Statut au 13 mai 2026 : arbitrages Q1 (retrait contrainte soft governance), Q2 (fusion A/C avec double libellé), Q3 (bandeau non bloquant) intégrés. La spec est prête à devenir un chantier opérationnel.

## 9. Plan de paquets

Le chantier "Profils d'adoption" est découpé en sept paquets de A à G, conçus pour être livrables et testables individuellement. L'ordre proposé respecte le principe de continuité d'exploitation : les paquets initiaux ajoutent l'infrastructure sans rien changer pour les biblios existantes (qui restent en profil D par défaut), les paquets intermédiaires activent les capacités, et le paquet final propose le choix aux biblios existantes.

### 9.1 Paquet A — Infrastructure DB

**Périmètre :** création des colonnes, contraintes, table d'audit et helpers DB.

**Livrables :**
- migration ajoutant les 4 colonnes `*_mode` sur `libraries` (avec DEFAULT correspondant au profil D pour préserver l'état existant) ;
- 2 contraintes CHECK croisées (publication réseau ⇒ network observable, full_sigb ⇒ rôles différenciés) ;
- table `library_profile_history` avec RLS readonly et trigger anti-UPDATE/DELETE ;
- 4 colonnes `requested_*_mode` + `profile_template_chosen` sur `library_signup_requests` (sans CHECK, validation à l'acceptation) ;
- helpers de lecture `fn_library_catalog_mode()`, `fn_library_circulation_mode()`, `fn_library_network_mode()`, `fn_library_governance_mode()` ;
- prédicats `fn_library_has_circulation()`, `fn_library_has_full_sigb()`, `fn_library_publishes_catalog()`, `fn_library_is_federated()`, `fn_library_uses_governance()` ;
- GRANT EXECUTE TO anon, authenticated sur tous les helpers (cf. doctrine exception RLS).

**Critères d'acceptation :**
- migration appliquée via CI Woodpecker, vérification timestamps avant push (cf. discipline migrations) ;
- les 3 biblios en prod (BLMF, BTL, +1) ont automatiquement les valeurs `(network_published, full_sigb, federated, full_governance)` ;
- les 2 contraintes CHECK sont satisfaites par les biblios existantes ;
- un test DO-block en simulé `SET LOCAL ROLE anon` + `SET LOCAL "request.jwt.claims" = '{}'` vérifie que les helpers retournent des valeurs cohérentes ;
- `library_profile_history` rejette tout UPDATE et DELETE (test en simulé authenticated).

**Risques :** faible. Pas de modification fonctionnelle, juste de l'infrastructure dormante.

**Coût estimé :** 1 jour.

### 9.2 Paquet B — Fonctions de transition

**Périmètre :** RPC de transition + tables symétriques D.6 pour les propositions/votes en `full_governance` + jobs pg_cron de carence et de gel.

**Livrables :**
- tables `library_profile_proposals` et `library_profile_votes` (symétriques à celles de cooptation D.6, scope = `library_id` plutôt que réseau) ;
  - `library_profile_proposals` : id, library_id, axis, old_value, new_value, motivation, proposed_by, proposed_at, status (`open`, `accepted_unanimous`, `rejected`, `expired`, `cancelled`), unanimous_at, expires_at (proposed_at + 30j), grace_period_until, completed_at ;
  - `library_profile_votes` : id, proposal_id, voter_id, vote (`for`, `against`), voted_at, rationale_against text NULLABLE ;
  - RLS readonly + INSERT via SECURITY DEFINER uniquement ; immutables (anti-UPDATE et anti-DELETE) ;
- RPC `fn_propose_library_profile_change(p_library_id, p_axis, p_new_value, p_motivation)` :
  - en `governance_mode = informal` ou `staff_roles` pour types 1/2/3 ou type 4 informal : initie directement la transition ;
  - en `governance_mode = staff_roles` pour type 4 : crée un proposal_id et notifie les admins/coords pour vote à la majorité ;
  - en `governance_mode = full_governance` pour type 4 : crée un proposal_id et notifie les autres admins pour vote à l'unanimité ;
- RPC `fn_vote_library_profile_change(p_proposal_id, p_vote, p_rationale_against)` ;
- RPC `fn_revoke_library_profile_transition(p_proposal_id, p_motivation)` (révocation pendant la carence) ;
- helper `fn_classify_transition(p_axis, p_old, p_new)` retournant le type 1/2/3/4 ;
- helper `fn_required_governance_for_transition(p_library_id, p_axis, p_new_value)` retournant le mode de gouvernance applicable (direct / majorité / unanimité / unanimité_élargie pour staff_roles→informal) ;
- exécuteur interne `fn_execute_library_profile_change(p_proposal_id)` appelé soit directement (transitions sans vote), soit à l'atteinte de l'unanimité, soit à l'expiration de la carence ;
- job pg_cron horaire `process_profile_transition_grace` : pour chaque proposal en carence dont `grace_period_until < now()`, appeler l'exécuteur ;
- job pg_cron quotidien `expire_profile_proposals` : pour chaque proposal `open` dont `expires_at < now()`, basculer en `expired` ;
- table `library_profile_grace_locks` : pour matérialiser le gel pendant carence (cf. §4.6) ;
  - `library_id`, `grace_until timestamptz`, `affected_axis text`, `affected_jobs text[]` ;
  - lue par les jobs pg_cron de circulation/gouvernance/réseau pour décider s'ils skip une biblio ;
- handler `team.profile_change_*` dans `notify-event` (6 events) :
  - `proposed`, `voted_for`, `voted_against`, `accepted_unanimous`, `cancelled_by_admin`, `completed_after_grace` ;
- libellés i18n des 6 events × 6 locales.

**Critères d'acceptation :**
- une transition de type 1 sur une biblio en `informal` est effective immédiatement ;
- une transition de type 3 sur `network_mode` insère un lock dans `library_profile_grace_locks`, qui est consulté par le job de refresh de `mv_books_catalog_list_network_v1` ;
- une transition de type 4 `circulation_mode: full_sigb → off` sur biblio en `full_governance` à 3 admins exige 3 votes "for" pour atteindre l'unanimité ;
- pendant la carence, les jobs de rappel mail skip la biblio (testable via une biblio fictive et un prêt avec échéance dans 2 jours) ;
- une révocation pendant la carence restaure l'état antérieur et lève le lock ;
- une proposition expirée à 30j passe en `expired` sans effet ;
- les 6 locales sont complètes pour les 6 events.

**Risques :** moyen-élevé. La logique d'unanimité, de carence et de gel est nouvelle et touche à plusieurs jobs pg_cron existants. Test simulé indispensable.

**Coût estimé :** 3 jours (vs 2 en v0.2, parce que les tables proposals/votes alourdissent le paquet).

**Dépendances :** paquet A.

### 9.3 Paquet C — Conditionnement des RLS et RPC métier

**Périmètre :** intégration des helpers dans les RLS et RPC existantes, sans modifier l'UI.

**Livrables :**
- audit exhaustif des 108 policies RLS pour identifier celles à conditionner (estimation §3.3 : 15-25 policies) ;
- audit des RPC `fn_create_emprestimo_v2`, `fn_create_reserva_v2`, `fn_create_consulta_*`, `fn_renew_my_loan`, etc. : ajout d'une vérification `fn_library_has_circulation()` en début de fonction ;
- audit des handlers Edge Function `emprestimo.*`, `reserva.*`, `consulta.*` dans `notify-event` : NOOP si `circulation_mode = off` ;
- audit des jobs pg_cron de circulation : skip des biblios sans circulation ;
- audit de la vue matérialisée `mv_books_catalog_list_network_v1` : filtre `catalog_mode = 'network_published'` à la construction ;
- audit de `api.libraries_public_v1` et `api.network_overview` : exclusion des biblios `network_mode = isolated` (extension de `fn_library_visible_to_caller`).

**Critères d'acceptation :**
- une biblio basculée en `circulation_mode = off` (via une transition de paquet B) ne peut plus avoir de nouveaux prêts ;
- une biblio basculée en `catalog_mode = local_only` ne remonte plus dans `mv_books_catalog_list_network_v1` après refresh ;
- une biblio basculée en `network_mode = isolated` n'apparaît plus dans `api.libraries_public_v1` ;
- les 3 biblios en prod, en profil D, continuent de fonctionner exactement comme avant ;
- aucune RLS n'inline directement `circulation_mode` ou autre colonne ; toutes passent par les helpers (test grep automatisé en CI).

**Risques :** élevé. C'est le paquet qui modifie le plus de code existant et qui peut casser la prod si une RLS est mal conditionnée. Test en simulé PostgREST obligatoire pour chaque RLS modifiée (`SET LOCAL ROLE` + `SET LOCAL "request.jwt.claims"`).

**Coût estimé :** 3-4 jours.

**Dépendances :** paquet A. Indépendant du paquet B (les RLS sont conditionnées indépendamment des transitions ; en l'absence de B, les modes sont juste fixés par défaut).

### 9.4 Paquet D — Mécanique d'archivage et de masquage

**Périmètre :** support de la mise à l'écart des transactions lors des transitions de type 4. La doctrine distingue **deux mécaniques** complémentaires (cf. §4.1) :
- **archivage** des transactions vivantes (prêts en cours, réservations actives, consultations ouvertes) avec colonne `archived_at` + `archive_reason` ;
- **masquage** des données historiques (prêts retournés, cotisations passées) par filtre dans les vues, sans modification de la donnée.

**Livrables — couche archivage :**
- ajout de colonnes `archived_at timestamptz NULL` et `archive_reason text NULL` sur les tables transactionnelles "vivantes" : `emprestimos`, `reservas`, `consultas`, `interlibrary_loans` (et `cotisations` si la table existe au moment du paquet) ;
- contrainte CHECK : `(archived_at IS NULL) = (archive_reason IS NULL)` (les deux NULL ou les deux non-NULL) ;
- `archive_reason` ∈ ('profile_transition', 'admin_manual', 'system_cleanup') ;
- index partiels `WHERE archived_at IS NULL` pour préserver la performance des requêtes courantes ;
- mise à jour exhaustive des vues `api.my_loans_active_v2`, `api.my_reservations_active_v2`, `api.emprestimo_itens_ui`, `api.emprestimo_lotes_painel_ui`, `api.reserva_itens_followup_ui`, etc. : filtre `WHERE archived_at IS NULL` ;
- nouvelle vue `api.library_archived_transactions(p_library_id)` accessible aux admins de la biblio, listant toutes les transactions archivées avec leurs métadonnées ;
- helper `fn_archive_library_circulation(p_library_id, p_proposal_id)` :
  - marque `archived_at = now()`, `archive_reason = 'profile_transition'` sur tous les `emprestimos.status IN ('active', 'overdue')`, `reservas.status NOT IN ('completed', 'cancelled')`, `consultas.status = 'open'`, `interlibrary_loans.status NOT IN ('completed', 'cancelled')` ;
  - **n'archive PAS** les lignes déjà clôturées (returned, cancelled) — celles-ci relèvent de la couche masquage ;
- helper `fn_unarchive_library_circulation(p_library_id, p_proposal_id)` pour la révocation pendant la carence : restaure `archived_at = NULL` sur toutes les lignes archivées par cette proposition ;
- helper `fn_archive_library_cotisations(p_library_id, p_proposal_id)` pour `full_sigb → informal` (n'archive que les cotisations en cours, pas l'historique des cotisations passées) ;

**Livrables — couche masquage :**
- mise à jour des vues d'historique consultées par le frontend : `api.my_loans_history_v2`, `api.my_reservations_history_v2`, etc. ;
- ajout d'un filtre `WHERE EXISTS (SELECT 1 FROM libraries WHERE libraries.id = <table>.library_id AND libraries.circulation_mode <> 'off')` ;
- **important** : ce filtre est rétroactif et automatique. Si une biblio passe en `circulation_mode = off`, son historique de prêts retournés disparaît des UIs courantes ; si elle revient à `circulation_mode = full_sigb` (ou `informal`), il réapparaît automatiquement ;
- cohérence comptable : `cotisations` historiques ne sont pas masquées (les données financières restent traçables même en mode `off`, accessibles via une vue dédiée `api.library_cotisation_history`).

**Livrables — désarchivage manuel :**
- RPC `fn_unarchive_transaction(p_table_name text, p_record_id uuid, p_motivation text)` accessible aux administrador·as ;
- vérifie que la biblio cible est revenue en `circulation_mode <> 'off'` (refuse sinon) ;
- vérifie que la date d'échéance théorique n'est pas trop ancienne (politique configurable, défaut : refus si `due_at < now() - interval '90 days'`) ;
- INSERT dans une nouvelle table d'audit `library_unarchive_log(library_id, table_name, record_id, unarchived_by, unarchived_at, motivation)` immutable ;
- restaure `archived_at = NULL`, `archive_reason = NULL` ;
- justification : un collectif qui revient à la circulation après 6 mois peut vouloir réactiver les prêts qui étaient en cours, parce que les exemplaires sont toujours physiquement chez les lecteur·rices.

**Critères d'acceptation :**
- l'archivage est réversible pendant la carence (test : initier transition type 4, vérifier état archivé, révoquer, vérifier restauration totale) ;
- l'archivage ne touche pas les transactions déjà clôturées (test : biblio avec 3 prêts actifs + 10 prêts retournés, après transition seuls les 3 actifs ont `archived_at` non-NULL) ;
- les vues d'historique masquent automatiquement les données quand `circulation_mode = off` (test : passage en off, recharger conta d'un usager, vérifier disparition de l'historique ; remettre en informal, vérifier réapparition) ;
- les cotisations historiques restent accessibles via `library_cotisation_history` (test comptabilité) ;
- le désarchivage manuel refuse les transactions trop anciennes (test : passer une biblio en off, attendre simulé 100 jours, repasser en informal, tenter désarchivage d'un prêt avec échéance d'il y a 100j → refus) ;
- les requêtes sur transactions actives restent rapides (test EXPLAIN sur `api.my_loans_active_v2` avant/après ajout d'index partiel : pas de régression).

**Risques :** moyen-élevé. La distinction archivage/masquage est nouvelle, la mise à jour exhaustive des vues est une cible large (estimation : ~10-15 vues à toucher). Test de non-régression sur les biblios en profil D obligatoire.

**Coût estimé :** 3 jours (inchangé par rapport à v0.2 mais avec un périmètre plus clair).

**Dépendances :** paquet B (les transitions de type 4 appellent les helpers d'archivage).

### 9.5 Paquet E — Frontend painel adaptatif

**Périmètre :** adaptation du painel et de quelques pages pour masquer/afficher conditionnellement selon les modes.

**Livrables :**
- enrichissement du `LibraryContext` (déjà existant) avec exposition de `catalogMode`, `circulationMode`, `networkMode`, `governanceMode` ;
- helpers React : `useHasCirculation()`, `useHasFullSigb()`, `usePublishesCatalog()`, `useIsFederated()`, `useUsesGovernance()` ;
- adaptation du composant de navigation painel (sidebar) :
  - onglets Empréstimos, Reservas, Consultas, Leitoras·es, Cotisações : visibles seulement si `circulationMode <> 'off'` ;
  - onglet Cotisações : visible seulement si `circulationMode = 'full_sigb'` ;
  - onglet Rede : visible seulement si `networkMode <> 'isolated'` ;
  - section Cooptação dans onglet Équipe : visible seulement si `governanceMode = 'full_governance'` ;
- adaptation de `BookDetailPage` (livro) :
  - bouton "Réserver" masqué si toutes les biblios qui possèdent l'exemplaire sont en `circulation_mode = off` ;
  - affichage d'un encart "Consultation sur place" pour ces biblios ;
- adaptation de `AccountPage` (conta) :
  - pour un usager dont la biblio est en `circulation_mode = off`, masquer "Mes prêts" et "Mes réservations" ;
  - n'afficher que les préférences personnelles ;
- nouveau composant `LibraryProfileBadge` (compact, affiché en en-tête du painel et sur la page publique de la biblio) ;
- adaptation de `SignupChooseLibraryPage` : afficher le profil de chaque biblio listée avec une mention claire ("Cette bibliothèque ne pratique pas le prêt formalisé", etc.).

**Critères d'acceptation :**
- pour une biblio en profil D, l'UI est strictement identique à l'UI actuelle ;
- pour une biblio en profil A/C (test manuel via transition d'une biblio de test), les onglets attendus sont masqués ;
- aucun "feature flag UI" sans backing DB : impossible d'arriver sur une page masquée par URL directe (les RLS du paquet C ferment l'accès) ;
- le `LibraryProfileBadge` est traduit dans les 6 locales.

**Risques :** moyen. Refonte UI transversale, risque de régression sur les biblios existantes. Tests manuels par profil obligatoires.

**Coût estimé :** 3 jours.

**Dépendances :** paquets A et C (l'UI conditionnelle s'appuie sur les modes lus en DB et la fermeture des RLS).

### 9.6 Paquet F — Onboarding refondu

**Périmètre :** refonte du formulaire de demande de bibliothèque pour intégrer le choix de profil.

**Livrables :**
- adaptation de `fn_submit_library_request` pour accepter les 4 paramètres de profil + `profile_template_chosen` ;
- validation des combinaisons à l'acceptation (refus si combinaison interdite, avec message explicite) ;
- adaptation de `fn_create_library_from_request` pour appliquer les 4 profils à la création ;
- refonte du formulaire frontend `LibraryRequestForm` en 3 écrans (cf. §5) :
  - écran 1 : 4 boutons profils-types (A, C, B, D dans cet ordre, les "légers" en premier) + bouton "Configurer en détail" ;
  - écran 2 : 4 sections empilées, une par axe, avec radios et descriptions politiques ;
  - écran 3 : récapitulatif et soumission ;
- libellés dans les 6 locales (~50 chaînes × 6 = ~300 ajouts, cf. §3.7) ;
- page `LibraryProfileEditPage` accessible depuis le painel pour modifier les profils a posteriori (appelle `fn_propose_library_profile_change` via 4 transitions unitaires si l'usager·e a cliqué sur "Appliquer le profil B" par exemple).

**Critères d'acceptation :**
- l'inscription sans choix de profil est impossible (champ obligatoire) ;
- les combinaisons interdites sont rejetées côté frontend (validation live) et côté backend (CHECK) ;
- les 6 locales sont complètes ;
- le récapitulatif présente les choix en langage politique, pas en valeurs techniques (ex. "Votre bibliothèque pratiquera un système de prêt complet" plutôt que "circulation_mode = full_sigb").

**Risques :** moyen. Modification du parcours d'inscription, partie sensible de l'application. Les 3 biblios en prod ne sont pas concernées par ce paquet (elles ont déjà été créées). Test exhaustif sur le formulaire en environnement de test.

**Coût estimé :** 2-3 jours.

**Dépendances :** paquet A. Indépendant des autres paquets pour l'inscription elle-même, mais `LibraryProfileEditPage` dépend du paquet B (transitions).

### 9.7 Paquet G — Déploiement et migration des biblios existantes

**Périmètre :** déploiement final, bandeau d'information pour les biblios existantes, documentation.

**Livrables :**
- bandeau non bloquant dans le painel des biblios existantes, affiché pendant 30 jours après le déploiement, invitant à "passer en revue le profil de votre bibliothèque" avec lien vers `LibraryProfileEditPage` ;
- libellé du bandeau dans les 6 locales ;
- documentation utilisateur (FAQ ou doc dédiée) : "Qu'est-ce qu'un profil de bibliothèque ?", "Comment changer le profil ?", "Quelles transitions sont réversibles ?" ;
- mise à jour de la documentation interne `docs/spec-profils-bibliotheque.md` en v1.0 (statut "adopté, déployé") ;
- entrée dans le backlog pour le futur chantier inter-bibs : "rappel : `network_mode: federated → observer` doit vérifier l'absence d'emprunts inter-bibs ouverts".

**Critères d'acceptation :**
- les 3 biblios en prod voient le bandeau, peuvent l'ignorer sans pénalité ;
- le bandeau disparaît automatiquement après 30 jours ou après un clic sur "j'ai compris" ;
- la documentation utilisateur est accessible depuis le bandeau et depuis l'aide générale.

**Risques :** faible. Travail de finition.

**Coût estimé :** 1 jour.

**Dépendances :** tous les paquets précédents.

## 10. Dépendances et ordre d'exécution

### 10.1 Graphe de dépendances

```
A (infrastructure DB)
├── B (transitions)
│   └── D (archivage)
├── C (RLS/RPC conditionnés)
│   └── E (frontend painel)
└── F (onboarding)
    └── E peut s'appuyer sur F pour LibraryProfileEditPage

G (déploiement final) dépend de A, B, C, D, E, F.
```

### 10.2 Ordre recommandé

L'ordre proposé minimise les risques de régression et permet des paliers de validation intermédiaires :

| Étape | Paquet | Justification |
|---|---|---|
| 1 | A | Infrastructure dormante, aucun risque sur la prod |
| 2 | C | Conditionnement RLS/RPC. Sans paquet B, les modes restent au défaut D, donc rien ne change fonctionnellement. C'est le moment d'auditer rigoureusement les 108 RLS et de valider que rien ne casse en profil D. |
| 3 | B | Fonctions de transition. Une fois ces fonctions livrées, on peut tester en environnement de test des transitions sur une biblio fictive. |
| 4 | D | Mécanique d'archivage. Nécessaire pour les transitions de type 4. |
| 5 | E | Frontend painel adaptatif. Les biblios en prod restent en profil D, donc l'UI est inchangée pour elles. |
| 6 | F | Onboarding refondu. À ce stade, toute nouvelle biblio s'inscrit avec un profil explicite. |
| 7 | G | Bandeau pour les biblios existantes, documentation, clôture. |

**Note importante :** chaque paquet est livrable et déployable indépendamment. En particulier, on peut s'arrêter après le paquet C si l'on veut figer la doctrine sans encore proposer de transitions ; on peut aussi s'arrêter après F si on veut que les nouvelles biblios choisissent leur profil sans imposer le bandeau aux biblios existantes.

### 10.3 Dépendances avec chantiers en cours

| Chantier | Interaction |
|---|---|
| Admin réseau paquet E (UI) | **Indépendant.** Le paquet E admin réseau et le paquet E profils sont sur des UIs différentes (admin réseau = onglet Rede ; profils = LibraryProfileEditPage). Pas de conflit. |
| Admin réseau paquet F (suppression role administrador local) | **Synergique.** La suppression du rôle local `administrador` (au profit de `network_administrator` transversal) interagit avec le mode `governance_mode = informal` (qui efface aussi la distinction de rôles). Cohérence à préserver : si `governance_mode = informal`, tous les membres sont `librarian` au plan technique mais le frontend n'affiche aucune distinction. |
| Catalogação (refonte) | **Synergique forte.** L'axe `catalog_mode` (local_only vs network_published) prépare la doctrine d'imports/exports et de partage de notices entre bibliothèques. La spec catalogação doit éventuellement intégrer cette distinction (un brouillon en `local_only` ne déclenche pas les workflows réseau de validation collective). À documenter. |
| Cotisations (#33, #36 du backlog) | **Bloquant léger.** Le chantier cotisations doit être conscient que `circulation_mode = informal` n'active pas les cotisations. À prévoir au moment de l'implémentation. |
| Consultas | **Indépendant.** La doctrine consultas est compatible avec les profils : une biblio en `circulation_mode = off` ne fait simplement aucune consultation tracée. |

## 11. Analyse de risques

### 11.1 Risques techniques

| Risque | Probabilité | Gravité | Atténuation |
|---|---|---|---|
| Une RLS du paquet C est mal conditionnée, fermant l'accès à des biblios en profil D | Moyenne | Élevée (coupure de service) | Test simulé PostgREST `SET LOCAL ROLE` + claims pour chaque RLS modifiée, validation en environnement de test avant push |
| Un défaut de cohérence entre l'archivage paquet D et les vues UI provoque des prêts fantômes (visibles mais non actionnables) | Moyenne | Moyenne | Mise à jour exhaustive des vues `api.my_*_active_v2` ET `api.*_history_v2` dans le même paquet ; check-list de ~10-15 vues à mettre à jour |
| Un défaut de cohérence entre l'archivage (transactions vivantes) et le masquage (historique) provoque des comportements incohérents (historique visible mais prêts actifs invisibles, ou inverse) | Moyenne | Moyenne | Doctrine §4.1 et §9.4 explicite : archivage = `archived_at` non-NULL sur lignes actives ; masquage = filtre `WHERE library.circulation_mode <> 'off'` sur vues d'historique. Test exhaustif des transitions aller-retour. |
| Une transition de type 4 est validée alors qu'unanimité requise n'est pas atteinte | Faible | Moyenne (politiquement problématique) | L'exécuteur `fn_execute_library_profile_change` vérifie l'état du proposal (`status = 'accepted_unanimous'` ou directe selon le mode) avant exécution. Aucune voie d'exécution alternative. |
| Un job pg_cron ignore le gel et exécute des actions sur une biblio en carence | Moyenne | Moyenne | Chaque job consultant `library_profile_grace_locks` avant traitement (cf. §4.6). Test unitaire par job. |
| Le désarchivage manuel d'un prêt très ancien crée une incohérence (l'exemplaire a peut-être été redéployé) | Faible | Moyenne | Politique défaut : refus si échéance théorique de plus de 90j dans le passé. Configurable par biblio. Audit dans `library_unarchive_log`. |
| Un défaut de cohérence i18n (chaîne manquante dans une des 6 locales) casse le formulaire d'inscription | Moyenne | Faible (fallback pt-BR fonctionne) | Linter i18n CI obligatoire avant push, conformément à la pratique projet |
| La migration paquet A applique un DEFAULT contradictoire avec une biblio existante mal configurée | Faible | Faible | Audit préalable des 3 biblios en prod : vérifier qu'aucune `visibility_level` ne contredise les défauts paquet A |

### 11.2 Risques doctrinaux

| Risque | Probabilité | Gravité | Atténuation |
|---|---|---|---|
| Les profils-types A/B/C/D ne couvrent pas un cas d'usage non anticipé qui apparaîtrait après déploiement | Moyenne | Faible | Les axes étant orthogonaux, n'importe quelle combinaison valide (modulo les 2 contraintes CHECK) est accessible via le mode "configuration détaillée". Le risque n'est pas l'impossibilité technique mais l'inconfort UX si beaucoup de cas tombent en "custom". |
| Une biblio bascule en `circulation_mode = off` par erreur ou suite à un conflit interne | Faible | Élevée | Carence 48h + notification obligatoire à tous les membres staff + possibilité de révocation pendant la carence (cf. §4.5). En `full_governance`, unanimité requise. |
| En `governance_mode = informal`, un·e seul·e membre staff initie une transition de type 4 sans que les autres y prêtent attention dans les 48h | Faible | Moyenne | Notification mail + bandeau visible dans le painel pendant la carence. Délai 48h jugé suffisant pour que la majorité des collectifs réagissent. |
| Le cas particulier `staff_roles → informal` (perte des rôles auto-validants) est mal géré et permet une perte de gouvernance unilatérale | Faible | Élevée | Doctrine §4.5.6 : carence 7j + unanimité élargie admins+coords + état préservé pendant la carence. À tester rigoureusement au paquet B. |
| Le bandeau du paquet G pousse les biblios existantes à se ré-interroger et certaines décident de basculer en profil dégradé, créant un sentiment de "perte" pour certains membres | Moyenne | Faible (politique) | Le bandeau est neutre dans sa formulation, n'incite ni à élargir ni à réduire. |
| L'inflation de chaînes i18n (~350 en v0.3) ralentit les autres chantiers | Faible | Faible | Découpage en deux vagues : core (axes, valeurs, profils, events transition) en paquet F ; descriptions politiques détaillées en paquet G. |

### 11.3 Risques d'éparpillement

Le chantier "Profils d'adoption" est transversal : il touche DB, RLS, RPC, Edge Functions, frontend painel, frontend onboarding, i18n. Le risque d'éparpillement est réel, surtout en concurrence avec le paquet F admin réseau et les chantiers cotisations.

**Mesure d'atténuation principale :** ne pas démarrer ce chantier tant que le paquet F admin réseau (suppression du rôle local `administrador`) n'est pas validé. Une fois admin réseau clos, ce chantier peut prendre la priorité, avec un objectif de bouclage en 2 semaines (≈ 14 jours développeur étalés sur ~3 semaines calendaires).

## 12. Grille de tests fonctionnels par profil

Pour valider que la spec est correctement implémentée, les tests suivants doivent être passés en environnement de test avec 4 biblios fictives, une par profil :

### 12.1 Tests pour le profil A/C (athénée OPAC / collectif contributeur)

- création d'une biblio test_A en profil A via le formulaire d'onboarding ;
- vérifier que les onglets Empréstimos, Reservas, Consultas, Leitoras·es, Cotisações sont absents du painel ;
- vérifier que l'onglet Rede est présent (network_mode = federated) ;
- vérifier que la section Cooptação dans Équipe est absente (governance_mode = informal) ;
- tenter d'appeler `fn_create_emprestimo_v2` sur cette biblio en tant qu'admin → doit échouer avec message explicite ;
- vérifier que les notices de test_A apparaissent dans `mv_books_catalog_list_network_v1` après refresh ;
- vérifier que test_A apparaît dans `api.libraries_public_v1` ;
- inscrire un·e usager·e à test_A : vérifier que sa page conta ne montre pas "Mes prêts" ni "Mes réservations".

### 12.2 Tests pour le profil B (bibliothèque souveraine)

- création d'une biblio test_B en profil B avec network_mode = isolated ;
- vérifier que test_B n'apparaît pas dans `api.libraries_public_v1` ni dans `api.network_overview` ;
- vérifier que les notices de test_B n'apparaissent pas dans `mv_books_catalog_list_network_v1` ;
- vérifier que l'onglet Rede est absent du painel ;
- créer un prêt sur test_B : vérifier que tout fonctionne normalement (circulation_mode = full_sigb) ;
- transition test_B vers network_mode = observer : vérifier le passage du paquet C (helpers retournent les nouvelles valeurs) et l'absence de panique dans l'UI.

### 12.3 Tests pour le profil D (bibliothèque complète)

- les 3 biblios en prod sont en profil D : tous les tests de non-régression existants doivent passer ;
- tester une transition test_D vers `circulation_mode: full_sigb → informal` avec des prêts ouverts : vérifier l'archivage des cotisations, la conservation des prêts simples, la confirmation explicite UX.

### 12.4 Tests de transitions

- transition de type 1 (élargissement) : test_A → ajout de `circulation_mode = informal`, doit être immédiate ;
- transition de type 3 (rétractation douce) : test_D → `catalog_mode = local_only`, doit être en carence 24h, refresh mv_network après carence ;
- transition de type 4 en `full_governance` : test_D → `circulation_mode = off` avec prêts ouverts. Doit créer un proposal, exiger unanimité des admins, archiver à l'expiration de la carence 48h post-unanimité ;
- transition de type 4 en `staff_roles` : test_D bascule en `staff_roles` puis tente `full_sigb → informal`. Doit exiger majorité simple des admins+coords ;
- transition de type 4 en `informal` : test_A initie `informal → off`. Doit attendre 48h sans révocation, alors exécuter ;
- révocation de transition pendant la carence : un·e deuxième administrador·a annule, doit restaurer l'état antérieur (archivage non encore exécuté, donc rien à désarchiver) ;
- transition refusée par contrainte CHECK : tenter `catalog_mode = network_published` alors que `network_mode = isolated` doit échouer avec message clair ;
- transition refusée par propositions en cours : tenter `full_governance → staff_roles` alors qu'une proposition de cooptation est ouverte doit échouer ;
- cas particulier `staff_roles → informal` : doit exiger unanimité admins+coords + carence 7j ;
- expiration : créer une proposition, ne pas la voter pendant 30j, vérifier passage en `expired` automatique.

### 12.5 Tests de gel pendant carence (§4.6)

- créer test_D avec un prêt dont l'échéance est dans 2 jours ;
- initier transition `circulation_mode: full_sigb → off` (validation unanimité instantanée si test_D a 1 seul admin, sinon vote complet) ;
- pendant la carence 48h, vérifier que :
  - le job `handleEmprestimoV2Reminder` skip ce prêt (pas de mail J-2 envoyé) ;
  - le job `expire_solicitada` skip test_D ;
  - le job `pending_removal_complete` skip les membres de test_D (si applicable) ;
- vérifier que les actions humaines restent possibles : un·e librarian enregistre un retour pendant la carence → doit fonctionner ;
- après expiration : l'archivage s'exécute, le prêt actif passe `archived_at` non-NULL.

### 12.6 Tests d'archivage et de masquage

- test_D avec 5 prêts actifs et 20 prêts retournés ;
- transition vers `circulation_mode = off`, attendre fin de carence et exécution ;
- vérifier : les 5 prêts actifs ont `archived_at` non-NULL avec `archive_reason = 'profile_transition'` ;
- vérifier : les 20 prêts retournés n'ont **pas** été modifiés en base ;
- vérifier : la page conta d'un usager qui avait un prêt actif ne montre plus rien (archivage masque les actifs) ;
- vérifier : la page conta d'un usager qui n'avait que des prêts retournés ne montre plus son historique (masquage des historiques) ;
- vérifier : `api.library_archived_transactions(test_D_id)` retourne bien les 5 prêts archivés ;
- vérifier : `api.library_cotisation_history(test_D_id)` reste accessible ;
- repasser test_D en `circulation_mode = informal` ;
- vérifier : l'historique des 20 prêts retournés réapparaît dans conta (masquage levé automatiquement) ;
- vérifier : les 5 prêts archivés ne réapparaissent pas (politique : pas de désarchivage automatique) ;
- depuis le painel admin, désarchiver manuellement un des 5 prêts via `fn_unarchive_transaction` → succès, INSERT dans `library_unarchive_log` ;
- tenter de désarchiver un prêt dont l'échéance théorique est de plus de 90j dans le passé → refus avec message explicite.

### 12.7 Tests d'invariants

- vérifier que `library_profile_history`, `library_profile_proposals`, `library_profile_votes`, `library_unarchive_log` rejettent tout UPDATE et DELETE (test simulé authenticated) ;
- vérifier que toute modification des colonnes `*_mode` hors de `fn_execute_library_profile_change` est refusée (RLS UPDATE sur ces colonnes) ;
- vérifier qu'aucune RLS modifiée n'inline directement une colonne `*_mode` (grep automatisé sur la base) ;
- vérifier que les 6 locales sont strictement uniformes en nombre de clés après paquet F ;
- vérifier que les contraintes CHECK croisées (publication ⇒ network observable, full_sigb ⇒ rôles différenciés) refusent les UPDATE qui les violeraient.

## 13. Récapitulatif chiffré

| Métrique | Valeur estimée |
|---|---|
| Paquets | 7 (A à G) |
| Coût total estimé | ≈ 16 jours développeur (révisé v0.3 : +2j paquets B et D affinés) |
| Coût étalé calendaire | ≈ 3-4 semaines |
| Tables modifiées | 2 (`libraries`, `library_signup_requests`) + ~5 tables transactionnelles avec ajout `archived_at` + `archive_reason` |
| Tables créées | 5 (`library_profile_history`, `library_profile_proposals`, `library_profile_votes`, `library_profile_grace_locks`, `library_unarchive_log`) |
| Colonnes ajoutées | ~16 |
| Helpers DB créés | 11 (`fn_library_*_mode` ×4, prédicats ×5, `fn_classify_transition`, `fn_required_governance_for_transition`) |
| Fonctions RPC créées/modifiées | ~9 (propose + vote + revoke + execute + unarchive + archive_circulation + archive_cotisations + signup + create_from_request) |
| RLS impactées | 15-25 (sur 108) |
| Vues impactées | ~10-15 (libraries_public_v1, network_overview, mv_network, library_circulation_stats, ~6 vues conta active, ~6 vues conta history, vues painel) |
| Edge Functions handlers impactés | 4 familles existantes (emprestimo, reserva, consulta) + 1 famille nouvelle (team.profile_change_* avec 6 events) |
| Jobs pg_cron modifiés | 5+ (consultation de `library_profile_grace_locks` par les jobs de circulation, gouvernance, refresh mv_network) |
| Jobs pg_cron créés | 2 (`process_profile_transition_grace` horaire, `expire_profile_proposals` quotidien) |
| Chaînes i18n ajoutées | ~60 × 6 locales = ~360 (révisé v0.3 : +60 pour events de proposition/vote/exécution) |
| Composants frontend nouveaux | 3 (LibraryProfileBadge, LibraryProfileEditPage, écrans onboarding) + composants de vote/proposition pour transitions type 4 |
| Composants frontend modifiés | 5+ (PainelPage, BookDetailPage, AccountPage, LibraryRequestForm, SignupChooseLibraryPage) |

---

*Fin v0.3 — spec opérationnelle, prête à être commitée et à devenir un chantier après clôture du paquet F admin réseau.*
