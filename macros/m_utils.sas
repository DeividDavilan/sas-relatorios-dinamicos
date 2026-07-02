/*==============================================================================
| Arquivo : macros/m_utils.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Helpers reutilizaveis do pipeline:
|            - %log_info / %log_warn / %log_erro : log padronizado em pt-BR
|            - %abortar                          : aborta o pipeline de forma controlada
|            - %load_report_spec                 : le config/report_spec.csv e cria
|                                                  as macro vars globais que dirigem
|                                                  colunas, filtros, graficos e titulos.
| Entradas : &REPORT_SPEC (caminho do CSV de spec), definido em config.sas.
| Saidas   : macro vars globais (ver %load_report_spec).
==============================================================================*/

/*------------------------------------------------------------------------------
| Log padronizado. Prefixos facilitam a leitura do log do SAS Studio.
------------------------------------------------------------------------------*/
%macro log_info(msg);
    %put NOTE- [RELATORIO] &msg.;
%mend log_info;

%macro log_warn(msg);
    %put WARNING: [RELATORIO] &msg.;
%mend log_warn;

%macro log_erro(msg);
    %put ERROR: [RELATORIO] &msg.;
%mend log_erro;

/*------------------------------------------------------------------------------
| Aborta o pipeline de forma controlada, com mensagem clara.
| Em modo batch/programa, ABORT CANCEL interrompe a submissao sem derrubar a
| sessao inteira do SAS Studio.
------------------------------------------------------------------------------*/
%macro abortar(msg);
    %log_erro(&msg.);
    %log_erro(Pipeline interrompido. Corrija a causa acima e rode novamente.);
    %abort cancel;
%mend abortar;

/*------------------------------------------------------------------------------
| %require_env(nome_var_ambiente, macro_var_ja_lida)
| Garante que uma credencial lida de variavel de ambiente (via %sysget no
| config.sas) nao esta vazia. %sysget de variavel inexistente retorna vazio
| (com WARNING), entao esta checagem e obrigatoria antes de usar credenciais.
------------------------------------------------------------------------------*/
%macro require_env(env_name, mvar);
    %if %superq(&mvar.) = %then %do;
        %abortar(Variavel de ambiente %upcase(&env_name) nao definida no SAS Viya.
                 Defina-a (ex.: export &env_name=...) antes de iniciar a sessao.);
    %end;
%mend require_env;

