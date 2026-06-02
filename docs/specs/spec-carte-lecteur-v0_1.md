Spec - Carte-lecteur AnarBib (phase β : génération + révocation)
Statut : Cadrée le 28/05/2026, en attente d'implémentation
Cible : Bologna FICEDL, septembre 2026 (livrable autonome détaché)
Origine : DECISION_chantier_mobile_arbitrages_2026-05-28 (arbitrages A.1 à A.4)
Phase : β - génération + révocation côté reader, modèle complet. La RPC de résolution staff (scan) est hors phase β, esquissée en § 9, à implémenter au Paquet 3.
Sommaire
1. Contexte et périmètre
2. Doctrine de sécurité (rappel)
3. Capacité activable côté bibliothèque
4. Schéma DB - table reader_card_tokens
5. RPC - génération
6. RPC - révocation
7. RLS et sécurité des objets
8. Frontend - génération du fichier PNG + PDF
9. Hors phase β - résolution staff (esquisse Paquet 3)
10. Checklist d'implémentation
11. Tests d'acceptation
1. Contexte et périmètre
La carte-lecteur est un laissez-passer détachable permettant à terme un prêt/retour express par scan en permanence (Paquet 3 du chantier mobile). En phase β, on livre uniquement la capacité de générer et révoquer une carte, exportable depuis l'app desktop existante en PNG et PDF. Le scan staff vient plus tard.
Dans le périmètre β :
* Capacité reader_cards_enabled activable par bibliothèque (case à cocher onglet profil Biblioteca)
* Table reader_card_tokens (modèle complet, avec historique de révocation)
* RPC api.generate_my_reader_card(p_library_id) - rôle reader
* RPC api.revoke_my_reader_card(p_token_id) - rôle reader
* Frontend reader : action " générer ma carte " ? PNG + PDF ; action " régénérer " (révoque + génère)
Hors périmètre β (Paquet 3) :
* RPC de résolution staff api.resolve_reader_card_token(p_token) (esquissée § 9)
* Interface de scan (PWA, caméra)
* Prêt/retour express
2. Doctrine de sécurité (rappel de la décision)
Propriété
Mise en œuvre en phase β
Détachable
La carte est exportée en fichier (PNG/PDF), hors de l'app. Pas un écran à présenter.
Révocable
api.revoke_my_reader_card invalide un jeton ; " régénérer " enchaîne révocation + génération. Côté reader uniquement.
Inerte hors scan staff
Le QR encode un jeton opaque aléatoire (un pointeur). Il ne résout vers l'appartenance que via une RPC staff (hors β). Le jeton seul ne prouve rien.
Opaque, non séquentiel
Le jeton est gen_random_bytes encodé base64url, jamais un entier incrémental.
Un jeton par appartenance
Clé étrangère vers user_library_memberships. Un lecteur dans 3 biblios = 3 jetons.
Principe directeur : un identifiant qui circule sur du papier ne doit jamais être une clé. Le user_id brut (UUID Supabase) ne circule jamais sur le support physique - seul le jeton opaque y figure.
3. Capacité activable côté bibliothèque
Sur le modèle de circulation_mode, on ajoute une colonne booléenne à libraries :
ALTER TABLE public.libraries
  ADD COLUMN reader_cards_enabled boolean NOT NULL DEFAULT false;
 
COMMENT ON COLUMN public.libraries.reader_cards_enabled IS
  'Capacite carte-lecteur (chantier mobile, decision 28/05/2026). Si true, les '
  'lecteur·ices membres peuvent generer une carte-laissez-passer detachable pour '
  'cette bibliotheque. Si false, identification nominale en permanence.';

