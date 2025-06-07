import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (req: Request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseAnonKey);

  const sixteenHoursAgo = new Date(Date.now() - 16 * 60 * 60 * 1000);

  const { data, error } = await supabase
    .from("form_instances")
    .select("id, created_at")
    .eq("status", "active")
    .lt("created_at", sixteenHoursAgo.toISOString());

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ count: data.length, forms: data }), {
    headers: { "Content-Type": "application/json" },
  });
});
