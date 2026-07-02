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
