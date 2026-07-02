/*===============================================================================
| oda_bundle_install.sas  —  INSTALADOR AUTOSSUFICIENTE (SAS OnDemand / Studio)
| Projeto: Relatorios Dinamicos Responsivos via SAS
| Cole este arquivo INTEIRO no SAS Studio e clique em Run (F3).
| Ele recria o projeto no seu HOME e roda o teste de fumaca. Nao usa internet.
==============================================================================*/
%let HOME_DIR = %sysget(HOME);
%if %superq(HOME_DIR)= %then %let HOME_DIR = %sysfunc(pathname(WORK));
%global PROJ_ROOT;
%let PROJ_ROOT = &HOME_DIR./sas-relatorios-dinamicos;

%macro _mkd(p);
  %if %sysfunc(fileexist(&p.))=0 %then %do;
    %let _rc=%sysfunc(dcreate(%scan(&p.,-1,/),%substr(&p.,1,%eval(%length(&p.)-%length(%scan(&p.,-1,/))-1))));
  %end;
%mend _mkd;

%_mkd(&PROJ_ROOT.);
%_mkd(&PROJ_ROOT./config);
%_mkd(&PROJ_ROOT./macros);
%_mkd(&PROJ_ROOT./src);
%_mkd(&PROJ_ROOT./data);
%_mkd(&PROJ_ROOT./tests);
%_mkd(&PROJ_ROOT./data/sample);

data _null_; file "&PROJ_ROOT./config/config.sas" lrecl=32767; input; put _infile_; datalines4;
/*==============================================================================
| Arquivo : config/config.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Configuracao central do pipeline. Define TODAS as macro vars
|            globais que controlam o comportamento do relatorio. O usuario
|            edita ESTE arquivo (e o report_spec.csv) — nunca o codigo dos
|            modulos.
| Entradas : variaveis de ambiente (para credenciais de API/DB), via %sysget.
| Saidas   : macro vars globais no ambiente SAS.
| Ambiente : SAS Viya / SAS Studio (nuvem).
| Obs      : Nenhuma credencial e hardcoded aqui. Ver bloco "CREDENCIAIS".
==============================================================================*/

/*------------------------------------------------------------------------------
| 1. RAIZ DO PROJETO
|    Ajuste PROJ_ROOT para o caminho onde o projeto foi carregado no SAS Viya.
|    Ex.: /home/seu.usuario/sas-relatorios-dinamicos
|    Todos os demais caminhos derivam deste.
------------------------------------------------------------------------------*/
%if not %symexist(PROJ_ROOT) %then %global PROJ_ROOT;
%if %superq(PROJ_ROOT) = %then
    %let PROJ_ROOT = /home/student/sas-relatorios-dinamicos;

%let DIR_CONFIG = &PROJ_ROOT./config;
%let DIR_SRC    = &PROJ_ROOT./src;
%let DIR_MACROS = &PROJ_ROOT./macros;
%let DIR_DATA   = &PROJ_ROOT./data;
%let DIR_OUT    = &PROJ_ROOT./output;
%let DIR_OUT_PDF  = &DIR_OUT./pdf;
%let DIR_OUT_HTML = &DIR_OUT./html;
%let DIR_OUT_DATA = &DIR_OUT./data;

/*------------------------------------------------------------------------------
| 2. FONTE DE DADOS (plugavel)
|    SOURCE_TYPE controla qual modulo de input o dispatcher (02_ingest) usa.
|    Valores validos: csv | api | db
|    v1 valida com csv.
------------------------------------------------------------------------------*/
%let SOURCE_TYPE = csv;

/* --- Fonte CSV --- */
%let CSV_PATH = &DIR_DATA./sample/vendas_exemplo.csv;

/* --- Fonte API (JSON) --- */
%let API_URL     = ;                     /* endpoint completo, ex.: https://api.exemplo.com/vendas */
%let API_METHOD  = GET;                   /* GET | POST */

/* --- Fonte DB (LIBNAME ODBC/POSTGRES) --- */
%let DB_ENGINE   = postgres;              /* postgres | odbc | ... */
%let DB_SERVER   = ;                      /* host do banco */
%let DB_PORT     = 5432;
%let DB_DATABASE = ;
%let DB_SCHEMA   = public;
%let DB_TABLE    = vendas;                /* tabela/consulta de origem */

