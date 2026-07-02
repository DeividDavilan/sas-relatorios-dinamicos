# 🏗️ Arquitetura — Relatórios Dinâmicos via SAS

Este documento explica o **pipeline**, o **contrato entre os módulos** e as
**decisões técnicas** do projeto. Para configurar um relatório, veja
[`COMO_CONFIGURAR.md`](COMO_CONFIGURAR.md).

---

## Visão geral

O sistema é um **pipeline SAS dirigido por configuração**. O comportamento do
relatório é definido por dois arquivos — `config/config.sas` e
`config/report_spec.csv` — e **não** por edição do código dos módulos.

```
config.sas + report_spec.csv
        │
        ▼
  [load_report_spec]  lê o spec -> macro vars (colunas, filtros, gráficos, títulos)
        │
        ▼
  [ingest]  dispatcher escolhe a fonte por &SOURCE_TYPE (csv | api | db)
        │      input_csv | input_api | input_db  ──►  WORK.report_src
        ▼
  [validate_src]  barra dataset vazio / coluna ausente / tipo incompatível
        ▼
  [transform]  KEEP (colunas) + WHERE (filtros) + LABEL (rótulos) ──► WORK.report_txf
        ▼
  [run_stats]  PROC MEANS / FREQ  ──► WORK.stats_means, WORK.stats_freq
        ▼
  [build_templates]  PROC TEMPLATE (GTL) compila o template reutilizável bar_tpl
        ▼
  [open_report]  abre ODS PDF + ODS HTML5 (mesmo conteúdo nos dois)
        ├─ [make_tables]  PROC REPORT: tabela-resumo formatada
        ├─ [make_viz]     SGRENDER/SGPLOT/SGPIE: barras, pizza, linha (+ escalas)
        └─ [make_notes]   notas de cálculo (média/mediana/total/…)
  [close_report]  fecha os dois destinos
        ▼
  [export_used_data]  PROC EXPORT ──► output/data/<nome>_dados_usados.csv
```

O ponto de entrada é **`src/99_run_all.sas`**, que carrega tudo e chama o
orquestrador `%run_report`.

---

## O contrato central: `WORK.report_src`

A chave da **plugabilidade de fontes** é um contrato único: qualquer que seja a
origem (CSV, API, banco), o dispatcher `%ingest` sempre entrega o dataset
**`WORK.report_src`** (`&SRC_DS`). Os módulos seguintes nunca sabem de onde o
dado veio — leem apenas esse dataset. Trocar de fonte = mudar `%let SOURCE_TYPE`
em `config.sas`; nenhuma outra linha de código muda.

| Fonte | Módulo | Como obtém os dados |
|-------|--------|---------------------|
| `csv` | `01_input_csv.sas` | `PROC IMPORT` de `&CSV_PATH` |
| `api` | `01_input_api.sas` | `PROC HTTP` + engine `JSON` (libname) |
| `db`  | `01_input_db.sas`  | `LIBNAME` POSTGRES/ODBC + `SET` da tabela |

---

## Convenções de código

- **Cada módulo define uma `%macro`** (ex.: `%transform`, `%make_viz`) e **não
  executa nada** só por ser incluído. Quem orquestra a ordem é `%run_report`.
  Isso permite controle de fluxo, `%abort cancel` limpo e reuso.
- **`00_setup.sas`** faz o `%include` de todas as macros e módulos (compila as
  definições) e garante que as pastas de saída existam.
- **Macro vars globais** vêm de `config.sas` (`&DIR_*`, `&SOURCE_TYPE`, `&SRC_DS`,
  `&TXF_DS`, credenciais via `%sysget`) e do spec (`&KEEP_VARS`, `&WHERE_CLAUSE`,
  `&COL_LABELS`, `&N_GRAF` e os slots `&&GRAF_*&i`, `&STAT_MEASURE`, `&STAT_GROUP`).
- **Cabeçalho de comentário** padronizado em todo `.sas` (propósito, entradas,
  saídas, dependências).
- **Idioma:** código e nomes em inglês; comentários, títulos e log em pt-BR.

---

## Tratamento de erros

`m_validate` (`%validate_src`) roda **antes** de gerar qualquer saída e barra:

1. **dataset vazio** (0 registros);
2. **coluna do spec ausente** na fonte;
3. **tipo incompatível** (a medida das estatísticas precisa ser numérica).

