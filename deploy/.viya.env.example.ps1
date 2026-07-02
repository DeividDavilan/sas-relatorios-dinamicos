# =============================================================================
#  TEMPLATE de credenciais do SAS Viya para deploy_viya_rest.ps1
#  -> COPIE este arquivo para  deploy/.viya.env.ps1  e preencha os valores.
#     (o .viya.env.ps1 e ignorado pelo git — nunca vai para o repositorio)
#  -> Depois e so pedir: "roda o deploy_viya_rest".
# =============================================================================

$env:VIYA_URL           = "https://SEU-VIYA.exemplo.com"   # sem barra no final
$env:VIYA_CLIENT_ID     = "SEU_CLIENT_ID"
$env:VIYA_CLIENT_SECRET = "SEU_CLIENT_SECRET"
$env:VIYA_USER          = "SEU_USUARIO"
$env:VIYA_PASSWORD      = "SUA_SENHA"

# Opcional: descomente se o certificado do Viya for self-signed
# $env:VIYA_SKIP_CERT   = "1"
