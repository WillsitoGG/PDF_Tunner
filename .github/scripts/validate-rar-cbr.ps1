[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$BackendBaseUrl,
    [Parameter(Mandatory = $true)][string]$ProbeExecutable
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-Crc32 {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)

    [uint32]$crc = [uint32]::MaxValue
    foreach ($value in $Bytes) {
        $crc = $crc -bxor [uint32]$value
        for ($bit = 0; $bit -lt 8; $bit++) {
            if (($crc -band 1) -ne 0) {
                $crc = [uint32]($crc -shr 1) -bxor [uint32]3988292384 # 0xEDB88320
            }
            else {
                $crc = [uint32]($crc -shr 1)
            }
        }
    }
    return [uint32]($crc -bxor [uint32]::MaxValue)
}

function Write-Le16 {
    param(
        [Parameter(Mandatory = $true)][System.IO.Stream]$Stream,
        [Parameter(Mandatory = $true)][uint16]$Value
    )
    $bytes = [BitConverter]::GetBytes($Value)
    $Stream.Write($bytes, 0, $bytes.Length)
}

function Write-Le32 {
    param(
        [Parameter(Mandatory = $true)][System.IO.Stream]$Stream,
        [Parameter(Mandatory = $true)][uint32]$Value
    )
    $bytes = [BitConverter]::GetBytes($Value)
    $Stream.Write($bytes, 0, $bytes.Length)
}

function New-Rar3Header {
    param(
        [Parameter(Mandatory = $true)][byte]$Type,
        [Parameter(Mandatory = $true)][uint16]$Flags,
        [Parameter(Mandatory = $true)][byte[]]$Body
    )

    $stream = [System.IO.MemoryStream]::new()
    try {
        Write-Le16 -Stream $stream -Value 0
        $stream.WriteByte($Type)
        Write-Le16 -Stream $stream -Value $Flags
        Write-Le16 -Stream $stream -Value ([uint16](7 + $Body.Length))
        $stream.Write($Body, 0, $Body.Length)
        [byte[]]$header = $stream.ToArray()
        [byte[]]$covered = $header[2..($header.Length - 1)]
        [uint16]$headCrc = [uint16]((Get-Crc32 -Bytes $covered) -band 0xffff)
        $header[0] = [byte]($headCrc -band 0xff)
        $header[1] = [byte](($headCrc -shr 8) -band 0xff)
        return $header
    }
    finally {
        $stream.Dispose()
    }
}

