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
