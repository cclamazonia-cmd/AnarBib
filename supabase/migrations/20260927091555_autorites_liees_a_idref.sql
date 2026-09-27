-- =========================================================================
-- Autorités, troisième phase : IdRef (27/09/2026)
-- =========================================================================
-- Réf. : backlog v34 C4 ; demande de Xavier du 26/09 (« une phase 3 avec une
--        bibliothèque brésilienne ou sud-américaine »), relevé validé le 27/09 ;
--        docs/journal/operations/enrichissement-autorites-2026-09-26/ (§ Troisième phase).
--
-- Les bibliothèques nationales du Brésil et d'Argentine ferment leur accès
-- automatisé (403, X-Services refusés) : non contourné. IdRef (autorités des
-- bibliothèques universitaires françaises, ABES) porte la nationalité (102), la
-- langue (101) et les dates (103), et de nombreux auteurs brésiliens et
-- hispano-américains traduits ou étudiés en France.
--
-- 187 fiches : vedette IdRef (sans précisions) identique à la forme de tri, ET preuve —
-- un titre de l'auteur au catalogue AnarBib (deux mots significatifs au moins)
-- parmi les documents SUDOC liés à la notice, ou des dates concordantes.
-- Écrit : external_ids.idref + trace idref_releve ; et, seulement là où c'est
-- vide : années (si la vedette ne les contredit pas), pays (102, nationalité),
-- langue (101, si unique et confirmée par les livres au catalogue ou le pays).
-- Garde : id ET forme retenue du relevé ; coalesce partout ; rien n'est écrasé.
-- =========================================================================

BEGIN;

