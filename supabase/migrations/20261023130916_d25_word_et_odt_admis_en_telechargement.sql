-- =========================================================================
-- D25 — les fichiers Word et ODT sont admis, en téléchargement seulement
-- =========================================================================
-- Date     : 2026-10-23
-- Chantier : documents numériques — REGISTRE §47 (NUMDIF)
-- Auteur   : Claude (assistant·e), pour la coordination
-- Ref      : docs/journal/audits/INVENTAIRE_d25_word_odt_anarchief_2026-10-23.md ;
--            supabase/functions/deposit-digital-candidate (le versement),
--            supabase/functions/read-digital-asset (la lecture)
--
-- POURQUOI
--   Décision de Xavier du 23/10/2026 (D25) : 28 fichiers Word/ODT d'Anarchief,
--   écartés le 15/10 parce que les seaux n'acceptaient que le PDF, entrent dans
--   AnarBib — en téléchargement seulement (aucune lecture en ligne : le lecteur
--   ne sait afficher que le PDF), à la portée de la lettre de leur lot comme les
--   PDF, versés par la file NUMDIF avec empreinte.
--
-- CE QUE FAIT LE PAQUET
--   1. Les deux seaux de la file (anarbib-pdf-public, pdf-restrito) admettent
--      aussi .doc, .docx et .odt. Ils gardent leur nom : la portée (publique ou
--      restreinte) reste celle du seau, le format n'y change rien.
--   2. Un type de ressource « documento » et un usage « telechargement », sur
--      les ressources des notices ET des brouillons (une reprise recopie les
--      ressources dans le brouillon : sans cela, reprendre une notice qui porte
--      un fichier Word échouerait).
--   3. L'enregistrement d'un versement (ingest.fn_digital_candidate_deposit_record)
--      reconnaît un document au nom du fichier versé (.doc, .docx, .odt) :
--      type « documento », usage « telechargement », MIME du format, libellé
--      « (arquivo de texto) », jamais ressource principale (la notice garde
--      son PDF ou son lien pour la lecture).
--   4. Le réalignement (garde et enregistrement) ne fait plus d'un document un
--      PDF : il change le seau, la portée et les droits, et garde le type
--      « documento » ; la garde le dit « aligné » sur le seau, la portée et les
--      droits seulement.
--      La ressource « à lire » d'une notice (get_book_primary_public_digital_asset_v2 :
--      la principale, SINON LA PLUS RÉCENTE — 403 ressources actives sont sur
--      des notices sans principale) n'est jamais un document : sans cela, un
--      fichier Word versé après un lien deviendrait le bouton « Lire ».
--   5. Une porte publique, api.book_documents_v1(book_id), liste les documents
--      d'une notice pour sa page (le public, et le restreint signalé « accès
--      accordé » ou non) : 0028 passe de 20 à 21, 0029 de 441 à 442 (verdicts
--      au complément du 23/10 des deux audits ; T10 et T12 de grants_herites).
--   Les fonctions sont patchées depuis leur définition RÉELLE, par motif exact,
--   le nombre d'occurrences vérifié (une ou deux selon le motif), droits
--   vérifiés inchangés. Banc : tests/sql/d25_documents_word_odt_tests.sql.
-- =========================================================================

BEGIN;

-- 1. les seaux
UPDATE storage.buckets
   SET allowed_mime_types = (
         SELECT array_agg(DISTINCT m ORDER BY m) FROM unnest(coalesce(allowed_mime_types, ARRAY['application/pdf']) || ARRAY[
           'application/msword',
           'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
           'application/vnd.oasis.opendocument.text']) m)
 WHERE id IN ('anarbib-pdf-public', 'pdf-restrito');

-- 2. le type et l'usage, sur les notices et les brouillons
ALTER TABLE public.book_digital_resources DROP CONSTRAINT book_digital_resources_resource_type_chk;
ALTER TABLE public.book_digital_resources ADD CONSTRAINT book_digital_resources_resource_type_chk
  CHECK (resource_type = ANY (ARRAY['pdf_publico', 'pdf_restrito', 'audio', 'video', 'image', 'link_externo', 'recurso_digital', 'epub', 'documento']));
ALTER TABLE public.book_digital_resources DROP CONSTRAINT book_digital_resources_usage_type_chk;
ALTER TABLE public.book_digital_resources ADD CONSTRAINT book_digital_resources_usage_type_chk
  CHECK (usage_type = ANY (ARRAY['leitura_online', 'escuta_online', 'visualizacao_online', 'link_externo', 'telechargement']));
