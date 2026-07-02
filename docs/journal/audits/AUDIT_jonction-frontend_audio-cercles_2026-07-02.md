# Bilan d'audit — GLB v16 (lecture du 2 juillet), trois axes : deux faux non-acquis de jonction + instrumentation FK

**Date** : 2026-07-02
**Auteur** : Xavier (session avec Claude, côté Windows, backend via WSL/`~/anarbib`)
**Contexte** : Le Grand Livre blanc v16 (lecture du 2 juillet) signale, avec des formules *explicitement prudentes*, deux périmètres où la jonction frontend serait à compléter — le **catalogage sonore** (« pas de sous-dossier audio dédié repéré », *à compléter*) et les **cercles de lecture** (« composant dédié non confirmé », *à confirmer*) — et un troisième chantier dur, le **point 8.2** (151 clés étrangères sans index). Audit déclenché pour lever ces incertitudes sur le **code déployé** (branche `main`), pas sur les specs, conformément à la ligne rouge v13 (« le code déployé fait foi »).
**Méthode** : `grep`/lecture sur `~/anarbib` (branche `main`, React 19/Vite, `.jsx`) croisée avec l'inventaire SQL de la prod (`uflwmikiyjfnikiphtcp`, lecture seule MCP). Pour chaque axe : la surface backend exposée, les appels frontend réels (fichier:ligne), l'exposition/`grant`, la parité i18n.
**Statut** : Document de référence. Corrige la table du chapitre 6 et l'ordre d'exécution du chapitre 10 du GLB v16 pour la révision suivante.

---

## Synthèse

Les deux « périmètres à compléter » du GLB v16 sont, comme en mai (méga-item #CL, jonction profils d'adoption), des **faux non-acquis** : livrés et câblés, mais non reconnus par le document parce qu'il a lu des **noms de dossiers** plutôt que le **contenu**. Le seul axe réellement ouvert était le **point 8.2**, traité ce jour. À périmètre v14 constant, la lecture d'achèvement réelle est donc plus haute que les ≈94 % affichés.

| Axe GLB v16 | Verdict GLB | Verdict code déployé | Action de la session |
|---|---|---|---|
| 6 — Catalogage sonore | « à compléter » | **Jonction tenue** (7/7 RPC `api.audio_*` câblées) | Acter *tenue* |
| 6 — Cercles de lecture | « à confirmer » | **Jonction tenue** (8 fonctions `fn_circle_*` câblées) | Acter *tenue* |
| 8.2 — 151 FK sans index | chantier dur ouvert | Réel | **136 index créés, déployés, vérifiés** |

---

## Axe 1 — Catalogage sonore : jonction tenue

Backend mûr (migrations `20260621162441` → `20260622120319`), exposé en schéma `api` et **entièrement consommé** :

- `src/pages/catalogacao/AudioSegmentsBlock.jsx` : `audio_track_upsert` (l.93), `audio_track_delete` (l.114), `audio_track_contributor_add` (l.132), `audio_track_contributor_remove` (l.144) ; lecture `v_audio_tracklist` (l.42) et `catalog_ref_audio_recording_types` (l.43).
- `src/pages/catalogacao/AudioFingerprintTool.jsx` : `audio_track_set_recording_mbid` (l.84), `audio_resource_set_fingerprint` (l.90), et **invoque l'Edge Function `audio_fingerprint_lookup`** (l.61) via `chromaprintFingerprint`.
- `src/pages/public/BookPage.jsx` : affichage public via `audio_tracklist_public` (l.183).

Les **7** RPC `api.audio_*` publiées sont appelées. Le GLB a conclu « à compléter » sur l'absence de *dossier* `audio/` — mais les fichiers vivent dans `catalogacao/` (l'audio est du catalogage, pas un domaine séparé).

Réserve mineure (non bloquante) : léger écart de comptage i18n `audio` (16 vs 17 selon la locale) — vraisemblablement une **valeur** traduite, pas une **clé** manquante (la CI impose la parité des clés). À confirmer d'un coup d'œil si on y touche.

