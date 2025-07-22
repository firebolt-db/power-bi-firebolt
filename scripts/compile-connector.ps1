param(
    [string]$sdkPath = $args[0]
)

Write-Host "Compiling Power BI Connector..."
# Find MakePQX.exe in the SDK tools directory
$toolsDir = Join-Path $sdkPath "tools"
$makePQXPath = Join-Path $toolsDir "MakePQX.exe"

Write-Host "Found MakePQX.exe at: $makePQXPath"

# Define paths
$projectPath = "$PWD"
$mezPath = "$PWD\Firebolt.mez"

# Compile the extension using MakePQX
Write-Host "Compiling Power BI connector using MakePQX.exe..."
& "$makePQXPath" compile

Write-Host "Power BI Connector compiled successfully"

# Copy the compiled mez file to the current directory
Copy-Item -Path "$PWD\bin\AnyCPU\Debug\power-bi-firebolt.mez" -Destination "$PWD\Firebolt.mez" -Force -ErrorAction Stop

# Set output for the next step
echo "connector-path=$PWD\Firebolt.mez" >> $env:GITHUB_OUTPUT
