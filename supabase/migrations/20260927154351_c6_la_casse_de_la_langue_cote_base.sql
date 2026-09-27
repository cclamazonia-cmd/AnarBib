-- ============================================================================
-- C6 — la casse de la langue, côté base : la file « titre_casse » propose ce que
-- propose le bouton de la fiche (spec conventions-catalographiques §4.1)
--
-- Le bouton « Normaliser la casse » applique depuis 1782dfcb la casse de la
-- langue du titre (casse de phrase pt/es/fr/it/ca/eo/nl/el, title case en,
-- mots-outils seuls de) ; la file de vérification, elle, proposait encore
-- fn_conv_lower_stopwords (mots-outils seuls). Cette migration porte la règle du
-- bouton en SQL, à l'identique :
--   · private.conv_mots_outils(lang)        — les listes de src/lib/titleCase.js ;
--   · private.conv_noms_propres_mots()      — le dictionnaire des noms propres
--     private.conv_noms_propres_phrases()     attestés (src/lib/nomsPropres.js,
--                                              engendré par scripts/noms-propres-attestes.mjs) ;
--   · public.fn_conv_casse_titre(titre, lang, sous_titre) — le miroir de
--     proposerCasse/normaliserCasse ;
--   · fn_conv_lot_titre_casse_seed : la proposition passe par elle. Le REPÉRAGE ne
--     change pas (règle T1, mots-outils capitalisés) : la nouvelle règle toucherait
--     1 510 titres, c'est une autre campagne.
-- Les propositions déjà en file ne sont PAS réécrites ici (migration suivante,
-- après le regard de Xavier sur la fiche
-- docs/journal/arbitrages/C6_propositions_casse_file_titres_2026-09-27.md).
--
-- Parité : tests/sql/casse_titre_tests.sql et src/tests/title-case.test.js
-- portent les mêmes cas ; la garde vitest compare les listes ci-dessous au JS.
-- Régénérer le dictionnaire = relancer le script puis une migration qui remplace
-- les deux fonctions private.conv_noms_propres_*.
-- ============================================================================
begin;

create or replace function private.conv_mots_outils(p_lang text)
returns text[]
language sql
immutable
set search_path to 'pg_catalog'
as $fn$
  select case
    when p_lang like 'pt%' then array['a','o','as','os','um','uma','uns','umas','de','da','do','das','dos','em','na','no','nas','nos','por','pela','pelo','pelas','pelos','para','com','sem','sob','sobre','entre','ao','aos','à','às','e','ou','que','se']
    when p_lang like 'es%' then array['el','la','los','las','un','una','unos','unas','a','de','del','al','en','por','para','con','sin','sobre','entre','y','e','o','u','que','se','su','sus']
    when p_lang like 'fr%' then array['le','la','les','un','une','des','du','de','au','aux','à','en','dans','par','pour','avec','sans','sur','sous','entre','et','ou','que','qui','ne']
    when p_lang like 'it%' then array['il','lo','la','i','gli','le','un','uno','una','di','del','della','dei','delle','da','dal','in','nel','con','su','sul','per','tra','fra','e','o','che']
    when p_lang like 'en%' then array['a','an','the','of','in','on','at','to','for','with','from','by','and','or','nor','but','as','is','it','its']
    when p_lang like 'ca%' then array['el','la','els','les','un','una','de','del','dels','a','al','als','en','amb','per','sobre','entre','i','o','que']
    when p_lang like 'eo%' then array['la','de','en','al','kun','por','kaj','aŭ','ke']
    when p_lang like 'de%' then array['der','die','das','den','dem','des','ein','eine','einen','einem','eines','und','oder','von','zu','zur','zum','in','im','an','am','auf','für','mit','als']
    else null
  end
$fn$;

