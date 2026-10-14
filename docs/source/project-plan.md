# Project Plan: KL Local Session
> App: KL Local Session
> Scope: KL & Selangor (Bangsar / PJ / Sri Hartamas / Bukit Bintang)
> Product: Mobile App for offline workshop & small social activity discovery, enquiry, booking & rating
> Target: Young people 18–35 years old
> Version: V1.0
> Date: Oct 2026

## 1. Project Overview
### Project Goal
Build a mobile application that connects local Hosts (workshop creators, café owners, community organisers) with young participants in KL.
Users can browse offline activities, filter by area/time/category, enquire with host, book session and leave rating/review after event.
Host can publish workshop, manage booking list and build reputation via reviews.

MVP strategy: **No in-app payment gateway**. Booking record only. Payment via bank transfer directly from attendee to host, to reduce development cost and regulatory risk for market validation.

### Assumption
1. There are enough independent workshop hosts around KL & PJ who want a simple booking tool.
2. Young users in KL have pain points finding offline activities scattered across IG / FB / WhatsApp groups.
3. MVP without built-in payment is acceptable for early adopters to validate the product-market fit.

### Out of Scope (MVP)
- Large events, concert, exhibition, tourism package
- Online virtual workshop
- Platform payment collection, refund handling by platform
- Advanced recommendation algorithm
- Web dashboard for host (only mobile host panel in MVP)

## 2. Stakeholders & Roles
| Role | Responsibility |
|---|---|
| Product Owner | Define requirement, prioritise backlog, validate market |
| QA (You) | Test case, E2E test, regression, UAT support |
| Frontend Dev | Mobile App UI (iOS + Android, can use Flutter / React Native) |
| Backend Dev | API, database, authentication, notification, booking logic |
| UX/UI Designer | Figma prototype, wireframe |
| Operation | Host recruitment, user interview, community management |

## 3. User Personas
### Persona 1: Attendee (End User)
- Age: 24–34, KL office worker / university student
- Needs: Find weekend / evening offline workshops quickly, check host credibility, book spot and get reminder.
- Pain: Activities spread on IG, hard to filter, no review system, manual DM communication.

### Persona 2: Host (Activity Creator)
- Age: 26–35, independent artist / café owner / hobby community organiser
- Needs: Post workshop, manage participant list, receive enquiry, collect reviews.
- Pain: Manual WhatsApp / IG DM registration, time-consuming admin, no way to accumulate review portfolio.

### Persona3: Admin
- Manage host application, review event content, handle report & basic platform analytics.

## 4. User Stories (As a <role>, I want <feature>, so that <reason>)
### Attendee
1. As an attendee, I want to browse nearby offline events in KL, so I can find interesting workshop for weekend / evening.
2. As an attendee, I want to filter events by area, date, category, price, so I can quickly find activities that fit my schedule.
3. As an attendee, I want to view event detail page (time, location, capacity, host info, price, cancellation policy), so I know all info before booking.
4. As an attendee, I want to send enquiry message to host inside app, so I can ask questions without switching to IG DM.
5. As an attendee, I want to book session, so I can secure my spot and get booking confirmation record.
6. As an attendee, I want to save favourite events, so I can view them later.
7. As an attendee, I want to receive push reminder before event starts, so I won’t miss the session.
8. As an attendee, I want to leave rating & review after attend event, so I can share my experience for other users.
9. As an attendee, I want to view host profile & past reviews, so I can check host credibility before sign up.

### Host
1. As a host, I want to create & post new offline workshop event, so I can publish my activity on platform.
2. As a host, I want to save as draft / edit / unpublish my event, so I can adjust details before event start.
3. As a host, I want to set max capacity, price, cancellation rule, so I can control booking limit & policy.
4. As a host, I want to receive enquiry messages from attendees, so I can answer their questions.
5. As a host, I want to view booking list & attendee information, so I can manage participants.
6. As a host, I want to see ratings & reviews on my profile, so I can build my reputation.
7. As a host, I want to mark attendee check-in status on event day, so I can track who came.

### Admin
1. As admin, I want to review host & event, so I can remove fake / inappropriate content.
2. As admin, I want to view basic platform metrics (event count, booking count, active user), so I can monitor platform growth.

