Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
function Write-Mark($path, [int]$size, [bool]$transparent = $false) {
    $bitmap = New-Object System.Drawing.Bitmap($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = 'AntiAlias'
    $graphics.Clear($(if ($transparent) { [System.Drawing.Color]::Transparent } else { [System.Drawing.ColorTranslator]::FromHtml('#00695C') }))
    $graphics.ScaleTransform($size / 1024.0, $size / 1024.0)
    $sun = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#FFD166'))
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 38)
    $pen.StartCap = 'Round'
    $pen.EndCap = 'Round'
    $pen.LineJoin = 'Round'
    $graphics.FillEllipse($sun, 390, 245, 244, 244)
    $graphics.DrawArc($pen, 474, 440, 100, 100, 180, 270)
    $graphics.DrawLine($pen, 524, 540, 512, 567)
    $points = [System.Drawing.PointF[]]@([System.Drawing.PointF]::new(512, 567), [System.Drawing.PointF]::new(270, 710), [System.Drawing.PointF]::new(754, 710), [System.Drawing.PointF]::new(512, 567))
    $graphics.DrawLines($pen, $points)
    $directory = Split-Path $path -Parent
    New-Item -ItemType Directory -Force $directory | Out-Null
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $pen.Dispose(); $sun.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
}
# Preserve the platform catalogs and replace each declared icon at its original size.
$icons = @('android/app/src/main/res/mipmap-*/ic_launcher.png', 'ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png', 'macos/Runner/Assets.xcassets/AppIcon.appiconset/*.png', 'web/icons/*.png', 'web/favicon.png')
foreach ($pattern in $icons) {
    foreach ($file in Get-ChildItem (Join-Path $root $pattern)) {
        $existing = [System.Drawing.Image]::FromFile($file.FullName)
        $size = $existing.Width
        $existing.Dispose()
        Write-Mark $file.FullName $size
    }
}
Write-Mark (Join-Path $root 'assets/brand/icon.png') 1024
Write-Mark (Join-Path $root 'assets/brand/icon-256.png') 256
$png = [System.IO.File]::ReadAllBytes((Join-Path $root 'assets/brand/icon-256.png'))
$stream = [System.IO.File]::Create((Join-Path $root 'windows/runner/resources/app_icon.ico'))
$writer = [System.IO.BinaryWriter]::new($stream)
$writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]1)
$writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0)
$writer.Write([uint16]1); $writer.Write([uint16]32)
$writer.Write([uint32]$png.Length); $writer.Write([uint32]22); $writer.Write($png)
$writer.Dispose()
foreach ($scale in 1..3) {
    $suffix = if ($scale -eq 1) { '' } else { "@${scale}x" }
    Write-Mark (Join-Path $root "ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage$suffix.png") (192 * $scale) $true
}
