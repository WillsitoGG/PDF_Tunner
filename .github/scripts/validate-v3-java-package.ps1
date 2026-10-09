[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Resolve-Path '.').Path
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Independent acceptance for the v3.1.0 Java/JLink production inputs.
# It does not rely on a globally installed Java runtime.
$libs = Join-Path $RepositoryRoot 'frontend/editor/src-tauri/libs'
$jre = Join-Path $RepositoryRoot 'frontend/editor/src-tauri/runtime/jre'
$jars = @(Get-ChildItem -LiteralPath $libs -File -Filter 'stirling-pdf-*.jar')
if ($jars.Count -ne 1) {
    throw "Expected exactly one upstream desktop backend JAR in $libs; found $($jars.Count)"
}
if (-not (Test-Path -LiteralPath (Join-Path $jre 'release') -PathType Leaf)) {
    throw "Bundled JLink runtime metadata is missing: $jre/release"
}
$java = Join-Path $jre 'bin/java.exe'
if (-not (Test-Path -LiteralPath $java -PathType Leaf)) {
    throw "Bundled JLink java.exe is missing: $java"
}
$release = Get-Content -LiteralPath (Join-Path $jre 'release') -Raw
if ($release -notmatch '(?m)^JAVA_VERSION="25(?:[.+"-]|")') {
    throw "Bundled runtime does not report the JDK 25 family: $release"
}
$reportedJava = (& $java --version 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) {
    throw "Bundled JLink java.exe failed to execute: $reportedJava"
}
Write-Host "PASS: bundled JLink runtime executes on Windows: $($reportedJava.Trim().Split([Environment]::NewLine)[0])"

Add-Type -AssemblyName System.IO.Compression
$zip = [System.IO.Compression.ZipFile]::OpenRead($jars[0].FullName)
try {
    # Verify that the bootJar really contains the compiled JDK 25 application.
    $appClass = $zip.GetEntry('BOOT-INF/classes/stirling/software/SPDF/SPDFApplication.class')
    if ($null -eq $appClass) { throw 'Compiled Spring Boot main class is missing from JAR' }
    $stream = $appClass.Open()
    try {
        $header = [byte[]]::new(8)
        if ($stream.Read($header, 0, 8) -ne 8) { throw 'Java class file is truncated' }
        if ($header[0] -ne 0xCA -or $header[1] -ne 0xFE -or $header[2] -ne 0xBA -or $header[3] -ne 0xBE) {
            throw 'Invalid Java class magic'
        }
        $major = 256 * [int]$header[6] + [int]$header[7]
        if ($major -ne 69) { throw "Wrong Java class major version: $major (expected 69 for Java 25)" }
    } finally {
        $stream.Dispose()
    }

    foreach ($name in @(
        'BOOT-INF/classes/static/pdf-tunner/icon-light.svg',
        'BOOT-INF/classes/static/pdf-tunner/icon-dark.svg',
        'BOOT-INF/classes/static/pdf-tunner/wordmark-black.svg',
        'BOOT-INF/classes/static/pdf-tunner/wordmark-white.svg',
        'BOOT-INF/classes/static/api-landing.html',
        'BOOT-INF/classes/static/mobile-upload.html'
    )) {
        if ($null -eq $zip.GetEntry($name)) { throw "Missing backend resource in JAR: $name" }
        Write-Host "PASS: packaged JAR contains $name"
    }
    foreach ($pair in @(
        @{ Path = 'BOOT-INF/classes/static/api-landing.html'; Required = 'PDF_Tunner - API Server' },
        @{ Path = 'BOOT-INF/classes/static/mobile-upload.html'; Required = 'PDF_Tunner - Mobile Upload' }
    )) {
        $entry = $zip.GetEntry($pair.Path)
        $reader = [System.IO.StreamReader]::new($entry.Open())
        try { $html = $reader.ReadToEnd() } finally { $reader.Dispose() }
        if (-not $html.Contains($pair.Required)) {
            throw "JAR's branded HTML does not contain '$($pair.Required)' in $($pair.Path)"
        }
    }
    Write-Host 'PASS: JDK 25 Spring Boot JAR includes actual PDF_Tunner HTML and SVG resources'
} finally {
    $zip.Dispose()
}
$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $jars[0].FullName
Write-Host "PASS: packaged backend JAR $($jars[0].Name) size=$($jars[0].Length) SHA256=$($hash.Hash)"
Write-Host 'NOTE: Java compilation + JLink validation is NOT backend startup, functional tools QA or final portable ZIP.'
