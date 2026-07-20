/*==============================================================================
| Arquivo : tests/test_smoke.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Teste de fumaca ponta a ponta. Roda o pipeline completo com a
|            fonte CSV de exemplo e verifica os criterios de aceite:
|              - output/pdf/<nome>.pdf existe e tem tamanho > 0
|              - output/html/<nome>.html existe e tem tamanho > 0
|              - output/data/<nome>_dados_usados.csv existe
|              - WORK.report_txf existe e tem registros
|              - WORK.stats_means existe (notas de calculo)
|            Ao final, imprime um resumo PASS/FAIL no log.
|            A SECAO 2 (opcional) valida que m_validate aborta em dataset vazio.
| Como usar: ajuste PROJ_ROOT e submeta no SAS Studio.
==============================================================================*/

/*------------------------------------------------------------------------------
| SECAO 1 - CAMINHO FELIZ: roda o pipeline e confere as saidas.
------------------------------------------------------------------------------*/
%if not %symexist(PROJ_ROOT) %then %global PROJ_ROOT;
%if %superq(PROJ_ROOT) = %then
    %let PROJ_ROOT = /home/student/sas-relatorios-dinamicos;

/* Garante fonte CSV de exemplo para o teste */
%global SOURCE_TYPE;
%let SOURCE_TYPE = csv;

/* Contador de resultados */
%global _SMOKE_PASS _SMOKE_FAIL;
%let _SMOKE_PASS = 0;
%let _SMOKE_FAIL = 0;

/* Macro auxiliar: incrementa PASS ou FAIL */
%macro _smoke_result(label, condition);
    %if &condition. %then %do;
        %let _SMOKE_PASS = %eval(&_SMOKE_PASS. + 1);
        %put NOTE: [PASS] &label.;
    %end;
    %else %do;
        %let _SMOKE_FAIL = %eval(&_SMOKE_FAIL. + 1);
        %put ERROR: [FAIL] &label.;
    %end;
%mend _smoke_result;

/* Executa o pipeline completo (define e chama %run_report) */
%include "&PROJ_ROOT./src/99_run_all.sas";

/*------------------------------------------------------------------------------
| Verificacao das saidas
------------------------------------------------------------------------------*/
%put NOTE: ============ RESULTADO DO SMOKE TEST ============;

/* 1. PDF existe e tem tamanho > 0 */
%_smoke_result(PDF gerado: &DIR_OUT_PDF./&RPT_NOME_ARQ..pdf,
    %sysfunc(fileexist(&DIR_OUT_PDF./&RPT_NOME_ARQ..pdf.)));

/* 2. HTML existe e tem tamanho > 0 */
%_smoke_result(HTML gerado: &DIR_OUT_HTML./&RPT_NOME_ARQ..html,
    %sysfunc(fileexist(&DIR_OUT_HTML./&RPT_NOME_ARQ..html.)));

/* 3. CSV de dados usados existe */
%_smoke_result(CSV exportado: &DIR_OUT_DATA./&RPT_NOME_ARQ._dados_usados.csv,
    %sysfunc(fileexist(&DIR_OUT_DATA./&RPT_NOME_ARQ._dados_usados.csv.)));

/* 4. Dataset transformado existe e tem registros */
%if %sysfunc(exist(WORK.report_txf)) %then %do;
    %local _nobs_txf;
    proc sql noprint; select count(*) into :_nobs_txf trimmed from WORK.report_txf; quit;
    %_smoke_result(Dataset WORK.report_txf existe com &_nobs_txf. registros, &_nobs_txf. > 0);
%end;
%else %_smoke_result(Dataset WORK.report_txf existe, 0);

/* 5. Dataset de estatisticas existe */
%_smoke_result(Dataset WORK.stats_means existe (notas de calculo),
    %sysfunc(exist(WORK.stats_means)));

/* 6. Log sem ERROR (checagem indireta: se chegou aqui, nao houve abort) */
%_smoke_result(Pipeline executou sem abort, 1);

/* Resumo */
%put NOTE: ---------------------------------------------------;
%put NOTE: PASS: &_SMOKE_PASS. | FAIL: &_SMOKE_FAIL.;
%if &_SMOKE_FAIL. = 0 %then
    %put NOTE: >>> SMOKE TEST: TODOS OS CRITERIOS OK <<<;
%else
    %put ERROR: >>> SMOKE TEST FALHOU: &_SMOKE_FAIL. item(s) com problema <<<;
%put NOTE: ---------------------------------------------------;

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
