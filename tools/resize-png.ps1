# Resize a PNG preserving alpha (logos, icons). Unlike crop-hero.ps1
# (JPEG-only), this keeps the alpha channel intact.
#
# Usage:
#   pwsh -File tools/resize-png.ps1 -Src in.png -Dst out.png -MaxWidth 360

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Src,
    [Parameter(Mandatory)][string]$Dst,
    [int]$MaxWidth = 360
)

Add-Type -AssemblyName System.Drawing

$img = [System.Drawing.Image]::FromFile((Resolve-Path $Src))
try {
    $w = $img.Width; $h = $img.Height
    if ($w -le $MaxWidth) {
        Write-Host ("skip  {0}: {1}x{2} already <= {3}px" -f (Split-Path -Leaf $Src), $w, $h, $MaxWidth)
        return
    }
    $newW = $MaxWidth
    $newH = [int]([math]::Round($h * $MaxWidth / $w))

    $bmp = New-Object System.Drawing.Bitmap -ArgumentList $newW, $newH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.Clear([System.Drawing.Color]::Transparent)
            $g.DrawImage($img, 0, 0, $newW, $newH)
        } finally { $g.Dispose() }
        $tmp = "$Dst.tmp.png"
        $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
        $img.Dispose(); $img = $null
        Move-Item -Force $tmp $Dst
        Write-Host ("OK    {0}: {1}x{2} -> {3}x{4}" -f (Split-Path -Leaf $Dst), $w, $h, $newW, $newH)
    } finally { $bmp.Dispose() }
} finally {
    if ($img) { $img.Dispose() }
}
