import { createClient } from 'npm:@supabase/supabase-js@2';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
};
function json(status, payload) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store'
    }
  });
}
function sanitizeFilename(value) {
  return (value || 'document').replace(/[^a-zA-Z0-9._-]+/g, '_').replace(/^_+|_+$/g, '') || 'document';
}
Deno.serve(async (req)=>{
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  if (req.method !== 'GET' && req.method !== 'POST') {
    return json(405, {
      error: 'method_not_allowed'
    });
  }
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
    return json(500, {
      error: 'missing_edge_env'
    });
  }
  const authHeader = req.headers.get('Authorization') || '';
  if (!authHeader.startsWith('Bearer ')) {
    return json(401, {
      error: 'missing_or_invalid_bearer_token'
    });
  }
  const token = authHeader.slice('Bearer '.length).trim();
  if (!token) {
    return json(401, {
      error: 'missing_or_invalid_bearer_token'
    });
  }
  let bibRef = null;
  if (req.method === 'GET') {
    const url = new URL(req.url);
    bibRef = url.searchParams.get('bib_ref') || url.searchParams.get('ref');
  } else {
    try {
      const body = await req.json();
      bibRef = body?.bib_ref ?? body?.ref ?? null;
    } catch  {
      return json(400, {
        error: 'invalid_json_body'
      });
    }
  }
  bibRef = typeof bibRef === 'string' ? bibRef.trim() : null;
  if (!bibRef) {
    return json(400, {
      error: 'missing_bib_ref'
    });
  }
  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: {
        Authorization: authHeader
      }
    },
    auth: {
      persistSession: false,
      autoRefreshToken: false
    }
  });
  // Validation canonique de l'utilisateur via la couche SQL user-scoped
  const { data: sessionCtx, error: sessionCtxError } = await userClient.from('my_session_context').select('user_id, is_authenticated, can_access_conta').maybeSingle();
  if (sessionCtxError || !sessionCtx?.user_id || sessionCtx?.is_authenticated !== true) {
    return json(401, {
      error: 'invalid_or_expired_user_token',
      details: sessionCtxError?.message ?? 'Auth session missing!',
      auth_header_present: !!authHeader,
      token_length: token.length
    });
  }
  const { error: ensureProfileError } = await userClient.rpc('fn_ensure_current_user_profile');
  if (ensureProfileError) {
    return json(500, {
      error: 'ensure_profile_failed',
      details: ensureProfileError.message
    });
  }
  const { data: readState, error: readStateError } = await userClient.rpc('fn_book_restricted_pdf_state_for_current_user', {
    p_bib_ref: bibRef
  });
  if (readStateError) {
    return json(500, {
      error: 'restricted_read_state_failed',
      details: readStateError.message
    });
  }
  const row = Array.isArray(readState) ? readState[0] : readState && typeof readState === 'object' ? readState : null;
  if (!row?.book_exists) {
    return json(404, {
      error: 'book_not_found'
    });
  }
  if (!row?.can_show_read_button) {
    return json(403, {
      error: 'reading_not_allowed',
      user_account_active: row?.user_account_active ?? false,
      has_reading_resource: row?.has_reading_resource ?? false,
      resource_status: row?.resource_status ?? null,
      file_exists: row?.file_exists ?? false
    });
  }
  const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false
    }
  });
  const { data: resource, error: resourceError } = await adminClient.from('book_digital_resources').select('storage_bucket, storage_path').eq('book_id', row.book_id).eq('resource_type', 'pdf_restrito').eq('usage_type', 'leitura_online').eq('access_scope', 'conta_ativa').eq('status', 'active').eq('is_active', true).order('updated_at', {
    ascending: false
  }).order('created_at', {
    ascending: false
  }).order('id', {
    ascending: false
  }).limit(1).maybeSingle();
  if (resourceError) {
    return json(500, {
      error: 'resource_lookup_failed',
      details: resourceError.message
    });
  }
  if (!resource?.storage_bucket || !resource?.storage_path) {
    return json(404, {
      error: 'active_pdf_resource_not_found'
    });
  }
  const { data: fileBlob, error: downloadError } = await adminClient.storage.from(resource.storage_bucket).download(resource.storage_path);
  if (downloadError || !fileBlob) {
    return json(404, {
      error: 'pdf_file_not_found',
      details: downloadError?.message ?? null
    });
  }
  const bytes = await fileBlob.arrayBuffer();
  const filename = `${sanitizeFilename(bibRef)}.pdf`;
  return new Response(bytes, {
    status: 200,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/pdf',
      'Content-Disposition': `inline; filename="${filename}"`,
      'Cache-Control': 'private, no-store, max-age=0',
      'X-Content-Type-Options': 'nosniff'
    }
  });
});
