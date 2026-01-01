# Build and package Windows release for JSONLens
# Usage: .\tool\release\build_windows_release.ps1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$RELEASE_DIR = "release\windows"
$BUILD_DIR = "build\windows"

Write-Host "1/5: Ensuring Flutter dependencies..."
flutter pub get

Write-Host "2/5: Building Windows release..."
flutter build windows --release

Write-Host "3/5: Locating .exe..."
# Search recursively under build/windows and prefer executables that are inside a Release folder
$exe = Get-ChildItem -Path $BUILD_DIR -Filter *.exe -File -Recurse -ErrorAction SilentlyContinue |
       Where-Object { $_.FullName -like '*\Release\*' } |
       Select-Object -First 1


























if (-not $exe) {
    Write-Error "ERROR: .exe not found in $BUILD_DIR"
    exit 1
}
$APP_NAME = [System.IO.Path]::GetFileNameWithoutExtension($exe.Name)
Write-Host "Found exe: $($exe.Name) (app name: $APP_NAME)"

Write-Host "4/5: Copying Release folder to release directory (only this folder will be kept)..."
New-Item -ItemType Directory -Path "$RELEASE_DIR" -Force | Out-Null
$targetDir = Join-Path $RELEASE_DIR $APP_NAME
# Ensure clean target
if (Test-Path $targetDir) { Remove-Item -Recurse -Force $targetDir }
# Create the runner\Release subpath under the target
$targetReleaseDir = Join-Path $targetDir 'runner\Release'
New-Item -ItemType Directory -Path $targetReleaseDir -Force | Out-Null

# Determine the source Release folder (where the exe was found)
$sourceReleaseDir = $exe.DirectoryName
if (-not (Test-Path $sourceReleaseDir)) {
    Write-Error "ERROR: source Release directory not found: $sourceReleaseDir"
    exit 1
}

# Copy only the contents of the source Release folder into release/windows/<AppName>/runner/Release
Copy-Item -Path (Join-Path $sourceReleaseDir '*') -Destination $targetReleaseDir -Recurse -Force

Write-Host "5/5: Creating ZIP artifact (contains <AppName>/runner/Release)..."
$zipPath = Join-Path $RELEASE_DIR ("$APP_NAME.zip")
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path $targetDir -DestinationPath $zipPath -Force

# Remove the copied folder to keep only the zip artifact
Remove-Item -Recurse -Force $targetDir

Write-Host "Done ✅"
Write-Host "Artifacts in: $RELEASE_DIR/"
if (Test-Path $zipPath) { Write-Host " - Zip: $zipPath" }
if (Test-Path $targetDir) { Write-Host " - Folder: $targetDir (still present)" } else { Write-Host " - Folder removed; only the zip artifact remains." }