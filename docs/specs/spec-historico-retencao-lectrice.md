# Spec — Maîtrise lectrice de la rétention de son historique

**Version** : 1.0
**Date** : 31/05/2026
**Statut** : Doctrine arrêtée — implémentation à venir
**Réfère à** : #CL.8 du méga-item conta, cahier Dunkerque §2.8
**Auteur·rice·s** : Xavier (CCLA) + Claude

---

## 1. Introduction

Le compte lectrice expose un onglet « Histórico » qui liste les emprunts passés
(et, à terme, les réservations et consultations passées). Aujourd'hui, cette
liste est subie : la lectrice voit tout ce qui n'a pas encore été purgé par la
politique de rétention de la biblio. Elle ne peut ni masquer une ligne
embarrassante, ni renoncer à conserver cet historique au-delà du strict
nécessaire.

Cette spec donne à la lectrice **une marge d'action explicite** sur la
visibilité et la conservation de ses propres traces, tout en préservant la
mémoire métier dont la biblio a besoin pour son fonctionnement collectif.

L'esprit de cette doctrine est celui que le cahier Dunkerque §2.8 résume :
*sobriété et autonomie*. La lectrice n'est pas l'objet d'un suivi qu'elle
subit ; elle est sujet d'une trace dont elle conserve une part de souveraineté.

## 2. Doctrines de référence

Cette spec s'inscrit dans la cohérence des doctrines déjà actées dans le
projet, qu'elle ne remet pas en cause mais qu'elle étend au domaine spécifique
de la rétention historique.

**Doctrine de la souveraineté biblio** (Position 1, actée 31/05/2026 matin
dans `spec-notifications-lecteur.md` §5). La biblio est souveraine sur les
politiques globales qui touchent à sa mission métier — y compris la rétention
RGPD. La lectrice peut ajuster *à la baisse* sa propre visibilité, mais ne
peut pas allonger ce que la biblio conserve.

**Doctrine de validation par-appartenance** (β.1/γ.1, actée 30/05/2026 dans
`DECISION_validation_par_appartenance_2026-05-30.md`). Les droits de la
lectrice se déclinent par biblio d'appartenance. Mais l'historique consulté
côté lectrice agrège tous ses emprunts toutes biblios confondues — ce qui
soulève la question de la coordination des préférences de rétention quand la
lectrice est membre de plusieurs biblios. Cette spec tranche : la préférence
de rétention est **par biblio**, pas globale.

**Doctrine de la mémoire collective non-occulte** (présente spec, §4.3).
La biblio garde mémoire de ses circulations à des fins légitimes (litiges,
statistiques agrégées, continuité métier). Mais elle ne cache pas à la
lectrice ce qu'elle voit, et la lectrice ne cache pas à la biblio ce qu'elle
fait (les masquages côté lectrice restent visibles côté staff avec un
marqueur). Pas d'asymétrie occulte des deux côtés.

**Doctrine de la rétention RGPD** (`fn_get_retention_policy` / `fn_purge_expired_data`
en production). La biblio définit une durée maximale de conservation par
catégorie (loans/reservations/consultations/notifications). Cette durée est
un plafond légal, pas un plancher : la lectrice peut faire purger *plus tôt*
ce qui la concerne, mais la biblio purgera de toute façon au-delà.

## 3. Périmètre et hors-périmètre

### 3.1 Dans le périmètre

- Masquage et suppression d'une ligne d'historique par la lectrice, dans
  les **trois domaines** : emprunts passés, réservations passées,
  consultations locales passées. La même doctrine s'applique aux trois
  domaines avec une UX cohérente.
- Désactivation prospective de la conservation de l'historique, par domaine
  (la lectrice peut désactiver la conservation de ses emprunts mais conserver
  celle de ses consultations, par exemple).
- Affichage clair de la politique de rétention biblio dans les onglets
  concernés (a minima `historico`, qui regroupe ces traces côté conta).
- Articulation avec le staff côté painel (marqueur visuel « masqué par la
  lectrice »).