function New-DeterministicRar3Cbr {
    param([Parameter(Mandatory = $true)][string]$Path)

    # Valid 2x2 RGB PNG. Keeping the bytes fixed makes the complete RAR3 fixture
    # deterministic and removes any download/network dependency from this gate.
    [byte[]]$png = [Convert]::FromBase64String(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEklEQVR42mP4z8DAAMIM/4EAAB/uBfvxq7p3AAAAAElFTkSuQmCC')
    if ($png.Length -ne 75) { throw "Unexpected deterministic PNG size: $($png.Length)." }
    [uint32]$pngCrc = Get-Crc32 -Bytes $png
    if ($pngCrc -ne [uint32]3716711989) { throw ('Unexpected deterministic PNG CRC32: 0x{0:X8}.' -f $pngCrc) }

    [byte[]]$name = [System.Text.Encoding]::ASCII.GetBytes('page_001.png')

    $mainBody = [byte[]]::new(6)
    [byte[]]$mainHeader = New-Rar3Header -Type 0x73 -Flags 0 -Body $mainBody

    $fileBodyStream = [System.IO.MemoryStream]::new()
    try {
        # RAR3 FILE header, method 0x30 = store. LONG_BLOCK makes the first
        # four body bytes the packed-data size that follows the header.
        Write-Le32 -Stream $fileBodyStream -Value ([uint32]$png.Length) # packSize
        Write-Le32 -Stream $fileBodyStream -Value ([uint32]$png.Length) # unpSize
        $fileBodyStream.WriteByte(0)                                    # hostOS
        Write-Le32 -Stream $fileBodyStream -Value $pngCrc              # fileCRC
        Write-Le32 -Stream $fileBodyStream -Value 0                    # fileTime
        $fileBodyStream.WriteByte(20)                                  # unpVersion
        $fileBodyStream.WriteByte(0x30)                                # unpMethod: store
        Write-Le16 -Stream $fileBodyStream -Value ([uint16]$name.Length)
        Write-Le32 -Stream $fileBodyStream -Value 0x20                 # normal file attr
        $fileBodyStream.Write($name, 0, $name.Length)
        [byte[]]$fileBody = $fileBodyStream.ToArray()
        [byte[]]$fileHeader = New-Rar3Header -Type 0x74 -Flags 0x8000 -Body $fileBody

        # Canonical RAR3 ENDARC header: CRC 0x3dc4, type 0x7b, flags 0x4000,
        # header size 7. This exact framing is accepted by embedded junrar.
        [byte[]]$endHeader = @(0xC4, 0x3D, 0x7B, 0x00, 0x40, 0x07, 0x00)
        [byte[]]$marker = @(0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00)

        $archive = [System.IO.MemoryStream]::new()
        try {
            $archive.Write($marker, 0, $marker.Length)
            $archive.Write($mainHeader, 0, $mainHeader.Length)
            $archive.Write($fileHeader, 0, $fileHeader.Length)
            $archive.Write($png, 0, $png.Length)
            $archive.Write($endHeader, 0, $endHeader.Length)
            [byte[]]$rar = $archive.ToArray()
            if ($rar.Length -ne 146) { throw "Unexpected deterministic RAR3 fixture size: $($rar.Length)." }
            [System.IO.File]::WriteAllBytes($Path, $rar)
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        $fileBodyStream.Dispose()
    }

    $sha = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    $expectedSha = '136cda2e5fd96e06a9d894b88c24c8c43e56c09c39bb17e0fc2e7c44c9b4368c'
    if ($sha -ne $expectedSha) {
        throw "Deterministic RAR3 fixture SHA-256 mismatch: expected $expectedSha, got $sha."
    }
}

function Invoke-StirlingFormToFile {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][hashtable]$Form,
        [Parameter(Mandatory = $true)][string]$OutFile
    )

    Invoke-WebRequest -Uri $Uri -Method Post -Form $Form -OutFile $OutFile -UseBasicParsing
    if (-not (Test-Path -LiteralPath $OutFile -PathType Leaf)) {
        throw "Stirling route returned no output file: $Uri"
    }
}

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$probeSource = (Resolve-Path -LiteralPath $ProbeExecutable).Path
$rarDir = Join-Path $portable 'tools/rar'
$rarExe = Join-Path $rarDir 'rar.exe'
$tempRoot = Join-Path $portable 'data/tmp/rar-cbr-validation'
$probeLog = Join-Path $portable 'data/tmp/rar-cbr-probe.log'
$fixture = Join-Path $tempRoot 'deterministic-rar3.cbr'
$pdf = Join-Path $tempRoot 'from-cbr.pdf'
$probeCbr = Join-Path $tempRoot 'probe-output.cbr'
$qpdf = Join-Path $portable 'tools/qpdf/bin/qpdf.exe'

Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $tempRoot, $rarDir | Out-Null
Remove-Item -LiteralPath $rarExe, $probeLog -Force -ErrorAction SilentlyContinue

