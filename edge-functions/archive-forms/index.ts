import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (req: Request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceRoleKey =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

  const sixteenHoursAgo = new Date(Date.now() - 16 * 60 * 60 * 1000);

  const { data, error } = await supabase
    .from("form_instances")
    .update({
      status: "archived",
      updated_at: new Date().toISOString(),
    })
    .eq("status", "active")
    .lt("created_at", sixteenHoursAgo.toISOString())
    .select("id, created_at");

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ archived: data.length, forms: data }), {
    headers: { "Content-Type": "application/json" },
  });
});
