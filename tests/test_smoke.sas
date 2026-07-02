/*==============================================================================
| Arquivo : tests/test_smoke.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Teste de fumaca ponta a ponta. Roda o pipeline completo com a
|            fonte CSV de exemplo e verifica os criterios de aceite:
|              - output/pdf/<nome>.pdf existe
|              - output/html/<nome>.html existe
|              - output/data/<nome>_dados_usados.csv existe
|            Ao final, imprime um resumo PASS/FAIL no log.
|            A SECAO 2 (opcional) valida que m_validate aborta em dataset vazio.
| Como usar: ajuste PROJ_ROOT e submeta no SAS Studio.
==============================================================================*/

/*------------------------------------------------------------------------------
| SECAO 1 - CAMINHO FELIZ: roda o pipeline e confere as 3 saidas.
------------------------------------------------------------------------------*/
%if not %symexist(PROJ_ROOT) %then %global PROJ_ROOT;
%if %superq(PROJ_ROOT) = %then
    %let PROJ_ROOT = /home/student/sas-relatorios-dinamicos;

/* Garante fonte CSV de exemplo para o teste */
%global SOURCE_TYPE;
%let SOURCE_TYPE = csv;

/* Executa o pipeline completo (define e chama %run_report) */
%include "&PROJ_ROOT./src/99_run_all.sas";

/* Verificacao das saidas */
%macro smoke_check;
    %local pdf html csv ok;
    %let pdf  = &DIR_OUT_PDF./&RPT_NOME_ARQ..pdf;
    %let html = &DIR_OUT_HTML./&RPT_NOME_ARQ..html;
    %let csv  = &DIR_OUT_DATA./&RPT_NOME_ARQ._dados_usados.csv;
    %let ok = 1;

    %put NOTE: ============ RESULTADO DO SMOKE TEST ============;

    %if %sysfunc(fileexist(&pdf.))  %then %put NOTE: [PASS] PDF gerado:  &pdf.;
    %else %do; %put ERROR: [FAIL] PDF nao encontrado: &pdf.;  %let ok = 0; %end;

    %if %sysfunc(fileexist(&html.)) %then %put NOTE: [PASS] HTML gerado: &html.;
    %else %do; %put ERROR: [FAIL] HTML nao encontrado: &html.; %let ok = 0; %end;

    %if %sysfunc(fileexist(&csv.))  %then %put NOTE: [PASS] CSV gerado:  &csv.;
    %else %do; %put ERROR: [FAIL] CSV nao encontrado: &csv.;  %let ok = 0; %end;

    %if &ok. = 1 %then %put NOTE: >>> SMOKE TEST: TODOS OS CRITERIOS OK <<<;
    %else %put ERROR: >>> SMOKE TEST FALHOU: verifique os itens [FAIL] acima <<<;

    %put NOTE: ==================================================;
%mend smoke_check;

%smoke_check;

/*------------------------------------------------------------------------------
| SECAO 2 (OPCIONAL) - TESTE NEGATIVO de m_validate.
| Descomente o bloco abaixo para confirmar que um dataset vazio aborta o
| pipeline com mensagem clara. ATENCAO: %abort cancel interrompe a submissao,
| por isso este teste fica por ultimo e deve ser rodado isoladamente.
------------------------------------------------------------------------------*/
/*
%let KEEP_VARS = valor;
data &SRC_DS.;
    stop;
    set &TXF_DS.;
run;
%put NOTE: [TESTE NEGATIVO] Esperado: %validate_src abortar com "0 registros".;
%validate_src;
%put ERROR: [FAIL] validate_src NAO abortou em dataset vazio (deveria ter abortado).;
*/

/* Fim de test_smoke.sas */
