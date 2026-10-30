# Jom (KL Local Session) – MVP Design

Oct 14, 2026 · @Leong · app name "Jom" (formerly "KL Local Session"; assumed available, store and trademark check still advisable before release)

**The hi-fi prototype `prototype/jom-hifi.html` is the source of truth for what the app does.** This doc describes the prototype screen by screen and turns it into rules a developer can build. `docs/source/research.md` and `docs/source/project-plan.md` give the market and scope background; where they disagree with the prototype, the prototype wins and the difference is listed under "Differences from the earlier docs".

## Goal and scope

A mobile app (Android and iOS, one Flutter codebase) where young people in KL and Selangor discover small offline workshops and social events, join them (paid events are paid for in the app, free events need only a sign-in), get a ticket, chat with the host, and review the event afterwards. Free community events show a "Join · Free" page with a link to the original post. Anyone can switch to **Host mode** to create events, see guests, check people in, and get paid out.

**Done means a workable app:** a stranger installs a beta build, browses without an account, signs in to join or save, books and pays (payment is mocked until the gateway is chosen, see "Pending and later"), receives a QR ticket, asks the host a question in Chat, attends, and reviews. A host creates an event, watches bookings fill, checks guests in, closes the event, and sees the payout. It passes the end-to-end test and ships to a closed beta.

## Differences from the earlier docs

| Topic | Earlier docs | Prototype (wins) | What follows |
|---|---|---|---|
| Payments | `project-plan.md`: none in MVP, bank transfer, payments are V2 | In-app payment through a gateway (FPX, card, e-wallet, DuitNow QR), a 10% platform fee, host payouts | Payments are in the MVP. **Update `project-plan.md` sections 1, 5 and 7.** New risks and open questions below. |
| Time bar | Now / Late / Sat / Sun / Later | Now / Night / Weekend / All | Prototype. |
| Sign-in | Google / email | Google or phone number; browsing open; **saving, joining (free or paid) and chatting need sign-in** | Prototype. |
| Chat with host | In the plan as "enquiry chat" | **Chat tab** (list and thread) for attendees and for hosts | **In the MVP** (decided Oct 14). Text only, one thread per attendee and host. |
| Admin backend | In the plan | No screen | Not in MVP. Host verification is manual (open question 1). |
| Push reminders | In the plan | Bell with badge, Chat badge, a "Notifications" row; no Notifications screen drawn | **No push in the MVP** (decided). New notifications show in the app only (bell badge and list). |
| Booking size | Not stated | Up to 2 people per booking | Prototype. |
| Cancellation policy | Fixed 24 h free cancellation | The host picks it when creating the event: 24 h, 48 h, 7 days, or no refunds; shown on the event, checkout and ticket | Per-event policy (decided). |
| Event editing | Hosts edit events | Host Event details has an **Edit** screen: title, description and spots are editable; date, place, price and refund window are locked once guests have joined | **Limited edit** (decided Oct 14). |
| Check-in | Host toggle | Host checklist plus a QR code on the attendee's ticket | Manual checklist now; scanning the QR is later. |

## Screens and flows (from the prototype)

**Roles.** One account can be an attendee and a host. Profile has "Switch to Host mode"; Host Profile has "Switch to Attendee mode". Attendee tabs: Explore, Saved, Bookings, **Chat**, Profile. Host tabs: Home, Events, Payouts, **Chat**, Profile. Chat tabs show an unread badge.

### Attendee