- Articulation avec la rétention RGPD existante (additive, pas conflictuelle ;
  les trois domaines sont déjà couverts par `fn_purge_expired_data` et le
  préavis e-mail livré aujourd'hui).
- Articulation avec les statistiques agrégées biblio (cf. §4.5).

### 3.2 Hors périmètre

- **Masquage de l'identité lectrice côté staff** : on ne masque pas une
  lectrice complète à la biblio — ce serait contraire à la mission de
  circulation. On masque des lignes d'historique de cette lectrice.
- **Effet sur les notifications** : les notifications passées
  (`user_notifications`) ont leur propre cycle de vie (archivage #CL.6, purge
  RGPD séparée). Elles ne sont pas affectées par la rétention historique
  d'emprunt/réservation/consultation.
- **Politique RGPD biblio** : modifier la durée de rétention biblio reste
  une prérogative staff, hors champ de cette spec.
- **Historique cross-domaine agrégé** (par exemple « tous mes emprunts ET
  réservations de telle biblio en 2025 ») : pas couvert par cette spec, qui
  traite chaque domaine indépendamment.

### 3.3 Statut d'implémentation au moment de la rédaction

Aucune ligne de code n'existe aujourd'hui pour cette doctrine côté frontend
ou côté backend. La spec est rédigée *avant* tout livrable, ce qui est l'inverse
du flux habituel (livrer puis documenter). Cette précédence doctrinale est
volontaire : la rétention historique touche aux libertés de la lectrice et
demande une articulation soigneuse avec la souveraineté biblio. Mieux vaut
écrire la doctrine d'abord et laisser l'implémentation s'y plier que de
construire un mécanisme ad-hoc qui obligerait à inventer la doctrine après
coup.

## 4. Décisions doctrinales

Cette section formalise les neuf principes qui structurent la doctrine. Chaque
principe a été tranché en cadrage préalable et est référencé dans la suite
de la spec.

### 4.1 Principe D.1 — Granularité de l'action lectrice

La lectrice peut agir à **deux granularités** :

- **par ligne individuelle** : un emprunt, une réservation ou une
  consultation passée prise isolément, identifié par son `id` en base. La
  lectrice ne masque/supprime pas un item d'un emprunt multi-items
  séparément : la granularité minimale est l'objet métier complet (un
  emprunt entier, une réservation entière, une consultation entière).
- **désactivation prospective globale par domaine** : la lectrice peut
  déclarer qu'elle ne souhaite plus conserver son historique pour un domaine
  donné (par exemple « ne conserve plus mes emprunts futurs »). Cette
  déclaration n'affecte pas le passé, qui reste géré ligne par ligne ; elle
  marque les nouveaux objets de ce domaine comme automatiquement masqués
  à leur clôture.

Les granularités intermédiaires (par période, par biblio en masse, « tout
purger ») sont **hors périmètre v1**. Si elles s'avèrent demandées par
l'usage, elles pourront être ajoutées dans une révision.

### 4.2 Principe D.2 — Deux opérations distinctes : masquer et supprimer

**Masquer** est une opération légère et réversible. La ligne reste en base
avec un drapeau `is_hidden_by_user = true` et un horodatage `hidden_at`. Elle
disparaît de la vue lectrice par défaut, mais reste accessible via une bascule
explicite (« afficher les lignes masquées »). Le staff continue de la voir
côté painel, avec un marqueur (cf. D.3).

**Supprimer** est une opération lourde et irréversible. La ligne est purgée
de la base — soit physiquement (`DELETE`), soit logiquement (drapeau
`deleted_by_user_at` qui exclut de toute lecture y compris staff, avec
purge physique différée). Cette spec retient le **DELETE physique** pour
être cohérente avec la promesse faite à la lectrice (« cette suppression
est définitive »).

L'UI distingue les deux par leur poids visuel : masquer est une icône
discrète accessible directement, supprimer demande une confirmation textuelle
explicite et avertit du caractère irréversible.

### 4.3 Principe D.3 — Mémoire collective non-occulte côté staff

Le staff côté painel **voit toujours** les lignes masquées par la lectrice,
**avec un marqueur visuel explicite** indiquant que la lectrice a exercé son
droit de masquage (icône, badge, ou mention type « masqué par la lectrice
le DD/MM »). Pas de mémoire occulte de la biblio sur la lectrice ; pas non
plus de retrait total qui priverait la biblio de sa continuité métier.

Les lignes **supprimées** par la lectrice, en revanche, sortent
définitivement de toutes les vues (lectrice, staff, statistiques) puisqu'elles
n'existent plus en base. C'est la mécanique du DELETE physique retenu en
D.2.

Cette doctrine se résume en deux propositions :

1. La biblio garde mémoire de ce que la lectrice n'efface pas.
2. La biblio sait quand la lectrice masque, ne le devine pas par déduction.

### 4.4 Principe D.4 — Articulation avec la rétention RGPD biblio

La rétention RGPD biblio (table `library_retention_policies`, fonction
`fn_purge_expired_data`) définit une **durée maximale** de conservation par
domaine. Cette durée est un plafond légal, pas un plancher négociable.

L'articulation est purement cumulative, sans conflit :

- Si la lectrice a **masqué** une ligne, la purge RGPD biblio la supprime
  quand même quand son terme arrive. Le masquage n'est pas un sursis légal.
- Si la lectrice a **supprimé** une ligne, elle n'existe plus en base —
  la purge RGPD biblio n'a rien à supprimer.
