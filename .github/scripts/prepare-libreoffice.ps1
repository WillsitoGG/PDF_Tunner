[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$LibreOfficeVersion,
    [Parameter(Mandatory = $true)][string]$LibreOfficeMsiUrl,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$LibreOfficeMsiSha256,
    [Parameter(Mandatory = $true)][string]$LauncherSource
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$core = Join-Path $PSScriptRoot 'prepare-libreoffice-core.ps1'
$fonts = Join-Path $PSScriptRoot 'prepare-conversion-fonts.ps1'
foreach ($requiredScript in @($core, $fonts)) {
    if (-not (Test-Path -LiteralPath $requiredScript -PathType Leaf)) {
        throw "Required PDF_Tunner LibreOffice preparation script is missing: $requiredScript"
    }
}

$coreParams = @{}
foreach ($key in $PSBoundParameters.Keys) { $coreParams[$key] = $PSBoundParameters[$key] }
& $core @coreParams

$diagnosticLog = Join-Path $PortableRoot 'data\logs\conversion-fonts-diagnostic.log'
try {
    & $fonts -PortableRoot $PortableRoot
}
catch {
    $errorRecord = $_
    $invocation = $errorRecord.InvocationInfo
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $diagnosticLog) | Out-Null
    $detail = @(
        "UTC=$([DateTime]::UtcNow.ToString('o'))",
        "EXCEPTION_TYPE=$($errorRecord.Exception.GetType().FullName)",
        "MESSAGE=$($errorRecord.Exception.Message)",
        "FULLY_QUALIFIED_ERROR_ID=$($errorRecord.FullyQualifiedErrorId)",
        "CATEGORY=$($errorRecord.CategoryInfo)",
        "SCRIPT_NAME=$($invocation.ScriptName)",
        "SCRIPT_LINE=$($invocation.ScriptLineNumber)",
        "OFFSET_IN_LINE=$($invocation.OffsetInLine)",
        "SOURCE_LINE=$($invocation.Line)",
        'POSITION_MESSAGE_BEGIN',
        [string]$invocation.PositionMessage,
        'POSITION_MESSAGE_END',
        'SCRIPT_STACK_TRACE_BEGIN',
        [string]$errorRecord.ScriptStackTrace,
        'SCRIPT_STACK_TRACE_END',
        'ERROR_RECORD_BEGIN',
        ($errorRecord | Format-List * -Force | Out-String),
        'ERROR_RECORD_END'
    )
    Set-Content -LiteralPath $diagnosticLog -Encoding utf8 -Value $detail
    Write-Host "Conversion-font preparation failed; retained bounded diagnostic at $diagnosticLog"
    throw
}
