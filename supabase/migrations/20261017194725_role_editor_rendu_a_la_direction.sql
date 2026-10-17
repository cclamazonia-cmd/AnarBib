-- =========================================================================
-- Rôle « editor » : les quatre lignes qui le portaient reçoivent leur vrai
-- rôle — la direction, ou rien (un éditeur commercial n'est pas une
-- responsabilité)
-- =========================================================================
-- Date     : 2026-10-17
-- Chantier : catalogage — panneau des responsabilités (refonte du 17/10/2026)
-- Auteur   : Claude (assistant·e), pour la coordination
-- Session  : Mode de sélection des autorités
-- Ref      : src/lib/catalogacao/bookDraft.js (ROLE_KEYS_TEXT sans « editor »,
--            inferContributorRole) ; supabase/functions/_shared/marc/
--            correspondance.ts (organizador ↔ edt / 340)
--
-- POURQUOI
--   « editor » doublait « organizador » : même code MARC21 (edt), et
--   « edited by » dit « sous la direction de ». Le libellé, lui, se lisait
--   « Éditeur·rice » en français, « Editor » en anglais (à côté
--   d'« Editor/compiler » pour organizador), « Redakteur*in » en allemand :
--   chaque langue y mettait un sens différent. Le rôle sort du menu ce
--   17/10/2026 ; « organizador » devient « Direction (dir.) ».
--   Relevé en production le 17/10/2026, quatre lignes le portaient, dans
--   les deux sens :
--     · « Barricada de Livros », sur « Viver a Utopia » (notice 2737,
--       brouillons 1118 et 1120) : c'est la maison d'édition — champ editora
--       et publisher_id 113 de la notice, editora des deux brouillons. Elle
--       n'a rien à faire parmi les responsabilités : la ligne est retirée ;
--     · « Woodcock, George », sur « Fields, factories, and workshops »
--       (brouillon 7598) : l'« edited by » de l'édition Black Rose — la
--       direction. Décision de Xavier le 17/10/2026.
--   La notice publiée de cette édition (2212) portait Woodcock en
--   « coordenador » : même direction, même correction, demandée par Xavier
--   le même jour.
--
-- CE QUE FAIT LE PAQUET
--   1. Retire les trois lignes « Barricada de Livros / editor », et
--      seulement si la notice ou le brouillon porte bien ce nom pour
--      éditeur.
--   2. Passe la ligne « Woodcock / editor » du brouillon 7598 en
--      « organizador ».
--   3. Passe la ligne « Woodcock / coordenador » de la notice 2212 en
--      « organizador ». Elle est liée à l'autorité 10112 : trg_sync_book_authors
--      ajoute le lien (2212, 10112, organizador, 2) mais ne retire l'ancien
--      que si l'autorité change, pas le rôle — le lien « coordenador » est
--      donc retiré ici, sans quoi Woodcock figurerait deux fois.
--      Conséquence voulue : « organizador » est un rôle affiché comme auteur
--      (AUTHOR_DISPLAY_ROLES, v_book_authors_canonical), « coordenador » ne
--      l'était pas.
--   Chaque geste ne touche que la ligne désignée ET dans l'état relevé : une
--   ligne modifiée depuis est laissée telle quelle (et dite en NOTICE) ;
--   rejouer le paquet ne fait rien.
--
-- EFFETS DE BORD (vérifiés le 17/10/2026)
--   · trg_sync_book_authors (book_contributors) : aucun pour Barricada de
--     Livros (pas d'author_id) ; pour la notice 2212, cf. le geste 3 ;
--   · trg_book_draft_contributors_touch_retake : aucun — les brouillons
--     1118, 1120 et 7598 sont publiés et déjà retake_untouched = false.
--
-- Aucun objet créé ni modifié : ni fonction, ni table, ni droit.
-- =========================================================================

BEGIN;

DO $editor$
DECLARE
  v_pub    int;
  v_drafts int;
  v_dir    int;
  v_pub_dir int;
  v_lien   int;
  v_reste  int;
BEGIN
  -- 1. L'éditeur commercial sort des responsabilités
  DELETE FROM public.book_contributors c
   USING public.books b
   WHERE c.id = 5504 AND c.book_id = 2737 AND b.id = c.book_id
     AND c.role = 'editor' AND c.author_id IS NULL
     AND c.name = 'Barricada de Livros' AND b.editora = 'Barricada de Livros';
  GET DIAGNOSTICS v_pub = ROW_COUNT;

  DELETE FROM public.book_draft_contributors c
   USING public.book_drafts d
   WHERE c.id IN (509, 512) AND d.id = c.draft_id AND c.draft_id IN (1118, 1120)
     AND c.role = 'editor' AND c.author_id IS NULL
     AND c.name = 'Barricada de Livros' AND d.editora = 'Barricada de Livros';
  GET DIAGNOSTICS v_drafts = ROW_COUNT;

  -- 2. La direction
  UPDATE public.book_draft_contributors
     SET role = 'organizador', role_code = NULL
   WHERE id = 4020 AND draft_id = 7598
     AND role = 'editor' AND name = 'Woodcock, George';
  GET DIAGNOSTICS v_dir = ROW_COUNT;

  -- 3. La direction, sur la notice publiée — et son lien d'autorité
  UPDATE public.book_contributors
     SET role = 'organizador', role_code = NULL
   WHERE id = 7134 AND book_id = 2212 AND position = 2
     AND role = 'coordenador' AND author_id = 10112 AND name = 'Woodcock, George';
  GET DIAGNOSTICS v_pub_dir = ROW_COUNT;

  v_lien := 0;
  IF v_pub_dir = 1 THEN
    DELETE FROM public.book_authors
     WHERE book_id = 2212 AND author_id = 10112 AND role = 'coordenador' AND ord = 2;
    GET DIAGNOSTICS v_lien = ROW_COUNT;
  END IF;

  SELECT (SELECT count(*) FROM public.book_contributors WHERE role = 'editor')
       + (SELECT count(*) FROM public.book_draft_contributors WHERE role = 'editor')
    INTO v_reste;

  RAISE NOTICE 'editor : % ligne(s) de notice et % de brouillon retirées (Barricada de Livros, attendu 1 et 2), % passée(s) en organizador (Woodcock, brouillon 7598, attendu 1) ; % ligne(s) encore en editor.',
    v_pub, v_drafts, v_dir, v_reste;
  RAISE NOTICE 'notice 2212 : % ligne passée de coordenador à organizador (attendu 1), % ancien lien book_authors retiré (attendu 1).',
    v_pub_dir, v_lien;
END
$editor$;

COMMIT;
