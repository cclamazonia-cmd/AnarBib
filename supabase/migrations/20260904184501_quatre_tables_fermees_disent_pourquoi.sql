-- B4 — les quatre tables à RLS sans policy qui ne sont pas du transit portent
-- leur verdict en commentaire (relevé du 04/09/2026 en production).
--
-- Une table avec RLS activé et aucune policy est fermée à tout rôle applicatif ;
-- seules les fonctions SECURITY DEFINER (et les vues qu'elles servent) y accèdent.
-- Pour ces quatre-là, c'est voulu : aucun chemin du front ne lit ou n'écrit la
-- table directement, tout passe par des fonctions nommées ci-dessous. La liste
-- des tables fermées attendues vit dans `deploy/bootstrap.sh`
-- (`SANS_POLICY_ATTENDUES`, contrôle de restauration) : l'ajout d'une policy ou
-- la disparition d'une de ces tables y fait échouer le contrôle, à dessein.
--
-- Rien d'autre ne change : ni droits, ni policies, ni données.

comment on table public.author_name_aliases is
  'Formes variantes de noms d''autorité (1 644 lignes au 04/09/2026). '
  'RLS sans policy, voulu : aucune lecture directe. Servie par des fonctions SECURITY DEFINER '
  '(merge_author, preview_merge_author, suggest_author_duplicates, suggest_authority_duplicates, '
  'fn_conv_fusionner_doublon_exact, api.search_catalog_v1) et deux vues '
  '(v_author_alias_candidates_unique, v_author_alias_worklist). Verdict B4, 04/09/2026.';

comment on table public.library_themes is
  'Table métier reliant une bibliothèque logique à un manifeste visuel de thème AnarBib. '
  'RLS sans policy, voulu : lue et écrite par fn_ensure_library_theme, get_library_theme_config, '
  'get_library_theme_config_by_library_id, set_library_theme_config, '
  'set_library_theme_config_by_library_id et api.get_library_institutional_workspace. '
  'Verdict B4, 04/09/2026.';

comment on table public.library_theme_configs is
  'Configuração visual leve por biblioteca para sobrepor o manifest do tema. '
  'RLS sans policy, voulu : même circuit que library_themes (get/set_library_theme_config*), '
  'aucune lecture directe. Vide au 04/09/2026. Verdict B4, 04/09/2026.';

comment on table public.interlibrary_loan_events is
  'Audit trail des prêts inter-bibliothèques. Anon SELECT révoqué le 2026-04-26 (palier 3). '
  'RLS sans policy, voulu : journal écrit par fn_v2_log_emprestimo_interbibliotecas_event '
  '(SECURITY DEFINER), jamais lu directement par le front. Vide au 04/09/2026 : le PEB n''a pas '
  'encore d''écran (item G6). Verdict B4, 04/09/2026.';

do $$
declare
  t text;
begin
  foreach t in array array['author_name_aliases', 'library_themes', 'library_theme_configs', 'interlibrary_loan_events']
  loop
    if to_regclass('public.' || t) is null then
      raise exception 'public.% absente', t;
    end if;
    if coalesce(obj_description(('public.' || t)::regclass, 'pg_class'), '') not like '%Verdict B4, 04/09/2026%' then
      raise exception 'public.% : commentaire non posé', t;
    end if;
  end loop;
end
$$;
