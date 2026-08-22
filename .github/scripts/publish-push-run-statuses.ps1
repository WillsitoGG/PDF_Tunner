param(
  [string]$Branch = 'pdf-tunner/windows-portable-v1',
  [string]$WorkflowFile = 'pdf-tunner-windows-portable.yml',
  [int]$Limit = 50
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
  Invoke-RestMethod -Method Post -Uri $statusUri -Headers $headers -ContentType 'application/json' -Body $payload | Out-Null
  Write-Host "Published connector status for #$RunNumber / $RunId / $Sha => $State"
}

# Publish the current run explicitly so its run_id is available even if the
# Actions run-list endpoint has not indexed the run yet.
$currentUrl = "$env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID"
Publish-RunStatus `
  -Sha $env:GITHUB_SHA `
  -RunId ([long]$env:GITHUB_RUN_ID) `
  -RunNumber ([int]$env:GITHUB_RUN_NUMBER) `
  -Status 'in_progress' `
  -Conclusion '' `
  -TargetUrl $currentUrl `
  -State 'pending'

# Backfill recent push runs so commits from before this bridge (notably run #50)
# become discoverable through GitHub.get_commit_combined_status as well.
$encodedBranch = [Uri]::EscapeDataString($Branch)
$runsUri = "https://api.github.com/repos/$env:GITHUB_REPOSITORY/actions/workflows/$WorkflowFile/runs?event=push&branch=$encodedBranch&per_page=$Limit"
$response = Invoke-RestMethod -Method Get -Uri $runsUri -Headers $headers

foreach ($run in @($response.workflow_runs)) {
  if ([string]::IsNullOrWhiteSpace([string]$run.head_sha)) {
    continue
  }

  Publish-RunStatus `
    -Sha ([string]$run.head_sha) `
    -RunId ([long]$run.id) `
    -RunNumber ([int]$run.run_number) `
    -Status ([string]$run.status) `
    -Conclusion ([string]$run.conclusion) `
    -TargetUrl ([string]$run.html_url) `
    -State (Convert-RunToState -Run $run)
}

Write-Host "PASS: published connector-readable commit statuses for $(@($response.workflow_runs).Count) recent push runs."
