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
- Sass in `_sass/` and `assets/css/main.scss` produces the site stylesheet.
- `_scripts/validate_content.rb` checks the source content contract before a
  build.

Internal links use Jekyll's `relative_url` or `absolute_url` filters so the
site remains portable between root and project-path deployments.

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
| `about/`, `community/`, `contact/`, `events/`, `news/`, `resources/` | Archive and information pages |

See [CONTRIBUTING.md](CONTRIBUTING.md) for content schemas and publishing
workflows.