| Screen | What it shows and does |
|---|---|
| **Explore (Home)** | Hero with the event count (odometer) and "N happening now · N free · closest X km · best 9 shown". Map-style pins and a card dock for the top 9 events (rules below). Time bar Now / Night / Weekend / All. Top bar: area pill (default Bangsar) opens the area sheet; bell; avatar circle. Hero wording per tab: Now "WED · 7:42 PM / N things are happening near you", Night "WED · TONIGHT / N ways to spend your night", Weekend "SAT 17 – SUN 18 OCT / N things to do this weekend". Dock cards show title, "Happening now" or the start time, price and distance. Browsing needs no account. |
| **View all** (opened by the All tab) | Full-screen page with a close button. Header "EVERYTHING IN KL · All 87 events". Scrolling chip row All, Make, Move, Meet, Free with counts. With All selected the page shows one section per category (title and count); with a chip selected, only that grid. 2-column posters. Each poster: a top tag (a red "HAPPENING" for live events; "⏱ in 17:42" counting down by the second for events starting within 2 hours; "⏱ in 1h 32m" beyond that; a clock tag such as "🌙 11:30 PM" or "SAT 2:00 PM" for later ones), a price pill (RM or Free), the event name, distance, and a save heart. |
| **Area sheet** | "Where to?" Chips: Bangsar, KLCC, PJ, Sri Hartamas, Mid Valley, Bukit Bintang (one selected, Bangsar by default). "Within" 2 km, 5 km (default), 10 km. Button "Show events". The prototype stores the choice but does not filter yet; the app must apply it to Home, View all and distances. |
| **Event (bookable)** | Shown for paid events. Hero art with a back button and a save heart. Label "Workshop / Fitness / Social · N spots left" (Make, Move, Meet), title, host row (avatar, name, ★ 4.8 · 36 reviews, opens the host profile), three tiles: date and time with duration ("Sun 9:00 AM · 1 hour"), area with distance ("Bangsar · 1.2 km away"), price per person; description; "✓ Free cancellation up to 24 hours before". Bottom bar: save heart and "Join · RM price". |
| **Event (free)** | Shown for free events. "Free · Join to save your spot", when, three tiles (when, area with distance, "Free · entry"), description ("A free community event, hosted by …. Join to get your ticket and the host's updates."), Get directions, a source card "Source: … on Instagram · View original post ↗". Bottom bar: save heart and **"Join · Free"**, which needs sign-in. Joining goes to Checkout (no payment, no hold) with button "Confirm my spot" and ends at the Ticket. Hosts can also message guests. |
| **Sign-in sheet** | A signed-out user can walk through the whole app (Explore, View all, event pages, host profiles). **Saving (heart), joining (free or paid) and chatting need an account.** Each opens this sheet; the heading and line change with the reason: "Sign in to join: Free or paid, we need to know who is coming. Browsing stays open." / "Sign in to save" / "Sign in to chat". Buttons Continue with Google and Continue with phone number. After signing in, the action the user started completes (event saved, Checkout opens, thread opens). Phone sign-in sends an SMS code (mocked until a provider is chosen). |
| **Checkout** | Event summary, for paid events "Spot held for 14:32" countdown, People stepper (− 1 +, "Up to 2 per booking"), contact (name and phone with an Edit link), Total (RM or "Free"), the **host's cancellation policy** ("Free cancellation up to 48 hours before" or "No refunds once booked") and "Paying (or Joining) means you accept the host's policy". Button "Pay RM total" or "Confirm my spot". |
| **Gateway page** | Stands in for the payment provider's hosted page: "Secure payment", amount, reference (for example KLS-4821), a radio list of the methods the gateway offers (online banking FPX with Maybank2u, CIMB Clicks, Public Bank; credit or debit card with Visa and Mastercard; e-wallet with Touch 'n Go, GrabPay, Boost, ShopeePay; DuitNow QR), "Methods shown are whatever the gateway offers. Session expires in 09:41", button "Pay RM total". This page is the gateway's own, not ours, so the real app opens the provider's hosted page and returns to the app. |
| **Confirming payment** | A spinner, "Confirming your payment. Please don't close the app or pay again. This takes a few seconds." and a reference with "Processing". Three outcomes: success, failed, delayed. (The three simulate buttons are prototype-only.) |
| **Payment failed** | "Your spot is held for another 06:12. If any money left your account, it's refunded automatically." Buttons Try again (back to the gateway) and Give up (release the spot, go Home). |
| **Ticket** | "You're in! A receipt was sent to your email." Event, QR code, reference, "Show this to the host on arrival", Directions, Add to calendar, Cancel booking, Done. |
| **Cancel sheet** | "Cancel this booking? You're within the free cancellation window. RM30 goes back to your original payment method in 3 to 7 working days." Buttons Yes, cancel and Keep booking. Shown only while inside the host's window; with "No refunds" or after the cutoff the Cancel button is hidden. |
| **Bookings** | Switch Upcoming / Past. Each booking: event art, name, date and time, status pill: Confirmed or Processing (payment delayed) under Upcoming; Attended or Cancelled under Past. Tapping an attended booking opens Review ("Tap an attended event to write a review"). Tapping a confirmed booking should open its ticket. |
| **Saved** | Poster grid of hearted events. |
| **Chat (list)** | Tab with an unread badge. One row per host (avatar, host name, last message, time, unread dot). Subtitle "Ask a host before you book." |
| **Chat (thread)** | Header with back and host name, an event card (art, title, date, area), a notice "Keep the chat in Jom. Phone numbers and social handles can't be shared here.", message bubbles with times, input and send button. Opened from the Chat tab or the "Message" button on the host row of an event page (needs sign-in). |
| **Review** | Event, date and host, five tappable stars (four set by default in the prototype), tag chips you can switch on (Friendly host, Good value, Beginner-friendly, Clean venue), "Your review: What was it like?", "✓ Verified attendee", button "Submit review". |
| **Host public profile** | Banner with back button, avatar, host name, "Bangsar · hosting since 2026", three stat tiles (4.8 rating, 36 reviews, 120 guests), "Coming up" sliding row of posters, "Reviews" list (name, stars, text). |
| **Profile** | Avatar, name, phone; rows My reviews, Notifications, Help & support, Terms & privacy; a highlighted "Switch to Host mode · Run your own events" card. |

