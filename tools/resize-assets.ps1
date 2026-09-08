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
    [string]$AssetsDir,
    [int]$HeroMaxWidth = 2400,
    [int]$DefaultMaxWidth = 1600,
    [int]$Quality = 82,
    # Bytes je Megapixel, ab denen neu kodiert wird, auch wenn die Breite passt.
    #
    # Gemessen im Bestand (08.09.2026): hero-landing.jpg kommt mit 82 KB/MP aus,
    # hero-angebot mit 163, hero-alltagstipps mit 201 - und hero-silvester.jpg
    # mit 347, also viermal so schwer wie das leichteste. 250000 zieht die
    # Grenze zwischen "kraeftig, aber plausibel" und "Ausreisser". Bilder mit
    # viel Rauschen oder Struktur duerfen schwerer sein, deshalb nicht enger.
    [int]$MaxBytesPerMegapixel = 250000,
    [switch]$DryRun
)

Add-Type -AssemblyName System.Drawing

# Welche Assets referenziert die Website ueberhaupt? Alles andere wird nur
# gemeldet, nicht angefasst.
#
# Grund: das Skript kodiert in der Quelldatei selbst neu. So ist
# grafitiwand_HQ.jpg (das Quellbild von hero-gebucht.jpg) unter die
# Aufloesung seines eigenen Derivats gerutscht, bevor es am 06.09.2026
# geloescht wurde. Ein Archivbild, das keine Seite einbindet, hat hier nichts
# zu suchen - aber solange es da liegt, soll es wenigstens heil bleiben.
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$referenziert = @{}
Get-ChildItem -Path $RepoRoot -Include *.html, *.css, *.xml -File -Recurse |
    Where-Object { $_.FullName -notmatch '\\(\.git|willkommensmappe)\\' } |
    ForEach-Object {
        $text = [System.IO.File]::ReadAllText($_.FullName)
        foreach ($m in [regex]::Matches($text, 'assets/([A-Za-z0-9._%-]+)')) {
            $referenziert[$m.Groups[1].Value] = $true
        }
    }

$jpegEncoder   = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
                 Where-Object { $_.MimeType -eq 'image/jpeg' }
$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$qualityParam  = New-Object System.Drawing.Imaging.EncoderParameter(
                   [System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)
$encoderParams.Param[0] = $qualityParam

function Get-MaxWidth($name) {
    # Heroes are full-bleed photos at the top of pages — they want
    # ~2400px to look crisp on retina monitors. Everything else
    # (portraits, offer cards, etc.) gets the 1600px default.
    #
    # `kontakt-hero` ist raus: die Datei heisst hero-kontakt.jpg, das Muster lief
    # ins Leere. `strand` ist ebenfalls raus - die Datei war in keiner Seite
    # referenziert und wurde am 08.09.2026 geloescht.
    #
    # Achtung bei Quell- oder Archivbildern: was hier nicht als Hero erkannt wird,
    # schrumpft die Pipeline auf 1600 px — und zwar in der Datei selbst. Genau so
    # ist grafitiwand_HQ.jpg (das Quellbild von hero-gebucht.jpg) unter die
    # Aufloesung seines eigenen Derivats gerutscht, bevor es am 06.09.2026
    # geloescht wurde. Ein neues Archivbild gehoert also entweder in dieses
    # Muster oder gar nicht nach assets/.
    if ($name -match '^hero-') { return $HeroMaxWidth }
    return $DefaultMaxWidth
}

function Resize-Jpeg($path, $maxWidth, $maxBytesPerMp) {
    $img = [System.Drawing.Image]::FromFile($path)
    try {
        $w = $img.Width
        $h = $img.Height

        # Zwei Gruende, eine Datei anzufassen:
        #   a) sie ist breiter als erlaubt  -> verkleinern
        #   b) sie ist zu schwer fuer ihre Flaeche -> nur neu kodieren
        #
        # (b) fehlte frueher. Dadurch lief hero-silvester.jpg mit 1920x1080 und
        # 670 KB als "already <= 2400px" durch, waehrend hero-landing.jpg mit
        # 2400x1552 nur 284 KB braucht. Die Schwelle ist grosszuegig gewaehlt:
        # sie soll Ausreisser fangen, nicht jedes Foto neu durch den Encoder
        # jagen. Fotos mit viel Rauschen oder Struktur duerfen schwerer sein.
        $bytes = (Get-Item $path).Length
        $megapixel = ($w * $h) / 1MB
        $proMp = if ($megapixel -gt 0) { $bytes / $megapixel } else { 0 }
        $zuBreit  = $w -gt $maxWidth
        $zuSchwer = $proMp -gt $maxBytesPerMp

        if (-not $zuBreit -and -not $zuSchwer) {
            return @{ changed = $false; grund = ''; oldW = $w; oldH = $h; newW = $w; newH = $h }
        }
        $grund = if ($zuBreit) { 'breit' } else { 'schwer' }

        $newW = if ($zuBreit) { $maxWidth } else { $w }
        $newH = if ($zuBreit) { [int]([math]::Round($h * $maxWidth / $w)) } else { $h }

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

                # Nur uebernehmen, wenn es sich lohnt. Ein reiner Neukodier-Lauf
                # (Breite passt, nur das Gewicht war auffaellig) kann sonst
                # Qualitaet kosten, ohne nennenswert Bytes zu sparen - und beim
                # naechsten Lauf wieder, und wieder.
                $neu = (Get-Item $tmp).Length
                $alt = (Get-Item $path).Length
                if (-not $zuBreit -and $neu -gt ($alt * 0.9)) {
                    Remove-Item $tmp -Force
                    return @{ changed = $false; grund = 'kein Gewinn'
                              oldW = $w; oldH = $h; newW = $w; newH = $h }
                }
                Move-Item -Force $tmp $path
            }
        } finally {
            $bmp.Dispose()
        }
        return @{ changed = $true; grund = $grund; oldW = $w; oldH = $h; newW = $newW; newH = $newH }
    } finally {
        if ($img) { $img.Dispose() }
    }
}