- Si la lectrice n'a **rien fait**, la purge RGPD biblio s'applique
  normalement, et la lectrice est avertie au préalable via le préavis
  e-mail + in-app (chantier §7.1 livré 31/05/2026).

Résumé doctrinal : *la lectrice peut accélérer ou réduire la visibilité de
ses traces, la biblio a la souveraineté finale sur la durée maximale de
conservation*.

### 4.5 Principe D.5 — Statistiques agrégées biblio

Les statistiques que la biblio tire de son activité de circulation (nombre
total d'emprunts, durée moyenne, retards, etc.) reflètent ce qui **existe
en base** :

- Les lignes **masquées** sont comptées dans les stats (elles existent
  toujours en base, juste invisibles côté lectrice).
- Les lignes **supprimées** ne sont pas comptées (elles n'existent plus).

Cette règle a une conséquence importante : la suppression par la lectrice
*réduit effectivement* la mémoire collective. C'est cohérent avec la
doctrine de sobriété — la lectrice qui supprime accepte de réduire la
mémoire qu'elle laisse au commun, et la biblio l'accepte comme un coût
légitime de l'autonomie lectrice.

### 4.6 Principe D.6 — Affichage de la politique de conservation

Chaque onglet concerné de la conta lectrice (a minima `historico`) affiche
en bandeau permanent et lisible la politique de rétention biblio applicable :
durée par domaine, date approximative de prochaine purge si calculable. Pas
de mention enfouie en pied de page, pas de lien vers une autre page —
l'information est là où la lectrice consulte ses traces et agit dessus.

Le ton de cet affichage est **pédagogique**, pas juridique : un encart
court qui explique simplement ce qui sera purgé et quand, sans copier la
politique entière.

### 4.7 Principe D.7 — Désactivation prospective non rétroactive

Le bouton « ne plus conserver mon historique de [domaine] » n'a **pas**
d'effet rétroactif. Il marque les **nouveaux** objets de ce domaine comme
automatiquement masqués à leur clôture (passage à un état terminal du
workflow). Le passé reste géré ligne par ligne via les actions D.1.

Un bouton complémentaire séparé, plus explicite (« supprimer tout mon
historique passé de [domaine] »), permet à la lectrice de **purger
rétroactivement**. Ce bouton est un raccourci pour ne pas obliger la
lectrice à supprimer ligne par ligne ; il n'introduit pas de doctrine
nouvelle, juste un confort opérationnel. Il demande une confirmation
explicite vu son caractère destructif.

Cette séparation des deux gestes prévient le piège classique : une lectrice
qui cliquerait par curiosité sur « désactiver la conservation » et verrait
soudain son historique entier disparaître alors que ce n'était pas son
intention.

### 4.8 Principe D.8 — Réversibilité du masquage

Une ligne masquée par la lectrice peut être **ré-affichée** par elle à
tout moment :

- L'onglet `historico` propose une bascule « afficher les lignes masquées ».
  Quand activée, les lignes masquées réapparaissent dans la liste, avec un
  marqueur visuel discret (icône œil barré).
- Sur une ligne masquée, un bouton « réafficher » la fait basculer en
  visible (`is_hidden_by_user = false`, `hidden_at = null`).

La **suppression** est par construction irréversible et ne dispose pas de
mécanisme symétrique.

Cette asymétrie est un signal de confiance : la lectrice peut masquer sans
crainte de se tromper, parce que c'est annulable. Elle ne supprime qu'après
avoir confirmé qu'elle accepte l'irréversibilité.

### 4.9 Principe D.9 — Préférences par biblio, pas globales

Lorsqu'une lectrice est membre de plusieurs biblios (cf.
`spec-multi-appartenance-lecteur` à venir), ses préférences de rétention
s'appliquent **par biblio**. Une lectrice peut conserver son historique
chez sa biblio principale et le désactiver chez une biblio où elle ne va
qu'occasionnellement.

Cette granularité par biblio est cohérente avec la doctrine de validation
par-appartenance déjà actée. La lectrice n'est pas un sujet uniforme face
au réseau, mais une multiplicité d'appartenances dont chacune a sa propre
relation à la biblio.

En pratique, la table de préférences (cf. §5) porte une clé composée
`(user_id, library_id, domain)` et une rangée par combinaison.

## 5. Modèle technique indicatif

Cette section propose un schéma technique qui matérialise la doctrine de §4.
Il est **indicatif** — l'implémentation peut le réviser tant que la doctrine
est respectée. Il sert à valider que la doctrine est implémentable, pas à
contraindre les décisions d'architecture à venir.

### 5.1 Colonnes ajoutées aux tables existantes

Sur chacune des trois tables racines d'historique (`emprestimos_v2`,
`reservas_v2`, `consultas_locais_v2`), on ajoute deux colonnes nullables :

