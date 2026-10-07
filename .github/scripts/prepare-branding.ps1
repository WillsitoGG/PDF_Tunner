[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Add-Type -AssemblyName System.Drawing

function New-PdfTunnerIconBitmap {
    param(
        [Parameter(Mandatory = $true)][int]$Size,
        [Parameter(Mandatory = $true)][System.Drawing.Color]$Foreground
    )

    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $scale = $Size / 64.0
    $pen = [System.Drawing.Pen]::new($Foreground, [single](4.0 * $scale))
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $brush = [System.Drawing.SolidBrush]::new($Foreground)
    $font = $null
    $format = [System.Drawing.StringFormat]::new()
    try {
        $outline = [System.Drawing.PointF[]]@(
            [System.Drawing.PointF]::new([single](14*$scale), [single](6*$scale)),
            [System.Drawing.PointF]::new([single](39*$scale), [single](6*$scale)),
            [System.Drawing.PointF]::new([single](50*$scale), [single](17*$scale)),
            [System.Drawing.PointF]::new([single](50*$scale), [single](58*$scale)),
            [System.Drawing.PointF]::new([single](14*$scale), [single](58*$scale)),
            [System.Drawing.PointF]::new([single](14*$scale), [single](6*$scale))
        )
        $graphics.DrawLines($pen, $outline)
        $fold = [System.Drawing.PointF[]]@(
            [System.Drawing.PointF]::new([single](39*$scale), [single](6*$scale)),
            [System.Drawing.PointF]::new([single](39*$scale), [single](18*$scale)),
            [System.Drawing.PointF]::new([single](50*$scale), [single](18*$scale))
        )
        $graphics.DrawLines($pen, $fold)

        $font = [System.Drawing.Font]::new('Segoe UI', [single](16*$scale), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $format.Alignment = [System.Drawing.StringAlignment]::Center
        $format.LineAlignment = [System.Drawing.StringAlignment]::Center
        $textRect = [System.Drawing.RectangleF]::new([single](14*$scale), [single](25*$scale), [single](36*$scale), [single](25*$scale))
        $graphics.DrawString('PT', $font, $brush, $textRect, $format)
        return $bitmap
    }
    finally {
        if ($font) { $font.Dispose() }
        $format.Dispose()
        $brush.Dispose()
        $pen.Dispose()
        $graphics.Dispose()
    }
}

function Write-PngCompressedIco {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $png = [System.IO.MemoryStream]::new()
    try {
        $Bitmap.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
        $payload = $png.ToArray()
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $writer = [System.IO.BinaryWriter]::new($stream)
        try {
            $writer.Write([UInt16]0)       # reserved
            $writer.Write([UInt16]1)       # icon
            $writer.Write([UInt16]1)       # one image
            $writer.Write([Byte]0)         # 256 px
            $writer.Write([Byte]0)         # 256 px
            $writer.Write([Byte]0)         # palette
            $writer.Write([Byte]0)
            $writer.Write([UInt16]1)       # planes
            $writer.Write([UInt16]32)      # bpp
            $writer.Write([UInt32]$payload.Length)
            $writer.Write([UInt32]22)      # ICONDIR + one ICONDIRENTRY
            $writer.Write($payload)
        }
        finally {
            $writer.Dispose()
            $stream.Dispose()
        }
    }
    finally {
        $png.Dispose()
    }
}

function Write-WordmarkPng {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bitmap = [System.Drawing.Bitmap]::new(620, 128, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $font = [System.Drawing.Font]::new('Segoe UI', 76, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    try {
        $graphics.DrawString('PDF_Tunner', $font, $brush, [System.Drawing.PointF]::new(0, 18))
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $brush.Dispose()
        $font.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

$repoRoot = (Resolve-Path '.').Path
$icoPath = Join-Path $repoRoot 'frontend/editor/src-tauri/icons/pdf-tunner.ico'
$signaturePath = Join-Path $repoRoot 'app/core/src/main/resources/static/images/signature.png'
$signingWordmarkPath = Join-Path $repoRoot 'app/core/src/main/resources/static/images/stirling-logo-white.png'

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $icoPath) | Out-Null

$icon = New-PdfTunnerIconBitmap -Size 256 -Foreground ([System.Drawing.Color]::FromArgb(17,17,17))
try {
    Write-PngCompressedIco -Bitmap $icon -Path $icoPath
}
finally {
    $icon.Dispose()
}

$signature = New-PdfTunnerIconBitmap -Size 512 -Foreground ([System.Drawing.Color]::FromArgb(17,17,17))
try {
    $signature.Save($signaturePath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $signature.Dispose()
}

Write-WordmarkPng -Path $signingWordmarkPath

$icoBytes = [System.IO.File]::ReadAllBytes($icoPath)
if ($icoBytes.Length -lt 1024 -or $icoBytes[0] -ne 0 -or $icoBytes[1] -ne 0 -or $icoBytes[2] -ne 1 -or $icoBytes[3] -ne 0) {
    throw "Generated PDF_Tunner icon is not a valid ICO resource: $icoPath"
}
foreach ($asset in @($signaturePath, $signingWordmarkPath)) {
    $bytes = [System.IO.File]::ReadAllBytes($asset)
    if ($bytes.Length -lt 512 -or $bytes[0] -ne 0x89 -or $bytes[1] -ne 0x50 -or $bytes[2] -ne 0x4e -or $bytes[3] -ne 0x47) {
        throw "Generated PDF_Tunner branding asset is not a valid PNG: $asset"
    }
}

Write-Host "PDF_Tunner ICO SHA-256: $((Get-FileHash -LiteralPath $icoPath -Algorithm SHA256).Hash.ToLowerInvariant())"
Write-Host "PDF_Tunner signature PNG SHA-256: $((Get-FileHash -LiteralPath $signaturePath -Algorithm SHA256).Hash.ToLowerInvariant())"
Write-Host "PDF_Tunner signing wordmark PNG SHA-256: $((Get-FileHash -LiteralPath $signingWordmarkPath -Algorithm SHA256).Hash.ToLowerInvariant())"
Write-Host 'PASS: deterministic PDF_Tunner binary branding assets were generated before the official desktop build.'
