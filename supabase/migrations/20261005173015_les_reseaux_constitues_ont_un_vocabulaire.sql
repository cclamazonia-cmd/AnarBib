-- =====================================================================
-- G13 (05/10/2026) — les réseaux constitués, du texte libre à un vocabulaire,
-- et jusqu'au catalogue public.
--
-- Demande de Xavier (07/09) : pouvoir restreindre le catalogue aux
-- bibliothèques d'un réseau constitué AVANT AnarBib — FICEDL, RebAL, NORLA.
-- Le seul porteur était `cartography_entries.reseau`, texte libre (« RebAL ;
-- FICEDL », « RebAL, FAI »…), fédérations de documentation et organisations
-- politiques mêlées. L'appartenance reste DÉCLARÉE PAR LA FICHE DE CARTE, qui
-- a déjà sa modération : aucun circuit nouveau.
--
-- (1) Normaliser :
--   * public.networks — le vocabulaire (slug, libellé, alias, nature, site).
--     Nature : documentation (réseaux de bibliothèques, centres et archives),
--     organisation_politique, autre ; NULL = à classer. Seules FICEDL, RebAL et
--     NORLA (nommées par Xavier) sont posées « documentation », FAI et FAI
--     Reggiana « organisation_politique » ; ABABA, FAO, AFI, UK Social Centre
--     Network et Radical Routes restent À CLASSER — c'est à une personne qui les
--     connaît de le faire, pas à une migration.
--   * cartography_entries.reseaux text[] — les slugs reconnus dans `reseau`,
--     dans l'ordre du texte, tenus par déclencheur : `reseau` reste le texte
--     saisi (création, mise à jour, carte), `reseaux` en est la lecture.
--     Un jeton hors vocabulaire reste dans le texte et n'entre pas dans
--     `reseaux` ; l'écran de la carte le montre. Une évolution du vocabulaire
--     (alias, réseau neuf) passe par une migration qui recalcule `reseaux`.
-- (2) Exposer : api.fn_catalog_networks_v1() — les réseaux de nature
--     « documentation » qui ont au moins une bibliothèque visible de
--     l'appelant (fn_library_visible_to_caller, comme api.libraries_public_v1)
--     par une fiche de carte publique, avec ces bibliothèques. DEFINER : la
--     carte n'est lisible que par des fonctions (politique
--     deny_direct_access_secdef_only), si bien que la jointure prévue dans la
--     vue invoker libraries_public_v1 n'aurait rien vu sous anon.
-- (3) Le filtre de l'OPAC lit cette fonction (CatalogPage) ; le RPC du
--     catalogue et les vues matérialisées ne bougent pas.
--
-- Données : `reseaux` rempli pour les 187 fiches, déclencheur set_updated_at
-- suspendu le temps de la reprise (aucune fiche n'a été modifiée par
-- personne). Suite : tests/sql/g13_reseaux_constitues_tests.sql.
-- =====================================================================

