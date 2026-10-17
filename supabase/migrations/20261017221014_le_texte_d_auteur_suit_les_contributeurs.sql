-- =====================================================================
-- Le texte d'auteur suit les contributeurs (18/10/2026, signalé par Xavier).
--
-- Xavier a remplacé les auteurs de « Casamento Indissolúvel… » (BTL-TL-000674)
-- par Wilhelm Reich ; la notice restait trouvée par le filtre « Auteur :
-- kropotkin » du catalogue. Cause, dans le formulaire du catalogage : à
-- l'enregistrement, le brouillon partait avec le texte d'auteur (`autor`)
-- d'AVANT, et le formulaire ne le recomposait depuis les contributeurs
-- qu'après l'envoi ; la publication recopiait ce texte périmé sur la notice.
-- Corrigé dans BookDraftForm.jsx (même commit). Ici, les données : les notices
-- dont les contributeurs ont été remplacés et dont le texte d'auteur n'en
-- cite plus aucun, relevées le 18/10 — trois cas sûrs.
--
--   636  Casamento Indissolúvel…    Godwin ; Bakunin ; Kropotkin ; Proudhon → Reich, Wilhelm
--   220  Errico Malatesta: a centocinquant'anni…  MALATESTA, Errico → Bonanno, Alfredo M. ; Autori vari
--   2738 L'insurrection qui vient     Hakim Bey… ; Tréguier… → Comité Invisible
--
-- Le texte est recomposé comme le fait l'écran (les contributeurs nommés,
-- dans l'ordre, séparés par « ; »), seulement si la notice porte encore le
-- texte périmé relevé : sans effet ailleurs. L'œuvre (une seule édition
-- chacune) suit : son auteur·rice principal·e devient le premier auteur de la
-- notice, ou personne quand il n'a pas d'autorité (Comité Invisible).
-- « Élisée Reclus: Geografia » (2563) n'est PAS touchée : ses contributeurs
-- n'ont plus d'auteur, seulement une coordination et une organisation ; le
-- texte « RECLUS, Élisée » est sans doute le bon, c'est le contributeur qui
-- manque — à décider au catalogage.
-- =====================================================================
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      (636::bigint,  'GODWIN, Willian ; BAKUNIN, Mikhail ; KROPOTKIN, Piotr ; PROUDHON, Pierre-Joseph'),
      (220::bigint,  'MALATESTA, Errico'),
      (2738::bigint, 'Hakim Bey 1945-2022 ; Tréguier Christine')
    ) AS v(id, perime)
  LOOP
    UPDATE public.books b
       SET autor = (SELECT string_agg(btrim(c.name), ' ; ' ORDER BY c.position)
                      FROM public.book_contributors c
                     WHERE c.book_id = b.id AND nullif(btrim(c.name), '') IS NOT NULL)
     WHERE b.id = r.id AND b.autor = r.perime
       AND EXISTS (SELECT 1 FROM public.book_contributors c
                    WHERE c.book_id = b.id AND nullif(btrim(c.name), '') IS NOT NULL);
    IF FOUND THEN
      UPDATE public.works w
         SET primary_author_id = (SELECT a.author_id FROM public.book_authors a
                                   WHERE a.book_id = r.id AND a.role = 'autor' ORDER BY a.ord LIMIT 1)
       WHERE w.id = (SELECT work_id FROM public.books WHERE id = r.id)
         AND (SELECT count(*) FROM public.books x WHERE x.work_id = w.id) = 1;
    END IF;
  END LOOP;
END $$;
