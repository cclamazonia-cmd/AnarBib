-- ============================================================================
-- Évidences de l'audit du 03/09 (4/4) — les lignes évidentes de la file sont
-- tranchées et appliquées, une par une, à liste fermée
-- Foyer : REGISTRE §37 `CONV` · CONV-1, CONV-2, CONV-6, CONV-O2, CONV-O7
-- ============================================================================
-- DÉCISION. Xavier, 03/09 au soir : « corrige en base tout ce qui est assez
-- évident et ne demande pas de deviner ». Il a lui-même posé 87 verdicts dans
-- l'Atelier entre 20 h 00 et 20 h 07 ; ce qui suit ne touche que des lignes
-- ENCORE « à revoir » à l'instant où la migration passe, et seulement si la
-- fiche porte encore la forme que la file a vue (CONV-O6). Une ligne qu'il aura
-- tranchée entre-temps est laissée telle quelle.
--
-- CE QUI EST ÉVIDENT ICI, et pourquoi :
--   · une filiation en tête (« Jr., Armando Boito ») rejoint le patronyme — le
--     20/08 classait A3 « mécanisable », sans exception ;
--   · une particule portugaise en tête se rejette (« De Serpa Pimentel » → « Serpa
--     Pimentel, Antonio de », pays PT) — CONV-6 ; les particules italienne,
--     anglaise et belge francophone que le 20/08 disait « conserver » sont
--     ÉCARTÉES (rien n'est écrit) ;
--   · une mention de rôle sort du nom (« (Org) », « (org.) ») et le rôle passe sur
--     le contributeur (`organizador`) ;
--   · une forme directe à deux ou trois mots dont le dernier est le patronyme —
--     noms portugais, anglais, un catalan à prénom composé (« Jose Luis Catalinas »)
--     — s'inverse ; les pseudonymes (« Filósofo da Selva »), les surnoms
--     (« Marcos Cesar (Grito) ») et les chaînes cassées (« Crusao), Luis
--     Woollands (Juan ») restent à la main ;
--   · un point d'accès tout en capitales sans apostrophe ni particule se remet
--     en casse naturelle (CONV-1) ;
--   · une collectivité inversée se dé-inverse et se type ; un sigle ou un nom de
--     collectivité non inversé se type sans se renommer (CONV-O7) ; « Congrès
--     Anarchiste International » est un `congress`. Les fiches à deux organismes
--     (« Dieese, CESIT », « Biblioteca Terra Livre e Núcleo… ») et les
--     périodiques ne sont pas touchés.
--
-- LE GESTE est celui de `conv_revue_appliquer`, recopié pour une ligne : le
-- verdict est ÉCRIT dans la file (`valide` si la proposition est retenue,
-- `corrige` avec la valeur sinon, `decided_by` NULL = la migration, note
-- explicite), puis appliqué exactement comme l'écran l'aurait fait.
--
-- SECURITY INVOKER, aucun grant. Suite : conv_evidence_file_tests.sql.
-- ============================================================================
begin;

create or replace function public.fn_conv_trancher_evidence(p_qid bigint, p_apres text, p_decision text default 'appliquer', p_type text default null)
returns boolean
language plpgsql
security invoker
set search_path to 'public', 'pg_catalog'
as $$
declare
  q       public.catalog_review_queue%rowtype;
  a       public.authors%rowtype;
  v_cible text;
  v_dec   text;
  v_type  text := coalesce(p_type, 'collective');
begin
  select * into q from public.catalog_review_queue where id = p_qid;
  if q.id is null or q.decision <> 'a_revoir' or q.applique_le is not null or q.entity_kind <> 'author' then return false; end if;
  select * into a from public.authors where id = q.entity_id;
  if a.id is null or a.sort_name is distinct from q.avant then return false; end if;   -- CONV-O6

  if p_decision = 'ecarte' then
    update public.catalog_review_queue set decision = 'ecarte', decided_at = now(),
           note = coalesce(note || ' · ', '') || 'Écartée par migration (évidence, audit 03/09) : ' || coalesce(p_apres, 'la forme actuelle est juste.')
     where id = p_qid;
    return true;
  end if;

  v_cible := coalesce(nullif(btrim(p_apres), ''), q.apres_propose);
  if v_cible is null then return false; end if;
  v_dec := case when v_cible = q.apres_propose then 'valide' else 'corrige' end;

  if q.lot = 'autorite_collectivite' then
    if v_type not in ('collective', 'congress') then return false; end if;
    update public.authors
       set authority_type = v_type,
           structured_meta = jsonb_set(coalesce(structured_meta, '{}'::jsonb), '{authorityType}', to_jsonb(v_type), true),
           sort_name = v_cible, preferred_name = v_cible
     where id = a.id;
  elsif q.lot in ('autorite_casse', 'autorite_patronyme', 'autorite_forme') then
    update public.authors
       set preferred_name = case
             when preferred_name = btrim(split_part(sort_name, ', ', 2) || ' ' || split_part(sort_name, ', ', 1))
               then case when v_cible ~ ', ' and (length(v_cible) - length(replace(v_cible, ',', ''))) = 1
                         then btrim(split_part(v_cible, ', ', 2) || ' ' || split_part(v_cible, ', ', 1))
                         else v_cible end
             else preferred_name end,
           sort_name = v_cible
     where id = a.id;
  else
    return false;
  end if;

  update public.catalog_review_queue
     set decision = v_dec,
         valeur_retenue = case when v_dec = 'corrige' then v_cible else null end,
         decided_at = now(),
         applique_le = now(),
         note = coalesce(note || ' · ', '') || 'Tranchée et appliquée par migration (évidence, audit 03/09, décision Xavier du soir).'
   where id = p_qid;
  return true;
end;
$$;

comment on function public.fn_conv_trancher_evidence(bigint, text, text, text) is
  'Audit 03/09 · tranche UNE ligne encore « à revoir » de la file et l''applique comme '
  'conv_revue_appliquer l''aurait fait (point d''accès + forme d''affichage, ou type + '
  'nom pour une collectivité). Refuse si la ligne est déjà tranchée ou si la fiche a '
  'changé (CONV-O6). p_decision = ''ecarte'' n''écrit rien sur la fiche. Migration seulement.';

revoke all on function public.fn_conv_trancher_evidence(bigint, text, text, text) from public, anon, authenticated;

do $$
begin
  if has_function_privilege('anon', 'public.fn_conv_trancher_evidence(bigint,text,text,text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.fn_conv_trancher_evidence(bigint,text,text,text)', 'EXECUTE') then
    raise exception 'Évidences 03/09 — trancher est exécutable depuis l''application : abandon.';
  end if;
end $$;

-- La liste fermée. Les identifiants sont ceux des LIGNES de la file (qid), relus en
-- production le 03/09 à 20 h 10 ; sur une base fraîche aucune n'existe : 0.
do $$
declare r record; v_n int := 0; v_saut int := 0;
begin
  for r in select * from (values
    -- filiation en tête (A3)
    (845, 'Gonçalves Filho, Edson',                  'appliquer', null),
    (931, 'Costa Jr., Paulo José da',                'appliquer', null),
    (928, 'Boito Jr., Armando',                      'appliquer', null),
    -- particule en tête : rejetée en portugais, conservée ailleurs (CONV-6, audit A2 du 20/08)
    (922, 'Serpa Pimentel, Antonio de',              'appliquer', null),
    (926, 'italien moderne : la particule se conserve (Di Filippo, audit A2)',        'ecarte', null),
    (919, 'italien moderne : la particule se conserve (De Sario)',                    'ecarte', null),
    (925, 'anglophone : la particule se conserve (Van Vogt)',                         'ecarte', null),
    (927, 'belge francophone : la particule se conserve (De Greef, audit A2 du 20/08)', 'ecarte', null),
    -- mention de rôle dans le nom
    (921, 'Fernandes, Rubem César',                  'appliquer', null),
    (853, 'Golarons, Ricard de Vargas',              'appliquer', null),
    (883, 'Santos, Kauan Willian dos',               'appliquer', null),
    -- forme directe, dernier mot = patronyme
    (847, 'Schons, Carme Regina',                    'appliquer', null),
    (846, 'Aurélio, Daniel Rodrigues',               'appliquer', null),
    (865, 'Peres, Fernando Antônio',                 'appliquer', null),
    (864, 'Azevedo, Francisca Nogueira de',          'appliquer', null),
    (852, 'Berger, George',                          'appliquer', null),
    (855, 'Beiguelman-Messina, Giselle',             'appliquer', null),
    (860, 'Magalhães, Henrique',                     'appliquer', null),
    (874, 'Schmid, J.R',                             'appliquer', null),
    (913, 'Cleugh, James',                           'appliquer', null),
    (880, 'Cunha, José Gay da',                      'appliquer', null),
    (894, 'Catalinas, Jose Luis',                    'appliquer', null),
    (909, 'Parra, Lúcia Silva',                      'appliquer', null),
    -- casse (CONV-1)
    (870, 'Ratgeb',                                  'appliquer', null),
    (918, 'Zizen',                                   'appliquer', null),
    (826, 'Roberti Martins, Angela Maria',           'appliquer', null),
    -- collectivités inversées : dé-inverser et typer (CONV-O7, CONV-O2)
    (805, 'Congrès Anarchiste International',        'appliquer', 'congress'),
    (806, 'Federazione Anarchica Italiana',          'appliquer', 'collective'),
    (807, 'Organização Anarquista Socialismo Libertário', 'appliquer', 'collective'),
    (808, 'Fundación de Estudios Libertarios',       'appliquer', 'collective'),
    (810, 'Federação Anarquista Uruguai',            'appliquer', 'collective'),
    (787, 'Universidade Popular',                    'appliquer', 'collective'),
    (789, 'Association Des Amis De Henri Roorda',    'appliquer', 'collective'),
    (794, 'Federation of Libertarian Students',      'appliquer', 'collective'),
    -- collectivités non inversées : typer sans renommer
    (778, 'ANTEAG',                                  'appliquer', 'collective'),
    (780, 'CNA',                                     'appliquer', 'collective'),
    (785, 'DIEESE',                                  'appliquer', 'collective'),
    (786, 'ENFF',                                    'appliquer', 'collective'),
    (793, 'Lesbianas y feministas por la descriminalización del aborto', 'appliquer', 'collective'),
    (792, 'MOVIMENTO - Centro de Cultura e Autoformação', 'appliquer', 'collective'),
    (791, 'Núcleo de Sociabilidade Libertária - NU-SOL', 'appliquer', 'collective'),
    (796, 'Serviço Nacional d Informações – SNI',    'appliquer', 'collective')
  ) as t(qid, apres, decision, typ)
  loop
    if public.fn_conv_trancher_evidence(r.qid, r.apres, r.decision, r.typ) then v_n := v_n + 1; else v_saut := v_saut + 1; end if;
  end loop;
  raise notice 'Évidences 03/09 — % ligne(s) de la file tranchée(s) et appliquée(s), % laissée(s) (déjà tranchées, fiche changée, ou base fraîche).', v_n, v_saut;
end $$;

-- Le rôle des trois « (Org.) » passe sur le contributeur — seulement si la fiche
-- porte bien la forme nettoyée (c'est-à-dire si la ligne ci-dessus a été appliquée).
do $$
declare v_n int;
begin
  with faits as (
    update public.book_contributors c
       set role = 'organizador'
      from public.authors a
     where a.id = c.author_id and c.role = 'autor'
       and (a.id, a.sort_name) in ((10570, 'Fernandes, Rubem César'), (11362, 'Golarons, Ricard de Vargas'), (11465, 'Santos, Kauan Willian dos'))
    returning 1)
  select count(*) into v_n from faits;
  raise notice 'Évidences 03/09 — % contributeur(s) passé(s) au rôle organizador (la mention sortie du nom).', v_n;
end $$;

commit;