CREATE TABLE public.networks (
  slug       text PRIMARY KEY CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  label      text NOT NULL UNIQUE CHECK (btrim(label) <> ''),
  aliases    text[] NOT NULL DEFAULT '{}',
  kind       text CHECK (kind IN ('documentation', 'organisation_politique', 'autre')),
  site_url   text,
  created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.networks IS
  'G13 (05/10/2026) — vocabulaire des réseaux constitués (FICEDL, RebAL, NORLA…) déclarés par les fiches de carte (cartography_entries.reseau → reseaux). kind NULL = à classer. Seuls les réseaux « documentation » filtrent le catalogue public.';
ALTER TABLE public.networks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.networks FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.networks TO anon, authenticated;
CREATE POLICY networks_lecture_publique ON public.networks FOR SELECT TO anon, authenticated USING (true);

INSERT INTO public.networks (slug, label, kind) VALUES
  ('ficedl',                   'FICEDL',                   'documentation'),
  ('rebal',                    'RebAL',                    'documentation'),
  ('norla',                    'NORLA',                    'documentation'),
  ('fai',                      'FAI',                      'organisation_politique'),
  ('fai-reggiana',             'FAI Reggiana',             'organisation_politique'),
  ('ababa',                    'ABABA',                    NULL),
  ('fao',                      'FAO',                      NULL),
  ('afi',                      'AFI',                      NULL),
  ('uk-social-centre-network', 'UK Social Centre Network', NULL),
  ('radical-routes',           'Radical Routes',           NULL);

-- La lecture d'un texte de réseaux : jetons séparés par « ; » ou « , »,
-- reconnus par libellé ou alias sans égard à la casse, sans doublon, dans
-- l'ordre du texte. Même règle côté écran : src/lib/reseaux.js.
CREATE FUNCTION public.fn_cartography_reseaux_de(p_reseau text)
RETURNS text[]
LANGUAGE sql STABLE
SET search_path = public, pg_catalog
AS $$
  SELECT coalesce(array_agg(x.slug ORDER BY x.ord), '{}')
    FROM (SELECT n.slug, min(t.ord) AS ord
            FROM regexp_split_to_table(coalesce(p_reseau, ''), '\s*[;,]\s*') WITH ORDINALITY AS t(tok, ord)
            JOIN public.networks n
              ON lower(n.label) = lower(btrim(t.tok))
              OR lower(btrim(t.tok)) = ANY (SELECT lower(a) FROM unnest(n.aliases) a)
           WHERE btrim(t.tok) <> ''
           GROUP BY n.slug) x
$$;
REVOKE ALL ON FUNCTION public.fn_cartography_reseaux_de(text) FROM PUBLIC, anon, authenticated;

ALTER TABLE public.cartography_entries ADD COLUMN reseaux text[] NOT NULL DEFAULT '{}';
COMMENT ON COLUMN public.cartography_entries.reseaux IS
  'G13 (05/10/2026) — slugs de public.networks reconnus dans `reseau` (texte saisi), tenus par trg_cartography_reseaux. Ne s''écrit pas directement.';

CREATE FUNCTION public.tg_cartography_reseaux()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
BEGIN
  NEW.reseaux := public.fn_cartography_reseaux_de(NEW.reseau);
  RETURN NEW;
END
$$;
REVOKE ALL ON FUNCTION public.tg_cartography_reseaux() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER trg_cartography_reseaux
  BEFORE INSERT OR UPDATE OF reseau, reseaux ON public.cartography_entries
  FOR EACH ROW EXECUTE FUNCTION public.tg_cartography_reseaux();

-- Reprise : la lecture des textes existants, sans toucher updated_at.
ALTER TABLE public.cartography_entries DISABLE TRIGGER cartography_entries_set_updated_at;
UPDATE public.cartography_entries SET reseaux = '{}' WHERE coalesce(btrim(reseau), '') <> '';
ALTER TABLE public.cartography_entries ENABLE TRIGGER cartography_entries_set_updated_at;

-- (2) Le catalogue public : réseaux « documentation » et leurs bibliothèques
-- visibles de l'appelant, par une fiche de carte publique.
CREATE FUNCTION api.fn_catalog_networks_v1()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'slug', n.slug, 'label', n.label, 'site_url', n.site_url, 'libraries', x.libs)
         ORDER BY n.label), '[]'::jsonb)
    FROM public.networks n
    JOIN LATERAL (
      SELECT jsonb_agg(DISTINCT jsonb_build_object('slug', l.slug, 'short_name', l.short_name, 'name', l.name)) AS libs
        FROM public.cartography_entries ce
        JOIN public.libraries l ON l.id = ce.library_id
       WHERE n.slug = ANY (ce.reseaux)
         AND ce.statut_public
         AND public.fn_library_visible_to_caller(l.id)
    ) x ON x.libs IS NOT NULL
   WHERE n.kind = 'documentation'
$$;
COMMENT ON FUNCTION api.fn_catalog_networks_v1() IS
  'G13 (05/10/2026) — filtre « réseau » du catalogue public : les réseaux de nature documentation qui ont au moins une bibliothèque visible de l''appelant par une fiche de carte publique, avec ces bibliothèques (slug, short_name, name). DEFINER : la carte n''est lisible que par fonction.';
REVOKE EXECUTE ON FUNCTION api.fn_catalog_networks_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_catalog_networks_v1() TO anon, authenticated, service_role;
