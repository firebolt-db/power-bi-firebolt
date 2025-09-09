<#
.SYNOPSIS
    Compiles and optionally signs the Power BI Connector using the PowerQuery SDK.
.DESCRIPTION
    This script locates the MakePQX.exe tool within the provided SDK path and uses it to compile the Power BI Connector project.
    The compiled .mez file is then copied to the current directory. If signing parameters are provided, the connector will be packed and signed.
.PARAMETER sdkPath
    The path to the PowerQuery SDK tools directory. This is passed as the first argument to the script.
.PARAMETER certificateBase64
    Base64 encoded signing certificate (.pfx). If provided, the connector will be signed.
.PARAMETER certificatePassword
    Password for the signing certificate. Required if certificateBase64 is provided.
#>
param(
    [string]$sdkPath = $args[0],
    [string]$certificateBase64 = $args[1],
    [string]$certificatePassword = $args[2]
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

# If signing parameters are provided, pack and sign the connector
if ($certificateBase64 -and $certificatePassword) {
    Write-Host "Signing connector..."
    
    # Decode the base64 certificate and save it as a .pfx file
    $certificateBytes = [System.Convert]::FromBase64String($certificateBase64)
    $certificatePath = "$PWD\signing-certificate.pfx"
    [System.IO.File]::WriteAllBytes($certificatePath, $certificateBytes)
    
    # Pack the .mez file into a .pqx file
    $pqxPath = "$PWD\Firebolt.pqx"
    & "$makePQXPath" pack --mez "$PWD\Firebolt.mez" --target "$pqxPath"
    
    # Sign the .pqx file
    & "$makePQXPath" sign "$pqxPath" --certificate "$certificatePath" --password "$certificatePassword"
    
    # Verify the signature
    & "$makePQXPath" verify "$pqxPath"
    
    # Set output for signed connector
    echo "connector-path=$PWD\Firebolt.mez" >> $env:GITHUB_OUTPUT
    echo "connector-path-signed=$pqxPath" >> $env:GITHUB_OUTPUT
    echo "connector-signed=true" >> $env:GITHUB_OUTPUT
} else {
    # Set output for unsigned connector
    echo "connector-path=$PWD\Firebolt.mez" >> $env:GITHUB_OUTPUT
    echo "connector-signed=false" >> $env:GITHUB_OUTPUT
}
