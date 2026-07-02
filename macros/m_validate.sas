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
