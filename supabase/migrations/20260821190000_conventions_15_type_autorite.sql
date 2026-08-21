-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 15 · Le type d'autorité devient lisible
-- Foyer : REGISTRE §37 `CONV` · CONV-O7, prérequis de CONV-O2 et CONV-O8
--
-- ---------------------------------------------------------------------
-- LE DIAGNOSTIC, CORRIGÉ AVANT D'ÊTRE CONSTRUIT.
--
-- Première hypothèse : « `authors` n'a pas de type, la distinction se perd
-- à la publication ». **Faux**, vérifié en base avant d'écrire une ligne.
-- Le formulaire collecte `authorityType` (`person` / `collective`), le
-- range dans `authors.structured_meta`, et `buildSortName` applique déjà
-- la règle — il n'inverse pas un nom de collectivité.
-- `Centro de Cultura Libertária da Amazônia` (11322) le prouve : typée,
-- non inversée.
--
-- LE VRAI DÉFAUT est en trois couches :
--
--   1. 1 255 fiches sur 1 300 n'ont AUCUN type — l'attribut est arrivé
--      après l'import ;
--   2. parmi elles, 16 collectivités INVERSÉES à tort par l'import
--      (« Krisis, Grupo » pour « Grupo Krisis »). Le chiffre annoncé au
--      départ était 8 : le premier jeu de mots-clés en manquait la moitié,
--      dont `CIRA Marseille` — une bibliothèque du réseau lui-même ;
--   3. et surtout : un `jsonb` non contraint qu'AUCUN traitement SQL ne
--      consulte. Les migrations 04, 08, 11, 12 et la file de vérification
--      ont toutes appliqué la règle d'inversion sans jamais demander à
--      quoi elles avaient affaire. Une collectivité correctement typée
--      aurait reçu la même proposition d'inversion qu'une personne.
--
-- Le chantier n'est donc pas « créer un type » : c'est le rendre LISIBLE
-- PAR LE SQL et le faire RESPECTER par l'outillage.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. La colonne. `text` + CHECK plutôt qu'enum PG (CAT-B1).
--
--    NULL est un état plein de sens ici : « personne ne s'est prononcé ».
--    Le distinguer de `person` est indispensable — remplir 1 255 fiches
--    avec « personne » par défaut affirmerait quelque chose de faux sur
--    les huit collectivités, et rendrait le travail de qualification
--    invisible en le déclarant fait.
-- ---------------------------------------------------------------------
alter table public.authors add column if not exists authority_type text;

alter table public.authors drop constraint if exists authors_authority_type_chk;
alter table public.authors add constraint authors_authority_type_chk
  check (authority_type is null or authority_type in ('person', 'collective', 'congress'));

comment on column public.authors.authority_type is
  'person | collective | congress. NULL = non qualifiée, et ce n''est pas un '
  'défaut : c''est le travail qui reste. Pilote la règle d''élément d''entrée — '
  'une collectivité ne s''inverse pas (« Grupo Krisis », jamais « Krisis, Grupo »). '
  'Rétro-remplie depuis structured_meta->>''authorityType'' le 21/08 ; '
  'le formulaire continue d''écrire dans le jsonb, la colonne en est le miroir '
  'lisible par le SQL (CONV-O7).';

create index if not exists authors_authority_type_idx
  on public.authors (authority_type) where authority_type is not null;

-- ---------------------------------------------------------------------
-- 2. Rétro-remplissage depuis le jsonb — la seule source qui existe.
-- ---------------------------------------------------------------------
update public.authors a
   set authority_type = a.structured_meta->>'authorityType'
 where a.authority_type is null
   and a.structured_meta->>'authorityType' in ('person', 'collective', 'congress');

-- ---------------------------------------------------------------------
-- 3. Le miroir doit rester vrai. Sans ce trigger, le formulaire écrirait
--    dans le jsonb et la colonne divergerait en silence — exactement le
--    genre d'écart qui se découvre trois mois plus tard sur des données.
-- ---------------------------------------------------------------------
create or replace function public.fn_sync_authority_type()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $function$
begin
  -- Le jsonb reste la source d'écriture (c'est ce que le formulaire connaît) ;
  -- la colonne en est le reflet. Si quelqu'un écrit directement la colonne,
  -- on ne l'écrase pas : on ne devine pas laquelle des deux fait foi.
  if NEW.structured_meta->>'authorityType' in ('person', 'collective', 'congress')
     and NEW.authority_type is distinct from NEW.structured_meta->>'authorityType'
     and NEW.authority_type is not distinct from coalesce(OLD.authority_type, NEW.authority_type)
  then
    NEW.authority_type := NEW.structured_meta->>'authorityType';
  end if;
  return NEW;
end;
$function$;

comment on function public.fn_sync_authority_type() is
  'CONV-O7 · maintient authors.authority_type en miroir de '
  'structured_meta->>authorityType, que le formulaire de catalogage écrit. '
  'N''écrase pas une valeur posée directement sur la colonne.';

revoke all on function public.fn_sync_authority_type() from public, anon, authenticated;