## 5. Feature Breakdown (MVP V1)
### Attendee Module
- Register / Login (Google / Email)
- Home page: event list, card view
- Filter: Area, date range, category, price range
- Event detail page: poster, description, time, location map, remaining slot, price, cancellation policy, host profile link
- Favourite / Save event
- Booking submit, booking history
- In-app text chat (enquiry only)
- Push notification: booking confirm, event reminder
- Rating + review submission (only after event end date)
- Host profile page: past events, aggregate rating & reviews

### Host Module
- Host registration & profile setup
- Event creation form: upload poster, fill title, description, location, date/time, quota, price, cancellation rule
- Draft / Publish / Unpublish event
- Booking list view: attendee name, contact, booking time
- Check-in toggle for each attendee
- Receive and reply enquiry messages
- Host profile page to display past events & reviews

### Admin Backend
- Host approval
- Event moderation
- Simple dashboard: active host, event count, booking count
- Content remove function

## 6. Project Timeline & Milestones
> Total MVP timeline: ~10–12 weeks

| Phase | Duration | Deliverable |
|---|---|---|
| Phase 0: Discovery & Pre-launch | Week 1–3 | User & Host interview, Figma wireframe + prototype, recruit 20 seed hosts, define backlog |
| Phase1: Design & Requirement freeze | Week3–4 | Final UI design, user story acceptance criteria, test plan |
| Phase2: Development | Week4–9 | Backend API + Mobile App MVP build, internal integration test |
| Phase3: QA & UAT | Week9–10 | Functional testing, E2E test, bug fix, UAT with seed users & hosts |
| Phase4: Beta Launch (Closed Beta) | Week10–11 | Invite-only beta with seed host & users, collect feedback, minor hotfix |
| Phase5: Public MVP Release | Week12 | Public launch for KL, start operation & track MVP KPIs |

### Post-MVP Roadmap (V2 & V3)
#### V2 (After MVP validation)
- Integrate local payment gateway (FPX / Touch n Go / Boost)
- QR code check-in
- Calendar view for events
- IG/TikTok share button
- No-show credit scoring system
- Platform commission model activate

#### V3 (Scale phase)
- Recommendation algorithm for homepage
- Event photo / short video upload
- Host analytics dashboard
- Expand coverage to Penang / Johor Bahru

## 7. Business Model
1. **MVP (0–6 months): Free**
Host can publish unlimited events with zero commission. Goal: build supply and validate PMF.
2. **V2 (After payment integration): Commission 10–15% per completed booking**
Platform deduct commission from each successful transaction.
3. **V3 (Monetisation add-on)**
Paid event pin / promotion, advanced host analytics dashboard (subscription).

## 8. Risk & Mitigation
| Risk | Impact | Mitigation |
|---|---|---|
| Chicken & egg problem: insufficient host supply, user drop off | High | Manual recruit seed hosts, help them create event page one by one, source host from IG / FB KL workshop community |
| High no-show rate hurts host retention | High | Clearly display cancellation policy on event page; V2 implement booking deposit + user credit score |
| Host divert customer to WhatsApp / IG outside platform | Medium | Prohibit external contact info inside event page; continuously deliver exclusive value: review portfolio, booking automation |
| Users reluctant to download new app, prefer IG | Medium | Host share event to IG story with deep link redirecting to app; build seed user community |
| Compliance & data privacy issue | Medium | MVP avoid payment collection; define privacy policy, terms of service for KL/MY market |

## 9. MVP Success KPIs
### Host metrics
- Total active host
- Weekly newly published events
- Host retention rate (host who publish >=2 events)

### Attendee metrics
- Download / Register
- Event browse, favourite rate
- Enquiry conversion (browse → send message)
- Booking conversion (enquiry → submit booking)
- Show-up rate (booking → attend event)
- Number of reviews generated

## 10. QA & Testing Strategy
> For your QA workflow
1. Functional test: verify each user story acceptance criteria
2. API test: backend endpoint validation
3. E2E test: simulate full user journey (register → browse → enquire → book → review)
4. UAT: seed host & seed user real scenario test
5. Regression test before each release
6. Compatibility test for iOS & Android different versions

## 11. Definition of Done
- All acceptance criteria of user story passed QA
- Critical & high priority bugs fixed
- UI matches Figma design
- API documented
- Basic error handling implemented
- User can complete end-to-end workflow

## 12. Next Action Items
1. Prepare user & host interview questionnaire for market validation
2. Start Figma wireframe
3. Start host outreach & recruitment from IG KL workshop accounts
4. Write test cases based on user stories for QA preparation
