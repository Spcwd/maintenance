import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function respond(body: Record<string, string>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return respond({ error: 'Method not allowed' }, 405);
  }

  const authorization = request.headers.get('Authorization');
  const token = authorization?.replace(/^Bearer\s+/i, '');
  if (!token) return respond({ error: 'Authentication required' }, 401);

  let payload: { userId?: unknown; password?: unknown };
  try {
    payload = await request.json();
  } catch {
    return respond({ error: 'Invalid request body' }, 400);
  }

  const userId =
    typeof payload.userId === 'string' ? payload.userId.trim() : '';
  const password =
    typeof payload.password === 'string' ? payload.password : '';
  if (!userId || password.length < 6) {
    return respond(
      { error: 'A target account and a password of at least 6 characters are required' },
      400,
    );
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error('Required Supabase Edge Function environment variables are missing');
    return respond({ error: 'Password service is not configured' }, 500);
  }

  const authClient = createClient(supabaseUrl, anonKey);
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: authData, error: authError } =
    await authClient.auth.getUser(token);
  if (authError || !authData.user) {
    return respond({ error: 'Authentication required' }, 401);
  }

  const { data: profile, error: profileError } = await adminClient
    .from('profiles')
    .select('role')
    .eq('id', authData.user.id)
    .maybeSingle();
  if (profileError) {
    console.error('Could not verify administrator role:', profileError.message);
    return respond({ error: 'Could not verify administrator permissions' }, 500);
  }
  if (profile?.role !== 'admin') {
    return respond({ error: 'Only administrators can change account passwords' }, 403);
  }

  const { error: updateError } = await adminClient.auth.admin.updateUserById(
    userId,
    { password },
  );
  if (updateError) {
    console.error('Could not update account password:', updateError.message);
    return respond({ error: 'Could not update the account password' }, 400);
  }

  return respond({ message: 'Password updated' });
});