### Host

| Screen | What it shows and does |
|---|---|
| **Host Home** | "Good evening", host name, HOST badge. A payout card "Upcoming payout RM318.60 · Wed 21 Oct → Maybank ••4821" (opens Payouts). Next event card with a fill bar ("12 of 12 paid · full") and buttons Bookings and Check-in. Tiles "14 bookings this week" and "4.8 ★ average rating". Button "+ New event". |
| **Host Chat (list and thread)** | Tab with unread badge; same layout, "Messages from guests about your events." Replies from the host appear as the host's bubbles. |
| **Host Events** | Tabs Draft, Published, Ended. Each card shows art, name, date and a pill "paid / spots" (green when full). Tapping a card opens **Event details**. "+ New event". |
| **Host Event details** | Poster, status, title, date, venue, a fill bar ("Full" or "N spots left"), three tiles (joined, checked in, gross), buttons **Scan tickets** and **Guest list**, an Event details card (description, price, refund window, expected payout, Edit link), a Messages row with unread count, a note about completion, "Delete this event", and a bottom button **Mark as completed**. |
| **Edit event** | Same form as New event. Editable: title, description, spots (stepper; cannot go below spots already sold, max 40). Shown with a lock and not editable: categories, date and time, venue, accept-bookings switch, price, refund window. "Save changes" or Cancel. |
| **Scan tickets** | Full-screen camera viewfinder with corner brackets and a moving scan line, a counter "6 / 12", a result card (guest name, people, ticket code, "Checked in just now" or "Waiting for a ticket"), and "Enter code manually / see list" (opens Check-in). The prototype has a "Simulate a scan" button; the app uses the real camera. |
| **Complete sheet** | "Mark as completed? Guests can leave reviews and your payout is scheduled for 3 working days later. 7 guests didn't check in. If you do nothing, the event completes by itself 24 hours after it ends." Buttons "Yes, mark completed" and "Not yet". |
| **New event** | "Add a poster" (upload), title, category chips Make, Move, Meet, Other (switch on to pick), when ("Sun 18 Oct · 9:00 – 10:00 AM"), where (an address line, "Bangsar, Jalan Telawi 3"), switch "Accept bookings: Guests pay online to join", price, spots, "Payouts to Maybank ••4821", buttons Save draft and Publish. Under "Cancellation by guests" the host picks 24 h before, 48 h before, 7 days before or No refunds. Also has a description box, a note "After the event, mark it completed yourself, or it completes automatically 24 hours after it ends", and Save draft / Publish. |
| **Guest list** | One event: date, paid count, gross. List of paid guests with the method they paid by and a Paid pill; "+ 7 more". Red "Delete this event" link opens the **Delete sheet**: "Delete this event? 12 guests have paid RM360 in total. All of them are refunded in full and told the event was cancelled. This can't be undone." Buttons "Yes, delete and refund" and "Keep event". |
| **Check-in** | A ring showing "5 / 8 checked in". Each guest with their ticket code and a tick box that can be ticked and unticked (the manual fallback). Buttons Scan and **Mark as completed**. |
| **Payouts** | Upcoming and Paid out totals. Per event: Gross (12 × RM30) RM360.00, Gateway fees −RM5.40, Platform fee (10%) −RM36.00, You receive RM318.60. Note "Illustrative numbers. Real fees depend on the gateway agreement." Payout account row (Maybank ••4821 · verified). |
| **Payout account** | "We pay your earnings here 3 working days after each event." Account holder, bank, account number, business registration (SSM · verified ✓), Save. |
| **Host Profile** | Rows Payout account, View public profile, Edit host info, and the Attendee mode switch. |

