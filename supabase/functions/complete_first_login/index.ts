import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "E_METHOD_NOT_ALLOWED" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json({ error: "E_SERVER_CONFIG" }, 500);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization) return json({ error: "E_FORBIDDEN" }, 403);

  const caller = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: userData, error: userError } = await caller.auth.getUser();
  if (userError || !userData.user) return json({ error: "E_FORBIDDEN" }, 403);

  let body: { new_password?: string };
  try {
    body = await request.json() as { new_password?: string };
  } catch {
    return json({ error: "E_INVALID_JSON" }, 400);
  }
  const newPassword = body.new_password ?? "";
  if (newPassword.length < 10) {
    return json({ error: "E_PASSWORD_WEAK" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey);
  const { data: profile, error: profileError } = await admin
    .from("profiles")
    .select("id, active, must_change_password")
    .eq("id", userData.user.id)
    .single();
  if (
    profileError || !profile?.active || !profile.must_change_password
  ) {
    return json({ error: profile?.active ? "E_FORBIDDEN" : "E_ACCOUNT_DISABLED" }, 403);
  }

  const { error: passwordError } = await admin.auth.admin.updateUserById(
    userData.user.id,
    { password: newPassword },
  );
  if (passwordError) return json({ error: "E_PASSWORD_UPDATE_FAILED" }, 500);

  const { error: updateError } = await admin
    .from("profiles")
    .update({ must_change_password: false })
    .eq("id", userData.user.id);
  if (updateError) return json({ error: "E_PASSWORD_UPDATE_FAILED" }, 500);

  return json({ ok: true });
});