/*------------------------------------------------------------------------------
| 3. CREDENCIAIS  (SOMENTE via variaveis de ambiente — NUNCA hardcoded)
|    Defina no shell do SAS Viya antes de iniciar a sessao, ex.:
|       export DB_USER=meu_usuario
|       export DB_PASSWORD=minha_senha
|       export API_TOKEN=xxxxx
|    %sysget le a variavel de ambiente. Se ausente, fica em branco e o
|    modulo de input correspondente aborta com mensagem clara (m_validate).
------------------------------------------------------------------------------*/
%let DB_USER     = %sysget(DB_USER);
%let DB_PASSWORD = %sysget(DB_PASSWORD);
%let API_TOKEN   = %sysget(API_TOKEN);

/*------------------------------------------------------------------------------
| 4. DATASET-ALVO (contrato unico entre input e o resto do pipeline)
|    Qualquer que seja a fonte, o dispatcher SEMPRE entrega WORK.report_src.
------------------------------------------------------------------------------*/
%let SRC_DS = WORK.report_src;

/* Dataset apos transformacao (filtros + selecao de colunas). Usado por
   04_stats, 06_viz, 07_tables e exportado por m_export_csv. */
%let TXF_DS = WORK.report_txf;

/*------------------------------------------------------------------------------
| 5. SPEC DO RELATORIO
|    Caminho do arquivo de configuracao do relatorio (colunas, filtros,
|    graficos, titulos, escalas). Ver docs/COMO_CONFIGURAR.md.
------------------------------------------------------------------------------*/
%let REPORT_SPEC = &DIR_CONFIG./report_spec.csv;

/*------------------------------------------------------------------------------
| 6. IDENTIDADE DO RELATORIO (titulos default, sobrepostos pelo spec)
------------------------------------------------------------------------------*/
%let RPT_TITULO    = Relatorio Dinamico de Vendas;
%let RPT_SUBTITULO = Gerado automaticamente pelo pipeline SAS;
%let RPT_RODAPE    = Fonte: dados internos | Elaboracao: pipeline SAS Viya;
%let RPT_NOME_ARQ  = relatorio_vendas;   /* nome-base dos arquivos de saida */

/* Motor do grafico de pizza. PROC SGPIE ja foi experimental em algumas
   versoes do SAS; se nao estiver habilitado no seu Viya, troque para
   'sgplot' e o pipeline desenha a participacao como barras horizontais %. */
%let PIE_ENGINE = sgpie;                  /* sgpie | sgplot */

/* Formato das imagens dos graficos: svg = nitido e incorporavel (recomendado). */
%let IMG_FMT = svg;

/*------------------------------------------------------------------------------
| 7. OPCOES DE SESSAO
------------------------------------------------------------------------------*/
options
    validvarname = v7      /* nomes de coluna compativeis / previsiveis */
    mprint                 /* expande macros no log (auditoria) */
    nodate nonumber        /* saida limpa no ODS */
    msglevel = i           /* mensagens informativas no log */
;

/* Fim de config.sas */
;;;;
run;

data _null_; file "&PROJ_ROOT./config/report_spec.csv" lrecl=32767; input; put _infile_; datalines4;
secao,p1,p2,p3,p4,p5,escala_min,escala_max
opcao,titulo,Relatorio Dinamico de Vendas - 1o Bimestre 2026,,,,,
opcao,subtitulo,Analise de faturamento por categoria e regiao,,,,,
opcao,rodape,Fonte: base interna de vendas | Pipeline SAS Viya,,,,,
coluna,produto,Produto,,,,,
coluna,categoria,Categoria,,,,,
coluna,regiao,Regiao,,,,,
coluna,valor,Valor (R$),,,,,
coluna,quantidade,Quantidade,,,,,
coluna,data,Data,,,,,
filtro,valor > 0,,,,,,
grafico,bar,categoria,valor,sum,Faturamento por Categoria (R$),0,
grafico,pie,regiao,valor,sum,Participacao no Faturamento por Regiao,,
grafico,line,data,valor,sum,Evolucao do Faturamento no Periodo,0,
;;;;
run;

