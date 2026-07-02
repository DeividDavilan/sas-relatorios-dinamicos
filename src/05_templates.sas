/*==============================================================================
| Arquivo : src/05_templates.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Define templates de grafico REUTILIZAVEIS via PROC TEMPLATE (GTL).
|            O template de barras (bar_tpl) e parametrizado por variaveis
|            dinamicas (eixo, medida, titulo e escala), preenchidas em tempo de
|            execucao pelo PROC SGRENDER em 06_viz. Compila uma vez; reusa em
|            todos os graficos de barra do relatorio.
| Entradas : nenhuma (definicao de template).
| Saidas   : template statgraph "bar_tpl" no store de templates da sessao.
| Depende  : m_utils.
==============================================================================*/

%macro build_templates;

    proc template;
        define statgraph bar_tpl;
            /* Variaveis dinamicas preenchidas pelo SGRENDER em runtime */
            dynamic _x _y _title _ymin _ymax;
            begingraph;
                entrytitle _title;
                layout overlay /
                    xaxisopts=(display=(line ticks tickvalues label))
                    yaxisopts=(linearopts=(viewmin=_ymin viewmax=_ymax));
                    barchart x=_x y=_y / stat=sum
                        datalabel
                        fillattrs=(color=cx1f77b4);
                endlayout;
            endgraph;
        end;
    run;

    %if &SYSERR. > 6 %then
        %abortar(Falha ao compilar o template GTL bar_tpl (PROC TEMPLATE).);

    %log_info(Template GTL "bar_tpl" compilado e disponivel para reuso.);

%mend build_templates;

/* Fim de 05_templates.sas */