/*------------------------------------------------------------------------------
| %load_report_spec
| Le o report_spec.csv e materializa as diretrizes em macro vars globais:
|   Colunas : &KEEP_VARS      (lista separada por espaco)
|             &COL_LABELS     (trecho pronto para statement LABEL)
|             &N_COLS
|   Filtros : &WHERE_CLAUSE   (expressoes unidas por " and "; vazio se nao houver)
|   Opcoes  : &OPT_TITULO &OPT_SUBTITULO &OPT_RODAPE (sobrepoem os defaults do config)
|   Graficos: &N_GRAF e, para i=1..&N_GRAF:
|             &&GRAF_TIPO&i  (bar|pie|line)
|             &&GRAF_CAT&i   (variavel de categoria / eixo X)
|             &&GRAF_MED&i   (variavel de medida / eixo Y)
|             &&GRAF_STAT&i  (sum|mean|freq)
|             &&GRAF_TIT&i   (titulo do grafico)
|             &&GRAF_MIN&i / &&GRAF_MAX&i (escala do eixo; vazio = automatico)
------------------------------------------------------------------------------*/
%macro load_report_spec;

    %global KEEP_VARS COL_LABELS N_COLS WHERE_CLAUSE
            OPT_TITULO OPT_SUBTITULO OPT_RODAPE N_GRAF
            STAT_MEASURE STAT_GROUP;

    /* Importa o spec como texto (todas as colunas como caractere) */
    %if %sysfunc(fileexist(&REPORT_SPEC.)) = 0 %then %do;
        %abortar(Arquivo de spec nao encontrado: &REPORT_SPEC.);
    %end;

    data _spec;
        length secao $12 p1 p2 p3 p4 p5 $256 escala_min escala_max $32;
        infile "&REPORT_SPEC." dsd firstobs=2 truncover;
        input secao $ p1 $ p2 $ p3 $ p4 $ p5 $ escala_min $ escala_max $;
    run;

    /* Defaults herdados do config; podem ser sobrepostos por linhas 'opcao' */
    %let OPT_TITULO    = &RPT_TITULO.;
    %let OPT_SUBTITULO = &RPT_SUBTITULO.;
    %let OPT_RODAPE    = &RPT_RODAPE.;

    /* ---- Opcoes (titulo/subtitulo/rodape) ---- */
    data _null_;
        set _spec(where=(lowcase(secao)='opcao'));
        chave = lowcase(strip(p1));
        valor = strip(p2);
        if      chave = 'titulo'    then call symputx('OPT_TITULO',    valor, 'G');
        else if chave = 'subtitulo' then call symputx('OPT_SUBTITULO', valor, 'G');
        else if chave = 'rodape'    then call symputx('OPT_RODAPE',    valor, 'G');
    run;

    /* ---- Colunas: KEEP list + LABEL statement ---- */
    proc sql noprint;
        select strip(p1)
            into :KEEP_VARS separated by ' '
            from _spec
            where lowcase(secao) = 'coluna';
        select count(*) into :N_COLS from _spec where lowcase(secao)='coluna';
    quit;

    data _null_;
        length lbls $2000;
        retain lbls '';
        set _spec(where=(lowcase(secao)='coluna')) end=last;
        if not missing(p2) then
            lbls = catx(' ', lbls, cats(strip(p1), "='", strip(p2), "'"));
        if last then call symputx('COL_LABELS', lbls, 'G');
    run;

    /* ---- Filtros: combina em uma unica clausula WHERE ---- */
    proc sql noprint;
        select strip(p1)
            into :WHERE_CLAUSE separated by ' and '
            from _spec
            where lowcase(secao) = 'filtro' and not missing(p1);
    quit;

    /* ---- Graficos: um conjunto de macro vars por grafico ---- */
    data _null_;
        set _spec(where=(lowcase(secao)='grafico')) end=last;
        i + 1;
        call symputx(cats('GRAF_TIPO', i), lowcase(strip(p1)), 'G');
        call symputx(cats('GRAF_CAT',  i), strip(p2),          'G');
        call symputx(cats('GRAF_MED',  i), strip(p3),          'G');
        call symputx(cats('GRAF_STAT', i), lowcase(strip(p4)), 'G');
        call symputx(cats('GRAF_TIT',  i), strip(p5),          'G');
        call symputx(cats('GRAF_MIN',  i), strip(escala_min),  'G');
        call symputx(cats('GRAF_MAX',  i), strip(escala_max),  'G');
        if last then call symputx('N_GRAF', i, 'G');
    run;
    %if not %symexist(N_GRAF) %then %let N_GRAF = 0;
    %if &N_GRAF = %then %let N_GRAF = 0;

    /* Declara os slots de grafico como globais (evita warning de resolucao) */
    %local i;
    %do i = 1 %to &N_GRAF;
        %global GRAF_TIPO&i GRAF_CAT&i GRAF_MED&i GRAF_STAT&i GRAF_TIT&i GRAF_MIN&i GRAF_MAX&i;
    %end;

    /* ---- Variaveis-alvo das estatisticas (notas de calculo) ----
       Inferidas do 1o grafico: medida = eixo Y; grupo = categoria/eixo X.
       Podem ser sobrepostas definindo STAT_MEASURE/STAT_GROUP antes de rodar. */
    %if &N_GRAF >= 1 %then %do;
        %if %superq(STAT_MEASURE) = %then %let STAT_MEASURE = &GRAF_MED1.;
        %if %superq(STAT_GROUP)   = %then %let STAT_GROUP   = &GRAF_CAT1.;
    %end;

    %log_info(Spec carregado: &N_COLS colunas e &N_GRAF graficos.);
    %log_info(Estatisticas sobre: medida=&STAT_MEASURE. grupo=&STAT_GROUP.);
    %log_info(Colunas: &KEEP_VARS.);
    %if %length(&WHERE_CLAUSE.) %then %log_info(Filtro: &WHERE_CLAUSE.);
    %else %log_info(Filtro: (nenhum));

%mend load_report_spec;

/* Fim de m_utils.sas */
