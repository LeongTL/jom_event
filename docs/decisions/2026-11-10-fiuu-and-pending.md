# Decisions and pending list (10 Nov 2026)

Status: brainstorming notes. Nothing here is an approved design yet; each item below still needs its own design and approval.

## Decided

**MVP payment model (decided 11 Nov 2026): manual bank transfer with proof upload. No gateway, no commission in the MVP.**
- The guest holds a seat, sees the host's payment details (bank account or DuitNow QR) and an unique reference code, pays by themselves, uploads the transfer receipt, and the host confirms or rejects. Confirmed means ticket issued; rejected or timed out means the seat is released.
- Hosts use the platform free during the MVP, to attract traffic. Platform commission is NOT collected. Whether to start charging a commission, or to integrate a gateway, is decided later, only if the market proves it wants the product.
- Fiuu stays the intended gateway for after the MVP (see below). It is not built now.
- Host payment details shown to guests: both a DuitNow QR image the host uploads and bank name, account number and holder name (decided 11 Nov). A host must give at least one; a guest sees whatever the host filled in.
- Seat hold for paying and uploading proof: 2 hours (decided 11 Nov). Once a guest submits proof the hold stops running out and waits for the host. Open: shorter hold close to event start, and what happens if the host never confirms.
- Host push notification when a guest submits proof (decided 11 Nov). This REVERSES the 14 Oct decision "no push in the MVP": the in-app bell is not enough when a host must confirm within hours. Needs device tokens, APNs and FCM setup, and a server job that sends the push. Guests still get in-app notifications only, for now.
- Fits the existing design: reuse the `processing` booking state and add a manual-transfer implementation behind `PaymentProvider`; "host confirms" replaces the gateway webhook.
- Changes needed (not yet designed): longer seat hold than 15 minutes, states and timeouts for "no proof uploaded" and "host never confirms", host payment details visible to guests (today only the host and an admin can read bank details), receipt image storage with access limited to that guest and host, a host confirm screen, refunds done by the host (platform holds no money).
- Risks to design for: fake receipts (host should check their own bank account, not the image), hosts who confirm late, disputes without a platform transaction record, and getting hosts to accept a fee later after a free period (tell them up front that the MVP is free for a limited time).
- Effect on other work: MVP fee maths, `fee_snapshots`, payouts, the Payouts screens, and the "platform fee" card in the back office wireframe are not needed in the MVP. Keep the code and tables, do not delete them.

**Payment gateway after the MVP: Fiuu.** The real gateway will be Fiuu (Malaysia). It replaces `MockProvider` behind the existing `PaymentProvider` interface (`supabase/functions/_shared/payment_provider.ts`: `createSession`, `parseWebhook`, `refund`). The webhook idempotency (`claim_webhook_delivery`, `apply_gateway_result`) stays as it is.

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

**One app for now, host entrance behind a flag (decided 13 Nov).** Audience and host stay in one app. In Settings (Profile) a signed-in user sees "Register as Event owner". After the platform approves them, Settings shows the entry to the host view instead; until then only the register button shows. The entrance is controlled by a feature flag so the flow can change later, for example if the host side is split into a second app. Today `identity.apply_host` sets `is_host = true` at once with no approval step (`verified_at` is only a badge set by hand), so a pending/approved state is new work. Approval is done by the platform admin in the web back office, not by hand in the Supabase dashboard (decided 13 Nov). The back office therefore has two roles, host and platform admin, kept strictly separate. Admin scope in the MVP (decided 13 Nov): approvals, a host list, and a platform-wide overview of events and bookings. Because approvals are needed to onboard the seed hosts, the approvals page has to be built before the rest of the back office (suggested order: approvals, then host list with suspend, then the overview). Admins (decided 13 Nov): the owner plus a few staff, all with the same admin rights. The admin role is given by hand in the database only, never from inside the app. Every approval, rejection and suspension records which admin did it and when. Suggested, not yet confirmed: two-factor sign-in required for every admin account.

**Private and Public events (decided 13 Nov).** A host picks Public or Private when creating an event. Public: visible to everyone, in Explore, search, map and the host's public profile, as today. Private: hidden from all of those; anyone who has the host's share link can open the event, join and pay, and can forward the link. No host approval per guest. Needs: database access rules that exclude private events from the open read policy, an unguessable share code (not the event id), private events left out of every list, and a landing page that is not indexed by search engines. Depends on the sharing work (share button, landing page, deeplinks).

**Host back office scope (decided 13 Nov): hosts can also create and edit events on the web**, not only read. So the host side covers: overview, events (create, edit within the same lock rules as the app, delete with refunds), guests, a pending-payments page to confirm or reject receipts, reviews, and host profile. The business rules already live in the database functions (`events.save_draft`, `events.publish`, `events.update_event`, `events.delete_event`), so the web form reuses them; only the screens are built a second time. Open for the design spec: whether the web is Flutter web or a separate web app.

## Under discussion (not decided)

1. **Free events are Save-only, with a saves count for the host** (decided 13 Nov). No Join, no ticket, no seat limit or guest list for free events; the guest sees Save, Directions and the source link, the host sees how many people saved it. Reverses the MVP rule "free events need only a sign-in to join". Touches the free branch of `bookings.create_booking`, the free join screens and `free_join_journey_test`.
2. ~~One app or two~~ Decided: one app for now (see "One app for now" above).
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
