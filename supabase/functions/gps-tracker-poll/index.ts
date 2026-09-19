// @ts-nocheck
// Supabase Edge Function: gps-tracker-poll
// Server-side proxy to poll GPS tracker providers (AIKA168, Traccar)
// Avoids CORS issues and uses authentic AIKA Web Forms + ASMX reverse-engineered protocol.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const AIKA_SERVERS = [
  "http://en.aika168.com",
  "http://www.aika168.com",
];

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ---------------------------------------------------------------------------
// AIKA168 Web Forms & ASMX Provider
// ---------------------------------------------------------------------------

interface AikaSession {
  success: boolean;
  cookie: string;
  server: string;
  internalDeviceId?: number;
  error?: string;
}

function extractCookie(resp: Response): string {
  try {
    if (typeof resp.headers.getSetCookie === "function") {
      const list = resp.headers.getSetCookie();
      if (list && list.length > 0) {
        return list.map((c: string) => c.split(";")[0]).join("; ");
      }
    }
  } catch (_) {}

  const raw = resp.headers.get("set-cookie") ?? "";
  const match = raw.match(/ASP\.NET_SessionId=[^;]+/i);
  return match ? match[0] : raw.split(";")[0];
}

async function aikaLoginWebForms(
  baseServer: string,
  identifier: string,
  password: string,
  logs?: any[],
): Promise<AikaSession> {
  const cleanId = identifier.trim();
  const cleanPass = password.trim();

  // Try both IMEI format (e.g. 9210186615) and Account format (e.g. AK-86615)
  const last5 = cleanId.slice(-5);
  const candidates = [
    { type: "imei", id: cleanId.replace(/^AK-?/i, "") },
    { type: "imei", id: cleanId },
    { type: "account", id: cleanId.startsWith("AK-") ? cleanId : `AK-${last5}` },
    { type: "account", id: cleanId },
  ];

  for (const cand of candidates) {
    try {
      // 1. Initial GET to obtain session cookie & ASP.NET state
      const initUrl = `${baseServer}/Login.aspx`;
      const initResp = await fetch(initUrl, {
        signal: AbortSignal.timeout(6000),
        headers: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
      });

      if (!initResp.ok) {
        logs?.push({ step: "init_get_failed", server: baseServer, status: initResp.status });
        continue;
      }

      let sessionCookie = extractCookie(initResp);
      const initHtml = await initResp.text();

      const vsMatch = initHtml.match(/id="__VIEWSTATE"\s+value="([^"]+)"/i);
      const evMatch = initHtml.match(/id="__EVENTVALIDATION"\s+value="([^"]+)"/i);

      if (!vsMatch) {
        logs?.push({ step: "no_viewstate", server: baseServer, htmlSnippet: initHtml.substring(0, 150) });
        continue;
      }

      // 2. Submit Login Form
      const postParams = new URLSearchParams();
      postParams.append("__VIEWSTATE", vsMatch[1]);
      if (evMatch) {
        postParams.append("__EVENTVALIDATION", evMatch[1]);
      }

      if (cand.type === "account") {
        postParams.append("txtUserName", cand.id);
        postParams.append("txtAccountPassword", cleanPass);
        postParams.append("btnLoginAccount", "");
      } else {
        postParams.append("txtImeiNo", cand.id);
        postParams.append("txtImeiPassword", cleanPass);
        postParams.append("btnLoginImei", "");
      }

      const loginResp = await fetch(initUrl, {
        method: "POST",
        signal: AbortSignal.timeout(7000),
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          Cookie: sessionCookie,
          Referer: initUrl,
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
        body: postParams.toString(),
      });

      const newCookie = extractCookie(loginResp);
      if (newCookie) {
        sessionCookie = `${sessionCookie}; ${newCookie}`.replace(/^;\s*/, "");
      }

      const loginHtml = await loginResp.text();

      // Successful login outputs: parent.location.href='/Monitor.aspx'
      const isSuccess =
        loginHtml.includes("location.href='/Monitor.aspx'") ||
        loginHtml.includes("location.href=\"/Monitor.aspx\"") ||
        loginHtml.includes("/Monitor.aspx");

      if (isSuccess) {
        // Fetch Monitor.aspx to resolve internal device ID
        let internalDeviceId: number | undefined;

        try {
          const monitorResp = await fetch(`${baseServer}/Monitor.aspx`, {
            signal: AbortSignal.timeout(6000),
            headers: {
              Cookie: sessionCookie,
              Referer: initUrl,
              "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            },
          });

          if (monitorResp.ok) {
            const monitorHtml = await monitorResp.text();
            const mapSrcMatch = monitorHtml.match(/src="(map\.aspx\?[^"]+)"/i);

            if (mapSrcMatch) {
              const mapPath = "/" + mapSrcMatch[1].replace(/&amp;/g, "&");
              const mapResp = await fetch(`${baseServer}${mapPath}`, {
                signal: AbortSignal.timeout(6000),
                headers: {
                  Cookie: sessionCookie,
                  Referer: `${baseServer}/Monitor.aspx`,
                  "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                },
              });

              if (mapResp.ok) {
                const mapHtml = await mapResp.text();
                const devIdMatch =
                  mapHtml.match(/id="hidDeviceID"\s+value="([^"]+)"/i) ||
                  mapPath.match(/deviceID=([0-9]+)/);
                if (devIdMatch) {
                  internalDeviceId = parseInt(devIdMatch[1]);
                }
              }
            }
          }
        } catch (_) {}

        return {
          success: true,
          cookie: sessionCookie,
          server: baseServer,
          internalDeviceId,
        };
      }
    } catch {
      // Continue to next candidate / server
    }
  }

  return {
    success: false,
    cookie: "",
    server: baseServer,
    error: "Invalid Device ID or Password on AIKA168.",
  };
}

