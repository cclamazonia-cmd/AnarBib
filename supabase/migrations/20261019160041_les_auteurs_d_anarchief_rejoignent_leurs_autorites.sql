-- =========================================================================
-- Les noms d'auteur·rice des notices d'Anarchief.org rejoignent leurs
-- autorités (liste fermée, décisions D1-D7 du 19/10/2026)
-- =========================================================================
-- Date     : 2026-10-19
-- Chantier : sources partenaires — Anarchief.org (bibliothèque source)
-- Auteur   : Claude (assistant·e), pour la coordination
-- Session  : Anarchief — autorités et liens vers le wiki
-- Ref      : PROPOSITION_autorites_anarchief_2026-10-19.md (hors dépôt,
--            dossier de la coordination) ; décision de Xavier du 19/10/2026
--            (« D1 à D7 comme proposé ») ; tests/sql/autorites_par_liste_tests.sql
--
-- POURQUOI
--   Les 1 002 notices d'Anarchief.Org sont au catalogue public depuis le
--   19/10. 898 portent un nom d'auteur·rice ; 2 seulement étaient liées à une
--   autorité : pas de page d'auteur·rice, pas de filtre par autorité, pas de
--   rapprochement avec les autres bibliothèques du réseau. 443 graphies
--   distinctes sans autorité (relevé du 19/10, lecture seule).
--
-- CE QUE FAIT LE PAQUET
--   1. private.fn_autorites_par_liste(bibliothèque, liste, étiquette, note) :
--      applique une LISTE FERMÉE aux contributeurs non liés des notices tenues
--      par la bibliothèque, dans cet ordre :
--        a. renommages  — un débris de conversion retrouve sa forme
--                         (« Eigen Hulp (Koor » → « Eigen Hulp (Koor, Orkest) ») ;
--        b. suppressions — la ligne-débris dont le texte est rentré dans la
--                         précédente (« Orkest) »), seulement si la notice garde
--                         une autre ligne ;
--        c. éclatements — une ligne qui porte plusieurs noms (la virgule devenue
--                         double espace) devient une ligne par nom, aux positions
--                         suivantes, non principales ;
--        d. autorités   — création des autorités neuves (forme retenue, forme de
--                         tri, type, étiquette de source, note de relecture,
--                         formes variantes en author_name_aliases) ; une autorité
--                         déjà créée par un passage précédent (même forme
--                         retenue, même étiquette) est reprise, pas doublée ;
--        e. liens       — book_contributors.author_id (et nature) pour chaque
--                         graphie de la liste ; book_authors suit par son
--                         déclencheur, jamais écrit ici.
--      Jamais : modifier une autorité existante (ni nom, ni alias), toucher une
--      ligne déjà liée, toucher une notice d'une autre bibliothèque, toucher
--      books.autor (la transcription). Rejouable. SECURITY INVOKER, sans
--      appelant API (EXECUTE retiré à PUBLIC, anon, authenticated).
--   2. L'appel pour Anarchief.Org, s'il existe (production seulement ; au
--      banc la bibliothèque n'existe pas et rien n'est écrit), avec la liste
--      fermée ci-dessous : 85 graphies vers des autorités existantes, 308
--      autorités neuves (197 personnes, 111 collectifs) pour 339 graphies,
--      20 éclatements, 5 renommages, 3 suppressions, 50 graphies laissées en
--      texte (Anoniem, titres de périodiques, J/M, mononymes de personnes,
--      noms de famille seuls issus des éclatements).
--
-- DÉCISIONS (Xavier, 19/10/2026)
--   D1 lier les graphies connues ; D2 créer toutes les autorités neuves,
--   marquées pour relecture (source_label « Anarchief.org · import 2026-10 ») ;
--   D3 réparer, éclater, nettoyer ; D4 tri néerlandais pour les Néerlandais
--   (« Ligt, Bart de »), belge pour les Belges (« De Paepe, César ») ; D5 pas
--   d'autorité pour J/M ; D6 mononymes de personnes et « PP » en texte ;
--   D7 enrichissement (Wikidata, IdRef) plus tard.
--
-- CHECKLIST DOCTRINE
--   - Une fonction INVOKER dans `private`, EXECUTE retiré (grants_herites T12).
--   - Aucune table, aucun index, aucune policy neuve ; écritures de lignes.
--   - Gardes finales : toute graphie d'Anarchief encore non liée est dans la
--     liste « texte » ; le nombre d'autorités à l'étiquette = la liste.
-- =========================================================================

CREATE OR REPLACE FUNCTION private.fn_autorites_par_liste(
  p_library_id   uuid,
  p_liste        jsonb,
  p_source_label text,
  p_note         text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $fn$
DECLARE
  v_e jsonb; v_a jsonb; v_l jsonb; v_part text;
  v_c record;
  v_i int; v_pos int;
  v_id bigint;
  v_cles jsonb := '{}'::jsonb;
  v_ren int := 0; v_sup int := 0; v_ecl int := 0; v_crees int := 0; v_alias int := 0; v_liens int := 0; v_n int;
BEGIN
  IF p_library_id IS NULL OR jsonb_typeof(p_liste) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'fn_autorites_par_liste : bibliothèque et liste (objet) requises';
  END IF;
  IF coalesce(btrim(p_source_label), '') = '' THEN
    RAISE EXCEPTION 'fn_autorites_par_liste : étiquette de source requise';
  END IF;

  -- a. renommages
  FOR v_e IN SELECT * FROM jsonb_array_elements(coalesce(p_liste->'renommages', '[]')) LOOP
    UPDATE public.book_contributors c SET name = v_e->>'en'
     WHERE c.name = v_e->>'nom' AND c.author_id IS NULL
       AND EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = c.book_id AND h.library_id = p_library_id);
    GET DIAGNOSTICS v_n = ROW_COUNT; v_ren := v_ren + v_n;
  END LOOP;

  -- b. suppressions (débris rentré dans une autre ligne de la même notice)
  DELETE FROM public.book_contributors c
   WHERE c.name IN (SELECT jsonb_array_elements_text(coalesce(p_liste->'suppressions', '[]')))
     AND c.author_id IS NULL
     AND EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = c.book_id AND h.library_id = p_library_id)
     AND EXISTS (SELECT 1 FROM public.book_contributors o WHERE o.book_id = c.book_id AND o.id <> c.id);
  GET DIAGNOSTICS v_sup = ROW_COUNT;

  -- c. éclatements
  FOR v_e IN SELECT * FROM jsonb_array_elements(coalesce(p_liste->'eclatements', '[]')) LOOP
    IF jsonb_array_length(coalesce(v_e->'parts', '[]')) < 2 THEN
      RAISE EXCEPTION 'fn_autorites_par_liste : éclatement sans parties : %', v_e->>'nom';
    END IF;
    FOR v_c IN
      SELECT c.* FROM public.book_contributors c
       WHERE c.name = v_e->>'nom' AND c.author_id IS NULL
         AND EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = c.book_id AND h.library_id = p_library_id)
       ORDER BY c.book_id, c.position
    LOOP
      UPDATE public.book_contributors SET name = v_e->'parts'->>0 WHERE id = v_c.id;
      FOR v_i IN 1 .. jsonb_array_length(v_e->'parts') - 1 LOOP
        SELECT max(position) + 1 INTO v_pos FROM public.book_contributors WHERE book_id = v_c.book_id;
        INSERT INTO public.book_contributors (book_id, position, name, role, role_code, is_primary)
        VALUES (v_c.book_id, v_pos, v_e->'parts'->>v_i, v_c.role, v_c.role_code, false);
      END LOOP;
      v_ecl := v_ecl + 1;
    END LOOP;
  END LOOP;

  -- d. autorités neuves (reprises si un passage précédent les a créées)
  FOR v_a IN SELECT * FROM jsonb_array_elements(coalesce(p_liste->'autorites', '[]')) LOOP
    IF coalesce(v_a->>'type', '') NOT IN ('person', 'collective') OR coalesce(btrim(v_a->>'preferred'), '') = '' THEN
      RAISE EXCEPTION 'fn_autorites_par_liste : autorité mal formée : %', v_a;
    END IF;
    SELECT a.id INTO v_id FROM public.authors a
     WHERE a.preferred_name = v_a->>'preferred' AND a.source_label = p_source_label
     ORDER BY a.id LIMIT 1;
    IF v_id IS NULL THEN
      INSERT INTO public.authors (preferred_name, sort_name, authority_type, source_label, notes, structured_meta)
      VALUES (v_a->>'preferred', coalesce(v_a->>'sort', v_a->>'preferred'), v_a->>'type', p_source_label, p_note,
              jsonb_build_object('authorityType', v_a->>'type'))
      RETURNING id INTO v_id;
      v_crees := v_crees + 1;
    END IF;
    FOR v_part IN SELECT jsonb_array_elements_text(coalesce(v_a->'alias', '[]')) LOOP
      INSERT INTO public.author_name_aliases (alias_text, alias_norm, author_id, match_kind, note)
      SELECT v_part, public.f_normalize_search(v_part), v_id, 'variant', 'Graphie des notices — ' || p_source_label
       WHERE NOT EXISTS (SELECT 1 FROM public.author_name_aliases x
                          WHERE x.author_id = v_id AND x.is_active AND x.alias_norm = public.f_normalize_search(v_part));
      GET DIAGNOSTICS v_n = ROW_COUNT; v_alias := v_alias + v_n;
    END LOOP;
    v_cles := v_cles || jsonb_build_object(v_a->>'cle', v_id);
  END LOOP;

  -- e. liens
  FOR v_l IN SELECT * FROM jsonb_array_elements(coalesce(p_liste->'liens', '[]')) LOOP
    IF v_l ? 'autorite' THEN
      v_id := (v_l->>'autorite')::bigint;
      IF NOT EXISTS (SELECT 1 FROM public.authors WHERE id = v_id) THEN
        RAISE EXCEPTION 'fn_autorites_par_liste : autorité % absente (graphie « % »)', v_id, v_l->>'nom';
      END IF;
    ELSE
      v_id := (v_cles->>(v_l->>'cle'))::bigint;
      IF v_id IS NULL THEN
        RAISE EXCEPTION 'fn_autorites_par_liste : clé « % » sans autorité (graphie « % »)', v_l->>'cle', v_l->>'nom';
      END IF;
    END IF;
    UPDATE public.book_contributors c
       SET author_id = v_id,
           nature = coalesce((SELECT a.authority_type FROM public.authors a WHERE a.id = v_id), c.nature)
     WHERE c.name = v_l->>'nom' AND c.author_id IS NULL
       AND EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = c.book_id AND h.library_id = p_library_id);
    GET DIAGNOSTICS v_n = ROW_COUNT; v_liens := v_liens + v_n;
  END LOOP;

  RETURN jsonb_build_object('renommages', v_ren, 'suppressions', v_sup, 'eclatements', v_ecl,
                            'autorites_creees', v_crees, 'alias', v_alias, 'liens', v_liens);
END
$fn$;

REVOKE ALL ON FUNCTION private.fn_autorites_par_liste(uuid, jsonb, text, text) FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION private.fn_autorites_par_liste(uuid, jsonb, text, text) IS
  'Applique une liste fermée (renommages, suppressions, éclatements, autorités neuves, liens) aux contributeurs non liés des notices d''une bibliothèque. Rejouable. Migration 20261019160041.';