data _null_; file "&PROJ_ROOT./macros/m_utils.sas" lrecl=32767; input; put _infile_; datalines4;
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
;;;;
run;

data _null_; file "&PROJ_ROOT./macros/m_validate.sas" lrecl=32767; input; put _infile_; datalines4;
/*==============================================================================
| Arquivo : macros/m_validate.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Tratamento de erros de dados. Barra problemas ANTES de gerar o
|            relatorio, para nunca produzir uma saida silenciosamente errada.
|            Checa: (a) dataset vazio, (b) colunas do spec ausentes na fonte,
|            (c) tipo incompativel (medida das estatisticas deve ser numerica).
| Entradas : &SRC_DS (dataset da ingestao), &KEEP_VARS, &STAT_MEASURE.
| Saidas   : nenhuma; aborta via %abortar (m_utils) se algo estiver errado.
| Depende  : m_utils (%abortar, %log_info).
==============================================================================*/

%macro validate_src;

    %local nobs dsid rc i col varn vtype;

    /* ---- (a) Dataset deve existir e ter linhas ---- */
    %if not %sysfunc(exist(&SRC_DS.)) %then
        %abortar(A ingestao nao produziu o dataset &SRC_DS.. Verifique a fonte de dados.);

    proc sql noprint;
        select count(*) into :nobs trimmed from &SRC_DS.;
    quit;

    %if &nobs. = 0 %then
        %abortar(A fonte de dados retornou 0 registros. O relatorio nao sera gerado.);

    /* ---- (b) e (c): colunas do KEEP existem e medida e numerica ---- */
    %let dsid = %sysfunc(open(&SRC_DS.));
    %if &dsid. = 0 %then
        %abortar(Nao foi possivel abrir &SRC_DS. para validacao. Verifique a ingestao.);

    /* (b) todas as colunas pedidas no spec existem na fonte? */
    %do i = 1 %to %sysfunc(countw(&KEEP_VARS.));
        %let col  = %scan(&KEEP_VARS., &i.);
        %let varn = %sysfunc(varnum(&dsid., &col.));
        %if &varn. = 0 %then %do;
            %let rc = %sysfunc(close(&dsid.));
            %abortar(A coluna "&col." definida no report_spec nao existe na fonte de dados.
                     Corrija o report_spec.csv ou a origem.);
        %end;
    %end;

    /* (c) a variavel de medida das estatisticas precisa ser numerica */
    %if %superq(STAT_MEASURE) ne %then %do;
        %let varn = %sysfunc(varnum(&dsid., &STAT_MEASURE.));
        %if &varn. > 0 %then %do;
            %let vtype = %sysfunc(vartype(&dsid., &varn.));
            %if &vtype. = C %then %do;
                %let rc = %sysfunc(close(&dsid.));
                %abortar(A coluna de medida "&STAT_MEASURE." deveria ser numerica
                         mas veio como texto. Ajuste a fonte/transformacao de tipos.);
            %end;
        %end;
    %end;

    %let rc = %sysfunc(close(&dsid.));

    %log_info(Validacao OK: &SRC_DS. tem &nobs. registros; colunas e tipos conferidos.);

%mend validate_src;

/* Fim de m_validate.sas */
;;;;
run;

data _null_; file "&PROJ_ROOT./macros/m_export_csv.sas" lrecl=32767; input; put _infile_; datalines4;
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
;;;;
run;

data _null_; file "&PROJ_ROOT./src/00_setup.sas" lrecl=32767; input; put _infile_; datalines4;
/*==============================================================================
| Arquivo : src/00_setup.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Preparar a sessao. Garante que as pastas de saida existam, liga o
|            ODS Graphics e carrega (%include) TODAS as definicoes de macro do
|            pipeline (macros utilitarias, modulos de input e modulos de etapa).
|            Apos rodar este arquivo, todas as %macros do pipeline estao
|            compiladas e prontas para o orquestrador %run_report chamar.
| Entradas : macro vars de config.sas (&DIR_*, caminhos).
| Saidas   : pastas output/{pdf,html,data} garantidas; macros compiladas.
| Obs      : config.sas DEVE ter sido %include-ado antes deste arquivo.
==============================================================================*/

