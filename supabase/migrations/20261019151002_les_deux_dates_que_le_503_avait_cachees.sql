-- ============================================================================
-- Les deux dates que le 503 avait cachées
--
-- `ficedl_thesaurus_terms` portait 621 termes là où le thésaurus en compte 623.
-- Le 3 septembre 2026, jour de l'aspiration, les fiches mot532 et mot538 ont
-- répondu HTTP 503 ; le racleur les a notées en erreur plutôt que d'inventer
-- leur contenu, et l'import s'est fait sans elles. Résultat visible : il
-- manquait 1897 entre 1896 et 1898, et 1903, à la facette « dates ».
--
-- Récupérées le 19/10/2026 à 15 h 08 UTC, une fiche à la fois, avec la même
-- lecture que les 159 autres dates : le libellé vient du titre de la page, les
-- liens de catalogue des ancres `spip_out` vers les sites de la fédération.
-- Comme toutes les dates, elles n'ont pas de bloc de traduction — d'où le
-- drapeau `no_translation_block` et le seul libellé français.
--
-- ANTI-FORK : rien n'est réécrit, rien n'est interprété. Deux lignes qui
-- manquaient sont ajoutées telles que la source les affiche.
-- Idempotent : ON CONFLICT (mot_id) DO NOTHING.
-- ============================================================================

INSERT INTO public.ficedl_thesaurus_terms (mot_id, facet, labels, el_roman, hierarchy, depth, catalog_links, import_normalizations, import_flags, source_url, harvested_at) VALUES ('mot532', '{dates}', '{"fr": "1897"}', NULL, '[]', NULL, '[{"href": "https://placard.ficedl.info/mot6686.html", "name": "1897"}, {"href": "https://cartoliste.ficedl.info/spip.php?page=parution&date=1897", "name": "Cartoliste"}]', '[]', '["no_translation_block"]', 'https://thesaurus.ficedl.info/spip.php?mot532', '2026-10-19 15:08:24+00') ON CONFLICT (mot_id) DO NOTHING;
INSERT INTO public.ficedl_thesaurus_terms (mot_id, facet, labels, el_roman, hierarchy, depth, catalog_links, import_normalizations, import_flags, source_url, harvested_at) VALUES ('mot538', '{dates}', '{"fr": "1903"}', NULL, '[]', NULL, '[{"href": "https://placard.ficedl.info/mot6692.html", "name": "1903"}, {"href": "https://cartoliste.ficedl.info/spip.php?page=parution&date=1903", "name": "Cartoliste"}]', '[]', '["no_translation_block"]', 'https://thesaurus.ficedl.info/spip.php?mot538', '2026-10-19 15:08:24+00') ON CONFLICT (mot_id) DO NOTHING;