## Axe 2 — Cercles de lecture : jonction tenue

Backend déployé et vérifié dès le 12/06 (migrations `20260612075752` FED-1 + `20260612131910`), documenté dans `docs/journal/HANDOFF-circulos-frontend-2026-06-12.md` (le frontend y était « le reste »). Ce reste est **fait** : `src/pages/federacao/FederacaoPage.jsx` contient un `CirculosTab` complet.

- Toutes les fonctions `api.fn_circle_*` sont câblées : `create`, `request_join`, `leave`, `object`, `set_dormancy`, `member_count`, `message`.
- `fn_circle_resolve_due` (résolution anti-blackball des adhésions échues) est **appelée paresseusement au chargement** (l.94) — la résolution fonctionne sans planificateur, exactement comme le prévoit le commentaire de la fonction (« appelée au chargement de la page et/ou par planificateur »). *Note : aucun `cron.schedule` ne la double ; l'appel lazy suffit tant que la page est visitée. Si l'usage devenait rare, un cron serait un filet utile — non urgent.*
- i18n `circulos` = **48 clés dans les 10 locales** (parité parfaite).
- `FederacaoPage.jsx` l.42 : `circulos` est explicitement dans le `Set` WIRED. L'onglet est en `STAFF_ONLY_TABS` — **décision produit** (la face fédération est ouverte aux membres rattachés, cf. handoff §0), pas un manque.

## Axe 3 — Point 8.2 : instrumentation des FK (fait ce jour)

Le seul axe réellement ouvert. Mesure prod confirmant le GLB : **151 FK `public.*` sans index de support sur 336**. Répartition affinée (le GLB attribuait le gros à `auth.users` ; c'est en réalité d'abord `profiles`) :

| Table pointée | FK sans index | Traitement |
|---|---|---|
| profiles | 45 | indexée |
| auth.users | 38 | indexée |
| libraries | 19 | indexée |
| entités opérationnelles | ~34 | indexée |
| `catalog_ref_*` (codes, <50 lignes) | 15 | **écartée** (index sans valeur) |

**Migration `20260702160920_fk_support_indexes_8_2.sql`** : 136 `CREATE INDEX IF NOT EXISTS` (btree mono-colonne), liste générée depuis la base (zéro transcription), idempotente, réversible (`DROP INDEX IF EXISTS ix_<table>_<colonne>`). Déployée via CI Forgejo ; **vérifiée en prod** : FK sans index 151 → **15** (uniquement les `catalog_ref_*` voulues), `unindexed_real = 0`.

Deux points doctrinaux :
1. **Lien avec BG2-14** : `fn_delete_my_account` balaie par `user_id` les colonnes d'acteur `network_*` (`voter_user_id`, `target_user_id`, `actor_user_id`, `proposed_by`…), toutes dans le lot — les indexer accélère l'effacement RGPD corrigé le matin même.
2. **Fenêtre** : fait *maintenant*, couches civiques quasi vides → `CREATE INDEX` simple, instantané et transactionnel (pas de `CONCURRENTLY`), **avant** l'activation tierce CIRA Marseille (arbitrage GLB ch.11 : instrumenter d'abord pour mesurer proprement l'activation).

---

## Recommandations pour la révision du GLB

- **Chapitre 6** : passer *Catalogage sonore* et *Cercles de lecture* à **Tenue**, avec renvois fichier:ligne ci-dessus.
- **Chapitre 10 (ordre d'exécution)** : la séquence **#1** (« jonction frontale audio+cercles ») est **close** ; la séquence **#2** (instrumentation FK) l'est aussi (résiduel = 15 FK de codes, volontairement non indexées).
- **Méthode** : le motif « faux non-acquis » se répète (mai : profils d'adoption ; juillet : audio + cercles). Toute lecture d'achèvement doit croiser le **code** (`grep` des RPC/`from`), pas l'arborescence des dossiers — sans quoi le dénominateur d'achèvement est sous-estimé.
