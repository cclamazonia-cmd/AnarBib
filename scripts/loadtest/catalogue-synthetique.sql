-- =====================================================================
-- catalogue-synthetique.sql — un catalogue synthétique pour mesurer à grande
-- échelle (B32, B33 ; 27-28/09/2026).
--
-- ⚠ BANC LOCAL SEULEMENT, dans une base JETABLE clonée du banc SQL
--   (scripts/ci/run-sql-suites.sh). JAMAIS en production : il écrit des
--   dizaines de milliers d'autorités, de notices et de fonds.
--
-- Fabrique : des autorités (noms et formes de tri réalistes, 15 % sans forme
-- de tri) ; leurs alias, aux formes relevées en production le 27/09
-- (manual, canonical_*, catalog_seed_*, variant) ; des éditeurs ; des notices
-- (titres de 2 à 6 mots en sept langues, une édition sur cinq rattachée à
-- l'œuvre d'une autre) et leurs contributeurs (book_authors en dérive) ; des
-- fonds répartis entre la bibliothèque publique du seed (blmf-test) et quatre
-- bibliothèques créées ici, une par branche de fn_library_visible_to_caller :
-- publique, réseau, privée, isolée. Rafraîchit les deux vues matérialisées.
--
-- usage :
--   psql -d postgres -c "CREATE DATABASE anarbib_perf TEMPLATE anarbib_test"
--   psql -d anarbib_perf -v n_auteurs=50000 -v n_notices=100000 -v n_editeurs=10000 \
--        -f scripts/loadtest/catalogue-synthetique.sql
-- Compter une bonne demi-heure pour 100 000 notices (34 min le 28/09/2026, sur
-- ce poste) : chacune traverse ses déclencheurs (œuvre, titres, expression,
-- contexte catalogue, éditeur), et les déclencheurs AFTER s'exécutent en fin
-- d'instruction, un par notice.
-- =====================================================================
\set ON_ERROR_STOP on
-- Le banc local (base construite par les migrations) n'accorde pas USAGE sur le
-- schéma extensions à anon/authenticated ; la production, si (ACL Supabase).
-- Sans lui, la recherche « q » de catalog_works_v1 lève 42501 sous anon : on
-- s'aligne sur la production. Base jetable, donc sans conséquence.
GRANT USAGE ON SCHEMA extensions TO anon, authenticated;
SELECT setseed(0.33);

