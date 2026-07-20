# ⚙️ Como configurar o relatório

Você monta o relatório editando **dois arquivos** — sem tocar no código SAS:

1. **`config/config.sas`** — de onde vêm os dados e onde ficam as saídas.
2. **`config/report_spec.csv`** — o que aparece no relatório (colunas, filtros, gráficos, títulos).

---

## 1. `config/config.sas` — o essencial

| O que ajustar | Macro var | Exemplo |
|---------------|-----------|---------|
| Raiz do projeto no SAS Viya | `PROJ_ROOT` | `/home/seu.usuario/sas-relatorios-dinamicos` |
| Fonte de dados | `SOURCE_TYPE` | `csv` \| `api` \| `db` |
| Caminho do CSV | `CSV_PATH` | `&DIR_DATA./sample/vendas_exemplo.csv` |
| Endpoint da API | `API_URL` | `https://api.exemplo.com/vendas` |
| Banco (host/porta/base/schema/tabela) | `DB_SERVER`, `DB_PORT`, `DB_DATABASE`, `DB_SCHEMA`, `DB_TABLE` | — |
| Nome-base dos arquivos de saída | `RPT_NOME_ARQ` | `relatorio_vendas` |
| Motor da pizza | `PIE_ENGINE` | `sgpie` (ou `sgplot` se o SGPIE não estiver habilitado) |

### Credenciais (nunca no arquivo!)

Credenciais de API e banco são lidas de **variáveis de ambiente** via `%sysget`.
Defina-as no shell do SAS Viya antes de iniciar a sessão:

```bash
export DB_USER=meu_usuario
export DB_PASSWORD=minha_senha
export API_TOKEN=xxxxx
```

Se a fonte exigir uma credencial ausente, o pipeline **aborta com mensagem clara**.

---

## 2. `config/report_spec.csv` — a "UI de configuração"

Cada **linha** é uma diretiva. A primeira coluna, `secao`, diz o tipo de diretiva.
As colunas são: `secao,p1,p2,p3,p4,p5,escala_min,escala_max`.

### 2.1 `opcao` — títulos do relatório

| secao | p1 | p2 |
|-------|----|----|
| `opcao` | `titulo` | Texto do título |
| `opcao` | `subtitulo` | Texto do subtítulo |
| `opcao` | `rodape` | Texto do rodapé |

```csv
opcao,titulo,Relatorio Dinamico de Vendas - 1o Bimestre 2026,,,,,
opcao,subtitulo,Analise de faturamento por categoria e regiao,,,,,
opcao,rodape,Fonte: base interna | Pipeline SAS Viya,,,,,
```

### 2.2 `coluna` — colunas a incluir (e o rótulo em pt-BR)

| secao | p1 (nome real da coluna) | p2 (rótulo exibido) |
|-------|--------------------------|---------------------|
| `coluna` | `valor` | `Valor (R$)` |

```csv
coluna,produto,Produto,,,,,
coluna,categoria,Categoria,,,,,
coluna,valor,Valor (R$),,,,,
coluna,data,Data,,,,,
```

Só as colunas listadas entram no relatório (aplicado via `KEEP`).

### 2.3 `filtro` — filtros (cláusula WHERE)

| secao | p1 (expressão WHERE) |
|-------|----------------------|
| `filtro` | `valor > 0` |

```csv
filtro,valor > 0,,,,,,
filtro,regiao = 'Sudeste',,,,,,
```

Vários filtros são combinados com **`and`**. Use a sintaxe SAS de `WHERE`
(texto entre aspas simples; datas como `'01JAN2026'd`).

### 2.4 `grafico` — gráficos desejados

| secao | p1 (tipo) | p2 (categoria/eixo X) | p3 (medida/eixo Y) | p4 (estatística) | p5 (título) | escala_min | escala_max |
|-------|-----------|-----------------------|--------------------|------------------|-------------|-----------|-----------|
| `grafico` | `bar` \| `pie` \| `line` | `categoria` | `valor` | `sum` \| `mean` \| `freq` | Título do gráfico | opcional | opcional |

