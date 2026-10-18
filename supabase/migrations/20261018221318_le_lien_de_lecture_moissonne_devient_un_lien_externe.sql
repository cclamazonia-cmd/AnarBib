-- =========================================================================
-- Le lien de lecture d'une notice moissonnée devient un lien externe du
-- brouillon, attribué à la source
-- =========================================================================
-- Date     : 2026-10-19 (heure de Paris)
-- Chantier : étape 4 du cadrage fédéralisme ASB ↔ AnarBib (18/10/2026,
--            section 2.7), côté AnarBib seulement
-- Auteur   : Claude (Opus 5.5), à la demande de Xavier
-- Suite    : tests/sql/oai_liens_externes_tests.sql
--
-- LE CONSTAT.
--   Une notice d'un entrepôt de textes en ligne (AnarcosyndicalismeBOOK :
--   des textes à lire, sans exemplaire physique) n'a de sens chez nous
--   qu'avec son lien de lecture. Le moissonneur le recevait en dc:identifier
--   et le perdait : il ne restait que dans raw_payload.dc_xml. Depuis le
--   commit voisin, harvest-oai-pmh le range dans
--   normalized_payload.external_links (adresses http(s), une fois chacune).
--
-- LE GESTE.
--   ingest.fn_create_book_drafts_from_import_rows, réécrite depuis sa
--   DÉFINITION RÉELLE (pg_get_functiondef ; lue en production le 19/10/2026 :
--   md5 432bb0a5fb138cd68bd961ced8f4c753, 12 288 caractères) — une ancre
--   comptée (une occurrence exacte), un bloc ajouté juste avant
--   l'enregistrement du lien ligne → brouillon. Signature, défauts,
--   SECURITY DEFINER, search_path et droits (postgres et service_role
--   seulement) restent ceux de la définition réelle : vérifié en fin de bloc.
--
--   Le bloc écrit, pour chaque adresse de normalized_payload.external_links
--   (http ou https, sans espace, 2 000 caractères au plus, cinq au plus, une
--   fois chacune, dans l'ordre du fichier) une ressource de brouillon :
--     resource_type = usage_type = 'link_externo', access_scope 'publico',
--     status 'draft', mime 'text/html', source_url = l'adresse,
--     source_name = attribution_text = label = le nom de la source
--     (partner_catalog_sources.partner_name) — aucune valeur propre à un
--     entrepôt n'est écrite ici —, rights_status laissé vide (les droits du
--     texte sont ceux de la source ; la sonde des ressources le classe en
--     informatif, pas en panne). C'est la forme exacte qu'écrit l'écran du
--     catalogage pour un lien saisi à la main (DigitalResourcesPanel).
--   La publication n'a pas à changer : publish_book_draft_digital_resources
--   recopie toute ressource active du brouillon (D9, D17).
--
-- CE QUE LE PAQUET NE FAIT PAS.
--   - Aucun fichier n'est téléchargé, aucun lien de fichier n'est fabriqué.
--   - Une ligne « rattachée » à une notice existante (IMP-26 h) ne devient
--     pas un brouillon : son lien n'est pas posé ici. À reprendre si une
--     notice papier doit recevoir le lien de lecture d'un entrepôt.
--   - Le réimport (H21) ne compare pas les liens.
--
-- CHECKLIST DOCTRINE
--   [x] Fonction SECURITY DEFINER : définition réelle conservée, droits
--       inchangés (comparés avant / après dans le bloc)
--   [x] Pas de table neuve, pas de colonne neuve ; RLS inchangée
--   [x] Ancre comptée : la migration ÉCHOUE si elle manque ou se répète ;
--       rejouée sur une fonction déjà modifiée, elle ne fait rien
--   [x] Le fonctionnel est dans la suite SQL, pas ici (DOC-MIGR-1)
-- =========================================================================

BEGIN;

DO $migration$
DECLARE
  v_sig   constant regprocedure := 'ingest.fn_create_book_drafts_from_import_rows(bigint,bigint[],text,text,uuid)'::regprocedure;
  v_def   text;
  v_acl   text;
  v_n     int;
  v_ancre constant text := E'    insert into ingest.partner_catalog_row_to_draft (staging_row_id, run_id, draft_id, batch_id, created_by)\n';
  v_bloc  constant text := $bloc$    -- Étape 4 du cadrage fédéralisme (19/10/2026) : les adresses de lecture
    -- qu'un moissonnage a lues en dc:identifier (normalized_payload.external_links)
    -- deviennent des liens externes du brouillon, publics, attribués à la
    -- source ; la publication les recopie. http(s) seulement, cinq au plus,
    -- une fois chacune : la ligne vient d'un serveur tiers.
    insert into public.book_draft_digital_resources (
      book_draft_id, resource_type, usage_type, access_scope, status, is_active,
      mime_type, label, source_name, source_url, attribution_text, metadata)
    select v_draft_id, 'link_externo', 'link_externo', 'publico', 'draft', true,
           'text/html', left(coalesce(nullif(btrim(rec.partner_name), ''), l.url), 200),
           nullif(btrim(rec.partner_name), ''), l.url, nullif(btrim(rec.partner_name), ''),
           jsonb_build_object('origine', 'import', 'run_id', rec.run_id, 'staging_row_id', rec.id)
      from (select u.url, min(u.ord) as ord
              from (select btrim(e.value) as url, e.ord
                      from jsonb_array_elements_text(case when jsonb_typeof(rec.normalized_payload->'external_links') = 'array'
                                                          then rec.normalized_payload->'external_links' else '[]'::jsonb end)
                           with ordinality as e(value, ord)) u
             where u.url ~* '^https?://[^[:space:]]+$' and length(u.url) <= 2000
             group by u.url
             order by min(u.ord)
             limit 5) l
     order by l.ord;

$bloc$;
BEGIN
  v_def := pg_get_functiondef(v_sig);
  SELECT proacl::text INTO v_acl FROM pg_proc WHERE oid = v_sig;

  IF strpos(v_def, 'normalized_payload->''external_links''') > 0 THEN
    RAISE NOTICE 'fn_create_book_drafts_from_import_rows pose deja les liens externes : rien a faire.';
    RETURN;
  END IF;

  v_n := (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'Ancre de fn_create_book_drafts_from_import_rows trouvee % fois (attendu 1) : la definition reelle a change, ne rien appliquer.', v_n;
  END IF;

  EXECUTE replace(v_def, v_ancre, v_bloc || v_ancre);

  -- Gardes structurelles : le bloc est là, les droits et l'enveloppe n'ont pas bougé.
  v_def := pg_get_functiondef(v_sig);
  IF strpos(v_def, 'normalized_payload->''external_links''') = 0 OR strpos(v_def, '''link_externo''') = 0 THEN
    RAISE EXCEPTION 'Le bloc des liens externes est absent apres reecriture.';
  END IF;
  IF (SELECT proacl::text FROM pg_proc WHERE oid = v_sig) IS DISTINCT FROM v_acl THEN
    RAISE EXCEPTION 'Les droits de fn_create_book_drafts_from_import_rows ont change.';
  END IF;
  IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = v_sig) THEN
    RAISE EXCEPTION 'fn_create_book_drafts_from_import_rows n''est plus SECURITY DEFINER.';
  END IF;
  IF has_function_privilege('anon', v_sig, 'EXECUTE') OR has_function_privilege('authenticated', v_sig, 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_create_book_drafts_from_import_rows est executable par anon ou authenticated.';
  END IF;
END
$migration$;

COMMIT;
