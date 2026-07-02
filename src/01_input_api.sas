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