```sql
ALTER TABLE public.emprestimos_v2
  ADD COLUMN is_hidden_by_user boolean NOT NULL DEFAULT false,
  ADD COLUMN hidden_at timestamptz;
-- idem pour reservas_v2 et consultas_locais_v2
```

Sémantique :

- `is_hidden_by_user = false` (défaut) : la lectrice voit la ligne dans sa
  conta. C'est le comportement actuel pour toutes les lignes existantes —
  la migration n'invalide rien.
- `is_hidden_by_user = true` : la lectrice ne voit pas la ligne dans sa conta
  par défaut. Le staff la voit côté painel avec un marqueur (cf. D.3).
- `hidden_at` : horodatage du dernier masquage, utilisé pour l'affichage staff
  (« masqué par la lectrice le DD/MM ») et pour audit.

Pas de colonne `deleted_*` — la suppression est un DELETE physique (cf. D.2
et §3.3 du présent verdict technique).

### 5.2 Table de préférences par biblio

Une nouvelle table porte les **préférences prospectives de non-conservation
par biblio et par domaine** :

```sql
CREATE TABLE public.user_history_retention_preferences (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  library_id uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  domain text NOT NULL CHECK (domain IN ('loans', 'reservations', 'consultations')),
  disable_retention boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, library_id, domain)
);
```

Sémantique :

- Absence de rangée pour un `(user_id, library_id, domain)` = comportement
  par défaut, la conservation reste active. La lectrice ne perd rien si elle
  n'a jamais touché à cette préférence.
- `disable_retention = true` : les **nouveaux objets** de ce domaine pour
  cette biblio seront automatiquement marqués `is_hidden_by_user = true` à
  leur clôture (passage à un état terminal). Aucun effet rétroactif (D.7).
- `disable_retention = false` (ou rangée absente) : comportement par défaut.

Doctrine de table : **Scénario C** (cf.
`CHANTIER_doctrine_creation_objets_securises_2026-05-12.md`, Template 2).
Table hors Data API, manipulée uniquement par RPC SECURITY DEFINER. REVOKE
explicite, GRANT à `service_role` seul, RLS lock-down.

### 5.3 RPC exposées au frontend

Quatre RPC, toutes en SECURITY DEFINER, REVOKE/GRANT explicites pour
`authenticated` :

```sql
-- Masquer une ligne d'historique
fn_hide_history_item(p_domain text, p_record_id bigint) → void

-- Réafficher une ligne précédemment masquée
fn_unhide_history_item(p_domain text, p_record_id bigint) → void

-- Supprimer définitivement une ligne d'historique
fn_delete_history_item(p_domain text, p_record_id bigint) → void

-- Lire et modifier les préférences prospectives
fn_get_my_retention_preferences() → table(library_id uuid, domain text, disable_retention boolean)
fn_set_my_retention_preference(p_library_id uuid, p_domain text, p_disable boolean) → void

-- Action de masse facultative (D.7) : supprimer tout l'historique passé d'un domaine pour une biblio
fn_delete_all_my_history(p_library_id uuid, p_domain text) → integer  -- retourne le nb supprimé
```

Toutes les RPC vérifient `auth.uid()` et filtrent par `user_id` du record cible.
La RPC `fn_delete_all_my_history` retourne le nombre de lignes affectées pour
permettre à l'UI d'afficher une confirmation a posteriori (« 47 emprunts
supprimés »).

Les RPC `fn_hide_history_item` et `fn_delete_history_item` n'agissent que sur
des lignes en **état terminal** (un emprunt en cours ne peut pas être masqué ;
une réservation active ne peut pas être supprimée). La doctrine de granularité
D.1 s'applique à l'historique, pas à la circulation en cours.

### 5.4 Trigger de masquage automatique prospectif

Un trigger AFTER UPDATE sur `emprestimos_v2.status_global` (et équivalents
pour réservations et consultations) détecte le passage à un état terminal,
consulte `user_history_retention_preferences` pour cette lectrice et cette
biblio, et marque `is_hidden_by_user = true` si la préférence est désactivée.

```sql
CREATE TRIGGER trg_auto_hide_on_close
  AFTER UPDATE ON public.emprestimos_v2
  FOR EACH ROW
  WHEN (NEW.status_global = 'encerrado' AND OLD.status_global IS DISTINCT FROM NEW.status_global)
  EXECUTE FUNCTION public.fn_auto_hide_on_close();
```

La fonction `fn_auto_hide_on_close` lit la préférence et fait l'UPDATE
silencieusement si applicable. Pas de notification associée — c'est le
comportement prospectif demandé par la lectrice, pas un événement nouveau.

### 5.5 Lectures côté staff

