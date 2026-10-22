-- ============================================================================
-- C27 — les notices d'Anarchief.org reçoivent les sujets de leur propre wiki
-- (décision Xavier, 22/10/2026).
--
-- Proposition : docs/journal/audits/PROPOSITION_c27_sujets_anarchief_2026-10-22.md
--
-- La copie d'import de chaque notice garde le champ `sujets` du wiki
-- d'Anarchief (marc_json → ingest → raw_payload → sujets, formes séparées par
-- « | ») : 326 notices, 128 sujets distincts. Xavier a tranché le 22/10 :
--
--   1. les correspondances EXACTES avec le vocabulaire matière se posent :
--      168 notices, 183 affectations (THES-4 : jamais vers plus générique) ;
--   2. les correspondances PROCHES attendent sa relecture ligne à ligne —
--      rien ici ; la même fonction les posera ensuite ;
--   3. « Mundaneum » (60 notices) n'est pas un sujet mais la provenance :
--      une phrase s'ajoute à la note de provenance ;
--   4. les sujets sans terme chez nous entrent comme PROPOSITIONS (statut
--      `proposto`, invisibles du public) : la coordination du catalogage les
--      valide ou non dans la gouvernance des matières (THES-1, THES-6). Économie
--      et Anti/impérialisme ont déjà leur proposition (62, 64, lot Solidaires).
--
-- `private.fn_indexer_sujets_importes(préfixe, correspondances)` porte la
-- règle, pour pouvoir la rejouer sur les proches : elle n'affecte que des
-- matières ACTIVES, ne crée jamais de matière, garde les sujets déjà posés et
-- range les nouveaux après eux, dans l'ordre du wiki. Rejouée, ne fait rien.
--
-- Trace : les affectations posées ici se retrouvent par leur `created_at`
-- (l'instant de cette migration) et se re-dérivent de la copie d'import.
-- Hors production (aucune notice ANARCHIEF-), seule la fonction est créée.
-- Banc : tests/sql/c27_sujets_importes_tests.sql.
-- ============================================================================

CREATE OR REPLACE FUNCTION private.fn_indexer_sujets_importes(p_prefixe text, p_correspondances jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = ''
AS $fn$
DECLARE
  v_subjects_avant int := (SELECT count(*) FROM public.subjects);
  v_manquant text;
  v_notices int; v_aff int;
BEGIN
  IF coalesce(btrim(p_prefixe), '') = '' OR jsonb_typeof(p_correspondances) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'Indexation : un préfixe de référence et un objet de correspondances sont requis' USING ERRCODE = '22023';
  END IF;

  SELECT string_agg(DISTINCT c.value, ', ') INTO v_manquant
    FROM jsonb_each_text(p_correspondances) c
   WHERE NOT EXISTS (SELECT 1 FROM public.subjects s WHERE s.slug = c.value AND s.status = 'ativo');
  IF v_manquant IS NOT NULL THEN
    RAISE EXCEPTION 'Indexation : matière(s) absente(s) ou non active(s) : %', v_manquant USING ERRCODE = '22023';
  END IF;

  WITH brut AS (
    SELECT b.id AS book_id, btrim(x.sujet) AS sujet, x.n
      FROM public.books b,
           regexp_split_to_table(coalesce(b.marc_json -> 'ingest' -> 'raw_payload' ->> 'sujets', ''), '\s*\|\s*')
             WITH ORDINALITY AS x(sujet, n)
     WHERE b.bib_ref LIKE p_prefixe || '%'
  ), voulu AS (
    SELECT br.book_id, s.id AS subject_id, min(br.n) AS n
      FROM brut br
      JOIN jsonb_each_text(p_correspondances) c ON c.key = br.sujet
      JOIN public.subjects s ON s.slug = c.value AND s.status = 'ativo'
     GROUP BY br.book_id, s.id
  ), neuf AS (
    SELECT v.book_id, v.subject_id, v.n
      FROM voulu v
     WHERE NOT EXISTS (SELECT 1 FROM public.book_subjects bs WHERE bs.book_id = v.book_id AND bs.subject_id = v.subject_id)
  ), ins AS (
    INSERT INTO public.book_subjects (book_id, subject_id, ord)
    SELECT n.book_id, n.subject_id,
           coalesce((SELECT max(bs.ord) FROM public.book_subjects bs WHERE bs.book_id = n.book_id), 0)
             + row_number() OVER (PARTITION BY n.book_id ORDER BY n.n, n.subject_id)
      FROM neuf n
    ON CONFLICT DO NOTHING
    RETURNING book_id
  )
  SELECT count(DISTINCT book_id), count(*) INTO v_notices, v_aff FROM ins;

  IF (SELECT count(*) FROM public.subjects) <> v_subjects_avant THEN
    RAISE EXCEPTION 'Indexation : le nombre de matières a changé (THES-4)';
  END IF;
  RETURN jsonb_build_object('notices', v_notices, 'affectations', v_aff);
END;
$fn$;

REVOKE ALL ON FUNCTION private.fn_indexer_sujets_importes(text, jsonb) FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION private.fn_indexer_sujets_importes(text, jsonb) IS
  'C27 (22/10/2026) : pose les sujets d''une copie d''import (raw_payload.sujets) sur les notices d''un préfixe de référence, '
  'selon des correspondances forme → slug de matière ACTIVE ; ne crée jamais de matière (THES-4), garde l''existant, rejouable.';

DO $$
DECLARE
  v_res jsonb; v_n int; v_manque int;
  c_exactes constant jsonb := '{
    "Antimilitarisme": "antimilitarismo", "Anti/militarisme": "antimilitarismo",
    "Syndicalisme": "sindicalismo",
    "Anarchisme": "anarquismo",
    "Russische Revolutie": "revolucao-russa",
    "Spaanse Revolutie": "revolucao-espanhola", "Révolution Espagne": "revolucao-espanhola",
    "Spaanse revolutie 1936-1939": "revolucao-espanhola",
    "Anti/Fascisme": "antifascismo",
    "Feminisme": "feminismo",
    "Biographie": "biografia",
    "Organiseren": "organisation", "Organiser/en": "organisation",
    "Marxisme": "marxismo",
    "Repressie": "repressao",
    "Fascisme": "fascismo",
    "Socialisme": "socialismo",
    "Commune van Parijs": "comuna-de-paris", "Commune de Paris": "comuna-de-paris",
    "1 Mei": "primeiro-de-maio", "1 mei": "primeiro-de-maio",
    "Stakingen": "greve",
    "Ecologie": "ecologia",
    "Dictatuur": "ditadura",
    "Communisme": "comunismo",
    "Mutualisme": "mutualismo"
  }';
  c_mundaneum constant text := 'Fonds du Mundaneum (Mons), d''après le wiki d''Anarchief.org.';
  r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.books WHERE bib_ref LIKE 'ANARCHIEF-%') THEN
    RAISE NOTICE 'C27 : aucune notice d''Anarchief ici, rien à indexer';
    RETURN;
  END IF;

  -- 1. Correspondances exactes
  v_res := private.fn_indexer_sujets_importes('ANARCHIEF-', c_exactes);
  RAISE NOTICE 'C27 exactes : %', v_res;

  -- 2. Mundaneum : provenance, pas sujet
  UPDATE public.books b
     SET provenance_note = CASE WHEN coalesce(btrim(b.provenance_note), '') = '' THEN c_mundaneum
                                ELSE b.provenance_note || E'\n' || c_mundaneum END
   WHERE b.bib_ref LIKE 'ANARCHIEF-%'
     AND coalesce(b.provenance_note, '') NOT LIKE '%Mundaneum%'
     AND EXISTS (SELECT 1 FROM regexp_split_to_table(coalesce(b.marc_json -> 'ingest' -> 'raw_payload' ->> 'sujets', ''), '\s*\|\s*') x
                  WHERE btrim(x) = 'Mundaneum');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'C27 Mundaneum : % note(s) de provenance complétée(s)', v_n;

  -- 3. Propositions de termes (statut proposto : ni public, ni affectable)
  FOR r IN
    SELECT * FROM (VALUES
      ('anarchief-capitalisme', 'Kapitalisme', '{"fr":"Capitalisme","nl":"Kapitalisme","en":"Capitalism","es":"Capitalismo","pt-BR":"Capitalismo","it":"Capitalismo","ca":"Capitalisme","de":"Kapitalismus","el":"Καπιταλισμός","eo":"Kapitalismo","ro":"Capitalism"}'),
      ('anarchief-democratie', 'Democratie', '{"fr":"Démocratie","nl":"Democratie","en":"Democracy","es":"Democracia","pt-BR":"Democracia","it":"Democrazia","ca":"Democràcia","de":"Demokratie","el":"Δημοκρατία","eo":"Demokratio","ro":"Democrație"}'),
      ('anarchief-congres', 'Congres', '{"fr":"Congrès","nl":"Congressen","en":"Congresses","es":"Congresos","pt-BR":"Congressos","it":"Congressi","ca":"Congressos","de":"Kongresse","el":"Συνέδρια","eo":"Kongresoj","ro":"Congrese"}'),
      ('anarchief-revolution', 'Revolutie', '{"fr":"Révolution","nl":"Revolutie","en":"Revolution","es":"Revolución","pt-BR":"Revolução","it":"Rivoluzione","ca":"Revolució","de":"Revolution","el":"Επανάσταση","eo":"Revolucio","ro":"Revoluție"}'),
      ('anarchief-nationalisme', 'Nationalisme', '{"fr":"Nationalisme","nl":"Nationalisme","en":"Nationalism","es":"Nacionalismo","pt-BR":"Nacionalismo","it":"Nazionalismo","ca":"Nacionalisme","de":"Nationalismus","el":"Εθνικισμός","eo":"Naciismo","ro":"Naționalism"}'),
      ('anarchief-materialisme', 'Materialisme', '{"fr":"Matérialisme","nl":"Materialisme","en":"Materialism","es":"Materialismo","pt-BR":"Materialismo","it":"Materialismo","ca":"Materialisme","de":"Materialismus","el":"Υλισμός","eo":"Materiismo","ro":"Materialism"}'),
      ('anarchief-abstentionnisme', 'Stemmen', '{"fr":"Abstentionnisme","nl":"Niet-stemmen","en":"Electoral abstention","es":"Abstencionismo","pt-BR":"Abstencionismo","it":"Astensionismo","ca":"Abstencionisme","de":"Wahlenthaltung","el":"Αποχή από τις εκλογές","eo":"Voĉdona sindeteno","ro":"Abstenționism"}'),
      ('anarchief-classe-ouvriere', 'Arbeidersklasse', '{"fr":"Classe ouvrière","nl":"Arbeidersklasse","en":"Working class","es":"Clase obrera","pt-BR":"Classe operária","it":"Classe operaia","ca":"Classe obrera","de":"Arbeiterklasse","el":"Εργατική τάξη","eo":"Laborista klaso","ro":"Clasa muncitoare"}'),
      ('anarchief-violence-non-violence', 'Geweld/loosheid, Geweld', '{"fr":"Violence et non-violence","nl":"Geweld en geweldloosheid","en":"Violence and nonviolence","es":"Violencia y no violencia","pt-BR":"Violência e não violência","it":"Violenza e nonviolenza","ca":"Violència i no-violència","de":"Gewalt und Gewaltfreiheit","el":"Βία και μη βία","eo":"Perforto kaj neperforto","ro":"Violență și nonviolență"}'),
      ('anarchief-provo', 'Provo', '{"fr":"Provo (mouvement)","nl":"Provo","en":"Provo (movement)","es":"Provo (movimiento)","pt-BR":"Provo (movimento)","it":"Provo (movimento)","ca":"Provo (moviment)","de":"Provo (Bewegung)","el":"Provo (κίνημα)","eo":"Provo (movado)","ro":"Provo (mișcare)"}'),
      ('anarchief-liberation-animale', 'Dierenbevrijding', '{"fr":"Libération animale","nl":"Dierenbevrijding","en":"Animal liberation","es":"Liberación animal","pt-BR":"Libertação animal","it":"Liberazione animale","ca":"Alliberament animal","de":"Tierbefreiung","el":"Απελευθέρωση των ζώων","eo":"Bestoliberigo","ro":"Eliberarea animalelor"}'),
      ('anarchief-alternatives', 'Alternatieven', '{"fr":"Alternatives","nl":"Alternatieven","en":"Alternatives","es":"Alternativas","pt-BR":"Alternativas","it":"Alternative","ca":"Alternatives","de":"Alternativen","el":"Εναλλακτικές","eo":"Alternativoj","ro":"Alternative"}')
    ) v(slug, forme, libelles)
  LOOP
    INSERT INTO public.subjects (slug, label_i18n, status, scope_note)
    SELECT r.slug, r.libelles::jsonb, 'proposto',
           'Proposé le 22/10/2026 (backlog C27) depuis le sujet « ' || r.forme || ' » du wiki d''Anarchief.org. '
           || 'À valider par la coordination du catalogage (THES-1) ; une fois actif, il s''affecte aux notices qui le portent.'
     WHERE NOT EXISTS (SELECT 1 FROM public.subjects s WHERE s.slug = r.slug);
  END LOOP;

  -- Vérification : toute paire exacte voulue est posée ; les 12 propositions existent
  SELECT count(*) INTO v_manque
    FROM public.books b,
         regexp_split_to_table(coalesce(b.marc_json -> 'ingest' -> 'raw_payload' ->> 'sujets', ''), '\s*\|\s*') x
    JOIN jsonb_each_text(c_exactes) c ON c.key = btrim(x)
    JOIN public.subjects s ON s.slug = c.value
   WHERE b.bib_ref LIKE 'ANARCHIEF-%'
     AND NOT EXISTS (SELECT 1 FROM public.book_subjects bs WHERE bs.book_id = b.id AND bs.subject_id = s.id);
  IF v_manque > 0 THEN
    RAISE EXCEPTION 'C27 : % correspondance(s) exacte(s) non posée(s)', v_manque;
  END IF;
  IF (SELECT count(*) FROM public.subjects WHERE slug LIKE 'anarchief-%' AND status = 'proposto') < 12 THEN
    RAISE EXCEPTION 'C27 : les douze propositions de termes ne sont pas toutes là';
  END IF;
END $$;
