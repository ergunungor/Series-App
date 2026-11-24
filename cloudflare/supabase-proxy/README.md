# Supabase vekili (Cloudflare Worker)

`supabase.co` engellenen ağlarda (bazı operatörler/ISS'ler) uygulamanın giriş ve
kayıt yapabilmesi için. Uygulama önce doğrudan Supabase'e bağlanmayı dener;
ulaşamazsa otomatik olarak bu vekili kullanır. Kullanıcının bir şey yapması gerekmez.

## Kurulum (bir kez, ~5 dk, ücretsiz)

1. https://dash.cloudflare.com adresinde ücretsiz hesap aç / giriş yap.
2. **Workers & Pages → Create → Create Worker** de, adını `series-supabase-proxy` yap, **Deploy** et.
3. **Edit code** ile içeriği bu klasördeki `worker.js` ile değiştir, **Deploy** et.
4. Worker adresini kopyala (örn. `https://series-supabase-proxy.KULLANICI.workers.dev`).
5. `lib/config/api_config.dart` içindeki `supabaseProxyUrl` değerine yapıştır (sonunda `/` olmasın).
6. Uygulamayı yeniden derle.

Wrangler ile: `cd cloudflare/supabase-proxy && npx wrangler deploy`

## Test

Tarayıcıda `https://<worker-adresi>/auth/v1/health` açılınca JSON yanıt (örn. `No API key found`) görmelisin.

Ücretsiz plan günde 100.000 istek verir.
