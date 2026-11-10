# Decisions and pending list (10 Nov 2026)

Status: brainstorming notes. Nothing here is an approved design yet; each item below still needs its own design and approval.

## Decided

**Payment gateway: Fiuu.** The real gateway will be Fiuu (Malaysia). It replaces `MockProvider` behind the existing `PaymentProvider` interface (`supabase/functions/_shared/payment_provider.ts`: `createSession`, `parseWebhook`, `refund`). The webhook idempotency (`claim_webhook_delivery`, `apply_gateway_result`) stays as it is.

What we know (source: Fiuu pricing appendix dated 19 Apr 2024, about two years old; real contract rates may differ):

| Channel (online) | Rate |
|---|---|
| FPX / DuitNow online banking (B2C) | 2.4%, minimum RM 1.00 |
| DuitNow QR | 1.00% |
| Touch 'n Go | 1.50% |
| ShopeePay | 1.30% |
| GrabPay, Boost | 1.40% |
| Visa / Mastercard, local | 2.40% |
| Visa / Mastercard, foreign | 3.15% |
| MyDebit | 2.00% |

Other terms: signup fee RM 99 (the PDF also shows RM 999, unclear which is current), yearly fee RM 99 (first year waived), FPX refund RM 0.70 per refund (needs applying for), settlement weekly on Thursday (domestic e-wallets T+2), minimum settlement RM 100, no chargeback fee, no reserve.

Integration model: hosted payment page. Fiuu has a Notify URL (server to server), a Return URL (browser redirect) and a Callback URL (deferred methods such as 7-Eleven cash). Signature is a keyed hash; exact parameter order, vcode, refund API and sandbox were NOT confirmed and must be read from Fiuu's full docs before building.

**Must ask Fiuu before designing the payout flow:**
1. Can one payment be split to several hosts (Marketplace Payment), or do we collect and pay hosts ourselves?
2. Can individual hosts (no SSM company) be paid out?
3. How do refunds work end to end (FPX refund via ORF, delete-event refunds)?

Cash-flow note: Fiuu settles weekly, the MVP design pays hosts 3 working days after the event. We may pay out before Fiuu settles.

**Security audit (later).** The user will tell us when. Then install `cloudflare/security-audit-skill`, read it first, and audit all access control (BAC, RBAC), RLS, `security definer` functions, webhook signatures, ticket HMAC, host bank details, and the new back office and share links.

## Under discussion (not decided)

1. **Free events are Save-only** (no Join). Open: A pure listing, B listing plus saves count (recommended), C optional RSVP per event. Reverses the MVP rule "free events need only a sign-in to join".
2. **One app or two.** Leaning one app; hosts do desk work on a web back office, phone app for scanning and chat.
3. **Host back office (web).** Lo-fi wireframe agreed in principle: Overview, Events, Event detail, Payouts, Host profile. Open: read-only (A, recommended first) or with event create and edit (B), and whether a platform admin view (C) is wanted. Was "not in MVP" in the MVP design.
4. **Event sharing and deeplinks.** None exist today (no share button, no App Links or Universal Links, no domain, no landing page). Routes `/event/:id` and `/host/:id` are ready. Leaning: share button plus a landing page with preview card first (WhatsApp and Telegram), App Links second, Instagram Story image later. Open: WhatsApp/Telegram only (A), Instagram/TikTok (B), or both (C).
5. **1000 concurrent users.** Design is sound (booking race is handled in the database) but the largest test so far is 200 users on the last-seat race, 100 on Home, 50 on chat. Run the k6 scripts on staging at 1000, check the connection pool, consider caching Home.

## Pending (from the implementation plan and today's findings)

Release work (plan Tasks 24 and 25):
- Run the k6 load tests on staging, add missing indexes, re-run (plan Task 24 steps 2 to 4).
- Low-end Android scroll check and iPhone check for Home and the dock.
- Real-device test: scan a real ticket QR shown on a second phone.
- Test the mock gateway success, failed and slow outcomes on `dev`.
- Google sign-in on a phone: create the iOS and Android OAuth clients (`docs/release/staging.md`).
- Release checklist, legal pages, `release.yml` signed builds, TestFlight and Play internal testing, onboard 20 seed hosts by hand (plan Task 25).
- Decide the app name and bundle id (affects the OAuth clients).

New scope from this session:
- Fiuu integration (`FiuuProvider`, return flow in the app, refunds, payout design) after the three Fiuu questions are answered.
- Free event Save-only change (touches `create_booking` free branch, free join screens, `free_join_journey_test`).
- Host web back office.
- Share button, landing page, deeplinks, domain.
- Security audit (see above).
- Real SMS provider for phone sign-in (staging only accepts test number `+60123456789`).
