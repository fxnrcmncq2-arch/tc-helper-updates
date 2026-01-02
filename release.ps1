param(
  [Parameter(Mandatory=$true)][string]$Version,
  [Parameter(Mandatory=$true)][string]$AppProjectPath
)

$ErrorActionPreference = "Stop"

# --- Paths ---
$updatesRepo = Split-Path -Parent $MyInvocation.MyCommand.Path
$distExe = Join-Path $AppProjectPath "dist\T&C Helper App.exe"
$zipName = "T.C.Helper.App.zip"
$zipPath = Join-Path $updatesRepo $zipName
$latestJsonPath = Join-Path $updatesRepo "latest.json"

# --- Sanity checks ---
if (!(Test-Path $distExe)) {
  throw "Cannot find EXE at: $distExe`nBuild first so dist\T&C Helper App.exe exists."
}
if (!(Test-Path $latestJsonPath)) {
  throw "Cannot find latest.json at: $latestJsonPath`nPut latest.json in this repo folder."
}

# --- Build zip containing ONLY the exe ---
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$tempDir = Join-Path $env:TEMP ("tc_helper_release_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempDir | Out-Null
Copy-Item $distExe (Join-Path $tempDir "T&C Helper App.exe")

Compress-Archive -Path (Join-Path $tempDir "T&C Helper App.exe") -DestinationPath $zipPath
Remove-Item $tempDir -Recurse -Force

# --- Calculate sha256 of the zip ---
$sha = (Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLower()

# --- Create GitHub Release + upload asset ---
# Tag format: v1.0.1
$tag = "v$Version"

# Create release (if it exists, this will error; you can delete or change version)
gh release create $tag $zipPath --title "T&C Helper App $Version" --notes "Auto release $Version" --repo fxnrcmncq2-arch/tc-helper-updates

# --- Update latest.json ---
$downloadUrl = "https://github.com/fxnrcmncq2-arch/tc-helper-updates/releases/download/$tag/$zipName"

$latestObj = @{
  version = $Version
  url     = $downloadUrl
  sha256  = $sha
}

$latestObj | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $latestJsonPath

# --- Commit + push latest.json ---
git add latest.json
git commit -m "Update latest.json to $Version"
git push

Write-Host ""
Write-Host "✅ Done!"
Write-Host "latest.json -> $Version"
Write-Host "url -> $downloadUrl"
Write-Host "sha256 -> $sha"