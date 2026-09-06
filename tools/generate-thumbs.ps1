# Generate small thumbnail versions of the Alltagstipps hero photos.
# The hub-page card grid and the "Weiterlesen" cards on detail pages
# render at roughly 400px wide. Loading the full 1920px hero for each
# is wasteful — we generate 800px-wide thumbs (= 2x DPI sweet spot)
# and let the cards reference those.
#
# Mapping: thumb-<slug>.jpg derived from a chosen source asset.
# Idempotent via mtime: rebuilds only when source is newer than thumb.
#
# Usage:
#   pwsh -File tools/generate-thumbs.ps1
#   pwsh -File tools/generate-thumbs.ps1 -Force   # always rebuild

[CmdletBinding()]
param(
    [string]$AssetsDir = "$PSScriptRoot\..\assets",
    [int]$MaxWidth = 800,
    [int]$Quality = 80,
    [switch]$Force
)

# Topic slug => source asset to derive thumb from.
$thumbs = @(
    @{ slug='welpenzeit';         source='offer-welpenkurs.jpg' }
    @{ slug='silvester';          source='hero-silvester.jpg' }
    @{ slug='urlaub';             source='hero-urlaub.jpg' }
    @{ slug='winter';             source='hero-winter.jpg' }
    @{ slug='alleinbleiben';      source='hero-alleinbleiben.jpg' }
    @{ slug='tierphysiotherapie'; source='hero-tierphysiotherapie.jpg' }
    @{ slug='ernaehrung';         source='hero-ernaehrung.jpg' }
    @{ slug='hund-entlaufen';     source='hero-hund-entlaufen.jpg' }
)

Add-Type -AssemblyName System.Drawing

$jpegEncoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
               Where-Object { $_.MimeType -eq 'image/jpeg' }
$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
    [System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)

$assetsDir = (Resolve-Path $AssetsDir -ErrorAction Stop).Path
$builtCount = 0
$skipCount = 0

foreach ($t in $thumbs) {
    $srcPath = Join-Path $assetsDir $t.source
    $dstPath = Join-Path $assetsDir "thumb-$($t.slug).jpg"

    if (-not (Test-Path $srcPath)) {
        Write-Host ("  skip (source missing): {0}" -f $t.source) -ForegroundColor DarkGray
        continue
    }

    # mtime-based idempotency: only rebuild if thumb is older than source
    if (-not $Force -and (Test-Path $dstPath)) {
        $srcTime = (Get-Item $srcPath).LastWriteTime
        $dstTime = (Get-Item $dstPath).LastWriteTime
        if ($dstTime -ge $srcTime) {
            $skipCount++
            continue
        }
    }

    $img = [System.Drawing.Image]::FromFile($srcPath)
    try {
        $sw = $img.Width; $sh = $img.Height
        if ($sw -le $MaxWidth) {
            $newW = $sw; $newH = $sh
        } else {
            $newW = $MaxWidth
            $newH = [int]([math]::Round($sh * $MaxWidth / $sw))
        }

        $bmp = New-Object System.Drawing.Bitmap $newW, $newH
        try {
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            try {
                $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $g.DrawImage($img, 0, 0, $newW, $newH)
            } finally { $g.Dispose() }

            $tmp = "$dstPath.tmp.jpg"
            $bmp.Save($tmp, $jpegEncoder, $encoderParams)
            $img.Dispose()
            $img = $null
            Move-Item -Force $tmp $dstPath
        } finally { $bmp.Dispose() }

        $srcSize = (Get-Item $srcPath).Length
        $dstSize = (Get-Item $dstPath).Length
        $builtCount++
        Write-Host ("  OK   thumb-{0}.jpg : {1}KB ({2}x{3}) from {4} ({5}KB)" -f `
            $t.slug, [int]($dstSize/1024), $newW, $newH, $t.source, [int]($srcSize/1024))
    } finally {
        if ($img) { $img.Dispose() }
    }
}

if ($builtCount -gt 0) {
    Write-Host ("Built {0} thumbnails, {1} skipped (up-to-date)" -f $builtCount, $skipCount)
} else {
    Write-Host ("All {0} thumbnails up-to-date" -f $skipCount)
}
