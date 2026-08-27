-- =========================================================================
-- Paquet PÉRIODIQUES P6 — Reprise des notices de périodiques existantes
-- =========================================================================
-- Date     : 2026-08-27
-- Chantier : périodiques (spec-periodiques v0.1, §8)
-- Auteur   : Xavier (arbitrages) + Claude (rédaction)
--
-- POURQUOI MAINTENANT. Le réseau compte 7 notices `periodico` sur 2 676, dont
-- quatre déjà problématiques. Tant qu'elles ne sont pas rattachées, la règle
-- anti-faux-doublons de P3 ne peut rien pour elles : elle a besoin d'un
-- serial_id commun pour reconnaître deux fascicules d'une même revue. La
-- reprise n'est donc pas du rangement, c'est ce qui met P3 en service sur
-- l'existant.
--
-- ÉTAT CONSTATÉ EN BASE LE 27/08/2026 :
--   · Ação Direta — Boletim da OSL/Pará, nº 01   titulo_periodico = « Ação Direta »
--   · Puxirum — Informativo do NARC / CAB, nº 01 titulo_periodico = « Puxirum »
--   · Verve                                      titulo_periodico vide, ISSN 1676-9090
--   · Encontros com a Civilização brasileira ×4  titulo_periodico vide, ano 1978,
--                                                1978, 1979, 1979, aucun numéro
-- Toutes à la BLMF. (La spec §8 parle de « trois notices sans
-- titulo_periodico » : il y en a cinq — Verve plus les quatre Encontros. Le
-- décompte de la spec était faux, le traitement ne change pas.)
--
-- DEUX RÈGLES, PAS UNE HEURISTIQUE.
--   1. Quand titulo_periodico est rempli, il EST le titre de la revue. C'est
--      littéralement ce que la colonne voulait dire avant P1.
--   2. Quand il est vide, le titre du FASCICULE est le titre de la revue —
--      c'est le cas des notices saisies sans distinguer les deux niveaux, et
--      c'est vérifiable à l'œil sur les cinq concernées.
-- Aucune normalisation, aucun rapprochement approximatif, aucune fusion : on
-- regroupe sur l'égalité STRICTE de la chaîne. Deux graphies différentes
-- produiront deux titres, et c'est l'Atelier qui tranchera (P5) — mieux vaut
-- deux autorités à fusionner qu'un rapprochement fait à la place de quelqu'un.
--
-- LES TITRES NAISSENT « proposto », DONC INVISIBLES DU PUBLIC. Rien ne
-- régresse : les sept notices restent exactement aussi visibles qu'avant dans
-- le catalogue, elles gagnent un lien. C'est seulement la PAGE DE REVUE qui
-- attendra la promotion par l'Atelier. C'est la doctrine de P1 (« aucune
-- autorité ne naît validée ») et elle vaut aussi quand la reprise est faite à
-- la main : sinon la règle ne tient que pour les autres.
--
-- IDEMPOTENT ET SANS EFFET SUR UNE BASE VIDE. Tout est conditionné à
-- serial_id IS NULL et à l'absence d'un titre de même forme exacte. Sur la base
-- de test reconstruite (aucun périodique dans le seed), ce paquet ne fait
-- rigoureusement rien et le dit.
--
-- CE QU'IL NE FAIT PAS : aucune fusion, aucune promotion, aucun arbitrage
-- « pas un doublon ». Les deux paires d'Encontros de même année RESTERONT dans
-- la file de l'Atelier — c'est le résultat voulu (spec §4), elles méritent un
-- œil humain.
--
-- CHECKLIST DOCTRINE
--   [x] Migration de DONNÉES : bornée, idempotente, sans effet si rien à faire
--   [x] Aucune DDL, aucun droit modifié
--   [x] Compte rendu chiffré en NOTICE (une reprise muette est invérifiable)
-- =========================================================================

BEGIN;

DO $reprise$
DECLARE
  v_titre       text;
  v_serial      bigint;
  v_couple      record;
  v_titres      int := 0;
  v_rattaches   int := 0;
  v_issn        int := 0;
  v_etats       int := 0;
  v_restants    int;
