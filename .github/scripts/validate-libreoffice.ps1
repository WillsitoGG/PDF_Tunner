[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PortableRoot,
    [Parameter(Mandatory = $true)][string]$LibreOfficeVersion,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$LibreOfficeMsiSha256,
    [string]$BackendBaseUrl,
    [string]$BackendLogRoot,
    [switch]$RequireRelocation
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$core = Join-Path $PSScriptRoot 'validate-libreoffice-core.ps1'
$fonts = Join-Path $PSScriptRoot 'validate-conversion-fonts.ps1'
$veraPdf = Join-Path $PSScriptRoot 'validate-verapdf.ps1'
foreach ($requiredScript in @($core, $fonts, $veraPdf)) {
    if (-not (Test-Path -LiteralPath $requiredScript -PathType Leaf)) {
        throw "Required PDF_Tunner LibreOffice/VeraPDF validation script is missing: $requiredScript"
    }
}

$coreParams = @{}
foreach ($key in $PSBoundParameters.Keys) { $coreParams[$key] = $PSBoundParameters[$key] }
& $core @coreParams
& $fonts `
    -PortableRoot $PortableRoot `
    -BackendBaseUrl $BackendBaseUrl `
    -BackendLogRoot $BackendLogRoot `
    -RequireRelocation:$RequireRelocation

# VeraPDF is embedded in app.jar rather than staged as an external executable.
# Exercise it only in the live-backend invocation of this wrapper; standalone
# LibreOffice validation remains independent of a running application.
if (-not [string]::IsNullOrWhiteSpace($BackendBaseUrl)) {
    if ([string]::IsNullOrWhiteSpace($BackendLogRoot)) {
        throw 'BackendLogRoot is required when running the embedded VeraPDF E2E gate.'
    }
    & $veraPdf `
        -PortableRoot $PortableRoot `
        -BackendBaseUrl $BackendBaseUrl `
        -BackendLogRoot $BackendLogRoot
}