drop trigger if exists trg_sync_authority_type on public.authors;
create trigger trg_sync_authority_type
  before insert or update of structured_meta on public.authors
  for each row execute function public.fn_sync_authority_type();

-- ---------------------------------------------------------------------
-- 4. L'outillage des conventions CONSULTE enfin le type.
--
--    La règle A1 (« forme inversée en preferred_name ») et la règle CONV-1
--    n'ont aucun sens pour une collectivité : « Grupo Krisis » n'a pas de
--    forme inversée, et ses capitales sont son orthographe. On les écarte,
--    et on ajoute la règle qui manquait — la seule qui concerne vraiment
--    les collectivités.
-- ---------------------------------------------------------------------
create or replace function private.conv_motifs_collectivite()
returns text
language sql
immutable
as $function$
  -- Repérage par mots-clés, pour les fiches que personne n'a qualifiées.
  -- Liste ÉLARGIE le 21/08 après épreuve sur les données : la première
  -- version ne trouvait que 8 fiches sur 16. Elle manquait `escuela`,
  -- `núcleo`, `união`, `equipo`, `departamento`, et surtout les SIGLES,
  -- qui sont la forme la plus courante des collectivités du corpus
  -- (`CIRA Marseille`, `CNT-AIT Sevilha`, `UFPA`, `DIEESE`).
  --
  -- CE QUI A ÉTÉ ESSAYÉ PUIS RETIRÉ : repérer les sigles génériquement par
  -- `[A-Z]{3,}`. Séduisant, et faux — il remonte `DOCTOROW, E. L.` et
  -- `F. FLECK, Richard`, qui sont des PERSONNES dont la casse n'est pas
  -- encore normalisée. Le motif attrapait un défaut d'un AUTRE lot et
  -- l'aurait fait passer pour un défaut de type. Sigles nommés un par un.
  select '\y(universidade|universidad|faculdade|facultad|instituto|editora'
      || '|edi[çc][õo]es|ediciones|coletivo|colectivo|grupo|federa|sindicat'
      || '|intersindical|associa|asocia|centro|biblioteca|ateneu|ateneo|comit'
      || '|conselho|consejo|comiss[aã]o|comisi[oó]n|confedera|cooperativa'
      || '|n[uú]cleo|c[ií]rculo|movimento|movimiento|uni[aã]o|uni[oó]n|liga'
      || '|escola|escuela|sociedade|sociedad|equipo|equipe|organiza'
      || '|departamento|funda[çc]|arquivo|museu|museo'
      || '|cnt|cgt|fai|ait|cira|ufpa|cesit|dieese|iww)\y'
$function$;

comment on function private.conv_motifs_collectivite() is
  'CONV-O7 · motifs de repérage des collectivités non qualifiées. '
  'Éprouvé sur les 1 300 autorités : 16 trouvées, 0 faux positif. '
  'Ne PAS y remettre un motif générique de sigles majuscules — testé, '
  'il remonte des personnes à la casse non normalisée.';

revoke all on function private.conv_motifs_collectivite() from public, anon, authenticated;

create or replace view private.v_conv_collectivites_inversees
with (security_invoker = true) as
  select a.id,
         a.sort_name  as avant,
         -- Dé-inversion mécanique : ce qui suit la virgule, puis ce qui précède.
         btrim(split_part(a.sort_name, ', ', 2) || ' ' || split_part(a.sort_name, ', ', 1)) as apres_propose
    from public.authors a
   where a.sort_name ~ ', '
     and (length(a.sort_name) - length(replace(a.sort_name, ',', ''))) = 1
     and split_part(a.sort_name, ', ', 2) <> ''
     and (
          a.authority_type in ('collective', 'congress')
       or (a.authority_type is null
           and a.sort_name ~* private.conv_motifs_collectivite())
         );

comment on view private.v_conv_collectivites_inversees is
  'CONV-O7 · collectivités dont le point d''accès a été inversé comme s''il '
  's''agissait d''une personne. Deux sources : le type déclaré, et — pour les '
  'fiches non qualifiées — un repérage par mots-clés, qui PROPOSE et ne '
  'décide pas. Dans `private`, sans grant : lecture par RPC staff.';

revoke all on private.v_conv_collectivites_inversees from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 5. Vérification
-- ---------------------------------------------------------------------
do $$
declare
  n_type   bigint;
  n_coll   bigint;
  n_inv    bigint;
  n_total  bigint;
begin
  select count(*) into n_total from public.authors;
  if n_total = 0 then
    raise notice 'CONV/15 — base sans autorités (reconstruction CI).';
    return;
  end if;

  select count(*) into n_type from public.authors where authority_type is not null;
  select count(*) into n_coll from public.authors where authority_type = 'collective';
  select count(*) into n_inv  from private.v_conv_collectivites_inversees;

  raise notice 'CONV/15 — % autorité(s) typée(s) sur % (dont % collectivités) · '
               '% point(s) d''accès de collectivité inversés, à relire.',
               n_type, n_total, n_coll, n_inv;
end $$;

commit;
