# Outstanding issues

Work deliberately left undone. Each entry says why it was deferred and the
checkable condition under which to act. Delete an entry once it is done.

## Lock down the feedback Google Form against direct submissions

- **Item:** The Google Form behind /feedback still accepts submissions posted
  straight to Google, bypassing our site and its bot traps. Its ID is in
  `HomeController::FEEDBACK_FORM_ID` and in the git history (the old iframe
  src). The fix is a fresh copy of the form whose ID lives in server
  credentials rather than source, optionally plus a required "relay key"
  question only our server fills in (first test whether Google enforces that
  answer check on direct formResponse posts — unverified).
- **Why deferred (2026-09-21):** The spam began the day the form went native,
  so our own form is the likelier route; the feedback honeypot and feedback
  time trap address that. No evidence yet that anyone posts to Google directly.
- **Condition to act:** Spam rows keep appearing in the responses spreadsheet
  after the traps are deployed, *and* the production log shows no
  `POST "/feedback"` request at the matching times (a `Feedback … sprung`
  line means the traps caught it; a relayed POST means a bot beat the traps —
  in that case the answer is the rate limit or Turnstile, not this).
- **Where:** `app/controllers/home_controller.rb`, `app/services/google_form_relay.rb`.

## Retail font files remain in git history

- **Item:** The full Galaxie Copernicus desktop set (24 OTF/TTF files) was
  committed to `design/fonts/` in d2b47c9 and removed from the tree on
  2026-09-24, but this repo is public and the files are still downloadable
  from history. Removing them needs a history rewrite (e.g. `git filter-repo`)
  and a force-push to master, which breaks existing clones and triggers a
  deploy.
- **Why deferred (2026-09-24):** Ed chose removal from the tree only; a
  history rewrite is a separate, disruptive decision.
- **Condition to act:** Ed decides to rewrite history (or the foundry asks).
- **Where:** `design/fonts/` (now gitignored), commit d2b47c9.

## Confirm the Galaxie Copernicus web licence

- **Item:** The site serves Galaxie Copernicus to every visitor (six weights
  as woff2 since 2026-09-24). Nobody has checked that the house's licence
  covers web use, only that the files are no longer desktop OTFs.
- **Why deferred (2026-09-24):** The licence records are with whoever bought
  the fonts; not in the repo.
- **Condition to act:** Ed has found the licence terms. If web use isn't
  covered, buy a web licence or change typeface.
- **Where:** `app/assets/fonts/`, `app/assets/stylesheets/fonts.css`.

## Cohort photos on /fellowship

- **Item:** Show each cohort's group photo under its heading on /fellowship.
  Available: 2021 (`fellows-pic.jpg`, the sofa photo, identified by Ed via
  Jacob Coxon), 2024 (`2024-cohort.png`, 5.6 MB, needs a web-sized JPEG),
  2025 (`2025-cohort.jpg`, also the /study-with-us plate). No photos in the
  repo for 2020, 2022, 2023 or the Seasons.
- **Why deferred (2026-09-24):** Raised during the dead-code cleanup; kept
  separate so each change does one thing.
- **Condition to act:** Ed asks to start it (and supplies any missing years).
- **Where:** `app/views/home/fellowship.html.haml`, `config/fellows.yml`.

## Previous-faculty page

- **Item:** A page listing past faculty. Portraits kept for it:
  `Stephanie.png`, `mustafa.png`, `sam.jpg`, `dan-kwiat.jpg`,
  `john-sandall.png` (all in `app/assets/images/`, currently unused).
- **Why deferred (2026-09-24):** Ed wants it alongside a faculty page update.
- **Condition to act:** Ed starts the faculty page update.
- **Where:** `app/views/home/_faculty.html.haml`, `app/assets/images/`.