create or replace function private.conv_noms_propres_mots()
returns text[]
language sql
immutable
set search_path to 'pg_catalog'
as $fn$
  select array[
    'abad','abella','ackelsberg','afeganistao','afganistan','afghanistan','agypten','ahuyentable',
    'alaiz','aland','albania','albanie','albanien','alberola','albert','albornoz',
    'aldegheri','alemanha','alemania','alemanya','alencar','alfonso','algeria','algerie',
    'algerien','alice','allemagne','almendros','alves','amado','america','amerikaans-samoa',
    'amerikanisch-samoa','amicis','amoros','andorra','andorre','andrade','andreu','angeli',
    'angola','anguila','anguilla','ansart','antarctica','antarctique','antarktis','antartida',
    'antartide','antich','antifascismo','antigua-et-barbuda','antonini','antonio','antony','apendices',
    'apollinaire','apter','aquatorialguinea','argelia','argentine','argentinien','armand','armenia',
    'armenie','armenien','artaud','aruba','ascher','aserbaidschan','assentamento','assis',
    'athiopien','australia','australie','australien','austria','autriche','auzias','avrich',
    'azambuja','azerbaidjan','azerbaigian','azerbaijan','azerbaijao','azerbaiyan','azevedo','baena',
    'bahamas','bahames','bahrain','bahrein','baigorria','baillargeon','bakounine','bakunin',
    'baldelli','balsamini','bandeira','banderas','bangladesch','bangladesh','baqueiro','barbade',
    'barbados','barbosa','baron','barret','barreto','barrett','barros','barry',
    'bartlett','barzun','basaglia','bastian','baudelaire','baudrillard','bay','bayer',
    'beauvoir','becarud','beevor','beiguelman','bein','belarus','belgica','belgien',
    'belgio','belgique','belgium','belice','belize','benedito','benim','benin',
    'berkman','bermuda','bermudas','bermudes','bernardo','bernecker','berneri','berthier',
    'bertonha','besnard','betto','bey','bhoutan','bhutan','biehl','bielorrusia',
    'bielorrussia','bielorussia','bielorussie','bivar','blanchot','blasco','blond','boal',
    'bolivia','bolivie','bolivien','bombardi','bonaire','bonanno','boni','bookchin',
    'boreu','borges','borghi','bosnia-herzegovina','bosnie-herzegovine','botsuana','botswana','bouvet',
    'bouvetinsel','bove','brademas','brandao','brasil','brasile','brasilien','brazil',
    'bresil','brinton','brissa','broca','brossat','broue','brunei','bruno',
    'bulgaria','bulgarie','bulgarien','burundi','butan','butao','butler','cafiero',
    'cajal','calendrier','calvo','camaroes','cambodge','cambodia','cambodja','cambogia',
    'camboja','camboya','cameroon','cameroun','camerun','camoes','canada','canclini',
    'cannac','cap-vert','caparros','capela','cappelletti','cardoso','carone','carpenter',
    'carpio','carr','carretero','carroll','carteles','carter','carteret','carvalho',
    'casanova','castoriadis','catalunha','catar','catarina','catroga','cazaquistao','cerruti',
    'cesar','chad','chade','chalita','chambat','chardin','chaves','chequia',
    'chiapas','chile','chili','china','chine','chipre','chomsky','christie',
    'christmaseiland','churchill','chypre','ciad','ciancabilla','cile','cina','cioran',
    'cipro','cirano','clastres','cleugh','cleyre','cocoseilanden','coggiola','cohen',
    'colombia','colombie','colombo','colomer','colson','comin','comoras','comore',
    'comores','comoros','congo','congresso','cookeilanden','cookinseln','corpo','correa',
    'correia','cortazar','corvisier','cote-d''ivoire','coutinho','creagh','croacia','croatia',
    'croatie','croazia','cuba','curacao','cusicanqui','cutler','cuvillier','cyprus',
    'dagerman','dahms','damiani','danemark','danimarca','darien','darwin','david',
    'davranche','debora','deleuze','delgado','dell''umbria','denmark','deops','descendencia',
    'deus','deutsch','deutschland','deves','diaz','dimenstein','dinamarca','djibouti',
    'doctorow','dolgoff','domingues','dominica','dominique','dommanget','dorlin','dostoievski',
    'dressen','drummond','dschibuti','duclos','dulles','dumesnil','dupuy','durkheim',
    'ecuador','egipte','egipto','egito','egitto','egypt','egypte','ehrenburg',
    'ehrlich','elfenbeinkuste','ellul','emmanuel','enckell','engels','enzensberger','equador',
    'equateur','eritrea','eritreia','ervin','erythree','eslovaquia','eslovenia','espagne',
    'espana','espanha','espanya','essuatini','estland','estonia','estonie','esuatini',
    'eswatini','ethiopia','ethiopie','etiopia','fabbri','fadiman','faeroer','fagnani',
    'falklandeilanden','falklandinseln','fanon','farhat','faroer','fast','faure','feeley',
    'feinmann','fernandes','ferrari','ferreira','ferrer','fidji','fidschi','figi',
    'figner','fiji','filho','filipinas','filipines','filippine','finchelstein','finland',
    'finlande','finlandia','finnland','fiori','flores','flynn','fonseca','fontoura',
    'ford','foucault','franca','france','francia','francini','franco','frank',
    'frankfurter','frankreich','frans-guyana','frans-polynesie','franzosisch-guayana','franzosisch-polynesien','freeman','freire',
    'freitas','fremion','freud','gaarder','gabaglia','gabao','gabon','gabun',
    'galeano','galindo','gallego','gallo','galvao','gambia','gambie','gana',
    'gandhi','garcia','gattai','gelderloos','georgia','georgie','georgien','germania',
    'germany','gertz','ghana','ghiraldelli','ghiraldo','giamaica','giappone','gibilterra',
    'gibraltar','gibuti','ginzburg','giordania','godio','godwin','golarons','goldman',
    'goldsmith','gomes','goncalves','gonzalez','goodman','gori','gorki','goytisolo',
    'graeber','granada','grand','grece','grecia','greece','greef','greenland',
    'gregori','grenada','grenade','griechenland','groenland','groenlandia','gronelandia','gronland',
    'grosz','guadalupa','guadalupe','guadeloupe','guam','guatemala','guattari','guerin',
    'guernesey','guernsey','guiana','guillen','guin','guine','guine-bissau','guinea',
    'guinea-bissau','guinee','guinee-bissau','gurvitch','guyana','guyau','haeckel','haiti',
    'halevy','hamon','hardman','harnecker','harper','heartfield','heinen','heintz',
    'hepner','heredia','heuvel','hobsbawm','hohlfeldt','holton','honduras','hondures',
    'hongkong','hongria','hongrie','horowitz','hungary','hungria','huxley','ianni',
    'ibanez','ibarruri','iceland','iemen','illich','inde','india','indissoluvel',
    'indonesia','indonesie','indonesien','ingenieros','irak','iran','irao','iraq',
    'iraque','ireland','irland','irlanda','irlande','island','islanda','islande',
    'islandia','israel','israele','italia','italie','italien','italy','jamaica',
    'jamaika','jamaique','janet','japan','japao','japo','japon','jay',
    'jellinek','jemen','jersey','jimenez','joffily','joll','jong','jordan',
    'jordania','jordanie','jordanien','jourdain','jourdan','joyeux','julliard','junco',
    'junior','junqueiro','kaaimaneilanden','kafka','kaimaninseln','kalicha','kambodscha','kamerun',
    'kanada','kaplan','karila','kasachstan','kassick','katar','kazajistan','kazakhstan',
    'kazakistan','kenia','kenya','kirghizistan','kirgisistan','kirguistan','kirguizistan','kiribati',
    'koestler','kokosinseln','kolumbien','komoren','kongo','korczak','kosovo','koval',
    'koweit','kroatien','kroeber','kropotkin','kuba','kunsch','kuwait','kyrgyzstan',
    'lacerda','lafargue','landauer','lane','laos','laplantine','latouche','latvia',
    'lazarte','lebanon','lebrun','ledon','lehane','lehning','leite','lenin',
    'lenoir','lesotho','lesoto','letonia','lettland','lettonia','lettonie','leuenroth',
    'leval','leys','liarte','liban','libano','libanon','liberia','libia',
    'libya','libye','libyen','lichtheim','liechtenstein','litauen','lithuania','lituania',
    'lituanie','lizano','llarch','lobo','london','lorenz','lorenzo','louys',
    'low','luaces','luengo','luft','lussemburgo','luxembourg','luxemburg','luxemburgo',
    'luzarraga','macao','macau','macedo','maceio','machado','madagascar','madagaskar',
    'madrid','magon','mahler','mailer','maitron','maiz','makhno','malaisia',
    'malaisie','malasia','malatesta','malato','malaui','malawi','malaysia','maldivas',
    'maldive','maldives','malediven','maleisie','malesia','mali','malta','malte',
    'mandosio','mannheim','margall','marin','marinone','maroc','marocco','marokko',
    'marroc','marrocos','marruecos','marshallinseln','martin','martinez','martinica','martinique',
    'marx','masi','masini','masjuan','masoch','mattos','maura','mauretanien',
    'maurice','maurici','mauricia','mauricio','mauritania','mauritanie','mauritius','mayer',
    'mayotte','mazower','mbah','mechoso','meinhof','mella','mendes','menezes',
    'mennucci','mercier','messico','meszaros','metchnikoff','mett','mexic','mexico',
    'mexiko','mexique','michel','michelet','micronesia','micronesie','mikronesien','milgram',
    'minc','mintz','miramar','mirbeau','mocambic','mocambique','modernell','moissonnier',
    'molaschi','moldavia','moldavie','moldawien','molina','monaco','mongolei','mongolia',
    'mongolie','monserrate','montenegro','montjuic','montseny','montserrat','morales','morel',
    'morike','moriyon','morocco','morris','mosambik','motoyama','mozambico','mozambique',
    'mumford','munoz','murray','musset','myanmar','namibia','namibie','nataf',
    'nauru','nechayev','neel','neill','nemico','nepal','nepomuceno','netherlands',
    'nettlau','neukaledonien','neuseeland','neves','nicaragua','niederlande','nietzsche','nieuw-caledonie',
    'nieuw-zeeland','niger','nigeria','niskier','niue','nomad','nordkorea','nordmazedonien',
    'norfolk','norfolkinsel','noruega','norvege','norvegia','norway','norwegen','nouvelle-caledonie',
    'nouvelle-zelande','ocalan','oekraine','ohsawa','oiticica','oliveira','olivo','oma',
    'oman','oriente','ortellado','ortner','orwell','ospina','osterreich','osttimor',
    'ouganda','ouzbekistan','paassen','pakistan','palante','palaos','palau','palestina',
    'palestine','pallottini','palmeiras','panama','panamazonia','paniagua','pannekoek','papouasie-nouvelle-guinee',
    'papua-neuguinea','paquistao','paraguai','paraguay','parijs','parsons','patsouras','pays-bas',
    'peirats','pelletier','pereira','peret','perlongher','perou','perrot','peru',
    'petersen','petitfils','peyraut','philippinen','philippines','philopat','pierrot','pimenta',
    'pimentel','pinheiro','pisa','pissarro','pitcairn','pitcairninseln','poetico','poland',
    'polen','pologne','polonia','portis','portogallo','pouget','prada','prado',
    'prat','privat','pronzato','protestantes','proudhon','puente','puig','punks',
    'qatar','queiroz','quenia','quirguistao','quiribati','quiroule','rabinad','ragon',
    'raiol','rajchman','ramon','raynaud','reclus','reed','reimer','reis',
    'relgis','republica','reszler','reuniao','reunion','rewald','rey','richards',
    'rimbaud','roca','rocha','rocker','rodrigo','rodrigues','roediger','rojas',
    'romania','romenia','rossanda','rossi','rothbard','roumanie','rousseau','royaume-uni',
    'ruanda','ruiz','rumania','rumanien','rusia','russell','russia','russie',
    'rwanda','ryner','sabino','sacchetti','sacco','sacher','sade','saffioti',
    'sahlins','saint-barthelemy','saint-christophe-et-nieves','saint-marin','saint-martin','saint-pierre-et-miquelon','saint-vincent-et-les-grenadines','sainte-helene',
    'sainte-lucie','salomo','salomonen','salomonseilanden','sambia','samis','samoa','sanguinetti',
    'santa','santarelli','santillan','santos','sarrazin','sartre','saudi-arabien','scalapino',
    'scantimburgo','schirone','schlink','schmidt','schulz','schweden','schweiz','scott',
    'senegal','serbia','serbie','serbien','serge','sergio','serpa','servia',
    'seychellen','seychelles','silva','silveira','simbabwe','singapore','singapour','singapur',
    'singapura','sint-helena','siria','sirkis','skidelsky','skirda','slovacchia','slovakia',
    'slovaquie','slovenia','slovenie','slowakei','slowenien','somalia','somalie','sorel',
    'souchy','soudan','sousa','souza','spagna','spain','spanien','spargo',
    'spencer','spooner','squarisi','staid','staline','stein','stirner','stojanovic',
    'streck','sud-africa','sudafrica','sudafrika','sudan','sudao','sudkorea','sudsudan',
    'suecia','suede','suica','suissa','suisse','suiza','surinam','suriname',
    'suvorov','svezia','svizzera','swazilandia','sweden','swift','switzerland','syrie',
    'tadjikistan','tadschikistan','tagikistan','tailandia','taiwan','tajikistan','tajiquistao','tanzania',
    'tax','tayikistan','tchad','thailand','thailande','thailandia','thomas','thompson',
    'thoreau','tiana','tiburi','timor-leste','togo','tokelau','tolstoi','tonga',
    'toso','tosquelles','tragtenberg','trinite-et-tobago','trotsky','tschad','tunesien','tunez',
    'tunisia','tunisie','turcato','turchia','turkei','turkiye','turkmenistan','turquemenistao',
    'turquia','turquie','tuvalu','twain','txad','txequia','ucraina','ucrania',
    'uganda','ukraine','ullman','ungarn','ungheria','urales','urtubia','uruguai',
    'uruguay','usbekistan','uzbekistan','uzbequistao','vaccaro','valadas','valery','vampre',
    'vaneigem','vanuatu','vanzetti','vaticaanstad','vatikanstadt','vega','venecuela','venezuela',
    'ventura','verissimo','verne','vescovi','veyne','viana','vieil','vienet',
    'vietnam','vietname','vinas','vitale','vogt','vuestro','waerland','walker',
    'wallis-et-futuna','walt','walter','ward','watts','weihnachtsinsel','wertmuller','westsahara',
    'wexler','wilde','wind','wisner','wolf','woodcock','xile','xina',
    'xipre','yemen','yibuti','zambia','zambie','zambrana','zamenhof','zasulic',
    'zenoni','zimbabue','zimbabwe','zinn','zola','zubillaga','zupancic','zypern',
    'αζερμπαιτζαν','αιγυπτος','αιθιοπια','αιτη','αλβανια','αλγερια','ανγκολα','ανγκουιλα',
    'ανδορρα','ανταρκτικη','αργεντινη','αρμενια','αρουμπα','αυστραλια','αυστρια','αφγανισταν',
    'βανουατου','βελγιο','βενεζουελα','βερμουδες','βιετναμ','βολιβια','βουλγαρια','βραζιλια',
    'γαλλια','γερμανια','γεωργια','γιβραλταρ','γκαμπια','γκαμπον','γκανα','γκουαμ',
    'γκουερνσει','γουαδελουπη','γουατεμαλα','γουιανα','γουινεα','γουινεα-μπισσαου','γρεναδα','γροιλανδια',
    'δανια','εκουαδορ','ελβετια','ελλαδα','εσθονια','ζαμπια','ζιμπαμπουε','ιαπωνια',
    'ινδια','ινδονησια','ιορδανια','ιρακ','ιρλανδια','ισημερινη-γουινεα','ισλανδια','ισπανια',
    'ισραηλ','ιταλια','καζακσταν','καμερουν','καμποτζη','καναδας','καταρ','κενυα',
    'κινα','κιργιζια','κιριμπατι','κολομβια','κοσοβο','κουβα','κουβειτ','κουρασαο',
    'κροατια','κυπρος','λετονια','λευκορωσια','λιβανο','λιβερια','λιθουανια','λουξεμβουργο',
    'μαγιοτ','μαδαγασκαρη','μακαου','μαλαισια','μαλαουι','μαλβιδες','μαλι','μαλτα',
    'μαροκο','μαρτινικα','μαυρικιος','μαυριτανια','μαυροβουνιο','μεξικο','μιανμαρ','μογγολια',
    'μοζαμβικη','μοντσερρατ','μπανγκλαντες','μπαρμπαντος','μπαχαμες','μπαχρειν','μπελιζ','μπενιν',
    'μποτσουανα','μπουβε','μπουρουντι','μπουταν','ναμιμπια','ναουρου','νεπαλ','νιγηρας',
    'νιγηρια','νικαραγουα','νιουε','νορβηγια','ολλανδια','ομαν','ονδουρα','ουγγαρια',
    'ουγκαντα','ουζμπεκισταν','ουκρανια','ουρουγουαη','πακισταν','παλαου','παναμας','παραγουαη',
    'περου','πολωνια','πορτογαλια','ρευνιον','ρουαντα','ρουμανια','σαμοα','σενεγαλη',
    'σερβια','σευχελλες','σιγκαπουρη','σλοβακια','σλοβενια','σομαλια','σουαζιλανδη','σουδαν',
    'σουηδια','σουριναμ','ταιλανδη','τατζικισταν','τζαμαικα','τζιμπουτι','τογκο','τοκελαου',
    'τονγκα','τουβαλου','τουρκια','τουρκμενισταν','τσαντ','τυνησια','υεμενη','φιλιππινες',
    'φινλανδια','χιλη']::text[]
