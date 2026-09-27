// CHEMIN DÉPÔT : supabase/functions/cover-batch/index.ts
//
// La recherche de capas EN LOT (27/09/2026) — la logique vit dans lot.ts.
//
// Déclenchée par pg_cron toutes les 10 minutes (public.fn_capas_lot_call, qui ne
// sonne que s'il reste des notices à chercher), ou à la main avec { limite }.
// L'état vit en base : fn_capas_lot_a_chercher dit quoi chercher,
// fn_capas_lot_enregistrer range les propositions ; aucune n'est posée sans une
// personne (écran de revue, api.capas_revue_accepter).
//
// verify_jwt : false (appel de pg_cron) — déclarée dans supabase/config.toml.
// L'appel est authentifié par le secret partagé des crons (X-Cron-Secret =
// GAZETTE_CRON_SECRET, même domaine de confiance : pg_cron -> nos fonctions),
// jamais par un Bearer, que verify_jwt=false ne vérifie pas.
//
// Déploiement : par la CI (tag deployed-functions). Secrets : SUPABASE_URL,
// SUPABASE_SECRET_KEYS (défaut), GAZETTE_CRON_SECRET.

import { secretKey } from '../_shared/core/secret-key.ts';
import { createClient } from '../_shared/deps.ts';
import { TAILLE_LOT, traiterLot } from './lot.ts';

Deno.serve(async (req) => {
  const attendu = Deno.env.get('GAZETTE_CRON_SECRET');
  if (!attendu || req.headers.get('x-cron-secret') !== attendu) {
    return new Response('forbidden', { status: 403 });
  }
  const corps = await req.json().catch(() => ({}));
  const demandee = Number(corps?.limite);
  const limite = Number.isInteger(demandee) && demandee >= 1 && demandee <= 48 ? demandee : TAILLE_LOT;

  try {
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, secretKey()!, { auth: { persistSession: false } });
    const bilan = await traiterLot({ rpc: (nom, args) => sb.rpc(nom, args) }, limite);
    return Response.json(bilan);
  } catch (e) {
    return Response.json({ ok: false, error: String((e as Error)?.message ?? e).slice(0, 500) }, { status: 500 });
  }
});
