# Product analytics (MS-147)

What the app tells PostHog about how clinics use it, and how to read the pilot's figures. The code is `Dentory/Core/Analytics`; the decisions are in `decisions-log.md` (MS-147).

## What is sent, and what never is

- **Events named by the PRD Appendix B element id** the person used (MS-100 D3), sent when the action went through (or was queued offline), not on every tap.
- **Properties are numbers, yes or no, and words from closed lists** (`AnalyticsEvent`, `AnalyticsWord`): counts, seconds, a role, an adjustment reason. `AnalyticsEventTests.noPayloadCarriesFreeText` fails the build if an event could carry anything else.
- **Who:** the member's user id (PostHog's distinct id), their role, and their clinic's id (registered with every event as `clinic_id`, and as the `clinic` group). Never a name, an email, a product name, a note, a lot number or invoice contents.
- **PostHog's own:** the app lifecycle events (Application Installed, Updated, Opened and Backgrounded) and, on every event, the device's model and type, iOS version, app version and build, language, time zone, screen size and network (Wi-Fi or cellular). PostHog's servers also see each request's IP address: with **Discard client IP data** on (project settings, IP data capture) it is not stored on the events; `$geoip_disable`, which the app sets, only stops the location lookup. Off: autocapture with its rage clicks and control text, screen views, session replay, surveys, push token and push-open capture, feature flag preloading, and location from the IP address (`PostHogAnalytics.start()`). The SDK still asks PostHog's `/flags` endpoint on a member's first identify and on each reset, with the same ids as the events; the app reads no flags.
- **One identity per member:** a member signed in over another on the same device (an invitation or password reset link opened on a shared iPad) starts a new PostHog identity, as does a relaunch into another member's session, so nobody's events count as someone else's.
- **Builds without a project token send nothing.** Release builds read `POSTHOG_PROJECT_TOKEN` from `Config/Secrets.xcconfig`; Debug builds only from `Config/Secrets.debug.xcconfig` (use a separate PostHog project there, so testing never counts). The host is the EU cloud (`https://eu.i.posthog.com`) unless `POSTHOG_HOST` says otherwise.

## Events

| Event (Appendix B id) | When | Properties |
|---|---|---|
| `signin.submit` | Sign in succeeded | |
| `onboard.continue` | Sign-up's clinic step created the clinic (step 2) | |
| `onboard.sendInvites` | Sign-up's last step sent invitations | `item_count` invitations |
| `onboard.skip` | Sign-up's last step was skipped | `item_count` 0 |
| `invite.submit` | An invitation was accepted and the member signed in | |
| `procDetail.start` | A procedure was started | `item_count` deducted, `bottles_opened`, `shortage_count` lines short of stock, `duration_s` from the screen's load to Start |
| `procDetail.save` | A past procedure's usage was edited | `item_count` supplies changed |
| `procDetail.cancel` | A procedure was cancelled | |
| `procEdit.save` | A procedure's defaults were saved | `item_count` supplies, `is_new` |
| `procEdit.delete` | A procedure template was deleted | |
| `product.adjust` | Stock was adjusted from Product detail | `reason` (physical_count, expired, damaged, waste, missing, returned, data_correction, other), `direction` (increase, decrease) |
| `product.addToBuy` | A product was added to To buy (Report low stock for Staff) | |
| `product.openNewBottle` | A bottle, syringe or kit was opened | |
| `product.bottle.finished` | An open one was finished | |
| `order.add` | A product was added from To buy's Add item | |
| `order.markOrdered` | Lines were marked as ordered | `item_count` lines |
| `expiring.card.dispose` | A batch was disposed | |
| `team.invite` | A teammate was invited | `role` (admin, staff) |
| `more.export` | A CSV export was started | |
| `settings.save` | Clinic settings were saved | `digest` (the weekly email stays on), `expiry_warning_days` (the first warning: 30, 60 or 90) |

Coming with their tickets, which add the case to `AnalyticsEventName` and call `analytics.track`: `inv.count.review` when a count is applied (MS-121: `item_count` corrections, `duration_s`), the invoice flow (MS-129 to MS-131: `invoice.confirm` with `item_count` lines, `matched_count` lines auto-matched, `created_count`, and `duration_s` from upload to confirm), `manual.receive`, and product creation (MS-117). The tickets carry a comment saying so.

## The pilot dashboard

In PostHog (the EU project), Dashboards, New dashboard "Pilot", then one SQL insight per figure (Product analytics, New insight, SQL):

1. **Weekly active clinics**
   ```sql
   select toStartOfWeek(timestamp) as week, count(distinct properties.clinic_id) as clinics
   from events
   where properties.clinic_id is not null and timestamp > now() - interval 12 week
   group by week order by week
   ```
2. **Procedures started per clinic per week**
   ```sql
   select toStartOfWeek(timestamp) as week, properties.clinic_id as clinic, count() as procedures
   from events
   where event = 'procDetail.start' and timestamp > now() - interval 12 week
   group by week, clinic order by week, clinic
   ```
3. **Invoices confirmed** (once MS-131 sends `invoice.confirm`): the same query with `event = 'invoice.confirm'`.
4. **Share of invoice lines auto-matched**
   ```sql
   select toStartOfWeek(timestamp) as week,
          sum(toInt(properties.matched_count)) / sum(toInt(properties.item_count)) as matched_share
   from events where event = 'invoice.confirm' group by week order by week
   ```
5. **Counts applied** (once MS-121 sends `inv.count.review`): the second query with that event.
6. **Time from invoice upload to confirm**
   ```sql
   select toStartOfWeek(timestamp) as week, quantile(0.5)(toInt(properties.duration_s)) as median_seconds
   from events where event = 'invoice.confirm' group by week order by week
   ```

Filter out Dentory's own test clinic with `and properties.clinic_id != '<its id>'` once the pilot starts.