-- ── L'appel pour Anarchief.Org (production seulement) ──────────────────
DO $anarchief_autorites$
DECLARE
  v_lib uuid;
  v_res jsonb;
  v_liste jsonb := $liste$
{
 "eclatements": [
  {"nom": "De Jong  Boerema  Wedman  Janzen", "parts": ["De Jong", "Boerema", "Wedman", "Janzen"]},
  {"nom": "Luxemburg  Berkman  Borovoj  Goldman  Schapiro", "parts": ["Luxemburg", "Berkman", "Borovoj", "Goldman", "Schapiro"]},
  {"nom": "Berkman  Borovoj  Goldman  Schapiro", "parts": ["Berkman", "Borovoj", "Goldman", "Schapiro"]},
  {"nom": "Vrije Bond  PP.  IWW", "parts": ["Vrije Bond", "PP.", "IWW"]},
  {"nom": "Dieu  Marcel (aka Hem Day) et Ryner  Han", "parts": ["Dieu, Marcel (aka Hem Day)", "Ryner, Han"]},
  {"nom": "De Jong  De Jong  Lehning  e.a.", "parts": ["De Jong", "De Jong", "Lehning"]},
  {"nom": "Hem Day  Woodcock  Zaccaria  Fleischer e.a.", "parts": ["Hem Day", "Woodcock", "Zaccaria", "Fleischer"]},
  {"nom": "Clark  Crown  McKee  Macpherson", "parts": ["Clark", "Crown", "McKee", "Macpherson"]},
  {"nom": "Ernestan  Piron  Van Overstraeten", "parts": ["Ernestan", "Piron", "Van Overstraeten"]},
  {"nom": "Collectief (Rodenko  Hornstra  Dekker)", "parts": ["Rodenko", "Hornstra", "Dekker"]},
  {"nom": "CNT  Spuigroep  ASSW", "parts": ["CNT", "Spuigroep", "ASSW"]},
  {"nom": "Dielo Truda  Archinow  Machno  Mett ea", "parts": ["Dielo Truda", "Archinow", "Machno", "Mett"]},
  {"nom": "Hem Day  E. Armand  W.J. Jong  J. Hooijberg", "parts": ["Hem Day", "E. Armand", "W.J. Jong", "J. Hooijberg"]},
  {"nom": "Campion  Léo et Day  Hem", "parts": ["Campion, Léo", "Day, Hem"]},
  {"nom": "Hem Day  Albin  Méric  Campion  Armand  Mualdès  Barcelone  Emery  Bruchard", "parts": ["Hem Day", "Albin", "Méric", "Campion", "Armand", "Mualdès", "Barcelone", "Emery", "Bruchard"]},
  {"nom": "Wereldscholen  Elcker-Ik  Vorming tot bevrijding", "parts": ["Wereldscholen", "Elcker-Ik", "Vorming tot bevrijding"]},
  {"nom": "ABC Gent  Kropotkin  Goldman", "parts": ["ABC Gent", "Kropotkin", "Goldman"]},
  {"nom": "Anarchistische Groep Amsterdam (AGA) Prole.info", "parts": ["Anarchistische Groep Amsterdam (AGA)", "Prole.info"]},
  {"nom": "Frans Masereel Romain Rolland", "parts": ["Frans Masereel", "Romain Rolland"]},
  {"nom": "Vervest P. Colstee I.", "parts": ["Vervest, P.", "Colstee, I."]}
 ],
 "renommages": [
  {"nom": "Eigen Hulp (Koor", "en": "Eigen Hulp (Koor, Orkest)"},
  {"nom": "5 vrouwen uit Utrecht (Metha  Hanneke  Simone  Mikkie", "en": "5 vrouwen uit Utrecht (Metha, Hanneke, Simone, Mikkie, Maartje)"},
  {"nom": "Stichting OVERAL (Hans", "en": "Stichting OVERAL (Hans, Kees)"},
  {"nom": "ABC Nijmegen)", "en": "ABC Nijmegen"},
  {"nom": "Anarchistisch Kollektief La Cecilia (Leuven", "en": "Anarchistisch Kollektief La Cecilia (Leuven)"}
 ],
 "suppressions": [
  "Orkest)",
  "Maartje)",
  "Kees)"
 ],
 "autorites": [
  {"cle": "Anton Constandse", "preferred": "Anton Constandse", "sort": "Constandse, Anton", "type": "person", "alias": ["A.L. Constandse", "Anton L. Constandse", "Anton e.a. Constandse"]},
  {"cle": "Bart de Ligt", "preferred": "Bart de Ligt", "sort": "Ligt, Bart de", "type": "person", "alias": ["Bart De Ligt"]},
  {"cle": "Ferdinand Domela Nieuwenhuis", "preferred": "Ferdinand Domela Nieuwenhuis", "sort": "Domela Nieuwenhuis, Ferdinand", "type": "person", "alias": ["F. Domela Nieuwenhuis"]},
  {"cle": "Hem Day", "preferred": "Hem Day", "sort": "Hem Day", "type": "person", "alias": ["Day  Hem (aka van/de Dieu  Marcel) (?)", "Day, Hem", "Dieu, Marcel", "Dieu, Marcel (aka Hem Day)", "Marcel (aka Hem Day) Dieu", "Marcel Dieu", "Marcel) Hem Day (aka van/de Dieu"]},
  {"cle": "Ravachol", "preferred": "Ravachol", "sort": "Ravachol", "type": "person", "alias": ["François Koënigstein", "François) Ravachol (aka van Koënigstein"]},
  {"cle": "Ernst Schneider", "preferred": "Ernst Schneider", "sort": "Schneider, Ernst", "type": "person", "alias": ["Ernst (aka Icarus) Schneider", "Icarus"]},
  {"cle": "Kreszentia Mühsam", "preferred": "Kreszentia Mühsam", "sort": "Mühsam, Kreszentia", "type": "person", "alias": ["Kreszentia (aka Zensi) Mühsam", "Zensi Mühsam"]},
  {"cle": "Hans Ramaer", "preferred": "Hans Ramaer", "sort": "Ramaer, Hans", "type": "person", "alias": ["H. Ramaer"]},
  {"cle": "Boudewijn Chorus", "preferred": "Boudewijn Chorus", "sort": "Chorus, Boudewijn", "type": "person", "alias": ["Boudewijn e.a. Chorus"]},
  {"cle": "Catherina Lydia de Ligt-van Rossem", "preferred": "Catherina Lydia de Ligt-van Rossem", "sort": "Ligt-van Rossem, Catherina Lydia de", "type": "person", "alias": ["Catherina Lydia De Ligt-Van Rossem", "Catherine Lydia De Ligt-Van Rossem"]},
  {"cle": "Albert de Jong", "preferred": "Albert de Jong", "sort": "Jong, Albert de", "type": "person", "alias": ["Albert De Jong", "Albert Secretariaat IAMV De Jong"]},
  {"cle": "Léo Campion", "preferred": "Léo Campion", "sort": "Campion, Léo", "type": "person", "alias": ["Campion", "Campion, Léo"]},
  {"cle": "J. Hooijberg", "preferred": "J. Hooijberg", "sort": "Hooijberg, J.", "type": "person", "alias": []},
  {"cle": "Alexander Schapiro", "preferred": "Alexander Schapiro", "sort": "Schapiro, Alexander", "type": "person", "alias": ["Schapiro"]},
  {"cle": "Anarchistisch Kollektief La Cecilia (Leuven)", "preferred": "Anarchistisch Kollektief La Cecilia (Leuven)", "sort": "Anarchistisch Kollektief La Cecilia (Leuven)", "type": "collective", "alias": ["Anarchistisch Kollektief La Cecilia", "Anarchistisch Kollektief La Cecilia Leuven"]},
  {"cle": "De Vieze Gasten", "preferred": "De Vieze Gasten", "sort": "De Vieze Gasten", "type": "collective", "alias": ["De Vieze Gasten (Gent)", "De vieze gasten", "Zijn Vieze Gasten"]},
  {"cle": "Landelijk Anarchistisch Overleg", "preferred": "Landelijk Anarchistisch Overleg", "sort": "Landelijk Anarchistisch Overleg", "type": "collective", "alias": ["LAO", "Landelijk Anarchistisch Overleg (LAO)"]},
  {"cle": "Anarchistische Groep Nijmegen", "preferred": "Anarchistische Groep Nijmegen", "sort": "Anarchistische Groep Nijmegen", "type": "collective", "alias": ["AGN", "Anarchistische Groep Nijmegen (AGN)"]},
  {"cle": "Anarchist Black Cross Gent", "preferred": "Anarchist Black Cross Gent", "sort": "Anarchist Black Cross Gent", "type": "collective", "alias": ["ABC Gent", "Anarchist Black Cross Gent (ABC Gent)"]},
  {"cle": "Anarchist Black Cross Nijmegen", "preferred": "Anarchist Black Cross Nijmegen", "sort": "Anarchist Black Cross Nijmegen", "type": "collective", "alias": ["ABC Nijmegen"]},
  {"cle": "Anarchist Black Cross Utrecht", "preferred": "Anarchist Black Cross Utrecht", "sort": "Anarchist Black Cross Utrecht", "type": "collective", "alias": ["ABC Utrecht", "Anarchist Black Cross Utrecht (ABC Utrecht)"]},
  {"cle": "Organisatie van Roermondse Anarchisten", "preferred": "Organisatie van Roermondse Anarchisten", "sort": "Organisatie van Roermondse Anarchisten", "type": "collective", "alias": ["Organisatie van Roermondse Anarchisten (Werkgroep Socialistische Theorie)"]},
  {"cle": "SKAL (Socio-Kulturele Aktiegroep Leuven)", "preferred": "SKAL (Socio-Kulturele Aktiegroep Leuven)", "sort": "SKAL (Socio-Kulturele Aktiegroep Leuven)", "type": "collective", "alias": ["SKAL", "SKAL (Socio-Kulurele Aktiegroep Leuven)"]},
  {"cle": "Onafhankelijk Verbond van Bedrijfsorganisaties", "preferred": "Onafhankelijk Verbond van Bedrijfsorganisaties", "sort": "Onafhankelijk Verbond van Bedrijfsorganisaties", "type": "collective", "alias": ["OVB", "Onafhankelijk Verbond van Bedrijfsorganisaties (OVB)"]},
  {"cle": "Anarchistisch Kollektief Gent", "preferred": "Anarchistisch Kollektief Gent", "sort": "Anarchistisch Kollektief Gent", "type": "collective", "alias": ["AK Gent", "AK Gent (Vrije Bond)"]},
  {"cle": "Anarchistische Groep Amsterdam", "preferred": "Anarchistische Groep Amsterdam", "sort": "Anarchistische Groep Amsterdam", "type": "collective", "alias": ["AGA", "Anarchistische Groep Amsterdam (AGA)"]},
  {"cle": "Situationistische Internationale", "preferred": "Situationistische Internationale", "sort": "Situationistische Internationale", "type": "collective", "alias": ["Situationistische Internationale (leden van de)"]},
  {"cle": "De Struikrover", "preferred": "De Struikrover", "sort": "De Struikrover", "type": "collective", "alias": ["De Struikrover (uitg.) Anoniem"]},
  {"cle": "Vrije Bond", "preferred": "Vrije Bond", "sort": "Vrije Bond", "type": "collective", "alias": []},
  {"cle": "IWW", "preferred": "IWW", "sort": "IWW", "type": "collective", "alias": []},
  {"cle": "Eigen Hulp (Koor, Orkest)", "preferred": "Eigen Hulp (Koor, Orkest)", "sort": "Eigen Hulp (Koor, Orkest)", "type": "collective", "alias": []},
  {"cle": "5 vrouwen uit Utrecht", "preferred": "5 vrouwen uit Utrecht", "sort": "5 vrouwen uit Utrecht", "type": "collective", "alias": ["5 vrouwen uit Utrecht (Metha, Hanneke, Simone, Mikkie, Maartje)"]},
  {"cle": "Stichting OVERAL", "preferred": "Stichting OVERAL", "sort": "Stichting OVERAL", "type": "collective", "alias": ["Stichting OVERAL (Hans, Kees)"]},
  {"cle": "Bertolt Brecht", "preferred": "Bertolt Brecht", "sort": "Brecht, Bertolt", "type": "person", "alias": ["Bertold Brecht"]},
  {"cle": "Brian A. Dominick", "preferred": "Brian A. Dominick", "sort": "Dominick, Brian A.", "type": "person", "alias": ["Brain A. Dominick"]},
  {"cle": "Gustave Hervé", "preferred": "Gustave Hervé", "sort": "Hervé, Gustave", "type": "person", "alias": ["Gustaaf Hervé"]},
  {"cle": "Attila Kotányi", "preferred": "Attila Kotányi", "sort": "Kotányi, Attila", "type": "person", "alias": ["Atilla Kotànyi"]},
  {"cle": "Wayne Price", "preferred": "Wayne Price", "sort": "Price, Wayne", "type": "person", "alias": ["Wayne Prize"]},
  {"cle": "Amory B. Lovins", "preferred": "Amory B. Lovins", "sort": "Lovins, Amory B.", "type": "person", "alias": ["Amory B Lovins"]},
  {"cle": "John M. Swomley Jr.", "preferred": "John M. Swomley Jr.", "sort": "Swomley, John M., Jr.", "type": "person", "alias": ["John M jr Swomley"]},
  {"cle": "H. Kolthek Jr.", "preferred": "H. Kolthek Jr.", "sort": "Kolthek, H., Jr.", "type": "person", "alias": []},
  {"cle": "Hetty C. Passchier-Meijer", "preferred": "Hetty C. Passchier-Meijer", "sort": "Passchier-Meijer, Hetty C.", "type": "person", "alias": ["Hetty C Passchier-Meijer"]},
  {"cle": "David H. Albert", "preferred": "David H. Albert", "sort": "Albert, David H.", "type": "person", "alias": ["David H Albert"]},
  {"cle": "Étienne de La Boétie", "preferred": "Étienne de La Boétie", "sort": "La Boétie, Étienne de", "type": "person", "alias": ["Étienne De la Boétie"]},
  {"cle": "Thom Holterman", "preferred": "Thom Holterman", "sort": "Holterman, Thom", "type": "person", "alias": []},
  {"cle": "Clara Wichmann", "preferred": "Clara Wichmann", "sort": "Wichmann, Clara", "type": "person", "alias": []},
  {"cle": "Jan Moulaert", "preferred": "Jan Moulaert", "sort": "Moulaert, Jan", "type": "person", "alias": []},
  {"cle": "Ruud Uittenhout", "preferred": "Ruud Uittenhout", "sort": "Uittenhout, Ruud", "type": "person", "alias": []},
  {"cle": "Roger Jacobs", "preferred": "Roger Jacobs", "sort": "Jacobs, Roger", "type": "person", "alias": []},
  {"cle": "Denise De Weerdt", "preferred": "Denise De Weerdt", "sort": "De Weerdt, Denise", "type": "person", "alias": []},
  {"cle": "Gene Sharp", "preferred": "Gene Sharp", "sort": "Sharp, Gene", "type": "person", "alias": []},
  {"cle": "Herman Gorter", "preferred": "Herman Gorter", "sort": "Gorter, Herman", "type": "person", "alias": []},
  {"cle": "Johny Lenaerts", "preferred": "Johny Lenaerts", "sort": "Lenaerts, Johny", "type": "person", "alias": []},
  {"cle": "Otto Rühle", "preferred": "Otto Rühle", "sort": "Rühle, Otto", "type": "person", "alias": []},
  {"cle": "Simon Radius", "preferred": "Simon Radius", "sort": "Radius, Simon", "type": "person", "alias": []},
  {"cle": "Steven De Batselier", "preferred": "Steven De Batselier", "sort": "De Batselier, Steven", "type": "person", "alias": []},
  {"cle": "André Bons", "preferred": "André Bons", "sort": "Bons, André", "type": "person", "alias": []},
  {"cle": "Antoon Roosens", "preferred": "Antoon Roosens", "sort": "Roosens, Antoon", "type": "person", "alias": []},
  {"cle": "Brian Martin", "preferred": "Brian Martin", "sort": "Martin, Brian", "type": "person", "alias": []},
  {"cle": "César De Paepe", "preferred": "César De Paepe", "sort": "De Paepe, César", "type": "person", "alias": ["Cesar De Paepe"]},
  {"cle": "Dirk Wouters", "preferred": "Dirk Wouters", "sort": "Wouters, Dirk", "type": "person", "alias": []},
  {"cle": "Eddy Bonte", "preferred": "Eddy Bonte", "sort": "Bonte, Eddy", "type": "person", "alias": []},
  {"cle": "Gabriel Kuhn", "preferred": "Gabriel Kuhn", "sort": "Kuhn, Gabriel", "type": "person", "alias": []},
  {"cle": "Henk Eikeboom", "preferred": "Henk Eikeboom", "sort": "Eikeboom, Henk", "type": "person", "alias": []},
  {"cle": "Jan Bervoets", "preferred": "Jan Bervoets", "sort": "Bervoets, Jan", "type": "person", "alias": []},
  {"cle": "Jean-François Füeg", "preferred": "Jean-François Füeg", "sort": "Füeg, Jean-François", "type": "person", "alias": []},
  {"cle": "Mark Barnsley", "preferred": "Mark Barnsley", "sort": "Barnsley, Mark", "type": "person", "alias": []},
  {"cle": "Peter Zegers", "preferred": "Peter Zegers", "sort": "Zegers, Peter", "type": "person", "alias": []},
  {"cle": "A. Sormon", "preferred": "A. Sormon", "sort": "Sormon, A.", "type": "person", "alias": ["A Sormon"]},
  {"cle": "A. Cabo", "preferred": "A. Cabo", "sort": "Cabo, A.", "type": "person", "alias": []},
  {"cle": "A. H. van Kampen", "preferred": "A. H. van Kampen", "sort": "Kampen, A. H. van", "type": "person", "alias": ["A.H. Van Kampen"]},
  {"cle": "Adam Weaver", "preferred": "Adam Weaver", "sort": "Weaver, Adam", "type": "person", "alias": []},
  {"cle": "Agnès Pawlowsky", "preferred": "Agnès Pawlowsky", "sort": "Pawlowsky, Agnès", "type": "person", "alias": []},
  {"cle": "Aimé Dieu Rosecroix", "preferred": "Aimé Dieu Rosecroix", "sort": "Rosecroix, Aimé Dieu", "type": "person", "alias": []},
  {"cle": "Albo Helm", "preferred": "Albo Helm", "sort": "Helm, Albo", "type": "person", "alias": []},
  {"cle": "An Gordier", "preferred": "An Gordier", "sort": "Gordier, An", "type": "person", "alias": []},
  {"cle": "André Prudhommeaux", "preferred": "André Prudhommeaux", "sort": "Prudhommeaux, André", "type": "person", "alias": []},
  {"cle": "Anja van Oostrom", "preferred": "Anja van Oostrom", "sort": "Oostrom, Anja van", "type": "person", "alias": ["Anja Van Oostrom"]},
  {"cle": "Ariane Miéville", "preferred": "Ariane Miéville", "sort": "Miéville, Ariane", "type": "person", "alias": []},
  {"cle": "Arnold Roller", "preferred": "Arnold Roller", "sort": "Roller, Arnold", "type": "person", "alias": []},
  {"cle": "Arthur IJzerman", "preferred": "Arthur IJzerman", "sort": "IJzerman, Arthur", "type": "person", "alias": []},
  {"cle": "Arthur Mendes-George", "preferred": "Arthur Mendes-George", "sort": "Mendes-George, Arthur", "type": "person", "alias": []},
  {"cle": "August Vermeylen", "preferred": "August Vermeylen", "sort": "Vermeylen, August", "type": "person", "alias": []},
  {"cle": "B. Cold", "preferred": "B. Cold", "sort": "Cold, B.", "type": "person", "alias": ["B Cold"]},
  {"cle": "B. Damme", "preferred": "B. Damme", "sort": "Damme, B.", "type": "person", "alias": []},
  {"cle": "Bao Jingyan", "preferred": "Bao Jingyan", "sort": "Bao, Jingyan", "type": "person", "alias": []},
  {"cle": "Bas Moreel", "preferred": "Bas Moreel", "sort": "Moreel, Bas", "type": "person", "alias": []},
  {"cle": "Bas van der Plas", "preferred": "Bas van der Plas", "sort": "Plas, Bas van der", "type": "person", "alias": []},
  {"cle": "Benjamin Tucker", "preferred": "Benjamin Tucker", "sort": "Tucker, Benjamin", "type": "person", "alias": []},
  {"cle": "Bernard Salmon", "preferred": "Bernard Salmon", "sort": "Salmon, Bernard", "type": "person", "alias": []},
  {"cle": "Bert Altena", "preferred": "Bert Altena", "sort": "Altena, Bert", "type": "person", "alias": []},
  {"cle": "R. Bökkerkink", "preferred": "R. Bökkerkink", "sort": "Bökkerkink, R.", "type": "person", "alias": ["Bökkerkink R"]},
  {"cle": "Bruno Bifo", "preferred": "Bruno Bifo", "sort": "Bifo, Bruno", "type": "person", "alias": []},
  {"cle": "C. Rubens", "preferred": "C. Rubens", "sort": "Rubens, C.", "type": "person", "alias": ["C Rubens"]},
  {"cle": "C. Drossaart van Dusseldorp", "preferred": "C. Drossaart van Dusseldorp", "sort": "Drossaart van Dusseldorp, C.", "type": "person", "alias": []},
  {"cle": "Cees Richter", "preferred": "Cees Richter", "sort": "Richter, Cees", "type": "person", "alias": []},
  {"cle": "Chaz Bufe", "preferred": "Chaz Bufe", "sort": "Bufe, Chaz", "type": "person", "alias": []},
  {"cle": "Chuck Morse", "preferred": "Chuck Morse", "sort": "Morse, Chuck", "type": "person", "alias": []},
  {"cle": "Cyril Markus", "preferred": "Cyril Markus", "sort": "Markus, Cyril", "type": "person", "alias": []},
  {"cle": "D. Petit", "preferred": "D. Petit", "sort": "Petit, D.", "type": "person", "alias": []},
  {"cle": "D. H. Lawrence", "preferred": "D. H. Lawrence", "sort": "Lawrence, D. H.", "type": "person", "alias": ["D.H. Lawrence"]},
  {"cle": "David Stephens", "preferred": "David Stephens", "sort": "Stephens, David", "type": "person", "alias": []},
  {"cle": "B. de Vries", "preferred": "B. de Vries", "sort": "Vries, B. de", "type": "person", "alias": ["de Vries B"]},
  {"cle": "Deric Shannon", "preferred": "Deric Shannon", "sort": "Shannon, Deric", "type": "person", "alias": []},
  {"cle": "Doctress Neutopia", "preferred": "Doctress Neutopia", "sort": "Doctress Neutopia", "type": "person", "alias": []},
  {"cle": "Doug Morris", "preferred": "Doug Morris", "sort": "Morris, Doug", "type": "person", "alias": []},
  {"cle": "E. Zandstra", "preferred": "E. Zandstra", "sort": "Zandstra, E.", "type": "person", "alias": []},
  {"cle": "Elly Kloosterman", "preferred": "Elly Kloosterman", "sort": "Kloosterman, Elly", "type": "person", "alias": []},
  {"cle": "Émile Chapelier", "preferred": "Émile Chapelier", "sort": "Chapelier, Émile", "type": "person", "alias": []},
  {"cle": "Emile Vandervelde", "preferred": "Emile Vandervelde", "sort": "Vandervelde, Emile", "type": "person", "alias": []},
  {"cle": "Eric Duivenvoorden", "preferred": "Eric Duivenvoorden", "sort": "Duivenvoorden, Eric", "type": "person", "alias": []},
  {"cle": "Eric Krebbers", "preferred": "Eric Krebbers", "sort": "Krebbers, Eric", "type": "person", "alias": []},
  {"cle": "Erik Buelinckx", "preferred": "Erik Buelinckx", "sort": "Buelinckx, Erik", "type": "person", "alias": []},
  {"cle": "Evie Embrechts", "preferred": "Evie Embrechts", "sort": "Embrechts, Evie", "type": "person", "alias": []},
  {"cle": "F. Boenders", "preferred": "F. Boenders", "sort": "Boenders, F.", "type": "person", "alias": ["F. e.a. Boenders"]},
  {"cle": "Flip Glastra", "preferred": "Flip Glastra", "sort": "Glastra, Flip", "type": "person", "alias": []},
  {"cle": "Francisco Galceran Ferrer", "preferred": "Francisco Galceran Ferrer", "sort": "Galceran Ferrer, Francisco", "type": "person", "alias": []},
  {"cle": "Frans Lodewijkx", "preferred": "Frans Lodewijkx", "sort": "Lodewijkx, Frans", "type": "person", "alias": []},
  {"cle": "Frans Masereel", "preferred": "Frans Masereel", "sort": "Masereel, Frans", "type": "person", "alias": []},
  {"cle": "Fredy Perlman", "preferred": "Fredy Perlman", "sort": "Perlman, Fredy", "type": "person", "alias": []},
  {"cle": "G. Iospa", "preferred": "G. Iospa", "sort": "Iospa, G.", "type": "person", "alias": []},
  {"cle": "G. L. Meijer", "preferred": "G. L. Meijer", "sort": "Meijer, G. L.", "type": "person", "alias": ["G.L. Meijer"]},
  {"cle": "George Katsiaficas", "preferred": "George Katsiaficas", "sort": "Katsiaficas, George", "type": "person", "alias": []},
  {"cle": "George Lakey", "preferred": "George Lakey", "sort": "Lakey, George", "type": "person", "alias": []},
  {"cle": "Gerhard Rijnders", "preferred": "Gerhard Rijnders", "sort": "Rijnders, Gerhard", "type": "person", "alias": []},
  {"cle": "Gernot Jochheim", "preferred": "Gernot Jochheim", "sort": "Jochheim, Gernot", "type": "person", "alias": []},
  {"cle": "Gustave Dache", "preferred": "Gustave Dache", "sort": "Dache, Gustave", "type": "person", "alias": []},
  {"cle": "Guy Debord", "preferred": "Guy Debord", "sort": "Debord, Guy", "type": "person", "alias": []},
  {"cle": "H. G. Wells", "preferred": "H. G. Wells", "sort": "Wells, H. G.", "type": "person", "alias": []},
  {"cle": "H. P. G. Quack", "preferred": "H. P. G. Quack", "sort": "Quack, H. P. G.", "type": "person", "alias": ["H.P.G. Quack"]},
  {"cle": "Han Schook", "preferred": "Han Schook", "sort": "Schook, Han", "type": "person", "alias": ["Han (met de pet) Schook"]},
  {"cle": "Han Kuysten", "preferred": "Han Kuysten", "sort": "Kuysten, Han", "type": "person", "alias": []},
  {"cle": "Hanneke Willemse", "preferred": "Hanneke Willemse", "sort": "Willemse, Hanneke", "type": "person", "alias": []},
  {"cle": "Hans Jar", "preferred": "Hans Jar", "sort": "Jar, Hans", "type": "person", "alias": []},
  {"cle": "Hans Krikke", "preferred": "Hans Krikke", "sort": "Krikke, Hans", "type": "person", "alias": []},
  {"cle": "Harmen van Houten", "preferred": "Harmen van Houten", "sort": "Houten, Harmen van", "type": "person", "alias": []},
  {"cle": "Henri Haenen", "preferred": "Henri Haenen", "sort": "Haenen, Henri", "type": "person", "alias": []},
  {"cle": "Henriëtte Roland Holst", "preferred": "Henriëtte Roland Holst", "sort": "Roland Holst, Henriëtte", "type": "person", "alias": []},
  {"cle": "Herbert L. Matthews", "preferred": "Herbert L. Matthews", "sort": "Matthews, Herbert L.", "type": "person", "alias": []},
  {"cle": "Hubert van den Berg", "preferred": "Hubert van den Berg", "sort": "Berg, Hubert van den", "type": "person", "alias": ["Hubert Van den Berg"]},
  {"cle": "Huub Kurstjens", "preferred": "Huub Kurstjens", "sort": "Kurstjens, Huub", "type": "person", "alias": []},
  {"cle": "I. Colstee", "preferred": "I. Colstee", "sort": "Colstee, I.", "type": "person", "alias": ["Colstee, I."]},
  {"cle": "J. Rogue", "preferred": "J. Rogue", "sort": "Rogue, J.", "type": "person", "alias": ["J Rogue"]},
  {"cle": "J. C. Schemerhorn", "preferred": "J. C. Schemerhorn", "sort": "Schemerhorn, J. C.", "type": "person", "alias": []},
  {"cle": "J. H. Mackay", "preferred": "J. H. Mackay", "sort": "Mackay, J. H.", "type": "person", "alias": ["J.H. Mackay"]},
  {"cle": "Jacob Kats", "preferred": "Jacob Kats", "sort": "Kats, Jacob", "type": "person", "alias": []},
  {"cle": "Jacques J. Giele", "preferred": "Jacques J. Giele", "sort": "Giele, Jacques J.", "type": "person", "alias": []},
  {"cle": "Jane Meyerding", "preferred": "Jane Meyerding", "sort": "Meyerding, Jane", "type": "person", "alias": []},
  {"cle": "Jean Barrot", "preferred": "Jean Barrot", "sort": "Barrot, Jean", "type": "person", "alias": []},
  {"cle": "Jean Casseur", "preferred": "Jean Casseur", "sort": "Casseur, Jean", "type": "person", "alias": []},
  {"cle": "Jean De Boë", "preferred": "Jean De Boë", "sort": "De Boë, Jean", "type": "person", "alias": []},
  {"cle": "Jean Tillie", "preferred": "Jean Tillie", "sort": "Tillie, Jean", "type": "person", "alias": []},
  {"cle": "Jeanne Duprat", "preferred": "Jeanne Duprat", "sort": "Duprat, Jeanne", "type": "person", "alias": []},
  {"cle": "Jeroen ten Dam", "preferred": "Jeroen ten Dam", "sort": "Dam, Jeroen ten", "type": "person", "alias": ["Jeroen Ten Dam"]},
  {"cle": "Jeroen van Raalte", "preferred": "Jeroen van Raalte", "sort": "Raalte, Jeroen van", "type": "person", "alias": ["Jeroen Van Raalte"]},
  {"cle": "Jessica Mitford", "preferred": "Jessica Mitford", "sort": "Mitford, Jessica", "type": "person", "alias": []},
  {"cle": "Joao Mora", "preferred": "Joao Mora", "sort": "Mora, Joao", "type": "person", "alias": []},
  {"cle": "Johan Anthierens", "preferred": "Johan Anthierens", "sort": "Anthierens, Johan", "type": "person", "alias": []},
  {"cle": "Jos Geens", "preferred": "Jos Geens", "sort": "Geens, Jos", "type": "person", "alias": []},
  {"cle": "Jules Vallès", "preferred": "Jules Vallès", "sort": "Vallès, Jules", "type": "person", "alias": []},
  {"cle": "Kathlijn Pittomvils", "preferred": "Kathlijn Pittomvils", "sort": "Pittomvils, Kathlijn", "type": "person", "alias": []},
  {"cle": "Kees Stad", "preferred": "Kees Stad", "sort": "Stad, Kees", "type": "person", "alias": []},
  {"cle": "Ken Knabb", "preferred": "Ken Knabb", "sort": "Knabb, Ken", "type": "person", "alias": []},
  {"cle": "Klaas Pit", "preferred": "Klaas Pit", "sort": "Pit, Klaas", "type": "person", "alias": []},
  {"cle": "L. J. Bot", "preferred": "L. J. Bot", "sort": "Bot, L. J.", "type": "person", "alias": []},
  {"cle": "L. Lichtveld", "preferred": "L. Lichtveld", "sort": "Lichtveld, L.", "type": "person", "alias": []},
  {"cle": "L. Vanheerentals", "preferred": "L. Vanheerentals", "sort": "Vanheerentals, L.", "type": "person", "alias": []},
  {"cle": "Lao Tsu", "preferred": "Lao Tsu", "sort": "Lao Tsu", "type": "person", "alias": []},
  {"cle": "Louis Adamic", "preferred": "Louis Adamic", "sort": "Adamic, Louis", "type": "person", "alias": []},
  {"cle": "Louis Loréal", "preferred": "Louis Loréal", "sort": "Loréal, Louis", "type": "person", "alias": []},
  {"cle": "Louis Paul Boon", "preferred": "Louis Paul Boon", "sort": "Boon, Louis Paul", "type": "person", "alias": []},
  {"cle": "Louis Simon", "preferred": "Louis Simon", "sort": "Simon, Louis", "type": "person", "alias": []},
  {"cle": "Louis Sinner", "preferred": "Louis Sinner", "sort": "Sinner, Louis", "type": "person", "alias": []},
  {"cle": "Lucien Grelaud", "preferred": "Lucien Grelaud", "sort": "Grelaud, Lucien", "type": "person", "alias": []},
  {"cle": "Ludo Abicht", "preferred": "Ludo Abicht", "sort": "Abicht, Ludo", "type": "person", "alias": []},
  {"cle": "Marina Micheli", "preferred": "Marina Micheli", "sort": "Micheli, Marina", "type": "person", "alias": []},
  {"cle": "Meinte Ringia", "preferred": "Meinte Ringia", "sort": "Ringia, Meinte", "type": "person", "alias": []},
  {"cle": "Melaina Feenstra", "preferred": "Melaina Feenstra", "sort": "Feenstra, Melaina", "type": "person", "alias": []},
  {"cle": "Michael P. Spahr", "preferred": "Michael P. Spahr", "sort": "Spahr, Michael P.", "type": "person", "alias": []},
  {"cle": "Nicolas Inghels", "preferred": "Nicolas Inghels", "sort": "Inghels, Nicolas", "type": "person", "alias": []},
  {"cle": "Nina Nijsten", "preferred": "Nina Nijsten", "sort": "Nijsten, Nina", "type": "person", "alias": []},
  {"cle": "Oscar Testut", "preferred": "Oscar Testut", "sort": "Testut, Oscar", "type": "person", "alias": []},
  {"cle": "P. J. De Ridder", "preferred": "P. J. De Ridder", "sort": "De Ridder, P. J.", "type": "person", "alias": ["P J De Ridder"]},
  {"cle": "P. Vervest", "preferred": "P. Vervest", "sort": "Vervest, P.", "type": "person", "alias": ["Vervest, P."]},
  {"cle": "Patrick Pasture", "preferred": "Patrick Pasture", "sort": "Pasture, Patrick", "type": "person", "alias": []},
  {"cle": "Peggy Kornegger", "preferred": "Peggy Kornegger", "sort": "Kornegger, Peggy", "type": "person", "alias": []},
  {"cle": "Peter Marshall", "preferred": "Peter Marshall", "sort": "Marshall, Peter", "type": "person", "alias": []},
  {"cle": "Peter Storm", "preferred": "Peter Storm", "sort": "Storm, Peter", "type": "person", "alias": []},
  {"cle": "Philippe Wittenberg", "preferred": "Philippe Wittenberg", "sort": "Wittenberg, Philippe", "type": "person", "alias": []},
  {"cle": "Pietre Bianchi", "preferred": "Pietre Bianchi", "sort": "Bianchi, Pietre", "type": "person", "alias": []},
  {"cle": "René Gabriëls", "preferred": "René Gabriëls", "sort": "Gabriëls, René", "type": "person", "alias": []},
  {"cle": "René Johannes Sanders", "preferred": "René Johannes Sanders", "sort": "Sanders, René Johannes", "type": "person", "alias": []},
  {"cle": "René Steyaert", "preferred": "René Steyaert", "sort": "Steyaert, René", "type": "person", "alias": []},
  {"cle": "Robert Willem Frijn", "preferred": "Robert Willem Frijn", "sort": "Frijn, Robert Willem", "type": "person", "alias": []},
  {"cle": "Roel van Duyn", "preferred": "Roel van Duyn", "sort": "Duyn, Roel van", "type": "person", "alias": ["Roel Van Duyn"]},
  {"cle": "Romain Rolland", "preferred": "Romain Rolland", "sort": "Rolland, Romain", "type": "person", "alias": []},
  {"cle": "Rymke Wiersma", "preferred": "Rymke Wiersma", "sort": "Wiersma, Rymke", "type": "person", "alias": []},
  {"cle": "S. M. Sheehan", "preferred": "S. M. Sheehan", "sort": "Sheehan, S. M.", "type": "person", "alias": ["S.M. Sheehan"]},
  {"cle": "Samar Ranjan Sen", "preferred": "Samar Ranjan Sen", "sort": "Sen, Samar Ranjan", "type": "person", "alias": []},
  {"cle": "Sonali Kolhatkar", "preferred": "Sonali Kolhatkar", "sort": "Kolhatkar, Sonali", "type": "person", "alias": []},
  {"cle": "Stijn Vanclooster", "preferred": "Stijn Vanclooster", "sort": "Vanclooster, Stijn", "type": "person", "alias": []},
  {"cle": "T. Barnacle", "preferred": "T. Barnacle", "sort": "Barnacle, T.", "type": "person", "alias": ["T Barnacle"]},
  {"cle": "T. Veenstra", "preferred": "T. Veenstra", "sort": "Veenstra, T.", "type": "person", "alias": ["T Veenstra"]},
  {"cle": "Thomas Meyer-Falk", "preferred": "Thomas Meyer-Falk", "sort": "Meyer-Falk, Thomas", "type": "person", "alias": []},
  {"cle": "Tommy Ryan", "preferred": "Tommy Ryan", "sort": "Ryan, Tommy", "type": "person", "alias": []},
  {"cle": "Toni Negri", "preferred": "Toni Negri", "sort": "Negri, Toni", "type": "person", "alias": []},
  {"cle": "Torsten Liesegang", "preferred": "Torsten Liesegang", "sort": "Liesegang, Torsten", "type": "person", "alias": []},
  {"cle": "Tristan Faes", "preferred": "Tristan Faes", "sort": "Faes, Tristan", "type": "person", "alias": []},
  {"cle": "Upton Sinclair", "preferred": "Upton Sinclair", "sort": "Sinclair, Upton", "type": "person", "alias": []},
  {"cle": "Van den Dungen", "preferred": "Van den Dungen", "sort": "Van den Dungen", "type": "person", "alias": []},
  {"cle": "G. Van der Bruggen", "preferred": "G. Van der Bruggen", "sort": "Van der Bruggen, G.", "type": "person", "alias": ["Van der Bruggen G"]},
  {"cle": "W. J. Jong", "preferred": "W. J. Jong", "sort": "Jong, W. J.", "type": "person", "alias": ["W.J. Jong"]},
  {"cle": "Willi Schlamm", "preferred": "Willi Schlamm", "sort": "Schlamm, Willi", "type": "person", "alias": []},
  {"cle": "Willy Verhoysen", "preferred": "Willy Verhoysen", "sort": "Verhoysen, Willy", "type": "person", "alias": []},
  {"cle": "Wolfgang Sternstein", "preferred": "Wolfgang Sternstein", "sort": "Sternstein, Wolfgang", "type": "person", "alias": []},
  {"cle": "Xavier Bekaert", "preferred": "Xavier Bekaert", "sort": "Bekaert, Xavier", "type": "person", "alias": []},
  {"cle": "Radicale Criminologen (Leuven)", "preferred": "Radicale Criminologen (Leuven)", "sort": "Radicale Criminologen (Leuven)", "type": "collective", "alias": []},
  {"cle": "Libertaire Studiegroep Gent", "preferred": "Libertaire Studiegroep Gent", "sort": "Libertaire Studiegroep Gent", "type": "collective", "alias": []},
  {"cle": "Landelijke Anarchistische Samenwerking", "preferred": "Landelijke Anarchistische Samenwerking", "sort": "Landelijke Anarchistische Samenwerking", "type": "collective", "alias": ["LAS", "Landelijke Anarchistische Samenwerking (LAS)"]},
  {"cle": "Nederlands Syndicalistisch Vakverbond", "preferred": "Nederlands Syndicalistisch Vakverbond", "sort": "Nederlands Syndicalistisch Vakverbond", "type": "collective", "alias": ["NSV", "Nederlands Syndicalistisch Vakverbond (NSV)"]},
  {"cle": "ONKRUIT België", "preferred": "ONKRUIT België", "sort": "ONKRUIT België", "type": "collective", "alias": []},
  {"cle": "Aktiegroep Dierenbevrijding Gent (ADB Gent)", "preferred": "Aktiegroep Dierenbevrijding Gent (ADB Gent)", "sort": "Aktiegroep Dierenbevrijding Gent (ADB Gent)", "type": "collective", "alias": []},
  {"cle": "IAMV", "preferred": "IAMV", "sort": "IAMV", "type": "collective", "alias": []},
  {"cle": "IOC-MAB", "preferred": "IOC-MAB", "sort": "IOC-MAB", "type": "collective", "alias": []},
  {"cle": "'t kan anders", "preferred": "'t kan anders", "sort": "'t kan anders", "type": "collective", "alias": []},
  {"cle": "A SEED Europe", "preferred": "A SEED Europe", "sort": "A SEED Europe", "type": "collective", "alias": []},
  {"cle": "ABC Antwerpen-Gent (Anarchist Black Cross)", "preferred": "ABC Antwerpen-Gent (Anarchist Black Cross)", "sort": "ABC Antwerpen-Gent (Anarchist Black Cross)", "type": "collective", "alias": []},
  {"cle": "ActivistSecurity.org Collective", "preferred": "ActivistSecurity.org Collective", "sort": "ActivistSecurity.org Collective", "type": "collective", "alias": []},
  {"cle": "Afdeling Amsterdam Onafhankelijk Verbond van Bedrijfsorganisaties", "preferred": "Afdeling Amsterdam Onafhankelijk Verbond van Bedrijfsorganisaties", "sort": "Afdeling Amsterdam Onafhankelijk Verbond van Bedrijfsorganisaties", "type": "collective", "alias": ["Afdeling Amsterdam Onafhankelijk Verbond van Bedrijfsorganisaties (OVB)", "OVB"]},
  {"cle": "Aktie Strohalm", "preferred": "Aktie Strohalm", "sort": "Aktie Strohalm", "type": "collective", "alias": []},
  {"cle": "Amsterdam Autovrij", "preferred": "Amsterdam Autovrij", "sort": "Amsterdam Autovrij", "type": "collective", "alias": []},
  {"cle": "Anarchisme Leuven", "preferred": "Anarchisme Leuven", "sort": "Anarchisme Leuven", "type": "collective", "alias": []},
  {"cle": "Anarchistisch Kollektief Unief Gent", "preferred": "Anarchistisch Kollektief Unief Gent", "sort": "Anarchistisch Kollektief Unief Gent", "type": "collective", "alias": []},
  {"cle": "Anarchistische Dagen Frankfurt", "preferred": "Anarchistische Dagen Frankfurt", "sort": "Anarchistische Dagen Frankfurt", "type": "collective", "alias": []},
  {"cle": "Anarchistische Federatie Gent", "preferred": "Anarchistische Federatie Gent", "sort": "Anarchistische Federatie Gent", "type": "collective", "alias": []},
  {"cle": "Anarchistische Federatie Nederland", "preferred": "Anarchistische Federatie Nederland", "sort": "Anarchistische Federatie Nederland", "type": "collective", "alias": []},
  {"cle": "Anarchistische Uitgeverij", "preferred": "Anarchistische Uitgeverij", "sort": "Anarchistische Uitgeverij", "type": "collective", "alias": []},
  {"cle": "AntiFascistisch Front (AFF Gent)", "preferred": "AntiFascistisch Front (AFF Gent)", "sort": "AntiFascistisch Front (AFF Gent)", "type": "collective", "alias": []},
  {"cle": "Antimilitaristisch Buro Leuven", "preferred": "Antimilitaristisch Buro Leuven", "sort": "Antimilitaristisch Buro Leuven", "type": "collective", "alias": []},
  {"cle": "Aspegroep Nederland", "preferred": "Aspegroep Nederland", "sort": "Aspegroep Nederland", "type": "collective", "alias": []},
  {"cle": "Asturian Institute of Comparative Vandalism", "preferred": "Asturian Institute of Comparative Vandalism", "sort": "Asturian Institute of Comparative Vandalism", "type": "collective", "alias": []},
  {"cle": "Autonome Antifa Gent", "preferred": "Autonome Antifa Gent", "sort": "Autonome Antifa Gent", "type": "collective", "alias": []},
  {"cle": "Autonoom Centrum Gent (AC Gent)", "preferred": "Autonoom Centrum Gent (AC Gent)", "sort": "Autonoom Centrum Gent (AC Gent)", "type": "collective", "alias": []},
  {"cle": "BedrijfsGroep Amsterdam", "preferred": "BedrijfsGroep Amsterdam", "sort": "BedrijfsGroep Amsterdam", "type": "collective", "alias": ["BGA", "BedrijfsGroep Amsterdam (BGA)"]},
  {"cle": "Bedrijfsorganisatie Collectieve Sector", "preferred": "Bedrijfsorganisatie Collectieve Sector", "sort": "Bedrijfsorganisatie Collectieve Sector", "type": "collective", "alias": ["BCS", "Bedrijfsorganisatie Collectieve Sector (BCS)"]},
  {"cle": "Beweging van de Tachtig (Nijmegen)", "preferred": "Beweging van de Tachtig (Nijmegen)", "sort": "Beweging van de Tachtig (Nijmegen)", "type": "collective", "alias": []},
  {"cle": "Beweging voor ArbeidersZelfbeheer", "preferred": "Beweging voor ArbeidersZelfbeheer", "sort": "Beweging voor ArbeidersZelfbeheer", "type": "collective", "alias": ["BAZ", "Beweging voor ArbeidersZelfbeheer (BAZ)"]},
  {"cle": "Black Cross Collective", "preferred": "Black Cross Collective", "sort": "Black Cross Collective", "type": "collective", "alias": []},
  {"cle": "BNFL", "preferred": "BNFL", "sort": "BNFL", "type": "collective", "alias": []},
  {"cle": "Bond Werkschuw Tuig", "preferred": "Bond Werkschuw Tuig", "sort": "Bond Werkschuw Tuig", "type": "collective", "alias": []},
  {"cle": "Collectief Zonder Stembiljet", "preferred": "Collectief Zonder Stembiljet", "sort": "Collectief Zonder Stembiljet", "type": "collective", "alias": []},
  {"cle": "Coördinatie van autonome groepen in Spanje", "preferred": "Coördinatie van autonome groepen in Spanje", "sort": "Coördinatie van autonome groepen in Spanje", "type": "collective", "alias": []},
  {"cle": "Croque Maison", "preferred": "Croque Maison", "sort": "Croque Maison", "type": "collective", "alias": []},
  {"cle": "De Nieuwe Komedie", "preferred": "De Nieuwe Komedie", "sort": "De Nieuwe Komedie", "type": "collective", "alias": []},
  {"cle": "De Vrienden van het Volk Bibliotheek", "preferred": "De Vrienden van het Volk Bibliotheek", "sort": "De Vrienden van het Volk Bibliotheek", "type": "collective", "alias": []},
  {"cle": "De Vrije Gedachte", "preferred": "De Vrije Gedachte", "sort": "De Vrije Gedachte", "type": "collective", "alias": []},
  {"cle": "De Vrije Ruisledenaar", "preferred": "De Vrije Ruisledenaar", "sort": "De Vrije Ruisledenaar", "type": "collective", "alias": []},
  {"cle": "Federatie van Vrije Socialisten Recht voor Allen", "preferred": "Federatie van Vrije Socialisten Recht voor Allen", "sort": "Federatie van Vrije Socialisten Recht voor Allen", "type": "collective", "alias": []},
  {"cle": "Het Cirkus van Vuile Mon", "preferred": "Het Cirkus van Vuile Mon", "sort": "Het Cirkus van Vuile Mon", "type": "collective", "alias": []},
  {"cle": "Het internationaal Van der Lubbe-comite", "preferred": "Het internationaal Van der Lubbe-comite", "sort": "Het internationaal Van der Lubbe-comite", "type": "collective", "alias": []},
  {"cle": "Het Krakend Gewricht", "preferred": "Het Krakend Gewricht", "sort": "Het Krakend Gewricht", "type": "collective", "alias": []},
  {"cle": "Internationale aaneensluiting tegen oorlog en militarisme RIGM", "preferred": "Internationale aaneensluiting tegen oorlog en militarisme RIGM", "sort": "Internationale aaneensluiting tegen oorlog en militarisme RIGM", "type": "collective", "alias": []},
  {"cle": "Internationale Anarchistische Bijeenkomst Ruigoord", "preferred": "Internationale Anarchistische Bijeenkomst Ruigoord", "sort": "Internationale Anarchistische Bijeenkomst Ruigoord", "type": "collective", "alias": []},
  {"cle": "KA", "preferred": "KA", "sort": "KA", "type": "collective", "alias": []},
  {"cle": "Kafe de Harde Kern", "preferred": "Kafe de Harde Kern", "sort": "Kafe de Harde Kern", "type": "collective", "alias": []},
  {"cle": "Karavaan Stop Europa", "preferred": "Karavaan Stop Europa", "sort": "Karavaan Stop Europa", "type": "collective", "alias": []},
  {"cle": "Kollektiv (Bremen)", "preferred": "Kollektiv (Bremen)", "sort": "Kollektiv (Bremen)", "type": "collective", "alias": []},
  {"cle": "Kritische Universiteit Nijmegen", "preferred": "Kritische Universiteit Nijmegen", "sort": "Kritische Universiteit Nijmegen", "type": "collective", "alias": []},
  {"cle": "Landelijke Werkgroep Anti-Autoritaire", "preferred": "Landelijke Werkgroep Anti-Autoritaire", "sort": "Landelijke Werkgroep Anti-Autoritaire", "type": "collective", "alias": []},
  {"cle": "Leesclub Les Pétroleuses", "preferred": "Leesclub Les Pétroleuses", "sort": "Leesclub Les Pétroleuses", "type": "collective", "alias": []},
  {"cle": "Les Groupes Anarchistes Bruxellois", "preferred": "Les Groupes Anarchistes Bruxellois", "sort": "Les Groupes Anarchistes Bruxellois", "type": "collective", "alias": []},
  {"cle": "Nederlands Instituut voor Vredesvraagstukken", "preferred": "Nederlands Instituut voor Vredesvraagstukken", "sort": "Nederlands Instituut voor Vredesvraagstukken", "type": "collective", "alias": []},
  {"cle": "Papieren Tijger", "preferred": "Papieren Tijger", "sort": "Papieren Tijger", "type": "collective", "alias": []},
  {"cle": "Pleasure Tendency", "preferred": "Pleasure Tendency", "sort": "Pleasure Tendency", "type": "collective", "alias": []},
  {"cle": "Red Sunshine Gang", "preferred": "Red Sunshine Gang", "sort": "Red Sunshine Gang", "type": "collective", "alias": []},
  {"cle": "Revolutionaire RadenSocialisten (Antwerpen)", "preferred": "Revolutionaire RadenSocialisten (Antwerpen)", "sort": "Revolutionaire RadenSocialisten (Antwerpen)", "type": "collective", "alias": []},
  {"cle": "Riot Squad", "preferred": "Riot Squad", "sort": "Riot Squad", "type": "collective", "alias": []},
  {"cle": "Scola Oikonomia", "preferred": "Scola Oikonomia", "sort": "Scola Oikonomia", "type": "collective", "alias": []},
  {"cle": "Socialistiese Opvoeding", "preferred": "Socialistiese Opvoeding", "sort": "Socialistiese Opvoeding", "type": "collective", "alias": []},
  {"cle": "Solidarité Ouvrière", "preferred": "Solidarité Ouvrière", "sort": "Solidarité Ouvrière", "type": "collective", "alias": []},
  {"cle": "Spartacusbond NL", "preferred": "Spartacusbond NL", "sort": "Spartacusbond NL", "type": "collective", "alias": []},
  {"cle": "Stichting Afval", "preferred": "Stichting Afval", "sort": "Stichting Afval", "type": "collective", "alias": []},
  {"cle": "Studenten van Straatsburg", "preferred": "Studenten van Straatsburg", "sort": "Studenten van Straatsburg", "type": "collective", "alias": []},
  {"cle": "The Laughing Poets", "preferred": "The Laughing Poets", "sort": "The Laughing Poets", "type": "collective", "alias": []},
  {"cle": "Twin Cities IWW Branch", "preferred": "Twin Cities IWW Branch", "sort": "Twin Cities IWW Branch", "type": "collective", "alias": []},
  {"cle": "Uitgeverij de Dolle Hond", "preferred": "Uitgeverij de Dolle Hond", "sort": "Uitgeverij de Dolle Hond", "type": "collective", "alias": []},
  {"cle": "Vuile Mong en de vieze gasten", "preferred": "Vuile Mong en de vieze gasten", "sort": "Vuile Mong en de vieze gasten", "type": "collective", "alias": []},
  {"cle": "Werkgroep Alternatieve Ekonomie", "preferred": "Werkgroep Alternatieve Ekonomie", "sort": "Werkgroep Alternatieve Ekonomie", "type": "collective", "alias": []},
  {"cle": "Werklozenvakbond Leuven", "preferred": "Werklozenvakbond Leuven", "sort": "Werklozenvakbond Leuven", "type": "collective", "alias": []},
  {"cle": "Workers Solidarity Movement", "preferred": "Workers Solidarity Movement", "sort": "Workers Solidarity Movement", "type": "collective", "alias": []},
  {"cle": "FELS Für Eine Linke Stromung", "preferred": "FELS Für Eine Linke Stromung", "sort": "FELS Für Eine Linke Stromung", "type": "collective", "alias": []},
  {"cle": "Accion Fuego", "preferred": "Accion Fuego", "sort": "Accion Fuego", "type": "collective", "alias": []},
  {"cle": "Angel Alley", "preferred": "Angel Alley", "sort": "Angel Alley", "type": "collective", "alias": []},
  {"cle": "A-Koepel", "preferred": "A-Koepel", "sort": "A-Koepel", "type": "collective", "alias": []},
  {"cle": "Anarchisme-info", "preferred": "Anarchisme-info", "sort": "Anarchisme-info", "type": "collective", "alias": []},
  {"cle": "Anarkantus", "preferred": "Anarkantus", "sort": "Anarkantus", "type": "collective", "alias": []},
  {"cle": "Cre-Act", "preferred": "Cre-Act", "sort": "Cre-Act", "type": "collective", "alias": []},
  {"cle": "Éen-meiGroep", "preferred": "Éen-meiGroep", "sort": "Éen-meiGroep", "type": "collective", "alias": []},
  {"cle": "EuroDusnie", "preferred": "EuroDusnie", "sort": "EuroDusnie", "type": "collective", "alias": []},
  {"cle": "Queerilla", "preferred": "Queerilla", "sort": "Queerilla", "type": "collective", "alias": []},
  {"cle": "Streetmedics", "preferred": "Streetmedics", "sort": "Streetmedics", "type": "collective", "alias": []},
  {"cle": "Wildgroei", "preferred": "Wildgroei", "sort": "Wildgroei", "type": "collective", "alias": []},
  {"cle": "Spuigroep", "preferred": "Spuigroep", "sort": "Spuigroep", "type": "collective", "alias": []},
  {"cle": "ASSW", "preferred": "ASSW", "sort": "ASSW", "type": "collective", "alias": []},
  {"cle": "Elcker-Ik", "preferred": "Elcker-Ik", "sort": "Elcker-Ik", "type": "collective", "alias": []},
  {"cle": "Wereldscholen", "preferred": "Wereldscholen", "sort": "Wereldscholen", "type": "collective", "alias": []},
  {"cle": "Vorming tot bevrijding", "preferred": "Vorming tot bevrijding", "sort": "Vorming tot bevrijding", "type": "collective", "alias": []},
  {"cle": "Prole.info", "preferred": "Prole.info", "sort": "Prole.info", "type": "collective", "alias": []}
 ],
 "liens": [
  {"nom": "'t kan anders", "cle": "'t kan anders"},
  {"nom": "5 vrouwen uit Utrecht (Metha, Hanneke, Simone, Mikkie, Maartje)", "cle": "5 vrouwen uit Utrecht"},
  {"nom": "A SEED Europe", "cle": "A SEED Europe"},
  {"nom": "A Sormon", "cle": "A. Sormon"},
  {"nom": "A-Koepel", "cle": "A-Koepel"},
  {"nom": "A. Cabo", "cle": "A. Cabo"},
  {"nom": "A. Lehning", "autorite": 10053},
  {"nom": "A.H. Van Kampen", "cle": "A. H. van Kampen"},
  {"nom": "A.L. Constandse", "cle": "Anton Constandse"},
  {"nom": "ABC Antwerpen-Gent (Anarchist Black Cross)", "cle": "ABC Antwerpen-Gent (Anarchist Black Cross)"},
  {"nom": "ABC Gent", "cle": "Anarchist Black Cross Gent"},
  {"nom": "ABC Nijmegen", "cle": "Anarchist Black Cross Nijmegen"},
  {"nom": "AGN", "cle": "Anarchistische Groep Nijmegen"},
  {"nom": "AK Gent (Vrije Bond)", "cle": "Anarchistisch Kollektief Gent"},
  {"nom": "ASSW", "cle": "ASSW"},
  {"nom": "Abel Paz", "autorite": 10194},
  {"nom": "Accion Fuego", "cle": "Accion Fuego"},
  {"nom": "ActivistSecurity.org Collective", "cle": "ActivistSecurity.org Collective"},
  {"nom": "Adam Weaver", "cle": "Adam Weaver"},
  {"nom": "Afdeling Amsterdam Onafhankelijk Verbond van Bedrijfsorganisaties (OVB)", "cle": "Afdeling Amsterdam Onafhankelijk Verbond van Bedrijfsorganisaties"},
  {"nom": "Agnès Pawlowsky", "cle": "Agnès Pawlowsky"},
  {"nom": "Aimé Dieu Rosecroix", "cle": "Aimé Dieu Rosecroix"},
  {"nom": "Aktie Strohalm", "cle": "Aktie Strohalm"},
  {"nom": "Aktiegroep Dierenbevrijding Gent (ADB Gent)", "cle": "Aktiegroep Dierenbevrijding Gent (ADB Gent)"},
  {"nom": "Albert De Jong", "cle": "Albert de Jong"},
  {"nom": "Albert Libertad", "autorite": 10789},
  {"nom": "Albert Secretariaat IAMV De Jong", "cle": "Albert de Jong"},
  {"nom": "Albo Helm", "cle": "Albo Helm"},
  {"nom": "Aldous Huxley", "autorite": 10185},
  {"nom": "Alexander Berkman", "autorite": 10006},
  {"nom": "Alexander Schapiro", "cle": "Alexander Schapiro"},
  {"nom": "Alfredo Bonanno", "autorite": 10349},
  {"nom": "Amory B Lovins", "cle": "Amory B. Lovins"},
  {"nom": "Amsterdam Autovrij", "cle": "Amsterdam Autovrij"},
  {"nom": "An Gordier", "cle": "An Gordier"},
  {"nom": "Anarchisme Leuven", "cle": "Anarchisme Leuven"},
  {"nom": "Anarchisme-info", "cle": "Anarchisme-info"},
  {"nom": "Anarchist Black Cross Gent (ABC Gent)", "cle": "Anarchist Black Cross Gent"},
  {"nom": "Anarchist Black Cross Utrecht (ABC Utrecht)", "cle": "Anarchist Black Cross Utrecht"},
  {"nom": "Anarchistisch Kollektief Gent", "cle": "Anarchistisch Kollektief Gent"},
  {"nom": "Anarchistisch Kollektief La Cecilia", "cle": "Anarchistisch Kollektief La Cecilia (Leuven)"},
  {"nom": "Anarchistisch Kollektief La Cecilia (Leuven)", "cle": "Anarchistisch Kollektief La Cecilia (Leuven)"},
  {"nom": "Anarchistisch Kollektief La Cecilia Leuven", "cle": "Anarchistisch Kollektief La Cecilia (Leuven)"},
  {"nom": "Anarchistisch Kollektief Unief Gent", "cle": "Anarchistisch Kollektief Unief Gent"},
  {"nom": "Anarchistische Dagen Frankfurt", "cle": "Anarchistische Dagen Frankfurt"},
  {"nom": "Anarchistische Federatie Gent", "cle": "Anarchistische Federatie Gent"},
  {"nom": "Anarchistische Federatie Nederland", "cle": "Anarchistische Federatie Nederland"},
  {"nom": "Anarchistische Groep Amsterdam (AGA)", "cle": "Anarchistische Groep Amsterdam"},
  {"nom": "Anarchistische Groep Nijmegen (AGN)", "cle": "Anarchistische Groep Nijmegen"},
  {"nom": "Anarchistische Uitgeverij", "cle": "Anarchistische Uitgeverij"},
  {"nom": "Anarkantus", "cle": "Anarkantus"},
  {"nom": "André Bons", "cle": "André Bons"},
  {"nom": "André Prudhommeaux", "cle": "André Prudhommeaux"},
  {"nom": "Angel Alley", "cle": "Angel Alley"},
  {"nom": "Anja Van Oostrom", "cle": "Anja van Oostrom"},
  {"nom": "AntiFascistisch Front (AFF Gent)", "cle": "AntiFascistisch Front (AFF Gent)"},
  {"nom": "Antimilitaristisch Buro Leuven", "cle": "Antimilitaristisch Buro Leuven"},
  {"nom": "Anton Constandse", "cle": "Anton Constandse"},
  {"nom": "Anton L. Constandse", "cle": "Anton Constandse"},
  {"nom": "Anton Pannekoek", "autorite": 11001},
  {"nom": "Anton e.a. Constandse", "cle": "Anton Constandse"},
  {"nom": "Antonio Gramsci", "autorite": 11346},
  {"nom": "Antoon Roosens", "cle": "Antoon Roosens"},
  {"nom": "Archinow", "autorite": 10147},
  {"nom": "Ariane Miéville", "cle": "Ariane Miéville"},
  {"nom": "Armand", "autorite": 10041},
  {"nom": "Arnold Roller", "cle": "Arnold Roller"},
  {"nom": "Arthur (biografie Le Monde Libertaire) Lehning", "autorite": 10053},
  {"nom": "Arthur IJzerman", "cle": "Arthur IJzerman"},
  {"nom": "Arthur Lehning", "autorite": 10053},
  {"nom": "Arthur Mendes-George", "cle": "Arthur Mendes-George"},
  {"nom": "Aspegroep Nederland", "cle": "Aspegroep Nederland"},
  {"nom": "Asturian Institute of Comparative Vandalism", "cle": "Asturian Institute of Comparative Vandalism"},
  {"nom": "Atilla Kotànyi", "cle": "Attila Kotányi"},
  {"nom": "August Vermeylen", "cle": "August Vermeylen"},
  {"nom": "Augustin Souchy", "autorite": 10066},
  {"nom": "Autonome Antifa Gent", "cle": "Autonome Antifa Gent"},
  {"nom": "Autonoom Centrum Gent (AC Gent)", "cle": "Autonoom Centrum Gent (AC Gent)"},
  {"nom": "B Cold", "cle": "B. Cold"},
  {"nom": "B. Damme", "cle": "B. Damme"},
  {"nom": "BNFL", "cle": "BNFL"},
  {"nom": "Bao Jingyan", "cle": "Bao Jingyan"},
  {"nom": "Bart De Ligt", "cle": "Bart de Ligt"},
  {"nom": "Bart de Ligt", "cle": "Bart de Ligt"},
  {"nom": "Bartolomeo Vanzetti", "autorite": 11263},
  {"nom": "Bas Moreel", "cle": "Bas Moreel"},
  {"nom": "Bas van der Plas", "cle": "Bas van der Plas"},
  {"nom": "BedrijfsGroep Amsterdam (BGA)", "cle": "BedrijfsGroep Amsterdam"},
  {"nom": "Bedrijfsorganisatie Collectieve Sector (BCS)", "cle": "Bedrijfsorganisatie Collectieve Sector"},
  {"nom": "Benjamin Tucker", "cle": "Benjamin Tucker"},
  {"nom": "Berkman", "autorite": 10006},
  {"nom": "Bernard Salmon", "cle": "Bernard Salmon"},
  {"nom": "Bert Altena", "cle": "Bert Altena"},
  {"nom": "Bertold Brecht", "cle": "Bertolt Brecht"},
  {"nom": "Beweging van de Tachtig (Nijmegen)", "cle": "Beweging van de Tachtig (Nijmegen)"},
  {"nom": "Beweging voor ArbeidersZelfbeheer (BAZ)", "cle": "Beweging voor ArbeidersZelfbeheer"},
  {"nom": "Black Cross Collective", "cle": "Black Cross Collective"},
  {"nom": "Bond Werkschuw Tuig", "cle": "Bond Werkschuw Tuig"},
  {"nom": "Boudewijn Chorus", "cle": "Boudewijn Chorus"},
  {"nom": "Boudewijn e.a. Chorus", "cle": "Boudewijn Chorus"},
  {"nom": "Brain A. Dominick", "cle": "Brian A. Dominick"},
  {"nom": "Brian Martin", "cle": "Brian Martin"},
  {"nom": "Bruno Bifo", "cle": "Bruno Bifo"},
  {"nom": "Bökkerkink R", "cle": "R. Bökkerkink"},
  {"nom": "C Rubens", "cle": "C. Rubens"},
  {"nom": "C. Drossaart van Dusseldorp", "cle": "C. Drossaart van Dusseldorp"},
  {"nom": "Campion", "cle": "Léo Campion"},
  {"nom": "Campion, Léo", "cle": "Léo Campion"},
  {"nom": "Catherina Lydia De Ligt-Van Rossem", "cle": "Catherina Lydia de Ligt-van Rossem"},
  {"nom": "Catherine Lydia De Ligt-Van Rossem", "cle": "Catherina Lydia de Ligt-van Rossem"},
  {"nom": "Cees Richter", "cle": "Cees Richter"},
  {"nom": "Cesar De Paepe", "cle": "César De Paepe"},
  {"nom": "Chaz Bufe", "cle": "Chaz Bufe"},
  {"nom": "Chuck Morse", "cle": "Chuck Morse"},
  {"nom": "Clara Wichmann", "cle": "Clara Wichmann"},
  {"nom": "Colin Ward", "autorite": 10039},
  {"nom": "Collectief Zonder Stembiljet", "cle": "Collectief Zonder Stembiljet"},
  {"nom": "Colstee, I.", "cle": "I. Colstee"},
  {"nom": "Coördinatie van autonome groepen in Spanje", "cle": "Coördinatie van autonome groepen in Spanje"},
  {"nom": "Cre-Act", "cle": "Cre-Act"},
  {"nom": "Croque Maison", "cle": "Croque Maison"},
  {"nom": "Cyril Markus", "cle": "Cyril Markus"},
  {"nom": "D. A. De Santillan", "autorite": 24},
  {"nom": "D. Petit", "cle": "D. Petit"},
  {"nom": "D.H. Lawrence", "cle": "D. H. Lawrence"},
  {"nom": "Daniel Guérin", "autorite": 8},
  {"nom": "Dario Fo", "autorite": 10134},
  {"nom": "David Graeber", "autorite": 10012},
  {"nom": "David H Albert", "cle": "David H. Albert"},
  {"nom": "David Stephens", "cle": "David Stephens"},
  {"nom": "Day  Hem (aka van/de Dieu  Marcel) (?)", "cle": "Hem Day"},
  {"nom": "Day, Hem", "cle": "Hem Day"},
  {"nom": "De Nieuwe Komedie", "cle": "De Nieuwe Komedie"},
  {"nom": "De Struikrover", "cle": "De Struikrover"},
  {"nom": "De Struikrover (uitg.) Anoniem", "cle": "De Struikrover"},
  {"nom": "De Vieze Gasten", "cle": "De Vieze Gasten"},
  {"nom": "De Vieze Gasten (Gent)", "cle": "De Vieze Gasten"},
  {"nom": "De Vrienden van het Volk Bibliotheek", "cle": "De Vrienden van het Volk Bibliotheek"},
  {"nom": "De Vrije Gedachte", "cle": "De Vrije Gedachte"},
  {"nom": "De Vrije Ruisledenaar", "cle": "De Vrije Ruisledenaar"},
  {"nom": "De vieze gasten", "cle": "De Vieze Gasten"},
  {"nom": "Denise De Weerdt", "cle": "Denise De Weerdt"},
  {"nom": "Deric Shannon", "cle": "Deric Shannon"},
  {"nom": "Dielo Truda", "autorite": 11332},
  {"nom": "Dieu, Marcel (aka Hem Day)", "cle": "Hem Day"},
  {"nom": "Dirk Wouters", "cle": "Dirk Wouters"},
  {"nom": "Doctress Neutopia", "cle": "Doctress Neutopia"},
  {"nom": "Doug Morris", "cle": "Doug Morris"},
  {"nom": "E. Armand", "autorite": 10041},
  {"nom": "E. Zandstra", "cle": "E. Zandstra"},
  {"nom": "Eddy Bonte", "cle": "Eddy Bonte"},
  {"nom": "Eigen Hulp (Koor, Orkest)", "cle": "Eigen Hulp (Koor, Orkest)"},
  {"nom": "Elcker-Ik", "cle": "Elcker-Ik"},
  {"nom": "Elly Kloosterman", "cle": "Elly Kloosterman"},
  {"nom": "Emile Vandervelde", "cle": "Emile Vandervelde"},
  {"nom": "Emma Goldman", "autorite": 52},
  {"nom": "Eric Duivenvoorden", "cle": "Eric Duivenvoorden"},
  {"nom": "Eric Krebbers", "cle": "Eric Krebbers"},
  {"nom": "Erik Buelinckx", "cle": "Erik Buelinckx"},
  {"nom": "Ernst (aka Icarus) Schneider", "cle": "Ernst Schneider"},
  {"nom": "Errico Malatesta", "autorite": 4},
  {"nom": "EuroDusnie", "cle": "EuroDusnie"},
  {"nom": "Evie Embrechts", "cle": "Evie Embrechts"},
  {"nom": "F. Domela Nieuwenhuis", "cle": "Ferdinand Domela Nieuwenhuis"},
  {"nom": "F. e.a. Boenders", "cle": "F. Boenders"},
  {"nom": "FELS Für Eine Linke Stromung", "cle": "FELS Für Eine Linke Stromung"},
  {"nom": "Federatie van Vrije Socialisten Recht voor Allen", "cle": "Federatie van Vrije Socialisten Recht voor Allen"},
  {"nom": "Ferdinand Domela Nieuwenhuis", "cle": "Ferdinand Domela Nieuwenhuis"},
  {"nom": "Flip Glastra", "cle": "Flip Glastra"},
  {"nom": "Francisco Galceran Ferrer", "cle": "Francisco Galceran Ferrer"},
  {"nom": "Frans Lodewijkx", "cle": "Frans Lodewijkx"},
  {"nom": "Frans Masereel", "cle": "Frans Masereel"},
  {"nom": "François) Ravachol (aka van Koënigstein", "cle": "Ravachol"},
  {"nom": "Fredy Perlman", "cle": "Fredy Perlman"},
  {"nom": "G. Iospa", "cle": "G. Iospa"},
  {"nom": "G.L. Meijer", "cle": "G. L. Meijer"},
  {"nom": "Gabriel Kuhn", "cle": "Gabriel Kuhn"},
  {"nom": "Gene Sharp", "cle": "Gene Sharp"},
  {"nom": "George Katsiaficas", "cle": "George Katsiaficas"},
  {"nom": "George Lakey", "cle": "George Lakey"},
  {"nom": "George Woodcock", "autorite": 10112},
  {"nom": "Georges Blond", "autorite": 10343},
  {"nom": "Georges Thonar", "autorite": 11232},
  {"nom": "Gerhard Rijnders", "cle": "Gerhard Rijnders"},
  {"nom": "Gernot Jochheim", "cle": "Gernot Jochheim"},
  {"nom": "Goldman", "autorite": 52},
  {"nom": "Gustaaf Hervé", "cle": "Gustave Hervé"},
  {"nom": "Gustav Landauer", "autorite": 10766},
  {"nom": "Gustave Dache", "cle": "Gustave Dache"},
  {"nom": "Guy Debord", "cle": "Guy Debord"},
  {"nom": "H. G. Wells", "cle": "H. G. Wells"},
  {"nom": "H. Kolthek Jr.", "cle": "H. Kolthek Jr."},
  {"nom": "H. Ramaer", "cle": "Hans Ramaer"},
  {"nom": "H.P.G. Quack", "cle": "H. P. G. Quack"},
  {"nom": "Han (met de pet) Schook", "cle": "Han Schook"},
  {"nom": "Han Kuysten", "cle": "Han Kuysten"},
  {"nom": "Hanneke Willemse", "cle": "Hanneke Willemse"},
  {"nom": "Hans Jar", "cle": "Hans Jar"},
  {"nom": "Hans Krikke", "cle": "Hans Krikke"},
  {"nom": "Hans Ramaer", "cle": "Hans Ramaer"},
  {"nom": "Harmen van Houten", "cle": "Harmen van Houten"},
  {"nom": "Hem Day", "cle": "Hem Day"},
  {"nom": "Henk Eikeboom", "cle": "Henk Eikeboom"},
  {"nom": "Henri David Thoreau", "autorite": 10067},
  {"nom": "Henri Haenen", "cle": "Henri Haenen"},
  {"nom": "Henriëtte Roland Holst", "cle": "Henriëtte Roland Holst"},
  {"nom": "Herbert L. Matthews", "cle": "Herbert L. Matthews"},
  {"nom": "Herbert Read", "autorite": 10019},
  {"nom": "Herman Gorter", "cle": "Herman Gorter"},
  {"nom": "Het Cirkus van Vuile Mon", "cle": "Het Cirkus van Vuile Mon"},
  {"nom": "Het Krakend Gewricht", "cle": "Het Krakend Gewricht"},
  {"nom": "Het internationaal Van der Lubbe-comite", "cle": "Het internationaal Van der Lubbe-comite"},
  {"nom": "Hetty C Passchier-Meijer", "cle": "Hetty C. Passchier-Meijer"},
  {"nom": "Howard Ehrlich", "autorite": 10539},
  {"nom": "Howard Zinn", "autorite": 10186},
  {"nom": "Hubert Van den Berg", "cle": "Hubert van den Berg"},
  {"nom": "Huub Kurstjens", "cle": "Huub Kurstjens"},
  {"nom": "I. Colstee", "cle": "I. Colstee"},
  {"nom": "IAMV", "cle": "IAMV"},
  {"nom": "IOC-MAB", "cle": "IOC-MAB"},
  {"nom": "IWW", "cle": "IWW"},
  {"nom": "Internationale Anarchistische Bijeenkomst Ruigoord", "cle": "Internationale Anarchistische Bijeenkomst Ruigoord"},
  {"nom": "Internationale aaneensluiting tegen oorlog en militarisme RIGM", "cle": "Internationale aaneensluiting tegen oorlog en militarisme RIGM"},
  {"nom": "J Rogue", "cle": "J. Rogue"},
  {"nom": "J. C. Schemerhorn", "cle": "J. C. Schemerhorn"},
  {"nom": "J. Hooijberg", "cle": "J. Hooijberg"},
  {"nom": "J.H. Mackay", "cle": "J. H. Mackay"},
  {"nom": "Jacob Kats", "cle": "Jacob Kats"},
  {"nom": "Jacques J. Giele", "cle": "Jacques J. Giele"},
  {"nom": "Jan Bervoets", "cle": "Jan Bervoets"},
  {"nom": "Jan Moulaert", "cle": "Jan Moulaert"},
  {"nom": "Jane Meyerding", "cle": "Jane Meyerding"},
  {"nom": "Janet Biehl", "autorite": 10335},
  {"nom": "Jean Barrot", "cle": "Jean Barrot"},
  {"nom": "Jean Barrue", "autorite": 11576},
  {"nom": "Jean Casseur", "cle": "Jean Casseur"},
  {"nom": "Jean De Boë", "cle": "Jean De Boë"},
  {"nom": "Jean Grave", "autorite": 10669},
  {"nom": "Jean Tillie", "cle": "Jean Tillie"},
  {"nom": "Jean-François Füeg", "cle": "Jean-François Füeg"},
  {"nom": "Jeanne Duprat", "cle": "Jeanne Duprat"},
  {"nom": "Jeroen Ten Dam", "cle": "Jeroen ten Dam"},
  {"nom": "Jeroen Van Raalte", "cle": "Jeroen van Raalte"},
  {"nom": "Jessica Mitford", "cle": "Jessica Mitford"},
  {"nom": "Jo Freeman", "autorite": 10619},
  {"nom": "Joao Mora", "cle": "Joao Mora"},
  {"nom": "Johan Anthierens", "cle": "Johan Anthierens"},
  {"nom": "Johann Most", "autorite": 10926},
  {"nom": "John M jr Swomley", "cle": "John M. Swomley Jr."},
  {"nom": "Johny Lenaerts", "cle": "Johny Lenaerts"},
  {"nom": "Jos Geens", "cle": "Jos Geens"},
  {"nom": "Jules Vallès", "cle": "Jules Vallès"},
  {"nom": "KA", "cle": "KA"},
  {"nom": "Kafe de Harde Kern", "cle": "Kafe de Harde Kern"},
  {"nom": "Karavaan Stop Europa", "cle": "Karavaan Stop Europa"},
  {"nom": "Kathlijn Pittomvils", "cle": "Kathlijn Pittomvils"},
  {"nom": "Kees Stad", "cle": "Kees Stad"},
  {"nom": "Ken Knabb", "cle": "Ken Knabb"},
  {"nom": "Klaas Pit", "cle": "Klaas Pit"},
  {"nom": "Kollektiv (Bremen)", "cle": "Kollektiv (Bremen)"},
  {"nom": "Kreszentia (aka Zensi) Mühsam", "cle": "Kreszentia Mühsam"},
  {"nom": "Kritische Universiteit Nijmegen", "cle": "Kritische Universiteit Nijmegen"},
  {"nom": "Kropotkin", "autorite": 5},
  {"nom": "L. J. Bot", "cle": "L. J. Bot"},
  {"nom": "L. Lichtveld", "cle": "L. Lichtveld"},
  {"nom": "L. Vanheerentals", "cle": "L. Vanheerentals"},
  {"nom": "Landelijk Anarchistisch Overleg", "cle": "Landelijk Anarchistisch Overleg"},
  {"nom": "Landelijk Anarchistisch Overleg (LAO)", "cle": "Landelijk Anarchistisch Overleg"},
  {"nom": "Landelijke Anarchistische Samenwerking (LAS)", "cle": "Landelijke Anarchistische Samenwerking"},
  {"nom": "Landelijke Werkgroep Anti-Autoritaire", "cle": "Landelijke Werkgroep Anti-Autoritaire"},
  {"nom": "Lao Tsu", "cle": "Lao Tsu"},
  {"nom": "Leesclub Les Pétroleuses", "cle": "Leesclub Les Pétroleuses"},
  {"nom": "Lehning", "autorite": 10053},
  {"nom": "Leo Tolstoy", "autorite": 10023},
  {"nom": "Les Groupes Anarchistes Bruxellois", "cle": "Les Groupes Anarchistes Bruxellois"},
  {"nom": "Libertaire Studiegroep Gent", "cle": "Libertaire Studiegroep Gent"},
  {"nom": "Louis Adamic", "cle": "Louis Adamic"},
  {"nom": "Louis Loréal", "cle": "Louis Loréal"},
  {"nom": "Louis Mercier Vega", "autorite": 10890},
  {"nom": "Louis Paul Boon", "cle": "Louis Paul Boon"},
  {"nom": "Louis Simon", "cle": "Louis Simon"},
  {"nom": "Louis Sinner", "cle": "Louis Sinner"},
  {"nom": "Louis Vega Mercier", "autorite": 10890},
  {"nom": "Louise Michel", "autorite": 10057},
  {"nom": "Lucien Grelaud", "cle": "Lucien Grelaud"},
  {"nom": "Ludo Abicht", "cle": "Ludo Abicht"},
  {"nom": "Luigi Fabbri", "autorite": 10031},
  {"nom": "Luxemburg", "autorite": 10034},
  {"nom": "Léo Campion", "cle": "Léo Campion"},
  {"nom": "Machno", "autorite": 10029},
  {"nom": "Marcel (aka Hem Day) Dieu", "cle": "Hem Day"},
  {"nom": "Marcel) Hem Day (aka van/de Dieu", "cle": "Hem Day"},
  {"nom": "Marina Micheli", "cle": "Marina Micheli"},
  {"nom": "Mark Barnsley", "cle": "Mark Barnsley"},
  {"nom": "Maurice Brinton", "autorite": 10364},
  {"nom": "Max Nettlau", "autorite": 40},
  {"nom": "Meinte Ringia", "cle": "Meinte Ringia"},
  {"nom": "Melaina Feenstra", "cle": "Melaina Feenstra"},
  {"nom": "Mett", "autorite": 10893},
  {"nom": "Michael Bakoenin", "autorite": 3},
  {"nom": "Michael P. Spahr", "cle": "Michael P. Spahr"},
  {"nom": "Murray Bookchin", "autorite": 10},
  {"nom": "Nederlands Instituut voor Vredesvraagstukken", "cle": "Nederlands Instituut voor Vredesvraagstukken"},
  {"nom": "Nederlands Syndicalistisch Vakverbond (NSV)", "cle": "Nederlands Syndicalistisch Vakverbond"},
  {"nom": "Nestor (e.a.) Machno", "autorite": 10029},
  {"nom": "Nestor Machno", "autorite": 10029},
  {"nom": "Nicola Sacco", "autorite": 11480},
  {"nom": "Nicolas Inghels", "cle": "Nicolas Inghels"},
  {"nom": "Nina Nijsten", "cle": "Nina Nijsten"},
  {"nom": "Noam Chomsky", "autorite": 9},
  {"nom": "ONKRUIT België", "cle": "ONKRUIT België"},
  {"nom": "Octave Mirbeau", "autorite": 10903},
  {"nom": "Onafhankelijk Verbond van Bedrijfsorganisaties (OVB)", "cle": "Onafhankelijk Verbond van Bedrijfsorganisaties"},
  {"nom": "Organisatie van Roermondse Anarchisten", "cle": "Organisatie van Roermondse Anarchisten"},
  {"nom": "Organisatie van Roermondse Anarchisten (Werkgroep Socialistische Theorie)", "cle": "Organisatie van Roermondse Anarchisten"},
  {"nom": "Oscar Testut", "cle": "Oscar Testut"},
  {"nom": "Oscar Wilde", "autorite": 10131},
  {"nom": "Otto Rühle", "cle": "Otto Rühle"},
  {"nom": "P J De Ridder", "cle": "P. J. De Ridder"},
  {"nom": "P. Kropotkin", "autorite": 5},
  {"nom": "P. Vervest", "cle": "P. Vervest"},
  {"nom": "Paolo Freire", "autorite": 10157},
  {"nom": "Papieren Tijger", "cle": "Papieren Tijger"},
  {"nom": "Patrick Pasture", "cle": "Patrick Pasture"},
  {"nom": "Paul Eltzbacher", "autorite": 10542},
  {"nom": "Paul Goodman", "autorite": 10032},
  {"nom": "Paul Lafargue", "autorite": 10765},
  {"nom": "Peggy Kornegger", "cle": "Peggy Kornegger"},
  {"nom": "Peter Kropotkin", "autorite": 5},
  {"nom": "Peter Marshall", "cle": "Peter Marshall"},
  {"nom": "Peter Storm", "cle": "Peter Storm"},
  {"nom": "Peter Zegers", "cle": "Peter Zegers"},
  {"nom": "Philippe Wittenberg", "cle": "Philippe Wittenberg"},
  {"nom": "Pierre Kropotkine", "autorite": 5},
  {"nom": "Pierre-Joseph Proudhon", "autorite": 29},
  {"nom": "Pietre Bianchi", "cle": "Pietre Bianchi"},
  {"nom": "Pjotr Arsjinof", "autorite": 10147},
  {"nom": "Pleasure Tendency", "cle": "Pleasure Tendency"},
  {"nom": "Prole.info", "cle": "Prole.info"},
  {"nom": "Queerilla", "cle": "Queerilla"},
  {"nom": "Radicale Criminologen (Leuven)", "cle": "Radicale Criminologen (Leuven)"},
  {"nom": "Raoul Vaneigem", "autorite": 10189},
  {"nom": "Reclus Elisée", "autorite": 1},
  {"nom": "Red Sunshine Gang", "cle": "Red Sunshine Gang"},
  {"nom": "René Berthier", "autorite": 51},
  {"nom": "René Fürth", "autorite": 10628},
  {"nom": "René Gabriëls", "cle": "René Gabriëls"},
  {"nom": "René Johannes Sanders", "cle": "René Johannes Sanders"},
  {"nom": "René Steyaert", "cle": "René Steyaert"},
  {"nom": "Revolutionaire RadenSocialisten (Antwerpen)", "cle": "Revolutionaire RadenSocialisten (Antwerpen)"},
  {"nom": "Riot Squad", "cle": "Riot Squad"},
  {"nom": "Robert Willem Frijn", "cle": "Robert Willem Frijn"},
  {"nom": "Roel Van Duyn", "cle": "Roel van Duyn"},
  {"nom": "Roger Jacobs", "cle": "Roger Jacobs"},
  {"nom": "Romain Rolland", "cle": "Romain Rolland"},
  {"nom": "Rudolf De Jong", "autorite": 10180},
  {"nom": "Rudolf Rocker", "autorite": 10020},
  {"nom": "Ruud Uittenhout", "cle": "Ruud Uittenhout"},
  {"nom": "Rymke Wiersma", "cle": "Rymke Wiersma"},
  {"nom": "Ryner, Han", "autorite": 10101},
  {"nom": "S. M. Petrisjenko", "autorite": 11032},
  {"nom": "S.M. Sheehan", "cle": "S. M. Sheehan"},
  {"nom": "SKAL", "cle": "SKAL (Socio-Kulturele Aktiegroep Leuven)"},
  {"nom": "SKAL (Socio-Kulurele Aktiegroep Leuven)", "cle": "SKAL (Socio-Kulturele Aktiegroep Leuven)"},
  {"nom": "Samar Ranjan Sen", "cle": "Samar Ranjan Sen"},
  {"nom": "Schapiro", "cle": "Alexander Schapiro"},
  {"nom": "Scola Oikonomia", "cle": "Scola Oikonomia"},
  {"nom": "Simon Radius", "cle": "Simon Radius"},
  {"nom": "Simone Weil", "autorite": 11300},
  {"nom": "Situationistische Internationale (leden van de)", "cle": "Situationistische Internationale"},
  {"nom": "Socialistiese Opvoeding", "cle": "Socialistiese Opvoeding"},
  {"nom": "Solidarité Ouvrière", "cle": "Solidarité Ouvrière"},
  {"nom": "Sonali Kolhatkar", "cle": "Sonali Kolhatkar"},
  {"nom": "Spartacusbond NL", "cle": "Spartacusbond NL"},
  {"nom": "Spuigroep", "cle": "Spuigroep"},
  {"nom": "Steven De Batselier", "cle": "Steven De Batselier"},
  {"nom": "Stichting Afval", "cle": "Stichting Afval"},
  {"nom": "Stichting OVERAL (Hans, Kees)", "cle": "Stichting OVERAL"},
  {"nom": "Stijn Vanclooster", "cle": "Stijn Vanclooster"},
  {"nom": "Streetmedics", "cle": "Streetmedics"},
  {"nom": "Stuart Christie", "autorite": 10430},
  {"nom": "Studenten van Straatsburg", "cle": "Studenten van Straatsburg"},
  {"nom": "Sébastien Faure", "autorite": 10049},
  {"nom": "T Barnacle", "cle": "T. Barnacle"},
  {"nom": "T Veenstra", "cle": "T. Veenstra"},
  {"nom": "The Laughing Poets", "cle": "The Laughing Poets"},
  {"nom": "Thom Holterman", "cle": "Thom Holterman"},
  {"nom": "Thomas Meyer-Falk", "cle": "Thomas Meyer-Falk"},
  {"nom": "Tommy Ryan", "cle": "Tommy Ryan"},
  {"nom": "Toni Negri", "cle": "Toni Negri"},
  {"nom": "Torsten Liesegang", "cle": "Torsten Liesegang"},
  {"nom": "Tristan Faes", "cle": "Tristan Faes"},
  {"nom": "Twin Cities IWW Branch", "cle": "Twin Cities IWW Branch"},
  {"nom": "Uitgeverij de Dolle Hond", "cle": "Uitgeverij de Dolle Hond"},
  {"nom": "Upton Sinclair", "cle": "Upton Sinclair"},
  {"nom": "Van den Dungen", "cle": "Van den Dungen"},
  {"nom": "Van der Bruggen G", "cle": "G. Van der Bruggen"},
  {"nom": "Vernon Richards", "autorite": 10148},
  {"nom": "Vervest, P.", "cle": "P. Vervest"},
  {"nom": "Victor Serge", "autorite": 39},
  {"nom": "Voline (aka van Vsevolod Eichenbaum)", "autorite": 10111},
  {"nom": "Voline (aka van Vsevolovod Eichenbaum)", "autorite": 10111},
  {"nom": "Vorming tot bevrijding", "cle": "Vorming tot bevrijding"},
  {"nom": "Vrije Bond", "cle": "Vrije Bond"},
  {"nom": "Vuile Mong en de vieze gasten", "cle": "Vuile Mong en de vieze gasten"},
  {"nom": "W.J. Jong", "cle": "W. J. Jong"},
  {"nom": "Wayne Prize", "cle": "Wayne Price"},
  {"nom": "Wereldscholen", "cle": "Wereldscholen"},
  {"nom": "Werkgroep Alternatieve Ekonomie", "cle": "Werkgroep Alternatieve Ekonomie"},
  {"nom": "Werklozenvakbond Leuven", "cle": "Werklozenvakbond Leuven"},
  {"nom": "Wildgroei", "cle": "Wildgroei"},
  {"nom": "Wilhelm Reich", "autorite": 10188},
  {"nom": "Willi Schlamm", "cle": "Willi Schlamm"},
  {"nom": "Willy Verhoysen", "cle": "Willy Verhoysen"},
  {"nom": "Wolfgang Sternstein", "cle": "Wolfgang Sternstein"},
  {"nom": "Woodcock", "autorite": 10112},
  {"nom": "Workers Solidarity Movement", "cle": "Workers Solidarity Movement"},
  {"nom": "Xavier Bekaert", "cle": "Xavier Bekaert"},
  {"nom": "Zijn Vieze Gasten", "cle": "De Vieze Gasten"},
  {"nom": "de Vries B", "cle": "B. de Vries"},
  {"nom": "Éen-meiGroep", "cle": "Éen-meiGroep"},
  {"nom": "Élisée Reclus", "autorite": 1},
  {"nom": "Émile Chapelier", "cle": "Émile Chapelier"},
  {"nom": "Étienne De la Boétie", "cle": "Étienne de La Boétie"}
 ],
 "texte": [
  "Albin",
  "Anarchisme",
  "Anoniem",
  "Assata",
  "Bandaalse Courant",
  "Barcelone",
  "Boerema",
  "Bonc-Brujevic",
  "Borovoj",
  "Botsing",
  "Bruchard",
  "CNT",
  "Cahiers Pensée et Action N°011 (1959-07 08 09)",
  "Censuur",
  "Clark",
  "Crown",
  "DROIT D'ASILE",
  "De Jong",
  "De Wapens Neder (red)",
  "Dekker",
  "Diego",
  "Emery",
  "Ernestan",
  "Fleischer",
  "Georges-Roux",
  "Ger",
  "Grakra",
  "Hornstra",
  "J/M",
  "Janzen",
  "Macpherson",
  "McKee",
  "Mualdès",
  "Méric",
  "Noordegraaf",
  "Orgaan der Vlaamsche Vrije Groepen VOORWAARTS",
  "PP",
  "PP.",
  "Piron",
  "Pépé",
  "Robben",
  "Rodenko",
  "Tadas/RAF R.",
  "V.A.",
  "VPRO programmatieboekje",
  "Van Overstraeten",
  "Wedman",
  "Yolan",
  "Yonomechupeldedo",
  "Zaccaria"
 ]
}
$liste$::jsonb;
  c_label constant text := 'Anarchief.org · import 2026-10';
  v_reste int;
  v_noms text;
  v_n int;