$fn$;

create or replace function private.conv_noms_propres_phrases()
returns text[]
language sql
immutable
set search_path to 'pg_catalog'
as $fn$
  select array[
    'africa do sul','afrique du sud','aland illes','aland islands',
    'american samoa','amerikaanse kleinere afgelegen eilanden','amerikaanse maagdeneilanden','amerikanische jungferninseln',
    'anarchist communist federation','antigua and barbuda','antigua e barbuda','antigua en barbuda',
    'antigua i barbuda','antigua und barbuda','antigua y barbuda','arabia saudita',
    'arabie saoudite','arabische republiek egypte','argentijnse republiek','association des amis de henri roorda',
    'bangla desh','birmania myanmar','bolivariaanse republiek venezuela','bonaire saint-eustache et saba',
    'bonaire san eustaquio y saba','bonaire sint eustatius and saba','bonaire sint eustatius en saba','bonaire sint eustatius i saba',
    'bondsrepubliek duitsland','bosnia and herzegovina','bosnia ed erzegovina','bosnia i hercegovina',
    'bosnia y herzegovina','bosnie en herzegovina','bosnien und herzegowina','bouvet eiland',
    'bouvet island','britische jungferninseln','britisches territorium im indischen ozean','british indian ocean territory',
    'brits indische oceaan','britse maagdeneilanden','brunei darussalam','burkina faso',
    'cabo verde','caiman illes','cap verd','cape verde',
    'capo verde','cayman islands','centraal-afrikaanse republiek','central african republic',
    'centreafricana republica','centro de cultura libertaria da amazonia','centro de memoria sindical','christmas illa',
    'christmas island','cira marseille','citta del vaticano','cnt ait sevilha',
    'cocos illes','cocos keeling islands','colectivo paideia','coletivo de ex trabalhadores',
    'coletivo edgard leuenroth','coletivo libertario de oposicao sindical','comissao de cidadania e direitos humanos','comite de resistencia curda',
    'comite pro libertad de los presos de bragado','confederacion nacional del trabajo','congo republica del','congo republica democratica del',
    'congres anarchiste international','cook illes','cook islands','cooperatieve republiek guyana',
    'coordenacao dos grupos autonomos da espanha','corea del nord','corea del sud','coree du nord',
    'coree du sud','coreia do norte','coreia do sul','costa d''avorio',
    'costa d''ivori','costa de marfil','costa do marfim','costa rica',
    'cote d''ivoire','czech republic','democratic republic of the congo','democratische republiek congo',
    'democratische republiek sao tome en principe','democratische republiek timor-leste','democratische socialistische republiek sri lanka','democratische volksrepubliek algerije',
    'democratische volksrepubliek korea','departamento intersindical de estatistica e estudos socioeconomicos','dielo truda grupo de anarquistas russos no estrangeiro','dominicaanse republiek',
    'dominican republic','dominicana republica','dominikanische republik','editora imaginario iel',
    'el salvador','emirados arabes unidos','emirati arabi uniti','emiratos arabes unidos',
    'emirats arabes unis','emirats arabs units','equatorial guinea','equipo el sindicalista',
    'escuela nacional de bellas artes','estados unidos','estats units eua','etats-unis d''amerique',
    'falkland islands malvinas','faroe islands','federacao anarquista do rio de janeiro','federacao anarquista francofona',
    'federacao anarquista uruguai','federacion iberica de juventudes libertarias','federale democratische republiek ethiopie','federale democratische republiek nepal',
    'federale republiek brazilie','federale republiek nigeria','federale republiek somalie','federale staten van micronesie',
    'federatie saint kitts en nevis','federation anarchiste','federation of libertarian students','federazione anarchica italiana',
    'feroe illes','franse republiek','franse zuidelijke gebieden','franzosische sud- und antarktisgebiete',
    'french guiana','french polynesia','french southern territories','fundacion de estudios libertarios',
    'gemenebest dominica','gemenebest van australie','gemenebest van de bahama''s','georgia del sud e isole sandwich meridionali',
    'georgia del sud i sandwich del sud illes','georgia del sur y las islas sandwich del sur','georgia do sul e ilhas sandwich do sul','georgie du sud-et-les iles sandwich du sud',
    'groothertogdom luxemburg','groupe er mai annecy','grupo anarquista º de maio','grupo comunista internacionalista',
    'grupo de estudio sobre el anarquismo','grupo de lucha proletaria','grupo krisis','guaiana francesa',
    'guayana francesa','guiana francesa','guine equatorial','guinea bissau',
    'guinea ecuatorial','guinea equatorial','guinea equatoriale','guinee equatoriale',
    'guyana francese','guyane francaise','hasjemitisch koninkrijk jordanie','heard e islas mcdonald',
    'heard en mcdonaldeilanden','heard illa i mcdonald illes','heard island and mcdonald islands','heard und mcdonaldinseln',
    'helleense republiek','holy see vatican city state','hong kong','hongaarse republiek',
    'ierse republiek','ijslandse republiek','ile bouvet','ile christmas',
    'ile de man','ile norfolk','iles caimans','iles cocos',
    'iles cook','iles feroe','iles heard-et-macdonald','iles malouines',
    'iles mariannes du nord','iles marshall','iles mineures eloignees des etats-unis','iles pitcairn',
    'iles salomon','iles turques-et-caiques','iles vierges americaines','iles vierges britanniques',
    'ilha bouvet','ilha de man','ilha de natal','ilha heard e ilhas mcdonald',
    'ilha norfolk','ilhas aland','ilhas caimao','ilhas cocos keeling',
    'ilhas cook','ilhas distantes dos eua','ilhas faroe','ilhas malvinas',
    'ilhas marianas do norte','ilhas marshall','ilhas pitcairn','ilhas salomao',
    'ilhas turcas e caicos','ilhas virgens americanas','ilhas virgens britanicas','illa de man',
    'illes periferiques menors dels eua','insel man','instituto de estudos libertarios','isla bouvet',
    'isla de man','isla de navidad','isla norfolk','islamic republic of iran',
    'islamitisch emiraat afghanistan','islamitische republiek iran','islamitische republiek mauritanie','islamitische republiek pakistan',
    'islas aland','islas caiman','islas cocos keeling','islas cook',
    'islas feroe','islas malvinas','islas marianas del norte','islas marshall',
    'islas salomon','islas turcas y caicos','islas ultramarinas menores de los estados unidos','islas virgenes britanicas',
    'islas virgenes de los estados unidos','isle of man','isola bouvet','isola del natale',
    'isola di man','isola norfolk','isole aland','isole bes',
    'isole cayman','isole cocos e keeling','isole cook','isole falkland',
    'isole fær øer','isole heard e mcdonald','isole marianne settentrionali','isole marshall',
    'isole minori esterne degli stati uniti','isole pitcairn','isole salomone','isole turks e caicos',
    'isole vergini americane','isole vergini britanniche','italiaanse republiek','kap verde',
    'kirgizische republiek','koninkrijk bahrein','koninkrijk belgie','koninkrijk bhutan',
    'koninkrijk cambodja','koninkrijk denemarken','koninkrijk der nederlanden','koninkrijk eswatini',
    'koninkrijk lesotho','koninkrijk marokko','koninkrijk noorwegen','koninkrijk saudi-arabie',
    'koninkrijk spanje','koninkrijk thailand','koninkrijk tonga','koninkrijk zweden',
    'lao democratische volksrepubliek','lao people''s democratic republic','le monde diplomatique','lesbianas y feministas por la descriminalizacion del aborto',
    'libanese republiek','macedoine du nord','macedonia del nord','macedonia del norte',
    'macedonia do norte','malvines illes','man eiland','mariannes septentrionals illes',
    'marshall illes','marshall islands','mianmar birmania','micronesia estats federats de',
    'micronesia federated states of','moldova republic of','movimento centro de cultura e autoformacao','new caledonia',
    'new zealand','noordelijke marianen','nordliche marianen','norfolk illa',
    'norfolk island','north korea','northern mariana islands','nova caledonia',
    'nova zelanda','nova zelandia','nucleo de estudos libertarios carlo aldegheri','nucleo de sociabilidade libertaria nu sol',
    'nucleo federacao libertaria de educacao','nueva caledonia','nueva zelanda','nuova caledonia',
    'nuova zelanda','ocean indien britannique','onafhankelijke staat papoea-nieuw-guinea','onafhankelijke staat samoa',
    'oostelijke republiek uruguay','organizacao anarquista socialismo libertario','paesi bassi','paises baixos',
    'paises baixos caribenhos','paises bajos','paisos baixos','papua new guinea',
    'papua nova guinea','papua nueva guinea','papua nuova guinea','papua-nova guine',
    'people''s republic of china','pitcairn illes','plurinationale staat bolivia','polinesia francesa',
    'polinesia francese','polynesie francaise','porto rico','portugese republiek',
    'puerto rico','regne unit','regno unito','reino unido',
    'repubblica ceca','repubblica centrafricana','repubblica del congo','repubblica democratica del congo',
    'repubblica di cina','repubblica dominicana','republic of the congo','republic of the gambia',
    'republica arabe siria','republica centro-africana','republica centroafricana','republica checa',
    'republica de corea','republica de guinea','republica democratica do congo','republica democratica popular de lao',
    'republica dominicana','republica federativa do brasil','republica popular democratica de corea','republica popular do congo',
    'republiek albanie','republiek angola','republiek armenie','republiek azerbeidzjan',
    'republiek benin','republiek botswana','republiek bulgarije','republiek burundi',
    'republiek chili','republiek colombia','republiek congo','republiek costa rica',
    'republiek cuba','republiek cyprus','republiek der filipijnen','republiek der maldiven',
    'republiek der marshalleilanden','republiek der seychellen','republiek djibouti','republiek ecuador',
    'republiek el salvador','republiek equatoriaal-guinea','republiek estland','republiek fiji',
    'republiek finland','republiek gabon','republiek gambia','republiek ghana',
    'republiek guatemala','republiek guinee','republiek guinee-bissau','republiek haiti',
    'republiek honduras','republiek india','republiek indonesie','republiek irak',
    'republiek ivoorkust','republiek jemen','republiek kaapverdie','republiek kameroen',
    'republiek kazachstan','republiek kenia','republiek kiribati','republiek korea',
    'republiek kosovo','republiek kroatie','republiek letland','republiek liberia',
    'republiek litouwen','republiek madagaskar','republiek malawi','republiek mali',
    'republiek malta','republiek mauritius','republiek moldavie','republiek mozambique',
    'republiek namibie','republiek nauru','republiek nicaragua','republiek niger',
    'republiek noord-macedonie','republiek oeganda','republiek oezbekistan','republiek oostenrijk',
    'republiek palau','republiek panama','republiek paraguay','republiek peru',
    'republiek polen','republiek rwanda','republiek san marino','republiek senegal',
    'republiek servie','republiek sierra leone','republiek singapore','republiek slovenie',
    'republiek soedan','republiek suriname','republiek tadzjikistan','republiek trinidad en tobago',
    'republiek tsjaad','republiek tunesie','republiek turkije','republiek van de unie van myanmar',
    'republiek vanuatu','republiek wit-rusland','republiek zambia','republiek zimbabwe',
    'republiek zuid-afrika','republiek zuid-soedan','republik kongo','republique centrafricaine',
    'republique democratique du congo','republique dominicaine','republique du congo','republique tcheque',
    'republique unie de tanzanie','reunio illa de la','revista do ifch ufrgs','roemeense republiek',
    'royaume d''eswatini','russian federation','russische federatie','russische foderation',
    'saara ocidental','sahara occidental','sahara occidentale','saint barthelemy',
    'saint helena','saint kitts and nevis','saint kitts e nevis','saint kitts i nevis',
    'saint kitts y nevis','saint lucia','saint martin francesa','saint martin french part',
    'saint pierre and miquelon','saint pierre e miquelon','saint vincent and the grenadines','saint vincent e grenadine',
    'saint vincent en de grenadines','saint vincent i les grenadines','saint-martin partie francaise','saint-martin partie neerlandaise',
    'saint-pierre en miquelon','saint-pierre i miquelon','saint-pierre und miquelon','saint-siege vatican',
    'salvador el','samoa americaines','samoa americana','samoa americane',
    'samoa nord-americana','san marino','san pedro y miquelon','san vicente y las granadinas',
    'sant''elena isola di ascensione e tristan da cunha','santa helena','santa helena ascension y tristan de acuna','santa lucia',
    'santa se','santa sede','santo tome y principe','sao bartolomeu',
    'sao cristovao e neves','sao martinho','sao tome and principe','sao tome e principe',
    'sao tome i principe','sao tome und principe','sao tome-et-principe','sao vicente e granadinas',
    'saudi arabia','serra leoa','servico nacional d informacoes sni','sierra leona',
    'sierra leone','sint maarten','sint maarten dutch part','sint maarten neerlandesa',
    'sint-maarten frans deel','slowaakse republiek','socialistische republiek vietnam','solomon islands',
    'soudan du sud','south africa','south georgia and the south sandwich islands','south korea',
    'south sudan','spitsbergen en jan mayen','sri lanka','st. helena',
    'st. kitts und nevis','st. lucia','st. vincent und die grenadinen','staat eritrea',
    'staat israel','staat koeweit','staat libie','staat palastina',
    'staat palestina','staat qatar','state of palestine','stati federati di micronesia',
    'stati uniti d''america','stato di palestina','sudan del sud','sudan del sur',
    'sudao do sul','sudgeorgien und die sudlichen sandwichinseln','sultanaat oman','svalbard and jan mayen',
    'svalbard e jan mayen','svalbard et ile jan mayen','svalbard i jan mayen','svalbard und jan mayen',
    'svalbard y jan mayen','syrian arab republic','syrien arabische republik','syrische arabische republiek',
    'taiwan province of china','tansania vereinigte republik','terras austrais e antarticas francesas','terres australes francaises',
    'territori britanic de l''ocea indic','territori britannici dell''oceano indiano','territori francesi del sud','territorio britanico del oceano indico',
    'territorio britanico do oceano indico','territorios palestinos','territoris francesos del sud','the republic of north macedonia',
    'tierras australes francesas','timor est','timor oriental','togolese republiek',
    'trindade e tobago','trinidad and tobago','trinidad e tobago','trinidad und tobago',
    'trinidad y tobago','trinitat i tobago','tschechische republik','tsjechische republiek',
    'turkmeense republiek','turks and caicos islands','turks i caicos illes','turks- en caicoseilanden',
    'turks- und caicosinseln','ufpa centro de filosofia e ciencias humanas','uniao regional rhone alpes','unie der comoren',
    'united arab emirates','united kingdom','united republic of tanzania','united states minor outlying islands',
    'united states of america','universidade popular','vatica ciutat del','vereinigte arabische emirate',
    'vereinigte staaten von amerika','vereinigtes konigreich','verenigd koninkrijk van groot-brittannie en noord-ierland','verenigde arabische emiraten',
    'verenigde mexicaanse staten','verenigde republiek tanzania','verenigde staten van amerika','verges britaniques illes',
    'verges nord-americanes illes','virgin islands british','virgin islands u.s.','volksrepubliek bangladesh',
    'volksrepubliek china','vorstendom andorra','vorstendom liechtenstein','vorstendom monaco',
    'wallis and futuna','wallis e futuna','wallis en futuna','wallis i futuna',
    'wallis und futuna','wallis y futuna','westelijke sahara','western sahara',
    'zentralafrikanische republik','zuid-georgia en de zuidelijke sandwicheilanden','zwitserse bondsstaat','αγια λουκια',
    'αγιος βαρθολομαιος','αγιος βικεντιος και γρεναδινες','αγιος μαρινος','αγιος μαρτινος γαλλια',
    'αγιος μαρτινος ολλανδια','ακτη ελεφαντοστου','αμερικανικες παρθενοι νησοι','αμερικανικη σαμοα',
    'ανατολικο τιμορ','αντιγκουα και μπαρμπουντα','απομακρυσμενες νησιδες των ηνωμενων πολιτειων','αραβικη δημοκρατια της συριας',
    'βαιλατο του τζερσει','βασιλειο του λεσοτο','βορειες μαριανες νησοι','βοσνια και ερζεγοβινη',
    'βρετανικες παρθενοι νησοι','βρετανικο εδαφος ινδικου ωκεανου','γαλλικα νοτια και ανταρκτικα εδαφη','γαλλικη γουιανα',
    'γαλλικη πολυνησια','δημοκρατια της βορειας μακεδονιας','δημοκρατια της κινας','δημοκρατια της κορεας',
    'δημοκρατια της μολδαβιας','δημοκρατια του κονγκο','δημοκρατια του πρασινου ακρωτηριου','δημοκρατια των φιτζι',
    'δομινικανη δημοκρατια','δυτικη σαχαρα','ελ σαλβαδορ','ενωμενη δημοκρατια της τανζανιας',
    'ενωση των κομορων','ηνωμενα αραβικα εμιρατα','ηνωμενες πολιτειες αμερικης','ηνωμενο βασιλειο',
    'ισλαμικη δημοκρατια του ιραν','κειμαν νησοι','κεντροαφρικανικη δημοκρατια','κοινοπολιτεια της δομινικας',
    'κοστα ρικα','κρατος της ερυθραιας','κρατος της λιβυης','κρατος της παλαιστινης',
    'κρατος της πολης του βατικανου','λαικη δημοκρατια του κονγκο','λαικη δημοκρατια του λαος','λαοκρατικη δημοκρατια της κορεας',
    'μποναιρ αγιος ευσταθιος και σαμπα','μπουρκινα φασο','νεα ζηλανδια','νεα καληδονια',
    'νησι νορφολκ','νησια κοκος','νησοι κουκ','νησοι μαρσαλ',
    'νησοι πιτκαιρν','νησοι σολομωντα','νησοι φεροες','νησοι φωκλαντ μαλβινας',
    'νησοι χερντ και μακντοναλντ','νησοι ωλαντ','νησος αγιας ελενης','νησος του μαν',
    'νησος των χριστουγεννων','νοτια αφρικη','νοτιο σουδαν','νοτιος γεωργια και νοτιοι σαντουιτς νησοι',
    'ομοσπονδες πολιτειες της μικρονησιας','ομοσπονδια αγιου χριστοφορου και νεβις','ουαλις και φουτουνα','παπουα νεα γουινεα',
    'πουερτο ρικο','πριγκιπατο του λιχτενσταιν','πριγκιπατο του μονακο','ρωσικη ομοσπονδια',
    'σαιν πιερ και μικελον','σαο τομε και πρινσιπε','σαουδικη αραβια','σβαλμπαρντ και γιαν μαγιεν',
    'σιερα λεονε','σουλτανατο του μπρουνει','σρι λανκα','τερκς και κεικος',
    'τρινινταντ και τομπαγκο','τσεχικη δημοκρατια','χονγκ κονγκ']::text[]
