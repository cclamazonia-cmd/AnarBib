-- =============================================================================
-- Sonde de sante des ressources numeriques
-- =============================================================================
-- Date     : 2026-08-21
-- Chantier : ressources numeriques / troisieme voie (DECISION_profil_numerisation §1)
--
-- POURQUOI MAINTENANT. Depuis 20260821000000, une ressource restreinte n'est
-- plus lisible par « tout compte actif » mais par les seuls membres d'une
-- bibliotheque DETENTRICE. La lisibilite depend donc desormais de
-- `book_holdings` — une table que le catalogage modifie pour de tout autres
-- raisons que les droits de lecture.
--
-- Consequence non voulue : retirer le dernier exemplaire d'un livre rend son
-- PDF restreint ILLISIBLE PAR TOUT LE MONDE. Silencieusement. La ressource
-- reste `is_active = true`, aucune erreur n'est levee, aucune trace n'est
-- ecrite : elle cesse simplement de s'ouvrir. C'est exactement la forme de
-- panne muette que le reseau a deja rencontree ailleurs (flux de notifications
-- morts, verrou de sauvegarde orphelin) et dont on sait qu'elle ne se decouvre
-- que par hasard, des mois plus tard.
--
-- CE QU'ON NE FAIT PAS. Pas de trigger interdisant le retrait du dernier
-- exemplaire : une bibliotheque peut legitimement retirer un exemplaire abime,
-- perdu ou cede sans vouloir pour autant fermer l'acces numerique. Interdire
-- ferait obstacle a un geste licite. On rend donc la situation OBSERVABLE, et
-- la decision reste humaine.
--
-- DOCTRINE DU CHAMP `ok` — reprise de fn_healthcheck_notifications :
--   `ok` ne compte QUE ce qui est casse ET que quelqu'un a l'intention de
--   reparer. Le reste est liste, motive, mais silencieux.
-- Sont donc BLOQUANTS les deux cas ou le systeme ne fait pas ce qu'il annonce :
-- une ressource restreinte que personne ne peut lire, et une ressource dont le
-- seau contredit la portee. Sont INFORMATIFS les manques editoriaux (statut de
-- droits absent, justification non ecrite) : ils relevent du catalogage, pas
-- d'une panne, et nul ne sait quand une bibliotheque les comblera.
--
-- LE CONTROLE DE SEAU SE LIT SUR storage.buckets.public, jamais sur le nom du
-- seau. Une portee restreinte servie depuis un seau public est une fuite : le
-- fichier est alors joignable par URL directe, sans signature ni verification
-- d'appartenance. Lire le drapeau plutot que la liste des noms fait tenir le
-- controle pour les seaux epub et media restreints, presents et a venir.
-- =============================================================================

begin;

create or replace function public.fn_healthcheck_digital_resources()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'storage', 'pg_temp'
as $fn$
declare
  v_sans_detenteur     jsonb := '[]'::jsonb;
  v_seau_incoherent    jsonb := '[]'::jsonb;
  v_sans_justification jsonb := '[]'::jsonb;
  v_sans_statut        jsonb := '[]'::jsonb;
begin
  -- ── 1. BLOQUANT : restreinte, active, mais plus aucun detenteur ───────────
  select coalesce(jsonb_agg(jsonb_build_object(
           'resource_id', r.id,
           'book_id',     b.id,
           'bib_ref',     b.bib_ref,
           'titulo',      b.titulo,
           'consequence', 'Illisible par tout le monde : plus aucune bibliotheque ne detient ce livre.')
         order by r.id), '[]'::jsonb)
    into v_sans_detenteur
  from public.book_digital_resources r
  join public.books b on b.id = r.book_id
  where r.access_scope is distinct from 'publico'
    and coalesce(r.is_active, false)
    and not exists (
      select 1 from public.book_holdings h where h.book_id = r.book_id);

  -- ── 2. BLOQUANT : la portee et le seau se contredisent ────────────────────
  select coalesce(jsonb_agg(jsonb_build_object(
           'resource_id',   r.id,
           'bib_ref',       b.bib_ref,
           'access_scope',  r.access_scope,
           'storage_bucket', r.storage_bucket,
           'seau_public',   sb.public,
           'consequence',
             case when coalesce(sb.public, false)
                  then 'FUITE : portee restreinte servie depuis un seau public, joignable par URL directe.'
                  else 'Ressource publique dans un seau prive : ne s''ouvrira pas sans signature.' end)
         order by r.id), '[]'::jsonb)
    into v_seau_incoherent
  from public.book_digital_resources r
  join public.books b on b.id = r.book_id
  left join storage.buckets sb on sb.id = r.storage_bucket
  where coalesce(r.is_active, false)
    and r.storage_bucket is not null
    and (
         (r.access_scope is distinct from 'publico' and coalesce(sb.public, false))
      or (r.access_scope = 'publico' and sb.public is distinct from true)
    );

  -- ── 3. INFORMATIF : sous droits, sans justification ecrite ────────────────
  -- « C'est la justification ecrite qui protege, pas le classement. »
  select coalesce(jsonb_agg(jsonb_build_object(
           'resource_id', r.id, 'bib_ref', b.bib_ref, 'titulo', b.titulo)
         order by r.id), '[]'::jsonb)
    into v_sans_justification
  from public.book_digital_resources r
  join public.books b on b.id = r.book_id
  where r.rights_status = 'sob_direitos'
    and coalesce(btrim(r.rights_justification), '') = '';

  -- ── 4. INFORMATIF : aucun statut de droits renseigne ───────────────────────
  select coalesce(jsonb_agg(jsonb_build_object(
           'resource_id', r.id, 'bib_ref', b.bib_ref, 'titulo', b.titulo,
           'access_scope', r.access_scope)
         order by r.id), '[]'::jsonb)
    into v_sans_statut
  from public.book_digital_resources r
  join public.books b on b.id = r.book_id
  where r.rights_status is null;

  return jsonb_build_object(
    'ok', (jsonb_array_length(v_sans_detenteur) = 0
           and jsonb_array_length(v_seau_incoherent) = 0),
    'genere_le', now(),
    'restreint_sans_detenteur',                 v_sans_detenteur,
    'seau_incoherent_avec_portee',              v_seau_incoherent,
    'sous_droits_sans_justification_informatif', v_sans_justification,
    'sans_statut_de_droits_informatif',          v_sans_statut
  );
end $fn$;

comment on function public.fn_healthcheck_digital_resources() is
  'Sonde de sante des ressources numeriques. Regle `ok` (identique a fn_healthcheck_notifications) : ne compte que ce qui est casse ET que quelqu''un compte reparer. BLOQUANT : ressource restreinte dont le livre n''a plus aucun detenteur (illisible par tous, silencieusement, depuis que la lecture restreinte suit book_holdings) ; portee et seau contradictoires (lu sur storage.buckets.public, pas sur le nom). INFORMATIF : statut de droits absent, justification non ecrite — editorial, non bloquant. Lecture seule.';

revoke all on function public.fn_healthcheck_digital_resources() from public, anon, authenticated;
grant execute on function public.fn_healthcheck_digital_resources() to service_role;

commit;
