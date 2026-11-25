# Glacio

A minimal money app for Canada: track spending, split costs, set bill reminders, and plan RRSP / TFSA / FHSA contributions.

This repo holds the app as a single-file web app (`index.html`) with no build step. Until the App Store version is approved, it runs on your iPhone as an installable web app.

## Use it on your iPhone now

1. Open **https://gavinsan.github.io/Glacio/** in Safari.
2. Tap **Share → Add to Home Screen**.
3. Open Glacio from the home screen icon. It runs full screen and works offline.

Your data is stored only on that phone, inside the home-screen app. Use **Settings (gear on Overview) → Export backup** now and then. The same backup file is how you move your data into the App Store version later.

Starting values in Tax are a typical Toronto renter (late 2026): salary $80,000, costs $3,500/month, save $8,000/year, RRSP room $14,400, TFSA $7,000, FHSA $8,000. Change any of them in Tax. The sources are in a comment above `TORONTO` in `index.html`.

To run it locally instead:

```bash
python -m http.server 8765
```

Then visit http://localhost:8765. It shows a phone frame on desktop.

## What the prototype covers

| Area | What it does |
|---|---|
| Overview | Income vs expense donut. Tap a slice to select it; press and hold to open spending by account (Visa, Amex, Debit, Cash), then tap an account for its category donut and records. |
| Investments | On Overview. Add TFSA / RRSP / FHSA / other accounts, log money put in or taken out, update what each is worth. Shows gain and this year's room left. |
| Add (+) | Income or expense, keypad, category, account (add one right there if you have none), date (yesterday, today, tomorrow, next 1st), repeat schedule. |
| Privacy | Eye button on every screen hides all amounts, including the spend & save chart. |
| Self-employed | Settings switch, then add each business (name, optional CRA business number). A Personal / business switch at the top of Overview focuses the page and new records on one of them, pick the CRA T2125 line (or T4A slip for income), note HST paid. Tax → Business shows All or one business (each is its own T2125) and makes two PDFs, one section per business, for your accountant: expenses with every receipt, and income. |
| Receipts | Attach a photo to any record. "Scan receipt" reads the total, date, store and HST on the phone itself (Tesseract, open source, served from `vendor/`; nothing is sent anywhere). Photos stay on the phone and copy to your private Supabase folder when signed in. |
| Settings | Your payment accounts: credit card (Visa, Mastercard, Amex, other), debit (chequing or savings), cash; export / restore a backup file, erase all data. Apple Wallet auto-logging waits for the App Store version. |
| Split | Shared groups in the cloud (signed in): invite people by email, add shared costs, "I paid" waits for the other person to confirm, reminders and payment news arrive in the in-app inbox (bell). People without Glacio can be added by name. Groups made before signing in stay on the phone and can be moved up with Share. |
| Tax · Plan | Province picker (city lookup), 2026 combined tax buckets, income and costs, RRSP / TFSA / FHSA room with "how to find it" help, then a suggested split that never exceeds what is left after costs. |
| Tax · Forecast | Salary slider, take-home, ordered "what to do" steps, 10-year projection by account, and a salary guide table. |
| Tax · Refund | Estimates your 2026 refund or balance owing (federal + Ontario: credits, Ontario surtax, Health Premium, LIFT, self-employed CPP, Canada Workers Benefit) and the benefits you may get: Canada Child Benefit, Ontario Child Benefit, GST/HST credit, Ontario Trillium, OAS/GIS, Canada Disability Benefit. Each benefit is marked Checked or Estimate. |
| Reminders | Bill due days and scheduled income / expenses. Scheduled items log themselves on their day. Tap any record to delete it. |

Design rules: about 70% black, 25% white and 5% light blue for controls and motion. Every row stays on one line, with no ellipsis. Categories use a colour-blind-checked palette.

## Notes for the real iOS app

- **Apple Wallet:** FinanceKit does not cover Canadian cards today. The workable route is a Shortcuts "Transaction" automation that calls a Glacio App Intent with the amount, merchant and card.
- **Tax data:** Federal and Ontario 2026 figures were checked against published tables. Other provinces are estimates and must be verified. Ship tax tables as remote data, updated yearly.
- **Split nudges** need user accounts and push notifications (for example CloudKit sharing or Firebase).
- **Legal:** All tax output is labelled as an educational estimate, not advice. Have a lawyer review the terms before App Store release.
- **Notifications:** the web app cannot send bill alerts on iPhone without a push server, so reminders are only highlighted inside the app. Real alerts come with the App Store version.
- **Cloud sync:** Settings → Cloud sync. Sign in with your email and a one-time code (a link would open Safari instead of the home-screen app). Data is one JSON row per user in Supabase (`supabase/schema.sql`), protected by row-level security. Changes upload about 1.5 s after you make them; when the app opens, the newer copy wins. Erasing a phone never touches the cloud copy.

## Tax and benefit figures (2026)

Amounts live in `TB_DEF`, `CR26` and `BEN` near the top of the script. "Checked" means several published 2026 sources agree; "Estimate" means we indexed it ourselves. Update these every July (benefit year) and January (tax year). Sources used:
- Canada Child Benefit 2026–27: wealthnorth.ca, canadianmoneyhelp.ca
- GST/HST credit (Groceries and Essentials Benefit) 2026–27: canadianmoneyhelp.ca, taxly.ca
- Canada Workers Benefit 2026: canadianmoneyhelp.ca, rcicnews.com
- OAS / GIS Oct–Dec 2026: savvynewcanadians.com, debtnorth.ca
- Federal credits 2026 (age, pension, disability, medical): taxtips.ca, Carleton tax appendix 2026, canadianmoneyhelp.ca
- Ontario Trillium and Ontario Child Benefit 2026–27: canada.ca (Province of Ontario page), lifemoney.ca
- Canada Disability Benefit 2026–27: immigrationnewscanada.ca
- **Supabase keep-alive:** the Free plan pauses a project after about a week without activity. `.github/workflows/supabase-keepalive.yml` calls the `glacio_ping` function (`supabase/keepalive.sql`) every 3 days. GitHub runs scheduled workflows only from the default branch, and turns them off after 60 days without repository activity (it emails you first).

## Sign-in and shared groups (phase 2)

- Glacio opens on a sign-in screen (email + 6-digit code). "Use on this phone only for now" skips it; nothing is shared until you sign in.
- Run `supabase/shared.sql` once in the Supabase SQL Editor. It adds profiles, groups, group_members, expenses, payments and notifications, all behind row-level security: you see only groups you belong to (or were invited to by email) and only your own notifications. Only the person who received money can confirm a payment.
- The policies were tested against a local Postgres set up like Supabase (46 checks: outsiders, invitees, members, payer vs receiver, notification spoofing, leaving a group).

## App Store version: to do

- **Apple Pay auto-logging.** When a Wallet card is used, log the purchase in Glacio automatically. If that card isn't one of your Glacio accounts yet, create the account from the card name. Route: a Shortcuts "Transaction" automation calling a Glacio App Intent (FinanceKit doesn't cover Canadian cards today).
- Native Sign in with Apple, push notifications for reminders and payment confirmations, Apple Vision on-device text recognition for receipts.
- Import a phone-only backup or sign in to bring data across.
