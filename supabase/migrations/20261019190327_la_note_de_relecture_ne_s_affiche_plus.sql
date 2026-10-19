-- =========================================================================
-- La note de relecture des autorités d'Anarchief ne s'affiche plus
-- =========================================================================
-- Date     : 2026-10-19
-- Chantier : sources partenaires — Anarchief.org (autorités)
-- Auteur   : Claude (assistant·e), pour la coordination
-- Session  : Anarchief — autorités et liens vers le wiki
-- Ref      : migration 20261019160041 (les 308 autorités créées) ; décision
--            de Xavier du 19/10/2026 (« efface la note de relecture, texte
--            exact seulement ; l'étiquette de source suffit »)
--
-- POURQUOI
--   La migration 20261019160041 a écrit dans authors.notes des 308 autorités
--   créées une note de travail (« Créée depuis les notices d'Anarchief.org
--   … À relire … D7 »). Or `notes` s'affiche sur la page publique d'une
--   autorité (« Biographie et notes ») : une consigne interne lue par tout le
--   monde. Les fiches restent repérables à relire par leur étiquette
--   (source_label = 'Anarchief.org · import 2026-10').
--
-- CE QUE FAIT LE PAQUET
--   Vide `notes` des seules autorités à cette étiquette dont la note est
--   EXACTEMENT ce texte. Une note retouchée depuis reste telle quelle. Rien
--   d'autre ne bouge. Au banc, aucune ligne ne répond : rien n'est écrit.
--   Garde : plus aucune autorité ne porte ce texte.
-- =========================================================================

DO $note_relecture$
DECLARE
  c_label constant text := 'Anarchief.org · import 2026-10';
  c_note  constant text := 'Créée depuis les notices d''Anarchief.org (liste fermée du 19/10/2026, décisions D1-D7). '
                           || 'À relire : ni dates, ni pays, ni identifiants externes (enrichissement prévu, D7).';
  v_n int;
BEGIN
  UPDATE public.authors SET notes = NULL
   WHERE source_label = c_label AND notes = c_note;
  GET DIAGNOSTICS v_n = ROW_COUNT;

  IF EXISTS (SELECT 1 FROM public.authors WHERE notes = c_note) THEN
    RAISE EXCEPTION 'Note de relecture : des autorités portent encore le texte';
  END IF;

  RAISE NOTICE 'Note de relecture effacée sur % autorité(s)', v_n;
END
$note_relecture$;
