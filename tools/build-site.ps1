[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$siteRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$galleryData = Import-PowerShellDataFile (Join-Path $siteRoot 'content\gallery.psd1')
$gallery = @($galleryData.Gallery)

function Write-SiteFile {
    param(
        [Parameter(Mandatory)] [string] $RelativePath,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Content
    )

    $destination = [IO.Path]::GetFullPath((Join-Path $siteRoot $RelativePath))
    if (-not $destination.StartsWith($siteRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to write outside the site root: $RelativePath"
    }

    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination)) | Out-Null
    [IO.File]::WriteAllText($destination, $Content.Trim() + [Environment]::NewLine, $utf8NoBom)
}

function Get-NavItem {
    param([string] $Href, [string] $Text, [string] $Name, [string] $Current)
    $currentAttribute = if ($Name -eq $Current) { ' aria-current="page"' } else { '' }
    return ('<li><a href="{0}"{1}>{2}</a></li>' -f $Href, $currentAttribute, $Text)
}

function Get-PageShell {
    param(
        [string] $Title,
        [string] $Description,
        [string] $Main,
        [string] $Prefix = '',
        [string] $Current = ''
    )

    $encodedTitle = [Net.WebUtility]::HtmlEncode($Title)
    $encodedDescription = [Net.WebUtility]::HtmlEncode($Description)
    $homeHref = if ($Prefix) { "${Prefix}index.html" } else { 'index.html' }
    $galleryHref = if ($Prefix) { "${Prefix}index.html#gallery" } else { '#gallery' }
    $nav = @(
        Get-NavItem -Href $homeHref -Text 'Home' -Name 'home' -Current $Current
        Get-NavItem -Href $galleryHref -Text 'Gallery' -Name 'gallery' -Current $Current
        Get-NavItem -Href "${Prefix}about/" -Text 'About' -Name 'about' -Current $Current
        Get-NavItem -Href "${Prefix}equipment/" -Text 'Equipment' -Name 'equipment' -Current $Current
        Get-NavItem -Href "${Prefix}contact/" -Text 'Contact' -Name 'contact' -Current $Current
    ) -join "`n                    "

    return @"
<!doctype html>
<html lang="en-NZ">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="$encodedDescription">
  <meta name="theme-color" content="#050711">
  <meta property="og:type" content="website">
  <meta property="og:title" content="$encodedTitle — David Clark Astrophotography">
  <meta property="og:description" content="$encodedDescription">
  <meta property="og:image" content="${Prefix}assets/images/carinamosaic1k.jpg">
  <title>$encodedTitle — David Clark Astrophotography</title>
  <link rel="icon" href="${Prefix}assets/icon.svg" type="image/svg+xml">
  <link rel="stylesheet" href="${Prefix}assets/css/site.css">
  <script src="${Prefix}assets/js/site.js" defer></script>
</head>
<body>
  <a class="skip-link" href="#main">Skip to content</a>
  <header class="site-header">
    <nav class="nav-shell" aria-label="Primary navigation">
      <a class="brand" href="$homeHref"><span class="brand-mark" aria-hidden="true"></span>David Clark Astrophotography</a>
      <button class="nav-toggle" type="button" data-nav-toggle aria-expanded="false" aria-controls="site-menu" aria-label="Open navigation">Menu</button>
      <ul class="nav-links" id="site-menu" data-nav-menu data-open="false">
                    $nav
      </ul>
    </nav>
  </header>
  <main id="main">
$Main
  </main>
  <footer class="site-footer">
    <div class="container footer-inner">
      <span>© <span data-current-year>2026</span> David Clark Astrophotography</span>
      <span>Auckland, New Zealand</span>
    </div>
  </footer>
</body>
</html>
"@
}