Côté Biblioteca (onglet profil) : une case à cocher " Activer les cartes-lecteur " qui écrit cette colonne via le wrapper de mise à jour du profil bibliothèque existant. Une bibliothèque qui ne l'active pas : ses lecteur·ices ne voient pas l'action " générer ma carte " pour cette appartenance.
4. Schéma DB - table reader_card_tokens
CREATE TABLE public.reader_card_tokens (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membership_id   uuid NOT NULL
                    REFERENCES public.user_library_memberships(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL,        -- denormalise pour RLS simple (== membership.user_id)
  library_id      uuid NOT NULL,        -- denormalise pour RLS et resolution staff
  token           text NOT NULL UNIQUE, -- opaque, base64url de gen_random_bytes(32)
  status          text NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'revoked')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  revoked_at      timestamptz,
  revoked_reason  text,                 -- optionnel : 'regenerated' | 'user_revoked' | ...
 
  -- Un seul jeton actif par appartenance a la fois (l'historique des revoques reste)
  CONSTRAINT reader_card_one_active_per_membership
    EXCLUDE (membership_id WITH =) WHERE (status = 'active')
);
 
CREATE INDEX idx_reader_card_tokens_token  ON public.reader_card_tokens(token)
  WHERE status = 'active';
CREATE INDEX idx_reader_card_tokens_user   ON public.reader_card_tokens(user_id);
CREATE INDEX idx_reader_card_tokens_member ON public.reader_card_tokens(membership_id);
 
COMMENT ON TABLE public.reader_card_tokens IS
  'Jetons de carte-lecteur (chantier mobile, decision 28/05/2026, A.3 mini-table '
  'dediee). Un jeton actif par appartenance (A.2), historique des revocations '
  'conserve. token = pointeur opaque base64url, jamais sequentiel. Resolution vers '
  'appartenance uniquement via RPC staff (Paquet 3, hors phase beta).';

Notes de conception.
* La contrainte EXCLUDE ... WHERE (status='active') garantit qu'il n'y a qu'un seul jeton actif par appartenance à un instant donné, tout en conservant les jetons révoqués (historique A.3). Nécessite l'extension btree_gist (à vérifier/activer).
* user_id et library_id sont dénormalisés depuis l'appartenance pour des RLS simples et une résolution staff efficace, sans jointure supplémentaire.
* token n'est jamais un UUID (qui pourrait suggérer une structure) : c'est encode(gen_random_bytes(32), 'base64') nettoyé en base64url (32 octets = 256 bits d'entropie, largement suffisant et non devinable).
5. RPC - génération
CREATE OR REPLACE FUNCTION api.generate_my_reader_card(p_library_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid          uuid := auth.uid();
  v_membership   public.user_library_memberships%ROWTYPE;
  v_cards_on     boolean;
  v_token        text;
  v_token_id     uuid;
  v_slug         text;
BEGIN
  -- 1. Authentification
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;
 
  -- 2. Appartenance active du lecteur a cette bibliotheque
  SELECT * INTO v_membership
  FROM public.user_library_memberships
  WHERE user_id = v_uid AND library_id = p_library_id
    AND role = 'reader' AND status = 'active'
  LIMIT 1;
 
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_a_member');
  END IF;
 
  -- 3. La bibliotheque a-t-elle active la capacite ?
  SELECT reader_cards_enabled, slug INTO v_cards_on, v_slug
  FROM public.libraries WHERE id = p_library_id;
 
  IF NOT COALESCE(v_cards_on, false) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'cards_disabled');
  END IF;
 
  -- 4. Revoquer le jeton actif precedent s'il existe (regeneration)
  UPDATE public.reader_card_tokens
  SET status = 'revoked', revoked_at = now(), revoked_reason = 'regenerated'
  WHERE membership_id = v_membership.id AND status = 'active';
 
  -- 5. Generer le nouveau jeton opaque (base64url, 256 bits)
  v_token := replace(replace(replace(
              encode(gen_random_bytes(32), 'base64'),
              '+', '-'), '/', '_'), '=', '');
 
  INSERT INTO public.reader_card_tokens
    (membership_id, user_id, library_id, token, status)
  VALUES
    (v_membership.id, v_uid, p_library_id, v_token, 'active')
  RETURNING id INTO v_token_id;
 
  -- 6. Retour : le jeton + le slug (pour la carte). Pas de user_id en clair.
  RETURN jsonb_build_object(
    'ok', true,
    'token', v_token,
    'token_id', v_token_id,
    'library_slug', v_slug
  );
END;
$$;
 
REVOKE ALL ON FUNCTION api.generate_my_reader_card(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.generate_my_reader_card(uuid) TO authenticated;
 
COMMENT ON FUNCTION api.generate_my_reader_card(uuid) IS
  'Genere (ou regenere) la carte-lecteur du lecteur authentifie pour la '
  'bibliotheque p_library_id. Revoque le jeton actif precedent. Verifie '
  'appartenance reader active + capacite reader_cards_enabled. Retour jsonb '
  '{ok, token, token_id, library_slug}. Chantier mobile phase beta, 28/05/2026.';

Note doctrine RPC v3 + sécurité objets v2. Cette RPC fait des écritures multi-lignes (révocation + insertion) avec validations métier ? RPC obligatoire, SECURITY DEFINER justifié (elle écrit sur une table que le reader ne doit pas modifier directement), REVOKE étendu FROM PUBLIC, anon, search_path fixé. Conforme.
6. RPC - révocation
CREATE OR REPLACE FUNCTION api.revoke_my_reader_card(p_token_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.reader_card_tokens%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  END IF;
 
  SELECT * INTO v_row FROM public.reader_card_tokens WHERE id = p_token_id;
 
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_found');
  END IF;
 
  -- Ownership : on ne revoque que SA propre carte
  IF v_row.user_id <> v_uid THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_owner');
  END IF;
 
  IF v_row.status <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'already_revoked');
  END IF;
 
  UPDATE public.reader_card_tokens
  SET status = 'revoked', revoked_at = now(), revoked_reason = 'user_revoked'
  WHERE id = p_token_id;
 
  RETURN jsonb_build_object('ok', true, 'token_id', p_token_id);
END;
$$;
 
REVOKE ALL ON FUNCTION api.revoke_my_reader_card(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.revoke_my_reader_card(uuid) TO authenticated;
 
COMMENT ON FUNCTION api.revoke_my_reader_card(uuid) IS
  'Revoque une carte-lecteur du lecteur authentifie (ownership check). Retour '
  'jsonb {ok, token_id}. Chantier mobile phase beta, 28/05/2026.';

7. RLS et sécurité des objets
ALTER TABLE public.reader_card_tokens ENABLE ROW LEVEL SECURITY;
 
-- Le lecteur lit ses propres jetons (pour afficher l'etat de sa carte)
CREATE POLICY reader_card_tokens_select_own
  ON public.reader_card_tokens FOR SELECT
  USING (user_id = auth.uid());
 
-- Aucune policy INSERT/UPDATE/DELETE directe : tout passe par les RPC DEFINER.
-- (La resolution staff, hors beta, aura sa propre policy ou passera par RPC DEFINER.)

Conforme à la doctrine création objets sécurisés v2 : RLS activée, lecture restreinte au propriétaire, écritures réservées aux RPC SECURITY DEFINER REVOKE-ées. La résolution staff (Paquet 3) ajoutera l'accès en lecture pour le staff de la bonne bibliothèque, via RPC dédiée - pas de policy permissive transverse.
8. Frontend - génération du fichier PNG + PDF
Emplacement : espace reader (AccountPage ou page dédiée " Mes cartes ").
Flux :
12. Pour chaque appartenance active où reader_cards_enabled = true, afficher une action " Générer ma carte " (ou " Régénérer " si une carte active existe déjà).
13. Au clic : appeler api.generate_my_reader_card(library_id).
14. Avec le token et le library_slug retournés, construire la carte :
* Un QR encodant le token (et seulement le token - pas d'URL, pas de user_id). Lib QR côté client, ex. qrcode (génération locale, aucune requête réseau, cohérent anti-tracking).
* Le slug/logo de la bibliothèque en clair (seule information humaine).
* Aucune autre donnée : ni nom, ni email, ni identifiant en clair.
15. Exporter en PNG (canvas ? blob ? téléchargement) ET proposer le PDF (ex. jsPDF, carte centrée format carte de visite ou A7).
16. Afficher l'avertissement de sécurité (A.4) : " Cette carte révèle votre appartenance à [biblio]. Elle ne donne pas accès à votre compte. Vous pouvez la régénérer ou la révoquer à tout moment. "
Dépendances frontend : une lib QR (génération locale) + une lib PDF. À choisir dans la phase d'implémentation, en privilégiant des libs sans appel réseau (cohérence anti-tracking).
Note importante : aucune donnée de carte n'est stockée en localStorage/sessionStorage (interdit dans le contexte, et inutile : la carte est un fichier exporté, pas un état d'app).
9. Hors phase β - résolution staff (esquisse Paquet 3)
Pour mémoire, à implémenter au Paquet 3 quand l'interface de scan existera :
-- ESQUISSE - NE PAS IMPLEMENTER EN PHASE BETA
CREATE OR REPLACE FUNCTION api.resolve_reader_card_token(p_token text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
-- Verifie : staff authentifie (can_access_painel) de la bibliotheque du jeton.
-- Resout le token actif vers l'appartenance (user_id, nom affichable selon policy).
-- Retour jsonb {ok, user_id, display_name, membership_id} ou {ok:false, reason}.
-- Le jeton revoque ou inconnu => reason 'invalid_token'.
$$;

Le modèle de données de la phase β est conçu pour que cette RPC n'ait qu'à lire reader_card_tokens WHERE token = p_token AND status = 'active', joindre l'appartenance et vérifier que le staff appelant appartient à library_id. Aucune migration de schéma ne sera nécessaire.
10. Checklist d'implémentation (phase β)
* ? Migration : ALTER TABLE libraries ADD reader_cards_enabled
* ? Migration : extension btree_gist si absente (pour la contrainte EXCLUDE)
* ? Migration : CREATE TABLE reader_card_tokens + index + RLS + policy select_own
* ? Migration : api.generate_my_reader_card + REVOKE/GRANT
* ? Migration : api.revoke_my_reader_card + REVOKE/GRANT
* ? DO-block de vérification en fin de transaction (test contexte anon simulé : un anon ne doit pas pouvoir appeler les RPC ni lire la table)
* ? Frontend Biblioteca : case à cocher reader_cards_enabled dans l'onglet profil
* ? Frontend reader : action générer/régénérer/révoquer + génération QR + export PNG + export PDF + avertissement sécurité
* ? i18n : clés nouvelles × 8 locales (conventions militantes)
* ? npm run build (quality gate)
* ? Test fumée
* ? Commit + push
11. Tests d'acceptation (phase β)
17. Une biblio avec reader_cards_enabled = false : le lecteur ne voit pas l'action générer pour cette appartenance.
18. Une biblio avec capacité activée : le lecteur génère une carte ? reçoit token + slug, le PNG et le PDF se téléchargent, le QR encode bien le token seul.
19. Régénération : un nouveau jeton est créé, l'ancien passe en revoked avec revoked_reason='regenerated', la contrainte EXCLUDE est respectée (un seul actif).
20. Révocation explicite : api.revoke_my_reader_card passe le jeton en revoked, revoked_reason='user_revoked'.
21. Ownership : un lecteur A ne peut pas révoquer la carte d'un lecteur B (not_owner).
22. Anon : un appel anonyme aux deux RPC retourne not_authenticated ; un anon ne peut pas lire reader_card_tokens (RLS).
23. Le QR ne contient jamais le user_id ni aucune donnée humaine - seulement le token opaque.
24. La carte affiche le slug de la bonne bibliothèque et rien d'autre d'identifiant.
Fin de la spec carte-lecteur v0.1 - phase β - 28 mai 2026.
