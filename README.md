# Glacio

A minimal money app for Canada: track spending, split costs, set bill reminders, and plan RRSP / TFSA / FHSA contributions.

This repo currently holds the **clickable UI prototype** (`index.html`), a single file with no build step. Open it in a browser, or serve the folder:

```bash
python -m http.server 8765
```

Then visit http://localhost:8765. It is sized for an iPhone and shows a phone frame on desktop.

## What the prototype covers

| Area | What it does |
|---|---|
| Overview | Income vs expense donut. Tap a slice to select it; press and hold to open spending by account (Visa, Amex, Debit, Cash), then tap an account for its category donut and records. |
| Add (+) | Income or expense, keypad, category, account, date, repeat schedule and reminder. |
| Apple Wallet | Demo of auto-logging Apple Pay taps (see note below). |
| Split | Group costs split evenly, who paid, who owes, nudge and mark-paid. Examples: a $100 party for 5, and rent + hydro + gas for 3 roommates. |
| Tax · Plan | Province picker (city lookup), 2026 combined tax buckets, income and costs, RRSP / TFSA / FHSA room with "how to find it" help, then a suggested split that never exceeds what is left after costs. |
| Tax · Forecast | Salary slider, take-home, ordered "what to do" steps, 10-year projection by account, and a salary guide table. |
| Reminders | Credit card, mortgage, loan and bill due dates with alert toggles, plus scheduled income and expenses. |

Design rules: about 70% black, 25% white and 5% light blue for controls and motion. Every row stays on one line, with no ellipsis. Categories use a colour-blind-checked palette.

## Notes for the real iOS app

- **Apple Wallet:** FinanceKit does not cover Canadian cards today. The workable route is a Shortcuts "Transaction" automation that calls a Glacio App Intent with the amount, merchant and card.
- **Tax data:** Federal and Ontario 2026 figures were checked against published tables. Other provinces are estimates and must be verified. Ship tax tables as remote data, updated yearly.
- **Split nudges** need user accounts and push notifications (for example CloudKit sharing or Firebase).
- **Legal:** All tax output is labelled as an educational estimate, not advice. Have a lawyer review the terms before App Store release.