ALTER TABLE public.book_draft_digital_resources DROP CONSTRAINT book_draft_digital_resources_resource_type_chk;
ALTER TABLE public.book_draft_digital_resources ADD CONSTRAINT book_draft_digital_resources_resource_type_chk
  CHECK (resource_type = ANY (ARRAY['pdf_publico', 'pdf_restrito', 'audio', 'video', 'image', 'link_externo', 'recurso_digital', 'epub', 'documento']));
ALTER TABLE public.book_draft_digital_resources DROP CONSTRAINT book_draft_digital_resources_usage_type_chk;
ALTER TABLE public.book_draft_digital_resources ADD CONSTRAINT book_draft_digital_resources_usage_type_chk
  CHECK (usage_type = ANY (ARRAY['leitura_online', 'escuta_online', 'visualizacao_online', 'link_externo', 'telechargement']));

-- 3 et 4. les fonctions, patchées par motif exact
DO $d25$
DECLARE
  v_fn regprocedure;
  v_def text;
  v_acl text;
  r record;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('ingest.fn_digital_candidate_deposit_record(bigint,uuid,text,text,text,text,bigint)',
       $m$v_c.book_id, v_dest->>'resource_type', 'leitura_online', v_dest->>'access_scope', 'active', true,$m$,
       $n$v_c.book_id,
    -- D25 (23/10/2026) : un document Word/ODT, reconnu au nom du fichier versé
    CASE WHEN p_path ~* '\.(docx?|odt)$' THEN 'documento' ELSE v_dest->>'resource_type' END,
    CASE WHEN p_path ~* '\.(docx?|odt)$' THEN 'telechargement' ELSE 'leitura_online' END,
    v_dest->>'access_scope', 'active', true,$n$, 1),
      ('ingest.fn_digital_candidate_deposit_record(bigint,uuid,text,text,text,text,bigint)',
       $m$NOT EXISTS (SELECT 1 FROM public.book_digital_resources r$m$,
       $n$p_path !~* '\.(docx?|odt)$' AND NOT EXISTS (SELECT 1 FROM public.book_digital_resources r$n$, 1),
      ('ingest.fn_digital_candidate_deposit_record(bigint,uuid,text,text,text,text,bigint)',
       $m$    'application/pdf',$m$,
       $n$    CASE lower(substring(p_path FROM '\.([A-Za-z]+)$'))
      WHEN 'doc' THEN 'application/msword'
      WHEN 'docx' THEN 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      WHEN 'odt' THEN 'application/vnd.oasis.opendocument.text'
      ELSE 'application/pdf' END,$n$, 1),
      ('ingest.fn_digital_candidate_deposit_record(bigint,uuid,text,text,text,text,bigint)',
       $m$' (fac-símile)'$m$,
       $n$CASE WHEN p_path ~* '\.(docx?|odt)$' THEN ' (arquivo de texto)' ELSE ' (fac-símile)' END$n$, 1),
      ('ingest.fn_digital_candidate_deposit_record(bigint,uuid,text,text,text,text,bigint)',
       $m$'Fac-símile da edição da ficha, fornecido pela mesma fonte que a ficha (NUMDIF-6 ; '$m$,
       $n$CASE WHEN p_path ~* '\.(docx?|odt)$' THEN 'Arquivo de texto (Word/ODT) da obra da ficha' ELSE 'Fac-símile da edição da ficha' END
      || ', fornecido pela mesma fonte que a ficha (NUMDIF-6 ; '$n$, 1),
      ('public.fn_digital_resource_realign_garde(bigint)',
       $m$AND v_r.resource_type IS NOT DISTINCT FROM v_dest->>'resource_type'$m$,
       $n$AND (v_r.resource_type = 'documento' OR v_r.resource_type IS NOT DISTINCT FROM v_dest->>'resource_type')$n$, 2),
      ('ingest.fn_digital_resource_realign_record(bigint,uuid,text,text,text,text,text)',
       $m$resource_type = v_dest->>'resource_type',$m$,
       $n$resource_type = CASE WHEN r.resource_type = 'documento' THEN 'documento' ELSE v_dest->>'resource_type' END,$n$, 2),
      ('public.get_book_primary_public_digital_asset_v2(bigint)',
       $m$and r.is_active = true$m$,
       $n$and r.is_active = true and r.resource_type <> 'documento'$n$, 1)
    ) v(fn, motif, neuf, attendu)
  LOOP
    v_fn := r.fn::regprocedure;
    v_def := pg_get_functiondef(v_fn);
    IF position(r.neuf IN v_def) > 0 THEN
      RAISE NOTICE 'D25 : % déjà patchée pour ce motif (rejeu), sans effet.', v_fn;
      CONTINUE;
    END IF;
    IF (length(v_def) - length(replace(v_def, r.motif, ''))) / length(r.motif) <> r.attendu THEN
      RAISE EXCEPTION 'D25 : motif trouvé % fois dans % (% attendu) — relire la définition réelle : %',
        (length(v_def) - length(replace(v_def, r.motif, ''))) / length(r.motif), v_fn, r.attendu, left(r.motif, 60);
    END IF;
    v_acl := (SELECT proacl::text FROM pg_proc WHERE oid = v_fn);
    EXECUTE replace(v_def, r.motif, r.neuf);
    IF (SELECT proacl::text FROM pg_proc WHERE oid = v_fn) IS DISTINCT FROM v_acl THEN
      RAISE EXCEPTION 'D25 : les droits de % ont changé', v_fn;
    END IF;
  END LOOP;
END
$d25$;

-- 5. la liste des documents d'une notice, pour la page de la notice
--    La notice ne montre qu'UNE ressource à lire (la principale) ; un document
--    n'est jamais principal. Et la RLS de book_digital_resources ne laisse voir
--    au lecteur que le public du seau public : un membre de la bibliothèque
--    détentrice ne verrait pas le document restreint qu'il a le droit de lire.
--    Porte DEFINER, ouverte à anon (page publique) : mêmes règles que
--    get_accessible_digital_asset_by_id_v2 — notice d'un catalogue lisible,
--    public validé, restreint marqué « accès accordé » pour qui le lit. Ni
--    seau, ni chemin, ni adresse de fichier : on lit par l'identifiant, via
--    read-digital-asset, qui signe l'URL.
CREATE FUNCTION api.book_documents_v1(p_book_id bigint)
RETURNS TABLE(asset_id bigint, label text, mime_type text, access_scope text, access_granted boolean, file_size_bytes bigint)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $fn$
  SELECT r.id, r.label, r.mime_type, r.access_scope,
         CASE WHEN r.access_scope = 'publico' THEN true
              ELSE public.fn_current_user_conta_ativa() AND public.fn_current_user_is_member_of_holding_library(r.book_id) END,
         CASE WHEN r.metadata->>'file_size_bytes' ~ '^\d{1,15}$' THEN (r.metadata->>'file_size_bytes')::bigint END
    FROM public.book_digital_resources r
   WHERE r.book_id = p_book_id
     AND r.resource_type = 'documento'
     AND r.status = 'active' AND coalesce(r.is_active, false)
     AND r.storage_path IS NOT NULL
     AND ((r.access_scope = 'publico' AND coalesce(r.bibliographic_match_validated, false))
          OR r.access_scope = 'conta_ativa')
     AND EXISTS (SELECT 1 FROM public.book_holdings h
                  WHERE h.book_id = r.book_id AND private.fn_catalog_library_visible_to_caller(h.library_id))
   ORDER BY r.label, r.id
$fn$;
COMMENT ON FUNCTION api.book_documents_v1(bigint) IS
  'D25 (23/10/2026) : les fichiers Word/ODT d''une notice, à télécharger. Porte publique (anon) : catalogue lisible, public validé, restreint signalé avec access_granted. Lecture par read-digital-asset.';
REVOKE EXECUTE ON FUNCTION api.book_documents_v1(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION api.book_documents_v1(bigint) TO anon, authenticated, service_role;

-- garde : ce que le paquet devait faire est fait
DO $garde$
BEGIN
  IF (SELECT count(*) FROM storage.buckets
       WHERE id IN ('anarbib-pdf-public', 'pdf-restrito')
         AND allowed_mime_types @> ARRAY['application/pdf', 'application/msword',
               'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
               'application/vnd.oasis.opendocument.text']) <> 2 THEN
    RAISE EXCEPTION 'D25 : les deux seaux n''admettent pas PDF, .doc, .docx et .odt';
  END IF;
  IF has_function_privilege('anon', 'api.book_documents_v1(bigint)', 'EXECUTE') IS NOT TRUE
     OR NOT has_function_privilege('authenticated', 'api.book_documents_v1(bigint)', 'EXECUTE')
     OR EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'api.book_documents_v1(bigint)'::regprocedure
                 AND proacl::text ~ '(^|[{,])=X/') THEN
    RAISE EXCEPTION 'D25 : api.book_documents_v1 doit être ouverte à anon et authenticated, et à eux seuls (pas à PUBLIC)';
  END IF;
END
$garde$;

COMMIT;