async function aikaGetTrackingTelemetry(
  session: AikaSession,
): Promise<any | null> {
  if (!session.internalDeviceId) return null;

  try {
    const payload = JSON.stringify({
      DeviceID: session.internalDeviceId,
      TimeZone: "China Standard Time",
    });

    const resp = await fetch(`${session.server}/Ajax/DevicesAjax.asmx/GetTracking`, {
      method: "POST",
      signal: AbortSignal.timeout(6000),
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        Cookie: session.cookie,
        Referer: `${session.server}/Tracking.aspx`,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      },
      body: payload,
    });

    if (!resp.ok) return null;

    const data = await resp.json();
    if (!data || !data.d) return null;

    // data.d is a JS object string: e.g. "{locationID:1,latitude:\"15.974202\",...}"
    let jsonStr = data.d.trim();
    jsonStr = jsonStr.replace(/([{,])\s*([a-zA-Z0-9_]+)\s*:/g, '$1"$2":');

    let parsed: any;
    try {
      parsed = JSON.parse(jsonStr);
    } catch {
      const latM = data.d.match(/latitude\s*:\s*["']?([0-9.]+)["']?/i);
      const lngM = data.d.match(/longitude\s*:\s*["']?([0-9.]+)["']?/i);
      const spdM = data.d.match(/speed\s*:\s*["']?([0-9.]+)["']?/i);
      const timeM = data.d.match(/deviceUtcDate\s*:\s*["']?([^"',]+)["']?/i);
      const statusM = data.d.match(/status\s*:\s*["']?([^"',]+)["']?/i);

      if (latM && lngM) {
        parsed = {
          latitude: latM[1],
          longitude: lngM[1],
          speed: spdM ? spdM[1] : "0",
          deviceUtcDate: timeM ? timeM[1] : null,
          status: statusM ? statusM[1] : "Online",
        };
      }
    }

    if (parsed) {
      const lat = parseFloat(parsed.latitude ?? "0");
      const lng = parseFloat(parsed.longitude ?? "0");

      if (lat !== 0 || lng !== 0) {
        return {
          latitude: lat,
          longitude: lng,
          speed_kph: parseFloat(parsed.speed ?? "0"),
          ignition: parsed.isStop !== 1 && parsed.work !== "OFF",
          online: parsed.status !== "Offline",
          gps_time: parsed.deviceUtcDate ?? parsed.serverUtcDate ?? new Date().toISOString(),
          battery: 100,
          status_text: parsed.status ?? "Online",
        };
      }
    }
  } catch (err) {
    console.error("Error in aikaGetTrackingTelemetry:", err);
  }

  return null;
}

async function aikaGetHistoryTelemetry(
  session: AikaSession,
  startDate: string,
  endDate: string,
): Promise<any[] | null> {
  if (!session.internalDeviceId) return null;

  try {
    const payload = JSON.stringify({
      DeviceID: session.internalDeviceId,
      Start: startDate,
      End: endDate,
      TimeZone: "China Standard Time",
      ShowLBS: 0,
    });

    const resp = await fetch(`${session.server}/Ajax/DevicesAjax.asmx/GetDevicesHistory`, {
      method: "POST",
      signal: AbortSignal.timeout(15000),
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        Cookie: session.cookie,
        Referer: `${session.server}/Playback.aspx`,
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      },
      body: payload,
    });

    if (!resp.ok) return null;

    const data = await resp.json();
    if (!data || !data.d) return null;

    let parsed: any;
    try {
      parsed = JSON.parse(data.d);
    } catch {
      try {
        let jsonStr = data.d.trim().replace(/([{,])\s*([a-zA-Z0-9_]+)\s*:/g, '$1"$2":');
        parsed = JSON.parse(jsonStr);
      } catch (evalErr) {
        console.error("Failed to parse Aika history JSON:", evalErr);
        return null;
      }
    }

    if (!parsed || !Array.isArray(parsed.devices)) {
      return [];
    }

    const points: any[] = [];
    for (const d of parsed.devices) {
      const lat = parseFloat(d.latitude ?? "0");
      const lng = parseFloat(d.longitude ?? "0");
      if (lat === 0 && lng === 0) continue;

      const speedKph = parseFloat(d.speed ?? "0");
      const heading = parseFloat(d.course ?? "0");
      const recordedAt = d.deviceUtcDate ?? d.serverUtcTime ?? new Date().toISOString();

      points.push({
        latitude: lat,
        longitude: lng,
        speed_kph: speedKph,
        speed_mps: speedKph / 3.6,
        heading_degrees: heading,
        is_stop: d.isStop === 1,
        source: "gps_tracker",
        recorded_at: recordedAt,
      });
    }

    return points;
  } catch (err) {
    console.error("Error in aikaGetHistoryTelemetry:", err);
    return null;
  }
}

async function pollAikaHistory(
  deviceIdentifier: string,
  password: string,
  startDate: string,
  endDate: string,
): Promise<{ success: boolean; points?: any[]; error?: string }> {
  for (const baseServer of AIKA_SERVERS) {
    const session = await aikaLoginWebForms(baseServer, deviceIdentifier, password);
    if (session.success) {
      const points = await aikaGetHistoryTelemetry(session, startDate, endDate);
      if (points !== null) {
        return {
          success: true,
          points,
        };
      }
    }
  }

  return {
    success: false,
    error: `Could not retrieve history for device ${deviceIdentifier} from AIKA servers.`,
  };
}

async function pollAika(
  deviceIdentifier: string,
  password: string,
): Promise<{ success: boolean; position?: any; error?: string; diagnostics?: any }> {
  for (const baseServer of AIKA_SERVERS) {
    const session = await aikaLoginWebForms(baseServer, deviceIdentifier, password);
    if (session.success) {
      const position = await aikaGetTrackingTelemetry(session);
      if (position) {
        return {
          success: true,
          position,
          diagnostics: { server: baseServer, deviceId: session.internalDeviceId },
        };
      }
    }
  }

  return {
    success: false,
    error: `Could not retrieve live coordinates for device ${deviceIdentifier} from AIKA servers.`,
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
    const { device_identifier, password, provider, action, start_date, end_date } = body;

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
      const logs: any[] = [];
      if (requestAction === "verify") {
        for (const baseServer of AIKA_SERVERS) {
          const session = await aikaLoginWebForms(baseServer, device_identifier, cleanPassword, logs);
          if (session.success) {
            return jsonResponse({
              success: true,
              server: baseServer,
              deviceId: session.internalDeviceId,
              logs,
            });
          }
        }
        return jsonResponse({
          success: false,
          error: "Authentication failed with AIKA server. Please check Device ID/IMEI and Password.",
          logs,
        });
      }

      if (requestAction === "history") {
        const fmtStart = (start_date ?? "").toString().trim() ||
          new Date(Date.now() - 86400000).toISOString().replace("T", " ").substring(0, 19);
        const fmtEnd = (end_date ?? "").toString().trim() ||
          new Date().toISOString().replace("T", " ").substring(0, 19);
        const result = await pollAikaHistory(device_identifier, cleanPassword, fmtStart, fmtEnd);
        return jsonResponse(result);
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
