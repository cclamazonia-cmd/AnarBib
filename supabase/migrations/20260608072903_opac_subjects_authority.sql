-- ════════════════════════════════════════════════════════════════════════════
-- OPAC étape 2 — Autorité MATIÈRE (thésaurus de sujets) — Paquet 1 : modèle
-- Auteur  : Claude (Opus)
-- Session : Etape 2 autorite matiere (P1 modele)
-- Date    : 2026-06-08 (UTC)
-- Registre: OPAC-ATL1 (autorité matière, chaînée après v1 OPAC)
--
-- Décisions de cadrage (08/06) : libellés en jsonb label_i18n ; thésaurus
-- HIÉRARCHIQUE (parent_id) ; graine curée + catalogage ; construction étagée
-- (ce paquet = modèle ; UI catalogage = P2 ; nuages #OPAC8/#AUT2 = P3).
--
-- Écritures réservées au staff via RPC (P2, DOC-RPC-3) : ici, lecture publique
-- seulement (typeahead + nuages). Tables en RLS, GRANT SELECT anon/authenticated.
-- ════════════════════════════════════════════════════════════════════════════

-- ── Autorité matière (thésaurus) ────────────────────────────────────────────
CREATE TABLE public.subjects (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  slug        text NOT NULL UNIQUE,
  label_i18n  jsonb NOT NULL DEFAULT '{}'::jsonb,   -- {locale: libellé} ; fallback pt-BR
  parent_id   bigint REFERENCES public.subjects(id) ON DELETE SET NULL, -- terme générique
  scope_note  text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  created_by  uuid,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  updated_by  uuid
);
CREATE INDEX subjects_parent_idx ON public.subjects(parent_id);
CREATE INDEX subjects_label_i18n_gin ON public.subjects USING gin (label_i18n);

ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
CREATE POLICY subjects_select_public ON public.subjects
  FOR SELECT TO anon, authenticated USING (true);
GRANT SELECT ON public.subjects TO anon, authenticated;

CREATE TRIGGER trg_subjects_touch_updated_at
  BEFORE UPDATE ON public.subjects
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- ── Lien notice ↔ sujet (publié) ────────────────────────────────────────────
CREATE TABLE public.book_subjects (
  book_id     bigint NOT NULL REFERENCES public.books(id) ON DELETE CASCADE,
  subject_id  bigint NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
  ord         int NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (book_id, subject_id)
);
CREATE INDEX book_subjects_subject_idx ON public.book_subjects(subject_id);

ALTER TABLE public.book_subjects ENABLE ROW LEVEL SECURITY;
CREATE POLICY book_subjects_select_public ON public.book_subjects
  FOR SELECT TO anon, authenticated USING (true);
GRANT SELECT ON public.book_subjects TO anon, authenticated;

-- ── Graine curée (thésaurus anarchiste) ─────────────────────────────────────
-- Libellés pt-BR / fr / es / en (les autres locales retomberont sur pt-BR à
-- l'affichage ; elles seront complétées au fil du catalogage / de l'Atelier).
INSERT INTO public.subjects (slug, label_i18n) VALUES
  ('anarquismo', jsonb_build_object('pt-BR','Anarquismo','fr','Anarchisme','es','Anarquismo','en','Anarchism')),
  ('socialismo', jsonb_build_object('pt-BR','Socialismo','fr','Socialisme','es','Socialismo','en','Socialism')),
  ('movimento-operario', jsonb_build_object('pt-BR','Movimento operário','fr','Mouvement ouvrier','es','Movimiento obrero','en','Labour movement')),
  ('educacao-libertaria', jsonb_build_object('pt-BR','Educação libertária','fr','Éducation libertaire','es','Educación libertaria','en','Libertarian education')),
  ('feminismo', jsonb_build_object('pt-BR','Feminismo','fr','Féminisme','es','Feminismo','en','Feminism')),
  ('ecologia-social', jsonb_build_object('pt-BR','Ecologia social','fr','Écologie sociale','es','Ecología social','en','Social ecology')),
  ('antimilitarismo', jsonb_build_object('pt-BR','Antimilitarismo','fr','Antimilitarisme','es','Antimilitarismo','en','Antimilitarism')),
  ('antifascismo', jsonb_build_object('pt-BR','Antifascismo','fr','Antifascisme','es','Antifascismo','en','Antifascism')),
  ('acao-direta', jsonb_build_object('pt-BR','Ação direta','fr','Action directe','es','Acción directa','en','Direct action')),
  ('anticlericalismo', jsonb_build_object('pt-BR','Anticlericalismo','fr','Anticléricalisme','es','Anticlericalismo','en','Anticlericalism')),
  ('abolicionismo-penal', jsonb_build_object('pt-BR','Abolicionismo penal','fr','Abolitionnisme pénal','es','Abolicionismo penal','en','Penal abolitionism')),
  ('questao-agraria', jsonb_build_object('pt-BR','Questão agrária','fr','Question agraire','es','Cuestión agraria','en','Land question')),
  ('historia-anarquismo', jsonb_build_object('pt-BR','História do anarquismo','fr','Histoire de l''anarchisme','es','Historia del anarquismo','en','History of anarchism')),
  ('biografia', jsonb_build_object('pt-BR','Biografia','fr','Biographie','es','Biografía','en','Biography')),
  ('contracultura', jsonb_build_object('pt-BR','Contracultura','fr','Contre-culture','es','Contracultura','en','Counterculture')),
  ('arte-e-militancia', jsonb_build_object('pt-BR','Arte e militância','fr','Art et militantisme','es','Arte y militancia','en','Art and activism')),
  ('anarcossindicalismo', jsonb_build_object('pt-BR','Anarcossindicalismo','fr','Anarchosyndicalisme','es','Anarcosindicalismo','en','Anarcho-syndicalism')),
  ('anarcocomunismo', jsonb_build_object('pt-BR','Anarcocomunismo','fr','Communisme libertaire','es','Anarcocomunismo','en','Anarcho-communism')),
  ('anarcofeminismo', jsonb_build_object('pt-BR','Anarcofeminismo','fr','Anarcha-féminisme','es','Anarcofeminismo','en','Anarcha-feminism')),
  ('anarquismo-individualista', jsonb_build_object('pt-BR','Anarquismo individualista','fr','Anarchisme individualiste','es','Anarquismo individualista','en','Individualist anarchism')),
  ('mutualismo', jsonb_build_object('pt-BR','Mutualismo','fr','Mutuellisme','es','Mutualismo','en','Mutualism')),
  ('marxismo', jsonb_build_object('pt-BR','Marxismo','fr','Marxisme','es','Marxismo','en','Marxism')),
  ('autogestao', jsonb_build_object('pt-BR','Autogestão','fr','Autogestion','es','Autogestión','en','Self-management')),
  ('sindicalismo', jsonb_build_object('pt-BR','Sindicalismo','fr','Syndicalisme','es','Sindicalismo','en','Trade unionism')),
  ('greve', jsonb_build_object('pt-BR','Greve','fr','Grève','es','Huelga','en','Strike')),
  ('revolucao-espanhola', jsonb_build_object('pt-BR','Revolução Espanhola','fr','Révolution espagnole','es','Revolución española','en','Spanish Revolution')),
  ('comuna-de-paris', jsonb_build_object('pt-BR','Comuna de Paris','fr','Commune de Paris','es','Comuna de París','en','Paris Commune')),
  ('revolucao-russa', jsonb_build_object('pt-BR','Revolução Russa','fr','Révolution russe','es','Revolución rusa','en','Russian Revolution')),
  ('makhnovtchina', jsonb_build_object('pt-BR','Makhnovtchina','fr','Makhnovtchina','es','Majnovshchina','en','Makhnovshchina'));

-- Hiérarchie (terme spécifique -> terme générique)
UPDATE public.subjects c SET parent_id = p.id
FROM public.subjects p
WHERE p.slug = CASE c.slug
  WHEN 'anarcossindicalismo'        THEN 'anarquismo'
  WHEN 'anarcocomunismo'            THEN 'anarquismo'
  WHEN 'anarcofeminismo'            THEN 'anarquismo'
  WHEN 'anarquismo-individualista'  THEN 'anarquismo'
  WHEN 'mutualismo'                 THEN 'anarquismo'
  WHEN 'marxismo'                   THEN 'socialismo'
  WHEN 'autogestao'                 THEN 'socialismo'
  WHEN 'sindicalismo'               THEN 'movimento-operario'
  WHEN 'greve'                      THEN 'movimento-operario'
  WHEN 'revolucao-espanhola'        THEN 'historia-anarquismo'
  WHEN 'comuna-de-paris'            THEN 'historia-anarquismo'
  WHEN 'revolucao-russa'            THEN 'historia-anarquismo'
  WHEN 'makhnovtchina'              THEN 'historia-anarquismo'
  ELSE NULL END;
