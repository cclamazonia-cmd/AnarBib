-- =====================================================================
-- AnarBib -- La disponibilite dit sa formule
-- Date    : 2026-08-31  ·  spec-flux-emprunts §11.1 (1)
--
-- POURQUOI CETTE MIGRATION N'AJOUTE QUE DES COMMENTAIRES.
--
-- Le 31/08, en verifiant le premier emprunt reel du reseau, la meme personne
-- s'est trompee TROIS FOIS EN UNE HEURE sur `available_count`, toujours de la
-- meme facon : en mesurant avec sa propre definition au lieu de celle du
-- produit.
--
--   1. Jointure de `emprestimo_itens_v2.item_id` sur `book_holdings` -- alors
--      qu'il designe un `exemplares.id`. Conclusion : « available_count faux ».
--      Faux.
--   2. Conclusion suivante : « item_id pointe le mauvais livre dans 6 cas sur
--      6 ». Faux aussi -- le modele est a DEUX NIVEAUX, `holding_id` est le
--      fonds, `item_id` la copie physique, et les six lignes sont coherentes.
--   3. Balayage des 2 709 exemplaires avec la formule « total moins emprunts
--      ouverts ». Un ecart trouve, declare « livre absent du catalogue que
--      personne n'a ». Faux encore : il etait sorti en PRET INTERBIBLIOTHEQUES,
--      terme que la formule ignorait.
--
-- Aucune de ces erreurs n'aurait survecu a une phrase ecrite quelque part. La
-- formule reelle vit uniquement dans le corps de
-- `fn_v2_recompute_holdings_availability`, cent lignes de CTE : on ne peut pas
-- l'enoncer sans la lire, donc chacun la reinvente, donc chacun la reinvente
-- FAUSSE. C'est un cout paye trois fois en une heure par quelqu'un qui avait
-- pourtant la base sous les yeux.
--
-- Un commentaire de colonne n'est pas de la decoration : c'est le seul endroit
-- ou une definition se trouve sans etre cherchee.
-- =====================================================================

BEGIN;

COMMENT ON COLUMN public.book_holdings.available_count IS
  'Nombre d''exemplaires REELLEMENT empruntables maintenant. Calcule par '
  'public.fn_v2_recompute_holdings_availability, et QUATRE termes le composent : '
  'exemplaires du fonds dont visibility = ''public'' '
  'MOINS les emprunts ouverts (emprestimo_itens_v2.item_status = ''aberto'') '
  'MOINS les reservations actives (reserva_linhas_v2.item_status = ''ativa'') '
  'MOINS les prets interbibliotheques sortis (interlibrary_loan_items_v2.item_status '
  'IN (''reservado_para_saida'',''emprestado'')). '
  'Oublier l''un des deux derniers termes fait conclure a tort qu''un exemplaire est '
  '« perdu » : c''est arrive trois fois le 31/08/2026, sur le premier emprunt reel du '
  'reseau. Invariant spec-flux-emprunts §11.1 (1).';

COMMENT ON COLUMN public.book_holdings.exemplares_total IS
  'Nombre d''exemplaires du fonds VISIBLES publiquement (exemplares.visibility = '
  '''public''), recalcule par fn_v2_recompute_holdings_availability. Ce n''est donc '
  'pas le nombre de lignes de `exemplares` : un exemplaire masque n''y figure pas.';

COMMENT ON COLUMN public.emprestimo_itens_v2.item_id IS
  'Reference l''EXEMPLAIRE PHYSIQUE emprunte : public.exemplares(id). '
  'A ne pas confondre avec `holding_id`, qui reference le FONDS -- « ce livre dans '
  'cette bibliotheque », public.book_holdings(id). Le modele est a deux niveaux et '
  'les deux colonnes sont normales : l''exemplaire appartient au fonds. Joindre '
  '`item_id` sur `book_holdings` produit des rapprochements qui ont l''air justes '
  'et ne le sont pas (vecu le 31/08/2026).';

COMMENT ON COLUMN public.emprestimo_itens_v2.holding_id IS
  'Reference le FONDS emprunte : public.book_holdings(id) -- « ce livre dans cette '
  'bibliotheque ». C''est la colonne que lit le recalcul de disponibilite. '
  'L''exemplaire physique, lui, est en `item_id`.';

-- ---------------------------------------------------------------------
-- Verification -- les quatre commentaires sont bien poses
-- ---------------------------------------------------------------------
DO $$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n
    FROM pg_description d
    JOIN pg_class c ON c.oid = d.objoid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = d.objsubid
   WHERE n.nspname = 'public'
     AND (c.relname, a.attname) IN (
       ('book_holdings','available_count'), ('book_holdings','exemplares_total'),
       ('emprestimo_itens_v2','item_id'),   ('emprestimo_itens_v2','holding_id'));
  IF v_n <> 4 THEN
    RAISE EXCEPTION 'ECHEC : % commentaire(s) au lieu de 4', v_n;
  END IF;
  RAISE NOTICE 'OK : la formule de la disponibilite et les deux niveaux du modele sont ecrits la ou on les cherche.';
END $$;

COMMIT;