# ACHTUNG, in PowerShell 5.1 nachgemessen: sobald [CmdletBinding()] gesetzt
# ist, ist $PSScriptRoot in den Vorgabewerten des param()-Blocks LEER. Der
# Vorgabewert fiel dadurch auf einen Pfad ohne Laufwerk zurueck und loeste
# zum Laufwerksstamm auf (C:\assets statt <repo>\assets); das Skript brach mit
# "Pfad kann nicht gefunden werden" ab, sobald man es ohne expliziten Pfad
# aufrief. Deshalb steht der Vorgabewert jetzt hier im Rumpf, wo
# $PSScriptRoot gefuellt ist.
if (-not $AssetsDir) { $AssetsDir = Join-Path $PSScriptRoot '..\assets' }
$resolved = Resolve-Path $AssetsDir -ErrorAction Stop
$totalBefore = 0
$totalAfter  = 0
$changedCount = 0
$skippedCount = 0
$errorCount = 0
$unreferenced = 0

Get-ChildItem -Path $resolved -File |
    Where-Object { $_.Extension -in '.jpg', '.jpeg', '.JPG', '.JPEG' } |
    Sort-Object Name | ForEach-Object {
    $f = $_
    $maxW = Get-MaxWidth $f.Name
    $sizeBefore = $f.Length
    $totalBefore += $sizeBefore

    if (-not $referenziert.ContainsKey($f.Name)) {
        $unreferenced++
        $totalAfter += $sizeBefore
        Write-Host ("frei  {0,-32} von keiner Seite referenziert - nicht angefasst" -f $f.Name) -ForegroundColor Yellow
        return
    }

    try {
        $r = Resize-Jpeg $f.FullName $maxW $MaxBytesPerMegapixel
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
            Write-Host ("$verb  {0,-32} {1}x{2} -> {3}x{4}   {5,5} -> {6,5} KB  ({7})" -f `
                $f.Name, $r.oldW, $r.oldH, $r.newW, $r.newH, $kbBefore, $kbAfter, $r.grund)
        } else {
            $skippedCount++
            $totalAfter += $sizeBefore
            $kb = [math]::Round($sizeBefore / 1024)
            Write-Host ("skip  {0,-32} {1}x{2}              already <= {3}px, {4} KB" -f `
                $f.Name, $r.oldW, $r.oldH, $maxW, $kb) -ForegroundColor DarkGray
        }
    } catch {
        # Frueher endete das Skript trotz Fehlern mit Exit 0, ein Aufrufer
        # hielt den Lauf also fuer gelungen. Jetzt wird gezaehlt und unten
        # mit 1 beendet.
        $errorCount++
        $totalAfter += $sizeBefore
        Write-Host ("ERR   {0,-32} {1}" -f $f.Name, $_.Exception.Message) -ForegroundColor Red
    }
}

$mbBefore = [math]::Round($totalBefore / 1MB, 2)
$mbAfter  = [math]::Round($totalAfter  / 1MB, 2)
$saved    = $totalBefore - $totalAfter
$mbSaved  = [math]::Round($saved / 1MB, 2)
$pct      = if ($totalBefore -gt 0) { [math]::Round(100 * $saved / $totalBefore, 1) } else { 0 }

Write-Host ""
Write-Host ("Resized: {0}, skipped: {1}, unreferenziert: {2}, Fehler: {3}" -f `
    $changedCount, $skippedCount, $unreferenced, $errorCount)
Write-Host ("Total: {0} MB -> {1} MB  (saved {2} MB, {3}%)" -f $mbBefore, $mbAfter, $mbSaved, $pct)
if ($DryRun) { Write-Host "(dry run -- no files were modified)" -ForegroundColor Yellow }

if ($errorCount -gt 0) {
    Write-Host ("{0} Datei(en) konnten nicht verarbeitet werden." -f $errorCount) -ForegroundColor Red
    exit 1
}