Les vues et fonctions painel qui lisent l'historique d'une lectrice
(emprunts passés, réservations passées, consultations passées) conservent
toutes les lignes — y compris masquées. Elles **ajoutent** simplement la
colonne `is_hidden_by_user` à leur projection. Le frontend painel se charge
de l'affichage du marqueur visuel (badge « masqué par la lectrice »).

Aucune migration de RPC staff n'est strictement nécessaire si les RPC
projetaient déjà `SELECT *` ou explicitement toutes les colonnes — il suffit
d'ajouter le rendu côté painel.

### 5.6 Lectures côté lectrice

Les fonctions qui alimentent la conta lectrice (`my_loans_history_v1` ou
équivalent) sont modifiées pour **filtrer par défaut** `is_hidden_by_user = false`.
Un paramètre booléen optionnel `p_include_hidden` permet la bascule
« afficher les lignes masquées » côté UI :

```sql
fn_my_history(p_domain text, p_include_hidden boolean DEFAULT false) → table(...)
```

Quand `p_include_hidden = true`, les lignes masquées sont retournées avec
leur drapeau, et le frontend les affiche avec un style discret (œil barré,
opacité réduite) et un bouton « réafficher ».


## 6. UX et écrans

Cette section décrit l'expérience utilisatrice attendue. Les choix visuels
précis (icônes, palette, micro-copy) restent à la main de l'implémentation,
mais les invariants doctrinaux suivants doivent être respectés.

### 6.1 Bandeau de politique de rétention

En tête de l'onglet `historico` (et, si le contenu y est groupé, aussi
dans les sections réservations passées et consultations passées), un
encart pédagogique permanent et discret affiche la politique applicable :

> Esta biblioteca conserva teu histórico durante **N dias**. Após esse
> prazo, é apagado automaticamente.

Si la lectrice est membre de plusieurs biblios actives, le bandeau s'adapte
ou se duplique pour rendre la rétention de chaque biblio lisible. Le ton
reste pédagogique, jamais juridique. Pas de lien externe, pas de mention de
loi ou de règlement — la lectrice doit comprendre en lisant la phrase elle-même.

### 6.2 Affichage par défaut de l'historique

Une ligne d'historique se présente comme aujourd'hui (titre, auteur,
dates, état terminal). À la différence d'aujourd'hui, deux actions discrètes
sont accessibles par ligne :

- Une icône **œil barré** (action *masquer*) — clic direct, pas de
  confirmation. Si la lectrice se trompe, le masquage est réversible.
  Tooltip : « Ocultar este registro do teu histórico ».
- Un bouton **plus formel** (action *supprimer*) — accessible derrière un
  menu contextuel léger ou un bouton secondaire. Clic → modale de confirmation
  avec texte explicite : « Esta exclusão é definitiva. O registro será
  apagado da base e não poderá ser recuperado. Tens certeza ? ».

Les deux actions ne sont disponibles **que sur les lignes en état terminal**
(garde-fou §5.3). Sur les lignes en cours, ni icône ni bouton.

### 6.3 Bascule des lignes masquées

En haut de la liste, une bascule discrète : « Mostrar registros ocultos
(N) ». Le compteur N reflète le nombre de lignes masquées par la lectrice
(pas affiché si N = 0). Activation → les lignes masquées réapparaissent
dans la liste à leur position chronologique, avec :

- Opacité réduite (50% suffit, à affiner).
- Icône **œil barré** présente, mais en couleur active pour signaler que
  c'est une ligne masquée.
- Bouton **réafficher** explicite (« Mostrar de novo »).

La bascule est purement frontend (paramètre `p_include_hidden = true` passé
à la RPC) — pas de préférence persistée. Chaque chargement de l'onglet
revient à la vue par défaut.

### 6.4 Bloc « Préférences de conservation »

Dans l'onglet `perfil`, sous le bloc « Préférences de notification » déjà
livré le 31/05/2026, un nouveau bloc « Préférences de conservation » expose :

- Un encart pédagogique court : « Tu podes pedir para a biblioteca não
  conservar mais teu histórico nesta categoria. Os novos registros serão
  ocultos automaticamente. Os registros antigos ficam acessíveis pelas
  ações da página Histórico. »
- Si la lectrice est membre de plusieurs biblios, un sélecteur de biblio
  (ou un répétiteur affichant un sous-bloc par biblio).
- Trois cases à cocher par biblio (une par domaine) :
  - « Não conservar empréstimos futuros »
  - « Não conservar reservas futuras »
  - « Não conservar consultas locais futuras »
- Un bouton « Salvar » qui appelle `fn_set_my_retention_preference` autant
  de fois que nécessaire.
- Un message de confirmation discret après sauvegarde.

### 6.5 Action de masse rétroactive

Sous (ou à côté de) chaque case à cocher prospective du §6.4, un lien-bouton
explicite : « Apagar todo o histórico passado de [domínio] desta biblioteca ».