try {
    # CBR -> PDF must be genuinely portable and must not rely on any RAR encoder.
    New-DeterministicRar3Cbr -Path $fixture
    if (Test-Path -LiteralPath $rarExe) {
        throw 'RAR encoder unexpectedly exists before the CBR->PDF portability test.'
    }

    Invoke-StirlingFormToFile `
        -Uri ($BackendBaseUrl.TrimEnd('/') + '/api/v1/convert/cbr/pdf') `
        -Form @{ fileInput = Get-Item -LiteralPath $fixture; optimizeForEbook = 'false' } `
        -OutFile $pdf

    [byte[]]$pdfBytes = [System.IO.File]::ReadAllBytes($pdf)
    if ($pdfBytes.Length -lt 5 -or [System.Text.Encoding]::ASCII.GetString($pdfBytes, 0, 5) -ne '%PDF-') {
        throw 'CBR->PDF did not return a PDF payload.'
    }
    if (-not (Test-Path -LiteralPath $qpdf -PathType Leaf)) {
        throw "Packaged qpdf is unavailable for CBR->PDF verification: $qpdf"
    }
    & $qpdf --check $pdf | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Packaged qpdf rejected the real CBR->PDF output with exit code $LASTEXITCODE."
    }
    Write-Host 'PASS: deterministic real RAR3/CBR converted through embedded junrar to a valid PDF with no rar.exe present.'

    # PDF -> CBR is conditional. The CI-only probe validates package-first
    # resolution and Stirling's exact real-RAR CLI contract. It is deliberately
    # not an encoder and its marker output must never be accepted as a real CBR.
    Copy-Item -LiteralPath $probeSource -Destination $rarExe -Force
    Remove-Item -LiteralPath $probeLog -Force -ErrorAction SilentlyContinue
    Invoke-StirlingFormToFile `
        -Uri ($BackendBaseUrl.TrimEnd('/') + '/api/v1/convert/pdf/cbr') `
        -Form @{ fileInput = Get-Item -LiteralPath $pdf; dpi = '72' } `
        -OutFile $probeCbr

    $probeMarker = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($probeCbr))
    if ($probeMarker -ne "PDF_TUNNER_RAR_PROBE_ONLY`n") {
        throw 'PDF->CBR response did not come from the CI-only RAR probe.'
    }
    if (-not (Test-Path -LiteralPath $probeLog -PathType Leaf)) {
        throw 'RAR probe was not invoked by the Stirling backend.'
    }

    $probeLines = Get-Content -LiteralPath $probeLog
    $expectedExe = (Resolve-Path -LiteralPath $rarExe).Path
    $actualExe = (($probeLines | Where-Object { $_ -like 'EXE=*' } | Select-Object -First 1) -replace '^EXE=', '')
    if (-not $actualExe -or -not [System.IO.Path]::GetFullPath($actualExe).Equals($expectedExe, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "RAR probe resolved outside package-first tools/rar: expected $expectedExe, got $actualExe."
    }
    foreach ($expected in @('ARG_0=a', 'ARG_1=-m5', 'ARG_2=-ep1')) {
        if ($probeLines -notcontains $expected) {
            throw "RAR probe did not receive expected argument: $expected"
        }
    }
    $outputArg = (($probeLines | Where-Object { $_ -like 'ARG_3=*' } | Select-Object -First 1) -replace '^ARG_3=', '')
    if (-not $outputArg -or [System.IO.Path]::GetExtension($outputArg) -ine '.cbr') {
        throw "RAR probe output argument is not .cbr: $outputArg"
    }
    $pageArgs = @($probeLines | Where-Object { $_ -match '^ARG_[4-9][0-9]*=' })
    if ($pageArgs.Count -lt 1 -or @($pageArgs | Where-Object { $_ -notmatch '(?i)\.png$' }).Count -gt 0) {
        throw 'RAR probe did not receive one or more rendered PNG page inputs.'
    }
    Write-Host 'PASS: PDF->CBR resolved package-local tools/rar/rar.exe and invoked exactly: rar a -m5 -ep1 <output.cbr> <page PNGs>.'

    # Remove the probe and prove Stirling does not silently fake RAR/CBR output
    # when a licensed/user-supplied encoder is absent.
    Remove-Item -LiteralPath $rarExe -Force
    $noRarResponse = Invoke-WebRequest `
        -Uri ($BackendBaseUrl.TrimEnd('/') + '/api/v1/convert/pdf/cbr') `
        -Method Post `
        -Form @{ fileInput = Get-Item -LiteralPath $pdf; dpi = '72' } `
        -SkipHttpErrorCheck `
        -UseBasicParsing
    if ($noRarResponse.StatusCode -lt 400) {
        throw "PDF->CBR unexpectedly succeeded without rar.exe (HTTP $($noRarResponse.StatusCode))."
    }
    Write-Host "PASS: PDF->CBR fails explicitly without rar.exe (HTTP $($noRarResponse.StatusCode)); no ZIP-as-CBR fallback exists."
}
finally {
    Remove-Item -LiteralPath $rarExe, $probeLog -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$leakedRar = @(Get-ChildItem -LiteralPath $portable -Recurse -Force -File -Filter 'rar.exe' -ErrorAction SilentlyContinue)
if ($leakedRar.Count -gt 0) {
    $leakedRar | Select-Object FullName, Length | Format-Table -AutoSize
    throw 'CI-only rar.exe probe leaked into the portable package.'
}
Write-Host 'PASS: RAR/CBR validation completed and no rar.exe is bundled in PDF_Tunner.'