CREATE TEMP TABLE enrichissement_idref (id bigint, nom text, ppn text, preuve text, naissance int, mort int, pays text, langue text) ON COMMIT DROP;
INSERT INTO enrichissement_idref VALUES
  (2, 'Francesco Codello', '108497046', 'titre « la buona educazione »', NULL, NULL, NULL, 'it'),
  (6, 'Serge Latouche', '026968126', 'titre « os perigos do mercado planetario »', NULL, NULL, NULL, 'fr'),
  (14, 'Pablo Ortellado', '091876613', 'titre « estamos vencendo resistencia global no brasil »', NULL, NULL, NULL, 'pt-BR'),
  (17, 'Guillaume Goutte', '158692365', 'titre « tout pour tous »', NULL, NULL, NULL, 'fr'),
  (23, 'Marianne Enckell', '030448301', 'titre « ciao anarchici »', NULL, NULL, NULL, NULL),
  (27, 'Paul Boino', '068867743', 'dates', NULL, NULL, NULL, 'fr'),
  (36, 'Ronald Creagh', '026804794', 'titre « histoire de l anarchisme aux etats unis d amerique »', NULL, NULL, NULL, NULL),
  (37, 'Eduardo Colombo', '055849547', 'titre « los desconocidos y los olvidados »', NULL, NULL, NULL, NULL),
  (43, 'Maurício Tragtenberg', '078393396', 'titre « burocracia e ideologia »', NULL, NULL, NULL, 'pt-BR'),
  (10014, 'Maurice Joyeux', '026942259', 'titre « autogestao gestao operaria gestao directa »', NULL, NULL, NULL, 'fr'),
  (10015, 'Gaston Leval', '026987406', 'titre « la falacia del marxismo »', NULL, NULL, NULL, 'fr'),
  (10045, 'Maria Luiza Tucci Carneiro', '029325455', 'titre « o racismo na historia do brasil »', NULL, NULL, NULL, 'pt-BR'),
  (10046, 'Jacinto Cimazo', '077884256', 'titre « luis danussi »', NULL, NULL, NULL, NULL),
  (10050, 'Carlos da Fonseca', '033204071', 'titre « para uma analise do movimento libertario e da sua historia »', NULL, NULL, NULL, 'pt-BR'),
  (10059, 'Cristina Escrivá Moscardó', '132316242', 'titre « los institutos para obreros »', NULL, NULL, NULL, 'es'),
  (10060, 'Roberto das Neves', '297467123', 'dates', NULL, NULL, NULL, NULL),
  (10065, 'Ênio Silveira', '24524333X', 'dates', NULL, NULL, NULL, 'pt-BR'),
  (10069, 'Tito Batini', '194169413', 'titre « filhos do povo »', NULL, NULL, NULL, 'pt-BR'),
  (10073, 'Júlio Carrapato', '221687122', 'titre « uma campanha de salubridade »', NULL, NULL, NULL, 'pt-BR'),
  (10086, 'Augustin Hamon', '026913585', 'titre « psicologia del socialista anarquista »', NULL, NULL, NULL, 'fr'),
  (10087, 'Francisco Foot Hardman', '02807386X', 'titre « nem patria nem patrao »', NULL, NULL, NULL, 'pt-BR'),
  (10098, 'Antonio Arnoni Prado', '034492860', 'titre « libertarios no brasil »', NULL, NULL, NULL, 'pt-BR'),
  (10100, 'Margareth Rago', '080139744', 'titre « entre a historia e a liberdade »', NULL, NULL, NULL, 'pt-BR'),
  (10102, 'Ramón Safón', '029290686', 'titre « la educacion en la espana revolucionaria 1936 1939 »', NULL, NULL, NULL, NULL),
  (10104, 'Fabio Santin', '079824307', 'titre « gaetano bresci »', NULL, NULL, 'IT', 'it'),
  (10107, 'Juan Suriano', '061501611', 'titre « auge y caida del anarquismo »', NULL, NULL, NULL, 'es'),
  (10116, 'Cornelius Castoriadis', '026772086', 'dates', NULL, NULL, NULL, 'fr'),
  (10120, 'Hugues Lenoir', '028296397', 'dates', NULL, NULL, NULL, 'fr'),
  (10130, 'Stanley Milgram', '033096244', 'dates', NULL, NULL, NULL, 'en'),
  (10140, 'Benedict Anderson', '031865186', 'dates', NULL, NULL, NULL, NULL),
  (10143, 'Raymond Carr', '031419798', 'titre « estudios sobre la republica y la guerra civil espanola »', NULL, NULL, NULL, 'en'),
  (10145, 'Pierre Broué', '026754959', 'dates', NULL, NULL, NULL, 'fr'),
  (10148, 'Vernon Richards', '027099105', 'titre « ensenanzas de la revolucion espanola »', NULL, NULL, NULL, 'en'),
  (10151, 'René Viénet', '027184617', 'dates', NULL, NULL, NULL, 'fr'),
  (10152, 'Pietro Ferrua', '026863340', 'dates', NULL, NULL, NULL, NULL),
  (10159, 'Everett Reimer', '082297126', 'dates', NULL, NULL, NULL, 'en'),
  (10162, 'Edgard Carone', '028349113', 'titre « socialismo e anarquismo no inicio do seculo »', NULL, NULL, NULL, 'pt-BR'),
  (10165, 'Fábio Luz', '129448974', 'dates', NULL, NULL, NULL, NULL),
  (10169, 'Christian Ferrer', '111915996', 'dates', NULL, NULL, NULL, 'es'),
  (10174, 'Joseph Staline', '027147029', 'titre « anarchisme ou socialisme »', NULL, NULL, NULL, NULL),
  (10182, 'Sheldon Leslie Maram', '149472765', 'titre « anarquistas imigrantes e o movimento operario brasileiro »', NULL, 1998, NULL, 'en'),
  (10188, 'Wilhelm Reich', '027093174', 'dates', NULL, NULL, NULL, NULL),
  (10206, 'Paul Singer', '029076153', 'dates', NULL, NULL, NULL, 'pt-BR'),
  (10211, 'André Reszler', '027095827', 'titre « la estetica anarquista »', NULL, NULL, NULL, 'fr'),
  (10212, 'Isidro Guardia Abella', '082048290', 'titre « conversaciones sobre el movimiento obrero »', NULL, NULL, NULL, 'es'),
  (10215, 'Carlos Augusto Addor', '298252104', 'titre « historia do anarquismo no brasil »', NULL, NULL, 'BR', 'pt-BR'),
  (10219, 'Ronaldo Conde Aguiar', '058648682', 'titre « o rebelde esquecido »', NULL, NULL, 'BR', 'pt-BR'),
  (10223, 'Martín Albornoz', '158987314', 'titre « cuando el anarquismo causaba sensacion »', NULL, NULL, NULL, NULL),
  (10255, 'João Arruda', '088932753', 'titre « o moloch moderno »', NULL, NULL, NULL, 'pt-BR'),
  (10271, 'Antônio Ladislau Monteiro Baena', '109400267', 'titre « compendio das eras da provincia do para »', NULL, NULL, NULL, 'pt-BR'),
  (10274, 'Quentin Bajac', '05247559X', 'titre « la commune photographiee »', 1965, NULL, 'FR', 'fr'),
  (10277, 'Giovanni Baldelli', '052465128', 'dates', NULL, NULL, NULL, NULL),
  (10298, 'Jean-Pierre Bastian', '030162556', 'dates', NULL, NULL, 'FR', NULL),
  (10324, 'Walther L. Bernecker', '028507266', 'titre « colectividades y revolucion social »', NULL, NULL, NULL, 'de'),
  (10331, 'Franco Bertolucci', '03562292X', 'titre « anarchismo e lotte sociali a pisa 1871 1901 »', 1957, NULL, 'IT', 'it'),
  (10332, 'João Fábio Bertonha', '080480268', 'titre « sob a sombra de mussolini »', NULL, NULL, 'BR', NULL),
  (10349, 'Alfredo María Bonanno', '134030516', 'dates', NULL, NULL, NULL, 'it'),
  (10389, 'Cristina Hebling Campos', '168911701', 'titre « o sonhar libertario »', NULL, NULL, 'BR', 'pt-BR'),
  (10395, 'Jose Capela', '034022376', 'dates', NULL, NULL, 'PT', NULL),
  (10399, 'Ana Claudia Moreira Cardoso', '12883448X', 'titre « tempos de trabalho tempos de nao trabalho »', 1971, NULL, 'BR', NULL),
  (10410, 'Elysio de Carvalho', '129305200', 'titre « barbaros e europeus »', NULL, NULL, NULL, NULL),
  (10426, 'Fiamma Chessa', '136861148', 'titre « aurelio chessa »', NULL, NULL, 'IT', 'it'),
  (10428, 'José Chrispiniano', '087541572', 'titre « a guerrilha surreal »', NULL, NULL, 'BR', 'pt-BR'),
  (10432, 'Giuseppe Ciancabilla', '194132102', 'dates', NULL, NULL, NULL, 'it'),
  (10435, 'Marcos Cirano', '14974806X', 'titre « os caminhos de dom helder »', NULL, NULL, 'BR', 'pt-BR'),
  (10448, 'Hector Adolfo Cordero', '085233900', 'titre « alberto ghiraldo »', NULL, NULL, NULL, 'es'),
  (10450, 'Joël Cornuault', '02679974X', 'titre « elisee reclus geographe et poete »', 1950, NULL, 'FR', 'fr'),
  (10466, 'Fernando O''Neill Cuesta', '076697983', 'titre « el caso pardeiro »', 1924, NULL, 'UY', 'es'),
  (10470, 'Armand Cuvillier', '026807904', 'titre « introducao a sociologia »', NULL, NULL, NULL, 'fr'),
  (10474, 'Hellmuth Günther Dahms', '087226812', 'dates', NULL, NULL, NULL, 'de'),
  (10478, 'Gilson Dantas', '24108136X', 'titre « estatistica da miseria e a miseria da estatistica »', NULL, NULL, 'BR', NULL),
  (10483, 'Henry David', '09283017X', 'titre « the history of the haymarket affair »', 1907, NULL, NULL, 'en'),
  (10486, 'Douglas Day', '050435639', 'titre « los cuadernos de la carcel de ricardo flores magon »', 1932, 2004, 'US', 'en'),
  (10516, 'Mário Domingues', '070349843', 'titre « a afirmacao negra e a questao colonial »', NULL, NULL, NULL, 'pt-BR'),
  (10520, 'Elsa Dorlin', '056216238', 'dates', NULL, NULL, NULL, 'fr'),
  (10526, 'Regina Horta Duarte', '078203678', 'dates', NULL, NULL, NULL, 'pt-BR'),
  (10528, 'Pierre Duchesne', '026840839', 'titre « sacco et vanzetti »', 1942, 1995, 'FR', 'fr'),
  (10553, 'Jorge Etchenique', '080199682', 'titre « pampa libre »', NULL, NULL, 'AR', 'es'),
  (10555, 'Richard F. Fleck', '035132620', 'titre « the indians of thoreau »', 1937, NULL, 'US', 'en'),
  (10558, 'Candace Falk', '081101570', 'titre « love anarchy and emma goldman »', NULL, NULL, NULL, 'en'),
  (10585, 'Sol Ferrer', '088590224', 'titre « le veritable francisco ferrer »', NULL, NULL, NULL, 'fr'),
  (10594, 'Fábio Luz Filho', '269130284', 'titre « cooperativas escolares »', NULL, NULL, NULL, 'pt-BR'),
  (10598, 'Marie Fleming', '243481543', 'titre « the geography of freedom »', 1943, NULL, 'CA', 'en'),
  (10599, 'Pere Foix', '059347260', 'titre « los archivos del terrorismo blanco »', 1893, 1978, 'ES', 'ca'),
  (10601, 'Carlos Fonseca', '075443376', 'titre « garrote vil para dos inocentes »', NULL, NULL, NULL, 'es'),
  (10604, 'Alfonso Font', '026868326', 'dates', NULL, NULL, NULL, 'es'),
  (10611, 'Alex Foti', '14270606X', 'titre « anarchy in the eu »', 1966, NULL, 'IT', 'it'),
  (10625, 'Yves Fremion', '026874458', 'dates', NULL, NULL, NULL, 'fr'),
  (10631, 'Jeanne Gaillard', '02687847X', 'titre « communes de province commune de paris 1870 1871 »', 1909, 1983, 'FR', 'fr'),
  (10662, 'Adelto Gonçalves', '059163267', 'titre « barcelona brasileira »', 1951, NULL, NULL, NULL),
  (10663, 'Rodolfo González Pacheco', '144507102', 'dates', NULL, NULL, NULL, 'es'),
  (10677, 'Armand Guerra', '035514744', 'titre « a traves de la metralla »', NULL, NULL, NULL, 'es'),
  (10680, 'Rafael Guimaraens', '134482697', 'titre « tragedia da rua da praia »', 1956, NULL, NULL, 'pt-BR'),
  (10683, 'Salvador Gurucharri', '091912040', 'titre « bibliografia del anarquismo espanol 1869 1975 »', NULL, NULL, 'ES', 'es'),
  (10692, 'Marta Harnecker', '028803698', 'titre « os desafios da esquerda latino americana »', NULL, NULL, NULL, 'es'),
  (10697, 'Jacqueline Heinen', '026917742', 'dates', NULL, NULL, NULL, 'fr'),
  (10698, 'Peter Heintz', '030781000', 'titre « problematica de la autoridad en proudhon »', NULL, NULL, NULL, 'de'),
  (10699, 'Benoît-P. Hepner', '033322120', 'titre « bakounine et le panslavisme revolutionnaire »', NULL, NULL, 'FR', NULL),
  (10703, 'Bob Holton', '082734623', 'titre « british syndicalism 1900 1914 »', NULL, NULL, NULL, NULL),
  (10727, 'Frank Jellinek', '083265856', 'titre « la guerra civil en espana »', NULL, NULL, NULL, 'en'),
  (10734, 'Édouard Jourdain', '135386136', 'dates', NULL, NULL, NULL, 'fr'),
  (10738, 'Paulo Ghiraldelli Jr.', '159694124', 'dates', NULL, NULL, NULL, NULL),
  (10743, 'Hilário Franco Júnior', '060274131', 'dates', NULL, NULL, 'BR', 'pt-BR'),
  (10755, 'Arthur Koestler', '29597446X', 'dates', NULL, NULL, NULL, NULL),
  (10768, 'Jacques Langlois', '026964651', 'titre « defense et actualite de proudhon »', 1944, NULL, 'FR', 'fr'),
  (10771, 'François Laplantine', '026965763', 'dates', NULL, NULL, NULL, 'fr'),
  (10778, 'Ascendino Leite', '029047021', 'dates', NULL, NULL, NULL, 'pt-BR'),
  (10805, 'Jesús Lizano', '061397628', 'dates', NULL, NULL, NULL, 'es'),
  (10815, 'Maria Margaret Lopes', '069797889', 'titre « o brasil descobre a pesquisa cientifica »', NULL, NULL, 'BR', 'pt-BR'),
  (10816, 'Milton Lopes', '124492983', 'titre « cronica dos primeiros anarquistas no rio de janeiro »', NULL, NULL, 'BR', 'pt-BR'),
  (10817, 'Alfredo López', '082990239', 'titre « historia del movimiento social y la clase obrera argentina »', NULL, NULL, NULL, 'es'),
  (10820, 'Christina Da Silva Roquette Lopreato', '091946700', 'titre « o espirito da revolta »', 1953, NULL, 'BR', 'pt-BR'),
  (10824, 'Albert Low', '035033339', 'dates', NULL, NULL, NULL, 'en'),
  (10849, 'Sílvia Maria Manfredi', '178067660', 'titre « formacao sindical no brasil »', 1946, NULL, 'BR', 'pt-BR'),
  (10861, 'Isabelle Marinone', '084317035', 'titre « cinema e anarquia »', NULL, NULL, 'FR', 'fr'),
  (10874, 'João da Mata', '264856996', 'dates', NULL, NULL, 'BR', 'pt-BR'),
  (10876, 'Marcelo Badaró Mattos', '084689633', 'titre « o sindicalismo brasileiro apos 1930 »', NULL, NULL, 'BR', NULL),
  (10892, 'István Mészáros', '079407277', 'titre « a necessidade do controle social »', NULL, NULL, NULL, NULL),
  (10895, 'Ruth Middleton', '29662733X', 'titre « alexandra david neel »', NULL, NULL, NULL, 'en'),
  (10898, 'Helene Minkin', '189493690', 'titre « storm in my heart »', NULL, NULL, 'US', 'en'),
  (10899, 'Jerome R. Mintz', '028837053', 'titre « the anarchists of casas viejas »', NULL, NULL, NULL, 'en'),
  (10905, 'José Álvaro Moisés', '028495047', 'titre « greve de massa e crise politica »', NULL, NULL, 'BR', 'pt-BR'),
  (10912, 'Michael Moore', '060313455', 'titre « mike s election guide 2008 »', NULL, NULL, NULL, 'en'),
  (10922, 'Mitsue Morissawa', '096319224', 'titre « a historia da luta pela terra e o mst »', NULL, NULL, NULL, 'pt-BR'),
  (10927, 'Shozo Motoyama', '137650493', 'dates', NULL, NULL, 'BR', 'pt-BR'),
  (10930, 'Esmeralda Blanco Bolsonaro de Moura', '111664233', 'titre « trabalho feminino e condicao social do menor em sao paulo 1890 1920 »', NULL, NULL, NULL, 'pt-BR'),
  (10974, 'Georges Ohsawa', '027119394', 'dates', NULL, NULL, NULL, 'ja'),
  (10989, 'Helmut Ortner', '032328788', 'dates', NULL, NULL, NULL, 'de'),
  (10992, 'Iaacov Oved', '117566446', 'titre « el anarquismo y el movimiento obrero en argentina »', NULL, NULL, NULL, NULL),
  (11004, 'Robert Paris', '032517505', 'titre « as origens do fascismo »', 1937, 2020, 'FR', 'fr'),
  (11006, 'Silvina Pascucci', '14081339X', 'titre « costureras monjas y anarquistas »', NULL, NULL, 'AR', 'es'),
  (11008, 'Louis Patsouras', '032742886', 'titre « the anarchism of jean grave »', NULL, NULL, 'US', NULL),
  (11038, 'Marc Pierrot', '230903908', 'dates', NULL, NULL, NULL, 'fr'),
  (11054, 'Richard Porton', '086028898', 'titre « cine y anarquismo »', NULL, NULL, NULL, 'en'),
  (11058, 'Antônio de Almeida Prado', '148608019', 'dates', NULL, NULL, NULL, 'pt-BR'),
  (11060, 'Dino Preti', '029590744', 'titre « analise de textos orais »', 1930, NULL, 'BR', 'pt-BR'),
  (11061, 'Andy Price', '282912932', 'titre « recovering bookchin »', 1984, NULL, 'US', 'en'),
  (11070, 'Eugene Pyziur', '155282301', 'titre « the doctrine of anarchism of michael a bakunin »', 1917, NULL, NULL, 'en'),
  (11080, 'Manuel González Ramírez', '033147647', 'titre « epistolario y textos de ricardo flores magon »', NULL, NULL, NULL, 'es'),
  (11081, 'John Randolph', '131324918', 'titre « the house in the garden »', 1967, NULL, 'US', 'en'),
  (11095, 'Joaquim Ribeiro', '02913143X', 'dates', NULL, NULL, NULL, 'pt-BR'),
  (11098, 'Penny Rimbaud', '187484007', 'dates', NULL, NULL, NULL, 'en'),
  (11113, 'Sérgio Rodrigues', '183696727', 'titre « elza a garota »', 1962, NULL, 'BR', 'pt-BR'),
  (11120, 'Pauline Rosen-Cros', '148536638', 'titre « duro companer s »', 1985, NULL, 'FR', 'fr'),
  (11133, 'Fernando Sabino', '030829852', 'titre « o homem nu »', NULL, NULL, NULL, 'pt-BR'),
  (11138, 'Michel Sahuc', '126040419', 'titre « un regard noir »', NULL, NULL, 'FR', 'fr'),
  (11140, 'Iza Salles', '09305369X', 'titre « um cadaver ao sol »', NULL, NULL, 'BR', NULL),
  (11141, 'Luis Alberto Sanchez', '02712147X', 'titre « don manuel »', 1900, 1994, 'PE', 'es'),
  (11142, 'Gianfranco Sanguinetti', '027121941', 'dates', NULL, NULL, NULL, 'it'),
  (11164, 'Alain Sergent', '027132714', 'titre « histoire de l anarchie »', NULL, NULL, NULL, 'fr'),
  (11175, 'Henri Simon', '027966321', 'titre « novo movimento »', 1922, 2024, 'FR', 'fr'),
  (11196, 'Dimas Antônio de Souza', '133030644', 'titre « o mito politico no teatro anarquista brasileiro »', NULL, NULL, NULL, 'pt-BR'),
  (11197, 'Ismara Izepe de Souza', '11904286X', 'titre « republica espanhola »', NULL, NULL, 'BR', 'pt-BR'),
  (11201, 'Hobart Spalding', '081229569', 'titre « la clase trabajadora argentina »', NULL, NULL, NULL, NULL),
  (11205, 'Andrea Staid', '12870098X', 'titre « gli arditi del popolo »', NULL, NULL, NULL, 'it'),
  (11212, 'Svetozar Stojanovic', '029012759', 'dates', NULL, NULL, NULL, 'sr'),
  (11215, 'Piro Subrat', '250524759', 'titre « invertidos y rompepatrias »', 1990, NULL, 'ES', 'es'),
  (11225, 'Moshik Temkin', '140779442', 'titre « the sacco vanzetti affair »', 1971, NULL, 'GB', 'en'),
  (11234, 'Edilene Toledo', '112332897', 'titre « travessias revolucionarias »', NULL, NULL, 'BR', NULL),
  (11251, 'Joan Connelly Ullman', '095623329', 'titre « la semana tragica »', NULL, NULL, NULL, 'en'),
  (11256, 'Salvo Vaccaro', '029599628', 'dates', NULL, NULL, NULL, 'it'),
  (11275, 'António Ventura', '079943349', 'titre « anarquistas republicanos e socialistas em portugal »', 1953, NULL, 'PT', 'pt-BR'),
  (11283, 'Alexandre Vieira', '136569471', 'titre « para a historia do sindicalismo em portugal »', NULL, NULL, 'PT', 'pt-BR'),
  (11301, 'Félix Weinberg', '029709385', 'titre « dos utopias argentinas de principios de siglo »', NULL, NULL, 'AR', 'es'),
  (11306, 'Alain Wisner', '027198634', 'dates', NULL, NULL, NULL, 'fr'),
  (11309, 'Joan Zambrana', '095658998', 'titre « la alternativa libertaria »', NULL, NULL, 'ES', NULL),
  (11313, 'Roberto Zani', '133342921', 'titre « alla prova del sessantotto »', NULL, NULL, 'IT', 'it'),
  (11321, 'Alenka Zupancic', '034164332', 'dates', NULL, NULL, NULL, NULL),
  (11325, 'Franco Schirone', '059378832', 'titre « il canto anarchico in italia »', NULL, NULL, NULL, 'it'),
  (11353, 'Vivien García', '11658162X', 'titre « l anarchisme aujourd hui »', 1983, NULL, 'FR', 'fr'),
  (11360, 'José Bové', '052637107', 'dates', NULL, NULL, NULL, 'fr'),
  (11379, 'Antonio Rabinad', '027961761', 'dates', NULL, NULL, NULL, 'es'),
  (11381, 'Jean Bécarud', '029328799', 'titre « los anarquistas espanoles »', NULL, NULL, NULL, 'fr'),
  (11396, 'Antoine Gimenez', '101339860', 'titre « les fils de la nuit »', 1910, 1982, 'IT', 'fr'),
  (11413, 'Paola Domingo', '088444015', 'titre « amerique s anarchiste s »', 1968, NULL, NULL, 'fr'),
  (11432, 'Angela Maria Souza Martins', '16725023X', 'titre « trajetorias historicas da educacao »', NULL, NULL, 'BR', 'pt-BR'),
  (11468, 'Josè J. Queiróz', '147576741', 'titre « a cultura do povo »', NULL, NULL, 'BR', 'pt-BR'),
  (11473, 'Pierre Karila-Cohen', '035827858', 'titre « lecon d histoire sur le syndicalisme en france »', NULL, NULL, NULL, 'fr'),
  (11503, 'Federico Mayor', '029455162', 'dates', NULL, NULL, NULL, 'es'),
  (11508, 'René Gertz', '031081436', 'dates', NULL, NULL, NULL, 'pt-BR'),
  (11518, 'Salvador Neves', '168592576', 'titre « polvora y tinta »', NULL, NULL, 'UY', NULL),
  (11519, 'Sam Mbah', '282932143', 'dates', NULL, NULL, NULL, NULL),
  (11532, 'James Cleugh', '083877169', 'titre « furia espanola »', NULL, NULL, 'GB', 'en'),
  (11533, 'Fernand Planche', '085541095', 'dates', NULL, NULL, 'FR', NULL),
  (11546, 'Robert A. Scalapino', '029352339', 'titre « el movimiento anarquista en china »', NULL, NULL, NULL, 'en'),
  (11547, 'Maria Sardelich', '078395801', 'titre « o que vamos guardar de nos »', NULL, NULL, NULL, 'pt-BR'),
  (11563, 'Christian Bay', '089320239', 'dates', NULL, NULL, NULL, NULL);

