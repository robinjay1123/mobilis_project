// @ts-nocheck
import { createClient } from 'npm:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const adminClient = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'Missing Supabase server configuration' }, 500);
  }

  const authorization = request.headers.get('Authorization') ?? '';
  const accessToken = authorization.replace(/^Bearer\s+/i, '').trim();
  if (!accessToken) {
    return jsonResponse({ error: 'Authentication is required' }, 401);
  }

  const { data: callerData, error: callerError } =
    await adminClient.auth.getUser(accessToken);
  if (callerError || !callerData.user) {
    return jsonResponse({ error: 'Invalid or expired admin session' }, 401);
  }

  const { data: callerProfile, error: profileError } = await adminClient
    .from('users')
    .select('role, is_blocked')
    .eq('id', callerData.user.id)
    .maybeSingle();
  if (profileError) {
    return jsonResponse({ error: profileError.message }, 500);
  }
  if (callerProfile?.role !== 'admin' || callerProfile?.is_blocked === true) {
    return jsonResponse(
      { error: 'Only an active administrator can create operators' },
      403,
    );
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch (_) {
    return jsonResponse({ error: 'Invalid request body' }, 400);
  }

  const fullName = String(body.full_name ?? '').trim();
  const email = String(body.email ?? '').trim().toLowerCase();
  const phone = body.phone == null ? null : String(body.phone).trim();
  const password = String(body.password ?? '');

  if (fullName.length < 2) {
    return jsonResponse({ error: 'Operator full name is required' }, 400);
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return jsonResponse({ error: 'A valid email address is required' }, 400);
  }
  const passwordError = validatePassword(password);
  if (passwordError) {
    return jsonResponse({ error: passwordError }, 400);
  }
  if (phone && !/^\+?\d{10,12}$/.test(phone)) {
    return jsonResponse({ error: 'Phone number must contain 10 to 12 digits' }, 400);
  }

  const { data: created, error: createError } =
    await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: fullName,
        name: fullName,
        phone,
        role: 'operator',
      },
      app_metadata: { role: 'operator' },
    });
  if (createError || !created.user) {
    return jsonResponse(
      { error: createError?.message ?? 'Could not create operator login' },
      400,
    );
  }

  const operatorId = created.user.id;
  const { error: userError } = await adminClient.from('users').upsert(
    {
      id: operatorId,
      name: fullName,
      full_name: fullName,
      email,
      phone: phone || null,
      role: 'operator',
      status: 'active',
      id_verified: true,
      verification_status: 'verified',
      is_blocked: false,
      is_available: false,
    },
    { onConflict: 'id' },
  );

  if (userError) {
    await adminClient.auth.admin.deleteUser(operatorId);
    return jsonResponse(
      { error: `Operator profile could not be saved: ${userError.message}` },
      500,
    );
  }

  return jsonResponse(
    {
      operator: {
        id: operatorId,
        full_name: fullName,
        email,
        phone,
        role: 'operator',
      },
    },
    201,
  );
});

function validatePassword(password: string): string | null {
  if (password.length < 8) return 'Password must contain at least 8 characters';
  if (!/[A-Z]/.test(password)) return 'Password needs an uppercase letter';
  if (!/[a-z]/.test(password)) return 'Password needs a lowercase letter';
  if (!/[0-9]/.test(password)) return 'Password needs a number';
  if (!/[^A-Za-z0-9]/.test(password)) {
    return 'Password needs a special character';
  }
  return null;
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}
