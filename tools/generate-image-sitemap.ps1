# ACHTUNG: keine Sonderzeichen in Zeichenketten. Die .ps1-Dateien haben
# kein BOM, PowerShell 5.1 liest sie als ANSI, und ein UTF-8-Geviertstrich
# zerfaellt dabei in ein typografisches Anfuehrungszeichen, das das String-
# Literal vorzeitig beendet. In Kommentaren ist es harmlos.
#
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
    [string]$RepoRoot,
    [string]$SiteBase = 'https://adventuredogs.training',
    [string]$OutFile  = $null
)


# ACHTUNG, in PowerShell 5.1 nachgemessen: sobald [CmdletBinding()] gesetzt
# ist, ist $PSScriptRoot in den Vorgabewerten des param()-Blocks LEER. Der
# Vorgabewert fiel dadurch auf einen Pfad ohne Laufwerk zurueck und loeste
# zum Laufwerksstamm auf (C:\assets statt <repo>\assets); das Skript brach mit
# "Pfad kann nicht gefunden werden" ab, sobald man es ohne expliziten Pfad
# aufrief. Deshalb steht der Vorgabewert jetzt hier im Rumpf, wo
# $PSScriptRoot gefuellt ist.
if (-not $RepoRoot) { $RepoRoot = Join-Path $PSScriptRoot '..' }
$RepoRoot = (Resolve-Path $RepoRoot -ErrorAction Stop).Path
if (-not $OutFile) { $OutFile = Join-Path $RepoRoot 'sitemap-images.xml' }

# Die Seitenliste kommt aus tools/pages.tsv — derselben Quelle, aus der auch
# generate-sitemap.sh und check-site.sh lesen. Frueher stand sie hier ein
# zweites Mal, von Hand gepflegt und in einer anderen Sprache; wer eine neue
# Seite nur in einem der beiden Skripte eintrug, verlor sie stillschweigend
# in der jeweils anderen Sitemap.
$pagesFile = Join-Path $RepoRoot 'tools/pages.tsv'
if (-not (Test-Path $pagesFile)) { throw "tools/pages.tsv fehlt - ohne die Seitenliste laeuft hier nichts." }

$urls = @()
foreach ($line in [System.IO.File]::ReadAllLines($pagesFile)) {
    if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
    $c = $line -split "`t"
    if ($c.Count -lt 6) { throw "pages.tsv: Zeile hat $($c.Count) statt 6 Tab-Spalten: $line" }
    # Spalte 6 sagt, ob die Seite in die Bild-Sitemap gehoert.
    if ($c[5].Trim() -ne 'ja') { continue }
    $urls += @{ url = $c[0]; file = $c[1] }
}
if ($urls.Count -eq 0) { throw "pages.tsv enthaelt keine Seite mit bilder=ja." }

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$sb.AppendLine('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"')
[void]$sb.AppendLine('        xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">')

$totalImages = 0
$pagesWithImages = 0

foreach ($u in $urls) {
    $path = Join-Path $RepoRoot $u.file
    if (-not (Test-Path $path)) {
        # Frueher: stilles `continue`. Eine umbenannte Seite fiel damit
        # lautlos aus der Bild-Sitemap, waehrend die Schlusszeile weiter
        # "N Seiten, M Bilder" meldete und gesund aussah.
        throw "$($u.file) aus pages.tsv existiert nicht - sitemap-images.xml nicht angefasst."
    }
    $html = [System.IO.File]::ReadAllText($path)

    # Sammle alle Asset-Refs auf dieser Seite
    $assets = @{}
    $srcMatches = [regex]::Matches($html, 'src="[^"]*assets/([^"]+)"')
    foreach ($m in $srcMatches) {
        $name = $m.Groups[1].Value
        # Logo + favicons ausblenden — sind nicht primärer Bildkontent
        # ('^logo\.' deckt logo.png und logo.svg bereits ab)
        if ($name -match '^logo\.') { continue }
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

Write-Host ("Image sitemap: {0} images across {1} pages -> {2}" -f `
    $totalImages, $pagesWithImages, (Split-Path -Leaf $OutFile))
