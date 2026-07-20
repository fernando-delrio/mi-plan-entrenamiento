// Proxy seguro hacia Mistral para el botón "🤖 Tutorial IA".
// La clave real (MISTRAL_API_KEY) vive como secreto de Supabase, nunca en
// el navegador. `verify_jwt` (activado por defecto en el proyecto) ya rechaza
// cualquier petición sin sesión antes de que este código llegue a ejecutarse
// — por eso no hace falta comprobar la autenticación aquí también.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const buildPrompt = (exerciseName: string) => `Eres un coach de calistenia y enduro MTB profesional, también fisioterapeuta deportivo. Fernando tiene 38 años, 1,78m, 86kg, choque femoroacetabular + artrosis en cadera derecha (dolor crónico, no operado, consulta el 28 de diciembre). Su objetivo es perder grasa, ganar músculo, doler menos y volver al enduro MTB. Explícale el ejercicio "${exerciseName}" en español de forma directa.

Responde SOLO con JSON válido (sin markdown):
{"como_hacerlo":["paso 1","paso 2","paso 3","paso 4"],"objetivo":"por qué este ejercicio le ayuda concretamente a perder grasa, ganar músculo o rendir en enduro","progresion":"cómo progresar la próxima vez: cuándo subir peso, reps o series","errores_comunes":["error 1","error 2","error 3"],"cue_activacion":"frase corta para sentir el músculo","cadera":"nota sobre la cadera de Fernando","nivel_dificultad":"Principiante / Intermedio / Avanzado"}`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const { exerciseName } = await req.json().catch(() => ({}));
  if (!exerciseName || typeof exerciseName !== "string") {
    return jsonResponse({ error: "Falta exerciseName" }, 400);
  }

  const mistralRes = await fetch("https://api.mistral.ai/v1/chat/completions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "authorization": `Bearer ${Deno.env.get("MISTRAL_API_KEY") ?? ""}`,
    },
    body: JSON.stringify({
      model: "mistral-large-latest",
      max_tokens: 800,
      response_format: { type: "json_object" },
      messages: [{ role: "user", content: buildPrompt(exerciseName) }],
    }),
  });

  if (!mistralRes.ok) {
    return jsonResponse({ error: "Error al consultar Mistral", detail: await mistralRes.text() }, 502);
  }

  const mistralData = await mistralRes.json();
  const text = mistralData.choices?.[0]?.message?.content ?? "{}";

  try {
    return jsonResponse(JSON.parse(text));
  } catch {
    return jsonResponse({ error: "El modelo no devolvió JSON válido" }, 502);
  }
});
