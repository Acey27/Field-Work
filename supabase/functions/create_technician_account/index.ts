import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { type AccountInput, validateAccountInput } from "./validation.ts";

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

  const { data: profile, error: profileError } = await caller
    .from("profiles")
    .select("role, active")
    .eq("id", userData.user.id)
    .single();
  if (
    profileError || !profile?.active ||
    !["admin", "super_admin"].includes(profile.role)
  ) {
    return json({ error: "E_FORBIDDEN" }, 403);
  }

  let body: AccountInput;
  try {
    body = await request.json() as AccountInput;
  } catch {
    return json({ error: "E_INVALID_JSON" }, 400);
  }
  const validated = validateAccountInput(body);
  if ("error" in validated) return json({ error: validated.error }, 400);
  const { email, startingPassword, fullName } = validated.value;

  const admin = createClient(supabaseUrl, serviceKey);
  const { data: created, error: createError } = await admin.auth.admin
    .createUser({
      email,
      password: startingPassword,
      email_confirm: true,
    });
  if (createError || !created.user) {
    const duplicate = createError?.message.toLowerCase().includes("already");
    return json({
      error: duplicate ? "E_EMAIL_TAKEN" : "E_ACCOUNT_CREATE_FAILED",
    }, 400);
  }

  const { data: code, error: codeError } = await admin.rpc("next_id", {
    p_prefix: "T",
  });
  if (codeError) {
    await admin.auth.admin.deleteUser(created.user.id);
    return json({ error: "E_ACCOUNT_CREATE_FAILED" }, 500);
  }
  const { error: insertError } = await admin.from("profiles").insert({
    id: created.user.id,
    code,
    role: "technician",
    full_name: fullName,
    must_change_password: true,
    created_by: userData.user.id,
  });
  if (insertError) {
    await admin.auth.admin.deleteUser(created.user.id);
    return json({ error: "E_ACCOUNT_CREATE_FAILED" }, 500);
  }
  await admin.from("audit_logs").insert({
    actor_id: userData.user.id,
    actor_role: profile.role,
    action: "account_created",
    table_name: "profiles",
    record_id: created.user.id,
    after: { code, role: "technician", full_name: fullName },
  });

  return json({
    profile_id: created.user.id,
    code,
    email,
  }, 201);
});
