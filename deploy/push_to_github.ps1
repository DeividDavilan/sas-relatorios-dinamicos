<#
=================================================================================
 Arquivo : deploy/push_to_github.ps1
 Projeto : Relatorios Dinamicos Responsivos via SAS
 Proposito: Empurra o projeto para um repositorio GitHub (transporte ate o Viya).
            De la, o SAS Studio clona via deploy/bootstrap_viya.sas.
 Pre-req  : gh CLI autenticado (voce ja esta como @DeividDavilan) e git no PATH.
 Uso      : pwsh deploy/push_to_github.ps1                 # repo privado (default)
            pwsh deploy/push_to_github.ps1 -Visibility public
            pwsh deploy/push_to_github.ps1 -RepoName outro-nome
=================================================================================
#>
[CmdletBinding()]
param(
    [string]$RepoName   = "sas-relatorios-dinamicos",
    [ValidateSet("private","public")]
    [string]$Visibility = "private",
    [string]$CommitMessage = "Deploy: pipeline SAS de relatorios dinamicos"
)

$ErrorActionPreference = "Stop"

# Raiz do projeto = pasta-pai deste script (deploy/)
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot
Write-Host "==> Projeto: $ProjectRoot"

# 1. Ferramentas
foreach ($tool in @("git","gh")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "'$tool' nao encontrado no PATH. Instale/abra um terminal com $tool disponivel."
    }
}

# 2. Repo git local
if (-not (Test-Path (Join-Path $ProjectRoot ".git"))) {
    Write-Host "==> git init"
    git init -b main | Out-Null
}

# Garante identidade do commit (usa a global se existir; senao define local)
if (-not (git config user.email)) { git config user.email "ddavilanandre@gmail.com" }
if (-not (git config user.name))  { git config user.name  "Deivid Davilan" }

# 3. Commit
Write-Host "==> git add + commit"
git add -A
# Só commita se houver algo staged
$staged = git diff --cached --name-only
if ($staged) {
    git commit -m $CommitMessage | Out-Null
    Write-Host "    commit criado."
} else {
    Write-Host "    nada novo para commitar."
}

# 4. Remote / criacao do repo
$hasOrigin = (git remote) -contains "origin"
if (-not $hasOrigin) {
    # Repo remoto ja existe na conta?
    $me = (gh api user --jq ".login").Trim()
    $exists = $false
    try { gh repo view "$me/$RepoName" *> $null; $exists = $true } catch { $exists = $false }

    if ($exists) {
        Write-Host "==> Repo $me/$RepoName ja existe. Adicionando remote origin."
        git remote add origin "https://github.com/$me/$RepoName.git"
        git push -u origin main
    } else {
        Write-Host "==> Criando repo $Visibility '$RepoName' e fazendo push"
        gh repo create $RepoName "--$Visibility" --source=. --remote=origin --push
    }
} else {
    Write-Host "==> Remote origin ja configurado. git push"
    git push -u origin main
}

# 5. Saida: URL para o bootstrap
$cloneUrl = (git remote get-url origin)
Write-Host ""
Write-Host "=================================================================="
Write-Host " PUSH CONCLUIDO."
Write-Host " URL de clone (use no deploy/bootstrap_viya.sas -> GIT_URL):"
Write-Host "   $cloneUrl"
if ($Visibility -eq "private") {
    Write-Host ""
    Write-Host " Repo PRIVADO: no SAS Viya, exporte antes de rodar o bootstrap:"
    Write-Host "   export GIT_USER=<seu_usuario_github>"
    Write-Host "   export GIT_TOKEN=<personal access token com escopo 'repo'>"
}
Write-Host "=================================================================="
