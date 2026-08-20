-- =============================================================================
-- Documenter `access_scope = 'conta_ativa'` : la valeur ne dit plus ce qu'elle fait
-- =============================================================================
-- Date     : 2026-08-21
-- Suite de : 20260821000000_lecture_restreinte_reservee_biblio_detentrice
--
-- PROBLEME DE NOMMAGE. Depuis la migration precedente, `conta_ativa` n'autorise
-- plus « tout compte actif » : elle exige AUSSI d'etre membre actif d'une
-- bibliotheque qui detient le livre. Le nom de la valeur decrit donc la moitie
-- de la regle, et la moitie la moins restrictive — le genre d'ecart qui se paie
-- au prochain audit.
--
-- POURQUOI ON NE RENOMME PAS (encore). La valeur est citee par deux contraintes
-- CHECK, cinq fonctions SQL, deux fonctions edge et le formulaire de catalogage.
-- La renommer proprement est un lot a part ; le faire dans la foulee ferait
-- porter un renommage de vocabulaire au chemin de lecture qu'on vient tout juste
-- de reparer. Meme famille que le doublon `rights_status` (PLAN_DE_MARCHE §8) :
-- a traiter quand le vocabulaire des `access_scope` sera repris.
--
-- CE QU'ON FAIT EN ATTENDANT. On ecrit la regle reelle la ou elle se lit : dans
-- le commentaire de colonne, visible depuis n'importe quel client SQL et depuis
-- le tableau de bord. Les libelles montres aux personnes ont ete corriges dans
-- le meme lot (« Bibliotheque detentrice » remplace « Compte actif »), dans les
-- dix langues : plus personne ne lit « compte actif » nulle part.
-- =============================================================================

begin;

comment on column public.book_digital_resources.access_scope is
  'Portee d''acces. `publico` : lisible par tout le monde, sans compte. `conta_ativa` : NOM HISTORIQUE, la regle reelle est plus etroite depuis le 21/08/2026 — lisible par les membres ACTIFS d''une bibliotheque qui DETIENT le livre (book_holdings), et dont le compte passe fn_current_user_conta_ativa(). Porte par get_accessible_digital_asset_by_id_v2 et fn_book_restricted_pdf_state. Le seau de stockage doit suivre : `conta_ativa` -> seau prive (pdf-restrito), `publico` -> seau public.';

comment on column public.book_draft_digital_resources.access_scope is
  'Portee d''acces du brouillon, reprise telle quelle a la publication. Memes valeurs et meme regle que book_digital_resources.access_scope — voir son commentaire.';

commit;