$fn$;

-- La clé d'un mot : sans ponctuation autour, sans accents, en minuscules (cleNom).
create or replace function private.conv_cle_nom(p_mot text)
returns text
language sql
immutable
set search_path to 'pg_catalog'
as $fn$
  select lower(regexp_replace(normalize(regexp_replace(p_mot, '^[^[:alpha:]]+|[^[:alpha:]]+$', '', 'g'), NFD),
                              '[\u0300-\u036f]', '', 'g'))
$fn$;

create or replace function public.fn_conv_casse_titre(p_title text, p_lang text, p_sous_titre boolean default false)
returns text
language plpgsql
stable
set search_path to 'pg_catalog'
as $fn$
declare
  c_romain constant text := '^(?=[MDCLXVI]{2,}$)M*(C[MD]|D?C{0,3})(X[CL]|L?X{0,3})(I[XV]|V?I{0,3})$';
  c_ponct  constant text := '^[.,;:!?«»"''()]+|[.,;:!?«»"''()]+$';
  v_regle  text;
  v_stop   text[];
  v_parts  text[];
  v_cles   text[];
  v_mots   text[];
  v_phr    text[];
  v_propre boolean[];
  v_out    text[] := '{}';
  v_tout_cap boolean;
  v_confiance boolean := false;
  v_initial boolean;
  v_debut  boolean;
  w text; nu text; mot text; bas text; ph text; ph_mots text[];
  i int; j int; n int;
  v_fige boolean;
  m text[];
