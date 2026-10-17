# Build order

Build the 58 tickets in this order. A ticket can start when every ticket in its "Blocked by" column is merged. Tickets next to each other with no link between them can run in parallel.

Generated from the ticket dependencies (ties broken by milestone, then priority). Each GitHub issue repeats its step at the top.


## M0 · Foundations

| Step | Ticket | Issue | Pri | Pts | Blocked by |
|---|---|---|---|---|---|
| 1 | MS-100 · Record the V1.1 build decisions and close the design gaps | [#71](https://github.com/grigorhello/Dentory/issues/71) | P0 | 1 | — |
| 2 | MS-101 · Set up the iOS app project for iPhone and iPad | [#72](https://github.com/grigorhello/Dentory/issues/72) | P0 | 3 | [MS-100](https://github.com/grigorhello/Dentory/issues/71) |
| 3 | MS-102 · Port the Dentory design system to SwiftUI | [#73](https://github.com/grigorhello/Dentory/issues/73) | P0 | 5 | [MS-101](https://github.com/grigorhello/Dentory/issues/72) |
| 4 | MS-153 · Set up Supabase locally and in CI | [#124](https://github.com/grigorhello/Dentory/issues/124) | P0 | 2 | [MS-100](https://github.com/grigorhello/Dentory/issues/71) |
| 5 | MS-104 · Create the database schema | [#75](https://github.com/grigorhello/Dentory/issues/75) | P0 | 5 | [MS-100](https://github.com/grigorhello/Dentory/issues/71), [MS-153](https://github.com/grigorhello/Dentory/issues/124) |
| 6 | MS-105 · Isolate clinics and enforce Admin and Staff permissions in the database | [#76](https://github.com/grigorhello/Dentory/issues/76) | P0 | 3 | [MS-104](https://github.com/grigorhello/Dentory/issues/75) |
| 7 | MS-106 · Build the stock transaction engine | [#77](https://github.com/grigorhello/Dentory/issues/77) | P0 | 8 | [MS-104](https://github.com/grigorhello/Dentory/issues/75), [MS-105](https://github.com/grigorhello/Dentory/issues/76) |
| 8 | MS-107 · Compute product status, attention counts and values | [#78](https://github.com/grigorhello/Dentory/issues/78) | P0 | 3 | [MS-104](https://github.com/grigorhello/Dentory/issues/75), [MS-106](https://github.com/grigorhello/Dentory/issues/77) |
| 9 | MS-154 · Build the app core: dependencies, data layer and session | [#125](https://github.com/grigorhello/Dentory/issues/125) | P0 | 3 | [MS-101](https://github.com/grigorhello/Dentory/issues/72), [MS-153](https://github.com/grigorhello/Dentory/issues/124) |
| 10 | MS-103 · Build the app shell: tabs, pushed screens, sheets and toasts | [#74](https://github.com/grigorhello/Dentory/issues/74) | P0 | 5 | [MS-102](https://github.com/grigorhello/Dentory/issues/73), [MS-154](https://github.com/grigorhello/Dentory/issues/125) |
| 11 | MS-108 · Handle errors, offline writes and double taps the same way everywhere | [#79](https://github.com/grigorhello/Dentory/issues/79) | P1 | 3 | [MS-106](https://github.com/grigorhello/Dentory/issues/77), [MS-154](https://github.com/grigorhello/Dentory/issues/125), [MS-103](https://github.com/grigorhello/Dentory/issues/74) |
| 12 | MS-109 · Seed a demo clinic that matches the design | [#80](https://github.com/grigorhello/Dentory/issues/80) | P1 | 2 | [MS-106](https://github.com/grigorhello/Dentory/issues/77) |

## M1 · Internal Alpha

| Step | Ticket | Issue | Pri | Pts | Blocked by |
|---|---|---|---|---|---|
| 13 | MS-110 · Sign in | [#81](https://github.com/grigorhello/Dentory/issues/81) | P0 | 2 | [MS-105](https://github.com/grigorhello/Dentory/issues/76), [MS-103](https://github.com/grigorhello/Dentory/issues/74) |
| 14 | MS-114 · Home: what needs me today | [#85](https://github.com/grigorhello/Dentory/issues/85) | P0 | 3 | [MS-107](https://github.com/grigorhello/Dentory/issues/78), [MS-103](https://github.com/grigorhello/Dentory/issues/74) |

## M0 · Foundations

| Step | Ticket | Issue | Pri | Pts | Blocked by |
|---|---|---|---|---|---|
| 15 | MS-155 · Rename the app, the code and the repository to Dentory | [#143](https://github.com/grigorhello/Dentory/issues/143) | P0 | 3 | [MS-110](https://github.com/grigorhello/Dentory/issues/81), [MS-114](https://github.com/grigorhello/Dentory/issues/85) |
| 16 | MS-156 · Rename MediSave to Dentory in the docs, the design files, the ticket sources and the issues | [#144](https://github.com/grigorhello/Dentory/issues/144) | P0 | 2 | [MS-155](https://github.com/grigorhello/Dentory/issues/143) |
| 17 | MS-157 · Rename the services and accounts outside the repository to Dentory | [#145](https://github.com/grigorhello/Dentory/issues/145) | P1 | 1 | [MS-155](https://github.com/grigorhello/Dentory/issues/143) |

## M1 · Internal Alpha

| Step | Ticket | Issue | Pri | Pts | Blocked by |
|---|---|---|---|---|---|
| 18 | MS-111 · Admin sign-up: account, clinic and team invites | [#82](https://github.com/grigorhello/Dentory/issues/82) | P0 | 5 | [MS-104](https://github.com/grigorhello/Dentory/issues/75), [MS-110](https://github.com/grigorhello/Dentory/issues/81), [MS-155](https://github.com/grigorhello/Dentory/issues/143) |
| 19 | MS-112 · Invite teammates and accept an invitation | [#83](https://github.com/grigorhello/Dentory/issues/83) | P0 | 3 | [MS-111](https://github.com/grigorhello/Dentory/issues/82) |
| 20 | MS-115 · Inventory list: browse, search and filter | [#86](https://github.com/grigorhello/Dentory/issues/86) | P0 | 3 | [MS-107](https://github.com/grigorhello/Dentory/issues/78), [MS-103](https://github.com/grigorhello/Dentory/issues/74) |
| 21 | MS-116 · Product detail | [#87](https://github.com/grigorhello/Dentory/issues/87) | P0 | 5 | [MS-115](https://github.com/grigorhello/Dentory/issues/86) |
| 22 | MS-117 · Create, edit and delete products | [#88](https://github.com/grigorhello/Dentory/issues/88) | P0 | 3 | [MS-116](https://github.com/grigorhello/Dentory/issues/87) |
| 23 | MS-118 · Adjust a quantity with a reason | [#89](https://github.com/grigorhello/Dentory/issues/89) | P0 | 2 | [MS-106](https://github.com/grigorhello/Dentory/issues/77), [MS-116](https://github.com/grigorhello/Dentory/issues/87) |
| 24 | MS-119 · Track expiry per batch: Add expiry and Edit batch | [#90](https://github.com/grigorhello/Dentory/issues/90) | P0 | 3 | [MS-106](https://github.com/grigorhello/Dentory/issues/77), [MS-116](https://github.com/grigorhello/Dentory/issues/87) |
| 25 | MS-120 · Multi-use products: open a new bottle and mark it finished | [#91](https://github.com/grigorhello/Dentory/issues/91) | P0 | 2 | [MS-106](https://github.com/grigorhello/Dentory/issues/77), [MS-116](https://github.com/grigorhello/Dentory/issues/87) |
| 26 | MS-121 · Count stock with review before applying | [#92](https://github.com/grigorhello/Dentory/issues/92) | P0 | 5 | [MS-106](https://github.com/grigorhello/Dentory/issues/77), [MS-115](https://github.com/grigorhello/Dentory/issues/86) |
| 27 | MS-122 · Procedures list and history | [#93](https://github.com/grigorhello/Dentory/issues/93) | P0 | 2 | [MS-107](https://github.com/grigorhello/Dentory/issues/78), [MS-103](https://github.com/grigorhello/Dentory/issues/74) |
| 28 | MS-123 · Adjust, then start a procedure | [#94](https://github.com/grigorhello/Dentory/issues/94) | P0 | 8 | [MS-106](https://github.com/grigorhello/Dentory/issues/77), [MS-120](https://github.com/grigorhello/Dentory/issues/91), [MS-122](https://github.com/grigorhello/Dentory/issues/93) |
| 29 | MS-124 · Procedure from history: edit usage or cancel | [#95](https://github.com/grigorhello/Dentory/issues/95) | P0 | 5 | [MS-123](https://github.com/grigorhello/Dentory/issues/94) |
| 30 | MS-113 · Reset a forgotten password | [#84](https://github.com/grigorhello/Dentory/issues/84) | P1 | 2 | [MS-110](https://github.com/grigorhello/Dentory/issues/81) |
| 31 | MS-125 · Edit procedure templates | [#96](https://github.com/grigorhello/Dentory/issues/96) | P1 | 3 | [MS-122](https://github.com/grigorhello/Dentory/issues/93) |

## M2 · Clinic Pilot

| Step | Ticket | Issue | Pri | Pts | Blocked by |
|---|---|---|---|---|---|
| 32 | MS-126 · Receive delivery: choose how | [#97](https://github.com/grigorhello/Dentory/issues/97) | P0 | 2 | [MS-103](https://github.com/grigorhello/Dentory/issues/74) |
| 33 | MS-127 · Receive manually | [#98](https://github.com/grigorhello/Dentory/issues/98) | P0 | 3 | [MS-106](https://github.com/grigorhello/Dentory/issues/77), [MS-117](https://github.com/grigorhello/Dentory/issues/88), [MS-126](https://github.com/grigorhello/Dentory/issues/97) |
| 34 | MS-128 · To buy list | [#99](https://github.com/grigorhello/Dentory/issues/99) | P0 | 5 | [MS-106](https://github.com/grigorhello/Dentory/issues/77), [MS-103](https://github.com/grigorhello/Dentory/issues/74) |
| 35 | MS-129 · Read invoices with AI | [#100](https://github.com/grigorhello/Dentory/issues/100) | P0 | 8 | [MS-104](https://github.com/grigorhello/Dentory/issues/75), [MS-126](https://github.com/grigorhello/Dentory/issues/97) |
| 36 | MS-130 · Review invoice lines | [#101](https://github.com/grigorhello/Dentory/issues/101) | P0 | 5 | [MS-117](https://github.com/grigorhello/Dentory/issues/88), [MS-129](https://github.com/grigorhello/Dentory/issues/100) |
| 37 | MS-131 · Confirm and receive an invoice | [#102](https://github.com/grigorhello/Dentory/issues/102) | P0 | 3 | [MS-106](https://github.com/grigorhello/Dentory/issues/77), [MS-128](https://github.com/grigorhello/Dentory/issues/99), [MS-130](https://github.com/grigorhello/Dentory/issues/101) |
| 38 | MS-132 · Expiring soon and Mark disposed | [#103](https://github.com/grigorhello/Dentory/issues/103) | P0 | 3 | [MS-106](https://github.com/grigorhello/Dentory/issues/77), [MS-107](https://github.com/grigorhello/Dentory/issues/78) |
| 39 | MS-133 · Activity: alerts and the bell | [#104](https://github.com/grigorhello/Dentory/issues/104) | P0 | 3 | [MS-107](https://github.com/grigorhello/Dentory/issues/78), [MS-114](https://github.com/grigorhello/Dentory/issues/85) |
| 40 | MS-134 · Activity: history | [#105](https://github.com/grigorhello/Dentory/issues/105) | P1 | 3 | [MS-133](https://github.com/grigorhello/Dentory/issues/104) |
| 41 | MS-136 · Pilot readiness pass | [#107](https://github.com/grigorhello/Dentory/issues/107) | P0 | 3 | [MS-110](https://github.com/grigorhello/Dentory/issues/81), [MS-114](https://github.com/grigorhello/Dentory/issues/85), [MS-111](https://github.com/grigorhello/Dentory/issues/82), [MS-112](https://github.com/grigorhello/Dentory/issues/83), [MS-115](https://github.com/grigorhello/Dentory/issues/86), [MS-116](https://github.com/grigorhello/Dentory/issues/87), [MS-117](https://github.com/grigorhello/Dentory/issues/88), [MS-118](https://github.com/grigorhello/Dentory/issues/89), [MS-119](https://github.com/grigorhello/Dentory/issues/90), [MS-120](https://github.com/grigorhello/Dentory/issues/91), [MS-121](https://github.com/grigorhello/Dentory/issues/92), [MS-122](https://github.com/grigorhello/Dentory/issues/93), [MS-123](https://github.com/grigorhello/Dentory/issues/94), [MS-124](https://github.com/grigorhello/Dentory/issues/95), [MS-125](https://github.com/grigorhello/Dentory/issues/96), [MS-126](https://github.com/grigorhello/Dentory/issues/97), [MS-127](https://github.com/grigorhello/Dentory/issues/98), [MS-128](https://github.com/grigorhello/Dentory/issues/99), [MS-129](https://github.com/grigorhello/Dentory/issues/100), [MS-130](https://github.com/grigorhello/Dentory/issues/101), [MS-131](https://github.com/grigorhello/Dentory/issues/102), [MS-132](https://github.com/grigorhello/Dentory/issues/103), [MS-133](https://github.com/grigorhello/Dentory/issues/104), [MS-134](https://github.com/grigorhello/Dentory/issues/105) |
| 42 | MS-135 · Inventory value | [#106](https://github.com/grigorhello/Dentory/issues/106) | P2 | 2 | [MS-107](https://github.com/grigorhello/Dentory/issues/78) |

## M3 · Commercial Beta

| Step | Ticket | Issue | Pri | Pts | Blocked by |
|---|---|---|---|---|---|
| 43 | MS-137 · Account screen and sign out | [#108](https://github.com/grigorhello/Dentory/issues/108) | P0 | 2 | [MS-114](https://github.com/grigorhello/Dentory/issues/85) |
| 44 | MS-138 · Team: invite, resend, change role, remove | [#109](https://github.com/grigorhello/Dentory/issues/109) | P0 | 3 | [MS-112](https://github.com/grigorhello/Dentory/issues/83), [MS-137](https://github.com/grigorhello/Dentory/issues/108) |
| 45 | MS-140 · Billing: trial, price and payment method with Stripe | [#111](https://github.com/grigorhello/Dentory/issues/111) | P0 | 5 | [MS-104](https://github.com/grigorhello/Dentory/issues/75), [MS-137](https://github.com/grigorhello/Dentory/issues/108) |
| 46 | MS-142 · Read-only mode when the trial ends without payment | [#113](https://github.com/grigorhello/Dentory/issues/113) | P0 | 3 | [MS-105](https://github.com/grigorhello/Dentory/issues/76), [MS-140](https://github.com/grigorhello/Dentory/issues/111) |
| 47 | MS-139 · Clinic settings | [#110](https://github.com/grigorhello/Dentory/issues/110) | P1 | 2 | [MS-137](https://github.com/grigorhello/Dentory/issues/108) |
| 48 | MS-144 · Push notifications | [#115](https://github.com/grigorhello/Dentory/issues/115) | P1 | 3 | [MS-133](https://github.com/grigorhello/Dentory/issues/104) |
| 49 | MS-141 · Billing invoices and billing emails | [#112](https://github.com/grigorhello/Dentory/issues/112) | P2 | 2 | [MS-140](https://github.com/grigorhello/Dentory/issues/111) |
| 50 | MS-143 · Export CSV | [#114](https://github.com/grigorhello/Dentory/issues/114) | P2 | 2 | [MS-137](https://github.com/grigorhello/Dentory/issues/108) |
| 51 | MS-145 · Weekly email digest | [#116](https://github.com/grigorhello/Dentory/issues/116) | P2 | 2 | [MS-139](https://github.com/grigorhello/Dentory/issues/110) |
| 52 | MS-146 · Let admins delete invoice files | [#117](https://github.com/grigorhello/Dentory/issues/117) | P2 | 1 | [MS-131](https://github.com/grigorhello/Dentory/issues/102) |
| 53 | MS-147 · Track product analytics with the element ids | [#118](https://github.com/grigorhello/Dentory/issues/118) | P2 | 2 | [MS-103](https://github.com/grigorhello/Dentory/issues/74) |

## M4 · V1 Launch

| Step | Ticket | Issue | Pri | Pts | Blocked by |
|---|---|---|---|---|---|
| 54 | MS-151 · Security review before launch | [#122](https://github.com/grigorhello/Dentory/issues/122) | P0 | 2 | [MS-136](https://github.com/grigorhello/Dentory/issues/107) |
| 55 | MS-148 · iPad layout pass | [#119](https://github.com/grigorhello/Dentory/issues/119) | P1 | 2 | [MS-136](https://github.com/grigorhello/Dentory/issues/107) |
| 56 | MS-149 · Accessibility and Dynamic Type pass | [#120](https://github.com/grigorhello/Dentory/issues/120) | P1 | 3 | [MS-136](https://github.com/grigorhello/Dentory/issues/107) |
| 57 | MS-150 · Performance, backups and reliability | [#121](https://github.com/grigorhello/Dentory/issues/121) | P1 | 3 | [MS-136](https://github.com/grigorhello/Dentory/issues/107) |
| 58 | MS-152 · Ship to TestFlight and the App Store | [#123](https://github.com/grigorhello/Dentory/issues/123) | P0 | 3 | [MS-151](https://github.com/grigorhello/Dentory/issues/122), [MS-148](https://github.com/grigorhello/Dentory/issues/119), [MS-149](https://github.com/grigorhello/Dentory/issues/120), [MS-150](https://github.com/grigorhello/Dentory/issues/121) |
