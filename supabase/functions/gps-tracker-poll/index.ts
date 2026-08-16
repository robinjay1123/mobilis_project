// @ts-nocheck
// Supabase Edge Function: gps-tracker-poll
// Server-side proxy to poll GPS tracker providers (AIKA168, Traccar)
// Avoids CORS issues when calling from Flutter web.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// AIKA168 reverse-engineered constants (from nyxnyx/gps_obd2_tracker)
const AIKA_APP_KEY = "7DU2DJFDR8321";
const AIKA_DEFAULT_SERVER = "https://en.aika168.com";

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ---------------------------------------------------------------------------
// AIKA168 Provider
// ---------------------------------------------------------------------------

async function aikaDiscoverApiServer(baseServer: string): Promise<string> {
  // The AIKA platform has a discovery endpoint that returns the actual API URL
  const discoveryUrl = `${baseServer}/getapp.aspx`;
  try {
    const resp = await fetch(discoveryUrl, { redirect: "follow" });
    if (resp.ok) {
      const text = (await resp.text()).trim();
      if (text && text.startsWith("http")) {
        return text;
      }
    }
  } catch (e) {
    console.log("AIKA discovery failed, using base server:", e);
  }
  return baseServer;
}

async function aikaLogin(
  apiServer: string,
  deviceIdentifier: string,
  password: string,
): Promise<{ success: boolean; deviceId?: string; model?: string; cookie?: string }> {
  const loginUrl = `${apiServer}/Login`;
  const payload = new URLSearchParams({
    Name: deviceIdentifier,
    Pass: password,
    LoginType: "1",
    LoginAPP: "AKSH",
    GMT: "8:00",
    Key: AIKA_APP_KEY,
  });

  try {
    const resp = await fetch(loginUrl, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: payload.toString(),
    });

    const text = await resp.text();
    let data: any;
    try {
      data = JSON.parse(text);
    } catch {
      console.log("AIKA login response is not JSON:", text.substring(0, 200));
      return { success: false };
    }

    // AIKA returns deviceInfo on success
    if (data && data.deviceInfo) {
      const cookie = resp.headers.get("set-cookie") ?? "";
      return {
        success: true,
        deviceId: data.deviceInfo.ID?.toString() ?? data.deviceInfo.id?.toString() ?? deviceIdentifier,
        model: data.deviceInfo.Model?.toString() ?? data.deviceInfo.model?.toString() ?? "",
        cookie,
      };
    }

    // Some AIKA servers return result code
    if (data && (data.Result === 0 || data.result === 0 || data.code === 0)) {
      return {
        success: true,
        deviceId: data.DeviceID?.toString() ?? data.deviceID?.toString() ?? deviceIdentifier,
        model: data.Model?.toString() ?? "",
        cookie: resp.headers.get("set-cookie") ?? "",
      };
    }

    console.log("AIKA login failed:", JSON.stringify(data).substring(0, 300));
    return { success: false };
  } catch (e) {
    console.error("AIKA login error:", e);
    return { success: false };
  }
}

async function aikaGetLocation(
  apiServer: string,
  deviceId: string,
  model: string,
  cookie?: string,
): Promise<any | null> {
  // Try multiple known AIKA location endpoints
  const endpoints = [
    "/GetLocation",
    "/Ajax/GetLocation.ashx",
    "/Location",
  ];

  const params = new URLSearchParams({
    DeviceID: deviceId,
    Model: model || "",
  });

  const headers: Record<string, string> = {
    "Content-Type": "application/x-www-form-urlencoded",
  };
  if (cookie) {
    headers["Cookie"] = cookie;
  }

  for (const endpoint of endpoints) {
    try {
      const url = `${apiServer}${endpoint}`;
      const resp = await fetch(url, {
        method: "POST",
        headers,
        body: params.toString(),
      });

      if (!resp.ok) continue;

      const text = await resp.text();
      let data: any;
      try {
        data = JSON.parse(text);
      } catch {
        continue;
      }

      // Normalize response - AIKA uses various field names
      const lat = parseFloat(data.lat ?? data.Lat ?? data.latitude ?? data.Latitude ?? "0");
      const lng = parseFloat(data.lng ?? data.Lng ?? data.longitude ?? data.Longitude ?? "0");

      if (lat !== 0 || lng !== 0) {
        return {
          latitude: lat,
          longitude: lng,
          speed_kph: parseFloat(data.speed ?? data.Speed ?? data.spd ?? "0"),
          ignition: data.work === 1 || data.Work === 1 || data.ignition === true || data.ACC === 1,
          online: data.ofl !== 1 && data.Ofl !== 1,
          gps_time: data.positiontime ?? data.PositionTime ?? data.gps_time ?? null,
          battery: parseFloat(data.battery ?? data.Battery ?? "0"),
          status_text: data.state ?? data.State ?? data.status ?? "Connected",
        };
      }
    } catch (e) {
      console.log(`AIKA endpoint ${endpoint} failed:`, e);
    }
  }

  return null;
}

async function pollAika(
  deviceIdentifier: string,
  password: string,
): Promise<{ success: boolean; position?: any; error?: string }> {
  // 1. Discover API server
  const apiServer = await aikaDiscoverApiServer(AIKA_DEFAULT_SERVER);
  console.log("AIKA API server:", apiServer);

  // 2. Login
  const login = await aikaLogin(apiServer, deviceIdentifier, password);
  if (!login.success) {
    return { success: false, error: "AIKA authentication failed. Check IMEI and password." };
  }
  console.log("AIKA login success, deviceId:", login.deviceId);

  // 3. Get location
  const location = await aikaGetLocation(
    apiServer,
    login.deviceId!,
    login.model ?? "",
    login.cookie,
  );

  if (!location) {
    return { success: false, error: "Could not retrieve GPS location from AIKA server." };
  }

  return { success: true, position: location };
}

// ---------------------------------------------------------------------------
// Main Handler
// ---------------------------------------------------------------------------

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const body = await request.json();
    const { device_identifier, password, provider, action } = body;

    if (!device_identifier || !password) {
      return jsonResponse(
        { error: "Missing required fields: device_identifier, password" },
        400,
      );
    }

    const providerName = (provider ?? "aika168").toLowerCase().trim();
    const requestAction = (action ?? "location").toLowerCase().trim();

    if (providerName === "aika168") {
      if (requestAction === "verify") {
        // Just verify credentials (login attempt)
        const apiServer = await aikaDiscoverApiServer(AIKA_DEFAULT_SERVER);
        const login = await aikaLogin(apiServer, device_identifier, password);
        return jsonResponse({
          success: login.success,
          error: login.success ? null : "Authentication failed",
        });
      }

      // Default: fetch location
      const result = await pollAika(device_identifier, password);
      return jsonResponse(result);
    }

    return jsonResponse(
      { error: `Unsupported GPS provider: ${providerName}` },
      400,
    );
  } catch (e) {
    console.error("GPS tracker poll error:", e);
    return jsonResponse({ error: `Internal error: ${e.message}` }, 500);
  }
});
