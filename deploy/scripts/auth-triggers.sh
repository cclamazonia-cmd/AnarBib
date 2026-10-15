#!/bin/sh
# =============================================================================
# AnarBib — les deux triggers de profil sur auth.users
# =============================================================================
# En production, deux triggers lient auth.users à public.profiles :
#   - on_auth_user_created_profile  (AFTER INSERT)          → crée le profil ;
#   - on_auth_user_email_changed    (AFTER UPDATE OF email) → suit le courriel.
# Les deux FONCTIONS sont dans le socle (20260510000000_baseline_live.sql), mais
# aucune migration ne pose les TRIGGERS : la base de test CI reconstruit `auth`
# depuis un stub et 74 suites insèrent dans auth.users puis créent leur profil
# elles-mêmes — un trigger dans les migrations les casserait (voir le commentaire
# de 20260702081711_pseudonymisation_bg2_14_fk_fix.sql). Sur une instance
# auto-hébergée, sans ces triggers, la création d'un compte laisse profiles
# vide et la fonction `register` répond PUBLIC_ID_NOT_READY.
# Diagnostic : le camarade (ASR2026), PR #34 du 15/10/2026, sur la VM d'essai.
#
# Ce script se lance APRÈS les migrations (les fonctions doivent exister) :
#   - bootstrap.sh, étape 5 ter, dans les deux modes (dépôt ou sauvegarde :
#     `supabase db dump` n'emporte pas les triggers du schéma `auth`) ;
#   - install.sh, après apply-pending-migrations.sh, pour une instance qui
#     existait déjà — celle de la VM d'essai, par exemple.
#
# Idempotent (CREATE OR REPLACE TRIGGER, PostgreSQL 14+). Il ne dit « ✓ » que
# si les deux triggers sont bel et bien dans pg_trigger ; sinon il sort en 1.
#
#   docker compose exec db sh /scripts/auth-triggers.sh
# =============================================================================

SU=""
for candidat in supabase_admin postgres; do
  if psql -U "$candidat" -d postgres -tAc "select 1" >/dev/null 2>&1; then
    SU="$candidat"; break
  fi
done
if [ -z "$SU" ]; then
  echo "✗ Impossible de se connecter à Postgres."
  exit 1
fi

if [ "$(psql -U "$SU" -d postgres -tAc "select to_regclass('auth.users') is not null")" != "t" ]; then
  echo "✗ auth.users absent : GoTrue n'a pas encore construit le schéma (étape 4 de bootstrap.sh)."
  exit 1
fi

MANQUANTES=$(psql -U "$SU" -d postgres -tAc "
  select string_agg(f, ', ')
    from unnest(array['handle_auth_user_created_profile','sync_profile_email_on_auth_change']) f
   where not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                      where n.nspname = 'public' and p.proname = f)")
if [ -n "$MANQUANTES" ]; then
  echo "✗ Fonction(s) absente(s) de public : $MANQUANTES — les migrations ne sont pas passées."
  exit 1
fi

if ! psql -U "$SU" -d postgres -v ON_ERROR_STOP=1 -q <<'SQL'
CREATE OR REPLACE TRIGGER on_auth_user_created_profile
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_auth_user_created_profile();

CREATE OR REPLACE TRIGGER on_auth_user_email_changed
  AFTER UPDATE OF email ON auth.users
  FOR EACH ROW
  WHEN (new.email IS DISTINCT FROM old.email)
  EXECUTE FUNCTION public.sync_profile_email_on_auth_change();
SQL
then
  echo "✗ La pose des triggers sur auth.users a échoué."
  exit 1
fi

NB=$(psql -U "$SU" -d postgres -tAc "
  select count(*) from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'auth' and c.relname = 'users' and not t.tgisinternal
     and t.tgname in ('on_auth_user_created_profile','on_auth_user_email_changed')")
if [ "$NB" != "2" ]; then
  echo "✗ $NB trigger(s) de profil sur auth.users au lieu de 2."
  exit 1
fi

echo "✓ Triggers de profil sur auth.users : on_auth_user_created_profile, on_auth_user_email_changed."
