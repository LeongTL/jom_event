# Sharing and deep links: design (app task 7)

Nov 14, 2026 · Status: written from decisions in `docs/decisions/2026-11-10-fiuu-and-pending.md`; waiting for the owner to read it. No code written.

## Goal

Someone who sees an interesting event can share it with a friend. The friend sees a clear preview in WhatsApp or Telegram, and the link opens the event in the app if it is installed, or a web page with a "Get the app" button if not.

## Decided (from the owner)

- WhatsApp and Telegram first, using one link with a preview card (title, poster, date, place). Instagram and TikTok (a generated poster image) come later.
- Needs a domain, a landing page and deep links. Private events use the same link with the unguessable share code.

## Defaults I chose

- Link shapes: `https://<domain>/e/<share_code>` for events and `https://<domain>/u/<username>` for people and hosts. The domain is not bought yet; the app reads it from the setting `SHARE_BASE_URL`, so nothing is hard-coded.
- The landing page is a Supabase Edge Function `share-page` that renders small server-side HTML (so link previews work), fronted by the domain through Cloudflare. No separate web hosting to maintain.
- Private events: the landing page works for anyone with the link, but sends `noindex` so search engines do not list it.
- Store links ("Get the app") are placeholders until the app has store pages.

## Database

- `events.share_preview(p_code text)` (callable by anon): returns only what a preview needs: title, starts and ends, area, venue, price (or Free), poster URL, host name, status. Works for private events; returns nothing for `draft` and `cancelled`. No phone, no payment details, no guest data.
- `identity.person_preview(p_username text)`: name, username, host flag, avatar URL, and area for hosts. Nothing else.
- The event `share_code` column comes from the event-visibility spec.

## Landing page (Edge function `share-page`)

- `GET /e/<code>` and `GET /u/<username>` return HTML with `og:title`, `og:description`, `og:image` (poster, or a default image), `og:url`, Twitter card tags, a short summary, an **Open in the app** button, and **Get the app**.
- A wrong or cancelled code returns a friendly "This event is not available" page with HTTP 404.
- Private events add `<meta name="robots" content="noindex">`; every page sets a short cache time so edits show up soon.
- Serves `/.well-known/assetlinks.json` (Android) and `/.well-known/apple-app-site-association` (iOS, no file extension, JSON content type) from the same function.

## App (Flutter)

- **Share button** on the event page, the people page and the host page, using the system share sheet (`share_plus`) with the text "Title · date · area" and the link.
- **Deep links** through `go_router`: `/e/:code` calls `events.share_preview` and `events.event_by_code`, then opens `/event/:id`; `/u/:username` opens `/people/:id`. A bad code opens a friendly "Event not found" screen.
- Android: `intent-filter` with `android:autoVerify="true"` for the domain; iOS: Associated Domains entitlement `applinks:<domain>`.
- Sign-in is not needed to open a shared link; saving, following and booking use the existing sign-in sheet.

## Tests (written first)

pgTAP: `share_preview` returns a public and a private event, nothing for draft or cancelled, and exposes no private fields; `person_preview` exposes only the listed fields.
Deno: `share-page` returns correct meta tags for an event and a person, 404 for a bad code, `noindex` only on private events, and the two well-known files.
Flutter: share button builds the right text and link; `/e/:code` and `/u/:username` routes resolve; a bad code shows the not-found screen; link parsing with and without a trailing slash.
Device checks (iOS first, then Android): the share sheet; a link tapped from WhatsApp or Telegram opens the app. Verified links need a real domain, a signed build and the two well-known files live; the iOS simulator can open links with `xcrun simctl openurl` but cannot prove Universal Links from a chat app.

## Out of scope

Instagram and TikTok poster images; click statistics; a full web version of the event pages.

## Needs from the owner (waiting time)

Buy the domain, point it at Cloudflare, and choose the app name before the store pages exist.