WITH cible AS (
  SELECT e.*,
         a.birth_year IS NULL AND e.naissance IS NOT NULL AS f_naissance,
         a.death_year IS NULL AND e.mort IS NOT NULL      AS f_mort,
         a.country IS NULL AND e.pays IS NOT NULL         AS f_pays,
         a.writing_language IS NULL AND e.langue IS NOT NULL AS f_langue
    FROM public.authors a
    JOIN enrichissement_idref e ON e.id = a.id AND e.nom = a.preferred_name
)
UPDATE public.authors a
   SET birth_year       = coalesce(a.birth_year, c.naissance),
       death_year       = CASE WHEN a.death_year IS NULL AND c.mort >= coalesce(a.birth_year, c.naissance, c.mort) THEN c.mort ELSE a.death_year END,
       country          = coalesce(a.country, c.pays),
       writing_language = coalesce(a.writing_language, c.langue),
       external_ids     = coalesce(a.external_ids, '{}'::jsonb)
                          || CASE WHEN a.external_ids ? 'idref' THEN '{}'::jsonb ELSE jsonb_build_object('idref', c.ppn) END
                          || jsonb_build_object('idref_releve', jsonb_build_object(
                               'ppn', c.ppn, 'date', '2026-09-27', 'preuve', c.preuve,
                               'champs', to_jsonb(array_remove(ARRAY[
                                 CASE WHEN c.f_naissance THEN 'birth_year' END, CASE WHEN c.f_mort THEN 'death_year' END,
                                 CASE WHEN c.f_pays THEN 'country' END, CASE WHEN c.f_langue THEN 'writing_language' END], NULL)))),
       updated_at       = now()
  FROM cible c
 WHERE a.id = c.id;

