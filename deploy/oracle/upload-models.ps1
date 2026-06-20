<#
.SYNOPSIS
  Upload file model .pt từ Windows lên Oracle Cloud VM.

.EXAMPLE
  .\deploy\oracle\upload-models.ps1 -SshKey "C:\keys\oracle.pem" -VmIp "123.45.67.89"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$SshKey,

    [Parameter(Mandatory = $true)]
    [string]$VmIp,

    [string]$RemoteUser = "ubuntu",
    [string]$AppDir = "/home/ubuntu/Doantotnghiep2"
)

$ErrorActionPreference = "Stop"
$ModelsDir = Join-Path $PSScriptRoot "..\..\ai_service\models" | Resolve-Path

$files = @(
    "classify_model.pt",
    "forecast_model.pt",
    "ocr_reco_model.pt",
    "classify_meta.json",
    "classify_vocab.json",
    "classify_preprocess.json",
    "forecast_meta.json",
    "ocr_reco_meta.json",
    "ocr_reco_charset.json"
)

Write-Host "==> Upload models -> ${RemoteUser}@${VmIp}:${AppDir}/ai_service/models/"
ssh -i $SshKey -o StrictHostKeyChecking=accept-new "${RemoteUser}@${VmIp}" "mkdir -p ${AppDir}/ai_service/models"

foreach ($f in $files) {
    $local = Join-Path $ModelsDir $f
    if (-not (Test-Path $local)) {
        Write-Warning "Bỏ qua (không có): $f"
        continue
    }
    $sizeMb = [math]::Round((Get-Item $local).Length / 1MB, 1)
    Write-Host "  -> $f (${sizeMb} MB)"
    scp -i $SshKey $local "${RemoteUser}@${VmIp}:${AppDir}/ai_service/models/"
}

Write-Host ""
Write-Host "Xong. Trên VM chạy:"
Write-Host "  sudo systemctl restart expense-ai"
Write-Host "  curl http://127.0.0.1:8000/health"
