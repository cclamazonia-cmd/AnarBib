-- C4, critère 2 (19/10/2026, accord de Xavier) : la détection des doubles
-- patronymes hispaniques rejouée après les pays posés par C4, et la nouvelle
-- liste versée dans la file de revue (lot `autorite_patronyme`), comme celle
-- de l'audit du 20/08 (conventions_04 et conventions_09).
--
-- Règle rejouée en lecture seule sur la production : fiche de personne d'un
-- pays hispanophone, point d'accès « NOM, Prénom Autre » (un seul mot avant
-- la virgule, deux ou plus après), absente du lot. 155 fiches hispanophones,
-- 23 candidates. Aucune heuristique ne distingue « Juan Carlos » (prénom
-- composé) de « Juan Gómez Casas » (double nom) : 3 faux positifs sur 22 en
-- août. Chaque ligne porte donc un AVIS en note : quinze « double nom probable »,
-- proposés inversés (le dernier mot du prénom passe en tête) ; huit « prénom
-- composé ou initiale probable », proposés INCHANGÉS — valider par erreur
-- n'y abîme rien. La décision reste humaine, dans
-- l'Atelier (C3) ; rien n'est appliqué ici.
--
-- Anti-écrasement : une ligne n'entre que si le point d'accès est encore celui
-- lu le 19/10 (la fonction d'application exige de même `sort_name = avant`).
-- Idempotente : `on conflict (lot, entity_id) do nothing`. Sur une base sans
-- ces fiches (banc, rejeu zéro), elle n'insère rien.

insert into public.catalog_review_queue (lot, entity_kind, entity_id, contexte, avant, apres_propose, note)
select 'autorite_patronyme', 'author', a.id, v.country, v.avant, v.apres, v.avis
  from (values
  (10286, 'ES', 'Barón, Antonio Garcia', 'Garcia Barón, Antonio', 'avis du contrôle du 19/10 : double nom de famille probable (premier nom pris pour un prénom) ; accent probable : García'),
  (10385, 'ES', 'Calvo, Enrique Gil', 'Gil Calvo, Enrique', 'avis du contrôle du 19/10 : double nom de famille probable (premier nom pris pour un prénom)'),
  (10463, 'ES', 'Criado, Buenaventura Delgado', 'Delgado Criado, Buenaventura', 'avis du contrôle du 19/10 : double nom de famille probable (premier nom pris pour un prénom)'),
  (10468, 'BO', 'Cusicanqui, Silvia Rivera', 'Rivera Cusicanqui, Silvia', 'avis du contrôle du 19/10 : double nom de famille probable (premier nom pris pour un prénom)'),
  (10567, 'AR', 'Feinmann, José Pablo', 'Feinmann, José Pablo', 'avis du contrôle du 19/10 : prénom composé ou initiale probable — proposition : point d''accès inchangé ; « Corriger » si c''est bien un double nom (José Pablo)'),
  (10572, 'UY', 'Fernandez, Gonzalo D.', 'Fernandez, Gonzalo D.', 'avis du contrôle du 19/10 : prénom composé ou initiale probable — proposition : point d''accès inchangé ; « Corriger » si c''est bien un double nom (initiale)'),
  (10641, 'ES', 'García, Luis Lamela', 'Lamela García, Luis', 'avis du contrôle du 19/10 : double nom de famille probable (premier nom pris pour un prénom)'),
  (10666, 'ES', 'González, Xosé Tarrio', 'Tarrio González, Xosé', 'avis du contrôle du 19/10 : double nom de famille probable (premier nom pris pour un prénom) ; accent probable : Tarrío'),
  (10700, 'CU', 'Hernández, Henry Eric', 'Hernández, Henry Eric', 'avis du contrôle du 19/10 : prénom composé ou initiale probable — proposition : point d''accès inchangé ; « Corriger » si c''est bien un double nom (Henry Eric)'),
  (10742, 'ES', 'Junco, José Álvarez', 'Álvarez Junco, José', 'avis du contrôle du 19/10 : double nom de famille probable (premier nom pris pour un prénom)'),
  (10796, 'AR', 'Lida, Clara E.', 'Lida, Clara E.', 'avis du contrôle du 19/10 : prénom composé ou initiale probable — proposition : point d''accès inchangé ; « Corriger » si c''est bien un double nom (initiale)'),
  (10825, 'ES', 'Luaces, Juan G. de', 'Luaces, Juan G. de', 'avis du contrôle du 19/10 : prénom composé ou initiale probable — proposition : point d''accès inchangé ; « Corriger » si c''est bien un double nom (initiale et particule)'),
  (10877, 'ES', 'Maura, Carlos Semprun', 'Semprun Maura, Carlos', 'avis du contrôle du 19/10 : double nom de famille probable (premier nom pris pour un prénom) ; accent probable : Semprún'),
  (10907, 'ES', 'Molina, José Luís Gutiérrez', 'Gutiérrez Molina, José Luís', 'avis du contrôle du 19/10 : double nom de famille probable (premier nom pris pour un prénom) ; une des seize fiches dont C4 a posé le pays le 18/10'),
  (10917, 'ES', 'Moral, Juan Diaz del', 'Diaz del Moral, Juan', 'avis du contrôle du 19/10 : double nom de famille probable (premier nom pris pour un prénom) ; accent probable : Díaz'),
  (10981, 'ES', 'Olivo, Pedro García', 'García Olivo, Pedro', 'avis du contrôle du 19/10 : double nom de famille probable (premier nom pris pour un prénom)'),
  (10990, 'CO', 'Ospina, Hernando Calvo', 'Calvo Ospina, Hernando', 'avis du contrôle du 19/10 : double nom de famille probable (premier nom pris pour un prénom)'),
  (11129, 'ES', 'Ruiz, Higinio Noja', 'Noja Ruiz, Higinio', 'avis du contrôle du 19/10 : double nom de famille probable (premier nom pris pour un prénom)'),
  (11141, 'PE', 'Sanchez, Luis Alberto', 'Sanchez, Luis Alberto', 'avis du contrôle du 19/10 : prénom composé ou initiale probable — proposition : point d''accès inchangé ; « Corriger » si c''est bien un double nom (Luis Alberto)'),
  (11163, 'ES', 'Sender, Ramon J.', 'Sender, Ramon J.', 'avis du contrôle du 19/10 : prénom composé ou initiale probable — proposition : point d''accès inchangé ; « Corriger » si c''est bien un double nom (Ramón J. Sender)'),
  (11239, 'CL', 'Toso, Sergio Grez', 'Grez Toso, Sergio', 'avis du contrôle du 19/10 : double nom de famille probable (premier nom pris pour un prénom)'),
  (11352, 'MX', 'Heredia, Juan Manuel', 'Heredia, Juan Manuel', 'avis du contrôle du 19/10 : prénom composé ou initiale probable — proposition : point d''accès inchangé ; « Corriger » si c''est bien un double nom (Juan Manuel)'),
  (11362, 'ES', 'Golarons, Ricard de Vargas', 'Vargas Golarons, Ricard de', 'avis du contrôle du 19/10 : double nom de famille probable (premier nom pris pour un prénom) ; particule « de » rejetée après le prénom (CONV-6)')
       ) as v(id, country, avant, apres, avis)
  join public.authors a on a.id = v.id and a.sort_name = v.avant
on conflict (lot, entity_id) do nothing;
