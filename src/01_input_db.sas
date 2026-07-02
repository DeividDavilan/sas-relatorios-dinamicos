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
