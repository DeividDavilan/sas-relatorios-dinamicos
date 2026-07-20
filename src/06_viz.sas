/*==============================================================================
| Arquivo : src/06_viz.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Gera os graficos definidos no report_spec. Percorre os N graficos
|            e renderiza cada um conforme o tipo: barras (via template GTL
|            reutilizavel bar_tpl + PROC SGRENDER), linha (PROC SGPLOT) e pizza
|            (PROC SGPIE, com fallback para barras % via PROC SGPLOT quando o
|            SGPIE nao estiver habilitado). Suporta ajuste dinamico de escala.
| Entradas : &N_GRAF e, por grafico i: &&GRAF_TIPO&i &&GRAF_CAT&i &&GRAF_MED&i
|            &&GRAF_STAT&i &&GRAF_TIT&i &&GRAF_MIN&i &&GRAF_MAX&i; &TXF_DS.
| Saidas   : graficos enviados aos destinos ODS abertos (PDF + HTML5).
| Depende  : 05_templates (bar_tpl), m_utils.
==============================================================================*/

/*------------------------------------------------------------------------------
| Renderiza UM grafico (indice i).
------------------------------------------------------------------------------*/
%macro one_chart(i);

    %local tipo cat med stat titulo vmin vmax dmin dmax stat_up yscale;
    %let tipo   = &&GRAF_TIPO&i.;
    %let cat    = &&GRAF_CAT&i.;
    %let med    = &&GRAF_MED&i.;
    %let stat   = &&GRAF_STAT&i.;
    %let titulo = &&GRAF_TIT&i.;
    %let vmin   = &&GRAF_MIN&i.;
    %let vmax   = &&GRAF_MAX&i.;

    /* Mapeia estatistica do spec para a palavra-chave do SAS */
    %if      &stat. = mean %then %let stat_up = MEAN;
    %else %if &stat. = freq %then %let stat_up = FREQ;
    %else                        %let stat_up = SUM;

    /* Clausula de escala para SGPLOT (so aplica o que veio do spec) */
    %let yscale =;
    %if %superq(vmin) ne %then %let yscale = &yscale. min=&vmin.;
    %if %superq(vmax) ne %then %let yscale = &yscale. max=&vmax.;

    /* ---------------- BARRAS: template GTL reutilizavel ---------------- */
    %if &tipo. = bar %then %do;
        %let dmin = %superq(vmin);
        %let dmax = %superq(vmax);

        proc sgrender data=&TXF_DS. template=bar_tpl;
            dynamic _x="&cat." _y="&med." _title="&titulo."
                    %if &dmin. ne %then %do; _ymin=&dmin.; %end;
                    %if &dmax. ne %then %do; _ymax=&dmax.; %end;
        run;
    %end;

    /* ---------------- LINHA ---------------- */
    %else %if &tipo. = line %then %do;
        proc sgplot data=&TXF_DS.;
            title "&titulo.";
            vline &cat. / response=&med. stat=&stat_up. markers
                          lineattrs=(thickness=2 color=cx1f77b4);
            %if %superq(yscale) ne %then %do;
            yaxis &yscale. grid;
            %end;
            %else %do;
            yaxis grid;
            %end;
        run;
        title;
    %end;

    /* ---------------- PIZZA (com fallback) ---------------- */
    %else %if &tipo. = pie %then %do;
        %if %lowcase(&PIE_ENGINE.) = sgpie %then %do;
            proc sgpie data=&TXF_DS.;
                title "&titulo.";
                pie &cat. / response=&med. datalabeldisplay=(category percent);
            run;
            title; /* limpa title apos SGPIE */
        %end;
        %else %do;
            /* Fallback: participacao como barras horizontais com % */
            proc sgplot data=&TXF_DS.;
                title "&titulo. (participacao)";
                hbar &cat. / response=&med. stat=&stat_up.
                             categoryorder=respdesc datalabel;
                xaxis grid label="&med.";
            run;
            title; /* limpa title apos SGPLOT fallback */
        %end;
    %end;

    /* ---------------- Tipo desconhecido ---------------- */
    %else %do;
        %log_warn(Tipo de grafico desconhecido "&tipo." (grafico &i.) — ignorado.);
    %end;

%mend one_chart;

/*------------------------------------------------------------------------------
| Renderiza TODOS os graficos do spec, na ordem.
------------------------------------------------------------------------------*/
%macro make_viz;

    %if &N_GRAF. = 0 %then %do;
        %log_warn(Nenhum grafico definido no report_spec. Relatorio sem visualizacoes.);
        %return;
    %end;

    %local i;
    %do i = 1 %to &N_GRAF.;
        %one_chart(&i.);
    %end;

    %log_info(&N_GRAF. grafico(s) renderizado(s).);

%mend make_viz;

/* Fim de 06_viz.sas */