CREATE TEMP TABLE _l AS SELECT
  ARRAY['Ana','Élisée','José','Maria','Luísa','Piotr','Emma','Errico','Mikhail','Voltairine','Ricardo','Lucía','Federica',
        'Buenaventura','Louise','Émile','Pierre-Joseph','Rudolf','Nestor','Gustav','Camillo','Luigi','Francisco','Isabel',
        'Teresa','Joana','João','Antônio','Neno','Edgard','Domingos','Oreste','Juana','Hélène','Séverine','Madeleine','Jean',
        'Jacques','Paulo','Beatriz','Clara','Rosa','Carmen','Dolores','Salvador','Alejandro','Diego','Manuel','Fernando','Kurt',
        'Otto','Max','Erich','Gustavo','Renata','Lídia','Maurício','Florentino','Anselmo','Angelina','Ettore','Leda','Virginia',
        'Elena','Andrés','Camila','Isadora','Maximiliano','Octavio','Valentina','Victor','Sophie','Nadia','Olga','Boris','Ivan',
        'Natalia','Ekaterina','Yuri','Sacha','Dmitri','Sonia','Eugène','Honorine','Ignacio','Joaquín','Pilar','Soledad',
        'Mercedes','Jules','Marius','Albert','Gaston','Hortense','Nathalie','Zoé','Raúl','Inês','Conceição']::text[] AS pr,
  ARRAY['Reclus','Kropotkin','Goldman','Malatesta','Bakunin','de Cleyre','Flores Magón','Durruti','Michel','Proudhon',
        'Rocker','Makhno','Landauer','Berneri','Fabbri','Ferrer','Montseny','Ascaso','Lima','Oiticica','Leuenroth','Crispim',
        'Gattai','Mella','Nettlau','Grave','Faure','Armand','Libertad','Pouget','Pelloutier','Guillaume','Cafiero','Merlino',
        'Galleani','Sacco','Vanzetti','Berkman','Parsons','Most','Stirner','Tolstoï','Tucker','Spooner','Voline','Arshinov',
        'Mühsam','Toller','Souchy','Leval','Peirats','Abad de Santillán','Mintz','Rüdiger','Colombo','Bonanno','Lorulot',
        'Duval','Pini','Darien','Mirbeau','Descaves','Barrué','Lapeyre','Joyeux','Ferrua','Serge','Brupbacher','Weil','Ibáñez',
        'Pestaña','Peiró','Urales','Sagra','Ortiz','Mera','Sánchez Saornil','Martínez','González','Fernández','Rodríguez',
        'López','Pérez','García','Gómez','Díaz','Silva','Santos','Oliveira','Souza','Costa','Pereira','Almeida','Ferreira',
        'Carvalho','Gomes','Ribeiro','Martins','Araújo','Barbosa','Rocha','Dias','Nascimento','Andrade','Moreira','Nunes',
        'Marques','Machado','Mendes','Freitas','Cardoso','Ramos','Gonçalves','Teixeira','Correia','Vieira','Monteiro',
        'Cavalcanti','Pinto','Moura','Lopes','Batista','Castro','Campos','Fonseca','Borges','Cunha','Sampaio','Coelho','Reis',
        'Magalhães','Brandão','Siqueira','Queiroz','Bezerra','Leite','Aguiar','Figueiredo','Tavares','Farias','Vasconcelos',
        'Pacheco','Duarte','Rezende','Macedo','Viana','Toledo','Camargo','Prado','Barros','Guimarães','Paiva','Sales','Matos',
        'Pires','Brito','Xavier','Neves','Amaral','Bastos','Medeiros','Serrano','Valente','Lacerda','Peixoto','Morais','Assis',
        'Bueno','Cruz','Franco','Lobo','Luz','Mota','Rangel','Sá','Valadares','Werneck']::text[] AS no,
  ARRAY['anarquia','liberdade','revolução','trabalho','história','mulheres','sindicato','comuna','greve','memória',
        'educação','escola','moderna','terra','pão','conquista','ajuda','mútua','estado','autoridade','deus','igreja',
        'anarquismo','comunismo','libertário','libertária','federação','operária','operário','imprensa','jornal','cartas',
        'diário','prisão','exílio','cidade','campo','camponeses','revolta','insurreição','barricada','bandeira','negra',
        'vermelha','manifesto','programa','crítica','economia','política','filosofia','ética','amor','livre','feminismo',
        'sexualidade','corpo','saúde','natureza','geografia','homem','sociedade','humanidade','progresso','ciência','arte',
        'literatura','poesia','teatro','música','canções','contos','romance','ensaios','estudos','textos','escritos','obras',
        'completas','antologia','biografia','vida','morte','luta','lutas','resistência','memórias','crônica','viagem',
        'américa','brasil','espanha','frança','itália','rússia','argentina','uruguai','méxico','portugal','catalunha',
        'paris','barcelona','kronstadt','ucrânia','coluna','milícias','coletividades','aragão','outubro','1936','1917','1871',
        'século','anarchie','liberté','révolution','travail','histoire','femmes','syndicat','commune','grève','mémoire',
        'éducation','école','entraide','état','anarchisme','fédération','ouvrière','exil','révolte','drapeau','noir','critique',
        'économie','philosophie','amour','libre','société','humanité','science','poésie','chansons','lutte','voyage',
        'anarquía','libertad','revolución','trabajo','historia','mujeres','memoria','educación','tierra','apoyo','mutuo',
        'federación','obrera','cárcel','exilio','revuelta','economía','filosofía','naturaleza','sociedad','ciencia','lucha',
        'da','de','do','dos','das','e','o','a','os','as','em','para','la','le','les','el','los','y','et']::text[] AS vo;

