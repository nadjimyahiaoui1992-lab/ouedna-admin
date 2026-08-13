import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { GoogleAuth } from "npm:google-auth-library@9.15.1";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const validTypes = new Set([
  "app_update",
  "place",
  "announcement",
  "event",
  "safety",
]);
const validTargets = new Set(["none", "place", "update", "url"]);

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

    const { data: profile } = await supabase
      .from("admin_profiles")
      .select("role")
      .eq("id", authData.user.id)
      .maybeSingle();
    if (profile?.role !== "admin") return json({ error: "forbidden" }, 403);

    const body = await request.json();
    const type = typeof body?.type === "string" ? body.type : "announcement";
    const title = typeof body?.title === "string" ? body.title.trim().slice(0, 120) : "";
    const message = typeof body?.body === "string" ? body.body.trim().slice(0, 500) : "";
    const targetType = typeof body?.target_type === "string" ? body.target_type : "none";
    const imageUrl = typeof body?.image_url === "string" ? body.image_url.trim() : null;
    const targetUrl = typeof body?.target_url === "string" ? body.target_url.trim() : null;
    const targetPlaceId = Number.isInteger(body?.target_place_id)
      ? body.target_place_id
      : null;

    if (!validTypes.has(type) || !validTargets.has(targetType) || !title || !message) {
      return json({ error: "invalid_notification_payload" }, 400);
    }
    if (targetType === "place" && !targetPlaceId) {
      return json({ error: "missing_target_place" }, 400);
    }
    if (targetType === "url") {
      try {
        if (!targetUrl || new URL(targetUrl).protocol !== "https:") {
          return json({ error: "invalid_target_url" }, 400);
        }
      } catch (_) {
        return json({ error: "invalid_target_url" }, 400);
      }
    }

    const { data: notification, error: notificationError } = await supabase
      .from("visitor_notifications")
      .insert({
        type,
        title,
        body: message,
        image_url: imageUrl || null,
        target_type: targetType,
        target_place_id: targetPlaceId,
        target_url: targetUrl || null,
        is_published: true,
        published_at: new Date().toISOString(),
        created_by: authData.user.id,
      })
      .select("id, type, title, body, target_type, target_place_id, target_url")
      .single();
    if (notificationError) throw notificationError;

    const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID");
    const serviceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (!firebaseProjectId || !serviceAccountRaw) {
      return json({ published: true, notification, push_status: "not_configured" });
    }

    const { data: devices } = await supabase
      .from("push_devices")
      .select("token")
      .eq("platform", "android")
      .limit(5000);
    const auth = new GoogleAuth({
      credentials: JSON.parse(serviceAccountRaw),
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    const client = await auth.getClient();
    const tokenResponse = await client.getAccessToken();
    if (!tokenResponse.token) throw new Error("unable_to_obtain_fcm_access_token");

    let sent = 0;
    for (const device of devices ?? []) {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${tokenResponse.token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: device.token,
              notification: { title, body: message },
              data: {
                type: "visitor_notification",
                notification_id: notification.id,
                target_type: targetType,
                target_place_id: targetPlaceId?.toString() ?? "",
                target_url: targetUrl ?? "",
              },
              android: {
                priority: "high",
                notification: { channel_id: "ouedna_updates", sound: "default" },
              },
            },
          }),
        },
      );
      if (response.ok) sent += 1;
    }

    return json({ published: true, notification, push_status: "sent", sent });
  } catch (error) {
    console.error("publish-visitor-notification", error);
    return json({ error: "unable_to_publish_notification" }, 500);
  }
});
