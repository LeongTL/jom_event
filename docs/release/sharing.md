# Sharing links: what to set up

The app builds links like `https://<domain>/e/<code>` (events) and `https://<domain>/u/<username>` (people and
hosts). The page behind them is the Supabase Edge Function `share-page`. The domain is not bought yet, so nothing in the
code names one: every place below uses a placeholder (`share.example.invalid`, a name that can never resolve) until the
real address exists.

## One setting, in four places

| Where | Setting | Placeholder now |
|---|---|---|
| The app build (`--dart-define-from-file=env/<name>.json`) | `SHARE_BASE_URL` | empty: links fall back to `jom://e/<code>`, which only opens on a phone that has the app |
| Android build | environment `SHARE_HOST` or `-PshareHost=...` (the host only, no `https://`) | `share.example.invalid` |
| iOS build | `SHARE_HOST` in `app/ios/Flutter/Debug.xcconfig` and `Release.xcconfig` (the Associated Domains entitlement is `applinks:$(SHARE_HOST)`) | `share.example.invalid` |
| The `share-page` function (`supabase secrets set ...`) | `SHARE_BASE_URL` | unset: the page leaves out `og:url` |

## The function's other settings

`supabase secrets set SHARE_BASE_URL=... ANDROID_CERT_SHA256=... IOS_TEAM_ID=... PLAY_STORE_URL=... APP_STORE_URL=...`

- `ANDROID_CERT_SHA256`: the SHA-256 fingerprint of the key that signs the Play build (Play Console, App integrity). It goes
  into `/.well-known/assetlinks.json`.
- `IOS_TEAM_ID`: your Apple developer team id. It goes into `/.well-known/apple-app-site-association` as `<team>.com.jom.jom`.
- `PLAY_STORE_URL`, `APP_STORE_URL`: the store pages. Until they exist the "Get the app" links go nowhere.

## Deploy and point the domain at it

1. `supabase functions deploy share-page --no-verify-jwt` (it is public on purpose: link previews and people without an
   account fetch it; it only reads the two preview functions with the public key).
2. Buy the domain and put it behind Cloudflare. Add a rule that sends `/e/*`, `/u/*` and `/.well-known/*` to
   `https://<project>.supabase.co/functions/v1/share-page/<same path>` (a Worker or a Transform Rule that rewrites the path).
3. Upload a 1200 x 630 image at `<domain>/default-share.png`: the preview used when an event has no poster.
4. Set the four settings above, build a signed app, and open `https://<domain>/e/<code>` on a phone.

## Checking it

- `curl -i https://<domain>/e/<code>`: 200 with `og:title`, `og:image` and, for a private event, `noindex`; a wrong code is 404.
- `curl https://<domain>/.well-known/assetlinks.json` and `.../apple-app-site-association`: both JSON.
- A link tapped inside WhatsApp or Telegram opening the app needs the real domain, a signed build and these two files live;
  it cannot be proven on a simulator.
