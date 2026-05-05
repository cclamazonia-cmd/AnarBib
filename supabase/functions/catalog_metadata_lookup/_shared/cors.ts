const envGet = (name)=>{
  const denoEnv = globalThis.Deno;
  if (denoEnv?.env?.get) return denoEnv.env.get(name);
  if (typeof process !== 'undefined' && process.env) return process.env[name];
  return undefined;
};
const allowOrigin = envGet('CATALOG_METADATA_ALLOW_ORIGIN') || '*';
export const corsHeaders = {
  'Access-Control-Allow-Origin': allowOrigin,
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Vary': 'Origin'
};