/* Guarda: config.sas precisa ter rodado antes */
%macro _check_config;
    %if not %symexist(PROJ_ROOT) %then %do;
        %put ERROR: config.sas nao foi carregado antes de 00_setup.sas. Rode 99_run_all.sas.;
        %abort cancel;
    %end;
%mend _check_config;
%_check_config;

/*------------------------------------------------------------------------------
| Cria as pastas de saida se nao existirem (ODS nao cria diretorio).
------------------------------------------------------------------------------*/
%macro _ensure_dir(path);
    %if %sysfunc(fileexist(&path.)) = 0 %then %do;
        %let _rc = %sysfunc(dcreate(%scan(&path., -1, /),
                                    %substr(&path., 1, %eval(%length(&path.) - %length(%scan(&path., -1, /)) - 1))));
        %put NOTE: [RELATORIO] Pasta criada: &path.;
    %end;
%mend _ensure_dir;

%_ensure_dir(&DIR_OUT.);
%_ensure_dir(&DIR_OUT_PDF.);
%_ensure_dir(&DIR_OUT_HTML.);
%_ensure_dir(&DIR_OUT_DATA.);

/*------------------------------------------------------------------------------
| ODS Graphics: formato de imagem nitido e incorporavel.
------------------------------------------------------------------------------*/
ods graphics on / imagefmt=&IMG_FMT. width=9in;

/*------------------------------------------------------------------------------
| Carrega as definicoes de macro (nao executam nada aqui, so definem %macro).
| Ordem: utilitarios -> input -> dispatcher -> etapas.
------------------------------------------------------------------------------*/
/* Macros utilitarias e de robustez */
%include "&DIR_MACROS./m_utils.sas";
%include "&DIR_MACROS./m_validate.sas";
%include "&DIR_MACROS./m_export_csv.sas";

/* Modulos de input (cada um define uma %macro input_*) */
%include "&DIR_SRC./01_input_csv.sas";
%include "&DIR_SRC./01_input_api.sas";
%include "&DIR_SRC./01_input_db.sas";

/* Dispatcher e etapas do pipeline (cada um define uma %macro) */
%include "&DIR_SRC./02_ingest.sas";
%include "&DIR_SRC./03_transform.sas";
%include "&DIR_SRC./04_stats.sas";
%include "&DIR_SRC./05_templates.sas";
%include "&DIR_SRC./06_viz.sas";
%include "&DIR_SRC./07_tables.sas";
%include "&DIR_SRC./08_report.sas";

%put NOTE: [RELATORIO] Setup concluido. Modulos e macros carregados.;

/* Fim de 00_setup.sas */
;;;;
run;

data _null_; file "&PROJ_ROOT./src/01_input_csv.sas" lrecl=32767; input; put _infile_; datalines4;
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
;;;;
run;

data _null_; file "&PROJ_ROOT./src/01_input_api.sas" lrecl=32767; input; put _infile_; datalines4;
/*==============================================================================
| Arquivo : src/01_input_api.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Fonte API/JSON. Faz a requisicao HTTP a &API_URL, faz o parse da
|            resposta com o engine JSON e entrega o contrato unico &SRC_DS.
| Entradas : &API_URL, &API_METHOD, &API_TOKEN (via %sysget), &SRC_DS.
| Saidas   : &SRC_DS (WORK.report_src).
| Obs      : O nome da tabela criada pelo engine JSON depende do formato do
|            payload. Ajuste &API_ROOT_TABLE conforme o array de registros da
|            sua API (rode uma vez e inspecione o libname APIDATA no log).
==============================================================================*/

