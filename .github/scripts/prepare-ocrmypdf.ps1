[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$PythonVersion,
    [Parameter(Mandatory = $true)][string]$PythonDownloadUrl,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$PythonSha256,
    [Parameter(Mandatory = $true)][string]$OcrMyPdfVersion,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$OcrMyPdfWheelSha256,
    [Parameter(Mandatory = $true)][string]$NumPyVersion,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$NumPyWheelSha256,
    [Parameter(Mandatory = $true)][string]$DependencyLockPath,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$DependencyLockSha256,
    [Parameter(Mandatory = $true)][string]$LauncherSource
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$core = Join-Path $PSScriptRoot 'prepare-ocrmypdf-core.ps1'
$aux = Join-Path $PSScriptRoot 'prepare-ocr-aux.ps1'
foreach ($requiredScript in @($core, $aux)) {
    if (-not (Test-Path -LiteralPath $requiredScript -PathType Leaf)) {
        throw "Required PDF_Tunner OCR preparation script is missing: $requiredScript"
    }
}

$coreParams = @{}
foreach ($key in $PSBoundParameters.Keys) {
    $coreParams[$key] = $PSBoundParameters[$key]
}

& $core @coreParams

$portable = (Resolve-Path -LiteralPath $PortableRoot).Path
$diagnosticRoot = Join-Path $portable 'data\logs'
$diagnosticLog = Join-Path $diagnosticRoot 'ocr-aux-diagnostic.log'
New-Item -ItemType Directory -Force -Path $diagnosticRoot | Out-Null

@(
    'STATUS=starting',
    'PHASE=invoke-prepare-ocr-aux',
    "UTC=$([DateTime]::UtcNow.ToString('o'))",
    "CORE=$core",
    "AUX=$aux",
    "PORTABLE_ROOT=$portable"
) | Set-Content -LiteralPath $diagnosticLog -Encoding utf8

try {
    & $aux -PortableRoot $PortableRoot
    @(
        'STATUS=success',
        'PHASE=invoke-prepare-ocr-aux',
        "UTC=$([DateTime]::UtcNow.ToString('o'))",
        "AUX=$aux"
    ) | Set-Content -LiteralPath $diagnosticLog -Encoding utf8
}
catch {
    $errorRecord = $_
    $exceptionType = if ($null -ne $errorRecord.Exception) { $errorRecord.Exception.GetType().FullName } else { '' }
    $exceptionMessage = if ($null -ne $errorRecord.Exception) { $errorRecord.Exception.Message } else { '' }
    $scriptName = if ($null -ne $errorRecord.InvocationInfo) { $errorRecord.InvocationInfo.ScriptName } else { '' }
    $scriptLine = if ($null -ne $errorRecord.InvocationInfo) { $errorRecord.InvocationInfo.ScriptLineNumber } else { '' }
    $offsetInLine = if ($null -ne $errorRecord.InvocationInfo) { $errorRecord.InvocationInfo.OffsetInLine } else { '' }
    $lineText = if ($null -ne $errorRecord.InvocationInfo) { $errorRecord.InvocationInfo.Line } else { '' }
    $positionMessage = if ($null -ne $errorRecord.InvocationInfo) { $errorRecord.InvocationInfo.PositionMessage } else { '' }
    $stackTrace = if ($null -ne $errorRecord.ScriptStackTrace) { $errorRecord.ScriptStackTrace } else { '' }
    $recordText = ($errorRecord | Format-List * -Force | Out-String -Width 4096).TrimEnd()

    @(
        'STATUS=failure',
        'PHASE=invoke-prepare-ocr-aux',
        "UTC=$([DateTime]::UtcNow.ToString('o'))",
        "AUX=$aux",
        "EXCEPTION_TYPE=$exceptionType",
        "EXCEPTION_MESSAGE=$exceptionMessage",
        "FULLY_QUALIFIED_ERROR_ID=$($errorRecord.FullyQualifiedErrorId)",
        "CATEGORY=$($errorRecord.CategoryInfo.Category)",
        "SCRIPT_NAME=$scriptName",
        "SCRIPT_LINE=$scriptLine",
        "OFFSET_IN_LINE=$offsetInLine",
        '--- LINE ---',
        $lineText,
        '--- POSITION ---',
        $positionMessage,
        '--- SCRIPT STACK TRACE ---',
        $stackTrace,
        '--- ERROR RECORD ---',
        $recordText
    ) | Set-Content -LiteralPath $diagnosticLog -Encoding utf8

    Write-Host "OCR auxiliary diagnostic captured at $diagnosticLog"
    throw
}