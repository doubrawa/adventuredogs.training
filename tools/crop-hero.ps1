# One-shot aspect-crop helper.
# Crops the input image to the given aspect ratio by trimming top+bottom
# (or left+right if source is wider than target). Then resizes to target.
#
# Usage:
#   pwsh -File tools/crop-hero.ps1 -Src "in.jpg" -Dst "out.jpg" -W 1920 -H 1080
#   pwsh -File tools/crop-hero.ps1 -Src "in.jpg" -Dst "out.jpg" -Anchor top
#
# -Anchor controls where the crop band sits in the source:
#   center (default) — middle band, trims equally from top and bottom
#                      (or equally from left and right for horizontal crops)
#   top              — keep the top, cut from the bottom
#   bottom           — keep the bottom, cut from the top
# For horizontal crops the same names map to: left/center/right via the
# obvious analogy (anchor=top → cropX=0, anchor=bottom → cropX=sw-cropW).

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Src,
    [Parameter(Mandatory)][string]$Dst,
    [int]$W = 1920,
    [int]$H = 1080,
    [int]$Quality = 88,
    [ValidateSet('center','top','bottom')][string]$Anchor = 'center'
)

Add-Type -AssemblyName System.Drawing

$jpegEncoder   = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
                 Where-Object { $_.MimeType -eq 'image/jpeg' }
$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
    [System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)

$img = [System.Drawing.Image]::FromFile($Src)
try {
    $sw = $img.Width
    $sh = $img.Height
    $ratio = $W / $H

    # Decide crop box on source: maximise area at target aspect, anchored
    # per -Anchor (default center).
    $cropW = $sw
    $cropH = [int]([math]::Round($sw / $ratio))
    if ($cropH -gt $sh) {
        # Source narrower than target ratio → horizontal crop, full height.
        $cropH = $sh
        $cropW = [int]([math]::Round($sh * $ratio))
        $cropY = 0
        switch ($Anchor) {
            'top'    { $cropX = 0 }                            # → keep left side
            'bottom' { $cropX = $sw - $cropW }                 # → keep right side
            default  { $cropX = [int]([math]::Round(($sw - $cropW) / 2)) }
        }
    } else {
        # Source taller than target ratio → vertical crop, full width.
        $cropX = 0
        switch ($Anchor) {
            'top'    { $cropY = 0 }                            # keep top, cut bottom
            'bottom' { $cropY = $sh - $cropH }                 # keep bottom, cut top
            default  { $cropY = [int]([math]::Round(($sh - $cropH) / 2)) }
        }
    }
    $srcRect = New-Object System.Drawing.Rectangle $cropX, $cropY, $cropW, $cropH

    $bmp = New-Object System.Drawing.Bitmap $W, $H
    try {
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $dstRect = New-Object System.Drawing.Rectangle 0, 0, $W, $H
            $g.DrawImage($img, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
        } finally { $g.Dispose() }
        $tmp = "$Dst.tmp.jpg"
        $bmp.Save($tmp, $jpegEncoder, $encoderParams)
        $img.Dispose()
        $img = $null
        Move-Item -Force $tmp $Dst
        Write-Host ("OK  {0} : {1}x{2} -> crop {3}x{4} @ ({5},{6}) -> {7}x{8}" -f `
            ([System.IO.Path]::GetFileName($Src)), $sw, $sh, $cropW, $cropH, $cropX, $cropY, $W, $H)
    } finally { $bmp.Dispose() }
} finally {
    if ($img) { $img.Dispose() }
}
