// ===========================================================================
// sos-worker — Cloudflare Worker for sos.nobulai.tools
// Receives heartbeats and SOS broadcasts from aisos.
// Relays to Datadog. Stores in KV for retrieval.
// ===========================================================================
//
// [PROVENANCE]
// tool: sos-worker
// version: 1.0.0
// created: 2026-04-05T00:04:18Z
// license: MIT — NOBUL (https://nobul.tech)
//
// [AGENT]
// name: Jose Palencia Castro
// org: NOBUL (nobul.tech)
// role: The Commander
//
// [AGENT]
// name: Agent Fantastic
// model: Claude Opus 4.6
// maker: Anthropic
// session: f8c53367-491d-45e2-9777-556697a1dae3
// url: https://claude.ai/chat/f8c53367-491d-45e2-9777-556697a1dae3
// role: Session agent
// trust: HIGH
// fear: LOW
// timestamp: 2026-04-05T00:04:18Z
//
// [DEPENDENCIES]
// runtime: Cloudflare Workers
// KV: AISOS_KV namespace (bind in wrangler.toml or dashboard)
// secrets: DD_API_KEY (set via wrangler secret or dashboard)
//
// [DEPLOYMENT]
// target: sos.nobulai.tools
// deploy: aideploy deploy <dir> --worker-name aisos-worker
// or: Cloudflare dashboard direct upload
//
// ===========================================================================

const DD_SITE = "us5.datadoghq.com";
const MAX_STORED_EVENTS = 1000;

export default {
  async fetch(request, env) {
    // CORS headers for all responses
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    };

    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);

    // GET / — status page
    if (request.method === "GET" && url.pathname === "/") {
      return handleStatus(env, corsHeaders);
    }

    // GET /events — retrieve stored events
    if (request.method === "GET" && url.pathname === "/events") {
      return handleGetEvents(env, url, corsHeaders);
    }

    // GET /latest — most recent event
    if (request.method === "GET" && url.pathname === "/latest") {
      return handleLatest(env, corsHeaders);
    }

    // POST / — receive heartbeat or SOS
    if (request.method === "POST") {
      return handleIncoming(request, env, corsHeaders);
    }

    return new Response(JSON.stringify({ error: "not found" }), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  },
};

// ── Handlers ──────────────────────────────────────────────────────────────

async function handleIncoming(request, env, corsHeaders) {
  let payload;
  try {
    payload = await request.json();
  } catch (e) {
    return jsonResponse({ error: "invalid JSON" }, 400, corsHeaders);
  }

  const timestamp = new Date().toISOString();
  const mode = extractMode(payload);
  const isSOS = mode === "sos";

  // Store in KV
  const eventId = `${Date.now()}-${mode}`;
  const stored = {
    id: eventId,
    received: timestamp,
    mode: mode,
    payload: payload,
    source_ip: request.headers.get("CF-Connecting-IP") || "unknown",
  };

  if (env.AISOS_KV) {
    try {
      await env.AISOS_KV.put(
        `event:${eventId}`,
        JSON.stringify(stored),
        { expirationTtl: 86400 * 30 } // 30 days
      );

      // Update latest pointer
      await env.AISOS_KV.put("latest", JSON.stringify(stored));

      // Update event index
      await updateIndex(env, eventId, mode, timestamp);
    } catch (e) {
      console.error("KV write failed:", e);
    }
  }

  // Relay to Datadog (redundant path)
  let ddResult = { sent: false };
  if (env.DD_API_KEY) {
    ddResult = await relayToDatadog(payload, env.DD_API_KEY);
  }

  const response = {
    status: "received",
    id: eventId,
    mode: mode,
    timestamp: timestamp,
    dd_relayed: ddResult.sent,
  };

  if (isSOS) {
    response.broadcast = true;
    response.message = "SOS RECEIVED — alarm sounded";
    console.log(`SOS BROADCAST: ${JSON.stringify(payload)}`);
  }

  return jsonResponse(response, isSOS ? 201 : 200, corsHeaders);
}

