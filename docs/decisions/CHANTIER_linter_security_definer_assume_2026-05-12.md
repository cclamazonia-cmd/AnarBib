# Décision : maintien volontaire de SECURITY DEFINER sur `api.library_circulation_stats`

**Date** : 2026-05-12
**Paquet associé** : L.11 (`20260515140000_paquetL11_my_access_security_invoker.sql`)
**Auteur de la décision** : Xavier, coordenador AnarBib
**Statut** : Actif (à reconsidérer si la doctrine du réseau évolue)

---

## TL;DR

La vue `api.library_circulation_stats` reste en `SECURITY DEFINER` malgré l'alerte du linter Supabase (`security_definer_view`, niveau ERROR). C'est un **choix politique conscient** ancré dans la doctrine anarchiste d'AnarBib, pas un oubli technique. Cette note explique pourquoi à toute personne qui auditerait le schéma à l'avenir.

---

## Contexte

Le chantier linter du 11-12 mai 2026 a éradiqué 18 ERRORs `security_definer_view` initiales et plusieurs centaines de WARNs en révoquant les permissions par défaut sur les fonctions et en basculant les vues critiques en `security_invoker=true`. Le paquet L.11 a traité les deux dernières ERRORs apparues entre-temps :

- `api.my_access` → basculée en `security_invoker=true` (cas trivial, filtrage par `auth.uid()` interne)
- `api.library_circulation_stats` → **maintenue en `SECURITY DEFINER` par choix politique**

Le linter Supabase continuera donc à signaler 1 ERROR sur cette vue. Cette note existe pour que ce ne soit pas confondu avec une régression ou un oubli.

---

## Ce que fait `api.library_circulation_stats`

La vue agrège, pour chaque bibliothèque active du réseau, plusieurs statistiques de circulation :

- nombre de prêts ouverts (`loans_open`)
- nombre de prêts en retard (`loans_overdue`)
- prêts retournés sur 7 jours
- prêts créés sur 7 et 30 jours
- réservations actives, réservations sur 30 jours
- consultations actives
- nombre de holdings, nombre d'exemplaires
- nombre de lecteur·rices actif·ves, nombre de staff actif·ves
- top 5 des livres empruntés sur les 90 derniers jours

Elle est consommée principalement par `RedePage.jsx` pour afficher la vue d'ensemble du réseau, et accessoirement par `BibliotecaPage.jsx`.

Sa définition complète accède à 7 tables sources :
- `emprestimos_v2`, `reservas_v2`, `consultas_locais_v2` (tables sensibles avec RLS staff-only)
- `book_holdings`, `exemplares`, `books`, `user_library_memberships`, `libraries` (tables publiques ou semi-publiques)

---

## La tension doctrinale

AnarBib applique simultanément deux régimes de transparence apparemment contradictoires :

### Régime (a) — Transparence agrégée du réseau

Doctrine anarchiste de réseau d'entraide. Toute personne membre du réseau (lecteur·rice, librarian, coordenador, admin réseau) doit pouvoir voir l'activité agrégée de toutes les bibliothèques fédérées :

- combien de prêts en cours dans chaque biblio
- combien de lecteur·rices actif·ves
- quels sont les livres les plus empruntés
- etc.

Cette transparence sert plusieurs fonctions politiques :

- **Légitimation** : le réseau démontre concrètement son activité, sans masque.
- **Émulation** : voir l'activité des autres biblios donne des idées et de l'élan.
- **Reconfiguration** : identifier collectivement où les ressources circulent ou stagnent.
- **Honnêteté collective** : ne pas pouvoir cacher une biblio peu active ou dormante.

### Régime (b) — Confidentialité individuelle stricte

Doctrine de protection de la vie privée militante. Qui a emprunté quoi, qui a réservé quoi, qui a consulté quoi : **strictement confidentiel**, protégé par RLS ligne par ligne.

Cette confidentialité sert plusieurs fonctions politiques :

- **Protection des camarades** contre la surveillance étatique ou patronale.
- **Liberté de lecture** : pouvoir emprunter un texte sans que d'autres personnes le sachent.
- **Anti-traçabilité** : refuser que les pratiques de lecture deviennent des données exploitables.

Les RLS sur `emprestimos_v2`, `reservas_v2`, `consultas_locais_v2` implémentent (b) : un·e simple lecteur·rice ne voit que ses propres lignes ; un·e staff ne voit que les lignes de sa propre biblio.

---

## Comment `SECURITY DEFINER` réconcilie les deux

