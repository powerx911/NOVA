import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(() => new Response(
  JSON.stringify({
    error: "LEGACY_NOVA_CONTROL_RETIRED",
    message: "The former NOVA Pages control service was retired during the NEXORA replacement.",
  }),
  {
    status: 410,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  },
));
