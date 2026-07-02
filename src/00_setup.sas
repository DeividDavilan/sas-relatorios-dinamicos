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