%macro input_api;

    /* Nome da tabela do engine JSON que contem o array de registros.
       Ex.: payload {"data":[...]} -> APIDATA.data. Default = alldata. Ajuste
       definindo %let API_ROOT_TABLE=... em config.sas conforme sua API. */
    %if not %symexist(API_ROOT_TABLE) %then %global API_ROOT_TABLE;
    %if %superq(API_ROOT_TABLE) = %then %let API_ROOT_TABLE = alldata;

    %if %superq(API_URL) = %then
        %abortar(API_URL vazio em config.sas. Informe o endpoint da API.);

    /* Token e opcional (APIs publicas nao exigem). Se sua API exige, defina a
       variavel de ambiente API_TOKEN antes da sessao. */

    filename _resp temp;

    proc http
        url="&API_URL."
        method="&API_METHOD."
        out=_resp;
        %if %superq(API_TOKEN) ne %then %do;
        headers "Authorization" = "Bearer &API_TOKEN."
                "Accept" = "application/json";
        %end;
        %else %do;
        headers "Accept" = "application/json";
        %end;
    run;

    %if &SYS_PROCHTTP_STATUS_CODE. ne 200 %then
        %abortar(A API retornou status &SYS_PROCHTTP_STATUS_CODE. (&SYS_PROCHTTP_STATUS_PHRASE.).
                 Verifique URL, metodo e credenciais.);

    libname apidata JSON fileref=_resp;

    data &SRC_DS.;
        set apidata.&API_ROOT_TABLE.;
    run;

    %if &SYSERR. > 6 %then
        %abortar(Falha ao ler a tabela "&API_ROOT_TABLE." do JSON. Inspecione o
                 libname APIDATA no log e ajuste API_ROOT_TABLE.);

    libname apidata clear;
    filename _resp clear;

    %log_info(Fonte API lida: &API_URL. (tabela &API_ROOT_TABLE.) -> &SRC_DS.);

%mend input_api;

/* Fim de 01_input_api.sas */
;;;;
run;

data _null_; file "&PROJ_ROOT./src/01_input_db.sas" lrecl=32767; input; put _infile_; datalines4;
/*==============================================================================
| Arquivo : src/01_input_db.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Fonte banco de dados. Conecta via LIBNAME (POSTGRES nativo ou ODBC),
|            le a tabela/consulta de origem e entrega o contrato unico &SRC_DS.
| Entradas : &DB_ENGINE, &DB_SERVER, &DB_PORT, &DB_DATABASE, &DB_SCHEMA,
|            &DB_TABLE, credenciais &DB_USER/&DB_PASSWORD (via %sysget).
| Saidas   : &SRC_DS (WORK.report_src).
| Obs      : Requer o modulo SAS/ACCESS correspondente licenciado no Viya.
|            Credenciais SOMENTE via variaveis de ambiente (nunca hardcoded).
==============================================================================*/

%macro input_db;

    /* Credenciais obrigatorias — abortam com mensagem clara se ausentes */
    %require_env(DB_USER,     DB_USER);
    %require_env(DB_PASSWORD, DB_PASSWORD);

    %if %superq(DB_SERVER) = %then
        %abortar(DB_SERVER vazio em config.sas. Informe o host do banco.);

    libname db &DB_ENGINE.
        server   = "&DB_SERVER."
        port     = &DB_PORT.
        user     = "&DB_USER."
        password = "&DB_PASSWORD."
        database = "&DB_DATABASE."
        schema   = "&DB_SCHEMA.";

    %if &SYSLIBRC. ne 0 %then
        %abortar(Falha ao conectar no banco (&DB_ENGINE. @ &DB_SERVER.).
                 Verifique host / credenciais / modulo SAS/ACCESS.);

    data &SRC_DS.;
        set db.&DB_TABLE.;
    run;

    %if &SYSERR. > 6 %then %do;
        libname db clear;
        %abortar(Falha ao ler a tabela &DB_SCHEMA..&DB_TABLE. do banco.);
    %end;

    libname db clear;

    %log_info(Fonte DB lida: &DB_ENGINE.:&DB_SCHEMA..&DB_TABLE. -> &SRC_DS.);

%mend input_db;

/* Fim de 01_input_db.sas */
;;;;
run;

