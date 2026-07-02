/*==============================================================================
| Arquivo : src/03_transform.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Aplica a especificacao do relatorio sobre a fonte: seleciona as
|            colunas pedidas (KEEP), aplica os filtros (WHERE) e atribui os
|            rotulos pt-BR (LABEL). Produz o dataset &TXF_DS usado por stats,
|            viz, tabelas e exportacao.
| Entradas : &SRC_DS, &KEEP_VARS, &WHERE_CLAUSE, &COL_LABELS.
| Saidas   : &TXF_DS (WORK.report_txf).
| Depende  : m_utils; a validacao (m_validate) ja rodou antes deste passo.
==============================================================================*/

%macro transform;

    data &TXF_DS.;
        set &SRC_DS. (keep=&KEEP_VARS.);
        %if %superq(WHERE_CLAUSE) ne %then %do;
        where &WHERE_CLAUSE.;
        %end;
        %if %superq(COL_LABELS) ne %then %do;
        label &COL_LABELS.;
        %end;
    run;

    %if &SYSERR. > 6 %then
        %abortar(Falha ao aplicar selecao de colunas/filtros. Confira nomes de
                 colunas e a sintaxe dos filtros no report_spec.csv.);

    /* Aviso se o filtro zerou o dataset (dado valido, mas relatorio vazio) */
    %local n_txf;
    proc sql noprint;
        select count(*) into :n_txf trimmed from &TXF_DS.;
    quit;
    %if &n_txf. = 0 %then
        %abortar(Apos aplicar os filtros (&WHERE_CLAUSE.) nao sobrou nenhum
                 registro. Revise os filtros no report_spec.csv.);

    %log_info(Transformacao concluida: &TXF_DS. com &n_txf. registros e colunas [&KEEP_VARS.].);

%mend transform;

/* Fim de 03_transform.sas */
