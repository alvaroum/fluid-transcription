# Publishing Docs

## Goal

This repository now includes a documentation tree that is ready to evolve into a published docs site.

The current structure is based on:

- `mkdocs.yml`
- `docs/` Markdown content
- `.github/workflows/docs.yml`

## Current Automated Path

The repository now includes a GitHub Pages workflow that:

- installs MkDocs
- builds the documentation site from `docs/`
- uploads the generated `site/` output as a Pages artifact
- deploys it using GitHub Pages

## Local Preview

If `mkdocs` is installed locally, you can preview the site with:

```bash
mkdocs serve
```

Then open the local URL shown by MkDocs.

## Build Static Site

```bash
mkdocs build
```

This generates the static site into:

```text
site/
```

That directory is ignored by git.

## What You May Still Want To Customize

- theme choice if you want something other than the default Read the Docs theme
- `site_url` and repository metadata if you want canonical URLs in generated pages
- navigation depth as the docs set grows

## Suggested Publication Paths

### GitHub Pages

- already wired through `.github/workflows/docs.yml`
- requires GitHub Pages to be enabled for the repository

### Internal Static Hosting

- run `mkdocs build`
- deploy `site/` to your internal web server or artifact host

## Documentation Maintenance Guidelines

- Keep README short and task-oriented
- Put durable explanations in `docs/`
- Add new pages by topic, not by date
- Keep command behavior synchronized with `--help`