data _null_; file "&PROJ_ROOT./src/02_ingest.sas" lrecl=32767; input; put _infile_; datalines4;
/*==============================================================================
| Arquivo : src/02_ingest.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Dispatcher da camada de input. Roteia por &SOURCE_TYPE e garante o
|            CONTRATO UNICO: qualquer fonte sempre produz o dataset &SRC_DS.
|            Esse contrato e o que torna as tres fontes intercambiaveis — os
|            modulos seguintes (transform/stats/viz/report) nunca sabem de onde
|            o dado veio; leem apenas &SRC_DS.
| Entradas : &SOURCE_TYPE (csv|api|db), macros input_csv/input_api/input_db.
| Saidas   : &SRC_DS (WORK.report_src) garantidamente existente.
| Depende  : m_utils (%abortar, %log_info).
==============================================================================*/

%macro ingest;

    %let SOURCE_TYPE = %lowcase(%superq(SOURCE_TYPE));

    %log_info(Ingestao iniciada. SOURCE_TYPE=&SOURCE_TYPE.);

    %if      &SOURCE_TYPE. = csv %then %input_csv;
    %else %if &SOURCE_TYPE. = api %then %input_api;
    %else %if &SOURCE_TYPE. = db  %then %input_db;
    %else %abortar(SOURCE_TYPE invalido: "&SOURCE_TYPE.". Use csv / api / db em config.sas.);

    /* Garantia do contrato: o dataset precisa existir apos a ingestao */
    %if not %sysfunc(exist(&SRC_DS.)) %then
        %abortar(A ingestao (&SOURCE_TYPE.) nao produziu &SRC_DS.. Verifique o modulo de input.);

    %log_info(Ingestao concluida. Dataset de trabalho: &SRC_DS.);

%mend ingest;

/* Fim de 02_ingest.sas */
;;;;
run;

data _null_; file "&PROJ_ROOT./src/03_transform.sas" lrecl=32767; input; put _infile_; datalines4;
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
;;;;
run;

data _null_; file "&PROJ_ROOT./src/04_stats.sas" lrecl=32767; input; put _infile_; datalines4;
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
;;;;
run;

data _null_; file "&PROJ_ROOT./src/05_templates.sas" lrecl=32767; input; put _infile_; datalines4;
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
;;;;
run;

data _null_; file "&PROJ_ROOT./src/06_viz.sas" lrecl=32767; input; put _infile_; datalines4;
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
        %let dmin = %superq(vmin); %if &dmin. = %then %let dmin = .;
        %let dmax = %superq(vmax); %if &dmax. = %then %let dmax = .;

        proc sgrender data=&TXF_DS. template=bar_tpl;
            dynamic _x="&cat." _y="&med." _title="&titulo."
                    _ymin=&dmin. _ymax=&dmax.;
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
            title;
        %end;
        %else %do;
            /* Fallback: participacao como barras horizontais com % */
            proc sgplot data=&TXF_DS.;
                title "&titulo. (participacao)";
                hbar &cat. / response=&med. stat=&stat_up.
                             categoryorder=respdesc datalabel;
                xaxis grid label="&med.";
            run;
            title;
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
;;;;
run;

data _null_; file "&PROJ_ROOT./src/07_tables.sas" lrecl=32767; input; put _infile_; datalines4;
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
        proc report data=&TXF_DS.(obs=50) nowd
            style(header)=[background=cx1f3864 color=white fontweight=bold];
            columns &KEEP_VARS.;
        run;
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
;;;;
run;

data _null_; file "&PROJ_ROOT./src/08_report.sas" lrecl=32767; input; put _infile_; datalines4;
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
;;;;
run;

data _null_; file "&PROJ_ROOT./src/99_run_all.sas" lrecl=32767; input; put _infile_; datalines4;
/*==============================================================================
| Arquivo : src/99_run_all.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: PONTO DE ENTRADA do pipeline. Carrega config e todas as definicoes
|            (00_setup), define o orquestrador %run_report e o executa. E o unico
|            arquivo que o usuario precisa abrir e submeter no SAS Studio.
| Entradas : config/config.sas + todos os modulos (via 00_setup.sas).
| Saidas   : relatorio em output/pdf + output/html + csv em output/data.
| Como usar: 1) ajuste PROJ_ROOT abaixo para o caminho real no SAS Viya;
|            2) submeta este arquivo inteiro no SAS Studio.
==============================================================================*/

