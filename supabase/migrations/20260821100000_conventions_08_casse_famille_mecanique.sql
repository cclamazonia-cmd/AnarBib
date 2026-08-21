-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 08 · Casse naturelle, famille mecanique
-- Foyer : REGISTRE §37 `CONV` · CONV-1 (point d'acces en casse naturelle)
--         + CONV-2 (preferred_name derive de sort_name)
--
-- ---------------------------------------------------------------------
-- CE QUE CETTE MIGRATION APPLIQUE, ET SUR QUELLE AUTORITE
--
-- La table de revue compte 1 274 propositions. Le tri par famille montre
-- qu'elles ne demandent pas le meme travail :
--
--   1 213  patronyme d'UN SEUL MOT, tout en capitales   -> mecanique
--      31  particule ou prefixe (Van, De, Di, Y, Von…)  -> a lire
--       3  apostrophe (O', Dell', Sant'…)               -> a lire
--      27  patronyme en plusieurs mots                  -> a lire
--
-- Seule la premiere famille est traitee ici. Elle l'est par PREDICAT
-- EXPLICITE — pas par un script qui aurait pose `valide = true` sur
-- 1 213 lignes, ce que le REGISTRE §37 interdit. La decision humaine
-- porte sur la FAMILLE, prise apres relecture d'un echantillon de 24
-- propositions tirees au hasard (21/08, Xavier) : 24/24 correctes, y
-- compris les pieges — ROSEN-CROS -> Rosen-Cros (trait d'union),
-- MENDONCA -> Mendonça (diacritiques), « FREITAS, Allan de » (la
-- particule du prenom reste minuscule), « CUTLER, Robert M. » (initiales).
--
-- Les 61 autres restent en table, verdict par verdict. initcap() s'y
-- trompe, et on sait deja comment : O'BRIEN -> « O'brien », DELL'UMBRIA
-- -> « Dell'umbria », FERRER Y GUARDIA -> « Ferrer Y Guardia ». Deux
-- lignes n'y sont d'ailleurs pas des problemes de casse du tout — une
-- collectivite cataloguee comme personne, et deux personnes dans une
-- seule autorite.
-- =====================================================================

begin;

-- Trace de l'application : `valide` reste reserve au verdict HUMAIN
-- ligne a ligne. Une colonne distincte dit ce qui a ete applique par
-- famille, et quand — les deux ne se confondent pas.
alter table conv_backup.autorites_casse_a_revoir_20260820
  add column if not exists applique_le timestamptz;

-- ---------------------------------------------------------------------
-- 1. Point d'acces (CONV-1)
--
--    Predicat identique, mot pour mot, a celui de l'echantillon relu.
--    Garde `a.sort_name = r.avant` : une fiche editee entre la
--    generation de la table et cette migration n'est PAS ecrasee.
-- ---------------------------------------------------------------------
with cible as (
  select r.id, r.avant, r.apres_propose
    from conv_backup.autorites_casse_a_revoir_20260820 r
   where r.applique_le is null
     and r.avant !~ '\y(Mc|Mac|O''|D''|L''|Van|Von|De|Della|Di|Du|Des|Le|La|Y|E|Ben|Al|Saint)\y'
     and r.avant !~ ''''
     and (length(split_part(r.avant, ', ', 1)) - length(replace(split_part(r.avant, ', ', 1), ' ', ''))) = 0
),
maj as (
  update public.authors a
     set sort_name = c.apres_propose
    from cible c
   where a.id = c.id
     and a.sort_name = c.avant
  returning a.id
)
update conv_backup.autorites_casse_a_revoir_20260820 r
   set applique_le = now()
  from maj
 where r.id = maj.id;

-- ---------------------------------------------------------------------
-- 2. Forme d'affichage (CONV-2) — elle DERIVE, elle ne vit pas sa vie.
--
--    La migration 04 avait reconstruit preferred_name en ordre direct
--    depuis l'ancien sort_name : « SILVEIRA, Ênio » avait donne
--    « Ênio SILVEIRA ». Le patronyme y est donc reste en capitales. On
--    re-derive ici depuis le sort_name CORRIGE — mais uniquement la ou
--    preferred_name est encore exactement la forme mecaniquement derivee
--    de l'ancien point d'acces. Une fiche retouchee a la main garde sa
--    forme : on ne recouvre jamais un geste humain.
-- ---------------------------------------------------------------------
update public.authors a
   set preferred_name = btrim(split_part(a.sort_name, ', ', 2) || ' ' || split_part(a.sort_name, ', ', 1))
  from conv_backup.autorites_casse_a_revoir_20260820 r
 where r.id = a.id
   and r.applique_le is not null
   and a.sort_name = r.apres_propose
   and (length(a.sort_name) - length(replace(a.sort_name, ',', ''))) = 1
   and split_part(a.sort_name, ', ', 2) <> ''
   and a.preferred_name = btrim(split_part(r.avant, ', ', 2) || ' ' || split_part(r.avant, ', ', 1));

-- ---------------------------------------------------------------------
-- 3. Verification — SIGNALE, ne bloque pas
-- ---------------------------------------------------------------------
do $$
declare
  n_applique bigint;
  n_reste    bigint;
  n_ecart    bigint;
  n_shouty   bigint;
begin
  select count(*) into n_applique from conv_backup.autorites_casse_a_revoir_20260820
   where applique_le is not null;
  select count(*) into n_reste from conv_backup.autorites_casse_a_revoir_20260820
   where applique_le is null;

  -- Fiches de la famille mecanique que la garde anti-ecrasement a ecartees
  -- (le point d'acces avait bouge depuis la generation de la table).
  select count(*) into n_ecart from conv_backup.autorites_casse_a_revoir_20260820 r
    join public.authors a on a.id = r.id
   where r.applique_le is null
     and r.avant !~ '\y(Mc|Mac|O''|D''|L''|Van|Von|De|Della|Di|Du|Des|Le|La|Y|E|Ben|Al|Saint)\y'
     and r.avant !~ ''''
     and (length(split_part(r.avant, ', ', 1)) - length(replace(split_part(r.avant, ', ', 1), ' ', ''))) = 0
     and a.sort_name <> r.avant;

  -- Etat CONV-1 global : points d'acces portant encore un mot tout en capitales.
  select count(*) into n_shouty from public.authors
   where sort_name ~ '\m[A-ZÀ-Þ]{2,}\M' and sort_name !~ '[A-ZÀ-Þ]\.';

  if n_ecart > 0 then
    raise warning 'CONV/08 — % fiche(s) de la famille mecanique ecartees par la garde '
                  'anti-ecrasement (point d''acces modifie depuis le 20/08). Elles restent '
                  'en table, a relire.', n_ecart;
  end if;

  raise notice 'CONV/08 — % point(s) d''acces passes en casse naturelle · % ligne(s) '
               'restent a la revue humaine · % autorite(s) portent encore des capitales '
               '(CONV-1 non solde).', n_applique, n_reste, n_shouty;
end $$;

commit;
