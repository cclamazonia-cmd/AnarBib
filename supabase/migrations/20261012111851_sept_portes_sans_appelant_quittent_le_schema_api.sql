-- Sept portes sans appelant quittent le schéma api (DOC-SURFACE-1, décision Xavier du 12/10/2026).
--
-- Le GLB v18 (11/10/2026, ch. 6.1) compte neuf fonctions du schéma api sans aucun appelant
-- — ni client, ni Edge Function, ni fonction SQL, ni vue, ni policy, ni trigger, ni cron —
-- et sans EXECUTE pour anon, authenticated ni service_role depuis B20 (02/09/2026) :
-- « une aile jamais ouverte se ferme à clé ». Une aile fermée à clé depuis six semaines,
-- que personne ne réclame, se démolit : sept sont supprimées ici.
--
--   api.attach_exemplar              — doublon → exemplaire, supplantée par le flux brouillon
--   api.clear_loan_return_schedule   ─┐
--   api.schedule_loan_return          ├ planification de retour et créneaux de retrait :
--   api.mark_loan_return_missed       │ lot écrit en mai, jamais branché à un écran (0 ligne)
--   api.refuse_pickup_slot           ─┘
--   api.conv_controle_qualite        ─┐ contrôles de conventions : la console lit directement
--   api.conv_controle_resumo         ─┘ private.v_conv_controle_qualite / _resumo, qui restent
--
-- Deux restent fermées à clé, sans être supprimées : api.fn_cartography_create_entry et
-- api.fn_cartography_toggle_public, que spec-cartographie-reseau v1.0 (G9, gelé) prévoit encore.
-- Les implémentations public.fn_v2_schedule_emprestimo_return, fn_v2_clear_emprestimo_return_schedule
-- et fn_v2_mark_emprestimo_return_missed restent, fermées (suite circulation_couche_supplantee).
--
-- Relu avant le DROP (11/10, base de production) : prosrc de public/api/private/ingest, pg_views,
-- pg_policies, pg_trigger, cron.job, et le dépôt (src/, supabase/functions/, scripts/) : 0 appelant.
-- Pas de CASCADE : si une dépendance existait, ce DROP échouerait, et c'est voulu.
-- Retour arrière : _rollback_20261012111851_sept_portes_sans_appelant_quittent_le_schema_api.sql
-- recrée les sept telles qu'elles étaient (définitions relevées en production le 11/10) et les referme.

DROP FUNCTION IF EXISTS api.attach_exemplar(bigint, text, text, text, text, date, text, text);
DROP FUNCTION IF EXISTS api.clear_loan_return_schedule(bigint, integer[]);
DROP FUNCTION IF EXISTS api.schedule_loan_return(bigint, integer[], timestamp with time zone);
DROP FUNCTION IF EXISTS api.mark_loan_return_missed(bigint, integer[]);
DROP FUNCTION IF EXISTS api.refuse_pickup_slot(bigint, integer, text);
DROP FUNCTION IF EXISTS api.conv_controle_qualite(text, integer);
DROP FUNCTION IF EXISTS api.conv_controle_resumo();

-- Le cache de schéma PostgREST se recharge de lui-même après un DDL ; rien d'autre à faire.
