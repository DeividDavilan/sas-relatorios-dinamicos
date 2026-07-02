# 🚀 Deploy no SAS Viya

Como não há SAS instalado localmente, o deploy leva o código até o **SAS Viya** e
o executa lá. Há três caminhos — do mais simples ao totalmente automatizado.
Todos usam **credenciais só por variável de ambiente** (nunca hardcoded).

| Arquivo | Papel |
|---------|-------|
| `push_to_github.ps1` | Empurra o projeto para um repo GitHub (transporte até o Viya). |
| `bootstrap_viya.sas` | Cola no SAS Studio: clona/atualiza o repo e roda o pipeline. |
| `deploy_viya_rest.ps1` | (Opcional) Automação total via API REST do Viya. |

---

## ✅ Caminho recomendado (GitHub + SAS Studio)

**Passo 1 — na sua máquina (PowerShell):** empurre o projeto para o GitHub.

```powershell
pwsh deploy/push_to_github.ps1                 # repo privado (default)
# ou, se preferir repo público (dispensa token no Viya):
pwsh deploy/push_to_github.ps1 -Visibility public
```

O script cria o repo (via `gh`, você já está logado como **@DeividDavilan**),
commita e faz o push. Ao final ele imprime a **URL de clone**.

**Passo 2 — ajuste o bootstrap:** em `deploy/bootstrap_viya.sas`, coloque essa URL
em `GIT_URL` (o padrão já aponta para `DeividDavilan/sas-relatorios-dinamicos`).

**Passo 3 — no SAS Studio (Viya):** se o repo for **privado**, exporte no ambiente
do Compute server antes de rodar:

```bash
export GIT_USER=DeividDavilan
export GIT_TOKEN=<personal access token com escopo 'repo'>
```

Abra `deploy/bootstrap_viya.sas` no SAS Studio e **submeta**. Ele clona o repo no
seu `$HOME`, aponta o `PROJ_ROOT` e roda o `tests/test_smoke.sas`. Procure no log:

```
NOTE: >>> SMOKE TEST: TODOS OS CRITERIOS OK <<<
```

e confira as saídas em `~/sas-relatorios-dinamicos/output/{pdf,html,data}`.

---

## ⚙️ Caminho automatizado (API REST — opcional)

Roda o deploy+execução **sem abrir o SAS Studio**. Requer acesso à API do seu Viya
e um client OAuth que permita o grant `password` (fale com o admin, se necessário).

```powershell
$env:VIYA_URL           = "https://seu-viya.exemplo.com"
$env:VIYA_CLIENT_ID     = "<client id>"
$env:VIYA_CLIENT_SECRET = "<client secret>"
$env:VIYA_USER          = "<usuario>"
$env:VIYA_PASSWORD      = "<senha>"
# $env:VIYA_SKIP_CERT   = "1"   # se o certificado for self-signed

pwsh deploy/deploy_viya_rest.ps1
```

Ele autentica, abre uma sessão do serviço **Compute**, submete o `bootstrap_viya.sas`
(que clona o repo e roda o smoke test) e imprime o **log SAS** no terminal.
Se o nome do compute context do seu ambiente for diferente, ajuste:

```powershell
pwsh deploy/deploy_viya_rest.ps1 -ComputeContext "Nome do seu contexto"
```

> Faça o `push_to_github.ps1` **antes**, pois o bootstrap clona do GitHub.

---

## 📦 Caminho manual (sem GitHub)

Se preferir não usar GitHub: compacte a pasta do projeto e faça upload pelo
**SAS Studio → Upload files**, extraia no `$HOME`, ajuste `PROJ_ROOT` em
`src/99_run_all.sas` e submeta esse arquivo (ou `tests/test_smoke.sas`).

```powershell
# zipar para upload manual
Compress-Archive -Path .\* -DestinationPath ..\sas-relatorios-dinamicos.zip -Force
```

---

## 🔐 Nota de segurança

Nada sensível é versionado: as credenciais de fonte de dados (API/DB) e do GitHub
são lidas de variáveis de ambiente no momento da execução. Os dados de exemplo são
fictícios. Ainda assim, **repo privado** é o default do `push_to_github.ps1`.