function Get-DetailMedia {
    param([hashtable] $Page)

    $imageBase = '../assets/images/'
    $mainImage = "$imageBase$($Page.Image)"
    $displayRelative = "web/$([IO.Path]::GetFileNameWithoutExtension($Page.Image)).webp"
    $displayCandidate = Join-Path $siteRoot ("assets\images\" + ($displayRelative -replace '/', '\'))
    $displayImage = if (Test-Path -LiteralPath $displayCandidate) { "$imageBase$displayRelative" } else { $mainImage }
    $mainAlt = [Net.WebUtility]::HtmlEncode($Page.Alt)

    switch ($Page.Special) {
        'pair' {
            $secondaryAlt = [Net.WebUtility]::HtmlEncode($Page.SecondaryAlt)
            return @"
<div class="image-pair">
  <a class="photo-frame" href="$mainImage"><img src="$displayImage" alt="$mainAlt"></a>
  <a class="photo-frame" href="$imageBase$($Page.SecondaryImage)"><img src="$imageBase$($Page.SecondaryImage)" alt="$secondaryAlt"></a>
</div>
<p class="media-note">Select either image to view the original dimensions.</p>
"@
        }
        'mosaic' {
            $annotationAlt = [Net.WebUtility]::HtmlEncode($Page.AnnotationAlt)
            $annotationDisplay = "${imageBase}web/$([IO.Path]::GetFileNameWithoutExtension($Page.AnnotationImage)).webp"
            return @"
<a class="photo-frame" href="../carina-mosaic/" aria-label="Open the interactive 170-megapixel Carina mosaic">
  <img src="$displayImage" alt="$mainAlt">
</a>
<div class="button-row" style="margin-top: 1rem">
  <a class="button" href="../carina-mosaic/">Explore the 170 MP mosaic</a>
</div>
<details class="supplement">
  <summary>View the annotated star map</summary>
  <a href="$imageBase$($Page.AnnotationImage)"><img src="$annotationDisplay" alt="$annotationAlt" loading="lazy"></a>
</details>
"@
        }
        'video' {
            return @"
<a class="photo-frame" href="$mainImage"><img src="$displayImage" alt="$mainAlt"></a>
<div class="video-frame" style="margin-top: 1rem">
  <video controls preload="metadata" poster="$mainImage">
    <source src="$imageBase$($Page.Video)" type="video/mp4">
    Your browser does not support embedded video. <a href="$imageBase$($Page.Video)">Download the MP4 recording</a>.
  </video>
</div>
<p class="media-note">41-second recording, converted from the original AVI to a 22.3 MiB H.264 MP4.</p>
<details class="supplement">
  <summary>View the predicted occultation path</summary>
  <a href="$imageBase$($Page.MapImage)"><img src="$imageBase$($Page.MapImage)" alt="Predicted Australian path for the Gonnessia occultation" loading="lazy"></a>
</details>
"@
        }
        default {
            $annotation = ''
            if ($Page.AnnotationImage) {
                $annotationAlt = [Net.WebUtility]::HtmlEncode($Page.AnnotationAlt)
                $annotationDisplay = "${imageBase}web/$([IO.Path]::GetFileNameWithoutExtension($Page.AnnotationImage)).webp"
                $annotation = @"
<details class="supplement">
  <summary>View the annotated image</summary>
  <a href="$imageBase$($Page.AnnotationImage)"><img src="$annotationDisplay" alt="$annotationAlt" loading="lazy"></a>
</details>
"@
            }
            return @"
<a class="photo-frame" href="$mainImage"><img src="$displayImage" alt="$mainAlt"></a>
<p class="media-note">Select the image to view it at full resolution.</p>
$annotation
"@
        }
    }
}

foreach ($page in $gallery) {
    $media = Get-DetailMedia -Page $page
    $title = [Net.WebUtility]::HtmlEncode($page.Title)
    $description = [Net.WebUtility]::HtmlEncode($page.Summary)
    $category = [Net.WebUtility]::HtmlEncode($page.CategoryLabel)
    $detailMain = @"
    <header class="page-hero">
      <div class="container">
        <a class="back-link" href="../index.html#gallery">← Back to gallery</a>
        <p class="eyebrow">$category · <time datetime="$($page.DateIso)">$($page.DateLabel)</time></p>
        <h1>$title</h1>
        <p class="page-intro">$description</p>
      </div>
    </header>
    <section class="section">
      <div class="container detail-layout">
        <div class="detail-media">
$media
        </div>
        <article class="detail-copy">
$($page.Body)
        </article>
      </div>
    </section>
"@
    $detailPage = Get-PageShell -Title $page.Title -Description $page.Summary -Main $detailMain -Prefix '../' -Current 'gallery'
    Write-SiteFile -RelativePath "$($page.Slug)\index.html" -Content $detailPage
}

$cards = foreach ($page in $gallery) {
    $cardTitle = [Net.WebUtility]::HtmlEncode($page.Title)
    $cardSummary = [Net.WebUtility]::HtmlEncode($page.Summary)
    $cardCategory = [Net.WebUtility]::HtmlEncode($page.CategoryLabel)
    $cardAlt = [Net.WebUtility]::HtmlEncode($page.Alt)
    @"
<article class="gallery-card" data-category="$($page.CategoryKey)">
  <a class="card-link" href="$($page.Slug)/">
    <img class="card-image" src="assets/images/$($page.Thumb)" alt="$cardAlt" loading="lazy" decoding="async">
    <div class="card-body">
      <span class="card-category">$cardCategory</span>
      <h3>$cardTitle</h3>
      <p>$cardSummary</p>
      <time class="card-date" datetime="$($page.DateIso)">$($page.DateLabel)</time>
    </div>
  </a>
</article>
"@
}

$homeMain = @"
    <section class="hero" aria-labelledby="hero-title">
      <div class="hero-content">
        <p class="eyebrow">Auckland · New Zealand</p>
        <h1 id="hero-title">The southern sky, in detail.</h1>
        <p class="hero-copy">Nebulae, galaxies, planets and time-sensitive observations captured from suburban Auckland and remote observatories.</p>
        <div class="button-row">
          <a class="button" href="#gallery">Explore the gallery</a>
          <a class="button secondary" href="carina-mosaic/">Open the 170 MP mosaic</a>
        </div>
      </div>
    </section>

    <section class="section" aria-labelledby="introduction-title">
      <div class="container">
        <div class="section-heading">
          <div>
            <p class="eyebrow">Field notes in light</p>
            <h2 id="introduction-title">From first light to deep mosaics</h2>
          </div>
          <p>This collection follows a journey through deep-sky imaging, planetary lucky imaging, photometry and asteroid occultation work. Every image below opens to its original story and full-resolution file.</p>
        </div>
        <div class="stats-grid" aria-label="Collection highlights">
          <div class="stat"><strong>$($gallery.Count) observing stories</strong><span>Nebulae, galaxies, planets and scientific observations</span></div>
          <div class="stat"><strong>839 exposures</strong><span>Combined in the 170-megapixel Carina mosaic</span></div>
          <div class="stat"><strong>7.75 seconds</strong><span>The measured Gonnessia stellar occultation</span></div>
        </div>
      </div>
    </section>

    <section class="section" id="gallery" aria-labelledby="gallery-title">
      <div class="container">
        <div class="section-heading">
          <div>
            <p class="eyebrow">The collection</p>
            <h2 id="gallery-title">Astronomical images</h2>
          </div>
          <p>Filter the collection by subject, or browse all observations in one responsive gallery.</p>
        </div>
        <div class="filter-bar" aria-label="Filter gallery">
          <button class="filter-button" type="button" data-filter="all" aria-pressed="true">All</button>
          <button class="filter-button" type="button" data-filter="nebulae" aria-pressed="false">Nebulae</button>
          <button class="filter-button" type="button" data-filter="solar-system" aria-pressed="false">Solar System</button>
          <button class="filter-button" type="button" data-filter="clusters-galaxies" aria-pressed="false">Clusters &amp; Galaxies</button>
          <button class="filter-button" type="button" data-filter="observations" aria-pressed="false">Observations</button>
        </div>
        <div class="gallery-grid">
$($cards -join "`n")
        </div>
      </div>
    </section>
"@

$homePage = Get-PageShell -Title 'Home' -Description 'Astrophotography by David Clark from Auckland, New Zealand: nebulae, galaxies, planets and astronomical observations.' -Main $homeMain -Current 'home'
Write-SiteFile -RelativePath 'index.html' -Content $homePage

$aboutMain = @"
    <header class="page-hero">
      <div class="container">
        <p class="eyebrow">About</p>
        <h1>Looking upward from Auckland.</h1>
        <p class="page-intro">David Clark is an amateur astrophotographer working from suburban Auckland, New Zealand, and with remote observatories when a target calls for darker skies.</p>
      </div>
    </header>
    <section class="section">
      <div class="container prose detail-copy">
        <p>This archive brings together deep-sky photographs, planetary imaging and scientific observations made between 2020 and 2022.</p>
        <p>The collection ranges from first attempts at the Orion Nebula and Jewel Box Cluster to a 170-megapixel Carina mosaic assembled from 839 exposures. It also records an exoplanet transit, a supernova and a 7.75-second stellar occultation by asteroid Gonnessia.</p>
        <p>The original website has been preserved here as a fast, accessible static gallery. The full-resolution photographs and interactive Carina mosaic remain available throughout the collection.</p>
        <div class="button-row" style="margin-top: 2rem"><a class="button" href="../index.html#gallery">View the gallery</a></div>
      </div>
    </section>
"@
$aboutPage = Get-PageShell -Title 'About' -Description 'About David Clark and this Auckland astrophotography collection.' -Main $aboutMain -Prefix '../' -Current 'about'
Write-SiteFile -RelativePath 'about\index.html' -Content $aboutPage

$equipmentMain = @"
    <header class="page-hero">
      <div class="container">
        <p class="eyebrow">Equipment</p>
        <h1>The original imaging setup.</h1>
        <p class="page-intro">The telescope, mount and imaging train used for much of this collection.</p>
      </div>
    </header>
    <section class="section">
      <div class="container">
        <div class="equipment-grid">
          <div class="equipment-item"><strong>Telescope</strong><span>Sky-Watcher Esprit 120ED apochromatic refractor</span></div>
          <div class="equipment-item"><strong>Mount</strong><span>iOptron CEM60-EC</span></div>
          <div class="equipment-item"><strong>Primary camera</strong><span>QHY163M monochrome camera</span></div>
          <div class="equipment-item"><strong>Filter wheel</strong><span>QHY v3 with L, R, G, B, H-alpha, S-II and O-III filters</span></div>
          <div class="equipment-item"><strong>Guiding</strong><span>QHY off-axis guider</span></div>
          <div class="equipment-item"><strong>Guide camera</strong><span>ZWO ASI174MM Mini</span></div>
        </div>
        <div class="prose detail-copy" style="margin-top: 2rem">
          <p>Selected later images were captured through remote-controlled telescopes at Siding Spring Observatory, Australia. Individual image pages identify those sessions.</p>
        </div>
      </div>
    </section>
"@
$equipmentPage = Get-PageShell -Title 'Equipment' -Description 'The telescope, mount, cameras and filters used for David Clark astrophotography.' -Main $equipmentMain -Prefix '../' -Current 'equipment'
Write-SiteFile -RelativePath 'equipment\index.html' -Content $equipmentPage

$contactMain = @"
    <header class="page-hero">
      <div class="container">
        <p class="eyebrow">Contact</p>
        <h1>Share a view of the sky.</h1>
        <p class="page-intro">Questions about an image, observing session or processing workflow are welcome.</p>
      </div>
    </header>
    <section class="section">
      <div class="container prose">
        <div class="contact-card">
          <p class="eyebrow">Email David</p>
          <h2 style="font-size: clamp(1.5rem, 4vw, 2.5rem)"><a href="mailto:davidjohnclark@gmail.com">davidjohnclark@gmail.com</a></h2>
          <p style="color: var(--muted); margin-bottom: 0">Suburban Auckland, New Zealand</p>
        </div>
      </div>
    </section>
"@
$contactPage = Get-PageShell -Title 'Contact' -Description 'Contact David Clark about astrophotography from Auckland, New Zealand.' -Main $contactMain -Prefix '../' -Current 'contact'
Write-SiteFile -RelativePath 'contact\index.html' -Content $contactPage

$notFoundMain = @"
    <header class="page-hero">
      <div class="container">
        <p class="eyebrow">404 · Lost in space</p>
        <h1>This object is outside the field of view.</h1>
        <p class="page-intro">The address may have changed during the migration from the original website.</p>
        <div class="button-row"><a class="button" href="index.html">Return to the gallery</a></div>
      </div>
    </header>
"@
$notFoundPage = Get-PageShell -Title 'Page not found' -Description 'The requested page could not be found.' -Main $notFoundMain
Write-SiteFile -RelativePath '404.html' -Content $notFoundPage

$mosaicPage = @"
<!doctype html>
<html lang="en-NZ">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#000000">
  <meta name="description" content="Explore David Clark's 170-megapixel Carina Nebula mosaic.">
  <title>Interactive Carina Mosaic — David Clark Astrophotography</title>
  <link rel="icon" href="../assets/icon.svg" type="image/svg+xml">
  <link rel="stylesheet" href="../assets/css/site.css">
</head>
<body class="mosaic-page">
  <a class="mosaic-exit" href="../carinamosaic/">← Back to the story</a>
  <main id="seadragon-viewer" class="mosaic-viewer" aria-label="Interactive 170-megapixel Carina Nebula mosaic"></main>
  <script src="../assets/vendor/openseadragon/openseadragon.min.js"></script>
  <script>
    OpenSeadragon({
      id: "seadragon-viewer",
      prefixUrl: "../assets/vendor/openseadragon/images/",
      tileSources: [{
        type: "zoomifytileservice",
        width: 15401,
        height: 11103,
        tilesUrl: "../assets/images/CarinaMosaic/"
      }],
      showFullPageControl: true,
      showNavigator: true,
      homeFillsViewer: true,
      gestureSettingsMouse: { clickToZoom: true, dblClickToZoom: true },
      gestureSettingsTouch: { pinchToZoom: true, flickEnabled: true }
    });
  </script>
</body>
</html>
"@
Write-SiteFile -RelativePath 'carina-mosaic\index.html' -Content $mosaicPage

$legacyMosaicRedirect = @"
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="0; url=carina-mosaic/"><link rel="canonical" href="carina-mosaic/">
<title>Opening the Carina mosaic</title></head>
<body><p><a href="carina-mosaic/">Open the interactive Carina mosaic</a></p></body></html>
"@
Write-SiteFile -RelativePath 'CarinaMosaic2.html' -Content $legacyMosaicRedirect

$sitemapEntries = @(
    'https://davidclarkastrophotography.com/'
    'https://davidclarkastrophotography.com/about/'
    'https://davidclarkastrophotography.com/equipment/'
    'https://davidclarkastrophotography.com/contact/'
    'https://davidclarkastrophotography.com/carina-mosaic/'
) + @($gallery | ForEach-Object { "https://davidclarkastrophotography.com/$($_.Slug)/" })
$sitemapUrls = $sitemapEntries | ForEach-Object { "  <url><loc>$([Security.SecurityElement]::Escape($_))</loc></url>" }
$sitemap = @"
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
$($sitemapUrls -join "`n")
</urlset>
"@
Write-SiteFile -RelativePath 'sitemap.xml' -Content $sitemap
Write-SiteFile -RelativePath 'robots.txt' -Content "User-agent: *`nAllow: /`nSitemap: https://davidclarkastrophotography.com/sitemap.xml"
Write-SiteFile -RelativePath '.nojekyll' -Content ''

Write-Host "Built $($gallery.Count) gallery pages and supporting static pages in $siteRoot"
