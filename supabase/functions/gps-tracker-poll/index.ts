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
const AIKA_SERVERS = [
  "http://en.aika168.com",
  "http://www.aika168.com",
  "http://app.aika168.com",
  "https://en.aika168.com",
  "https://www.aika168.com",
];

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
  const discoveryUrl = `${baseServer}/getapp.aspx`;
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 4000);
    const resp = await fetch(discoveryUrl, { redirect: "follow", signal: controller.signal });
    clearTimeout(timeout);
    if (resp.ok) {
      const text = (await resp.text()).trim();
      if (text && text.startsWith("http")) {
        return text.replace(/\/$/, "");
      }
    }
  } catch (e) {
    // Discovery endpoint failed, fallback
  }
  return baseServer.replace(/\/$/, "");
}

async function aikaLogin(
  apiServer: string,
  deviceIdentifier: string,
  password: string,
): Promise<{ success: boolean; deviceId?: string; model?: string; cookie?: string; serverUsed?: string }> {
  const loginEndpoints = ["/Login", "/Login.aspx", "/Ajax/Login.ashx", "/login.aspx"];
  const passwordsToTry = [password, "123456", "000000"].filter(
    (p, idx, arr) => Boolean(p) && arr.indexOf(p) === idx
  );

  for (const pass of passwordsToTry) {
    const payload = new URLSearchParams({
      Name: deviceIdentifier,
      Pass: pass,
      LoginType: "1",
      LoginAPP: "AKSH",
      GMT: "8:00",
      Key: AIKA_APP_KEY,
    });

    for (const endpoint of loginEndpoints) {
      try {
        const loginUrl = `${apiServer}${endpoint}`;
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 6000);
        const resp = await fetch(loginUrl, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: payload.toString(),
          signal: controller.signal,
        });
        clearTimeout(timeout);

        const text = await resp.text();
        let data: any;
        try {
          data = JSON.parse(text);
        } catch {
          continue;
        }

        if (data && data.deviceInfo) {
          const cookie = resp.headers.get("set-cookie") ?? "";
          return {
            success: true,
            deviceId:
              data.deviceInfo.ID?.toString() ??
              data.deviceInfo.id?.toString() ??
              deviceIdentifier,
            model:
              data.deviceInfo.Model?.toString() ??
              data.deviceInfo.model?.toString() ??
              "",
            cookie,
            serverUsed: apiServer,
          };
        }

        if (data && (data.Result === 0 || data.result === 0 || data.code === 0)) {
          return {
            success: true,
            deviceId:
              data.DeviceID?.toString() ??
              data.deviceID?.toString() ??
              deviceIdentifier,
            model: data.Model?.toString() ?? "",
            cookie: resp.headers.get("set-cookie") ?? "",
            serverUsed: apiServer,
          };
        }
      } catch (e) {
        // Continue to next endpoint
      }
    }
  }

  return { success: false };
}

async function aikaGetLocation(
  apiServer: string,
  deviceId: string,
  model: string,
  cookie?: string,
): Promise<any | null> {
  const endpoints = [
    "/GetLocation",
    "/Ajax/GetLocation.ashx",
    "/Location",
    "/getlocation.aspx",
    "/GetLocation.aspx",
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
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 6000);
      const resp = await fetch(url, {
        method: "POST",
        headers,
        body: params.toString(),
        signal: controller.signal,
      });
      clearTimeout(timeout);

      if (!resp.ok) continue;

      const text = await resp.text();
      let data: any;
      try {
        data = JSON.parse(text);
      } catch {
        continue;
      }

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
          status_text: data.state ?? data.State ?? data.status ?? "GPS Online",
        };
      }
    } catch (e) {
      // Continue to next endpoint
    }
  }

  return null;
}

async function pollAika(
  deviceIdentifier: string,
  password: string,
): Promise<{ success: boolean; position?: any; error?: string; diagnostics?: any }> {
  const triedServers: string[] = [];

  for (const baseServer of AIKA_SERVERS) {
    try {
      const apiServer = await aikaDiscoverApiServer(baseServer);
      triedServers.push(apiServer);

      const login = await aikaLogin(apiServer, deviceIdentifier, password);
      if (!login.success) continue;

      const location = await aikaGetLocation(
        apiServer,
        login.deviceId!,
        login.model ?? "",
        login.cookie,
      );

      if (location) {
        return {
          success: true,
          position: location,
          diagnostics: { server: apiServer, deviceId: login.deviceId },
        };
      }
    } catch (err) {
      // Try next server
    }
  }

  return {
    success: false,
    error: `Could not retrieve live coordinates for device ${deviceIdentifier} from AIKA servers.`,
    diagnostics: { triedServers },
  };
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

    if (!device_identifier) {
      return jsonResponse(
        { error: "Missing required field: device_identifier" },
        400,
      );
    }

    const cleanPassword = (password ?? "123456").toString().trim();
    const providerName = (provider ?? "aika168").toLowerCase().trim();
    const requestAction = (action ?? "location").toLowerCase().trim();

    if (providerName === "aika168") {
      if (requestAction === "verify") {
        for (const baseServer of AIKA_SERVERS) {
          const apiServer = await aikaDiscoverApiServer(baseServer);
          const login = await aikaLogin(apiServer, device_identifier, cleanPassword);
          if (login.success) {
            return jsonResponse({ success: true, server: apiServer });
          }
        }
        return jsonResponse({
          success: false,
          error: "Authentication failed with AIKA server. Please check IMEI.",
        });
      }

      // Default: fetch location
      const result = await pollAika(device_identifier, cleanPassword);
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
