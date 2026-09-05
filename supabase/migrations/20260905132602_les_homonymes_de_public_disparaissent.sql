-- B7 — les trois homonymes de `public` disparaissent ; les versions `ingest` sont les seules.
--
-- Relevé du 05/09/2026 en production. Quatre noms existent dans les deux schémas :
-- `set_updated_at` (trigger banal, il reste) et trois fonctions de décision
-- éditoriale sur catalogue partenaire, aux signatures différentes :
--
--   public.fn_bulk_create_book_drafts_from_run(p_run_id bigint, p_batch_id bigint, p_created_by uuid)
--   public.fn_bulk_set_partner_catalog_editorial_decision(p_row_ids bigint[], p_editorial_decision text, p_reviewed_by uuid)
--   public.fn_set_partner_catalog_editorial_decision(p_row_id bigint, p_editorial_decision text, p_reviewed_by uuid)
--
-- Tous les appels du code vivant sont QUALIFIÉS par schéma et visent `ingest.*`
-- (`fn_import_promote`, `fn_import_set_editorial`, `fn_import_reconcile_duplicates`) ;
-- aucune fonction, vue, trigger, Edge Function ni fichier du front n'appelle les
-- trois de `public` — sauf l'une l'autre (`public.fn_set_…` → `public.fn_bulk_set_…`
-- → `ingest.fn_set_…`), chaîne que personne n'emprunte. Elles sont SECURITY DEFINER
-- et exécutables par `authenticated` : trois entrées de plus au lint 0029 pour rien.
-- Le risque décrit par B7 — un `search_path` qui ferait résoudre l'autre — n'existe
-- plus dès qu'il n'y a plus qu'une fonction par nom.
--
-- Garde : la migration refuse si un corps de fonction ou une vue cite encore
-- `public.<nom>` qualifié, ou si les versions `ingest` manquent.

do $$
declare
  cible text;
  n int;
  cibles constant text[] := array[
    'public.fn_bulk_create_book_drafts_from_run(bigint, bigint, uuid)',
    'public.fn_bulk_set_partner_catalog_editorial_decision(bigint[], text, uuid)',
    'public.fn_set_partner_catalog_editorial_decision(bigint, text, uuid)'
  ];
  noms constant text[] := array[
    'fn_bulk_create_book_drafts_from_run',
    'fn_bulk_set_partner_catalog_editorial_decision',
    'fn_set_partner_catalog_editorial_decision'
  ];
  nom text;
begin
  -- Les versions ingest existent : ce sont elles que le code appelle.
  foreach nom in array noms loop
    if not exists (select 1 from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
                    where ns.nspname = 'ingest' and p.proname = nom) then
      raise exception 'ingest.% absente : rien à départager, migration refusée', nom;
    end if;
  end loop;

  -- Personne ne cite public.<nom> — ni fonction (hors les trois elles-mêmes), ni vue.
  foreach nom in array noms loop
    select count(*) into n
      from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
     where p.prosrc ~ ('public\.' || nom || '\s*\(')
       and not (ns.nspname = 'public' and p.proname = any (noms));
    if n > 0 then
      raise exception 'public.% est encore appelée par % fonction(s) : migration refusée', nom, n;
    end if;
    select count(*) into n from pg_views v where v.definition ~ ('public\.' || nom || '\s*\(');
    if n > 0 then
      raise exception 'public.% est citée par % vue(s) : migration refusée', nom, n;
    end if;
  end loop;

  foreach cible in array cibles loop
    if to_regprocedure(cible) is null then
      raise notice '% : déjà absente', cible;
    else
      execute 'drop function ' || cible;
      raise notice '% : supprimée', cible;
    end if;
  end loop;
end
$$;

comment on function ingest.fn_bulk_create_book_drafts_from_run(bigint, text[], text[], text, text, uuid) is
  'Seule fonction de ce nom depuis le 05/09/2026 (B7) : l''homonyme de public, appelé par personne, a été supprimé. Appelée par public.fn_import_promote.';
comment on function ingest.fn_bulk_set_partner_catalog_editorial_decision(bigint, text, text[], text[], text, uuid) is
  'Seule fonction de ce nom depuis le 05/09/2026 (B7) : l''homonyme de public, appelé par personne, a été supprimé.';
comment on function ingest.fn_set_partner_catalog_editorial_decision(bigint, bigint[], text, text, uuid) is
  'Seule fonction de ce nom depuis le 05/09/2026 (B7) : l''homonyme de public, appelé par personne, a été supprimé. Appelée par public.fn_import_set_editorial et public.fn_import_reconcile_duplicates.';

do $$
begin
  if to_regprocedure('public.fn_bulk_create_book_drafts_from_run(bigint, bigint, uuid)') is not null
     or to_regprocedure('public.fn_bulk_set_partner_catalog_editorial_decision(bigint[], text, uuid)') is not null
     or to_regprocedure('public.fn_set_partner_catalog_editorial_decision(bigint, text, uuid)') is not null then
    raise exception 'B7 : un homonyme de public existe encore';
  end if;
end
$$;