-- ── 1. Autorités (15 % sans forme de tri) ──
CREATE TEMP TABLE _a (id bigint, preferred_name text, sort_name text, r real);
WITH x AS (
  SELECT l.pr[1 + floor(random() * array_length(l.pr, 1))::int] AS p,
         l.no[1 + floor(random() * array_length(l.no, 1))::int] AS n,
         random() AS r
    FROM _l l, generate_series(1, :n_auteurs)
), ins AS (
  INSERT INTO public.authors (preferred_name, sort_name, authority_type)
  SELECT p || ' ' || n, CASE WHEN r < 0.15 THEN NULL ELSE n || ', ' || p END, 'person' FROM x
  RETURNING id, preferred_name, sort_name
)
INSERT INTO _a SELECT id, preferred_name, sort_name, random() FROM ins;

-- ── 2. Alias, aux formes relevées en production le 27/09 ──
INSERT INTO public.author_name_aliases (author_id, alias_text, alias_norm, match_kind, is_active)
SELECT id, preferred_name, public.f_normalize_search(preferred_name),
       CASE WHEN r < 0.7 THEN 'manual' ELSE 'canonical_preferred_name' END, true FROM _a
UNION ALL
SELECT id, sort_name, public.f_normalize_search(sort_name),
       CASE WHEN r < 0.2 THEN 'catalog_seed_sort_name' ELSE 'canonical_sort_name' END, true
  FROM _a WHERE sort_name IS NOT NULL AND r < 0.4
UNION ALL
SELECT id, left(preferred_name, 1) || '. ' || split_part(preferred_name, ' ', 2),
       public.f_normalize_search(left(preferred_name, 1) || '. ' || split_part(preferred_name, ' ', 2)),
       'variant', r < 0.09 FROM _a WHERE r < 0.1
ON CONFLICT DO NOTHING;

-- ── 3. Éditeurs ──
INSERT INTO public.publishers (name)
SELECT 'Editora ' || initcap(l.vo[1 + floor(random() * 150)::int]) || ' ' || initcap(l.vo[1 + floor(random() * 150)::int]) || ' ' || g
  FROM _l l, generate_series(1, :n_editeurs) g;

-- ── 4. Notices : titre de 2 à 6 mots, un ou deux auteurs, un éditeur connu une fois sur deux ──
CREATE TEMP TABLE _an AS SELECT row_number() OVER (ORDER BY id) AS rn, id, preferred_name, sort_name FROM _a;
CREATE UNIQUE INDEX ON _an (rn);
CREATE TEMP TABLE _en AS SELECT row_number() OVER (ORDER BY id) AS rn, name FROM public.publishers;
CREATE UNIQUE INDEX ON _en (rn);
ANALYZE _an; ANALYZE _en;

CREATE TEMP TABLE _choix AS
SELECT g,
       1 + floor(random() * (SELECT count(*) FROM _an))::int AS r1,
       CASE WHEN random() < 0.3 THEN 1 + floor(random() * (SELECT count(*) FROM _an))::int END AS r2,
       CASE WHEN random() < 0.5 THEN 1 + floor(random() * (SELECT count(*) FROM _en))::int END AS re,
       t.titre
  FROM generate_series(1, :n_notices) g
  CROSS JOIN LATERAL (
    SELECT string_agg(l.vo[1 + floor(random() * array_length(l.vo, 1))::int], ' ') AS titre
      FROM _l l, generate_series(1, 2 + (g % 5))
  ) t;

CREATE TEMP TABLE _src AS
SELECT c.g, a1.id AS a1, a2.id AS a2,
       upper(left(c.titre, 1)) || substr(c.titre, 2) AS titulo,
       coalesce(a1.sort_name, a1.preferred_name) AS autor,
       coalesce(e.name, 'Edições ' || initcap(split_part(c.titre, ' ', 1))) AS editora,
       'SYN-' || lpad(c.g::text, 6, '0') AS bib_ref
  FROM _choix c
  JOIN _an a1 ON a1.rn = c.r1
  LEFT JOIN _an a2 ON a2.rn = c.r2
  LEFT JOIN _en e ON e.rn = c.re;

-- ── 4 bis. Bibliothèques : la publique du seed (blmf-test) et quatre autres,
--    une par branche de fn_library_visible_to_caller ──
INSERT INTO public.libraries (id, slug, name, visibility_level, catalog_mode, network_mode, is_active)
VALUES ('b32b32b3-0000-4000-8000-0000000000a1', 'perf-publica', 'Perf pública', 'public', 'network_published', 'federated', true),
       ('b32b32b3-0000-4000-8000-0000000000a2', 'perf-rede', 'Perf rede', 'network', 'network_published', 'federated', true),
       ('b32b32b3-0000-4000-8000-0000000000a3', 'perf-privada', 'Perf privada', 'private', 'network_published', 'federated', true),
       ('b32b32b3-0000-4000-8000-0000000000a4', 'perf-isolada', 'Perf isolada', 'public', 'local_only', 'isolated', true)