begin
  if p_title is null or p_lang is null then return p_title; end if;
  v_regle := case
    when p_lang ~ '^(pt|es|fr|it|ca|eo|nl|el)' then 'phrase'
    when p_lang like 'en%' then 'titre'
    when p_lang like 'de%' then 'outils'
  end;
  if v_regle is null then return p_title; end if;
  v_parts := array_remove(regexp_split_to_array(btrim(p_title), '\s+'), '');
  n := coalesce(array_length(v_parts, 1), 0);
  if n = 0 then return ''; end if;
  if v_regle = 'outils' then
    return public.fn_conv_lower_stopwords(array_to_string(v_parts, ' '), p_lang);
  end if;
  v_stop := coalesce(private.conv_mots_outils(p_lang), '{}');
  v_tout_cap := n > 1 and array_to_string(v_parts, '') !~ '[[:lower:]]';

  -- Casse de phrase déjà là : un mot plein (3 lettres, hors mots-outils) en minuscules, hors tête.
  if v_regle = 'phrase' then
    for i in 2..n loop
      w := v_parts[i];
      nu := regexp_replace(w, c_ponct, '', 'g');
      if w ~ '^[^[:alpha:]]*[[:lower:]][[:lower:]''’-]*[^[:alpha:]]*$'
         and length(nu) >= 3 and not (lower(nu) = any (v_stop)) then
        v_confiance := true; exit;
      end if;
    end loop;
  end if;

  -- Noms propres attestés : mots et suites de mots.
  v_propre := array_fill(false, array[n]);
  if v_regle = 'phrase' then
    v_mots := private.conv_noms_propres_mots();
    v_phr := private.conv_noms_propres_phrases();
    v_cles := '{}';
    for i in 1..n loop v_cles := v_cles || private.conv_cle_nom(v_parts[i]); end loop;
    for i in 1..n loop
      if v_cles[i] = any (v_mots) then v_propre[i] := true; end if;
      foreach ph in array v_phr loop
        ph_mots := string_to_array(ph, ' ');
        if ph_mots[1] = v_cles[i] and i + array_length(ph_mots, 1) - 1 <= n
           and v_cles[i:i + array_length(ph_mots, 1) - 1] = ph_mots then
          for j in 1..array_length(ph_mots, 1) loop
            if not (ph_mots[j] = any (v_stop)) then v_propre[i + j - 1] := true; end if;
          end loop;
        end if;
      end loop;
    end loop;
  end if;

  v_initial := not p_sous_titre;
  for i in 1..n loop
    w := v_parts[i];
    v_debut := v_initial;
    v_initial := w ~ '[:;?!]$' or (w ~ '\.$' and w !~ '\..*\.' and length(w) > 2) or w in ('-', '–', '—');

    -- figé : sigle, initiale, chiffre romain, mot à chiffres
    nu := regexp_replace(w, '^[«»"''()¿¡]+|[,;:!?«»"''()]+$', '', 'g');
    mot := regexp_replace(nu, '\.$', '');
    v_fige := nu = '' or nu ~ '\d'
      or nu ~ '^([[:upper:]]\.){2,}$' or nu ~ '^([[:upper:]]\.)+[[:upper:]]$'
      or nu ~ '^[[:upper:]]\.$'
      or (case when v_tout_cap then mot ~ '^[IVX]{2,}$' and mot ~ c_romain
               else mot ~ c_romain
                    or (mot ~ '^[[:upper:]]{2,3}$' and not (lower(mot) = any (v_stop))) end);
    if v_fige then v_out := v_out || w; continue; end if;

    if v_confiance and not v_debut and w ~ '^[^[:alpha:]]*[[:upper:]][[:lower:]''’-]*[^[:alpha:]]*$' then
      v_out := v_out || w; continue;
    end if;

    bas := lower(w);
    if (v_regle = 'titre' and (v_debut or not (regexp_replace(bas, c_ponct, '', 'g') = any (v_stop))))
       or (v_regle = 'phrase' and (v_debut or v_propre[i])) then
      m := regexp_match(bas, '^([^[:alpha:]]*)([[:alpha:]])(.*)$');
      if m is not null then bas := m[1] || upper(m[2]) || m[3]; end if;
    end if;
    v_out := v_out || bas;
  end loop;
  return array_to_string(v_out, ' ');