async function handleStatus(env, corsHeaders) {
  const status = {
    service: "sos.nobulai.tools",
    version: "1.0.0",
    status: "operational",
    timestamp: new Date().toISOString(),
    kv: env.AISOS_KV ? "bound" : "not bound",
    dd: env.DD_API_KEY ? "configured" : "not configured",
  };

  // Get latest event if KV is available
  if (env.AISOS_KV) {
    try {
      const latest = await env.AISOS_KV.get("latest");
      if (latest) {
        const parsed = JSON.parse(latest);
        status.last_event = {
          mode: parsed.mode,
          received: parsed.received,
          id: parsed.id,
        };
      }
    } catch (e) {
      status.last_event = null;
    }
  }

  return jsonResponse(status, 200, corsHeaders);
}

async function handleGetEvents(env, url, corsHeaders) {
  if (!env.AISOS_KV) {
    return jsonResponse({ error: "KV not bound" }, 503, corsHeaders);
  }

  const mode = url.searchParams.get("mode"); // filter by mode
  const limit = Math.min(parseInt(url.searchParams.get("limit") || "50"), 100);

  try {
    const index = await env.AISOS_KV.get("index");
    if (!index) {
      return jsonResponse({ events: [], count: 0 }, 200, corsHeaders);
    }

    let entries = JSON.parse(index);

    // Filter by mode if specified
    if (mode) {
      entries = entries.filter((e) => e.mode === mode);
    }

    // Most recent first, limited
    entries = entries.slice(-limit).reverse();

    // Fetch full events
    const events = [];
    for (const entry of entries) {
      const data = await env.AISOS_KV.get(`event:${entry.id}`);
      if (data) {
        events.push(JSON.parse(data));
      }
    }

    return jsonResponse({ events: events, count: events.length }, 200, corsHeaders);
  } catch (e) {
    return jsonResponse({ error: "failed to read events" }, 500, corsHeaders);
  }
}

async function handleLatest(env, corsHeaders) {
  if (!env.AISOS_KV) {
    return jsonResponse({ error: "KV not bound" }, 503, corsHeaders);
  }

  try {
    const latest = await env.AISOS_KV.get("latest");
    if (!latest) {
      return jsonResponse({ error: "no events" }, 404, corsHeaders);
    }
    return jsonResponse(JSON.parse(latest), 200, corsHeaders);
  } catch (e) {
    return jsonResponse({ error: "failed to read latest" }, 500, corsHeaders);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

function extractMode(payload) {
  // Check tags for mode
  if (payload.tags) {
    for (const tag of payload.tags) {
      if (tag === "mode:sos" || tag === '"mode:sos"') return "sos";
      if (tag === "mode:heartbeat" || tag === '"mode:heartbeat"') return "heartbeat";
    }
  }
  // Check title
  if (payload.title) {
    if (payload.title.startsWith("SOS")) return "sos";
    if (payload.title.startsWith("HEARTBEAT")) return "heartbeat";
  }
  return "unknown";
}

async function updateIndex(env, eventId, mode, timestamp) {
  let index = [];
  try {
    const existing = await env.AISOS_KV.get("index");
    if (existing) {
      index = JSON.parse(existing);
    }
  } catch (e) {
    index = [];
  }

  index.push({ id: eventId, mode: mode, timestamp: timestamp });

  // Trim to max
  if (index.length > MAX_STORED_EVENTS) {
    const removed = index.splice(0, index.length - MAX_STORED_EVENTS);
    // Clean up old KV entries
    for (const entry of removed) {
      try {
        await env.AISOS_KV.delete(`event:${entry.id}`);
      } catch (e) {
        // best effort
      }
    }
  }

  await env.AISOS_KV.put("index", JSON.stringify(index));
}

async function relayToDatadog(payload, apiKey) {
  try {
    const resp = await fetch(`https://api.${DD_SITE}/api/v1/events`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "DD-API-KEY": apiKey,
      },
      body: JSON.stringify(payload),
    });
    return { sent: resp.ok, status: resp.status };
  } catch (e) {
    return { sent: false, error: e.message };
  }
}

function jsonResponse(data, status, corsHeaders) {
  return new Response(JSON.stringify(data, null, 2), {
    status: status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