BEGIN
  SELECT id INTO v_lib FROM public.libraries WHERE slug = 'anarchief-org';
  IF v_lib IS NULL THEN
    RAISE NOTICE 'Anarchief.Org absente (banc) : aucune autorité posée';
    RETURN;
  END IF;

  v_res := private.fn_autorites_par_liste(
    v_lib, v_liste, c_label,
    'Créée depuis les notices d''Anarchief.org (liste fermée du 19/10/2026, décisions D1-D7). '
      || 'À relire : ni dates, ni pays, ni identifiants externes (enrichissement prévu, D7).');

  -- Garde 1 : toute graphie encore non liée sur une notice d'Anarchief est
  -- dans la liste « texte » (rien d'oublié, rien d'inattendu).
  SELECT count(*), string_agg(DISTINCT c.name, ' | ') INTO v_reste, v_noms
    FROM public.book_contributors c
   WHERE c.author_id IS NULL
     AND EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = c.book_id AND h.library_id = v_lib)
     AND c.name NOT IN (SELECT jsonb_array_elements_text(v_liste->'texte'));
  IF v_reste > 0 THEN
    RAISE EXCEPTION 'Anarchief : % ligne(s) non liée(s) hors de la liste « texte » : %', v_reste, left(v_noms, 400);
  END IF;

  -- Garde 2 : autant d'autorités à l'étiquette que d'autorités dans la liste.
  SELECT count(*) INTO v_n FROM public.authors WHERE source_label = c_label;
  IF v_n <> jsonb_array_length(v_liste->'autorites') THEN
    RAISE EXCEPTION 'Anarchief : % autorité(s) à l''étiquette, % attendue(s)', v_n, jsonb_array_length(v_liste->'autorites');
  END IF;

  RAISE NOTICE 'Anarchief : %', v_res;
END
$anarchief_autorites$;