Qualquer falha chama `%abortar` (em `m_utils`), que registra mensagem clara em
pt-BR no log e executa `%abort cancel` — interrompendo a submissão **sem gerar um
relatório silenciosamente errado** e sem derrubar a sessão do SAS Studio. Os
módulos também checam `&SYSERR`/`&SYSLIBRC`/`&SYS_PROCHTTP_STATUS_CODE` após
operações críticas.

---

## Decisões técnicas

| Decisão | Por quê | Alternativa descartada |
|---------|---------|------------------------|
| Cada módulo é uma `%macro` chamada pelo orquestrador | Controle de fluxo, ordem explícita, `%abort` limpo, reuso | Código de topo executando no `%include` |
| ODS PDF **e** HTML5 abertos juntos, um par abre/fecha | Mesmo conteúdo nos dois destinos; PDF num arquivo único | Cada módulo abrir/fechar seu próprio ODS (saída fragmentada) |
| **v1 processa em WORK** (não CAS) | Volume moderado; PROC IMPORT/MEANS/SGPLOT/REPORT são nativos em WORK | CAS/caslib (necessário só p/ milhões de linhas — roadmap) |
| Barras via **template GTL** + SGRENDER; linha/pizza via SGPLOT/SGPIE | Demonstra o "template reutilizável" do briefing sem over-engineering | Tudo em GTL (verboso demais p/ o escopo) |
| `PIE_ENGINE` com fallback (`sgpie`→`sgplot`) | `PROC SGPIE` já foi experimental; garante que a pizza sempre saia | Assumir SGPIE disponível sem plano B |
| HTML5 com `svg_mode="inline"` + `imagefmt=svg` | HTML autocontido e nítido, ideal para incorporar na web | PNG externo (arquivos soltos p/ servir) |
| Credenciais só via `%sysget` | Segurança: nada sensível no repositório | Credenciais hardcoded no config |

---

## Mapa de arquivos

| Arquivo | Macro principal | Papel |
|---------|-----------------|-------|
| `config/config.sas` | — | macro vars globais, `SOURCE_TYPE`, credenciais |
| `config/report_spec.csv` | — | spec do relatório (a "UI de configuração") |
| `src/00_setup.sas` | `_ensure_dir` | pastas de saída + `%include` de tudo |
| `src/01_input_csv.sas` | `%input_csv` | fonte CSV |
| `src/01_input_api.sas` | `%input_api` | fonte API/JSON |
| `src/01_input_db.sas` | `%input_db` | fonte banco |
| `src/02_ingest.sas` | `%ingest` | dispatcher (contrato `WORK.report_src`) |
| `src/03_transform.sas` | `%transform` | KEEP + WHERE + LABEL |
| `src/04_stats.sas` | `%run_stats` | média/mediana/frequência |
| `src/05_templates.sas` | `%build_templates` | template GTL `bar_tpl` |
| `src/06_viz.sas` | `%make_viz` / `%one_chart` | gráficos + escalas |
| `src/07_tables.sas` | `%make_tables` | tabela-resumo (PROC REPORT) |
| `src/08_report.sas` | `%open_report` / `%make_notes` / `%close_report` | ODS PDF + HTML5 |
| `src/99_run_all.sas` | `%run_report` | ponto de entrada / orquestrador |
| `macros/m_utils.sas` | `%log_*`, `%abortar`, `%require_env`, `%load_report_spec` | utilitários |
| `macros/m_validate.sas` | `%validate_src` | validação de dados |
| `macros/m_export_csv.sas` | `%export_used_data` | export .csv |

---

## Riscos conhecidos

1. **`PROC SGPIE`** já foi experimental em versões do SAS — mitigado por
   `PIE_ENGINE` com fallback para barras de participação.
2. **Nome da tabela do engine JSON** varia com o formato da API — ajustável via
   `API_ROOT_TABLE` (inspecionar o libname `APIDATA` no primeiro run).
3. **Caminhos do SAS Compute server** diferem por ambiente — isolados em
   `PROJ_ROOT` (`config.sas` / `99_run_all.sas`).
4. **Inferência de tipos do PROC IMPORT** — o CSV deve usar ponto decimal e datas
   ISO (`YYYY-MM-DD`).
5. **Encoding** — garantir sessão UTF-8 no context do Viya para acentos pt-BR.
