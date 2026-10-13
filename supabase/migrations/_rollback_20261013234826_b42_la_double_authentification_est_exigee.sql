-- Retour arrière de 20261013234826_b42_la_double_authentification_est_exigee.sql
-- Retour arrière de l'activation B42 (mode 'facteurs', fonction d'avant-requête branchée).
-- Débranche la fonction (PostgREST ne l'appelle plus) et remet le mode à 'off' : Storage et
-- Edge Functions cessent d'exiger aussitôt. La correction de DETAIL (status + headers) est
-- gardée : elle ne fait rien tant que rien n'est branché.
-- Fichier préfixé « _rollback_ » : jamais appliqué par la CI, à jouer à la main si besoin
-- (tracé : DOC-DEPLOY-3).

ALTER ROLE authenticator RESET pgrst.db_pre_request;
NOTIFY pgrst, 'reload config';
UPDATE private.double_facteur_reglage SET mode = 'off', modifie_le = now() WHERE id;