ON CONFLICT (id) DO NOTHING;

-- Une édition sur cinq rejoint l'œuvre d'une notice précédente (le catalogue
-- par œuvre regroupe alors plusieurs éditions).
CREATE TEMP TABLE _b (id bigint, a1 bigint, a2 bigint, g int);
WITH ins AS (
  INSERT INTO public.books (titulo, autor, editora, ano, tipo_material, bib_ref, idioma)
  SELECT titulo, autor, editora, (1850 + (g * 7) % 170)::text, 'livro', bib_ref,
         (ARRAY['pt-BR', 'pt-BR', 'pt-BR', 'es', 'fr', 'en', 'it'])[1 + g % 7]
    FROM _src ORDER BY g
  RETURNING id, bib_ref
)
INSERT INTO _b SELECT i.id, s.a1, s.a2, s.g FROM ins i JOIN _src s ON s.bib_ref = i.bib_ref;
CREATE INDEX ON _b (g);
UPDATE public.books b SET work_id = p.work_id
  FROM _b x JOIN _b y ON y.g = x.g - 1 JOIN public.books p ON p.id = y.id
 WHERE b.id = x.id AND x.g % 5 = 0;

-- ── 5. Contributeurs (book_authors en dérive) ──
INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
SELECT b.id, b.a1, 1, a.preferred_name, 'autor', true FROM _b b JOIN _a a ON a.id = b.a1
UNION ALL
SELECT b.id, b.a2, 2, a.preferred_name, 'autor', false FROM _b b JOIN _a a ON a.id = b.a2
 WHERE b.a2 IS NOT NULL AND b.a2 <> b.a1;

-- ── 6. Fonds : 55 % publique du seed, 15 % seconde publique, 15 % réseau,
--    8 % privée, 2 % isolée, 5 % dans deux bibliothèques (publique + réseau) ──
INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)
SELECT b.id,
       CASE WHEN b.g % 100 < 55 THEN (SELECT id FROM public.libraries WHERE slug = 'blmf-test')
            WHEN b.g % 100 < 70 THEN 'b32b32b3-0000-4000-8000-0000000000a1'::uuid
            WHEN b.g % 100 < 85 THEN 'b32b32b3-0000-4000-8000-0000000000a2'::uuid
            WHEN b.g % 100 < 93 THEN 'b32b32b3-0000-4000-8000-0000000000a3'::uuid
            WHEN b.g % 100 < 95 THEN 'b32b32b3-0000-4000-8000-0000000000a4'::uuid
            ELSE (SELECT id FROM public.libraries WHERE slug = 'blmf-test') END,
       b.g % 4 <> 0, 1 + b.g % 3, (b.g % 3)
  FROM _b b
UNION ALL
SELECT b.id, 'b32b32b3-0000-4000-8000-0000000000a2'::uuid, true, 1, 1 FROM _b b WHERE b.g % 100 >= 95;

-- ── 7. Vues matérialisées et statistiques ──
REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;
ANALYZE public.authors; ANALYZE public.author_name_aliases; ANALYZE public.publishers; ANALYZE public.books;
ANALYZE public.book_authors; ANALYZE public.book_holdings; ANALYZE public.works; ANALYZE public.libraries;
ANALYZE public.mv_books_catalog_list_v1; ANALYZE public.mv_books_catalog_list_network_v1;

SELECT 'autorités ' || (SELECT count(*) FROM public.authors) || ' · notices ' || (SELECT count(*) FROM public.books)
    || ' · œuvres ' || (SELECT count(*) FROM public.works) || ' · fonds ' || (SELECT count(*) FROM public.book_holdings)
    || ' · MV publique ' || (SELECT count(*) FROM public.mv_books_catalog_list_v1)
    || ' · MV réseau ' || (SELECT count(*) FROM public.mv_books_catalog_list_network_v1) AS bilan;