Clic → modale de confirmation à double palier :

1. Message d'avertissement : « Vais apagar definitivamente N registros de
   [domínio] desta biblioteca. Esta operação não pode ser desfeita. »
2. Champ de saisie : la lectrice doit taper le mot **APAGAR** (en pt-BR ;
   traduit dans les 8 locales de l'app — `SUPPRIMER` en fr, `DELETE` en en,
   `BORRAR` en es, `ELIMINARE` en it, `LÖSCHEN` en de, `ESBORRAR` en ca,
   `FORVIŜI` en eo) pour valider. Le mot attendu est lu via une clé i18n
   dédiée et la validation côté frontend compare la saisie à cette clé,
   case-insensitive. Pattern classique des opérations destructives lourdes.
3. Bouton final activé seulement si la saisie est correcte.

Appel à `fn_delete_all_my_history(p_library_id, p_domain)`. Confirmation
a posteriori avec le nombre retourné : « N registros apagados. »

### 6.6 Affichage côté staff (painel)

Sur la liste d'historique d'une lectrice côté painel (page lecteur·rice),
les lignes masquées par la lectrice apparaissent avec :

- Un badge discret « Ocultado pela leitora » près du titre.
- Une opacité légère (70%) pour distinguer visuellement.
- Tous les autres détails restent identiques (titre, dates, statut, etc.).

Hover ou clic sur le badge → tooltip : « Esta linha foi ocultada pela
leitora em DD/MM/AAAA. A informação permanece visível para a equipe da
biblioteca. »

Pas d'action staff sur une ligne masquée — le staff peut consulter, pas
démasquer. Le masquage est un droit lectrice, pas une décision biblio.

## 7. Articulation avec l'existant

Cette section liste les points d'articulation avec les composants déjà
livrés du projet, sans détailler le code (qui sera traité lors de
l'implémentation).

### 7.1 Avec la rétention RGPD biblio (livrée 31/05/2026)

Aucun conflit. Cf. principe D.4. La purge RGPD continue de tourner sur son
cycle habituel et supprime les lignes (même masquées) au-delà du plafond
biblio. Le préavis e-mail RGPD livré aujourd'hui notifie la lectrice 30
jours avant que la purge atteigne son historique — elle peut alors choisir
d'anticiper en supprimant elle-même, ou laisser faire.

### 7.2 Avec les préférences de notification (livrées 31/05/2026)

Les deux blocs de préférences (notification et rétention) cohabitent dans
l'onglet `perfil`. Leur table support est distincte (cf. §5.2 et dette
notée). Aucun couplage fonctionnel : désactiver les notifications
n'affecte pas la rétention, et inversement.

### 7.3 Avec la doctrine de validation par-appartenance (30/05/2026)

Les préférences de rétention sont par biblio, donc s'inscrivent
naturellement dans la doctrine d'appartenance. Une lectrice qui change de
biblio principale ou qui quitte une biblio peut conserver ses préférences
sur les biblios où elle reste membre.

Quand une lectrice quitte définitivement une biblio (suppression de
l'appartenance), la cascade `ON DELETE` sur `user_library_memberships` ne
touche pas la préférence de rétention (la table de préférences référence
`libraries.id`, pas l'appartenance). La préférence reste en base mais
devient inerte — aucun nouvel emprunt ne sera créé pour cette biblio par
cette lectrice.

### 7.4 Avec la doctrine de souveraineté biblio (31/05/2026 matin)

La rétention historique illustre exactement la doctrine Position 1 actée
ce matin : la biblio fixe la durée maximale (souveraineté), la lectrice peut
ajuster à la baisse pour elle-même (autonomie). Aucune contradiction —
cette spec est l'extension cohérente de la doctrine au domaine historique.

### 7.5 Avec le bandeau d'état du compte (#CL.3)

Le bandeau d'état du compte (`fn_my_account_status`) n'est pas affecté.
Il continue de refléter l'état actuel (emprunts en cours, blocages,
cotisation), pas l'historique passé. Les actions de masquage/suppression
n'ont aucun effet sur le bandeau.


## 8. Cas limites et risques

Cette section traite les situations où la doctrine se confronte à ses
limites — techniques, juridiques, et opérationnelles. Le projet préfère
les nommer explicitement plutôt que les cacher derrière une promesse trop
forte.

### 8.1 Garanties techniques et limites d'hébergement

**La doctrine retient le DELETE physique** (cf. D.2). Mais aucune approche
logicielle dans une base hébergée chez un fournisseur cloud commercial ne
peut garantir l'inaccessibilité absolue d'une donnée précédemment écrite.
Plusieurs canaux techniques peuvent retarder la disparition complète :

- **PostgreSQL MVCC** : un DELETE crée une nouvelle version de la ligne
  marquée morte. La donnée physique reste présente jusqu'au prochain VACUUM
  (automatique, fréquence variable selon la charge). Délai typique : minutes
  à heures.
- **Write-Ahead Logs (WAL)** : les WAL conservent trace de l'opération de
  suppression pendant la fenêtre de rétention configurée par Supabase.
- **Point-in-Time Recovery (PITR)** : Supabase conserve les backups
  permettant la restauration à un instant T jusqu'à 7 jours par défaut
  (pouvant aller à 30 jours selon le plan).
- **Backups journaliers** : Supabase effectue des sauvegardes quotidiennes
  qui contiennent la donnée jusqu'à leur expiration (rétention typique 7 à
  30 jours).
