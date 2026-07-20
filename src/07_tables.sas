/*==============================================================================
| Arquivo : src/07_tables.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Monta a tabela formatada do relatorio. Gera um resumo agregado por
|            categoria (soma da medida) via PROC REPORT, com rotulos pt-BR (que
|            vem do LABEL aplicado em 03_transform) e uma linha de total geral.
| Entradas : &TXF_DS, &STAT_GROUP (categoria), &STAT_MEASURE (medida).
| Saidas   : tabela enviada aos destinos ODS abertos (PDF + HTML5).
| Depende  : m_utils.
==============================================================================*/

%macro make_tables;

    %if %superq(STAT_GROUP) = or %superq(STAT_MEASURE) = %then %do;
        /* Sem grupo/medida definidos: lista as primeiras linhas como fallback */
        title j=center height=12pt "&OPT_TITULO.";
        proc report data=&TXF_DS.(obs=50) nowd
            style(header)=[background=cx1f3864 color=white fontweight=bold];
            columns &KEEP_VARS.;
        run;
        title;
        %return;
    %end;

    proc report data=&TXF_DS. nowd
        style(header) =[background=cx1f3864 color=white fontweight=bold]
        style(column) =[fontsize=10pt]
        style(summary)=[background=cxdbe5f1 fontweight=bold];

        columns &STAT_GROUP. &STAT_MEASURE.;

        define &STAT_GROUP.   / group order=data;
        define &STAT_MEASURE. / analysis sum format=comma14.2;

        rbreak after / summarize style=[background=cxdbe5f1 fontweight=bold];
        compute after;
            &STAT_GROUP. = 'TOTAL GERAL';
        endcomp;
    run;

    %if &SYSERR. > 6 %then
        %abortar(Falha ao montar a tabela (PROC REPORT). Verifique grupo/medida.);

    %log_info(Tabela-resumo montada por "&STAT_GROUP." (soma de "&STAT_MEASURE.").);

%mend make_tables;

/* Fim de 07_tables.sas */
