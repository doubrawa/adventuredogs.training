# Resize JPEG assets to web-sensible dimensions.
#
# Idempotent: only touches files that exceed the size cap, so running
# this repeatedly (or after a fresh design re-import) does the right
# thing -- already-sized files are left alone.
#
# Two tiers:
#   hero-*.jpg / kontakt-hero.jpg         → max 2400px wide  (full-bleed photos)
#   everything else                       → max 1600px wide  (portraits, section
#                                                              images, offer cards)
#
# JPEG quality 82, EXIF/colour-profile metadata stripped (small but adds up).
# Resampling: HighQualityBicubic -- the slow but visually best built-in mode.
#
# Usage:
#   pwsh -File tools/resize-assets.ps1            (from repo root)
#   pwsh -File tools/resize-assets.ps1 -DryRun    (report what would change)

[CmdletBinding()]
param(
    [string]$AssetsDir = "$PSScriptRoot\..\assets",
    [int]$HeroMaxWidth = 2400,
    [int]$DefaultMaxWidth = 1600,
    [int]$Quality = 82,
    [switch]$DryRun
)

Add-Type -AssemblyName System.Drawing

$jpegEncoder   = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
                 Where-Object { $_.MimeType -eq 'image/jpeg' }
$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$qualityParam  = New-Object System.Drawing.Imaging.EncoderParameter(
                   [System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)
$encoderParams.Param[0] = $qualityParam

function Get-MaxWidth($name) {
    if ($name -match '^(hero-|kontakt-hero)') { return $HeroMaxWidth }
    return $DefaultMaxWidth
}

function Resize-Jpeg($path, $maxWidth) {
    $img = [System.Drawing.Image]::FromFile($path)
    try {
        $w = $img.Width
        $h = $img.Height
        if ($w -le $maxWidth) {
            return @{ changed = $false; oldW = $w; oldH = $h; newW = $w; newH = $h }
        }
        $newW = $maxWidth
        $newH = [int]([math]::Round($h * $maxWidth / $w))

        $bmp = New-Object System.Drawing.Bitmap($newW, $newH)
        try {
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            try {
                $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $g.DrawImage($img, 0, 0, $newW, $newH)
            } finally {
                $g.Dispose()
            }

            if (-not $DryRun) {
                # System.Drawing keeps a lock on the source while $img is
                # alive, so save to a tempfile and replace afterwards.
                $tmp = "$path.tmp.jpg"
                $bmp.Save($tmp, $jpegEncoder, $encoderParams)
                $img.Dispose()
                $img = $null
                Move-Item -Force $tmp $path
            }
        } finally {
            $bmp.Dispose()
        }
        return @{ changed = $true; oldW = $w; oldH = $h; newW = $newW; newH = $newH }
    } finally {
        if ($img) { $img.Dispose() }
    }
}

$resolved = Resolve-Path $AssetsDir -ErrorAction Stop
$totalBefore = 0
$totalAfter  = 0
$changedCount = 0
$skippedCount = 0

Get-ChildItem -Path $resolved -File |
    Where-Object { $_.Extension -in '.jpg', '.jpeg', '.JPG', '.JPEG' } |
    Sort-Object Name | ForEach-Object {
    $f = $_
    $maxW = Get-MaxWidth $f.Name
    $sizeBefore = $f.Length
    $totalBefore += $sizeBefore

    try {
        $r = Resize-Jpeg $f.FullName $maxW
        if ($r.changed) {
            $changedCount++
            if (-not $DryRun) {
                $sizeAfter = (Get-Item $f.FullName).Length
            } else {
                $sizeAfter = $sizeBefore  # dry run, can't actually measure
            }
            $totalAfter += $sizeAfter
            $kbBefore = [math]::Round($sizeBefore / 1024)
            $kbAfter  = [math]::Round($sizeAfter / 1024)
            $verb = if ($DryRun) { 'WOULD' } else { 'OK   ' }
            Write-Host ("$verb  {0,-32} {1}x{2} -> {3}x{4}   {5,5} -> {6,5} KB" -f `
                $f.Name, $r.oldW, $r.oldH, $r.newW, $r.newH, $kbBefore, $kbAfter)
        } else {
            $skippedCount++
            $totalAfter += $sizeBefore
            $kb = [math]::Round($sizeBefore / 1024)
            Write-Host ("skip  {0,-32} {1}x{2}              already <= {3}px, {4} KB" -f `
                $f.Name, $r.oldW, $r.oldH, $maxW, $kb) -ForegroundColor DarkGray
        }
    } catch {
        Write-Host ("ERR   {0,-32} {1}" -f $f.Name, $_.Exception.Message) -ForegroundColor Red
    }
}

$mbBefore = [math]::Round($totalBefore / 1MB, 2)
$mbAfter  = [math]::Round($totalAfter  / 1MB, 2)
$saved    = $totalBefore - $totalAfter
$mbSaved  = [math]::Round($saved / 1MB, 2)
$pct      = if ($totalBefore -gt 0) { [math]::Round(100 * $saved / $totalBefore, 1) } else { 0 }

Write-Host ""
Write-Host ("Resized: {0}, skipped: {1}" -f $changedCount, $skippedCount)
Write-Host ("Total: {0} MB -> {1} MB  (saved {2} MB, {3}%)" -f $mbBefore, $mbAfter, $mbSaved, $pct)
if ($DryRun) { Write-Host "(dry run -- no files were modified)" -ForegroundColor Yellow }
