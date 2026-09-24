# Newspeak House website

Public site + member portal for Newspeak House (newspeak.house). Ruby 3.3 / Rails 7.2 monolith: Postgres, Sidekiq, Devise, ActiveAdmin, Stripe billing. Local dev runs in Docker (`docker compose up`).

## Tests

```
docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgresql://postgres:postgres@database/nwspk_test --entrypoint sh web -c "bundle exec rspec"
```

The `DATABASE_URL` override is load-bearing: the compose file pins it to the dev database, and Rails merges the env var over `database.yml` even in test mode — without the override, `maintain_test_schema!` wipes the dev database. `--entrypoint sh -c` is needed because the image ENTRYPOINT ignores args and boots the server. If the `gem_cache` volume shadows freshly built image gems after a Gemfile change, delete the volume.

## Deploying

Pushing to `master` deploys straight to production via GitHub Actions (pull → bundle → migrate → precompile → restart → warm), ~1–1.5 min. The `staging` branch deploys to the staging droplet the same way. Watch runs with `gh run watch <id> --interval 30` (the default 3s interval floods the log).

## Design language (2026 restyle)

The site speaks in print-shop terms: big images are "plates" that bleed to the viewport edge; smaller images take a solid ink-block offset shadow (never blur); colophon/contact lines are letter-spaced small caps; red means clickable; the charcoal sidebar carries the college book emblem. On the homepage the masthead plaque owns the identity and the sidebar fades in as the plaque roundel scrolls off.

Type: Galaxie Copernicus (licensed; serif) and Lato (OFL; the small sans used for event dates/venues, pills, buttons, tables) are both self-hosted from `app/assets/fonts` as woff2 only — no Google Fonts link (it sends every visitor's IP to Google), and never serve or commit desktop OTF/TTF files: the repo is public and `design/fonts/` is gitignored for that reason.

Layout must survive narrow windows (browser side panels are common): the text column is `minmax(0, 768px)` in both the `body` and `.home-columns` grids, and the sidebar's no-wrap contact line takes a fixed margin below 1330px so it can't clip. Don't reintroduce fixed track widths.

## Glossary

Ed refers to features by these names — keep them stable, and add a line here when building something new.

Site-wide: the **sidebar** (`aside`, charcoal left column) holds the **side-logo** (the book emblem alone — NOT a roundel; the book is what sits at the roundel's centre, home link), the **nav links** (italic red), and the **side-contact** (address + email at its foot). The **site footer** is the centered small-caps line under the main column. On phones the sidebar becomes the **nav drawer**, opened by the **nav toggle** (diamond button) over the **nav overlay** (dim backdrop). The **text column** is the middle `minmax(0, 768px)` grid track.

Homepage: the **plaque** (`.home-plaque`, masthead band) contains the **plaque roundel** (LCPT emblem) and the **lede** (opening statement). The **home cover** is the front-door photo bleeding right. The **sidebar fade** is the scroll-linked opacity that tracks the plaque roundel's exit (in `application.js`).

Other: the **ICS feed** (`/api/events.ics`, `ApiController#events`) is limited by the **ICS window** (`ICS_WINDOW`, past 13 months + all upcoming) because Proton Calendar refuses subscriptions over 1 MB and the full archive was 2.7 MB — don't widen it; the archive is /events. **event search** (live filter on /events), **email decode** (client-side de-obfuscation of addresses), **plates** and **ink shadows** (image treatments, see above).

Social previews: the **social preview tags** (`ApplicationHelper#social_preview_tags`, rendered from `layouts/_head`) give *every* page the house title, description, social card and `twitter:card` by default — a page overrides just what differs by assigning `@og_title` / `@og_description` / `@og_url`, and `:extra_tags` is left for anything beyond the standard set. Don't reintroduce per-page og blocks: six pages had shipped with no preview card at all because the tags were opt-in. The **event share link** (`/events?id=N#event-N`, built by `EventsHelper#event_share_path` / `#event_share_url` — always use the helper) is the URL format that yields a per-event preview card; bare `/#event-N` fragments never reach the server, so they can't. The **event preview tags** (the og overrides in `events/index.html.haml`; selected event resolved in `EventsController#index` over the whole visible scope, so links outlive the event) render the event name as title and "date • hosted by X at Newspeak House" as description. The **social card** (`lcpt-roundel-social-card.jpg`, 1200×1200) is the roundel in plaque colours — paper-grey `#e8e8e8` art on charcoal `#2e2e2e`, matching the homepage masthead — used as og:image site-wide (transparent PNGs render unpredictably in some apps; regenerate flattened if the roundel or plaque colours change). Its source MUST be `lcpt-logo-white.png` — the dark-background artwork variant with solid-filled book pages, the same file the plaque's CSS mask uses; `lcpt-logo.png` is the light-background variant whose pages let the ground show through and read black on charcoal. The **share-link intercept** (in `application.js`) lets event share links be real hrefs while a plain click on a page that already shows that event row scrolls in place instead of navigating (and pushes the share link into the address bar). It keys off the link's own `#event-` fragment, so it covers both the homepage TOC entries and the event rows; modified and middle clicks are left to the browser so open-in-new-tab still opens the shareable URL.

Feedback (/feedback): the **feedback form** is native (house-styled inputs; the old Google Form iframe is gone). The **feedback relay** (`GoogleFormRelay` + `HomeController#submit_feedback`) posts submissions server-side to the Google Form's formResponse endpoint and verifies Google's confirmation message, so responses still land in the same spreadsheet. `GoogleFormRelay` owns everything Google-shaped — the housekeeping fields, the confirmation wording, and the five-part date-time encoding (`.date_time_fields`); the controller owns only which form and which questions. The **feedback fallback email** (`AdminMailer#feedback_fallback_email`) fires when Google doesn't confirm — it carries the full submission so nothing is lost. If the Google Form is ever edited, the entry.* field mapping in `HomeController` must be updated (procedure in the code comments) and a test submission made. Two bot traps guard the form (spam began when it went native — bots can't see into Google's iframe but can see our markup): the **feedback honeypot** (an off-screen decoy "Subject" field only a bot fills) and the **feedback time trap** (a signed served-at stamp; a submission under 3 seconds old, or with a forged stamp, is a bot). A caught submission gets the ordinary thank-you, is neither relayed nor emailed, and leaves a `Feedback … sprung` warning in the log. The form takes reports against individuals, so the traps must never catch a person: a missing stamp passes, and content filtering (links, scripts) was rejected for that reason — don't add it.