end;
$fn$;

comment on function public.fn_conv_casse_titre(text, text, boolean) is
  'C6 · la casse de la langue d''un titre (spec conventions §4.1), miroir exact de proposerCasse '
  '(src/lib/titleCase.js). Sert la proposition du lot titre_casse. Console et cron seulement.';

revoke all on function private.conv_mots_outils(text) from public, anon, authenticated;
revoke all on function private.conv_noms_propres_mots() from public, anon, authenticated;
revoke all on function private.conv_noms_propres_phrases() from public, anon, authenticated;
revoke all on function private.conv_cle_nom(text) from public, anon, authenticated;
revoke all on function public.fn_conv_casse_titre(text, text, boolean) from public, anon, authenticated;

-- Le semeur des titres propose désormais la casse de la langue.
create or replace function public.fn_conv_lot_titre_casse_seed()
returns bigint
language plpgsql
set search_path to 'public', 'pg_catalog'
as $function$
declare v_n bigint;
begin
  with faits as (
    insert into public.catalog_review_queue (lot, entity_kind, entity_id, contexte, avant, apres_propose, decision, note)
    select 'titre_casse', 'book', b.id, b.idioma, b.titulo,
           public.fn_conv_casse_titre(b.titulo, b.idioma),
           'a_revoir',
           'Audit 03/09 · mot-outil capitalisé pour la langue du titre (CONV-3). '
             || 'La proposition applique la casse de la langue (§4.1) et garde les noms propres attestés ; '
             || 'un nom propre abaissé se corrige ici.'
      from public.books b
     where b.idioma is not null
       and nullif(btrim(coalesce(b.titulo, '')), '') is not null
       and public.fn_conv_lower_stopwords(b.titulo, b.idioma) is distinct from b.titulo
       and not exists (select 1 from public.libraries l
                        where l.id = b.owner_library_id and l.slug like '%-teste')
    on conflict (lot, entity_id) do nothing
    returning 1
  )
  select count(*) into v_n from faits;
  return v_n;
end;
$function$;

do $$
begin
  if public.fn_conv_casse_titre('lE tRuc qui FAIT cHIER', 'fr') <> 'Le truc qui fait chier'
     or public.fn_conv_casse_titre('Tratado Geral Do Brasil', 'pt-BR') <> 'Tratado geral do Brasil' then
    raise exception 'C6 : fn_conv_casse_titre ne rend pas la règle du bouton';
  end if;
  if has_function_privilege('authenticated', 'public.fn_conv_casse_titre(text, text, boolean)', 'EXECUTE')
     or has_function_privilege('anon', 'public.fn_conv_casse_titre(text, text, boolean)', 'EXECUTE') then
    raise exception 'C6 : droits inattendus';
  end if;
end $$;

commit;
