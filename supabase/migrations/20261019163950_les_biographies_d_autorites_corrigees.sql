-- Les biographies d'autorités : coquilles et faits corrigés (19/10/2026).
--
-- Relecture des sources pt-BR et de leurs traductions (migration
-- 20261019154741) : Engel → Engels, « ecomomista », Bookchin « fora ser »
-- et crochet orphelin, Penafiel redoublé, légende d'image orpheline de
-- Colombo (onze langues), titre hybride « La Volonté do povo », Лвович →
-- Львович, Sébastien Faure, ponctuation et parenthèses (Leuenroth, Almeida
-- Prado, Antonini), présent de Creagh et de Colombo mis au passé (morts en
-- 2023 et 2018), « triangular » → « articular » (Mechoso), Villa Commedia
-- rapportée à une tradition locale et « Amanhã » (1909) dite posthume
-- (Reclus, mort en 1905).
--
-- Déjà appliqué en production par remplacements ciblés ; ce fichier rejoue
-- les mêmes remplacements, sans effet là où le texte est déjà corrigé.
-- Un motif absent est signalé, pas bloquant (base sans ces fiches).
-- authors.biography (colonne historique = texte pt-BR) est réalignée.

do $do$
declare r record; b text; misses text := ''; n int := 0;
begin
for r in select * from (values
 -- Engels
 (26,'pt-BR','r',$q$Friedrich Engel;$q$,$q$Friedrich Engels;$q$),
 (26,'ro','r',$q$Friedrich Engel;$q$,$q$Friedrich Engels;$q$),
 -- Latouche
 (6,'pt-BR','r',$q$Quem acredite num crescimento ilimitado é compatível$q$,$q$Quem acredita que um crescimento ilimitado é compatível$q$),
 (6,'pt-BR','r',$q$ou é ecomomista$q$,$q$ou é economista$q$),
 (6,'pt-BR','r',$q$sem limites, E, para$q$,$q$sem limites. E, para$q$),
 -- Bookchin
 (10,'pt-BR','r',$q$Bookchin fora ser o autor de$q$,$q$Bookchin foi autor de$q$),
 (10,'pt-BR','r',$q$Ecologia Social],$q$,$q$Ecologia Social,$q$),
 (10,'*A*','r',$q$Bookchin fora ser o autor de$q$,$q$Bookchin foi autor de$q$),
 (10,'*A*','r',$q$Ecologia Social],$q$,$q$Ecologia Social,$q$),
 -- Neno Vasco
 (15,'ca','r','(Penafiel, Penafiel,','(Penafiel,'),(15,'de','r','(Penafiel, Penafiel,','(Penafiel,'),(15,'eo','r','(Penafiel, Penafiel,','(Penafiel,'),
 (15,'es','r','(Penafiel, Penafiel,','(Penafiel,'),(15,'fr','r','(Penafiel, Penafiel,','(Penafiel,'),(15,'it','r','(Penafiel, Penafiel,','(Penafiel,'),
 (15,'nl','r','(Penafiel, Penafiel,','(Penafiel,'),(15,'pt-BR','r','(Penafiel, Penafiel,','(Penafiel,'),(15,'ro','r','(Penafiel, Penafiel,','(Penafiel,'),
 -- Victor Serge
 (39,'de','r','Лвович','Львович'),(39,'eo','r','Лвович','Львович'),(39,'pt-BR','r','Лвович','Львович'),(39,'ro','r','Лвович','Львович'),
 (39,'pt-BR','r',$q$revolucionário fecundo escritor$q$,$q$revolucionário, fecundo escritor$q$),
 (39,'pt-BR','r',$q$tantos outros revolucionário,$q$,$q$tantos outros revolucionários,$q$),
 -- Maria Lacerda, Leuenroth, Almeida Prado, Antonini
 (46,'pt-BR','r','Sebastien Faure','Sébastien Faure'),
 (41,'pt-BR','r',$q$Ação Direta Foi também$q$,$q$Ação Direta. Foi também$q$),
 (11058,'pt-BR','r',$q$(julho a novembro de 1931, nomeou$q$,$q$(julho a novembro de 1931), nomeou$q$),
 (11058,'pt-BR','r','Em seu livros','Em seus livros'),
 (53,'pt-BR','r',$q$(e depois o IEP de Paris, curso que$q$,$q$(e depois o IEP de Paris), curso que$q$),
 -- Colombo : légende orpheline
 (37,'pt-BR','L',$q$Lodo da Federação Operária Regional Argentina.$q$,''),
 (37,'ro','L',$q$Logoul Federației Muncitorești Regionale Argentiniene.$q$,''),
 (37,'fr','L',$q$Logo de la Fédération ouvrière régionale argentine.$q$,''),
 (37,'es','L',$q$Logotipo de la Federación Obrera Regional Argentina.$q$,''),
 (37,'ca','L',$q$Logotip de la Federació Obrera Regional Argentina.$q$,''),
 (37,'de','L',$q$Logo der Federación Obrera Regional Argentina.$q$,''),
 (37,'en','L',$q$Logo of the Argentine Regional Workers’ Federation.$q$,''),
 (37,'it','L',$q$Logo della Federazione Operaia Regionale Argentina.$q$,''),
 (37,'nl','L',$q$Logo van de Argentijnse Regionale Arbeidersfederatie.$q$,''),
 (37,'el','L',$q$Λογότυπο της Περιφερειακής Εργατικής Ομοσπονδίας Αργεντινής.$q$,''),
 (37,'eo','L',$q$Emblemo de la Argentina Regiona Laborista Federacio.$q$,''),
 -- Colombo : titre et temps
 (37,'pt-BR','r',$q$La Volonté do povo, Démocratie et anarchie$q$,$q$La Volonté du peuple. Démocratie et anarchie$q$),
 (37,'de','r',$q$La Volonté du peuple, Démocratie$q$,$q$La Volonté du peuple. Démocratie$q$),
 (37,'el','r',$q$La Volonté du peuple, Démocratie$q$,$q$La Volonté du peuple. Démocratie$q$),
 (37,'eo','r',$q$La Volonté du peuple, Démocratie$q$,$q$La Volonté du peuple. Démocratie$q$),
 (37,'pt-BR','r',$q$e desde então vive em Paris, onde continua seu engajamento político.$q$,$q$e desde então viveu em Paris, onde continuou seu engajamento político.$q$),
 (37,'pt-BR','r',$q$Contribui para várias$q$,$q$Contribuiu para várias$q$),
 (37,'pt-BR','r',$q$Ele também é membro da Confédération$q$,$q$Foi também membro da Confédération$q$),
 (37,'fr','r',$q$est un médecin psychiatre$q$,$q$était un médecin psychiatre$q$),
 (37,'fr','r',$q$et vit depuis à Paris, où il poursuit son engagement politique.$q$,$q$et vécut dès lors à Paris, où il poursuivit son engagement politique.$q$),
 (37,'fr','r',$q$Il contribue à plusieurs$q$,$q$Il contribua à plusieurs$q$),
 (37,'fr','r',$q$Il est aussi membre de la Confédération$q$,$q$Il fut aussi membre de la Confédération$q$),
 (37,'ca','r',$q$i des d'aleshores viu a París, on continua el seu compromís polític.$q$,$q$i des d'aleshores va viure a París, on va continuar el seu compromís polític.$q$),
 (37,'ca','r',$q$Contribueix a diverses$q$,$q$Va contribuir a diverses$q$),
 (37,'ca','r',$q$També és membre de la Confédération$q$,$q$També va ser membre de la Confédération$q$),
 (37,'de','r',$q$und lebt seitdem in Paris, wo er sein politisches Engagement fortsetzt.$q$,$q$und lebte seitdem in Paris, wo er sein politisches Engagement fortsetzte.$q$),
 (37,'de','r',$q$Er schreibt für mehrere$q$,$q$Er schrieb für mehrere$q$),
 (37,'de','r',$q$Er ist außerdem Mitglied der Confédération$q$,$q$Er war außerdem Mitglied der Confédération$q$),
 (37,'el','r',$q$και έκτοτε ζει στο Παρίσι, όπου συνεχίζει την πολιτική του δράση.$q$,$q$και έκτοτε έζησε στο Παρίσι, όπου συνέχισε την πολιτική του δράση.$q$),
 (37,'el','r',$q$Συνεργάζεται με διάφορα$q$,$q$Συνεργάστηκε με διάφορα$q$),
 (37,'el','r',$q$Είναι επίσης μέλος της Confédération$q$,$q$Ήταν επίσης μέλος της Confédération$q$),
 (37,'en','r',$q$and has since lived in Paris, where he continues his political engagement.$q$,$q$and from then on lived in Paris, where he continued his political engagement.$q$),
 (37,'en','r',$q$He contributes to several$q$,$q$He contributed to several$q$),
 (37,'en','r',$q$(France), since 1997. He is also a member$q$,$q$(France), from 1997 onwards. He was also a member$q$),
 (37,'eo','r',$q$kaj ekde tiam vivas en Parizo, kie li daŭrigas$q$,$q$kaj ekde tiam vivis en Parizo, kie li daŭrigis$q$),
 (37,'eo','r',$q$Li kontribuas al pluraj$q$,$q$Li kontribuis al pluraj$q$),
 (37,'eo','r',$q$Li ankaŭ estas membro de la Confédération$q$,$q$Li ankaŭ estis membro de la Confédération$q$),
 (37,'es','r',$q$y desde entonces vive en París, donde continúa su compromiso político.$q$,$q$y desde entonces vivió en París, donde continuó su compromiso político.$q$),
 (37,'es','r',$q$Colabora en varias$q$,$q$Colaboró en varias$q$),
 (37,'es','r',$q$También es miembro de la Confédération$q$,$q$También fue miembro de la Confédération$q$),
 (37,'it','r',$q$e da allora vive a Parigi, dove prosegue il suo impegno politico.$q$,$q$e da allora visse a Parigi, dove proseguì il suo impegno politico.$q$),
 (37,'it','r',$q$Contribuisce a diverse$q$,$q$Contribuì a diverse$q$),
 (37,'it','r',$q$È inoltre membro della Confédération$q$,$q$Fu inoltre membro della Confédération$q$),
 (37,'nl','r',$q$en woont sindsdien in Parijs, waar hij zijn politieke engagement voortzet.$q$,$q$en woonde sindsdien in Parijs, waar hij zijn politieke engagement voortzette.$q$),
 (37,'nl','r',$q$Hij draagt bij aan verschillende$q$,$q$Hij droeg bij aan verschillende$q$),
 (37,'nl','r',$q$Hij is ook lid van de Confédération$q$,$q$Hij was ook lid van de Confédération$q$),
 (37,'ro','r',$q$și de atunci trăiește la Paris, unde își continuă angajamentul politic.$q$,$q$și de atunci a trăit la Paris, unde și-a continuat angajamentul politic.$q$),
 (37,'ro','r',$q$Contribuie la mai multe$q$,$q$A contribuit la mai multe$q$),
 (37,'ro','r',$q$Este, de asemenea, membru al Confédération$q$,$q$A fost, de asemenea, membru al Confédération$q$),
 -- Creagh
 (36,'fr','r',$q$est un sociologue britannique$q$,$q$était un sociologue britannique$q$),
 (36,'fr','r',$q$Il vit à Montpellier, où il enseigne la civilisation$q$,$q$Il a vécu à Montpellier, où il a enseigné la civilisation$q$),
 (36,'fr','r',$q$Il anime le site$q$,$q$Il animait le site$q$),
 (36,'fr','r',$q$, participe à la revue$q$,$q$, participait à la revue$q$),
 (36,'fr','r',$q$Il est également membre du comité$q$,$q$Il était également membre du comité$q$),
 (36,'pt-BR','r',$q$Ele mora em Montpellier, onde leciona$q$,$q$Viveu em Montpellier, onde lecionou$q$),
 (36,'pt-BR','r',$q$Ele mantém o site$q$,$q$Mantinha o site$q$),
 (36,'pt-BR','r',$q$, participa da revista$q$,$q$, participava da revista$q$),
 (36,'pt-BR','r',$q$Ele também é membro do comitê$q$,$q$Foi também membro do comitê$q$),
 (36,'ca','r',$q$Viu a Montpeller, on ensenya$q$,$q$Va viure a Montpeller, on va ensenyar$q$),
 (36,'ca','r',$q$Manté el lloc web$q$,$q$Mantenia el lloc web$q$),
 (36,'ca','r',$q$, participa en la revista$q$,$q$, participava en la revista$q$),
 (36,'ca','r',$q$També és membre del comitè$q$,$q$També va ser membre del comitè$q$),
 (36,'de','r',$q$Er lebt in Montpellier, wo er an der Universität Paul-Valéry amerikanische Kultur und Gesellschaft lehrt.$q$,$q$Er lebte in Montpellier, wo er an der Universität Paul-Valéry amerikanische Kultur und Gesellschaft lehrte.$q$),
 (36,'de','r',$q$Er betreibt die Website$q$,$q$Er betrieb die Website$q$),
 (36,'de','r',$q$, wirkt seit ihrer Gründung$q$,$q$, wirkte seit ihrer Gründung$q$),
 (36,'de','r',$q$Er ist außerdem Mitglied der Redaktion$q$,$q$Er war außerdem Mitglied der Redaktion$q$),
 (36,'el','r',$q$Ζει στο Μονπελιέ, όπου διδάσκει$q$,$q$Έζησε στο Μονπελιέ, όπου δίδαξε$q$),
 (36,'el','r',$q$Διατηρεί τον ιστότοπο$q$,$q$Διατηρούσε τον ιστότοπο$q$),
 (36,'el','r',$q$, συμμετέχει στο περιοδικό$q$,$q$, συμμετείχε στο περιοδικό$q$),
 (36,'el','r',$q$Είναι επίσης μέλος της συντακτικής$q$,$q$Ήταν επίσης μέλος της συντακτικής$q$),
 (36,'en','r',$q$He lives in Montpellier, where he teaches$q$,$q$He lived in Montpellier, where he taught$q$),
 (36,'en','r',$q$He runs the website$q$,$q$He ran the website$q$),
 (36,'en','r',$q$and has taken part in the journal Réfractions since its creation$q$,$q$and took part in the journal Réfractions from its creation$q$),
 (36,'en','r',$q$He is also a member of the editorial board$q$,$q$He was also a member of the editorial board$q$),
 (36,'eo','r',$q$Li loĝas en Montpeliero, kie li instruas$q$,$q$Li loĝis en Montpeliero, kie li instruis$q$),
 (36,'eo','r',$q$Li prizorgas la retejon$q$,$q$Li prizorgis la retejon$q$),
 (36,'eo','r',$q$, partoprenas en la revuo$q$,$q$, partoprenis en la revuo$q$),
 (36,'eo','r',$q$Li ankaŭ estas membro de la redakcia$q$,$q$Li ankaŭ estis membro de la redakcia$q$),
 (36,'es','r',$q$Vive en Montpellier, donde enseña$q$,$q$Vivió en Montpellier, donde enseñó$q$),
 (36,'es','r',$q$Mantiene el sitio$q$,$q$Mantenía el sitio$q$),
 (36,'es','r',$q$, participa en la revista$q$,$q$, participaba en la revista$q$),
 (36,'es','r',$q$Es también miembro del comité$q$,$q$Fue también miembro del comité$q$),
 (36,'it','r',$q$Vive a Montpellier, dove insegna$q$,$q$Visse a Montpellier, dove insegnò$q$),
 (36,'it','r',$q$Cura il sito$q$,$q$Curava il sito$q$),
 (36,'it','r',$q$, partecipa alla rivista$q$,$q$, partecipava alla rivista$q$),
 (36,'it','r',$q$È inoltre membro del comitato$q$,$q$Fu inoltre membro del comitato$q$),
 (36,'nl','r',$q$Hij woont in Montpellier, waar hij Amerikaanse beschaving doceert$q$,$q$Hij woonde in Montpellier, waar hij Amerikaanse beschaving doceerde$q$),
 (36,'nl','r',$q$Hij beheert de website$q$,$q$Hij beheerde de website$q$),
 (36,'nl','r',$q$en werkt sinds de oprichting$q$,$q$en werkte sinds de oprichting$q$),
 (36,'nl','r',$q$Hij is ook lid van de redactieraad$q$,$q$Hij was ook lid van de redactieraad$q$),
 (36,'ro','r',$q$Locuiește la Montpellier, unde predă$q$,$q$A locuit la Montpellier, unde a predat$q$),
 (36,'ro','r',$q$Întreține site-ul$q$,$q$A întreținut site-ul$q$),
 (36,'ro','r',$q$, participă la revista$q$,$q$, a participat la revista$q$),
 (36,'ro','r',$q$Este, de asemenea, membru al comitetului$q$,$q$A fost, de asemenea, membru al comitetului$q$),
 -- Mechoso
 (33,'pt-BR','r','para triangular os movimentos','para articular os movimentos'),
 (33,'ca','r','per triangular els moviments','per articular els moviments'),
 (33,'el','r','για την τριγωνοποίηση των μαζικών','για τη διασύνδεση των μαζικών'),
 (33,'en','r','Their home served','His home served'),
 (33,'en','r','for triangulating the mass social movements','for linking up the mass social movements'),
 (33,'eo','r','por triangulumi la amasajn','por kunligi la amasajn'),
 (33,'es','r','para triangular los movimientos','para articular los movimientos'),
 (33,'fr','r','pour trianguler les mouvements','pour articuler les mouvements'),
 (33,'it','r','per triangolare i movimenti','per articolare i movimenti'),
 (33,'nl','r','om te trianguleren met de sociale massabewegingen waarin zij actief zijn.','om de sociale massabewegingen waarin zij actief zijn met elkaar te verbinden.'),
 (33,'ro','r','pentru a triangula mișcările','pentru a articula mișcările'),
 -- Reclus : Villa Commedia (tradition locale) et Amanhã (posthume)
 (1,'pt-BR','r','Élisée Reclus identificou a Villa Commedia','Segundo uma tradição local, Élisée Reclus teria identificado a Villa Commedia'),
 (1,'ca','r','Élisée Reclus va identificar la Villa Commedia','Segons una tradició local, Élisée Reclus hauria identificat la Villa Commedia'),
 (1,'de','r','Élisée Reclus identifizierte die Villa Commedia','Einer örtlichen Überlieferung zufolge identifizierte Élisée Reclus die Villa Commedia'),
 (1,'el','r','Ο Ελιζέ Ρεκλύ ταύτισε τη Βίλα Κωμωδία','Σύμφωνα με μια τοπική παράδοση, ο Ελιζέ Ρεκλύ ταύτισε τη Βίλα Κωμωδία'),
 (1,'en','r','Élisée Reclus identified Pliny','According to a local tradition, Élisée Reclus identified Pliny'),
 (1,'eo','r','Élisée Reclus identigis la Villa Commedia','Laŭ loka tradicio, Élisée Reclus identigis la Villa Commedia'),
 (1,'es','r','Élisée Reclus identificó la Villa Commedia','Según una tradición local, Élisée Reclus habría identificado la Villa Commedia'),
 (1,'it','r','Élisée Reclus identificò la Villa Commedia','Secondo una tradizione locale, Élisée Reclus avrebbe identificato la Villa Commedia'),
 (1,'nl','r','Élisée Reclus identificeerde de Villa Commedia','Volgens een plaatselijke overlevering identificeerde Élisée Reclus de Villa Commedia'),
 (1,'pt-BR','r',$q$Encontra-se colaboração da sua autoria na revista "Amanhã" (1909).$q$,$q$Textos seus foram publicados postumamente na revista "Amanhã" (1909).$q$),
 (1,'ca','r',$q$Hi ha col·laboracions seves a la revista «Amanhã» (1909).$q$,$q$La revista «Amanhã» en va publicar textos pòstumament (1909).$q$),
 (1,'de','r',$q$Von ihm stammen Beiträge in der Zeitschrift „Amanhã“ (1909).$q$,$q$Die Zeitschrift „Amanhã“ veröffentlichte 1909 postum Texte von ihm.$q$),
 (1,'el','r',$q$Συνεργασία του απαντά στο περιοδικό «Amanhã» (1909).$q$,$q$Κείμενά του δημοσιεύτηκαν μετά θάνατον στο περιοδικό «Amanhã» (1909).$q$),
 (1,'en','r',$q$Contributions by him can be found in the magazine ‘Amanhã’ (1909).$q$,$q$Texts by him were published posthumously in the magazine ‘Amanhã’ (1909).$q$),
 (1,'eo','r',$q$Oni trovas kontribuaĵojn de li en la revuo „Amanhã“ (1909).$q$,$q$Tekstoj de li aperis postmorte en la revuo „Amanhã“ (1909).$q$),
 (1,'es','r',$q$Se encuentran colaboraciones suyas en la revista «Amanhã» (1909).$q$,$q$La revista «Amanhã» publicó textos suyos de forma póstuma (1909).$q$),
 (1,'it','r',$q$Si trova una sua collaborazione nella rivista «Amanhã» (1909).$q$,$q$Suoi testi furono pubblicati postumi nella rivista «Amanhã» (1909).$q$),
 (1,'nl','r',$q$Van zijn hand verscheen een bijdrage in het tijdschrift “Amanhã” (1909).$q$,$q$In 1909 verscheen postuum werk van zijn hand in het tijdschrift “Amanhã”.$q$)
) v(a,l,k,o,nw) loop
  if r.l = '*A*' then select biography into b from public.authors where id = r.a;
  else select biography into b from public.author_translations where author_id = r.a and lang = r.l; end if;
  if b is null or strpos(b, r.o) = 0 then misses := misses || r.a || ':' || r.l || ' [' || left(r.o,40) || '] '; continue; end if;
  if r.k = 'L' then b := replace(replace(b, r.o || E'\r\n', ''), r.o || E'\n', '');
  else b := replace(b, r.o, r.nw); end if;
  if r.l = '*A*' then update public.authors set biography = b where id = r.a;
  else update public.author_translations set biography = b where author_id = r.a and lang = r.l; end if;
  n := n + 1;
end loop;
if misses <> '' then raise notice 'motifs absents (déjà corrigés ou base sans ces fiches) : %', misses; end if;
raise notice 'appliqués : %', n;
end $do$;

update public.authors a set biography = t.biography
  from public.author_translations t
 where t.author_id = a.id and t.lang = 'pt-BR'
   and a.id in (1,6,10,15,26,33,36,37,39,41,46,53,11058)
   and a.biography is distinct from t.biography;
