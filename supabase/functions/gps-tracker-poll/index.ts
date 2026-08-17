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
  const loginEndpoints = ["/Login", "/Login.aspx", "/Ajax/Login.ashx", "/login.aspx", "/Ajax/login.ashx"];
  const passwordsToTry = [password, "123456", "000000"].filter(
    (p, idx, arr) => Boolean(p) && arr.indexOf(p) === idx
  );

  const raw = deviceIdentifier.trim();
  const last5 = raw.slice(-5);
  const nameCandidates = [
    raw,
    `AK-${last5}`,
    `AK-${raw}`,
    raw.replace(/^AK-?/i, ""),
    `0${raw}`,
  ].filter((v, idx, arr) => Boolean(v) && arr.indexOf(v) === idx);

  for (const name of nameCandidates) {
    for (const pass of passwordsToTry) {
      for (const loginType of ["1", "2"]) {
        // App payload
        const payload = new URLSearchParams({
          Name: name,
          Pass: pass,
          LoginType: loginType,
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

            const cookie = resp.headers.get("set-cookie") ?? "";
            const text = await resp.text();
            let data: any = null;
            try {
              data = JSON.parse(text);
            } catch {
              // Not JSON, check if redirect or cookie is set for Monitor.aspx
              if (resp.status === 200 || resp.status === 302) {
                if (cookie && (cookie.includes("ASP.NET_SessionId") || cookie.includes("Token") || cookie.includes("user"))) {
                  return {
                    success: true,
                    deviceId: name,
                    model: "AK",
                    cookie,
                    serverUsed: apiServer,
                  };
                }
              }
            }

            if (data && data.deviceInfo) {
              return {
                success: true,
                deviceId:
                  data.deviceInfo.ID?.toString() ??
                  data.deviceInfo.id?.toString() ??
                  name,
                model:
                  data.deviceInfo.Model?.toString() ??
                  data.deviceInfo.model?.toString() ??
                  "AK",
                cookie,
                serverUsed: apiServer,
              };
            }

            if (data && (data.Result === 0 || data.result === 0 || data.code === 0 || data.success === true)) {
              return {
                success: true,
                deviceId:
                  data.DeviceID?.toString() ??
                  data.deviceID?.toString() ??
                  data.id?.toString() ??
                  name,
                model: data.Model?.toString() ?? "AK",
                cookie,
                serverUsed: apiServer,
              };
            }
          } catch {
            // Continue
          }
        }

        // Also try web query format: /Ajax/Login.ashx?action=login&username=...&password=...
        try {
          const webLoginUrl = `${apiServer}/Ajax/Login.ashx?action=login&username=${encodeURIComponent(name)}&password=${encodeURIComponent(pass)}&loginType=${loginType}`;
          const controller = new AbortController();
          const timeout = setTimeout(() => controller.abort(), 6000);
          const resp = await fetch(webLoginUrl, { signal: controller.signal });
          clearTimeout(timeout);
          const cookie = resp.headers.get("set-cookie") ?? "";
          const text = await resp.text();
          if (resp.ok && (text.includes("true") || text.includes("1") || text.includes("success") || cookie.length > 5)) {
            return {
              success: true,
              deviceId: name,
              model: "AK",
              cookie,
              serverUsed: apiServer,
            };
          }
        } catch {
          // Continue
        }
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
    "/Ajax/GetMonitor.ashx",
    "/Ajax/GetDeviceList.ashx",
    "/Ajax/Devices.ashx",
    "/Location",
    "/getlocation.aspx",
    "/GetLocation.aspx",
    "/Monitor.aspx",
  ];

  const params = new URLSearchParams({
    DeviceID: deviceId,
    Model: model || "AK",
    action: "getlocation",
    id: deviceId,
  });

  const headers: Record<string, string> = {
    "Content-Type": "application/x-www-form-urlencoded",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
  };
  if (cookie) {
    headers["Cookie"] = cookie;
  }

  for (const endpoint of endpoints) {
    try {
      const url = `${apiServer}${endpoint}`;
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 6000);
      const isGet = endpoint.endsWith(".aspx") || endpoint.includes("Monitor");
      const resp = await fetch(url, {
        method: isGet ? "GET" : "POST",
        headers,
        body: isGet ? undefined : params.toString(),
        signal: controller.signal,
      });
      clearTimeout(timeout);

      if (!resp.ok) continue;

      const text = await resp.text();
      let data: any = null;
      try {
        data = JSON.parse(text);
      } catch {
        // Parse from HTML table (like Monitor.aspx)
        const latMatch = text.match(/Latitude[^0-9]*([0-9]+\.[0-9]+)/i) ||
          text.match(/([0-9]{2}\.[0-9]{4,8})[\s,]+([0-9]{3}\.[0-9]{4,8})/);
        const lngMatch = text.match(/Longitude[^0-9]*([0-9]+\.[0-9]+)/i);

        if (latMatch && lngMatch) {
          const lat = parseFloat(latMatch[1]);
          const lng = parseFloat(lngMatch[1]);
          if (lat > 0 && lng > 0) {
            return {
              latitude: lat,
              longitude: lng,
              speed_kph: 0.0,
              ignition: !text.includes("ACC OFF"),
              online: !text.includes("Offline"),
              gps_time: new Date().toISOString(),
              battery: 100,
              status_text: "Online via AIKA Monitor",
            };
          }
        }
      }

      if (data) {
        if (Array.isArray(data) && data.length > 0) {
          data = data[0];
        }
        if (data.data && Array.isArray(data.data) && data.data.length > 0) {
          data = data.data[0];
        }

        const lat = parseFloat(data.lat ?? data.Lat ?? data.latitude ?? data.Latitude ?? data.B_Lat ?? "0");
        const lng = parseFloat(data.lng ?? data.Lng ?? data.longitude ?? data.Longitude ?? data.B_Lng ?? "0");

        if (lat !== 0 || lng !== 0) {
          return {
            latitude: lat,
            longitude: lng,
            speed_kph: parseFloat(data.speed ?? data.Speed ?? data.spd ?? "0"),
            ignition: data.work === 1 || data.Work === 1 || data.ignition === true || data.ACC === 1 || data.acc === "ON",
            online: data.ofl !== 1 && data.Ofl !== 1 && data.online !== false,
            gps_time: data.positiontime ?? data.PositionTime ?? data.gps_time ?? data.time ?? null,
            battery: parseFloat(data.battery ?? data.Battery ?? "100"),
            status_text: data.state ?? data.State ?? data.status ?? "GPS Online",
          };
        }
      }
    } catch {
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
        login.model ?? "AK",
        login.cookie,
      );

      if (location) {
        return {
          success: true,
          position: location,
          diagnostics: { server: apiServer, deviceId: login.deviceId },
        };
      }
    } catch {
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