/*------------------------------------------------------------------------------
| 1. Raiz do projeto no SAS Viya. AJUSTE UMA VEZ para o seu ambiente.
|    Ex.: /home/seu.usuario/sas-relatorios-dinamicos
|    (config.sas respeita este valor se ja definido.)
------------------------------------------------------------------------------*/
%if not %symexist(PROJ_ROOT) %then %global PROJ_ROOT;
%if %superq(PROJ_ROOT) = %then
    %let PROJ_ROOT = /home/student/sas-relatorios-dinamicos;

/*------------------------------------------------------------------------------
| 2. Carrega configuracao e todas as macros/modulos.
------------------------------------------------------------------------------*/
%include "&PROJ_ROOT./config/config.sas";
%include "&DIR_SRC./00_setup.sas";

/*------------------------------------------------------------------------------
| 3. Orquestrador: executa as etapas do pipeline na ordem correta.
|    Qualquer etapa que detecte problema aborta via %abort cancel (m_utils),
|    interrompendo a submissao com mensagem clara — nunca gera saida errada.
------------------------------------------------------------------------------*/
%macro run_report;

    %log_info(===== INICIO DO PIPELINE (fonte=&SOURCE_TYPE.) =====);

    %load_report_spec;      /* le report_spec.csv -> macro vars de config      */
    %ingest;                /* dispatcher por &SOURCE_TYPE -> &SRC_DS          */
    %validate_src;          /* barra dataset vazio / colunas / tipos           */
    %transform;             /* KEEP + WHERE + LABEL -> &TXF_DS                 */
    %run_stats;             /* media/mediana/frequencia -> WORK.stats_*        */
    %build_templates;       /* compila template GTL reutilizavel               */

    %open_report;           /* abre ODS PDF + ODS HTML5                        */
        %make_tables;       /* tabela-resumo formatada                         */
        %make_viz;          /* graficos (barras/pizza/linha) do spec           */
        %make_notes;        /* notas de calculo (media/mediana/...)            */
    %close_report;          /* fecha os dois destinos                          */

    %export_used_data;      /* exporta os dados usados em .csv                 */

    %log_info(===== PIPELINE CONCLUIDO COM SUCESSO =====);

%mend run_report;

%run_report;

/* Fim de 99_run_all.sas */
;;;;
run;

data _null_; file "&PROJ_ROOT./data/sample/vendas_exemplo.csv" lrecl=32767; input; put _infile_; datalines4;
produto,categoria,regiao,valor,quantidade,data
Notebook Pro 14,Eletronicos,Sudeste,5299.90,3,2026-01-08
Notebook Pro 14,Eletronicos,Sul,5299.90,2,2026-01-15
Mouse Sem Fio,Acessorios,Sudeste,129.90,25,2026-01-09
Mouse Sem Fio,Acessorios,Nordeste,129.90,18,2026-02-02
Teclado Mecanico,Acessorios,Sudeste,349.00,12,2026-01-22
Teclado Mecanico,Acessorios,Sul,349.00,9,2026-02-11
Monitor 27 4K,Eletronicos,Sudeste,2199.00,6,2026-01-30
Monitor 27 4K,Eletronicos,Centro-Oeste,2199.00,4,2026-02-14
Cadeira Ergonomica,Mobiliario,Sudeste,1899.00,5,2026-01-18
Cadeira Ergonomica,Mobiliario,Nordeste,1899.00,3,2026-02-20
Mesa Standing Desk,Mobiliario,Sul,2450.00,2,2026-02-05
Mesa Standing Desk,Mobiliario,Sudeste,2450.00,4,2026-02-25
Webcam Full HD,Acessorios,Norte,289.90,15,2026-01-27
Webcam Full HD,Acessorios,Sudeste,289.90,22,2026-02-17
Headset Gamer,Acessorios,Sul,459.00,11,2026-01-12
Headset Gamer,Acessorios,Centro-Oeste,459.00,7,2026-02-09
SSD 1TB,Componentes,Sudeste,649.00,30,2026-01-05
SSD 1TB,Componentes,Nordeste,649.00,14,2026-02-19
Placa de Video RTX,Componentes,Sudeste,4899.00,3,2026-01-25
Placa de Video RTX,Componentes,Sul,4899.00,2,2026-02-22
Memoria RAM 32GB,Componentes,Sudeste,899.00,20,2026-01-14
Memoria RAM 32GB,Componentes,Norte,899.00,8,2026-02-13
Impressora Laser,Eletronicos,Nordeste,1299.00,5,2026-01-20
Impressora Laser,Eletronicos,Sudeste,1299.00,9,2026-02-27
Roteador Wi-Fi 6,Eletronicos,Sul,599.00,16,2026-01-11
Roteador Wi-Fi 6,Eletronicos,Sudeste,599.00,21,2026-02-08
;;;;
run;

