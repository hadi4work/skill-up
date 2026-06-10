/**
 * إرسال Push عبر FCM HTTP v1 بعد إنشاء إشعار في Firestore (يُستدعى من التطبيق).
 *
 * Secrets (Supabase Dashboard → Edge Functions → Secrets):
 * - PUSH_DISPATCH_SECRET: نفس القيمة في --dart-define=PUSH_DISPATCH_SECRET
 * - FIREBASE_PROJECT_ID: معرف مشروع Firebase (مثل smartapp-a308b)
 * - GOOGLE_SERVICE_ACCOUNT_JSON: محتوى ملف JSON لحساب خدمة Google (من Firebase Console)
 */
import * as jose from "https://deno.land/x/jose@v5.2.3/index.ts";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "Content-Type, Authorization, x-push-secret, apikey, x-client-info",
};

function jsonResponse(data: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

function channelIdForPriority(priority: string): string {
  if (priority === "high") return "high_priority_channel";
  if (priority === "low") return "low_priority_channel";
  return "default_priority_channel";
}

function firestoreStringField(
  doc: { fields?: Record<string, unknown> },
  name: string,
): string | null {
  const f = doc.fields?.[name] as Record<string, unknown> | undefined;
  const sv = f?.stringValue;
  return typeof sv === "string" && sv.length > 0 ? sv : null;
}

async function getAccessToken(sa: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const pk = await jose.importPKCS8(sa.private_key.replace(/\\n/g, "\n"), "RS256");
  const jwt = await new jose.SignJWT({
    scope: "https://www.googleapis.com/auth/cloud-platform",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email) // مطلوب لطلبات Google OAuth بحساب الخدمة
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(pk);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const data = (await res.json()) as { access_token?: string; error?: string };
  if (!res.ok || !data.access_token) {
    throw new Error(`OAuth token failed: ${data.error ?? res.status}`);
  }
  return data.access_token;
}

async function fetchUserFcmToken(
  projectId: string,
  accessToken: string,
  userId: string,
): Promise<string | null> {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${userId}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (res.status === 404) return null;
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Firestore read failed: ${res.status} ${t}`);
  }
  const doc = (await res.json()) as { fields?: Record<string, unknown> };
  return firestoreStringField(doc, "fcmToken");
}

function stringifyDataPayload(
  meta: Record<string, unknown> | undefined,
  base: Record<string, string>,
): Record<string, string> {
  const out = { ...base };
  if (!meta) return out;
  for (const [k, v] of Object.entries(meta)) {
    if (v === undefined || v === null) continue;
    out[k] = typeof v === "string" ? v : JSON.stringify(v);
  }
  return out;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const expectedSecret = Deno.env.get("PUSH_DISPATCH_SECRET");
  const gotSecret = req.headers.get("x-push-secret") ?? "";
  if (!expectedSecret || gotSecret !== expectedSecret) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  const saRaw = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
  if (!projectId || !saRaw) {
    return jsonResponse(
      { error: "Server misconfigured: FIREBASE_PROJECT_ID or GOOGLE_SERVICE_ACCOUNT_JSON" },
      500,
    );
  }

  let body: Record<string, unknown>;
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    return jsonResponse({ error: "Invalid JSON" }, 400);
  }

  const userId = typeof body.userId === "string" ? body.userId.trim() : "";
  const title = typeof body.title === "string" ? body.title.trim() : "";
  const bodyText = typeof body.body === "string" ? body.body.trim() : "";
  const notificationId = typeof body.notificationId === "string"
    ? body.notificationId
    : "";
  const type = typeof body.type === "string" ? body.type : "";
  const priority = typeof body.priority === "string" ? body.priority : "default";
  const actionType = typeof body.actionType === "string" ? body.actionType : "";
  const assignmentId = typeof body.assignmentId === "string" ? body.assignmentId : "";
  const metadata = body.metadata as Record<string, unknown> | undefined;

  if (!userId || !title) {
    return jsonResponse({ error: "Missing userId or title" }, 400);
  }

  let sa: { client_email: string; private_key: string };
  try {
    sa = JSON.parse(saRaw) as { client_email: string; private_key: string };
  } catch {
    return jsonResponse({ error: "Invalid GOOGLE_SERVICE_ACCOUNT_JSON" }, 500);
  }

  try {
    const accessToken = await getAccessToken(sa);
    const fcmToken = await fetchUserFcmToken(projectId, accessToken, userId);

    if (!fcmToken) {
      return jsonResponse({ ok: true, skipped: "no_fcm_token" });
    }

    const dataPayload = stringifyDataPayload(metadata, {
      actionType,
      assignmentId,
      type,
      priority,
      notificationId,
    });

    const fcmBody = {
      message: {
        token: fcmToken,
        notification: {
          title: title || "SkillUp AI",
          body: bodyText || "لديك إشعار جديد",
        },
        android: {
          priority: priority === "high" ? "HIGH" : "NORMAL",
          notification: {
            channel_id: channelIdForPriority(priority),
          },
        },
        data: dataPayload,
      },
    };

    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(fcmBody),
      },
    );

    if (!fcmRes.ok) {
      const errText = await fcmRes.text();
      return jsonResponse(
        { error: "FCM send failed", details: errText },
        502,
      );
    }

    return jsonResponse({ ok: true, sent: true });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonResponse({ error: msg }, 500);
  }
});
