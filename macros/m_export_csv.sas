/*==============================================================================
| Arquivo : macros/m_export_csv.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Exporta para .csv o conjunto de dados efetivamente usado no
|            relatorio (apos filtros e selecao de colunas), para auditoria/reuso.
| Entradas : &TXF_DS (dataset transformado), &DIR_OUT_DATA, &RPT_NOME_ARQ.
| Saidas   : output/data/<nome>_dados_usados.csv
| Depende  : m_utils (%log_info).
==============================================================================*/

%macro export_used_data;

    %local out_csv;
    %let out_csv = &DIR_OUT_DATA./&RPT_NOME_ARQ._dados_usados.csv;

    proc export data=&TXF_DS.
        outfile="&out_csv."
        dbms=csv replace;
    run;

    %if &SYSERR. > 6 %then
        %abortar(Falha ao exportar o CSV de dados usados em &out_csv..);

    %log_info(Dados usados exportados em: &out_csv.);

%mend export_used_data;

/* Fim de m_export_csv.sas */
