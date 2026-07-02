# 📊 Relatórios Dinâmicos Responsivos via SAS

Pipeline **SAS modular e dirigido por configuração** que gera relatórios dinâmicos
(tabelas, gráficos e estatísticas) a partir de múltiplas fontes de dados, entregando
o resultado em **PDF e HTML5** — pronto para uso ou incorporação em plataformas web.

> **Ambiente-alvo:** SAS Viya (nuvem, licenciado) · SAS Studio / SAS Compute.
> O código é escrito para rodar diretamente no SAS Studio do Viya.

---

## ✨ O que ele faz

1. **Ingesta** dados de CSV local, API/URL (JSON) ou banco de dados (LIBNAME/ODBC) — escolha por configuração.
2. **Filtra e seleciona** colunas conforme a especificação do usuário.
3. **Calcula estatísticas** (média, mediana, frequência/histograma).
4. **Renderiza gráficos** reutilizáveis: barras, pizza e linha.
5. **Monta tabelas** formatadas com rótulos em pt-BR.
6. **Gera o relatório final** em **PDF (ODS PDF)** e **HTML (ODS HTML5)** com título, tabela, gráficos e notas de cálculo.
7. **Exporta** os dados usados em `.csv`.
8. **Trata erros** de dados e registra log claro em português.

> **Princípio central:** o comportamento do relatório é definido por **configuração**,
> não por edição de código. Trocar de fonte = trocar `SOURCE_TYPE`. Trocar
> colunas/gráficos/títulos = editar `config/report_spec.csv`.

---

## 🗂️ Estrutura

```
sas-relatorios-dinamicos/
├── config/
│   ├── config.sas          # macro vars globais: caminhos, SOURCE_TYPE, credenciais (%sysget)
│   └── report_spec.csv     # spec do relatório: colunas, filtros, gráficos, títulos, escalas
├── src/
│   ├── 00_setup.sas        # options, libnames, %include dos módulos e macros
│   ├── 01_input_csv.sas    # PROC IMPORT de CSV
│   ├── 01_input_api.sas    # PROC HTTP + engine JSON
│   ├── 01_input_db.sas     # LIBNAME ODBC / POSTGRES
│   ├── 02_ingest.sas       # dispatcher: roteia por &SOURCE_TYPE -> WORK.report_src
│   ├── 03_transform.sas    # filtros (WHERE) + seleção de colunas (KEEP) + validação
│   ├── 04_stats.sas        # média / mediana / frequência
│   ├── 05_templates.sas    # PROC TEMPLATE (GTL) — templates de gráfico reutilizáveis
│   ├── 06_viz.sas          # SGPLOT/SGPIE: barras, pizza, linha (+ escalas)
│   ├── 07_tables.sas       # PROC REPORT — tabela formatada
│   ├── 08_report.sas       # ODS PDF + ODS HTML5 (título, tabela, gráficos, notas)
│   └── 99_run_all.sas      # define e chama %run_report(); ponto de entrada
├── macros/
│   ├── m_validate.sas      # tratamento de erros/dados (nulos, tipos, dataset vazio)
│   ├── m_export_csv.sas    # PROC EXPORT dos dados usados
│   └── m_utils.sas         # helpers (log padronizado, checagens, %abort controlado)
├── data/sample/            # dados de exemplo (vendas_exemplo.csv)
├── output/{pdf,html,data}/ # saídas geradas
├── tests/test_smoke.sas    # roda o pipeline com dados de exemplo e valida saídas
└── docs/                   # ARQUITETURA.md e COMO_CONFIGURAR.md
```

---

## ▶️ Como rodar no SAS Viya / SAS Studio

1. Carregue a pasta `sas-relatorios-dinamicos/` no SAS Viya (upload ou `git clone`).
2. Ajuste **`config/config.sas`**:
   - `PROJ_ROOT` → caminho real do projeto no Viya (ex.: `/home/seu.usuario/sas-relatorios-dinamicos`).
   - `SOURCE_TYPE` → `csv` (default), `api` ou `db`.
3. (Opcional) Edite **`config/report_spec.csv`** para escolher colunas, filtros e gráficos.
4. Abra e execute **`src/99_run_all.sas`**.
5. Confira as saídas em `output/pdf/`, `output/html/` e `output/data/`.

Para um teste rápido de ponta a ponta com os dados de exemplo, execute **`tests/test_smoke.sas`**.

---

## 🚀 Deploy no SAS Viya

Sem SAS local, o deploy leva o código ao Viya e o executa lá. Caminho recomendado:

```powershell
pwsh deploy/push_to_github.ps1     # empurra o projeto para o GitHub
```

Depois, no SAS Studio, submeta **`deploy/bootstrap_viya.sas`** — ele clona o repo
e roda o smoke test. Há também um script de automação total via API
(`deploy/deploy_viya_rest.ps1`). Detalhes em [`deploy/README_DEPLOY.md`](deploy/README_DEPLOY.md).

---

## 🔐 Credenciais

Credenciais de API e banco são lidas **somente de variáveis de ambiente** via `%sysget`
— nunca ficam no repositório. Defina-as no shell do SAS Viya antes de iniciar a sessão:

```bash
export DB_USER=meu_usuario
export DB_PASSWORD=minha_senha
export API_TOKEN=xxxxx
```

---

## 📦 Dependências SAS

- **BASE SAS:** DATA step, PROC IMPORT/EXPORT, PROC PRINT/REPORT, PROC MEANS/FREQ/UNIVARIATE, PROC TEMPLATE, ODS PDF, ODS HTML5.
- **ODS Graphics / SAS/GRAPH:** PROC SGPLOT, PROC SGPIE.
- **Input API:** PROC HTTP + engine JSON (LIBNAME JSON).
- **Input DB:** engine de banco (LIBNAME `POSTGRES` ou `ODBC`) — requer licença do SAS/ACCESS correspondente.

---

## 🌐 Idioma

Código e nomes de arquivos em **inglês**; comentários, títulos de relatório e
documentação em **pt-BR**.

---

## 📄 Documentação

- [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md) — pipeline e contratos entre módulos.
- [`docs/COMO_CONFIGURAR.md`](docs/COMO_CONFIGURAR.md) — guia do `report_spec.csv` para o usuário final.
