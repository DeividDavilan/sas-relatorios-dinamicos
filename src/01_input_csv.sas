/*==============================================================================
| Arquivo : src/01_input_csv.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Fonte CSV local. Le o arquivo apontado por &CSV_PATH e entrega o
|            contrato unico da camada de input: o dataset &SRC_DS.
| Entradas : &CSV_PATH (caminho do CSV), &SRC_DS (nome do dataset de saida).
| Saidas   : &SRC_DS (WORK.report_src).
| Obs      : GUESSINGROWS=MAX evita erro de tipo em colunas longas. O CSV deve
|            usar ponto decimal e datas ISO (YYYY-MM-DD) para inferencia correta.
==============================================================================*/

%macro input_csv;

    %if %sysfunc(fileexist(&CSV_PATH.)) = 0 %then
        %abortar(Arquivo CSV nao encontrado: &CSV_PATH.. Ajuste CSV_PATH em config.sas.);

    proc import datafile="&CSV_PATH."
        out=&SRC_DS.
        dbms=csv replace;
        guessingrows=max;
        getnames=yes;
    run;

    %if &SYSERR. > 6 %then
        %abortar(Falha ao importar o CSV &CSV_PATH.. Verifique o formato do arquivo.);

    %log_info(Fonte CSV lida: &CSV_PATH. -> &SRC_DS.);

%mend input_csv;

/* Fim de 01_input_csv.sas */
