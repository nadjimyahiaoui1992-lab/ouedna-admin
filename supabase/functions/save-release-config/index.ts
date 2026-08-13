import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader) return json({ error: "unauthorized" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: "server_configuration_error" }, 500);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const accessToken = authHeader.replace(/^Bearer\s+/i, "");
    const { data: authData, error: authError } = await supabase.auth.getUser(
      accessToken,
    );
    if (authError || !authData.user) return json({ error: "unauthorized" }, 401);

    const { data: profile, error: profileError } = await supabase
      .from("admin_profiles")
      .select("id, role")
      .eq("id", authData.user.id)
      .maybeSingle();
    if (profileError || profile?.role !== "admin") {
      return json({ error: "forbidden" }, 403);
    }

    const body = await request.json();
    const latestVersion = typeof body?.latest_version === "string"
      ? body.latest_version.trim().slice(0, 48)
      : "";
    const directApkUrl = typeof body?.direct_apk_url === "string"
      ? body.direct_apk_url.trim()
      : "";
    const apkSha256 = typeof body?.apk_sha256 === "string"
      ? body.apk_sha256.trim().toLowerCase()
      : "";
    const releaseNotes = typeof body?.release_notes === "string"
      ? body.release_notes.trim().slice(0, 2000)
      : null;
    const forceUpdate = body?.force_update === true;

    let isHttpsApkUrl = false;
    try {
      isHttpsApkUrl = new URL(directApkUrl).protocol === "https:";
    } catch (_) {
      isHttpsApkUrl = false;
    }
    if (!latestVersion || !isHttpsApkUrl) {
      return json({ error: "invalid_release_configuration" }, 400);
    }
    if (!/^[a-f0-9]{64}$/.test(apkSha256)) {
      return json({ error: "invalid_apk_sha256" }, 400);
    }

    const { data: configuration, error: saveError } = await supabase
      .from("app_config")
      .upsert({
        id: 1,
        latest_version: latestVersion,
        force_update: forceUpdate,
        android_store_url: null,
        direct_apk_url: directApkUrl,
        apk_sha256: apkSha256,
        release_notes: releaseNotes || null,
      })
      .select(
        "latest_version, force_update, direct_apk_url, apk_sha256, release_notes",
      )
      .single();
    if (saveError) throw saveError;

    return json({ saved: true, configuration });
  } catch (error) {
    console.error("save-release-config", error);
    return json({ error: "unable_to_save_release_configuration" }, 500);
  }
});
