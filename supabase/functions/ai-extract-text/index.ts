// Supabase Edge Function: استخراج النص من صورة باستخدام الذكاء الاصطناعي (Groq Vision)
// يستخدم نفس GROQ_API_KEY من Supabase Secrets

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const VISION_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct";

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

  const imageBase64 = typeof body.imageBase64 === "string" ? body.imageBase64 : "";
  if (!imageBase64.trim()) {
    return jsonResponse({ error: "Missing or invalid 'imageBase64'" }, 400);
  }

  const imageUrl = imageBase64.startsWith("data:")
    ? imageBase64
    : `data:image/jpeg;base64,${imageBase64}`;

  const systemPrompt =
    "أنت مساعد لاستخراج النص من الصور. مهمتك أن تكتب كل النص الذي تراه في الصورة كما هو (عربي أو إنجليزي أو أرقام). اكتب النص فقط دون تعليق أو وصف.";
  const userContent = [
    { type: "text", text: "استخرج كل النص من هذه الصورة واكتبه كما يظهر." },
    { type: "image_url", image_url: { url: imageUrl } },
  ];

  try {
    const response = await fetch(GROQ_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: VISION_MODEL,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userContent },
        ],
        max_tokens: 2048,
        temperature: 0.2,
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

    return jsonResponse({ text: content.trim() });
  } catch (e) {
    return jsonResponse(
      { error: e instanceof Error ? e.message : String(e) },
      500
    );
  }
});
