<#
=================================================================================
 Arquivo : deploy/deploy_viya_rest.ps1
 Projeto : Relatorios Dinamicos Responsivos via SAS
 Proposito: (OPCIONAL / automacao total) Dispara o deploy+execucao no SAS Viya
            SEM abrir o SAS Studio. Autentica na API, abre uma sessao do
            servico Compute, submete o codigo do deploy/bootstrap_viya.sas
            (que clona o repo e roda o smoke test) e imprime o log SAS.
 Requer   : PowerShell 7+ e acesso a API do seu ambiente Viya.
            Um client OAuth que permita o grant 'password' (fale com seu admin
            se nao tiver). O caminho recomendado/simples continua sendo o
            deploy/bootstrap_viya.sas colado no SAS Studio.

 Credenciais — SOMENTE via variaveis de ambiente (nunca hardcoded):
     $env:VIYA_URL           = "https://seu-viya.exemplo.com"
     $env:VIYA_CLIENT_ID     = "<client id>"
     $env:VIYA_CLIENT_SECRET = "<client secret>"
     $env:VIYA_USER          = "<usuario>"
     $env:VIYA_PASSWORD      = "<senha>"
     # opcional, se o certificado for self-signed:
     $env:VIYA_SKIP_CERT     = "1"
 Uso: pwsh deploy/deploy_viya_rest.ps1
=================================================================================
#>
[CmdletBinding()]
param(
    [string]$ComputeContext = "SAS Job Execution compute context",
    [int]$TimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"

function Get-EnvOrFail([string]$name) {
    $v = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrWhiteSpace($v)) { throw "Variavel de ambiente '$name' nao definida. Veja o cabecalho do script." }
    return $v
}

$ViyaUrl      = (Get-EnvOrFail "VIYA_URL").TrimEnd("/")
$ClientId     = Get-EnvOrFail "VIYA_CLIENT_ID"
$ClientSecret = Get-EnvOrFail "VIYA_CLIENT_SECRET"
$User         = Get-EnvOrFail "VIYA_USER"
$Password     = Get-EnvOrFail "VIYA_PASSWORD"

# Opcao para ignorar validacao de certificado (self-signed)
$RestOpts = @{}
if ($env:VIYA_SKIP_CERT -eq "1") { $RestOpts["SkipCertificateCheck"] = $true }

# Codigo SAS a submeter = o bootstrap (clona o repo + roda o smoke test)
$BootstrapPath = Join-Path $PSScriptRoot "bootstrap_viya.sas"
if (-not (Test-Path $BootstrapPath)) { throw "Nao achei $BootstrapPath" }
$CodeLines = @(Get-Content -LiteralPath $BootstrapPath)

Write-Host "==> [1/5] Autenticando em $ViyaUrl"
$basic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$ClientId`:$ClientSecret"))
$tokenResp = Invoke-RestMethod @RestOpts -Method Post -Uri "$ViyaUrl/SASLogon/oauth/token" `
    -Headers @{ Authorization = "Basic $basic" } `
    -ContentType "application/x-www-form-urlencoded" `
    -Body @{ grant_type = "password"; username = $User; password = $Password }
$token = $tokenResp.access_token
if (-not $token) { throw "Falha ao obter token OAuth." }
$auth = @{ Authorization = "Bearer $token" }

Write-Host "==> [2/5] Localizando o compute context '$ComputeContext'"
$ctxFilter  = [uri]::EscapeDataString("eq(name,'$ComputeContext')")
$ctxUri = "$ViyaUrl/compute/contexts?filter=$ctxFilter&limit=1"
$ctx = Invoke-RestMethod @RestOpts -Method Get -Uri $ctxUri `
    -Headers ($auth + @{ Accept = "application/vnd.sas.collection+json" })
$ctxId = $ctx.items[0].id
if (-not $ctxId) { throw "Compute context '$ComputeContext' nao encontrado. Ajuste -ComputeContext." }

Write-Host "==> [3/5] Abrindo sessao Compute"
$session = Invoke-RestMethod @RestOpts -Method Post -Uri "$ViyaUrl/compute/contexts/$ctxId/sessions" `
    -Headers ($auth + @{ Accept = "application/vnd.sas.compute.session+json" }) `
    -ContentType "application/vnd.sas.compute.session.request+json" -Body "{}"
$sessionId = $session.id

try {
    Write-Host "==> [4/5] Submetendo o bootstrap ($($CodeLines.Count) linhas)"
    $jobBody = @{ name = "deploy-relatorios-sas"; code = $CodeLines } | ConvertTo-Json -Depth 5
    $job = Invoke-RestMethod @RestOpts -Method Post -Uri "$ViyaUrl/compute/sessions/$sessionId/jobs" `
        -Headers ($auth + @{ Accept = "application/vnd.sas.compute.job+json" }) `
        -ContentType "application/vnd.sas.compute.job.request+json" -Body $jobBody
    $jobId = $job.id

    Write-Host "==> [5/5] Aguardando conclusao (timeout ${TimeoutSeconds}s)"
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        Start-Sleep -Seconds 3
        $state = (Invoke-RestMethod @RestOpts -Method Get `
            -Uri "$ViyaUrl/compute/sessions/$sessionId/jobs/$jobId/state" `
            -Headers ($auth + @{ Accept = "text/plain" })).ToString().Trim()
        Write-Host "    estado: $state"
    } while ($state -notin @("completed","failed","canceled","error") -and (Get-Date) -lt $deadline)

    # Log SAS
    Write-Host ""
    Write-Host "----------------------- LOG SAS -----------------------"
    $log = Invoke-RestMethod @RestOpts -Method Get `
        -Uri "$ViyaUrl/compute/sessions/$sessionId/jobs/$jobId/log/content?limit=1000000" `
        -Headers ($auth + @{ Accept = "application/vnd.sas.collection+json" })
    $log.items | ForEach-Object { $_.line } | Write-Host
    Write-Host "-------------------------------------------------------"

    if ($state -eq "completed") {
        Write-Host "==> Deploy/execucao concluidos. Procure [PASS]/[FAIL] do smoke test no log acima."
    } else {
        Write-Warning "Job terminou com estado '$state'. Verifique o log acima."
    }
}
finally {
    # Encerra a sessao
    try {
        Invoke-RestMethod @RestOpts -Method Delete -Uri "$ViyaUrl/compute/sessions/$sessionId" -Headers $auth | Out-Null
        Write-Host "==> Sessao Compute encerrada."
    } catch { Write-Warning "Nao foi possivel encerrar a sessao $sessionId." }
}
