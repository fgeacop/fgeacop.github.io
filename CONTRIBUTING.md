# Contributing content

All published statements must be factual, attributable where appropriate, and
reviewed by a person familiar with the subject. Do not infer that a scheduled
event occurred. Use Australian/British spelling, Oxford commas, and concise
plain language.

Run these checks before requesting review:

```sh
bundle exec ruby _scripts/validate_content.rb
JEKYLL_ENV=production bundle exec jekyll build --strict_front_matter --trace --baseurl /fgea
bundle exec htmlproofer ./_site --disable-external --swap-urls '^/fgea/:/'
```

## News

Create `_posts/YYYY-MM-DD-short-title.md`. Required front matter is:

```yaml
---
layout: post
title: A factual title
date: "YYYY-MM-DD"
summary: A short listing summary.
kind: announcement
published: true
---
```

`kind` is `announcement`, `recap`, `article`, or `update`. The date must remain
quoted. `description` may provide a longer metadata description and otherwise
falls back to `summary`.

For a sourced item, provide both fields:

```yaml
source_url: https://example.org/original
source_label: Original announcement
```

To link news to an event, add its stable `event_id`. Use `kind: recap` only for
an account that evidence establishes took place. Only one recap may reference
an event. Archives and homepage cards are generated automatically.

## Events and event recaps

Create `_events/stable-event-id.md` with:

```yaml
---
layout: event
event_id: stable-event-id
title: Event title
summary: A factual event summary.
start_date: "YYYY-MM-DD"
start_time: "10:00"
end_time: "12:30"
timezone: Australia/Sydney
format: online
event_status: confirmed
source: https://example.org/announcement
source_label: Original announcement
published: true
---
```

Dates must be quoted. Times use 24-hour `HH:MM`. Add a quoted `end_date` for a
multi-day event. `format` is `online`, `in-person`, or `hybrid`.
`event_status` is `confirmed`, `tentative`, `postponed`, or `cancelled`.

Include `venue`, `location`, or `registration_url` only when verified.
`registration_url` must be an absolute HTTP(S) URL. Keep the source and its
label together. The generator excludes cancelled events from upcoming events
and lists past events newest first.

Create a recap as a news post and link it with `event_id`. Preserve an
announcement if it remains the accurate historical source. Do not rewrite it
as a recap without evidence.

## Resources

Create `_resources/` when the first reviewed resource is ready, then add a
Markdown document with:

```yaml
---
layout: resource
resource_id: stable-resource-id
title: Resource title
summary: A factual resource summary.
resource_type: guide
published_date: "YYYY-MM-DD"
external_url: https://example.org/resource
published: true
---
```

`resource_type` is `report`, `guide`, `tool`, `recording`, `presentation`,
`article`, or `other`. Provide exactly one of:

- `external_url`, an absolute HTTP(S) URL; or
- `download_path`, a safe local file path such as
  `/assets/downloads/resource.pdf`.

Optional source attribution uses the `source_url` and `source_label` pair.

## Site configuration, people, and community data

- Edit `_data/organization.yml` for organisation-wide text and contact details.
- Edit `_data/navigation.yml` for primary navigation.
- Edit `_data/people.yml` for leadership and advisory entries.
- Edit `_data/community.yml` for participating organisations and chapter
  regions.
- Record image provenance and review status in `_data/media.yml`.

Do not add claims to structured data that are absent from reviewed source
content. Changes to names, roles, affiliations, membership, contact details,
or links require factual review.

## Images

Store local images below `assets/images/`. An `image` field must have an
`image_alt` field, including an empty string only when the image is genuinely
decorative. Do not hotlink an essential image. Confirm provenance, reuse
permission, credit, dimensions, and compression before publishing. No logo or
favicon should be inferred from decorative site artwork.

## Drafts, publication, and removal

Use `_drafts/` for unfinished news, or set `published: false` on a post,
event, or resource. Unpublished collection items are excluded from generated
lists. Preview drafts only in a deliberate local review.

Removing a published URL breaks bookmarks. Prefer a correction or archival
note. If removal is required, add the old path to `redirect_from` on the
replacement:

```yaml
redirect_from:
  - /old/local/path.html
```

Keep filenames, `event_id`, `resource_id`, explicit permalinks, and established
redirects stable. Never hardcode the deployment base path in content or
templates. Use root-relative paths with `relative_url` for internal links.

## Review checklist

1. Confirm every date, time, timezone, status, location, name, role, and claim.
2. Check source links and labels against the source.
3. Confirm that summaries do not imply more than the body or source.
4. Review images and downloads for provenance, permission, accessibility, and
   file size.
5. Run source validation, a strict production build, and HTML proofing.
6. Inspect the rendered page, archives, metadata, and redirects at narrow and
   wide viewport widths.