- **Read replicas** : si configurés, ils peuvent garder la donnée jusqu'à
  leur synchronisation suivante.

**Conséquence honnête** : pendant une fenêtre d'environ 30 jours après
suppression par la lectrice, une réquisition technique extraordinaire
(requête à Supabase et/ou son hébergeur AWS, sous CLOUD Act ou autre
contrainte légale équivalente) pourrait théoriquement reconstituer la
donnée. Au-delà de cette fenêtre, et sauf incident d'hébergement
exceptionnel, la donnée est effectivement perdue.

**Engagement de la CCLA** :

- Ne pas conserver de backup applicatif au-delà de la rétention Supabase
  standard.
- Documenter cette limite dans la politique de confidentialité publique
  d'AnarBib, dans le manuel lectrice, et dans la section RGPD de l'app.
- En cas de réquisition judiciaire portant sur des données précédemment
  supprimées par une lectrice, accompagner la réponse d'un rappel explicite
  au requérant que la personne concernée avait exercé son droit à
  l'effacement — sans capacité technique de bloquer la réquisition, mais
  avec une trace politique de l'opposition de principe.
- Évaluer périodiquement la pertinence d'un hébergement alternatif (auto-
  hébergement chiffré, hébergeurs européens hors CLOUD Act, etc.) en
  fonction des besoins et des risques.

La promesse faite à la lectrice dans l'UI ne dit pas « cette suppression
est définitive et inaccessible à quiconque ». Elle dit, plus honnêtement :
« Esta exclusão é definitiva. Os dados são apagados da aplicação. Para
informações técnicas detalhadas sobre os backups, consulta nossa política
de privacidade. » Le lien vers la politique de confidentialité dépaye la
question complexe vers son lieu approprié, sans masquer le sujet.

### 8.2 Lectrice membre de plusieurs biblios — historique partagé ?

Un emprunt appartient à une biblio. Une réservation aussi. Une consultation
aussi. Il n'existe pas aujourd'hui d'objet d'historique partagé entre
biblios. Donc la doctrine par biblio (D.9) n'a pas de cas limite ici :
chaque ligne d'historique est attachée à exactement une biblio, et c'est la
préférence de cette biblio qui s'applique.

Si à l'avenir un objet inter-bibliothécaire venait à exister (PEB
multi-biblio en historique consolidé, par exemple), il faudrait revisiter
cette doctrine. Pas un blocage v1 ; à inscrire en dette future.

### 8.3 Suppression par la lectrice d'un emprunt encore référencé par staff

