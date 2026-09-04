-- =========================================================================
-- Paquet moisson-oai-reservee-a-l-administration — moissonner un entrepot
-- OAI-PMH est un geste de reseau, comme deposer un catalogue compagnon
-- =========================================================================
-- Date     : 2026-09-04
-- Chantier : importations — qui peut faire entrer quoi dans le catalogue
-- Auteur   : coordination AnarBib (decision Xavier du 04/09/2026, apres-midi)
--
-- POURQUOI
--   Le paquet du matin (20260904121500) a pose la doctrine : la provenance
--   decide, pas le volume. Le catalogue PROPRE de la bibliotheque reste a la
--   coordination ; le catalogue d'une bibliotheque COMPAGNE (partner_deposit)
--   engage le reseau et passe a l'administration.
--
--   Un entrepot OAI-PMH moissonne est un fonds tiers, exactement de la meme
--   nature, avec le volume en plus. Le chemin etait bancal : enregistrer
--   l'entrepot etait deja un geste admin (fn_import_register_oai_source),
--   mais declencher la moisson et faire entrer le lot dans la file restaient
--   ouverts a la coordination de la bibliotheque rattachee — l'admin ouvrait
--   le robinet, la coordination tirait. En production aucune source oai_pmh
--   n'existe : ce paquet ne retire rien a personne.
--
-- CE QUE FAIT LE PAQUET
--   1. fn_import_harvest_oai : administration du reseau seulement.
--   2. fn_import_create et fn_import_promote : la garde du matin s'etend de
--      partner_deposit a oai_pmh (un run de moisson passe par la meme
--      promotion que les autres).
--   Le refus porte le meme HINT 'error.import.deposit_admin_only' ; les
--   libelles des dix locales sont elargis a la moisson OAI dans le meme
--   commit. Le cron hebdomadaire (ingest.fn_cron_import_harvest_oai) ne passe
--   pas par fn_import_harvest_oai et n'est pas concerne.
--
-- LA FORME
--   Aucun corps n'est recopie : on part de pg_get_functiondef (la definition
--   REELLE — signature, defauts, search_path, messages unifies par B14) et on
--   n'y remplace que la chaine visee, avec verification que la substitution a
--   bien eu lieu (patron 20260901091431). Le matin meme, une recopie depuis le
--   baseline avait reintroduit un oracle d'existence : c'est la lecon.
--
-- CHECKLIST DOCTRINE
--   [x] Fonctions SECURITY DEFINER : definition reelle conservee (search_path,
--       volatilite, defauts) ; les GRANT survivent a CREATE OR REPLACE
--   [x] Aucune table, vue, policy ou CHECK touchee ; RLS inchangee
--   [x] Substitutions verifiees : la migration ECHOUE si un motif manque
--   [x] Bout-en-bout fonctionnel dans tests/sql/import_moisson_oai_admin_tests.sql
-- =========================================================================

begin;

do $$
declare
  v_def text;
  v_new text;
  v_old text;
  v_rep text;
begin
  -- ── 1. fn_import_harvest_oai : coordenador -> admin reseau ────────────
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'fn_import_harvest_oai'
     and pg_get_function_identity_arguments(p.oid) = 'p_source_id bigint, p_max_lots integer';
  if v_def is null then
    raise exception 'fn_import_harvest_oai(bigint, integer) introuvable';
  end if;

  v_old := E'  IF v_actor.role IS DISTINCT FROM \'coordenador\' AND NOT public.fn_caller_is_network_admin() THEN\n'
        || E'    RAISE EXCEPTION \'Acesso restrito ao coordenador da biblioteca.\';\n'
        || E'  END IF;';
  v_rep := E'  -- 04/09/2026 : moissonner un entrepot tiers est un geste de reseau, comme\n'
        || E'  -- deposer un catalogue compagnon (20260904121500). Admin reseau seulement.\n'
        || E'  IF NOT public.fn_caller_is_network_admin() THEN\n'
        || E'    RAISE EXCEPTION \'Moisson OAI-PMH reservada a administracao da rede.\'\n'
        || E'      USING HINT = \'error.import.deposit_admin_only\';\n'
        || E'  END IF;';
  if position(v_old in v_def) = 0 then
    raise exception 'fn_import_harvest_oai : le bloc coordenador attendu est absent — la definition a change, relire avant de substituer';
  end if;
  v_new := replace(v_def, v_old, v_rep);
  if v_new = v_def or position('error.import.deposit_admin_only' in v_new) = 0 then
    raise exception 'fn_import_harvest_oai : substitution non appliquee';
  end if;
  execute v_new;

  -- ── 2. fn_import_create et fn_import_promote : partner_deposit -> + oai_pmh ─
  v_old := E'IF v_source_kind = \'partner_deposit\' AND NOT public.fn_caller_is_network_admin() THEN';
  v_rep := E'IF v_source_kind IN (\'partner_deposit\', \'oai_pmh\') AND NOT public.fn_caller_is_network_admin() THEN';

  for v_def in
    select pg_get_functiondef(p.oid)
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname in ('fn_import_create', 'fn_import_promote')
  loop
    if position(v_old in v_def) = 0 then
      raise exception 'garde partner_deposit absente dans : %', left(v_def, 100);
    end if;
    v_new := replace(v_def, v_old, v_rep);
    if v_new = v_def then
      raise exception 'substitution non appliquee dans : %', left(v_def, 100);
    end if;
    execute v_new;
  end loop;
end
$$;

comment on function public.fn_import_harvest_oai(bigint, integer) is
  'Declenche un moissonnage OAI-PMH pour une source donnee : cree un run (queued), '
  'pose le verrou in_progress, puis appelle l''EF harvest-oai-pmh par pg_net '
  '(ingest.fn_dispatch_oai_harvest). Asynchrone. Un in_progress de plus de 30 '
  'minutes est repris (reclaimed_stale_lock = true). Depuis le 04/09/2026 : '
  'administration du reseau seulement (HINT error.import.deposit_admin_only), '
  'comme le depot d''un catalogue compagnon — un entrepot moissonne est un fonds tiers.';

-- ── 3. Verification structurelle (aucune dependance aux donnees) ──────────
do $verif$
declare
  v_def text;
  v_n int := 0;
begin
  for v_def in
    select pg_get_functiondef(p.oid)
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('fn_import_harvest_oai', 'fn_import_create', 'fn_import_promote')
  loop
    if position('error.import.deposit_admin_only' in v_def) = 0 then
      raise exception 'garde admin manquante : %', left(v_def, 100);
    end if;
    if v_def like '%fn_import_harvest_oai%' and position('IS DISTINCT FROM ''coordenador''' in v_def) > 0 then
      raise exception 'fn_import_harvest_oai porte encore la porte coordenador';
    end if;
    if v_def not like '%fn_import_harvest_oai%' and position('(''partner_deposit'', ''oai_pmh'')' in v_def) = 0 then
      raise exception 'garde oai_pmh manquante : %', left(v_def, 100);
    end if;
    v_n := v_n + 1;
  end loop;
  if v_n <> 3 then
    raise exception '% fonction(s) relue(s) au lieu de 3', v_n;
  end if;
  raise notice 'Paquet moisson-oai-reservee-a-l-administration : verifications OK';
end
$verif$;

commit;
