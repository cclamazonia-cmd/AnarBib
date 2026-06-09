// Edge Function : export-catalog-lote (Lot 5, IMP-13).
//
// Session : Lot 5 — Export de lote
// Auteur  : Claude Opus 4.8
//
// ⚠️ STUB TEMPORAIRE. Le serialiseur (serialize.ts) est pret et teste, mais la
// logique d'acces (coordenador, IMP-14), la requete catalogue scopee biblio et
// la livraison du fichier arrivent dans la SUITE du Lot 5. Cet entrypoint existe
// pour que `supabase functions deploy` reussisse : sans index.ts, le deploiement
// de TOUTES les Edge Functions s'interrompt (boucle CI en `set -e`).
//
// Aucune surface frontend n'invoque encore cette fonction.

import { SERIALIZER_VERSION, SUPPORTED_FORMATS } from './serialize.ts';

Deno.serve(() =>
  new Response(
    JSON.stringify({
      error: 'export-catalog-lote: not yet implemented (Lot 5 in progress).',
      serializer_version: SERIALIZER_VERSION,
      supported_formats: SUPPORTED_FORMATS,
    }),
    { status: 501, headers: { 'Content-Type': 'application/json; charset=utf-8' } },
  )
);
