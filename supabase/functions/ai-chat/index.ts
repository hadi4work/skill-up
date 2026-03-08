// Supabase Edge Function: استدعاء نموذج الذكاء الاصطناعي (Groq) من السيرفر
// أضف GROQ_API_KEY في Supabase Dashboard → Project Settings → Edge Functions → Secrets

declare const Deno: {
  serve: (handler: (req: Request) => Promise<Response>) => void;
  env: { get: (key: string) => string | undefined };
};

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const DEFAULT_MODEL = "llama-3.3-70b-versatile";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

function jsonResponse(
  data: Record<string, unknown>,
  status = 200
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const apiKey = Deno.env.get("GROQ_API_KEY");
  if (!apiKey) {
    return jsonResponse({
      error: "GROQ_API_KEY not set in Supabase secrets",
    }, 500);
  }

  let body: Record<string, unknown>;
  try {
    const text = await req.text();
    if (!text || text.trim() === "") {
      return jsonResponse({ error: "Missing or invalid body" }, 400);
    }
    body = JSON.parse(text) as Record<string, unknown>;
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const prompt = typeof body.prompt === "string" ? body.prompt : "";
  if (!prompt.trim()) {
    return jsonResponse({ error: "Missing or invalid 'prompt'" }, 400);
  }

  const systemPrompt =
    typeof body.systemPrompt === "string"
      ? body.systemPrompt
      : "أنت مساعد تعليمي مفيد وودود. تجيب بالعربية الفصحى أو العامية حسب سياق السؤال. لا تعطِ الإجابة النهائية مباشرة للتمارين، قدّم تلميحات وتوجيهاً.";
  const model =
    typeof body.model === "string" ? body.model : DEFAULT_MODEL;

  try {
    const response = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: prompt },
        ],
        max_tokens: 1024,
        temperature: 0.7,
      }),
    });

    if (!response.ok) {
      const errText = await response.text();
      return jsonResponse(
        { error: "Groq API error", details: errText },
        response.status
      );
    }

    const data = (await response.json()) as {
      choices?: Array<{ message?: { content?: string } }>;
    };
    const content = data.choices?.[0]?.message?.content ?? "";

    return jsonResponse({ text: content });
  } catch (e) {
    return jsonResponse(
      { error: e instanceof Error ? e.message : String(e) },
      500
    );
  }
});

export {};
