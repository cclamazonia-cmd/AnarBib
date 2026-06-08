---
Genre : référence
Statut : 🟢 conception consolidée (IMP-1..15 tranchés ; implémentation par lots)
Décisions : incarne `IMP-1..IMP-15` (REGISTRE §17) ; cite `ACQ-Q4`, `CAT-B3`, `CAT-B5`, `CAT-D3`/`D4`/`D6`, `CAT-E*`, `ILL-1..ILL-9`, `PARTNER-D6`/`D7`/`D9`, `DOC-RPC-3`, `DOC-I18N-1`
Supersédé par : —
---

# spec-importacoes-exportacoes

| | |
|---|---|
| **Version** | v0.2 — **conception consolidée** (les 6 arbitrages du remplissage tranchés le 08/06 ; reste l'implémentation par lots, §13) |
| **Date** | 8 juin 2026 (révise la v0.1 du 5 juin) |
| **Emplacement cible** | `docs/specs/` |
| **Statut** | `IMP-1..8` ✅ actés (05/06) ; **`IMP-9..15` ✅ tranchés (08/06, validés Xavier)** — run d'import, profils de mapping, adaptateurs, autorités, export de lote, rôles, articulation tableau de bord/wizard. Reste l'implémentation **par lots** (§13). |
| **Réfère à** | `#ILL-digital` (`spec-flux-partage-numerique`) ; `#PARTNERS` (`spec-partenariat-biblios`, `library_partnerships`) ; Catalogação (`spec-catalogacao-fiche-et-paliers`) ; provenance (`spec-acquisition-provenance`) ; autorités (`spec-sources-externes-autorites`, `spec-notice-autorite-enrichie`). |
| **Dépendances** | `book_drafts` + `book_draft_import_events` · `catalog_ref_source_formats`/`_methods`/`_partners`/`_systems` · staging `import_*` · `partner_source_records`/`_holdings`/`_items` · `library_partnerships` · `catalog_partners(_policy_flags_v2)` · Supabase Storage. |

> **Convention.** **[A]** = acté (`IMP-*`, session 05/06). On **cite l'ID** (REGISTRE §17), on ne reformule pas ailleurs. La maquette `maquette_importacoes_v7.html` est une **trace visuelle** (non-normative).
> **Frontière (`ACQ-Q4`).** Ce module fait l'**ingestion technique** (faire entrer des notices, préparer des rascunhos) ; l'**entrée-en-collection** (provenance, exemplaires, destination) reste en **Catalogação**.

---

## 1. Préambule & objet — module bidirectionnel [A — IMP-1]
- La page **Importações/Exportações** porte **deux sens** : faire **entrer** des notices d'origines diverses (import) et faire **sortir** du catalogue (export).
- L'import s'arrête au **rascunho** (`book_drafts`) ; il ne pose ni provenance ni exemplaire — ça, c'est Catalogação (`ACQ-Q4`).
- L'export n'est jamais inconditionnel : il est gouverné par le consentement et le périmètre (§8).

## 2. Les deux sens — vue d'ensemble [A — IMP-1]
- **Importar** : tableau de bord = circuits (§3) + couche format/adaptateur (§4–5) + **file de revisão** `book_drafts` (§7) + journal (`book_draft_import_events`).
- **Exportar** : *partilha de documento* (#ILL-digital, §8) · *exportação de lote* (sérialisation, §5) · *ser fonte para companheiras* (moisson OAI, gated `mutualize_allowed`, §8).
- La page reste un **tableau de bord** ; l'action « Novo import » est un **wizard** (§9).

## 3. Les trois circuits — par nature du lot, pas par instance [A — IMP-2]
- **Migração de sistema** — le lot vient d'un SIGB antérieur (notices + exemplaires), lote unique. *Ex. : BLMF (PMB / UNIMARC).*
- **Importação de arquivo** — le lot vient d'un export / fichier bibliographique à mapper. *Ex. : Terra Livre (Zotero).*
- **Fontes externas** — notices puisées en ligne : *companheiras* (relation consentie, `catalog_partners`) et *institutionnelles* (copy-cataloging, BN / WorldCat).
- Les noms de biblios ne sont que des **exemples** : un nouveau cas réutilise le circuit, jamais un nouvel onglet.

## 4. Le format — trois plans [A — IMP-3]
1. **Structure de transport** (le contenant) : ISO 2709 · XML (MARCXML / MODS / Dublin Core / EAD) · JSON (MARC-in-JSON / CSL-JSON) · tabulaire (CSV / TSV) · texte-balisé (BibTeX / RIS).
2. **Vocabulaire / schéma** (le sens des champs) : UNIMARC · MARC21 · INTERMARC · Dublin Core · Zotero/CSL · BibTeX · RIS · ONIX · KBART · BIBFRAME.
3. **Modèle conceptuel** : ISBD linéaire *vs* FRBR / IFLA-LRM (Œuvre–Expression–Manifestation–Item). **AnarBib a le sien** (`book_drafts` + autorités) — cible de tout mapping.
- Le **circuit** (§3) et le **format** sont **orthogonaux** : un même MARC21 peut arriver par fichier, par fonte externe ou par migration.

## 5. L'adaptateur [A — IMP-4]
- **Adaptateur = décodeur de structure + mappeur de vocabulaire → `book_drafts`.**
- Indexé sur `catalog_ref_source_formats` (+ `catalog_ref_import_methods`). Un **profil de mapping** (`campos da fonte → book_drafts` ; points d'accès → autorités) est **réutilisable** (profil « Terra Livre / Zotero », profil « BLMF / PMB »…).
- **Nouveau format** = nouvel adaptateur (souvent une combinaison déjà connue) + profil — *pas* une nouvelle aba. Combinaison inconnue → **repli mapping manuel** ou demande d'adaptateur.
- **Sortie** : le **même registre sérialise** vers MARC / Dublin Core / CSV… (exportação de lote, §8).

## 6. Champs descriptifs vs points d'accès [A — IMP-5]
- **Descriptifs** (titre, édition, collation, identifiants) → colonnes `book_drafts`.
- **Points d'accès** (auteur, sujet) → **résolution / création d'autorités** AnarBib (cf. `CAT-D3` `authority_lookup`, `CAT-D4` formes variantes, `CAT-D6` viaf/isni/wikidata) — **jamais** du texte libre.
- En UNIMARC, ces liens sont des `$3 = PPN` (blocs 6XX / 7XX) ; à l'import, ils deviennent des liens d'autorité internes.

## 7. La dérivation = la file de revisão [A — IMP-6]
- Importer n'est jamais une copie propre. La **dérivation** (copy-cataloging) impose une **passe de nettoyage** : retrait des identifiants locaux de la source, re-pointage des autorités, traduction / normalisation des notes.
- Cette passe **est** la **file de revisão** `book_drafts` (`review_status` : `not_reviewed → pending_review → reviewed_local` / `reviewed_with_source`). **Aucun import ne publie directement.**

## 8. Export — symétrie & gouvernance [A — IMP-7]
- **Partilha de documento (#ILL-digital)** : entre **biblios fédérées** (`library_partnerships`, droit `digital_share`), **pas** avec les `catalog_partners` ; flux et périmètre = **`ILL-1..ILL-9`** (`spec-flux-partage-numerique`, charpente figée). Ce module **ne redéfinit rien** : il référence.
- **Exportação de lote** : sérialisation via la couche §5 (backup · remise à une companheira · migration sortante).
- **Ser fonte para companheiras** : miroir de « fontes externas » — moisson OAI **ouverte seulement si `mutualize_allowed = true`** (`catalog_partners_policy_flags_v2`).
- Principe : **les mêmes `*_allowed` régissent les deux sens** ; rien ne sort plus ouvert que ce qu'on assume.

## 9. Assistant d'import (wizard) [A — IMP-8]
**Forme.** Le wizard est l'**action « Novo import »** lancée depuis le tableau de bord (la page n'est pas un wizard). **Route dédiée** (pas une modale), **stepper linéaire** avec **retour arrière** entre étapes, et **écriture unique à la promotion** (rien ne touche `book_drafts` avant l'étape 5). **Import-only** : l'export reste une machine à états (`ILL-7`), hors wizard.

**Polymorphisme.** L'**étape 2 dépend du circuit** ; les étapes 3–5 convergent.

### 9.1 Étapes
1. **Circuit** — *migração de sistema · importação de arquivo · fontes externas*. Détermine l'UI de l'étape 2.
2. **Source** *(selon circuit)* :
   - *importação de arquivo* → dépôt d'un fichier ;
   - *migração de sistema* → sélection d'un **lot déjà en staging** (`import_*`) ;
   - *fontes externas* → requête / connexion à la source (cache `partner_source_records`).
   Puis **auto-détection structure + vocabulaire → adaptateur résolu** (§4–5) ; combinaison inconnue → repli **mapping manuel**.
3. **Mapping** — confirmer / éditer le **profil** (`campos da fonte → book_drafts` ; points d'accès → autorités, §6) ; réutiliser un profil sauvegardé.
4. **Aperçu / dry-run** — **simulation en lecture seule** (une RPC renvoie un rapport, **zéro écriture**). Statut **par ligne** : `mappable` · `doublon` (ISBN/EAN sur l'existant) · `autorité à résoudre` · `hors-périmètre` · `erreur` (non-mappable). On peut **exclure des lignes** ou revenir corriger le mapping (étape 3).
5. **Promotion** — **une seule RPC** (`DOC-RPC-3`) insère les rascunhos retenus dans `book_drafts` + journalise dans `book_draft_import_events`, **en transaction**. Récap final (N promus · M exclus · P en avertissement).

### 9.2 Doctrine du dry-run
- **Bloquant** : doublon ISBN réseau (cohérent `CAT-B5` — blocage + rattachement) ; ligne non-mappable.
- **Avertissement** (non bloquant) : confiance basse, autorité non résolue. Ces lignes **passent quand même** en `book_drafts` avec `review_status = pending_review` + drapeau de confiance — **la file de revisão tranche** (`IMP-6`, §7).
- **Autorités** : résoudre les évidentes au dry-run (`authority_lookup`, `CAT-D3`) ; **déférer le reste à la file**. On ne bloque jamais un import sur la perfection des autorités.
- **Idempotence** : matcher `source_record_id` + ISBN/EAN pour ne pas réimporter une notice déjà entrée.

### 9.3 Rôles *(reco — ratification au foyer `spec-gouvernance-roles`)*
- Lancer le wizard + promouvoir = **`librarian` + `coordenador`** (ingestion dans l'espace staff, pas publication).
- **Ouvrir une source companheira** (`catalog_partners`, activer `mutualize_allowed`) = **`coordenador`** seulement (acte de relation / gouvernance, cf. PARTNER).

### 9.4 Reprise & état
Un import est long → **objet « run d'import »** (nouveau, **DDL à trancher** §12) : `{circuit, source, adaptateur, profil, statut, compteurs, acteur, horodatages}`, statut `en préparation → mappé → en revue → promu | abandonné`. Permet de quitter et reprendre, et trace l'audit du lot.

## 10. Implications techniques
- **Écritures via RPC** (`DOC-RPC-3`) : promotion de lot, application d'un profil, journalisation. Lectures simples sous RLS tolérées ; `storage.from()` hors périmètre RPC.
- **Journal** : `book_draft_import_events` (`event_kind`, `source_partner_code` / `source_system_code` / `source_format_code`, `import_method_code`, `review_status_code`, `confidence_level_code`, `event_payload` jsonb…).
- **Réfs contrôlées** : `catalog_ref_source_formats` / `_methods` / `_partners` / `_systems`.
- **Staging** existant : `import_blmf_books_rows`, `import_blmf_exemplares_rows`, `import_terra_livre_zotero_staging`.
- **Fontes externas** : cache `partner_source_records` / `_holdings` / `_items` ; relation `catalog_partners` + `catalog_partners_policy_flags_v2`.
- **Export** : sérialiseurs réutilisant la couche §5 ; partilha = objets de `spec-flux-partage-numerique` (à coder).

## 11. Articulation avec le corpus
`spec-flux-partage-numerique` (ILL ; **circuit distinct**, ne pas redéfinir) · `spec-partenariat-biblios` (`library_partnerships`, `mutualize_allowed`) · `spec-catalogacao-fiche-et-paliers` (`book_drafts`, `CAT-B3` visibility, `CAT-E*` registre) · `spec-acquisition-provenance` (frontière `ACQ-Q4`) · `spec-sources-externes-autorites` / `spec-notice-autorite-enrichie` (résolution d'autorités) · `DOC-RPC-3` · `DOC-I18N-1`.

## 12. Arbitrages du remplissage — ✅ tranchés le 08/06/2026

Les six points ouverts de la v0.1 sont tranchés (validés Xavier). Nouveaux IDs au REGISTRE §17.

**IMP-9 — Run d'import (table de session).** Nouvelle table `catalog_import_runs` : `{ circuit, source, structure_code, vocabulary_code, profile_id, status (en_preparation → mapping → preview → promu | abandonne), counts jsonb {staged, mapped, promoted, excluded, errors}, initiated_by, library_id, created_at, updated_at }`. C'est l'**épine du wizard** (quitter/reprendre, §9.4) ; alimente le journal `book_draft_import_events`. Écritures via RPC (`DOC-RPC-3`).

**IMP-10 — Profils de mapping.** Table `catalog_import_mapping_profiles` : `{ name, scope ('library' | 'network'), library_id, structure_code, vocabulary_code, mapping jsonb (champ_source → colonne `book_drafts` | cible autorité), created_by }`. Le mapping lui-même = **jsonb**. Portée **biblio** par défaut, **réseau** optionnel (partage). Éditable en UI (étape 3 du wizard), réutilisable.

**IMP-11 — Adaptateurs (hybride).** Registre **déclaratif** `catalog_import_adapters` (combinaisons structure × vocabulaire connues → profil par défaut + statut) ; la **logique de décodage vit en code** (un parser par structure de transport, côté EF ou frontend). **Détection auto = la structure** (magie ISO 2709, racine XML, forme JSON, sniff CSV) ; le **vocabulaire** est déclaré/choisi. Combinaison inconnue → repli **mapping manuel** (`IMP-4`). **Priorité d'implémentation** : (a) **CSV/TSV · Zotero (CSL-JSON) · BibTeX · RIS** + **UNIMARC ISO 2709** (migration BLMF réelle) ; (b) Dublin Core · MARCXML · OAI-PMH ; (c) MARC21 · BIBFRAME.

**IMP-12 — Résolution d'autorités à l'import.** Au **dry-run** : auto-match des points d'accès contre les autorités existantes (`authority_lookup`, `CAT-D3`). Les non-résolus **ne bloquent pas** : la notice passe en `book_drafts` avec `review_status = pending_review` + drapeau « autorité à résoudre », et la **résolution se fait ensuite en Catalogação** (cohérent `IMP-6` + `ACQ-Q4`). Jamais de blocage d'import sur la perfection des autorités.

**IMP-13 — Exportação de lote.** Périmètre **catalogue / collection / sélection** ; formats de sortie = la **couche adaptateur en sens inverse** (sérialisation) : MARC21 · MARCXML · Dublin Core XML · UNIMARC ISO 2709 · CSV · JSON · BibTeX. **Une RPC/EF de sérialisation**. Le verrou de consentement (`mutualize_allowed`, périmètre ILL, plafond de diffusion) reste régi par §8 / `ILL-1..9` — l'export technique ne contourne rien.

**IMP-14 — Rôles.** **`coordenador`** : lance le wizard, promeut, exporte, gère les relations partenaires + `digital_share` (`PARTNER-D7`). **`librarian`** : consulte + imports fichier simples (espace staff, pas publication). Ratification au foyer `spec-gouvernance-roles`.

**IMP-15 — Articulation tableau de bord / wizard.** Le **tableau de bord v7** (`maquette_importacoes_v7.html`) est la **page canonique** : il porte le modèle (circuits × adaptateurs × profils, fila, journal, export). Le **wizard** est l'action guidée « Novo import » lancée depuis lui (§9). **Ordre de réalisation** : on bâtit d'abord la page v7 (elle fige le modèle + le backend), **puis on re-dérive le wizard** de la page finie (`maquette_wizard_import_v1` → v2 alignée). Construire le wizard avant figerait un flux contre un modèle mouvant.

**Reste transverse** : i18n (`DOC-I18N-1`) — clés du module + wizard externalisées sur les 10 locales, au fil des lots.

## 13. Plan de lots (implémentation)

Cadrage d'abord (cette v0.2) ✅. Puis, **par lots vérifiés** (close-before-open, `DOC-CLOSE-1`) :

- **Lot 0 — fondations backend.** Migrations : `catalog_import_runs` (`IMP-9`), `catalog_import_mapping_profiles` (`IMP-10`), `catalog_import_adapters` (`IMP-11`, registre). RPC : création de run, application de profil, **dry-run** (lecture seule), **promotion** (transaction, `DOC-RPC-3`).
- **Lot 1 — tableau de bord v7 (frontend).** Refonte `ImportacoesPage.jsx` sur la maquette v7 : toggle Sentido, bandeau adaptateur, 3 circuits, **fila de revisão** (`book_drafts`), **journal** (`book_draft_import_events`). Réutilise l'existant (`fn_bulk_create_book_drafts_from_run`…). i18n.
- **Lot 2 — circuit « Importação de arquivo » (Zotero / CSL-JSON), de bout en bout.** Adaptateur CSL-JSON + mapping éditable + dry-run + promotion. Cas réel : Terra Livre.
- **Lot 3 — circuit « Migração de sistema » (UNIMARC ISO 2709).** Adaptateur UNIMARC + lot BLMF (staging → `book_drafts`).
- **Lot 4 — circuit « Fontes externas ».** Companheiras (consentement `catalog_partners`) + institutionnelles (copy-cataloging, `catalog_metadata_lookup` déjà livré).
- **Lot 5 — face Export.** Exportação de lote (`IMP-13`, sérialisation) ; partilha ILL **référence** `spec-flux-partage-numerique` ; ser fonte (OAI, `mutualize_allowed`).
- **Lot 6 — wizard.** Maj `maquette_wizard_import_v1` → v2 alignée sur la page finie, puis implémentation (`IMP-15`).
- **Formats suivants** (Dublin Core / MARCXML / MARC21 / BIBFRAME) : adaptateurs additionnels au fil des besoins (`IMP-11` priorité c).

---

*v0.2 (conception consolidée, 08/06/2026). Décisions au REGISTRE `IMP-1..IMP-15` (§17). Trace visuelle : `maquette_importacoes_v7.html` (tableau de bord) + `maquette_wizard_import_v1.html` (wizard, à re-dériver). Implémentation par lots (§13), foyer unique (CHARTE_corpus : citer plutôt que recopier).*