## Linked in the prototype but not drawn

The prototype has buttons and rows that lead to screens it never shows. Because the prototype is the end goal, each needs a screen or a defined behaviour:

| Item | What the app needs |
|---|---|
| Bell on Home (and none on Host Home) | Notifications screen is drawn; add the same bell to Host Home |
| Profile > Notifications | Opens the Notifications screen (list and switches) |
| Profile > My reviews | List of the reviews I wrote (no edit or delete in the MVP: the database keeps one review per booking) |
| Profile > Help & support | Contact and FAQ page |
| Profile > Terms & privacy | Terms and privacy policy pages |
| Profile avatar on Home | Opens Profile |
| Sign-in (Google or phone) | Phone number and one-time-code screens; sign-up details (name) on first sign-in |
| Checkout > Edit contact | Edit name and phone |
| Ticket > Directions, Free page > Get directions | Open the phone's maps app at the venue |
| Ticket > Add to calendar | Add to the phone's calendar |
| Free page > View original post | Open the source link |
| Ticket > Cancel booking | The cancel sheet above (refund note), then the booking shows Cancelled |
| Bookings > a booking | Open its ticket |
| Host Profile > Edit host info | Edit host name, area, bio, avatar |
| Host Profile > Payout account, Payouts > Edit, New event > "change" | The Payout account screen |
| Host Bookings > "+ 7 more" | The full guest list |
| Host Events > a card | Host Event details (Scan tickets, Guest list, Edit, Mark as completed) |
| Hearts everywhere | Require sign-in (opens the sheet), then one saved list; see "Saved events" in the backend section |
| Log out and delete account | Not in the prototype; required by the app stores, add to Profile |

## Home rules

