# Generate a separate image sitemap (sitemap-images.xml) that lists
# all unique /assets/ image references per page. Google uses this for
# Image Search indexing — separate from the regular URL sitemap so
# the two concerns stay clean.
#
# Strategy: walk the URL list (same as sitemap.xml), for each HTML
# file scan all <img src=...> and url(...) references that point to
# /assets/, dedupe per-page, emit <image:image> children.
#
# Idempotent: always regenerates from current HTML.

[CmdletBinding()]
param(
    [string]$RepoRoot = $PSScriptRoot + '\..',
    [string]$SiteBase = 'https://adventuredogs.training',
    [string]$OutFile  = $null
)

$RepoRoot = (Resolve-Path $RepoRoot -ErrorAction Stop).Path
if (-not $OutFile) { $OutFile = Join-Path $RepoRoot 'sitemap-images.xml' }

# URL -> relative HTML path mapping. Mirrors the URL list in sitemap.xml.
$urls = @(
    @{ url='/';                                  file='index.html' }
    @{ url='/angebot/';                          file='angebot/index.html' }
    @{ url='/ueber-mich/';                       file='ueber-mich/index.html' }
    @{ url='/alltagstipps/';                     file='alltagstipps/index.html' }
    @{ url='/alltagstipps/welpenzeit/';          file='alltagstipps/welpenzeit/index.html' }
    @{ url='/alltagstipps/silvester/';           file='alltagstipps/silvester/index.html' }
    @{ url='/alltagstipps/urlaub/';              file='alltagstipps/urlaub/index.html' }
    @{ url='/alltagstipps/winter/';              file='alltagstipps/winter/index.html' }
    @{ url='/alltagstipps/alleinbleiben/';       file='alltagstipps/alleinbleiben/index.html' }
    @{ url='/alltagstipps/tierphysiotherapie/';  file='alltagstipps/tierphysiotherapie/index.html' }
    @{ url='/alltagstipps/ernaehrung/';          file='alltagstipps/ernaehrung/index.html' }
    @{ url='/alltagstipps/hund-entlaufen/';      file='alltagstipps/hund-entlaufen/index.html' }
    @{ url='/kontakt/';                          file='kontakt/index.html' }
)

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$sb.AppendLine('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"')
[void]$sb.AppendLine('        xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">')

$totalImages = 0
$pagesWithImages = 0

foreach ($u in $urls) {
    $path = Join-Path $RepoRoot $u.file
    if (-not (Test-Path $path)) { continue }
    $html = [System.IO.File]::ReadAllText($path)

    # Sammle alle Asset-Refs auf dieser Seite
    $assets = @{}
    $srcMatches = [regex]::Matches($html, 'src="[^"]*assets/([^"]+)"')
    foreach ($m in $srcMatches) {
        $name = $m.Groups[1].Value
        # Logo + favicons ausblenden — sind nicht primärer Bildkontent
        if ($name -match '^logo\.' -or $name -eq 'logo.png' -or $name -eq 'logo.svg') { continue }
        $assets[$name] = $true
    }
    $urlMatches = [regex]::Matches($html, "url\([`"']?[^)]*assets/([^)`"']+)[`"']?\)")
    foreach ($m in $urlMatches) {
        $name = $m.Groups[1].Value
        if ($name -match '\.css$' -or $name -match '\.woff') { continue }
        if ($name -match '^logo\.') { continue }
        $assets[$name] = $true
    }

    if ($assets.Count -eq 0) { continue }

    [void]$sb.AppendLine('  <url>')
    [void]$sb.AppendFormat('    <loc>{0}{1}</loc>{2}', $SiteBase, $u.url, "`n")
    foreach ($name in ($assets.Keys | Sort-Object)) {
        [void]$sb.AppendFormat('    <image:image>{0}', "`n")
        [void]$sb.AppendFormat('      <image:loc>{0}/assets/{1}</image:loc>{2}', $SiteBase, $name, "`n")
        [void]$sb.AppendLine('    </image:image>')
        $totalImages++
    }
    [void]$sb.AppendLine('  </url>')
    $pagesWithImages++
}

[void]$sb.AppendLine('</urlset>')

[System.IO.File]::WriteAllText($OutFile, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))

Write-Host ("Image sitemap: {0} images across {1} pages → {2}" -f `
    $totalImages, $pagesWithImages, (Split-Path -Leaf $OutFile))
