// @ts-nocheck
import { createClient } from 'npm:@supabase/supabase-js@2';

type QueueRow = {
  id: string;
  push_token: string;
  title: string;
  message: string;
  type: string;
  payload: Record<string, unknown> | null;
};

type FirebaseServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
};

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const configuredProjectId = Deno.env.get('FCM_PROJECT_ID') ?? '';
const firebaseServiceAccountJson =
  Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON') ?? '';

const supabase = createClient(supabaseUrl, serviceRoleKey);

Deno.serve(async () => {
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      { error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY' },
      500,
    );
  }

  if (!firebaseServiceAccountJson) {
    return jsonResponse(
      {
        error:
          'Missing FIREBASE_SERVICE_ACCOUNT_JSON. Add your Firebase admin SDK JSON as a Supabase secret.',
      },
      500,
    );
  }

  let serviceAccount: FirebaseServiceAccount;
  try {
    serviceAccount = JSON.parse(
      firebaseServiceAccountJson,
    ) as FirebaseServiceAccount;
  } catch (error) {
    return jsonResponse(
      {
        error: `FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON: ${
          error instanceof Error ? error.message : String(error)
        }`,
      },
      500,
    );
  }

  const projectId = configuredProjectId || serviceAccount.project_id;
  if (!projectId || !serviceAccount.client_email || !serviceAccount.private_key) {
    return jsonResponse(
      {
        error:
          'Firebase service account JSON is missing project_id, client_email, or private_key.',
      },
      500,
    );
  }

  let accessToken = '';
  try {
    accessToken = await getAccessToken(serviceAccount);
  } catch (error) {
    return jsonResponse(
      {
        error: `Failed to generate FCM access token: ${
          error instanceof Error ? error.message : String(error)
        }`,
      },
      500,
    );
  }

  const { data, error } = await supabase
    .from('push_notification_queue')
    .select('id, push_token, title, message, type, payload')
    .eq('status', 'pending')
    .order('created_at', { ascending: true })
    .limit(50);

  if (error) {
    return jsonResponse({ error: error.message }, 500);
  }

  const queueRows = (data ?? []) as QueueRow[];
  const results: Array<Record<string, unknown>> = [];

  for (const row of queueRows) {
    try {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: row.push_token,
              notification: {
                title: row.title,
                body: row.message,
              },
              data: normalizePayload(row),
            },
          }),
        },
      );

      const responseText = await response.text();

      if (!response.ok) {
        await markQueueRow(row.id, 'failed', responseText);
        results.push({
          id: row.id,
          status: 'failed',
          response: responseText,
        });
        continue;
      }

      await supabase
        .from('push_notification_queue')
        .update({
          status: 'sent',
          sent_at: new Date().toISOString(),
          error_message: null,
        })
        .eq('id', row.id);

      results.push({
        id: row.id,
        status: 'sent',
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      await markQueueRow(row.id, 'failed', message);
      results.push({
        id: row.id,
        status: 'failed',
        response: message,
      });
    }
  }

  return jsonResponse({
    processed: results.length,
    results,
  });
});

function normalizePayload(row: QueueRow): Record<string, string> {
  const payload = row.payload ?? {};
  const normalizedEntries = Object.entries(payload).map(([key, value]) => [
    key,
    value == null ? '' : String(value),
  ]);

  return {
    ...Object.fromEntries(normalizedEntries),
    queue_id: row.id,
    notification_type: row.type,
  };
}

async function getAccessToken(
  serviceAccount: FirebaseServiceAccount,
): Promise<string> {
  const issuedAt = Math.floor(Date.now() / 1000);
  const expiresAt = issuedAt + 3600;
  const tokenUri = serviceAccount.token_uri || 'https://oauth2.googleapis.com/token';

  const header = {
    alg: 'RS256',
    typ: 'JWT',
  };

  const claimSet = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: tokenUri,
    iat: issuedAt,
    exp: expiresAt,
  };

  const unsignedToken = `${base64UrlEncodeJson(header)}.${base64UrlEncodeJson(
    claimSet,
  )}`;
  const signature = await signJwt(unsignedToken, serviceAccount.private_key);
  const assertion = `${unsignedToken}.${signature}`;

  const response = await fetch(tokenUri, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  const tokenResponse = await response.json();
  if (!response.ok || !tokenResponse.access_token) {
    throw new Error(JSON.stringify(tokenResponse));
  }

  return tokenResponse.access_token as string;
}

async function signJwt(data: string, privateKeyPem: string): Promise<string> {
  const pemContents = privateKeyPem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '');

  const keyBuffer = base64Decode(pemContents);
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBuffer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(data),
  );

  return base64UrlEncode(signature);
}

function base64UrlEncodeJson(value: Record<string, unknown>): string {
  return base64UrlEncode(new TextEncoder().encode(JSON.stringify(value)));
}

function base64UrlEncode(data: BufferSource): string {
  const bytes = data instanceof Uint8Array ? data : new Uint8Array(data);
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function base64Decode(value: string): ArrayBuffer {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const padding = normalized.length % 4 === 0
    ? ''
    : '='.repeat(4 - (normalized.length % 4));
  const binary = atob(`${normalized}${padding}`);
  const bytes = new Uint8Array(binary.length);

  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }

  return bytes.buffer;
}

async function markQueueRow(
  id: string,
  status: 'failed' | 'pending' | 'sent',
  errorMessage: string | null,
) {
  await supabase
    .from('push_notification_queue')
    .update({
      status,
      error_message: errorMessage,
    })
    .eq('id', id);
}

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: {
      'Content-Type': 'application/json',
    },
  });
}
