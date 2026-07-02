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
