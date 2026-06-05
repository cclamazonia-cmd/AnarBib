---
description: Passe les security advisors Supabase (MCP) et resume ERROR/WARN par regle. Ne corrige rien en direct.
---
Tu vas auditer la securite de la base Supabase d'AnarBib (project_id uflwmikiyjfnikiphtcp).

Etapes :
1. Appelle l'outil MCP Supabase get_advisors avec type "security". Si je precise "perf", refais avec type "performance".
2. Resume-moi les resultats GROUPES PAR REGLE : nom de la regle, niveau (ERROR/WARN/INFO), nombre d'occurrences, du plus grave au moins grave. Pour chaque regle, donne le lien de remediation cliquable.
3. Pour chaque ERROR et chaque WARN sensible (fuite anon, SECURITY DEFINER expose, RLS manquante, bucket public listable), explique en UNE phrase le risque concret.
4. NE CORRIGE RIEN directement. Doctrine : execute_sql = inspection/lecture SEULE ; JAMAIS apply_migration, create_branch ni deploy_edge_function via MCP. Toute correction se livre en FICHIER de migration dans supabase/migrations/, puis passe par /commit-migration et le push (c'est Woodpecker qui applique).
5. Si je valide une correction, propose-moi le fichier de migration COMPLET, conforme a la doctrine : SET search_path ; REVOKE EXECUTE FROM PUBLIC, anon, authenticated, service_role (pas seulement PUBLIC) ; RLS ENABLE + policy ; GRANT cible ; security_invoker=true sur les vues ; NOTIFY pgrst en fin si schema change.
