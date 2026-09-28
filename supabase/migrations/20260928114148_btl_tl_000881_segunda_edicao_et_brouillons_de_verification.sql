-- ============================================================================
-- BTL-TL-000881 : l'exemplaire de 2011 est la 2ª edição, pas un tirage — et la
-- note se lit en portugais, la langue de la BTL. Deux brouillons de reprise
-- ouverts par la vérification à l'écran du 28/09 sont écartés.
--
-- Xavier, 28/09/2026 : « l'un des deux exemplaires est de 2010 et l'autre est
-- de 2011 (2. ed.) ». La migration 20260928111729 avait noté « Tirage de 2010 »
-- / « Tirage de 2011 » en français : deux éditions successives du même éditeur,
-- réunies sous une notice par décision de la coordination (la notice garde la
-- première, 2010), l'édition notée sur chaque exemplaire.
--
-- Les brouillons 6276 (BTL-TL-000181) et 6277 (BTL-TL-000881) ont été créés à
-- 11:37 et 11:40 UTC par le bouton « Éditer » pendant la vérification de
-- l'action « Même édition » ; sans aucune modification, ils vont à la corbeille
-- (status cancelled, réversible).
--
-- Rejouée sur une base sans ces données (banc, CI), la migration ne fait rien.
-- ============================================================================
begin;

do $$
begin
  update public.exemplares e
     set notes = replace(e.notes, ' — Tirage de 2010.', ' — 1ª edição, 2010.'),
         updated_at = now()
   where e.tombo = 'BTL-TL-EX-000881' and e.notes like '%Tirage de 2010.%';

  update public.exemplares e
     set notes = regexp_replace(e.notes,
                   ' — Tirage de 2011 \(ex-notice BTL-TL-000880, fusionnée dans BTL-TL-000881 le 28/09/2026 ; la notice garde 2010, la première édition\)\.',
                   ' — 2ª edição, 2011 (ficha BTL-TL-000880, reunida em BTL-TL-000881 em 28/09/2026 por decisão da coordenação; a ficha mantém a 1ª edição, 2010).'),
         updated_at = now()
   where e.tombo = 'BTL-TL-EX-000880' and e.notes like '%Tirage de 2011%';

  if exists (select 1 from public.exemplares
              where tombo in ('BTL-TL-EX-000880', 'BTL-TL-EX-000881') and notes like '%Tirage de%') then
    raise exception 'BTL-TL-000881 : une note « Tirage de … » n''a pas été remplacée';
  end if;

  update public.book_drafts d
     set status = 'cancelled', updated_at = now()
   where d.id in (6276, 6277)
     and d.status = 'draft' and d.action = 'update'
     and d.bib_ref in ('BTL-TL-000181', 'BTL-TL-000881')
     and d.updated_at < d.created_at + interval '5 minutes';   -- jamais touchés depuis leur création
end $$;

commit;
