// Supabase ters vekili (Cloudflare Worker).
//
// Bazı internet sağlayıcıları/operatörler *.supabase.co alan adını engelliyor.
// Uygulama doğrudan erişemezse istekleri bu worker üzerinden gönderir; worker
// yalnızca bu projenin Supabase adresine iletir (açık vekil değildir).
//
// Ortam değişkeni (isteğe bağlı): SUPABASE_URL

const DEFAULT_UPSTREAM = "https://scycflgsxpkgoouunptr.supabase.co";
const ALLOWED_PATH = /^\/(auth|rest|storage|realtime|functions|graphql)\/v1(\/|$)/;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (!ALLOWED_PATH.test(url.pathname)) {
      return new Response("Not found", { status: 404 });
    }

    const upstream = env.SUPABASE_URL || DEFAULT_UPSTREAM;
    const target = new URL(url.pathname + url.search, upstream);

    // Method, header, gövde ve WebSocket yükseltmesi (realtime) aynen geçer.
    return fetch(new Request(target, request), { redirect: "manual" });
  },
};