```csv
grafico,bar,categoria,valor,sum,Faturamento por Categoria (R$),0,
grafico,pie,regiao,valor,sum,Participacao por Regiao,,
grafico,line,data,valor,sum,Evolucao do Faturamento,0,
```

- **`escala_min` / `escala_max`**: fixam os limites do eixo (deixe em branco para
  escala automática).
- A **primeira** linha `grafico` também define sobre qual medida/categoria são
  calculadas as **notas de cálculo** (média, mediana, total etc.).

---

## 3. Rodar

1. Ajuste `PROJ_ROOT` em `src/99_run_all.sas` (e/ou `config.sas`).
2. Abra `src/99_run_all.sas` no SAS Studio e **submeta**.
3. Confira as saídas:
   - `output/pdf/<nome>.pdf`
   - `output/html/<nome>.html`
   - `output/data/<nome>_dados_usados.csv`

Para um teste rápido, submeta `tests/test_smoke.sas` — ele roda o pipeline e
imprime `PASS/FAIL` no log para cada saída esperada.

---

## 4. Exemplos rápidos

**Trocar a fonte para banco de dados:** em `config.sas`, `%let SOURCE_TYPE = db;`
e preencha `DB_SERVER`, `DB_DATABASE`, `DB_SCHEMA`, `DB_TABLE`; exporte
`DB_USER`/`DB_PASSWORD` no ambiente. Nada mais muda.

**Relatório só de uma região:** adicione em `report_spec.csv`:
`filtro,regiao = 'Nordeste',,,,,,`

**Mudar o gráfico de barras para média em vez de soma:** troque `sum` por `mean`
na coluna `p4` da linha `grafico,bar,...`.

---

## 5. Troubleshooting

| Erro no log | Causa provável | Solução |
|-------------|----------------|---------|
| `config.sas nao foi carregado antes de 00_setup.sas` | `99_run_all.sas` não encontrou `config.sas` | Verifique `PROJ_ROOT` — deve apontar para a raiz do projeto |
| `Arquivo CSV nao encontrado` | `CSV_PATH` incorreto | Ajuste o caminho em `config.sas`; use `&DIR_DATA./...` |
| `SOURCE_TYPE invalido` | Valor fora de `csv\|api\|db` | Corrija `SOURCE_TYPE` em `config.sas` (minúsculo) |
| `A coluna "X" definida no report_spec nao existe` | Nome de coluna no CSV difere do dado | rode `PROC CONTENTS` no dataset para ver os nomes reais |
| `A coluna de medida "X" deveria ser numerica` | Coluna veio como texto (ex.: valor com `,` ou `R$`) | Limpe a coluna na fonte ou ajuste o `INPUT` no `01_input_csv.sas` |
| `Nenhum registro apos aplicar filtros` | Filtro muito restritivo | Revise as linhas `filtro` no `report_spec.csv` |
| `Falha ao compilar o template GTL bar_tpl` | SAS/GRAPH ou ODS Graphics não habilitado | Verifique `ods graphics on` e licença SAS/GRAPH |
| `API retornou status 401` | Token ausente ou inválido | Exporte `API_TOKEN` no ambiente antes da sessão |
| `Falha ao conectar no banco` | Host/credenciais/SAS/ACCESS incorretos | Teste a conexão separadamente; verifique `DB_SERVER`, `DB_PORT` |
| `PIPELINE CONCLUIDO` mas PDF vazio | Nenhum gráfico/tabela gerado | Verifique se `report_spec.csv` tem linhas `coluna` e `grafico` |

### Dica: validate manual

Para validar o `report_spec.csv` antes de rodar o pipeline completo, abra o SAS
Studio e submeta:

```sas
%include "config/config.sas";
%include "macros/m_utils.sas";
%load_report_spec;
%put NOTE: Spec OK — &N_COLS. colunas, &N_GRAF. graficos.;
```

Se não houver ERROR no log, o spec está sintaticamente correto.
