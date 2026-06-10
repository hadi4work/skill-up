// Supabase Edge Function: استدعاء نموذج الذكاء الاصطناعي (Groq) من السيرفر
// أضف GROQ_API_KEY في Supabase Dashboard → Project Settings → Edge Functions → Secrets

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const DEFAULT_MODEL = "llama-3.3-70b-versatile";
const MAX_HISTORY_MESSAGES = 12;

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

function hasDisallowedScripts(text: string): boolean {
  // Cyrillic + CJK ranges
  const cyrillic = /[\u0400-\u04FF]/u;
  const cjk = /[\u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]/u;
  return cyrillic.test(text) || cjk.test(text);
}

async function callGroq(params: {
  apiKey: string;
  model: string;
  messages: Array<{ role: "system" | "user" | "assistant"; content: string }>;
}): Promise<string> {
  const response = await fetch(GROQ_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${params.apiKey}`,
    },
    body: JSON.stringify({
      model: params.model,
      messages: params.messages,
      max_tokens: 1024,
      temperature: 0.7,
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Groq API error (${response.status}): ${errText}`);
  }

  const data = (await response.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };
  return data.choices?.[0]?.message?.content ?? "";
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
      : "أنت مساعد تعليمي مفيد وودود. تجيب بالعربية فقط وبأحرف عربية فقط (مسموح الأرقام والرموز المعتادة). حلّل السؤال داخلياً أولاً ثم قدّم إجابة واضحة. يمكنك شرح طريقة الحل خطوة بخطوة بشكل مختصر ومباشر. إذا طلب الطالب الحل النهائي صراحةً فاعطه الحل مع شرح الفكرة.";
  const model =
    typeof body.model === "string" ? body.model : DEFAULT_MODEL;

  const historyRaw = Array.isArray(body.history) ? body.history : [];
  const history = historyRaw
    .filter((item) => item && typeof item === "object")
    .map((item) => {
      const role = (item as Record<string, unknown>).role;
      const content = (item as Record<string, unknown>).content;
      if (
        (role === "user" || role === "assistant") &&
        typeof content === "string" &&
        content.trim() !== ""
      ) {
        return { role, content: content.trim() };
      }
      return null;
    })
    .filter((item): item is { role: "user" | "assistant"; content: string } => item !== null)
    .slice(-MAX_HISTORY_MESSAGES);

  try {
    let content = await callGroq({
      apiKey,
      model,
      messages: [
        { role: "system", content: systemPrompt },
        ...history,
        { role: "user", content: prompt },
      ],
    });

    // Safety pass: if model leaked Cyrillic/CJK, force Arabic rewrite.
    if (hasDisallowedScripts(content)) {
      const rewritePrompt =
        "أعد صياغة النص التالي بالعربية فقط وبأحرف عربية فقط، دون أي كلمات روسية أو صينية، مع الحفاظ على نفس المعنى:\n\n" +
        content;
      content = await callGroq({
        apiKey,
        model,
        messages: [
          {
            role: "system",
            content:
              "أنت مدقق لغة. أخرج النص بالعربية فقط وبأحرف عربية فقط (مسموح الأرقام والرموز). لا تضف شروحات.",
          },
          { role: "user", content: rewritePrompt },
        ],
      });
    }

    return jsonResponse({ text: content });
  } catch (e) {
    return jsonResponse(
      { error: e instanceof Error ? e.message : String(e) },
      500
    );
  }
});

export {};
