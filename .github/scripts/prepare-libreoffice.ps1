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

$logRoot = Join-Path $PortableRoot 'data\logs'
$phaseLog = Join-Path $logRoot 'libreoffice-stage-phase.log'
$diagnosticLog = Join-Path $logRoot 'libreoffice-stage-diagnostic.log'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
Set-Content -LiteralPath $phaseLog -Encoding ascii -Value @(
    "UTC=$([DateTime]::UtcNow.ToString('o'))",
    'PHASE=WRAPPER_START',
    "CORE_BLOB_EXPECTED=ea79085578b488b7a3f7e4f4aa47d3decefad3da"
)

function Add-PhaseMarker {
    param([Parameter(Mandatory = $true)][string]$Phase)
    Add-Content -LiteralPath $phaseLog -Encoding ascii -Value "UTC=$([DateTime]::UtcNow.ToString('o'));PHASE=$Phase"
}

function Write-StageDiagnostic {
    param(
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("UTC=$([DateTime]::UtcNow.ToString('o'))")
    $lines.Add("PHASE=$Phase")
    $lines.Add("ERROR_RECORD=$($ErrorRecord.ToString())")
    if ($null -ne $ErrorRecord.Exception) {
        $lines.Add("EXCEPTION_TYPE=$($ErrorRecord.Exception.GetType().FullName)")
        $lines.Add("MESSAGE=$($ErrorRecord.Exception.Message)")
    }
    $lines.Add("FULLY_QUALIFIED_ERROR_ID=$($ErrorRecord.FullyQualifiedErrorId)")
    $lines.Add("CATEGORY=$($ErrorRecord.CategoryInfo)")
    if ($null -ne $ErrorRecord.InvocationInfo) {
        $lines.Add("SCRIPT_NAME=$($ErrorRecord.InvocationInfo.ScriptName)")
        $lines.Add("SCRIPT_LINE=$($ErrorRecord.InvocationInfo.ScriptLineNumber)")
        $lines.Add("OFFSET_IN_LINE=$($ErrorRecord.InvocationInfo.OffsetInLine)")
        $lines.Add("SOURCE_LINE=$($ErrorRecord.InvocationInfo.Line)")
        $lines.Add('POSITION_MESSAGE_BEGIN')
        $lines.Add([string]$ErrorRecord.InvocationInfo.PositionMessage)
        $lines.Add('POSITION_MESSAGE_END')
    }
    $lines.Add('SCRIPT_STACK_TRACE_BEGIN')
    $lines.Add([string]$ErrorRecord.ScriptStackTrace)
    $lines.Add('SCRIPT_STACK_TRACE_END')

    try {
        Set-Content -LiteralPath $diagnosticLog -Encoding utf8 -Value $lines
        Add-PhaseMarker -Phase ("$Phase`_DIAGNOSTIC_WRITTEN")
    }
    catch {
        # Keep at least a minimal marker even if rich error formatting itself fails.
        Add-Content -LiteralPath $phaseLog -Encoding ascii -Value "UTC=$([DateTime]::UtcNow.ToString('o'));PHASE=$Phase`_DIAGNOSTIC_WRITE_FAILED;ERROR=$($_.Exception.Message)"
    }
}

$coreParams = @{}
foreach ($key in $PSBoundParameters.Keys) { $coreParams[$key] = $PSBoundParameters[$key] }

Add-PhaseMarker -Phase 'CORE_START'
try {
    & $core @coreParams
}
catch {
    Write-StageDiagnostic -Phase 'CORE_FAILURE' -ErrorRecord $_
    throw
}
Add-PhaseMarker -Phase 'CORE_SUCCESS'

Add-PhaseMarker -Phase 'FONTS_START'
try {
    & $fonts -PortableRoot $PortableRoot
}
catch {
    Write-StageDiagnostic -Phase 'FONTS_FAILURE' -ErrorRecord $_
    throw
}
Add-PhaseMarker -Phase 'FONTS_SUCCESS'
