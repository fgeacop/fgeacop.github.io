# FGEA Community of Practice website

The production website for the Future Generation Enterprise Architecture
Community of Practice. It is a static Jekyll 4 site published at
<https://fgeacop.github.io/>.

The site has no analytics, cookies, forms, external CMS, search service, or
runtime API. Content is reviewed in this repository and built into static
files.

## Architecture

- Jekyll layouts and includes render pages, collections, navigation, metadata,
  and JSON-LD.
- News uses Jekyll posts in `_posts/`.
- Events use the `_events/` collection.
- Resources use the optional `_resources/` collection.
- `_plugins/event_collections.rb` produces predictable upcoming, past, and
  recent activity collections in the `Australia/Sydney` timezone.
- `_data/` holds organisation, navigation, people, community, and media data.
- `_data/media.yml` is the provenance ledger for every migrated local image.
- Sass in `_sass/` and `assets/css/main.scss` produces the site stylesheet.
- `_scripts/validate_content.rb` checks the source content contract before a
  build.

Internal links use Jekyll's `relative_url` or `absolute_url` filters so the
site remains portable between root and project-path deployments.

Event media is stored under `assets/images/events/<event-id>/`. Historical
DigiSAS material retains its canonical source URL and source status; an elapsed
event date alone is never treated as evidence that an event occurred.

## Prerequisites and setup

- Ruby 3.4.4, as declared in `.ruby-version`
- Bundler

From the repository root:

```sh
gem install bundler
bundle config set --local path vendor/bundle
bundle install
```

## Develop and validate

Serve locally:

```sh
bundle exec jekyll serve --livereload
```

Open <http://127.0.0.1:4000/>.

Run the source validator and the production build:

```sh
bundle exec ruby _scripts/validate_content.rb
JEKYLL_ENV=production bundle exec jekyll build --strict_front_matter --trace
bundle exec htmlproofer ./_site --disable-external
```

To test a project-path deployment:

```sh
JEKYLL_ENV=production bundle exec jekyll build --strict_front_matter --trace --baseurl /example
bundle exec htmlproofer ./_site --disable-external --swap-urls '^/example/:/'
```

`FGEA_TODAY=YYYY-MM-DD` may be supplied to make event grouping deterministic
during a focused test.

## Add events and news

Content is added with Markdown files. No page template or archive page needs
to be edited: Jekyll automatically adds published records to the Events, News,
and home pages.

### Add an event

1. Create `_events/<event-id>.md`. Use a stable, lowercase, hyphenated ID,
   such as `fgea-2026-q3-symposium`.
2. Copy this template and replace the example values:

```yaml
---
layout: event
event_id: fgea-2026-q3-symposium
title: FGEA CoP 2026 Q3 Symposium
summary: A hybrid FGEA CoP symposium scheduled for 24 September 2026.
start_date: "2026-09-24"
start_time: "10:00"
end_time: "12:30"
timezone: Australia/Sydney
format: hybrid
host_chapter: asia-pacific
event_status: confirmed
occurrence_status: scheduled
venue: Venue name, Sydney
registration_url: https://example.org/register
featured: false
published: true
topics: []
permalink: /events/fgea-2026-q3-symposium/
---

Add the event description, programme, speakers, and other reviewed details
here using Markdown.
```

Dates must be quoted and times use 24-hour `HH:MM`. Valid `format` values are
`online`, `in-person`, `hybrid`, and `unspecified`. Valid `event_status` values
are `confirmed`, `tentative`, `postponed`, and `cancelled`. Use
`occurrence_status: scheduled` for a future event, `occurred` after delivery
has been confirmed, or `unconfirmed` for an older schedule where delivery
cannot be verified. Omit `venue` and `registration_url` when they do not
apply. Set the optional `host_chapter` to a chapter `slug` defined in
`_data/community.yml`; omit it until the host is confirmed.

### Add a news item

1. Create `_posts/YYYY-MM-DD-<short-title>.md`. The filename date is the
   publication date.
2. Copy this template:

```yaml
---
layout: post
title: News item title
date: "2026-08-22"
summary: A concise summary shown on news listings.
kind: announcement
published: true
permalink: /news/short-title/
---

Write the news item here using Markdown.
```

Valid `kind` values are `announcement`, `recap`, `article`, and `update`. Use
`published: false` while drafting, then change it to `true` when the item is
ready.

### Link news to an event

For an event announcement, update, or recap, create both files and give them
the same `event_id`:

```yaml
# In _posts/YYYY-MM-DD-short-title.md
event_id: fgea-2026-q3-symposium
```

This automatically adds links between the event and news pages. Use
`kind: recap` only after the event has occurred, and set the event record to
`occurrence_status: occurred`. Only one recap can be linked to each event.

An optional original source link can be added to either record. Both fields
must be supplied together:

```yaml
# Event
source: https://example.org/original
source_label: Original event page

# News
source_url: https://example.org/original
source_label: Original announcement
```

### Add event images

Store images in `assets/images/events/<event-id>/`. A featured image on a news
post requires all four fields:

```yaml
image: /assets/images/events/fgea-2026-q3-symposium/agenda.png
image_alt: Published agenda for the FGEA CoP 2026 Q3 Symposium
image_width: 1600
image_height: 900
image_caption: Published agenda for the 2026 Q3 symposium.
```

The width and height must match the actual image. Strip location, device, and
other private metadata before adding photographs. Record every new local image
in `_data/media.yml`; see existing entries for the required provenance fields.
Transcribe important text from agenda images into the Markdown body so it is
accessible.

### Preview and publish

Run the local server and open <http://127.0.0.1:4000/>:

```sh
bundle exec jekyll serve --livereload
```

Before publishing, run:

```sh
bundle exec ruby _scripts/validate_content.rb
JEKYLL_ENV=production bundle exec jekyll build --strict_front_matter --trace
bundle exec htmlproofer ./_site --disable-external
```

Commit the content files and push them to a branch for review. A pull request
build validates the site without deploying it. Merging or pushing the approved
change to `main` deploys the updated site through GitHub Actions.

For complete field definitions, image requirements, redirects, drafts, and the
review checklist, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Deployment

`.github/workflows/pages.yml` validates content, builds with the base path
reported by GitHub Pages, checks internal HTML links, uploads `_site`, and
deploys that artifact. Pull requests validate without deploying. Pushes to
`main`, manual runs, and the scheduled workflow can deploy.

Only `_site` is uploaded. Source files, configuration, dependencies,
documentation, scripts, and caches are not deployment inputs.

## Repository structure

| Path | Purpose |
| --- | --- |
| `_config.yml` | Jekyll, collection, plugin, URL, and exclusion settings |
| `_data/` | Reviewed structured facts used across pages |
| `_events/` | Event records |
| `_posts/` | News, announcements, articles, updates, and recaps |
| `_resources/` | Resource records, created when the first resource is ready |
| `_includes/`, `_layouts/` | Reusable presentation and metadata templates |
| `_plugins/` | Build-time event and activity logic |
| `_scripts/` | Source validation |
| `_sass/`, `assets/` | Styles, JavaScript, images, and downloads |
| `about/`, `chapters/`, `community/`, `contact/`, `events/`, `news/`, `resources/` | Archive and information pages |

See [CONTRIBUTING.md](CONTRIBUTING.md) for the complete content schemas and
publishing requirements.