**Time tabs** (in `Asia/Kuala_Lumpur` time whatever the phone's zone). With `now`:
- *Now*: live events (started, not ended) and events starting within 120 minutes.
- *Night*: events starting later tonight, meaning after the Now window and before 04:00 the next morning (a 01:30 event belongs to tonight). Night never contains an event that is in Now.
- *Weekend*: Saturday and Sunday events; on a Saturday or Sunday, what is left of the weekend.
- *All*: opens the View-all page (every upcoming or live event); it is a page, not a list state.
- An event can be in Night and Weekend together. Ended and cancelled events are in no tab.

**Pins and dock.** Only the top 9 events by score are shown, each as a pin and as a dock card, so every pin has a card. Score = `(live ? 3 : 0) + (starts in under 30 min ? 2 : 0) + (free ? 1 : 0) − distanceKm × 0.35`. Pin positions are decorative, not geographic: seeded from the event id, pushed apart until no two are closer than 72 px, scaled to fill about 215 × 190 px and centred, and stable across redraws and tabs. Real distance in km is computed from the user's coarse location and shown on cards. Cards are 196 × 104; the centred card is lifted (translateY −12, scale 1.06) and its neighbours step aside. Tapping a pin scrolls the dock to its card without rebuilding it; scrolling the dock selects the pin; tapping the centred card opens the event; a side card centres on tap. Live events read "Happening now". With no events the hero says "Nothing right now".

**Look.** Film-grain background over a per-tab sky: Now (sunset), Night (dark sky with a moon), Weekend (day sky with a sun). The hero count is an odometer of lime `#c8ff2e` tiles with a pulsing glow on every tab. Colour tokens are copied from the CSS variables in the prototype (`.phone[data-t=...]`). Pins use a map-pin shape with a soft street-map backdrop.

**Categories.** Make, Move, Meet (an event can have several); Free is derived from price 0; the host form also offers Other, which shows in All only. An event with several categories appears under each chip on View all.

## Booking and payment rules

**Which page opens.** An event is bookable when the host turned on "Accept bookings" and its price is above 0; otherwise the free page opens. (Free events are joined from the free page and need sign-in.)

**Booking states:** `held` → `processing` → `confirmed` → `attended`, with `payment_failed`, `cancelled` and `expired` as side exits.
- Tapping Join and then Checkout creates a `held` booking and holds the seats for 15 minutes (the prototype shows 14:32). Seats are counted for `held`, `processing` and `confirmed` bookings. Two people taking the last seat at once must produce exactly one booking.
- Pay opens the gateway (session about 10 minutes). The gateway's webhook decides the outcome, never the app screen: success → `confirmed` and a receipt email; failure → `payment_failed`, the hold keeps its remaining time, Try again reuses it; no answer yet → `processing`, shown in Bookings as "Processing" until the webhook arrives.
- A `held` or `payment_failed` booking whose hold runs out becomes `expired` and frees its seats. A success webhook that arrives after expiry is refunded automatically unless the seats are still free, in which case the booking is confirmed.
- Cancelling is offered until the cutoff the **host chose** for that event (24 h, 48 h, 7 days, or never): status `cancelled`, seats freed, a refund to the original payment method (3 to 7 working days). The policy is copied onto the booking when it is made, so it cannot change under the guest. After the cutoff, or with "No refunds", the Cancel button is not shown. Free events: cancelling just releases the spot. If the **host deletes the event**, every booking is cancelled and refunded in full regardless of policy.
- Check-in marks `confirmed` → `attended`. Completing the event (host taps Mark as completed, or auto after 24 hours) sets it `ended`, marks the rest `no_show`, and unlocks payout and reviews.
- Maximum 2 people per booking. Prices are integer sen, shown as `RM 45` or `Free`.

**Money.** Gross = price × people. Platform fee = 10% of gross. Gateway fees are whatever the gateway charges (the prototype's example is 1.5% of gross, shown as illustrative). Host receives gross − gateway fees − platform fee, paid to the host's bank account 3 working days after the event is closed. Each booking stores its own fee figures so old bookings do not change when rates change. Refunded bookings are removed from gross.

**Reviews.** Only an attended booking can be reviewed, once, after the event is closed. Stars, one or more tags and optional text. Host profile shows the average and count; "Verified attendee" appears on each review.

**Hosts.** A user applies to host by filling the payout account (holder such as "Mei Studio Sdn Bhd", bank, account number, SSM registration). The "verified" badges in the prototype mean the account name and SSM details were checked before the first payout (open question 1: who checks). **Individual hosts can register** (decided): the SSM business registration is optional; a host without one is verified another way (open question 10).

**Hosts create, lightly edit, and delete events (decided).** The New event form covers title, description, poster, categories, date and time, venue, price, spots, the accept-bookings switch and the refund window, saved as a draft or published. A draft can be changed freely. **After publishing, a host can edit the title, description and spots** (add or cut, never below the seats sold). Date, venue, price and refund window are locked once any guest has joined (a host with no guests yet can still change them). To change a locked field the host deletes the event and creates a new one. A new title or description is shown to existing guests; a change to spots notifies no one. Deleting an event with bookings refunds every booking in full, marks it `cancelled`, and notifies every guest in the app.

**Completion and payout.** After the end time the host taps **Mark as completed**; otherwise a scheduled job completes the event **24 hours after its end time**. Completing moves `confirmed` bookings that were never checked in to `no_show`, unlocks reviews for `attended` guests, and starts the 3-working-day payout clock. An event with no check-ins still completes and still pays (guests paid for it); no-shows get no refund.

**Check-in.** The host scans the QR on the guest's ticket with the phone camera. The ticket QR carries a signed token for the booking. `bookings.check_in(token)` verifies it belongs to this event, is `confirmed`, and not already used, then sets `attended`; a second scan of the same ticket says "Already checked in at 9:02 AM". A ticket for another event, a cancelled booking or an unpaid one is refused with a clear message. The manual list with tick boxes is the fallback when a camera or QR fails. Scanning needs a connection in the MVP; without one the host uses the manual list.

## Architecture

The Flutter app calls only Supabase over HTTPS; row-level security protects every table, and signed-out users may read published events. Edge functions receive gateway webhooks and run scheduled jobs. A modular monolith with six modules, each with its own Postgres schema and migration prefix, following the same boundary rules as the TCG Card Community project (a module reads and writes only its own schema and reaches others through a view or function):

| Module | Owns |
|---|---|
| `identity` | profiles, roles, host profile and payout account, saved events, in-app notifications |
| `events` | events, categories, event status (draft, published, ended, cancelled) |
| `bookings` | bookings, seat holds, check-in, ticket codes |
| `payments` | payment attempts, gateway webhooks, refunds, fee snapshots, payouts |
| `reviews` | reviews and tags, host rating view |
| `chat` | threads (one per attendee and host), messages, read markers |

Local, staging and production are three Supabase projects applying the same migrations; Flutter flavors `dev`, `staging`, `prod`. The payment provider sits behind a `PaymentProvider` interface. **The MVP ships a mock implementation** (always succeeds, can simulate failed and delayed); the real gateway is built later. The SMS provider sits behind an `OtpSender` interface, also mocked at first.

## Backend

Proposal, to confirm. Everything is in the one Supabase project, split by the six modules above.

**Tables**

| Module | Tables and key fields |
|---|---|
| `identity` | `profiles` (name, phone, host flag); `hosts` (host name, area, bio, bank, account holder, account number, SSM number optional, `verified_at`); `saved_events`; `notifications` |
| `events` | `events` (host, title, description, glyph and two colours, poster, categories, area, venue, coordinates, starts and ends, capacity, `price_sen`, `cancel_policy` (24h, 48h, 7d or none), `accept_bookings`, `source_url`, status draft / published / ended / cancelled) |
| `bookings` | `bookings` (event, attendee, people 1 to 2, status, `hold_expires_at`, ticket code like KLS-4821, contact name and phone, checked-in time) |
| `payments` | `payment_attempts` (booking, gateway reference, method, status, raw webhook); `refunds`; `fee_snapshots` (gross, gateway fee, platform fee, host receives, saved per booking); `payouts` (host, event, amount, status, due date, paid reference) |
| `reviews` | `reviews` (booking, stars, tags, text); view `host_rating(host_id, average, count)` |
| `chat` | `threads` (attendee, host, optional event, `last_message_at`); `messages` (thread, sender, body, created_at); `thread_reads` (thread, user, `read_at`) |

**Functions** (the app calls these; it never writes bookings or payments directly)
- `bookings.create_booking(event_id, people)`: locks the event row, counts seats from held, processing and confirmed bookings, creates a `held` booking for 15 minutes. Two people taking the last seat give exactly one booking.
- `payments.start_payment(booking_id)`: creates the attempt and returns the gateway session.
- `payments.apply_gateway_result(attempt_id, outcome)`: the only way a booking becomes confirmed, failed or processing. Safe to replay: the second call changes nothing.
- `bookings.cancel_booking(booking_id)`: refused after the booking's own cutoff (from the host's policy); frees seats and creates the refund.
- `events.update_event(event_id, title, description, capacity)`: host only; rejects capacity below seats sold or above 40; touches no other field after publish. `events.delete_event(event_id)`: host only. Cancels every booking, calls `payments.refund_booking` for each paid one, marks the event `cancelled`, writes a notification per guest. One transaction; a failed refund is retried by a job and shown to you in a "refund failed" list.
- `bookings.check_in(token)` and `events.complete_event(event_id)`: see Check-in and Completion above. A job `events.auto_complete` runs every 15 minutes.
- `chat.send_message(thread_id, body)`: checks the sender belongs to the thread, **rejects bodies containing phone numbers, WhatsApp or Instagram handles** (same filter as event text), writes the message, adds a notification for the other side. `chat.open_thread(host_id, event_id)` finds or creates the thread. Realtime delivers new messages.
- `reviews.submit_review(...)`, `identity.apply_host(...)`.

**Edge functions and scheduled jobs**
- `payment-webhook`: checks the gateway signature, then calls `apply_gateway_result`.
- `expire-holds` (every minute): expires held and failed bookings whose hold ran out and frees their seats.
- `schedule-payouts`: creates payout rows 3 working days after an event is closed; transfers are manual at first (open question 4).
- `receipt-email`: sends the receipt and ticket on confirmation.
- `delete-account`: removes personal data on request.

**Security**
- Signed-out users can read published events, host profiles and reviews, and nothing else; saving, booking and reviewing need an account.
- A user sees only their own bookings and payments; only the webhook function writes payment results.
- Host bank details are readable only by that host and by an admin.
- A review is allowed only for an attended booking, once.

**Saved events (the hearts).** One row per user and event in `identity.saved_events(user_id, event_id, created_at)`, primary key on the pair so a double tap cannot duplicate. `identity.toggle_save(event_id)` adds or removes it and returns the new state. A user reads and changes only their own rows. Every heart (poster, event hero, event bottom bar) and the Saved tab read the same list. A saved event that has ended stays in Saved, greyed with an "Ended" tag.

**Notifications (in-app only, no push in the MVP).** `identity.notifications(user_id, type, ref, title, created_at, read_at)` written by `identity.notify(...)` from the other modules. The bell and the Chat tab show unread badges and update live through Realtime. The Notifications screen (opened by the bell and by Profile > Notifications) is drawn in the prototype: a list with unread dots, tap to open the booking, thread or event, and switches for the optional types. Triggers: booking confirmed, payment delayed then resolved, payment failed, event deleted and refunded, new chat message, review request after close; for hosts: new booking, event full, payout sent. Reminders before an event are **not** sent in the MVP because they would need push. FCM push is a later add-on.

**Backend risks to test:** a payment result that arrives late or twice; a result that arrives after the hold expired; fee maths in integer sen; deleting an event while someone is paying for it (the held or processing booking must also be refunded or released); refund failing halfway through a delete; a chat message with a phone number split across words; a thread opened by a signed-out user.

## Testing and launch

| Layer | What it covers |
|---|---|
| Unit | Time tabs, scoring, pin layout, money and fee maths, odometer |
| Database (pgTAP) | RLS; last-seat concurrency; hold expiry; webhook idempotency; per-event cancellation cutoff; delete-event refunds everything; chat thread access and contact filter; payout amounts; review eligibility |
| Widget | Home with 0, 1 and many events; dock and pin sync; checkout timer; each payment outcome screen |
| Integration | Sign in at booking, pay in the gateway sandbox, ticket, host check-in, close event, review, payout record |
| Real devices | One low-end Android and one iPhone: dock scrolling, grain and glow |

Launch checklist: privacy policy and terms (the Profile rows); PDPA consent; in-app account deletion; sandbox then live gateway; payout process rehearsed with one real host; 20 seed hosts onboarded by hand; closed beta of 20 to 50 people on TestFlight and Play internal testing; KPIs from `project-plan.md` section 9.

## Pending and later (decided Oct 14)

| Item | Status |
|---|---|
| **Payment gateway** | **Pending.** We will build it, but not now. The MVP uses a mock `PaymentProvider` with the same interface (success, failed, delayed). The Gateway page screen stays as the hosted-page stand-in. Choosing a provider, the host payout method and the regulatory check come before any real money moves. |
| **Host eKYC** | Noted for later, not in the MVP. For the beta, hosts are checked by hand (open question 1). |
| **SMS provider** | Later. OTP is mocked for now (fixed code in dev and staging). |
| **Push notifications** | Not in the MVP. In-app notifications only. |
| **Full editing of published events** | Not in the MVP. Only title, description and spots can change; everything else is delete and recreate. |
| **Admin backend** | Not in the MVP. |
| **App name** | "Jom" is assumed available. |

## Build progress (30 Oct 2026)

| Part | Status |
|---|---|
| Backend, sign-in, Home, event page, booking, chat, notifications (Tasks 1 to 19) | Built and merged |
| Calm redesign 19A to 19G (cards, design system, Tickets, Home, map, event and checkout, Saved, Chat, Notifications, sign-in) | Built; 19F and 19G wait in PR #30 to reach `main` |
| Task 20: reviews, host public page, Profile, Help, Terms and privacy, account deletion | Built, in its own PR; simulator walk not done yet |
| Tasks 21 to 25: host mode, scanner and payouts, end-to-end tests, load tests, closed beta | Not started |

Known gaps: the real paid booking through the mock gateway has not been walked on a device; no Android device test; staging does not have the Calm backend yet; the support email and the legal texts are drafts until Task 25.

## Open questions

1. **Manual host check for the beta:** who verifies bank account holder name (and SSM when given) before the first payout, and how are bad events removed? Proposal: you, in the Supabase dashboard, for the first 20 hosts.
2. ~~"Admin" in decision 8~~ Decided: host can edit title, description and spots after publishing; admin backend is still not in the MVP.
3. Decided: Notifications screen added to the prototype (bell and Profile row open it): list with unread dots, plus "Show me" switches (booking and payment updates and event changes are always on; chat messages and review requests can be switched off), and a line saying no push yet.
4. **Chat rules:** text only, no images; no limit on how many hosts a guest can message; can a guest message a host without having booked (the prototype copy says "Ask a host before you book")? Proposal: yes, with the contact filter and a block/report option later.
5. **Free events:** a free event can have capacity and a ticket after joining (as drawn). Who adds the "Source: Instagram" free listings (the host, or you)?
6. **Fee rates:** platform fee 10% is in the prototype; gateway fee depends on the future contract. With the mock gateway the numbers are illustrative.
7. **Payment and payouts when built:** which gateway supports FPX, cards, e-wallets and DuitNow QR; whether collecting for hosts carries regulatory duties in Malaysia (ask the provider and a lawyer); pragmatic start is that you pay hosts by weekly bank transfer.
8. **Signed-out tabs:** the prototype draws Saved, Bookings, Chat and Profile only for a signed-in user. Proposal: signed out, each shows "Sign in to see your saved events / bookings / chats / profile" with the two sign-in buttons. Hearts never work signed out, so nothing is stored on the phone.
9. Decided: delete is allowed until the event starts; it refunds confirmed bookings and releases held ones. After the start it can only be marked completed.
10. **Individual hosts without SSM:** verified by matching the bank account holder name to the host name (manual, see 1) until eKYC exists.
11. Decided: **online-only scanning in the MVP**. If the phone has no signal, the host uses the manual guest list (tick boxes), which also syncs when the connection returns. Offline scanning with a downloaded guest list is later.
12. Decided: a no-show gets no refund and cannot review.