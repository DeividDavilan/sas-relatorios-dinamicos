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
