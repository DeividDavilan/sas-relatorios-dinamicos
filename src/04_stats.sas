/*==============================================================================
| Arquivo : src/04_stats.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Calcula as estatisticas que viram as "notas de calculo" do
|            relatorio: media, mediana, desvio, min/max e contagem (PROC MEANS)
|            sobre a variavel de medida, e a distribuicao por categoria
|            (PROC FREQ). Guarda tudo em datasets stats_* consumidos pelo
|            relatorio (08_report) e pelas tabelas.
| Entradas : &TXF_DS, &STAT_MEASURE (medida numerica), &STAT_GROUP (categoria).
| Saidas   : WORK.stats_means, WORK.stats_freq.
| Depende  : m_utils.
==============================================================================*/

%macro run_stats;

    %if %superq(STAT_MEASURE) = %then %do;
        %log_warn(Sem variavel de medida definida; etapa de estatisticas ignorada.);
        %return;
    %end;

    /* Media, mediana, desvio, extremos e contagem da variavel de medida */
    proc means data=&TXF_DS. noprint;
        var &STAT_MEASURE.;
        output out=WORK.stats_means (drop=_TYPE_ _FREQ_)
            n=qtd mean=media median=mediana std=desvio
            min=minimo max=maximo sum=total;
    run;

    %if &SYSERR. > 6 %then
        %abortar(Falha em PROC MEANS sobre "&STAT_MEASURE.". Verifique o tipo da coluna.);

    /* Distribuicao por categoria (alimenta tabela/graficos de participacao) */
    %if %superq(STAT_GROUP) ne %then %do;
        proc freq data=&TXF_DS. noprint;
            tables &STAT_GROUP. / out=WORK.stats_freq (drop=percent) nocum;
        run;
    %end;

    %log_info(Estatisticas calculadas sobre "&STAT_MEASURE." (WORK.stats_means / stats_freq).);

%mend run_stats;

/* Fim de 04_stats.sas */
