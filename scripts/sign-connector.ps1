<#
.SYNOPSIS
    Signs the Power BI Connector using the PowerQuery SDK.
.DESCRIPTION
    This script packs and signs the Power BI Connector .mez file using the provided signing certificate.
.PARAMETER sdkPath
    The path to the PowerQuery SDK tools directory.
.PARAMETER mezPath
    The path to the .mez file to be signed.
.PARAMETER certificateBase64
    Base64 encoded signing certificate (.pfx).
.PARAMETER certificatePassword
    Password for the signing certificate.
.PARAMETER outputPath
    Optional path for the output .pqx file. Defaults to same directory as .mez file.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$sdkPath,
    
    [Parameter(Mandatory=$true)]
    [string]$mezPath,
    
    [Parameter(Mandatory=$true)]
    [string]$certificateBase64,
    
    [Parameter(Mandatory=$true)]
    [string]$certificatePassword,
    
    [string]$outputPath
)

Write-Host "Signing Power BI Connector..."

# Validate inputs
if (-not (Test-Path $mezPath)) {
    Write-Error "MEZ file not found: $mezPath"
    exit 1
}

if (-not (Test-Path $sdkPath)) {
    Write-Error "SDK path not found: $sdkPath"
    exit 1
}

# Find MakePQX.exe in the SDK tools directory
$toolsDir = Join-Path $sdkPath "tools"
$makePQXPath = Join-Path $toolsDir "MakePQX.exe"

if (-not (Test-Path $makePQXPath)) {
    Write-Error "MakePQX.exe not found at: $makePQXPath"
    exit 1
}

Write-Host "Found MakePQX.exe at: $makePQXPath"

# Determine output path
if (-not $outputPath) {
    $mezDir = Split-Path $mezPath -Parent
    $mezBaseName = [System.IO.Path]::GetFileNameWithoutExtension($mezPath)
    $outputPath = Join-Path $mezDir "$mezBaseName.pqx"
}

Write-Host "Output path: $outputPath"

# Decode the base64 certificate and save it as a .pfx file
Write-Host "Decoding signing certificate..."
$certificateBytes = [System.Convert]::FromBase64String($certificateBase64)
$certificatePath = Join-Path (Split-Path $mezPath -Parent) "signing-certificate.pfx"
[System.IO.File]::WriteAllBytes($certificatePath, $certificateBytes)

# Pack the .mez file into a .pqx file
Write-Host "Packing MEZ file to PQX..."
& "$makePQXPath" pack --mez "$mezPath" --target "$outputPath"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to pack MEZ file"
    exit 1
}

# Sign the .pqx file
Write-Host "Signing PQX file..."
& "$makePQXPath" sign "$outputPath" --certificate "$certificatePath" --password "$certificatePassword"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to sign PQX file"
    exit 1
}

# Verify the signature
Write-Host "Verifying signature..."
& "$makePQXPath" verify "$outputPath"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to verify signature"
    exit 1
}

Write-Host "Connector signed successfully: $outputPath"

# Set GitHub Actions outputs
if ($env:GITHUB_OUTPUT) {
    echo "connector-path-signed=$outputPath" >> $env:GITHUB_OUTPUT
}
