// ═══════════════════════════════════════════════════════════════════════════
// AnarBib — Edge Function `altcha-challenge`
// ═══════════════════════════════════════════════════════════════════════════
//
// Sert un défi de preuve de travail au navigateur. C'est le seul point d'entrée
// public de la chaîne Altcha ; toute la vérification se fait ailleurs, dans la
// fonction qui reçoit le formulaire.
//
// PUBLIQUE PAR CONSTRUCTION : elle est appelée avant toute session, sur la page
// d'inscription et sur la cartographie. `verify_jwt = false` dans config.toml.
//
// N'expose rien. Un défi est un nombre aléatoire et sa signature : le connaître
// ne donne aucun pouvoir, il faut encore le résoudre — et la résolution ne vaut
// qu'une fois, grâce à fn_consume_altcha_challenge (AR-4).
//
// Cf. docs/journal/arbitrages/DECISION_anti_robots_2026-08-20.md
// ═══════════════════════════════════════════════════════════════════════════

import { creerDefi } from '../_shared/altcha.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  if (req.method !== 'GET' && req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'content-type': 'application/json; charset=utf-8' },
    });
  }

  try {
    const defi = await creerDefi();
    return new Response(JSON.stringify(defi), {
      status: 200,
      headers: {
        ...corsHeaders,
        'content-type': 'application/json; charset=utf-8',
        // Un défi ne se met pas en cache : deux personnes qui recevraient le
        // même défi consommeraient le même jeton, et la seconde serait refusée
        // par l'anti-rejeu sans rien avoir fait de mal.
        'cache-control': 'no-store',
      },
    });
  } catch (e) {
    // Le cas le plus probable : ALTCHA_HMAC_SECRET absent des secrets Supabase.
    console.error('altcha-challenge:', (e as Error)?.message ?? e);
    return new Response(JSON.stringify({ error: 'challenge_unavailable' }), {
      status: 500,
      headers: { ...corsHeaders, 'content-type': 'application/json; charset=utf-8' },
    });
  }
});
