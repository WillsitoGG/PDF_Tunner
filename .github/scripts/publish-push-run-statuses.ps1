param(
  [string]$Branch = 'pdf-tunner/windows-portable-v1',
  [string]$WorkflowFile = 'pdf-tunner-windows-portable.yml',
  [ValidateRange(2, 10)][int]$Limit = 5
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($env:GH_TOKEN)) {
  throw 'GH_TOKEN is required to publish connector-readable run statuses.'
}
if ([string]::IsNullOrWhiteSpace($env:GITHUB_REPOSITORY)) {
  throw 'GITHUB_REPOSITORY is not available.'
}

$headers = @{
  Authorization = "Bearer $env:GH_TOKEN"
  Accept = 'application/vnd.github+json'
  'X-GitHub-Api-Version' = '2022-11-28'
}
$context = 'pdf-tunner/windows-portable-push'

function Convert-RunToState {
  param($Run)

  if ($Run.status -ne 'completed') {
    return 'pending'
  }

  switch ($Run.conclusion) {
    'success' { return 'success' }
    'failure' { return 'failure' }
    'timed_out' { return 'failure' }
    'action_required' { return 'failure' }
    default { return 'error' }
  }
}

function Publish-RunStatus {
  param(
    [Parameter(Mandatory = $true)][string]$Sha,
    [Parameter(Mandatory = $true)][long]$RunId,
    [Parameter(Mandatory = $true)][int]$RunNumber,
    [Parameter(Mandatory = $true)][string]$Status,
    [string]$Conclusion,
    [Parameter(Mandatory = $true)][string]$TargetUrl,
    [Parameter(Mandatory = $true)][string]$State
  )

  $resultText = if ([string]::IsNullOrWhiteSpace($Conclusion)) { $Status } else { "$Status/$Conclusion" }
  $description = "#$RunNumber $resultText run_id=$RunId"
  if ($description.Length -gt 140) {
    $description = $description.Substring(0, 140)
  }

  $payload = @{
    state = $State
    target_url = $TargetUrl
    description = $description
    context = $context
  } | ConvertTo-Json -Compress

  $statusUri = "https://api.github.com/repos/$env:GITHUB_REPOSITORY/statuses/$Sha"
  for ($attempt = 1; $attempt -le 2; $attempt++) {
    try {
      Invoke-RestMethod -Method Post -Uri $statusUri -Headers $headers -ContentType 'application/json' -Body $payload -TimeoutSec 10 | Out-Null
      Write-Host "Published connector status for #$RunNumber / $RunId / $Sha => $State"
      return $true
    }
    catch {
      if ($attempt -eq 2) {
        Write-Warning "Connector status publication failed after $attempt bounded attempts for run #$RunNumber / ${RunId}: $($_.Exception.Message)"
        return $false
      }
      Start-Sleep -Seconds 2
    }
  }
}

# Publish the current run explicitly so its run_id is available even if the
# Actions run-list endpoint has not indexed the run yet.
$currentUrl = "$env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"
$publishedCount = 0
$currentPublished = Publish-RunStatus `
  -Sha $env:GITHUB_SHA `
  -RunId ([long]$env:GITHUB_RUN_ID) `
  -RunNumber ([int]$env:GITHUB_RUN_NUMBER) `
  -Status 'in_progress' `
  -Conclusion '' `
  -TargetUrl $currentUrl `
  -State 'pending'
if ($currentPublished) { $publishedCount++ }

# Publish only the latest completed predecessor. Historical backfill has already
# been completed; replaying dozens of status writes adds no useful evidence and
# makes an auxiliary connector bridge vulnerable to transient GitHub transport
# failures before the functional gates begin.
$encodedBranch = [Uri]::EscapeDataString($Branch)
$runsUri = "https://api.github.com/repos/$env:GITHUB_REPOSITORY/actions/workflows/$WorkflowFile/runs?event=push&branch=$encodedBranch&per_page=$Limit"
$response = $null
for ($attempt = 1; $attempt -le 2; $attempt++) {
  try {
    $response = Invoke-RestMethod -Method Get -Uri $runsUri -Headers $headers -TimeoutSec 10
    break
  }
  catch {
    if ($attempt -eq 2) {
      Write-Warning "Recent-run lookup failed after $attempt bounded attempts: $($_.Exception.Message)"
    }
    else {
      Start-Sleep -Seconds 2
    }
  }
}

if ($null -ne $response) {
  $predecessor = @($response.workflow_runs | Where-Object {
      [long]$_.id -ne [long]$env:GITHUB_RUN_ID -and
      $_.status -eq 'completed' -and
      -not [string]::IsNullOrWhiteSpace([string]$_.head_sha)
    } | Select-Object -First 1)

  if ($predecessor.Count -eq 1) {
    $predecessorPublished = Publish-RunStatus `
      -Sha ([string]$predecessor[0].head_sha) `
      -RunId ([long]$predecessor[0].id) `
      -RunNumber ([int]$predecessor[0].run_number) `
      -Status ([string]$predecessor[0].status) `
      -Conclusion ([string]$predecessor[0].conclusion) `
      -TargetUrl ([string]$predecessor[0].html_url) `
      -State (Convert-RunToState -Run $predecessor[0])
    if ($predecessorPublished) { $publishedCount++ }
  }
}

Write-Host "PASS: connector status bridge completed with $publishedCount successful bounded publication(s); status publication is auxiliary and does not replace functional gates."
