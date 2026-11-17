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
| Settings | Your payment accounts (credit, debit, cash), export / restore a backup file, erase all data. Apple Wallet auto-logging waits for the App Store version. |
| Split | Create a group, add shared costs, see who owes whom, send a reminder through the iPhone share sheet, mark paid. |
| Tax · Plan | Province picker (city lookup), 2026 combined tax buckets, income and costs, RRSP / TFSA / FHSA room with "how to find it" help, then a suggested split that never exceeds what is left after costs. |
| Tax · Forecast | Salary slider, take-home, ordered "what to do" steps, 10-year projection by account, and a salary guide table. |
| Reminders | Bill due days and scheduled income / expenses. Scheduled items log themselves on their day. Tap any record to delete it. |

Design rules: about 70% black, 25% white and 5% light blue for controls and motion. Every row stays on one line, with no ellipsis. Categories use a colour-blind-checked palette.

## Notes for the real iOS app

- **Apple Wallet:** FinanceKit does not cover Canadian cards today. The workable route is a Shortcuts "Transaction" automation that calls a Glacio App Intent with the amount, merchant and card.
- **Tax data:** Federal and Ontario 2026 figures were checked against published tables. Other provinces are estimates and must be verified. Ship tax tables as remote data, updated yearly.
- **Split nudges** need user accounts and push notifications (for example CloudKit sharing or Firebase).
- **Legal:** All tax output is labelled as an educational estimate, not advice. Have a lawyer review the terms before App Store release.
- **Notifications:** the web app cannot send bill alerts on iPhone without a push server, so reminders are only highlighted inside the app. Real alerts come with the App Store version.
- **Cloud database (in progress):** `supabase/schema.sql` creates one row per user with row-level security, so each person can only read their own data. Sign-in and sync get switched on once the Supabase project exists.