data _null_; file "&PROJ_ROOT./tests/test_smoke.sas" lrecl=32767; input; put _infile_; datalines4;
/*==============================================================================
| Arquivo : tests/test_smoke.sas
| Projeto : Relatorios Dinamicos Responsivos via SAS
| Proposito: Teste de fumaca ponta a ponta. Roda o pipeline completo com a
|            fonte CSV de exemplo e verifica os criterios de aceite:
|              - output/pdf/<nome>.pdf existe
|              - output/html/<nome>.html existe
|              - output/data/<nome>_dados_usados.csv existe
|            Ao final, imprime um resumo PASS/FAIL no log.
|            A SECAO 2 (opcional) valida que m_validate aborta em dataset vazio.
| Como usar: ajuste PROJ_ROOT e submeta no SAS Studio.
==============================================================================*/

/*------------------------------------------------------------------------------
| SECAO 1 - CAMINHO FELIZ: roda o pipeline e confere as 3 saidas.
------------------------------------------------------------------------------*/
%if not %symexist(PROJ_ROOT) %then %global PROJ_ROOT;
%if %superq(PROJ_ROOT) = %then
    %let PROJ_ROOT = /home/student/sas-relatorios-dinamicos;

/* Garante fonte CSV de exemplo para o teste */
%global SOURCE_TYPE;
%let SOURCE_TYPE = csv;

/* Executa o pipeline completo (define e chama %run_report) */
%include "&PROJ_ROOT./src/99_run_all.sas";

/* Verificacao das saidas */
%macro smoke_check;
    %local pdf html csv ok;
    %let pdf  = &DIR_OUT_PDF./&RPT_NOME_ARQ..pdf;
    %let html = &DIR_OUT_HTML./&RPT_NOME_ARQ..html;
    %let csv  = &DIR_OUT_DATA./&RPT_NOME_ARQ._dados_usados.csv;
    %let ok = 1;

    %put NOTE: ============ RESULTADO DO SMOKE TEST ============;

    %if %sysfunc(fileexist(&pdf.))  %then %put NOTE: [PASS] PDF gerado:  &pdf.;
    %else %do; %put ERROR: [FAIL] PDF nao encontrado: &pdf.;  %let ok = 0; %end;

    %if %sysfunc(fileexist(&html.)) %then %put NOTE: [PASS] HTML gerado: &html.;
    %else %do; %put ERROR: [FAIL] HTML nao encontrado: &html.; %let ok = 0; %end;

    %if %sysfunc(fileexist(&csv.))  %then %put NOTE: [PASS] CSV gerado:  &csv.;
    %else %do; %put ERROR: [FAIL] CSV nao encontrado: &csv.;  %let ok = 0; %end;

    %if &ok. = 1 %then %put NOTE: >>> SMOKE TEST: TODOS OS CRITERIOS OK <<<;
    %else %put ERROR: >>> SMOKE TEST FALHOU: verifique os itens [FAIL] acima <<<;

    %put NOTE: ==================================================;
%mend smoke_check;

%smoke_check;

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
;;;;
run;

/* ---- Recria o projeto acima. Agora executa o teste de fumaca. ---- */
%put NOTE: [INSTALL] Projeto recriado em &PROJ_ROOT.;
%include "&PROJ_ROOT./tests/test_smoke.sas";

