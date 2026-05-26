---
titulo: "Arquitetura do Projeto dbt"
aliases:
  - "arquitetura"
  - "estrutura"
tags:
  - dbt
  - bigquery
  - arquitetura
  - policy-tags
data_criacao: "2026-01-01"
data_modificacao: "2026-04-08"
---

# Guia 02 — Arquitetura do Projeto

## Visão Geral

- **Projeto dbt**: `br_mec_segape`
- **Banco de dados**: Google BigQuery
- **Projeto BigQuery (dev)**: `br-mec-segape-dev`
- **Raiz dbt**: `queries/`
- **Profile**: `queries` (definido em `dev/profiles.yml` -- veja [[01-setup-ambiente]])
- **Status**: produção

---

## Escala

| Métrica | Quantidade |
|---------|-----------|
| Modelos SQL | ~1.060 |
| Arquivos YAML (sources + schema) | ~100 |
| Schemas/pastas | ~100 |
| Macros | 9 |
| Seeds | 3 |
| Testes | ~580 |

---

## Camadas de Dados

A organização de pastas em `queries/models/` segue uma convenção de prefixos
que define a materialização e o propósito de cada camada:

| Prefixo de pasta | Materialização | Descrição |
|------------------|---------------|-----------|
| `raw_*` | view | Extração bruta (CSV, banco de dados, API). Renomeio de colunas e cast de tipos. |
| `educacao_politica_*` | table | Lógica de negócio. Transformações, joins, regras de filtragem. |
| `educacao_*_dados_abertos` | table | Disseminação pública. Dados tratados para publicação. |
| `indicador_politica_*` | table | KPIs e indicadores calculados. |
| `projeto_*` | table | Dashboards e relatórios. Modelos consumidos diretamente pelo Looker Studio. |

### Pastas com mais modelos

| Pasta | Modelos | Descrição |
|-------|---------|-----------|
| `projeto_painel_ministro` | ~88 | Painel principal do Ministro |
| `educacao_politica_spo` | ~62 | Secretaria de Planejamento e Orçamento |
| `projeto_gaia` | ~39 | Projeto GAIA |
| `educacao_politica_fnde` | ~39 | Fundo Nacional de Desenvolvimento da Educação |
| `raw_csv_inep` | ~35 | Dados brutos do INEP via CSV |

---

## Fontes de Dados Principais

INEP, SIMEC, CadUnico, CAPES, FNDE, IBGE, SISU, ENEM, FIES, PROUNI

---

## Variáveis dbt

Definidas em `queries/dbt_project.yml`:

| Variável | Valor | Uso |
|----------|-------|-----|
| `ano_base` | `2022` | Filtro para governo atual (`ano > ano_base`) |
| `filtro_id_brasil` | `99` | Código geográfico para nível Brasil nos painéis |

---

## Macros Disponíveis

Localizadas em `queries/macros/`:

| Macro | Descrição |
|-------|-----------|
| `convert_type` | Conversão de tipos com tratamento de erros |
| `null_if_invalid` | Retorna NULL se valor for inválido |
| `sanitize_string` | Limpeza de strings (espaços, caracteres especiais) |
| `generate_database_name` | Geração do nome do banco (padrão BigQuery) |
| `generate_schema_name` | Geração do nome do schema/dataset |
| `get_partition_range` | Range de particionamento |
| `handle_null` | Tratamento de valores nulos |
| `parse_date_format` | Parsing de formatos de data |

### Testes customizados

| Teste | Descrição |
|-------|-----------|
| `string_nullable` | Valida se campo string aceita nulos corretamente |
| `valid_parse_date_format` | Valida formato de data parseado |

---

## Seeds

Dados estáticos em `queries/seeds/`, schema `raw_seed_dbt_eng_dados`:

| Arquivo | Descrição |
|---------|-----------|
| `prefect_environment_variables.csv` | Variáveis de ambiente do Prefect |
| `prefect_pipeline.csv` | Configuração de pipelines |
| `prefect_source_query.csv` | Queries de extração |

---

## Policy Tags

O projeto utiliza 5 policy tags para dados sensíveis, definidas em `dbt_project.yml`:

| Tag | Colunas protegidas |
|-----|-------------------|
| `TAG_CPF` | CPF |
| `TAG_NIS` | NIS |
| `TAG_NOME` | Nome completo |
| `TAG_DATA_NASCIMENTO` | Data de nascimento |
| `TAG_ETNIA` / `TAG_GENERO` | Cor/raça, sexo |

Colunas com policy tags exigem permissão específica no BigQuery para leitura. Veja [[05-armadilhas]] para detalhes sobre como policy tags podem ser destruídas acidentalmente.

---

## Estrutura de Diretórios

```
pipelines-main/
├── .pipelines/              # Venv isolado com adaptador BigQuery
│   └── bin/
│       ├── dbt              # Binário dbt (USAR ESTE)
│       └── python           # Python do venv
├── dev/                     # Configuração local
│   └── profiles.yml         # Credenciais BigQuery (não commitar)
├── queries/                 # Raiz do projeto dbt
│   ├── dbt_project.yml      # Configuração do projeto
│   ├── models/              # Modelos SQL (~100 pastas)
│   ├── macros/              # Macros Jinja2
│   ├── seeds/               # Dados estáticos CSV
│   ├── tests/               # Testes customizados
│   └── target/              # Saída gerada (não commitar)
├── contexto/                # Guias de desenvolvimento
└── scripts/                 # Scripts Python auxiliares
```

Para os padrões de código exigidos nas revisões, consulte [[04-padroes-codigo]].

---

## Navegação

| Documento | Descrição |
|-----------|-----------|
| [01 - Setup do Ambiente](01-setup-ambiente.md) | Configuração do ambiente local |
| [04 - Padrões de Código](04-padroes-codigo.md) | Standards de SQL, schema.yml, commits |
| [05 - Armadilhas](05-armadilhas.md) | Erros conhecidos e como evitá-los |

[Voltar ao índice](onboarding.md)
