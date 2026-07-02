/*==============================================================================
| Arquivo : deploy/bootstrap_viya.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: DEPLOY + EXECUCAO no SAS Viya em um unico passo. Cole este arquivo
|            no SAS Studio (Viya) e submeta. Ele:
|              1. Clona (ou atualiza) o repositorio do projeto no home do
|                 servidor de Compute usando as funcoes GIT nativas do SAS.
|              2. Aponta PROJ_ROOT para a pasta clonada.
|              3. Roda o teste de fumaca (pipeline completo com o CSV de exemplo).
| Requisitos: SAS 9.4M6+ / Viya (funcoes GITFN_*). Acesso de rede do Compute
|             server ao GitHub.
| Segredos  : para repo PRIVADO, defina no ambiente do Compute server:
|                 export GIT_USER=DeividDavilan
|                 export GIT_TOKEN=<personal access token>
|             (lidos via %sysget; nunca hardcoded). Repo publico dispensa isso.
==============================================================================*/

/*------------------------------------------------------------------------------
| 1. Parametros — AJUSTE a URL do repositorio.
------------------------------------------------------------------------------*/
%let GIT_URL = https://github.com/DeividDavilan/sas-relatorios-dinamicos.git;

/* Pasta de destino do clone no servidor de Compute (persistente no home) */
%let HOME_DIR = %sysget(HOME);
%if %superq(HOME_DIR) = %then %let HOME_DIR = %sysfunc(pathname(WORK));
%let CLONE_DIR = &HOME_DIR./sas-relatorios-dinamicos;

/* Credenciais opcionais (apenas repo privado) */
%let GIT_USER  = %sysget(GIT_USER);
%let GIT_TOKEN = %sysget(GIT_TOKEN);

/*------------------------------------------------------------------------------
| 2. Clona ou atualiza o repositorio.
------------------------------------------------------------------------------*/
%macro deploy_from_git;
    %local rc n;

    %if %sysfunc(fileexist(&CLONE_DIR./.git)) %then %do;
        /* Ja existe -> atualiza (pull) */
        %put NOTE: [DEPLOY] Repositorio ja presente. Atualizando (pull) em &CLONE_DIR.;
        %if %superq(GIT_TOKEN) ne %then
            %let rc = %sysfunc(GITFN_PULL(&CLONE_DIR., &GIT_USER., &GIT_TOKEN.));
        %else
            %let rc = %sysfunc(GITFN_PULL(&CLONE_DIR.));
    %end;
    %else %do;
        /* Primeira vez -> clona */
        %put NOTE: [DEPLOY] Clonando &GIT_URL. em &CLONE_DIR.;
        %if %superq(GIT_TOKEN) ne %then
            %let n = %sysfunc(GITFN_CLONE(&GIT_URL., &CLONE_DIR., &GIT_USER., &GIT_TOKEN.));
        %else
            %let n = %sysfunc(GITFN_CLONE(&GIT_URL., &CLONE_DIR.));
        %put NOTE: [DEPLOY] Clone concluido (&n. arquivos).;
    %end;

    %if not %sysfunc(fileexist(&CLONE_DIR./src/99_run_all.sas)) %then %do;
        %put ERROR: [DEPLOY] Falha no deploy: &CLONE_DIR./src/99_run_all.sas nao encontrado.;
        %put ERROR: [DEPLOY] Verifique a GIT_URL, o acesso de rede e (repo privado) GIT_USER/GIT_TOKEN.;
        %abort cancel;
    %end;

    %put NOTE: [DEPLOY] Deploy OK. PROJ_ROOT sera &CLONE_DIR.;
%mend deploy_from_git;

%deploy_from_git;

/*------------------------------------------------------------------------------
| 3. Aponta o projeto para a pasta clonada e roda o teste de fumaca.
|    (99_run_all.sas / test_smoke.sas respeitam este PROJ_ROOT pre-definido.)
------------------------------------------------------------------------------*/
%global PROJ_ROOT;
%let PROJ_ROOT = &CLONE_DIR.;

%include "&PROJ_ROOT./tests/test_smoke.sas";

/* Fim de bootstrap_viya.sas */
