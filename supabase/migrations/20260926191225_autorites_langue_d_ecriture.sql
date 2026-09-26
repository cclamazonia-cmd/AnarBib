-- =========================================================================
-- Autorités : la langue d'écriture principale (26/09/2026)
-- =========================================================================
-- Réf. : backlog v34 C8 (enrichir les autorités) ; demande de Xavier du 26/09
--        (« nationalité, années de naissance et de mort, langue d'écriture
--        principale ») ; DOC-CONV-1 (une seule vérité, plusieurs rendus).
--
-- La fiche d'autorité n'avait aucun endroit pour dire dans quelle langue une
-- personne écrit. `name_lang` dit la langue de la FORME DU NOM, pas celle de
-- l'œuvre. Colonne neuve `writing_language`, au même référentiel que la langue
-- des notices (`books.idioma`, src/lib/languages.js, CONV-7) : un code BCP-47
-- (`fr`, `es`, `pt-BR`…), jamais un libellé ; le libellé se calcule à
-- l'affichage (clés `language.<code>`, dix locales).
--
-- Trois endroits à tenir ensemble, comme pour une colonne de `books` :
--   * `author_drafts` porte la colonne (le formulaire écrit le brouillon) ;
--   * `publish_author_draft` la recopie vers `authors` (insertion ET mise à jour) ;
--   * `create_author_draft_from_author` la recopie vers le brouillon.
-- Les deux fonctions sont reprises de leur définition RÉELLE en production
-- (lue le 26/09) : seule la colonne est ajoutée aux listes.
-- =========================================================================

BEGIN;

-- 1) Les colonnes
ALTER TABLE public.authors
  ADD COLUMN IF NOT EXISTS writing_language text
  CONSTRAINT authors_writing_language_code CHECK (writing_language ~ '^[a-z]{2}(-[A-Z]{2})?$');
COMMENT ON COLUMN public.authors.writing_language IS
  'Langue d''écriture principale : code BCP-47 du référentiel des notices (src/lib/languages.js, comme books.idioma), jamais un libellé. Distincte de name_lang (langue de la forme du nom).';

ALTER TABLE public.author_drafts
  ADD COLUMN IF NOT EXISTS writing_language text
  CONSTRAINT author_drafts_writing_language_code CHECK (writing_language ~ '^[a-z]{2}(-[A-Z]{2})?$');
COMMENT ON COLUMN public.author_drafts.writing_language IS
  'Langue d''écriture principale, recopiée vers authors.writing_language par publish_author_draft.';

-- 2) Publication d'un brouillon : la colonne suit
CREATE OR REPLACE FUNCTION public.publish_author_draft(p_draft_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_draft public.author_drafts%rowtype;
  v_author_id bigint;
begin
  -- #79 RBAC : publication reservee au staff de catalogage (librarian/coordenador).
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.' USING HINT = 'error.catalog.staff_only';
  END IF;
  select * into v_draft
  from public.author_drafts
  where id = p_draft_id;

  if not found then
    raise exception 'Rascunho de autor nao encontrado: %', p_draft_id;
  end if;

  if v_draft.status = 'cancelled' then
    raise exception 'Este rascunho de autor foi descartado.';
  end if;

  if v_draft.published_author_id is null then
    insert into public.authors (
      preferred_name, sort_name, biography, birth_year, death_year, country,
      source_kind, source_label, source_url, viaf_id, isni, wikidata_id,
      variant_forms, photo_object_path, notes, structured_meta, writing_language,
      created_by, updated_by, updated_at
    )
    values (
      v_draft.preferred_name, v_draft.sort_name, v_draft.biography,
      v_draft.birth_year, v_draft.death_year, v_draft.country,
      v_draft.source_kind, v_draft.source_label, v_draft.source_url,
      v_draft.viaf_id, v_draft.isni, v_draft.wikidata_id,
      v_draft.variant_forms, v_draft.photo_object_path, v_draft.notes,
      coalesce(v_draft.structured_meta, '{}'::jsonb), v_draft.writing_language,
      coalesce(v_draft.created_by, auth.uid()),
      coalesce(v_draft.updated_by, auth.uid()), now()
    )
    returning id into v_author_id;
  else
    update public.authors
    set
      preferred_name = v_draft.preferred_name,
      sort_name = v_draft.sort_name,
      biography = v_draft.biography,
      birth_year = v_draft.birth_year,
      death_year = v_draft.death_year,
      country = v_draft.country,
      source_kind = v_draft.source_kind,
      source_label = v_draft.source_label,
      source_url = v_draft.source_url,
      viaf_id = v_draft.viaf_id,
      isni = v_draft.isni,
      wikidata_id = v_draft.wikidata_id,
      variant_forms = v_draft.variant_forms,
      photo_object_path = v_draft.photo_object_path,
      notes = v_draft.notes,
      structured_meta = coalesce(v_draft.structured_meta, '{}'::jsonb),
      writing_language = v_draft.writing_language,
      updated_by = coalesce(v_draft.updated_by, auth.uid()),
      updated_at = now()
    where id = v_draft.published_author_id
    returning id into v_author_id;
  end if;

  update public.author_drafts
  set
    published_author_id = v_author_id,
    status = 'published',
    updated_by = coalesce(v_draft.updated_by, auth.uid()),
    updated_at = now()
  where id = p_draft_id;

  return v_author_id;
end;
$function$;

-- 3) Brouillon depuis une fiche publiée : la colonne suit
CREATE OR REPLACE FUNCTION public.create_author_draft_from_author(p_author_id bigint, p_batch_id bigint DEFAULT NULL::bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id bigint;
begin
  insert into public.author_drafts (
    published_author_id, batch_id, action, status,
    preferred_name, sort_name, biography, birth_year, death_year, country,
    source_kind, source_label, source_url, viaf_id, isni, wikidata_id,
    variant_forms, photo_object_path, notes, structured_meta, writing_language,
    created_by, updated_by
  )
  select
    a.id, p_batch_id, 'update', 'draft',
    a.preferred_name, a.sort_name, a.biography, a.birth_year, a.death_year, a.country,
    a.source_kind, a.source_label, a.source_url, a.viaf_id, a.isni, a.wikidata_id,
    a.variant_forms, a.photo_object_path, a.notes,
    coalesce(a.structured_meta, '{}'::jsonb), a.writing_language,
    auth.uid(), auth.uid()
  from public.authors a
  where a.id = p_author_id
  returning id into v_id;

  if v_id is null then
    raise exception 'Autor nao encontrado: %', p_author_id;
  end if;

  return v_id;
end;
$function$;

-- 4) Vérification
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'authors' AND column_name = 'writing_language')
     OR NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'author_drafts' AND column_name = 'writing_language') THEN
    RAISE EXCEPTION 'writing_language absente d''une des deux tables';
  END IF;
  IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public' AND p.proname IN ('publish_author_draft', 'create_author_draft_from_author')
         AND p.prosrc LIKE '%writing_language%') <> 2 THEN
    RAISE EXCEPTION 'une fonction de recopie ignore writing_language';
  END IF;
  IF has_function_privilege('anon', 'public.publish_author_draft(bigint)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.create_author_draft_from_author(bigint, bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'fonction de recopie ouverte à anon';
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;
