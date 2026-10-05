# F3 — les fonctions de notification et de service « redondantes » : verdicts

*05/10/2026 — item F3 du backlog v34. Chaque fonction lue (en-tête et appels), ses
appelants cherchés dans le front, dans la base (`pg_proc.prosrc`, `cron.job`) et dans
les autres fonctions, son trafic relevé dans les journaux de la plateforme
(`function_edge_logs`, du 28/09 au 05/10, une fenêtre de 24 h par jour, de 565 à 677
appels de fonctions par jour).*

La fiche partait d'une ressemblance de noms. La consigne était de vérifier avant de
conclure : sur quatre groupes, **deux fonctions sont mortes et sont retirées**, les
autres ont des destinataires ou des autorisations différentes et restent séparées.

## 1. Les récapitulatifs — séparation justifiée

| Fonction | Déclenchée par | Destinataires | Contenu |
|---|---|---|---|
| `notify-weekly-report` | `fn_cron_notify_weekly_report_per_library`, bouton « envoyer maintenant » (`fn_send_weekly_report_now`, Bibliothèque) | l'équipe d'UNE bibliothèque (`weekly_report_email`) | l'activité de la semaine de cette bibliothèque |
| `notify-network-weekly-report` | `fn_cron_notify_network_weekly_report` | les admins réseau (`destinatairesAdminsReseau`, F15) | l'activité du réseau entier |
| `notify-cross-library-digest` | `fn_cron_notify_cross_library_digest` | les bibliothèques où l'administration réseau a agi | la transparence des gestes d'admin hors de leur bibliothèque (journal `network_admin_cross_library_actions_log`) |
| `notify-rede-digest` | `fn_rede_digest_call` | les lecteur·rices abonné·es à la Lettre (consentement de la Lettre) | les nouveautés réseau (Gazette, cercles), seulement s'il y a du neuf |

Quatre publics, quatre consentements ou rôles, quatre requêtes. Les deux rapports
hebdomadaires partagent déjà le transport (F7) et le calcul du routage ; les fondre
mêlerait des destinataires que tout sépare. Les quatre ont tourné dans les dernières
24 heures (de une à six fois).

## 2. Les lecteurs de documents — `read-pdf` retirée

| Fonction | Entrée | Autorisation | Verdict |
|---|---|---|---|
| `read-digital-asset` | `asset_id` | `get_accessible_digital_asset_by_id_v2` (public, ou compte actif), URL signée courte | **gardée** — appelée par `BookPage`, `ReaderPage` ; 12 appels le 05/10 |
| `read-ill-shared-asset` | `share_id` | `fn_ill_signed_url` RE-VALIDE à chaque appel : équipe réceptrice, partenariat actif, droit `digital_share`, état transmis | **gardée** — autorisation propre au partage entre bibliothèques ; appelée par `LibraryDigitalSharesSection` |
| `read-pdf` | `bib_ref` | `fn_book_restricted_pdf_state_for_current_user`, flux PDF streamé | **retirée** : `read-digital-asset` l'a remplacée (son en-tête le dit : « remplace la logique PDF-only ») ; **aucun appelant** (front, base, fonctions), **aucun lien stocké** (`books.digital_native_url`, ressources numériques, règlements), **zéro appel** du 28/09 au 05/10. Elle restait déployée, `verify_jwt = false`, en version 1660 : une porte de plus sans usage. |

## 3. Les exports — séparation justifiée

`export-catalog-lote` rend un fichier de notices (CSV, MARCXML, JSON, UNIMARC, MARC21) ;
`export-fonds-bundle` rend un ZIP de matériel gris numérisé et libre de droits
(notices + fichiers + manifeste), avec sa propre éligibilité (`fn_export_fonds_records`,
domaine public confirmé) et sa trace (`fonds_export_runs`). Le second **réutilise déjà**
le sérialiseur du premier (`export-catalog-lote/serialize.ts`) : la mise en commun utile
est faite, une fusion n'ajouterait qu'un aiguillage.

## 4. `mail-i18n-test` — retirée

Page de test des libellés de courriel (32 lignes, renvoie du JSON), sans appelant, zéro
appel en huit jours, déployée en production (version 1653). Les libellés sont gardés par
les tests du dépôt (`mail-ptbr-voce`, `mails-fond-et-couleur`, bancs des fonctions) :
elle ne servait plus à rien.

## Ce qui reste à faire hors du dépôt

La CI déploie les fonctions présentes, elle ne supprime pas celles qui disparaissent
(`scripts/ci/deployer-backend.sh`) : `read-pdf` et `mail-i18n-test` sont à supprimer
de la plateforme, comme `notify-mid-loan-reading` l'a été pour F1 (geste de Xavier).
Compte après retrait : **52 dossiers** de fonctions (hors `_shared`, `main` compris),
**38** déclarations `verify_jwt`.
