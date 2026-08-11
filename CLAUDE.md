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

Layout must survive narrow windows (browser side panels are common): the text column is `minmax(0, 768px)` in both the `body` and `.home-columns` grids, and the sidebar's no-wrap contact line takes a fixed margin below 1330px so it can't clip. Don't reintroduce fixed track widths.

## Glossary

Ed refers to features by these names — keep them stable, and add a line here when building something new.

Site-wide: the **sidebar** (`aside`, charcoal left column) holds the **side-logo** (the book emblem alone — NOT a roundel; the book is what sits at the roundel's centre, home link), the **nav links** (italic red), and the **side-contact** (address + email at its foot). The **site footer** is the centered small-caps line under the main column. On phones the sidebar becomes the **nav drawer**, opened by the **nav toggle** (diamond button) over the **nav overlay** (dim backdrop). The **text column** is the middle `minmax(0, 768px)` grid track.

Homepage: the **plaque** (`.home-plaque`, masthead band) contains the **plaque roundel** (LCPT emblem) and the **lede** (opening statement). The **home cover** is the front-door photo bleeding right. The **sidebar fade** is the scroll-linked opacity that tracks the plaque roundel's exit (in `application.js`).

Other: **event search** (live filter on /events), **email decode** (client-side de-obfuscation of addresses), **plates** and **ink shadows** (image treatments, see above).