DO $$
DECLARE v_total int; v_presents int; v_ecarts text;
BEGIN
  SELECT count(*), count(a.id) INTO v_total, v_presents
    FROM enrichissement_idref e LEFT JOIN public.authors a ON a.id = e.id AND a.preferred_name = e.nom;
  IF v_presents = 0 THEN
    RAISE NOTICE 'Enrichissement IdRef : aucune des fiches relevées dans cette base (banc) — rien à appliquer.';
    RETURN;
  END IF;
  IF v_presents < v_total THEN
    RAISE EXCEPTION 'Enrichissement IdRef : % fiches sur % retrouvées (id + forme retenue) — on n''applique pas à moitié.', v_presents, v_total;
  END IF;
  SELECT string_agg(e.id::text, ', ') INTO v_ecarts
    FROM enrichissement_idref e JOIN public.authors a ON a.id = e.id
   WHERE NOT (a.external_ids ? 'idref') OR NOT (a.external_ids ? 'idref_releve')
      OR (e.naissance IS NOT NULL AND a.birth_year IS NULL)
      OR (e.pays IS NOT NULL AND a.country IS NULL)
      OR (e.langue IS NOT NULL AND a.writing_language IS NULL);
  IF v_ecarts IS NOT NULL THEN
    RAISE EXCEPTION 'Enrichissement IdRef : fiches incomplètes après application : %', v_ecarts;
  END IF;
  RAISE NOTICE 'Enrichissement IdRef : % fiches liées à IdRef.', v_total;
END $$;

COMMIT;
