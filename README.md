# David Clark Astrophotography

A dependency-free, responsive static gallery for David Clark's astrophotography. The site preserves the photographs, observing notes, equipment information, Gonnessia occultation recording, and interactive 170-megapixel Carina mosaic from the original ASP.NET Core website.

## Structure

- index.html — responsive, filterable gallery
- one directory per observing story, each with its own index.html
- assets/images — full-resolution photographs, thumbnails, video, and mosaic tiles
- assets/vendor/openseadragon — the local deep-zoom viewer runtime
- content/gallery.psd1 — gallery metadata and editorial copy
- tools/build-site.ps1 — reproducible page generator

All URLs are relative so the same files work both at the GitHub project URL and later at davidclarkastrophotography.com.

## Rebuild

From PowerShell in the repository root:

    ./tools/build-site.ps1

The generator writes the root page, detail pages, About, Equipment, Contact, 404, sitemap, robots file, and interactive mosaic page.

## Local preview

Use any static file server. For example, with Python installed:

    python -m http.server 8080

Then open http://localhost:8080/.

## Media migration notes

- The original 141.6 MiB raw AVI was converted to a 22.3 MiB H.264 MP4 at its original 400 × 300 resolution, 30 fps, and 41.1-second duration.
- Four BMP display images were losslessly converted to PNG.
- The original files remain preserved in the source Website.zip outside this repository.
- Duplicate build output, nested deployment archives, and unreferenced Microsoft/NASA viewer demos were intentionally excluded.

## Publishing

The repository is intended for GitHub Pages with deployment from the main branch root. No server-side runtime, database, package installation, or build service is required to serve it.
