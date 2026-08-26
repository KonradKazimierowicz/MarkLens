<# Creates the neutral multi-size app/marklens.ico icon. #>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path $PSScriptRoot -Parent
$outputPath = Join-Path $repoRoot 'app\marklens.ico'
$size = 256
$bitmap = New-Object Drawing.Bitmap($size, $size, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$shape = New-Object Drawing.Drawing2D.GraphicsPath
$background = New-Object Drawing.Drawing2D.LinearGradientBrush(
    (New-Object Drawing.Point(20, 20)), (New-Object Drawing.Point(236, 236)),
    [Drawing.Color]::FromArgb(255, 37, 99, 235), [Drawing.Color]::FromArgb(255, 14, 165, 164)
)
$markBrush = New-Object Drawing.SolidBrush([Drawing.Color]::White)
$font = New-Object Drawing.Font('Segoe UI', 92, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
$format = New-Object Drawing.StringFormat
$streams = @()
$writer = $null
$file = $null

try {
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.Clear([Drawing.Color]::Transparent)
    $margin = 14; $radius = 46; $diameter = $radius * 2; $edge = $size - (2 * $margin)
    $shape.AddArc($margin, $margin, $diameter, $diameter, 180, 90)
    $shape.AddArc($margin + $edge - $diameter, $margin, $diameter, $diameter, 270, 90)
    $shape.AddArc($margin + $edge - $diameter, $margin + $edge - $diameter, $diameter, $diameter, 0, 90)
    $shape.AddArc($margin, $margin + $edge - $diameter, $diameter, $diameter, 90, 90)
    $shape.CloseFigure()
    $graphics.FillPath($background, $shape)
    $format.Alignment = [Drawing.StringAlignment]::Center
    $format.LineAlignment = [Drawing.StringAlignment]::Center
    $graphics.DrawString('M', $font, $markBrush, (New-Object Drawing.PointF(128, 122)), $format)
    $pen = New-Object Drawing.Pen([Drawing.Color]::White, 12)
    try {
        $pen.StartCap = [Drawing.Drawing2D.LineCap]::Round; $pen.EndCap = [Drawing.Drawing2D.LineCap]::Round
        $graphics.DrawLine($pen, 128, 153, 128, 203)
        $graphics.DrawLine($pen, 103, 179, 128, 204)
        $graphics.DrawLine($pen, 153, 179, 128, 204)
    } finally { $pen.Dispose() }

    $sizes = @(256, 48, 32, 16)
    $blobs = New-Object 'Collections.Generic.List[byte[]]'
    foreach ($iconSize in $sizes) {
        $stream = New-Object IO.MemoryStream; $streams += $stream
        if ($iconSize -eq 256) { $bitmap.Save($stream, [Drawing.Imaging.ImageFormat]::Png) }
        else {
            $small = New-Object Drawing.Bitmap($iconSize, $iconSize, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $smallGraphics = [Drawing.Graphics]::FromImage($small)
            try { $smallGraphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic; $smallGraphics.DrawImage($bitmap, 0, 0, $iconSize, $iconSize); $small.Save($stream, [Drawing.Imaging.ImageFormat]::Png) }
            finally { $smallGraphics.Dispose(); $small.Dispose() }
        }
        $blobs.Add($stream.ToArray())
    }
    $file = New-Object IO.FileStream($outputPath, [IO.FileMode]::Create)
    $writer = New-Object IO.BinaryWriter($file)
    $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
    $offset = 6 + (16 * $sizes.Count)
    for ($index = 0; $index -lt $sizes.Count; $index += 1) {
        $dimension = if ($sizes[$index] -eq 256) { [byte]0 } else { [byte]$sizes[$index] }
        $writer.Write($dimension); $writer.Write($dimension); $writer.Write([byte]0); $writer.Write([byte]0)
        $writer.Write([uint16]1); $writer.Write([uint16]32); $writer.Write([uint32]$blobs[$index].Length); $writer.Write([uint32]$offset)
        $offset += $blobs[$index].Length
    }
    foreach ($blob in $blobs) { $writer.Write($blob) }
    $writer.Flush()
}
finally {
    if ($writer) { $writer.Dispose() }; if ($file) { $file.Dispose() }; foreach ($stream in $streams) { $stream.Dispose() }
    $format.Dispose(); $font.Dispose(); $markBrush.Dispose(); $background.Dispose(); $shape.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
}
Write-Output $outputPath
