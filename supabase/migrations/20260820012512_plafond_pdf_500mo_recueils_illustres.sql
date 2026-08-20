-- Plafond des buckets PDF porte de 300 a 500 Mo.
--
-- ⚠️ ORDRE DE REJEU. Ce fichier porte un numero a l'HEURE REELLE (01:25 UTC),
-- alors que 20260820230000_plafonds_buckets_numerisation porte un numero AVANCE
-- A LA MAIN. Au rejeu, l'autre s'execute donc APRES celui-ci et reposerait
-- 300 Mo. La valeur a ete corrigee la-bas aussi ; les deux fichiers posent
-- desormais 500 Mo, dans les deux ordres possibles.
--
-- POURQUOI (PLAN_DE_MARCHE §4.3). Le profil de numerisation chiffre une page
-- illustree a 200 ko - 1 Mo. Un volume de 300 pages entierement illustre —
-- recueil d'affiches, presse illustree, precisement ce qu'une bibliotheque
-- libertaire numerise en priorite — pese donc 60 a 300 Mo, et arrivait PILE au
-- plafond de 300 Mo pose le 20/08. Un versement parfaitement legitime pouvait
-- etre refuse, sans autre message qu'une erreur de taille.
--
-- Le plafond existe pour arreter un versement de 4 Go par megarde, pas pour
-- arbitrer un recueil de 350 Mo. On l'aligne donc sur celui deja retenu pour
-- les buckets media (500 Mo), qui encadre le meme genre d'objet lourd.
--
-- Les autres plafonds ne bougent pas : EPUB 50 Mo, couvertures et portraits
-- 10 Mo, carte 5 Mo, confidentialite 1 Mo. Les listes blanches de types MIME
-- posees le 20/08 sont inchangees.
--
-- MEME GARDE QUE 20260820230000, et pour les memes raisons : le schema
-- `storage` n'est pas cree par les migrations mais par le service Storage a son
-- initialisation. Depuis le 2026-08-20 le harnais sql-tests pose un stub
-- `storage` (tests/sql/_ci_setup_storage_stub.sql), donc la migration s'applique
-- VRAIMENT en CI ; la garde reste utile pour une pile reconstruite tant que le
-- conteneur storage n'a pas demarre.
--
-- COROLLAIRE : sur une pile reconstruite, cette migration passe SANS rien poser ;
-- c'est deploy/bootstrap.sh qui la rejoue apres le demarrage des services. Elle
-- est idempotente, le rejeu ne coute rien.
begin;

do $$
declare
  v_avant text;
  v_apres text;
begin
  if to_regclass('storage.buckets') is null then
    raise notice
      'storage.buckets absent : plafond PDF NON applique. Attendu sur une pile reconstruite avant le demarrage du service Storage. deploy/bootstrap.sh rejoue ce fichier au bon moment.';
    return;
  end if;

  select string_agg(id || '=' || round(file_size_limit/1048576.0) || ' Mo', ', ' order by id)
    into v_avant
  from storage.buckets
  where id in ('anarbib-pdf-public', 'pdf-restrito');

  update storage.buckets
     set file_size_limit = 524288000   -- 500 Mo
   where id in ('anarbib-pdf-public', 'pdf-restrito')
     and file_size_limit is distinct from 524288000;

  select string_agg(id || '=' || round(file_size_limit/1048576.0) || ' Mo', ', ' order by id)
    into v_apres
  from storage.buckets
  where id in ('anarbib-pdf-public', 'pdf-restrito');

  raise notice 'Plafond PDF : % -> %', coalesce(v_avant, '(aucun bucket PDF)'), coalesce(v_apres, '(aucun bucket PDF)');
end $$;

commit;