La vue `library_circulation_stats` en `SECURITY DEFINER` exécute ses sous-requêtes avec les droits du créateur (postgres), **bypass les RLS des tables sources**, mais **n'expose que des agrégats** (counts, sums, top N). Les lignes individuelles ne fuitent jamais à travers la vue.

Concrètement, la vue retourne `loans_open = 5` pour une biblio, mais **n'expose pas** quelles 5 lignes de `emprestimos_v2` ont produit ce chiffre. La confidentialité individuelle est préservée, la transparence agrégée est obtenue.

C'est exactement le **pattern d'usage légitime** de `SECURITY DEFINER` recommandé dans la documentation PostgreSQL : exposer un agrégat statistique sans exposer les lignes individuelles qui le composent.

---

## Pourquoi `security_invoker=true` ne convient PAS ici

Si on basculait la vue en `security_invoker=true` pour éliminer l'alerte linter :

- Pour un·e **staff de BLMF**, les agrégats refléteraient uniquement les lignes BLMF visibles via RLS. Toutes les autres biblios apparaîtraient avec des compteurs à zéro.
- Pour un·e **simple lecteur·rice**, presque tous les compteurs seraient à zéro (sauf `holdings_count` et `exemplars_count` qui lisent des tables sans RLS).
- Pour un·e **admin réseau**, le résultat dépendrait des policies — potentiellement correct mais fragile.

**Résultat** : la page Rede afficherait des chiffres faux et désorientants pour la majorité des caller·euses, ce qui **trahirait la doctrine de transparence agrégée** sans gain de sécurité réel (puisque les lignes individuelles ne sont pas exposées de toute façon).

---

## Pourquoi une policy SELECT permissive ne convient PAS non plus

Une alternative consisterait à ajouter une policy SELECT permissive sur `emprestimos_v2`, `reservas_v2`, `consultas_locais_v2` qui autoriserait tous les `authenticated` à lire toutes les lignes. Cela ferait fonctionner la vue en `security_invoker=true` sans perte d'agrégats.

**Mais cette solution casserait la doctrine de confidentialité individuelle** : un·e lecteur·rice pourrait alors directement requêter `SELECT * FROM emprestimos_v2 WHERE library_id = '<autre_biblio>'` et obtenir la liste nominative des emprunteur·euses d'une autre biblio. C'est précisément ce qu'AnarBib refuse.

PostgreSQL ne sait pas, au niveau RLS, masquer certaines colonnes à certaines lignes sans vue intermédiaire. La seule manière propre de combiner les deux régimes reste donc une **vue agrégée en SECURITY DEFINER**.

---

## L'alerte linter assumée

Le linter Supabase signalera durablement :

```
security_definer_view (ERROR)
View `api.library_circulation_stats` is defined with the SECURITY DEFINER property
```

C'est **attendu et accepté**. Le `COMMENT ON VIEW` posé par le paquet L.11 documente la doctrine au niveau du schéma lui-même, accessible via :

```sql
SELECT obj_description('api.library_circulation_stats'::regclass);
```

Toute personne consultant la base ou les rapports de linter peut donc, en 30 secondes, comprendre pourquoi cette ERROR est volontaire.

---

## Conditions de remise en question

Cette décision est à reconsidérer si :

1. **PostgreSQL gagne la capacité de masquer des colonnes par RLS** : on pourrait alors créer une RLS qui autorise SELECT large mais masque les colonnes `user_id`, `notes`, etc. La vue en `security_invoker` deviendrait alors faisable sans rompre la confidentialité.

2. **La doctrine politique d'AnarBib évolue** : si le réseau décide collectivement que les agrégats statistiques ne doivent plus être publics, on peut basculer en `security_invoker` et accepter que chaque caller·euse ne voie que sa propre perspective.

3. **Un·e contributeur·rice trouve une troisième voie** : un mécanisme combinant `security_invoker=true`, des vues filtrées intermédiaires, et des policies fines qui préserveraient les deux régimes sans le contournement `SECURITY DEFINER`.

D'ici là, la vue reste en `SECURITY DEFINER`, le linter affiche 1 ERROR, et c'est très bien comme ça.

---

## Références

- Paquet de migration : `supabase/migrations/20260515140000_paquetL11_my_access_security_invoker.sql`
- Documentation Supabase de l'alerte : <https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view>
- Pattern PostgreSQL `SECURITY DEFINER` recommandé : <https://www.postgresql.org/docs/current/sql-createfunction.html#SQL-CREATEFUNCTION-SECURITY>
- Document de synthèse du chantier linter : `docs/decisions/AnarBib_Recap_Chantier_Linter_2026-05-12.docx`