BEGIN
  -- ---------------------------------------------------------------------
  -- 1. Règle 1 — le titre de périodique transcrit devient une autorité.
  -- ---------------------------------------------------------------------
  FOR v_titre IN
    SELECT DISTINCT btrim(b.titulo_periodico)
    FROM public.books b
    WHERE b.serial_id IS NULL
      AND b.tipo_material = 'periodico'
      AND nullif(btrim(coalesce(b.titulo_periodico, '')), '') IS NOT NULL
    ORDER BY 1
  LOOP
    SELECT id INTO v_serial FROM public.serials WHERE uniform_title = v_titre;
    IF v_serial IS NULL THEN
      -- Ni slug ni statut : l'autoslug et le défaut 'proposto' de P1 font foi.
      INSERT INTO public.serials (uniform_title) VALUES (v_titre) RETURNING id INTO v_serial;
      v_titres := v_titres + 1;
    END IF;

    UPDATE public.books
       SET serial_id = v_serial
     WHERE serial_id IS NULL
       AND tipo_material = 'periodico'
       AND btrim(coalesce(titulo_periodico, '')) = v_titre;
    GET DIAGNOSTICS v_restants = ROW_COUNT;
    v_rattaches := v_rattaches + v_restants;
  END LOOP;

  -- ---------------------------------------------------------------------
  -- 2. Règle 2 — sans titre transcrit, le titre du fascicule est celui de la
  --    revue. Cas des cinq notices Verve et Encontros.
  -- ---------------------------------------------------------------------
  FOR v_titre IN
    SELECT DISTINCT btrim(b.titulo)
    FROM public.books b
    WHERE b.serial_id IS NULL
      AND b.tipo_material = 'periodico'
      AND nullif(btrim(coalesce(b.titulo_periodico, '')), '') IS NULL
      AND nullif(btrim(coalesce(b.titulo, '')), '') IS NOT NULL
    ORDER BY 1
  LOOP
    SELECT id INTO v_serial FROM public.serials WHERE uniform_title = v_titre;
    IF v_serial IS NULL THEN
      INSERT INTO public.serials (uniform_title) VALUES (v_titre) RETURNING id INTO v_serial;
      v_titres := v_titres + 1;
    END IF;

    UPDATE public.books
       SET serial_id = v_serial
     WHERE serial_id IS NULL
       AND tipo_material = 'periodico'
       AND nullif(btrim(coalesce(titulo_periodico, '')), '') IS NULL
       AND btrim(coalesce(titulo, '')) = v_titre;
    GET DIAGNOSTICS v_restants = ROW_COUNT;
    v_rattaches := v_rattaches + v_restants;
  END LOOP;

  -- ---------------------------------------------------------------------
  -- 3. Reporter l'ISSN du fascicule sur le titre — mais SEULEMENT si tous les
  --    fascicules rattachés s'accordent. Un ISSN est un identifiant de REVUE :
  --    le trouver sur un fascicule est une information sur la revue. En
  --    revanche, deux ISSN divergents sous un même titre signalent un problème
  --    (deux supports, ou une erreur de saisie) qu'il ne faut pas trancher ici.
  --    Cas réel : Verve porte 1676-9090.
  -- ---------------------------------------------------------------------
  UPDATE public.serials s
     SET issn = q.issn, updated_at = now()
    FROM (
      SELECT b.serial_id, min(nullif(btrim(b.issn), '')) AS issn
      FROM public.books b
      WHERE b.serial_id IS NOT NULL
        AND nullif(btrim(coalesce(b.issn, '')), '') IS NOT NULL
      GROUP BY b.serial_id
      HAVING count(DISTINCT nullif(btrim(b.issn), '')) = 1
    ) q
   WHERE s.id = q.serial_id AND s.issn IS NULL;
  GET DIAGNOSTICS v_issn = ROW_COUNT;

  -- ---------------------------------------------------------------------
  -- 4. Poser l'état de collection CALCULÉ de chaque couple (revue,
  --    bibliothèque). Aucun `statement` n'est inventé : ce que ces
  --    bibliothèques DÉCLARENT posséder, elles seules peuvent l'écrire.
  -- ---------------------------------------------------------------------
  FOR v_couple IN
    SELECT DISTINCT b.serial_id, h.library_id
    FROM public.books b
    JOIN public.book_holdings h ON h.book_id = b.id
    WHERE b.serial_id IS NOT NULL
  LOOP
    PERFORM public.fn_recompute_serial_holdings(v_couple.serial_id, v_couple.library_id);
    v_etats := v_etats + 1;
  END LOOP;

  -- ---------------------------------------------------------------------
  -- 5. Compte rendu. Une reprise muette est une reprise invérifiable.
  -- ---------------------------------------------------------------------
  SELECT count(*) INTO v_restants
  FROM public.books
  WHERE tipo_material = 'periodico' AND serial_id IS NULL;

  IF v_titres = 0 AND v_rattaches = 0 THEN
    RAISE NOTICE 'Paquet PÉRIODIQUES P6 : aucun périodique à reprendre (base de test ou reprise déjà faite).';
  ELSE
    RAISE NOTICE 'Paquet PÉRIODIQUES P6 : % titre(s) créé(s), % fascicule(s) rattaché(s), % ISSN reporté(s), % état(s) de collection calculé(s).',
      v_titres, v_rattaches, v_issn, v_etats;
  END IF;

  IF v_restants > 0 THEN
    -- Ne PAS lever : un périodique sans titre ni titre transcrit est une notice
    -- à corriger à la main, pas une raison de refuser le déploiement.
    RAISE WARNING 'Paquet PÉRIODIQUES P6 : % notice(s) periodico restent sans titre de revue (ni titulo_periodico ni titulo). À reprendre au catalogage.',
      v_restants;
  END IF;
END $reprise$;

COMMIT;

-- =========================================================================
-- APRÈS DÉPLOIEMENT — ce qui reste à faire à la main, et qui ne peut pas
-- l'être ici :
--
--   1. PROMOUVOIR les titres dans l'Atelier (proposto -> ativo), sans quoi
--      aucune page de revue n'est publique. Rien d'autre ne régresse : les
--      notices restent visibles au catalogue comme avant.
--   2. RENSEIGNER l'état de collection DÉCLARÉ (api.fn_serial_upsert_holdings).
--      Seule la bibliothèque sait dire « 1896-1914, lacunes : n°23, 1902 » ;
--      le calcul posé ici ne dit que ce qui est catalogué.
--   3. NE PAS attendre de changement dans la file de doublons. La spec §8.4
--      demandait de « vérifier que les paires Encontros se comportent comme
--      prévu en §4 » ; vérification faite en base, les quatre notices partagent
--      work_id = 15 et la règle préexistante « même œuvre » les écarte DÉJÀ.
--      Elles ne sont pas dans la file avant ce paquet et n'y seront pas après.
--      La règle de P3 se mesure sur des notices d'œuvres distinctes — soit tout
--      ce qui arrivera par import.
--
-- Rollback ciblé (détache sans rien détruire d'autre) :
--   BEGIN;
--     UPDATE public.books SET serial_id = NULL WHERE tipo_material = 'periodico';
--     DELETE FROM public.serials s WHERE NOT EXISTS
--       (SELECT 1 FROM public.books b WHERE b.serial_id = s.id);
--   COMMIT;
-- =========================================================================
