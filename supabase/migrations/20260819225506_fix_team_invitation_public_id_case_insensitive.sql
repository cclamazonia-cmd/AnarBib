-- fn_team_propose_invitation : recherche du public_id insensible a la casse.
--
-- SYMPTOME. Inviter quelqu'un dans l'equipe d'une bibliotheque echouait
-- systematiquement avec « not_found: no profile with that public_id », meme en
-- fournissant un identifiant parfaitement valide. Verifie de bout en bout : une
-- coordenadora BTL invitant une personne reelle avec son vrai public_id est
-- refusee.
--
-- CAUSE. La fonction cherche
--     WHERE public_id = upper(btrim(p_invited_public_id))
-- Elle met l'ENTREE en majuscules mais pas la COLONNE. Tant que les public_id
-- avaient la forme sequentielle « U000123 » (deja en majuscules), la
-- comparaison tombait juste par hasard. Depuis la regeneration du 2026-08-17
-- (migration 20260817032913, fermeture de la fuite d'annuaire), generate_public_id
-- produit de l'hexadecimal MINUSCULE : 14 des 15 profils contiennent desormais
-- des minuscules, et aucune entree ne peut plus correspondre.
--
-- L'invitation d'equipe est donc cassee depuis le 17/08, silencieusement : le
-- message d'erreur accuse l'identifiant fourni, jamais la comparaison.
-- 20260820200000 (retrait du DEFAULT sequentiel) n'a pas cause la panne, il l'a
-- rendue VISIBLE en faisant echouer invitation_equipe_tests en CI.
--
-- PORTEE VERIFIEE — seule cette fonction est touchee. fn_painel_search_reader
-- (recherche au comptoir), fn_painel_find_profile_by_lookup, resolve_login_email
-- (connexion) et fn_network_resolve_public_id resolvent tous correctement un
-- identifiant minuscule : ils comparent les DEUX cotes normalises, ou cherchent
-- sur plusieurs colonnes.
--
-- CORRECTIF. Normaliser les deux cotes, comme le fait deja
-- fn_network_resolve_public_id :
--     WHERE upper(btrim(public_id)) = upper(btrim(p_invited_public_id))
-- Insensible a la casse, donc compatible avec l'ancien format « U000123 »
-- comme avec le nouveau. A cette echelle (15 profils) l'absence d'index sur
-- l'expression est sans consequence.
--
-- Applique par REMPLACEMENT TEXTUEL sur la definition courante plutot que par
-- recopie integrale : la fonction fait 60 lignes et a deja ete modifiee par
-- plusieurs chantiers ; la recopier a la main risquerait d'annuler leurs
-- changements. L'assertion ci-dessous fait echouer la migration si le motif
-- n'est pas trouve exactement une fois, plutot que de laisser passer un
-- remplacement silencieusement sans effet.
do $$
declare
  v_def text;
  v_ancien constant text := 'WHERE public_id = upper(btrim(p_invited_public_id))';
  v_neuf   constant text := 'WHERE upper(btrim(public_id)) = upper(btrim(p_invited_public_id))';
  v_occ integer;
begin
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'fn_team_propose_invitation';

  if v_def is null then
    raise exception 'fn_team_propose_invitation introuvable.';
  end if;

  -- Deja corrigee (rejeu de la migration) : on ne fait rien.
  if position(v_neuf in v_def) > 0 then
    raise notice 'fn_team_propose_invitation deja insensible a la casse : rien a faire.';
    return;
  end if;

  v_occ := (length(v_def) - length(replace(v_def, v_ancien, ''))) / length(v_ancien);
  if v_occ <> 1 then
    raise exception 'Motif attendu trouve % fois (1 attendue) dans fn_team_propose_invitation : la fonction a change, correctif a revoir.', v_occ;
  end if;

  execute replace(v_def, v_ancien, v_neuf);
end $$;

comment on function public.fn_team_propose_invitation(uuid, text, text) is
  'Propose une invitation d''equipe (role librarian). Recherche du public_id INSENSIBLE A LA CASSE depuis le 2026-08-20 : les identifiants sont en hexadecimal minuscule depuis la regeneration du 17/08, et la comparaison ne normalisait que l''entree.';