Cas : la lectrice supprime un emprunt passé qui faisait partie d'une
discussion staff en cours (litige sur un retard, négociation de
remplacement, etc.). La FK étant en CASCADE, l'emprunt et tous ses items
sont supprimés. Les éventuelles notes staff associées (`emprestimo_*_notas`
s'il en existe) sont supprimées avec.

**Doctrine de la spec** : c'est un coût acceptable de l'autonomie lectrice.
La biblio doit composer avec le fait que la lectrice peut effacer son
historique à tout moment. Si la biblio veut conserver une trace au-delà
d'un cas litigieux, c'est à elle d'extraire l'information avant la
suppression (par exemple en utilisant un système de notes staff
indépendant des objets d'emprunt).

Mitigation possible (hors spec, à arbitrer ultérieurement) : exposer côté
staff un avertissement quand un emprunt est en discussion active et qu'une
notification de purge RGPD imminente arrive, pour donner au staff l'occasion
d'extraire les éléments dont il a besoin.

### 8.4 Race condition entre purge RGPD et masquage lectrice

Cas : la purge RGPD s'exécute (cron quotidien) au moment où la lectrice
est en train de masquer une ligne. La purge supprime la ligne ; le masquage
qui suit échoue silencieusement (la ligne n'existe plus).

**Doctrine** : la purge gagne. La lectrice voit la disparition de la ligne
sans avoir pu la « masquer d'abord ». C'est cohérent — la purge RGPD est
souveraine (D.4), et de toute façon la lectrice obtient ce qu'elle
voulait : la ligne n'est plus visible.

Mitigation côté UI : si la RPC `fn_hide_history_item` retourne « ligne
inexistante », le frontend rafraîchit silencieusement la liste et n'affiche
pas d'erreur — la lectrice constate juste la disparition.

### 8.5 Masquage massif involontaire

Cas : une lectrice clique par erreur sur l'icône « masquer » plusieurs
lignes d'affilée et veut tout réafficher rapidement.

**Doctrine** : le masquage est réversible (D.8). La bascule « afficher les
lignes masquées » permet de tout revoir d'un coup, et chaque ligne a son
bouton « réafficher ». Pas de bouton « tout réafficher en masse » dans la
v1 — si l'usage révèle que c'est demandé, l'ajout est trivial. Pas de
risque structurel ici, juste un confort potentiel.

### 8.6 Récidive après désactivation prospective

Cas : une lectrice active la désactivation prospective (D.7), puis emprunte
plus tard, l'emprunt se ferme, est automatiquement masqué (D.7), mais la
lectrice veut soudain le voir.

**Doctrine** : elle peut. Le masquage automatique met juste
`is_hidden_by_user = true` ; la bascule UI « afficher les lignes masquées »
le ramène. Et le bouton « réafficher » sur la ligne le fait basculer en
visible permanent. Pas de différence entre un masquage manuel et un masquage
automatique — c'est le même drapeau, la même réversibilité.

## 9. Implications pour l'implémentation

Cette spec décrit la doctrine. L'implémentation effective sera un chantier
distinct, à conduire dans une ou plusieurs sessions ultérieures à tête
reposée. Cette section donne l'estimation du périmètre et les dépendances.

### 9.1 Volumétrie estimée

- **Migration SQL** : ~250 lignes. Ajout des deux colonnes sur les 3 tables
  racines (3 ALTER), création de `user_history_retention_preferences` (table
  + REVOKE/GRANT + RLS + lock-down), 6 RPC SECURITY DEFINER, 3 triggers
  AFTER UPDATE pour masquage automatique, doctrine v2 respectée partout.
- **Frontend AccountPage.jsx** : ~250 lignes. Bandeau §6.1, actions §6.2,
  bascule §6.3, bloc préférences §6.4, modale destructive §6.5.
- **Frontend painel (page lecteur·rice)** : ~30 lignes. Badge §6.6 et tooltip.
- **i18n** : ~15 clés × 8 locales = 120 entrées. Incluant les 8 traductions
  du mot de confirmation destructive.
- **Mise à jour `fn_my_history*` côté backend** : ~30 lignes. Filtre par
  défaut + paramètre `p_include_hidden`.
- **Documentation** : section dans le manuel lectrice + ligne dans la
  politique de confidentialité publique (cf. §8.1).

Total estimé : **1 session technique pleine** (~5-6h) pour l'ensemble,
quand la fenêtre se présente.

### 9.2 Dépendances et ordre

Aucune dépendance bloquante côté technique. La spec peut être implémentée
indépendamment de `spec-multi-appartenance-lecteur` (qui reste à écrire) —
la table de préférences est déjà clé composée `(user_id, library_id, domain)`
et fonctionnera quelle que soit la doctrine future de multi-appartenance.

Ordre de chantier recommandé pour l'implémentation :

1. Migration SQL (table + colonnes + RPC + triggers) avec bloc DO de
   vérification. Test de bout en bout en SQL Editor avant frontend.
2. Mise à jour `fn_my_history*` pour le filtre et le paramètre.
3. Frontend AccountPage : actions par ligne (§6.2 et §6.3) en premier,
   parce que c'est le geste lectrice le plus fréquent.
4. Frontend AccountPage : bloc préférences (§6.4) et modale destructive
   (§6.5) en second.
5. Frontend painel : badge masqué (§6.6) en dernier (sans urgence — le
   staff peut continuer à fonctionner sans le badge dans l'intervalle).
6. i18n complète sur les 8 locales en parallèle.
7. Documentation manuel + politique de confidentialité.

### 9.3 Acceptation

Cette spec est considérée respectée par l'implémentation si :

- Les 9 principes doctrinaux (§4.1 à §4.9) sont effectivement vivants
  dans le code produit, vérifiables ligne par ligne.
- L'UX décrite §6 est livrée sur les 8 locales.
- L'articulation §7 est respectée (pas de régression sur les composants
  existants nommés).
- Les cas limites §8 sont traités au moins comme noté (ou avec une
  amélioration documentée si l'implémentation va plus loin).
- Le chantier est suivi d'une mise à jour publique de la politique de
  confidentialité d'AnarBib mentionnant l'existence du droit à l'effacement
  lectrice et ses limites techniques (§8.1).

