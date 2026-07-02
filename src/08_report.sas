/*==============================================================================
| Arquivo : src/08_report.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Monta e emite o relatorio final nos DOIS destinos simultaneos:
|            ODS PDF e ODS HTML5. Tudo que for gerado entre %open_report e
|            %close_report (tabela + graficos + notas) sai identico nos dois.
|            O HTML5 usa SVG inline (self-contained), ideal para incorporar em
|            plataformas web.
| Entradas : &DIR_OUT_PDF, &DIR_OUT_HTML, &RPT_NOME_ARQ, &OPT_TITULO,
|            &OPT_SUBTITULO, &OPT_RODAPE, &IMG_FMT; WORK.stats_means.
| Saidas   : output/pdf/<nome>.pdf e output/html/<nome>.html.
| Depende  : m_utils.
==============================================================================*/

/*------------------------------------------------------------------------------
| Abre os dois destinos ODS e imprime o cabecalho do relatorio.
------------------------------------------------------------------------------*/
%macro open_report;

    /* Fecha destinos residuais e liga graficos incorporaveis */
    ods _all_ close;
    ods graphics on / imagefmt=&IMG_FMT. width=9in;

    ods pdf file="&DIR_OUT_PDF./&RPT_NOME_ARQ..pdf"
        style=journal startpage=no notoc;

    ods html5 path="&DIR_OUT_HTML."
        file="&RPT_NOME_ARQ..html"
        style=htmlblue
        options(svg_mode="inline");

    /* Cabecalho comum aos dois destinos */
    title  j=center height=14pt "&OPT_TITULO.";
    title2 j=center height=10pt color=gray "&OPT_SUBTITULO.";
    footnote j=left height=8pt color=gray "&OPT_RODAPE.";

    %log_info(Relatorio aberto (PDF + HTML5). Base do arquivo: &RPT_NOME_ARQ.);

%mend open_report;

/*------------------------------------------------------------------------------
| Notas de calculo: le WORK.stats_means e escreve um paragrafo formatado.
------------------------------------------------------------------------------*/
%macro make_notes;

    %if not %sysfunc(exist(WORK.stats_means)) %then %return;

    %local v_media v_mediana v_desvio v_min v_max v_total v_qtd;
    proc sql noprint;
        select put(media,   comma14.2),
               put(mediana, comma14.2),
               put(desvio,  comma14.2),
               put(minimo,  comma14.2),
               put(maximo,  comma14.2),
               put(total,   comma14.2),
               put(qtd,     comma12.0)
          into :v_media, :v_mediana, :v_desvio, :v_min, :v_max, :v_total, :v_qtd
          from WORK.stats_means;
    quit;

    ods text="^{style [fontweight=bold fontsize=11pt] Notas de calculo (&STAT_MEASURE.):}";
    ods text="Registros: &v_qtd. | Total: &v_total. | Media: &v_media. | Mediana: &v_mediana. | Desvio-padrao: &v_desvio. | Minimo: &v_min. | Maximo: &v_max.";
    ods text="^{style [fontsize=8pt color=gray] Estatisticas calculadas sobre os dados apos filtros e selecao de colunas definidos no report_spec.}";

    %log_info(Notas de calculo inseridas no relatorio.);

%mend make_notes;

/*------------------------------------------------------------------------------
| Fecha os dois destinos ODS.
------------------------------------------------------------------------------*/
%macro close_report;

    ods pdf close;
    ods html5 close;
    ods graphics off;
    title;
    footnote;

    %log_info(Relatorio finalizado: &DIR_OUT_PDF./&RPT_NOME_ARQ..pdf e
              &DIR_OUT_HTML./&RPT_NOME_ARQ..html);

%mend close_report;

/* Fim de 08_report.sas */
