<#
.SYNOPSIS
    Downloads and extracts the PowerQuery SDK NuGet package.
.DESCRIPTION
    This script downloads the latest version of the Microsoft.PowerQuery.SdkTools NuGet package and extracts its contents.
    It locates the PQTest.exe tool and ensures all dependencies are available.
.PARAMETER outputDir
    The directory where the NuGet package will be extracted.
#>

# PowerShell script to download and extract the PowerQuery SDK NuGet package

$nugetPath = "$env:TEMP\nuget.exe"
Write-Host "Downloading nuget.exe..."
Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile $nugetPath

$packageId = "Microsoft.PowerQuery.SdkTools"
$outputDir = $args[0]

# Get the latest version of the package
Write-Host "Finding latest version of $packageId..."
$listOutput = & $nugetPath list $packageId -Source nuget.org -PreRelease
$latestVersion = ($listOutput | Where-Object { $_ -match "^$packageId\s+(.+)$" } | ForEach-Object { $Matches[1] }) | Select-Object -First 1

Write-Host "Latest version found: $latestVersion"
& $nugetPath install $packageId -Version $latestVersion -OutputDirectory $outputDir -Source nuget.org

# Find the installed package directory
$packageDir = Get-ChildItem "$outputDir\$packageId.*" -Directory | Sort-Object Name -Descending | Select-Object -First 1

Write-Host "Package installed at: $($packageDir.FullName)"

# Find the tools directory with PQTest.exe and its dependencies
$toolsDir = Join-Path $packageDir.FullName "tools"
$pqTestSource = Join-Path $toolsDir "PQTest.exe"

if (-not (Test-Path $pqTestSource)) {
  Write-Host "PQTest.exe not found in tools directory: $toolsDir" -ForegroundColor Red
  exit 1
}

# Use PQTest.exe from its original location to ensure all dependencies are available
echo "pqtest-path=$pqTestSource" >> $env:GITHUB_OUTPUT
echo "sdk-path=$($packageDir.FullName)" >> $env:GITHUB_OUTPUT
