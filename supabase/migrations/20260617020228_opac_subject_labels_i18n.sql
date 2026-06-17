-- 20260617020228_opac_subject_labels_i18n.sql
-- OPAC / découverte — complète subjects.label_i18n pour les 6 locales en fallback
-- total (it, de, ca, nl, eo, el) et comble les 2 trous fr/es/en (mulheres-anarquistas).
-- Avant : pt-BR 31/31, fr/es/en 29/31, it/de/ca/nl/eo/el 0/31.
-- Après : 30 sujets en parité 10 locales. Le 31e (`pierre-joseph-proudhon`,
--   personne employée comme sujet, libellé mal formé « Pierre-Joseph Proudhon ; »,
--   0 livre) est VOLONTAIREMENT laissé de côté : à SUPPRIMER côté catalogage.
--
-- Données de référence (pas d'objet créé) : ni RLS, ni SECURITY DEFINER ici.
-- Le merge `||` préserve les clés existantes (pt-BR/fr/es/en) et n'ajoute que
-- les locales manquantes → idempotent.
--
-- ⚠️ Termes spécialisés à faire relire par des locuteur·rices natif·ves :
--   - abolicionismo-penal (de/nl/eo/el : terme rare, rendu au plus proche) ;
--   - makhnovtchina (translittérations it/de/ca/nl/eo/el) ;
--   - el (grec) : pas de convention typographique arrêtée — libellés = noms de
--     concepts (non genrés pour la plupart), à valider en communauté.
--
-- Session : Catalogue longue traîne (recherche + fiche auteur)

update subjects s
set label_i18n = s.label_i18n || v.add
from (values
  ('anarquismo',                '{"it":"Anarchismo","de":"Anarchismus","ca":"Anarquisme","nl":"Anarchisme","eo":"Anarkiismo","el":"Αναρχισμός"}'::jsonb),
  ('socialismo',                '{"it":"Socialismo","de":"Sozialismus","ca":"Socialisme","nl":"Socialisme","eo":"Socialismo","el":"Σοσιαλισμός"}'::jsonb),
  ('movimento-operario',        '{"it":"Movimento operaio","de":"Arbeiterbewegung","ca":"Moviment obrer","nl":"Arbeidersbeweging","eo":"Laborista movado","el":"Εργατικό κίνημα"}'::jsonb),
  ('educacao-libertaria',       '{"it":"Educazione libertaria","de":"Libertäre Erziehung","ca":"Educació llibertària","nl":"Libertaire opvoeding","eo":"Libereca edukado","el":"Ελευθεριακή εκπαίδευση"}'::jsonb),
  ('feminismo',                 '{"it":"Femminismo","de":"Feminismus","ca":"Feminisme","nl":"Feminisme","eo":"Feminismo","el":"Φεμινισμός"}'::jsonb),
  ('ecologia-social',           '{"it":"Ecologia sociale","de":"Soziale Ökologie","ca":"Ecologia social","nl":"Sociale ecologie","eo":"Socia ekologio","el":"Κοινωνική οικολογία"}'::jsonb),
  ('antimilitarismo',           '{"it":"Antimilitarismo","de":"Antimilitarismus","ca":"Antimilitarisme","nl":"Antimilitarisme","eo":"Kontraŭmilitarismo","el":"Αντιμιλιταρισμός"}'::jsonb),
  ('antifascismo',              '{"it":"Antifascismo","de":"Antifaschismus","ca":"Antifeixisme","nl":"Antifascisme","eo":"Kontraŭfaŝismo","el":"Αντιφασισμός"}'::jsonb),
  ('acao-direta',               '{"it":"Azione diretta","de":"Direkte Aktion","ca":"Acció directa","nl":"Directe actie","eo":"Rekta agado","el":"Άμεση δράση"}'::jsonb),
  ('anticlericalismo',          '{"it":"Anticlericalismo","de":"Antiklerikalismus","ca":"Anticlericalisme","nl":"Antiklerikalisme","eo":"Kontraŭklerikalismo","el":"Αντικληρικαλισμός"}'::jsonb),
  ('abolicionismo-penal',       '{"it":"Abolizionismo penale","de":"Strafrechtsabolitionismus","ca":"Abolicionisme penal","nl":"Penaal abolitionisme","eo":"Puna aboliciismo","el":"Ποινικός αβολιτιονισμός"}'::jsonb),
  ('questao-agraria',           '{"it":"Questione agraria","de":"Agrarfrage","ca":"Qüestió agrària","nl":"Agrarische kwestie","eo":"Agrara demando","el":"Αγροτικό ζήτημα"}'::jsonb),
  ('historia-anarquismo',       '{"it":"Storia dell''anarchismo","de":"Geschichte des Anarchismus","ca":"Història de l''anarquisme","nl":"Geschiedenis van het anarchisme","eo":"Historio de anarkiismo","el":"Ιστορία του αναρχισμού"}'::jsonb),
  ('biografia',                 '{"it":"Biografia","de":"Biografie","ca":"Biografia","nl":"Biografie","eo":"Biografio","el":"Βιογραφία"}'::jsonb),
  ('contracultura',             '{"it":"Controcultura","de":"Gegenkultur","ca":"Contracultura","nl":"Tegencultuur","eo":"Kontraŭkulturo","el":"Αντικουλτούρα"}'::jsonb),
  ('arte-e-militancia',         '{"it":"Arte e militanza","de":"Kunst und Aktivismus","ca":"Art i militància","nl":"Kunst en activisme","eo":"Arto kaj aktivismo","el":"Τέχνη και ακτιβισμός"}'::jsonb),
  ('anarcossindicalismo',       '{"it":"Anarcosindacalismo","de":"Anarchosyndikalismus","ca":"Anarcosindicalisme","nl":"Anarchosyndicalisme","eo":"Anarkisindikalismo","el":"Αναρχοσυνδικαλισμός"}'::jsonb),
  ('anarcocomunismo',           '{"it":"Anarco-comunismo","de":"Anarchokommunismus","ca":"Anarcocomunisme","nl":"Anarchocommunisme","eo":"Anarkikomunismo","el":"Αναρχοκομμουνισμός"}'::jsonb),
  ('anarcofeminismo',           '{"it":"Anarcofemminismo","de":"Anarcha-Feminismus","ca":"Anarcofeminisme","nl":"Anarchafeminisme","eo":"Anarki-feminismo","el":"Αναρχοφεμινισμός"}'::jsonb),
  ('anarquismo-individualista', '{"it":"Anarchismo individualista","de":"Individualistischer Anarchismus","ca":"Anarquisme individualista","nl":"Individualistisch anarchisme","eo":"Individuisma anarkiismo","el":"Ατομικιστικός αναρχισμός"}'::jsonb),
  ('mutualismo',                '{"it":"Mutualismo","de":"Mutualismus","ca":"Mutualisme","nl":"Mutualisme","eo":"Mutualismo","el":"Μουτουαλισμός"}'::jsonb),
  ('marxismo',                  '{"it":"Marxismo","de":"Marxismus","ca":"Marxisme","nl":"Marxisme","eo":"Marksismo","el":"Μαρξισμός"}'::jsonb),
  ('autogestao',                '{"it":"Autogestione","de":"Selbstverwaltung","ca":"Autogestió","nl":"Zelfbeheer","eo":"Memmastrumado","el":"Αυτοδιαχείριση"}'::jsonb),
  ('sindicalismo',              '{"it":"Sindacalismo","de":"Syndikalismus","ca":"Sindicalisme","nl":"Syndicalisme","eo":"Sindikatismo","el":"Συνδικαλισμός"}'::jsonb),
  ('greve',                     '{"it":"Sciopero","de":"Streik","ca":"Vaga","nl":"Staking","eo":"Striko","el":"Απεργία"}'::jsonb),
  ('revolucao-espanhola',       '{"it":"Rivoluzione spagnola","de":"Spanische Revolution","ca":"Revolució espanyola","nl":"Spaanse Revolutie","eo":"Hispana revolucio","el":"Ισπανική Επανάσταση"}'::jsonb),
  ('comuna-de-paris',           '{"it":"Comune di Parigi","de":"Pariser Kommune","ca":"Comuna de París","nl":"Commune van Parijs","eo":"Pariza Komunumo","el":"Παρισινή Κομμούνα"}'::jsonb),
  ('revolucao-russa',           '{"it":"Rivoluzione russa","de":"Russische Revolution","ca":"Revolució russa","nl":"Russische Revolutie","eo":"Rusia revolucio","el":"Ρωσική Επανάσταση"}'::jsonb),
  ('makhnovtchina',             '{"it":"Makhnovščina","de":"Machnowschtschina","ca":"Makhnovtxina","nl":"Machnovsjtsjina","eo":"Maĥnovŝĉino","el":"Μαχνοβτσίνα"}'::jsonb),
  ('mulheres-anarquistas',      '{"en":"Anarchist women","fr":"Femmes anarchistes","es":"Mujeres anarquistas","it":"Donne anarchiche","de":"Anarchistinnen","ca":"Dones anarquistes","nl":"Anarchistische vrouwen","eo":"Anarkiistinoj","el":"Αναρχικές γυναίκες"}'::jsonb)
) as v(slug, add)
where s.slug = v.slug;
