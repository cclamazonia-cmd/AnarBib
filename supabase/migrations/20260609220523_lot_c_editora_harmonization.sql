-- ════════════════════════════════════════════════════════════════════════════
-- LOT C — Harmonisation des éditeurs (Groupe 1 : normalisations sûres)
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-09 (UTC)
--
-- OBJET : Fusionne les variantes typographiques d'un MÊME éditeur sur la
-- colonne libre public.books.editora (pas de relation, réversible par un
-- simple UPDATE). Principe de forme canonique : accent correct + forme la plus
-- fréquente + suppression des suffixes juridiques (SA / Ltda / S.A).
--
-- PÉRIMÈTRE : Groupe 1 uniquement (entités certaines). Le Groupe 2 (entités
-- possiblement distinctes : CNT/CNT-RP, Semente/Sementeira, Martins Fontes/WMF,
-- FCE/FCE Usa, Idea/Ideas, co-éditions Imaginário) est LAISSÉ INTACT — il
-- requiert la validation des bibliothécaires catalogueur·euses.
--
-- Match sur btrim(editora) pour rattraper les variantes space-paddées.
-- Idempotent : réappliquer ne change rien (les variantes auront disparu).
-- ════════════════════════════════════════════════════════════════════════════

UPDATE public.books SET editora = 'Civilização Brasileira'
 WHERE btrim(editora) IN ('Civilização brasileira', 'Civilzação brasileira', 'Civilização Brasileira S. A');

UPDATE public.books SET editora = 'Intermezzo Editorial'
 WHERE btrim(editora) = 'Editorial Intermezzo';

UPDATE public.books SET editora = 'Autêntica Editora'
 WHERE btrim(editora) = 'Editora Autêntica';

UPDATE public.books SET editora = 'Fondo de Cultura Económica'
 WHERE btrim(editora) IN ('Fondo de Cultura Economica', 'Fundo de Cultura Económica');

UPDATE public.books SET editora = 'Cortez Editora'
 WHERE btrim(editora) = 'Editora Cortez';

UPDATE public.books SET editora = 'Conrad Editora'
 WHERE btrim(editora) IN ('Editora Conrad', 'Conrad editora');

UPDATE public.books SET editora = 'L&PM Pocket'
 WHERE btrim(editora) = 'L & PM Pocket';

UPDATE public.books SET editora = 'Editores Mexicanos Unidos'
 WHERE btrim(editora) IN ('Editores Mexicanos Unidos SA', 'Editores mexicanos unidos s. a');

UPDATE public.books SET editora = 'Alianza Editorial'
 WHERE btrim(editora) = 'Alianza Editorial Sa';

UPDATE public.books SET editora = 'Jorge Zahar Editor'
 WHERE btrim(editora) = 'Jorge Zahar Editor Ltda';

UPDATE public.books SET editora = 'VJR Editores Associados'
 WHERE btrim(editora) = 'VJR - Editores Associados';

UPDATE public.books SET editora = 'Editora da Unicamp'
 WHERE btrim(editora) IN ('Editora Unicamp', 'Editora UNICAMP');

UPDATE public.books SET editora = 'Centro Editor de América Latina'
 WHERE btrim(editora) = 'Centro Editor de America Latina';

UPDATE public.books SET editora = 'Círculo do Livro'
 WHERE btrim(editora) IN ('Circulo do Livro', 'Círculo do Livro S.A', 'Circulo do Livro S/a');

UPDATE public.books SET editora = 'Companhia Editora Nacional'
 WHERE btrim(editora) = 'Companhia editorial nacional';

UPDATE public.books SET editora = 'Francisco Alves'
 WHERE btrim(editora) = 'Edt. Francisco Alves';

UPDATE public.books SET editora = 'Terra sem Amos'
 WHERE btrim(editora) = 'Terra Sem Amos - TSA';

UPDATE public.books SET editora = 'Ediciones La Piqueta'
 WHERE btrim(editora) = 'Las Ediciones de La Piqueta';

UPDATE public.books SET editora = 'Fundación de Estudios Libertarios Anselmo Lorenzo'
 WHERE btrim(editora) = 'Fundacion de Estudios Libertarios Anselmo Lorenzo';

UPDATE public.books SET editora = 'Ediciones La Rosa Blindada'
 WHERE btrim(editora) = 'Edciones La Rosa Blindada';

UPDATE public.books SET editora = 'Editora da Universidade'
 WHERE btrim(editora) = 'Editora da Unversidade';

UPDATE public.books SET editora = 'Editora Escrituras'
 WHERE btrim(editora) = 'Escrituras Editora';

UPDATE public.books SET editora = 'Cosac Naify'
 WHERE btrim(editora) = 'Cosac & Naify';

UPDATE public.books SET editora = 'Editorial A Sementeira'
 WHERE btrim(editora) = 'Editorial "A Sementeira"';

UPDATE public.books SET editora = 'Arquivo do Estado: Imprensa Oficial'
 WHERE btrim(editora) = 'Arquivo do Estado, Imprensa Oficial';

UPDATE public.books SET editora = 'La Malatesta Editorial / Prensas Universitarias de Zaragoza Madrid / Zangoza (españa)'
 WHERE btrim(editora) = 'La Malatesta Editorial / Prensas Univewrsitarias de Zaragoza Madrid / Zangoza (españa)';

UPDATE public.books SET editora = 'Biblioteca Terra Livre / Laboratório de Educação anarquista'
 WHERE btrim(editora) = 'Biblioteca Terra Livre/ Laboratório de educação anarquista';

NOTIFY pgrst, 'reload schema';
