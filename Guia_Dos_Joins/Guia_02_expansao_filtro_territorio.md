---
titulo: "Guia de Joins: Expansão Territorial com filtro_territorio"
aliases:
  - "expansão territorial"
  - "guia joins 2"
  - "filtro territorio"
  - "triplicação"
tags:
  - sql
  - bigquery
  - joins
  - territorio
  - looker
  - guia
data_criacao: "2026-01-01"
data_modificacao: "2026-04-08"
---

# Expansão Territorial com `filtro_territorio`

## Por que este guia existe

Os dashboards do Looker precisam de filtros que funcionem em três níveis: município, estado e país. O usuário seleciona "Todos" no dropdown de estado para ver o Brasil inteiro, ou "Todos" no dropdown de município para ver um estado inteiro. O problema é que os dados de origem vêm no nível mais granular -- município. Se você simplesmente jogar esses dados no Looker, os filtros "Todos" não vão funcionar, porque não existe nenhuma linha onde `estado = 'Todos'` ou `municipio = 'Todos'`.

A solução é a **triplicação**: cada registro do nível município é replicado para os níveis estado e país, com os campos de filtro ajustados para conter `'Todos'` nos níveis superiores. Assim, quando o Looker filtra por "Todos", ele encontra linhas correspondentes e consegue agregar os valores corretamente.

Este guia ensina o template SQL completo para fazer essa triplicação usando a tabela `filtro_territorio` como referência territorial.

---

## Árvore de decisão: Qual guia usar?

Antes de seguir, verifique se este é o guia certo para o seu caso:

- **Preciso só de coordenadas (latitude/longitude) de instituições?**
  Use [[Guia_01_coordenadas_instituicoes]].

- **Já uso `filtro_territorio` no dashboard e preciso expandir os dados para os três níveis?**
  Este guia (Guia 02) é o correto. Continue lendo.

- **Dashboard novo e quero metadados IBGE (código, centroide, área) junto com a triplicação?**
  Use [[Guia_03_expansao_municipio_ibge]].

---

## Quando usar

- Dashboard Looker com filtros "Estado: Todos" e "Município: Todos"
- Precisa que os Big Numbers e tabelas funcionem em todos os níveis de agregação
- Fonte territorial: `filtro_territorio` (tem ids fake para "Todos")

## Como funciona

A tabela `filtro_territorio` tem três níveis de `id`:
- **7 dígitos**: Município (ex: `3104007` = Araxá-MG)
- **2 dígitos**: Estado (ex: `31` = Minas Gerais, título "Todos")
- **`99`**: País (Brasil, título "Todos")

A estratégia é **triplicar os dados**: cada registro do nível município é replicado para os níveis estado e país, permitindo que os filtros "Todos" funcionem corretamente.

---

## CONCEITO CHAVE: Campos de Filtro vs Campos de Exibição

A triplicação exige **dois pares de campos** para estado e município:

| Campo | Propósito | Valores possíveis |
|-------|-----------|-------------------|
| `estado` | **FILTRO** do Looker | nome_uf OU `'Todos'` |
| `municipio` | **FILTRO** do Looker | nome_ente OU `'Todos'` |
| `estado_nome` | **EXIBIÇÃO** em tabelas/gráficos | **sempre** o nome real do estado |
| `municipio_nome` | **EXIBIÇÃO** em tabelas/gráficos | **sempre** o nome real do município/ente |

### Por que dois pares?

Os filtros do Looker usam o valor literal `'Todos'` para selecionar o nível de agregação.
Mas na **exibição** (tabelas, gráficos, tooltips), queremos sempre ver o nome real.

> Se este conceito não ficou claro, releia antes de continuar -- é fundamental para entender o template.

### Exemplo com Goiânia-GO:

```
NÍVEL MUNICÍPIO:  estado=Goiás,  municipio=Goiânia,  estado_nome=Goiás,  municipio_nome=Goiânia
NÍVEL ESTADO:     estado=Goiás,  municipio=Todos,    estado_nome=Goiás,  municipio_nome=Goiânia
NÍVEL PAÍS:       estado=Todos,  municipio=Todos,    estado_nome=Goiás,  municipio_nome=Goiânia
```

Quando o Looker filtra `estado=Todos` + `municipio=Todos` (nível país):
- Os **filtros** casam com as linhas do nível país
- A **tabela** exibe `estado_nome=Goiás` e `municipio_nome=Goiânia` (nomes reais!)
- O Looker agrega (SUM) os valores de todos os municípios

### No Looker Studio:

| Componente | Usa campo de... | Exemplo |
|------------|----------------|---------|
| Filtro dropdown de Estado | `estado` (filtro) | Inclui "Todos" como opção |
| Filtro dropdown de Município | `municipio` (filtro) | Inclui "Todos" como opção |
| Coluna "Estado" na tabela | `estado_nome` (exibição) | Mostra "Goiás", "Bahia", etc. |
| Coluna "Município" na tabela | `municipio_nome` (exibição) | Mostra "Goiânia", "Salvador", etc. |
| Scorecard / Big Number | Qualquer métrica | SUM funciona no nível selecionado |

---

## Template SQL

Abaixo está o template completo. Antes de cada CTE, há uma explicação do que ela faz, por que é necessária e qual é o erro mais comum ao modificá-la. Leia cada bloco com atenção antes de adaptar ao seu caso.

### CTE `territorio` -- Referência territorial

- **Objetivo**: Carregar a tabela de referência com os IDs territoriais (7 dígitos para município, 2 para estado, 99 para país).
- **Por que**: Sem esta CTE, não há como mapear o nome do município para o código IBGE que o `filtro_territorio` usa. O JOIN posterior depende desses IDs.
- **Armadilha comum**: Trocar a tabela `filtro_territorio` por outra tabela territorial que não tenha os IDs fake (2 dígitos e 99). Se a referência não tiver esses níveis, a triplicação não funciona.

### CTE `dados_de_origem` -- Tratamento de inconsistências

- **Objetivo**: Normalizar nomes de municípios com grafia divergente e classificar a região de cada UF.
- **Por que**: A tabela de origem pode ter "Cidade de Goiás" em vez de "Goiás", ou "Comboriu" em vez de "Camboriú". Sem esse tratamento, o JOIN com `territorio` falha silenciosamente (retorna NULL) e você perde registros.
- **Armadilha comum**: Assumir que os nomes na origem estão limpos. Sempre verifique se há municípios sem match depois do JOIN -- um `WHERE id IS NULL` na `dados_com_id` revela os casos problemáticos.

### CTE `dados_com_id` -- Vinculação territorial via LEFT JOIN

- **Objetivo**: Associar cada registro da origem ao seu ID territorial via o nome do município.
- **Por que**: As CTEs de agregação (município, estado, país) dependem do campo `id` para determinar o nível territorial. Sem o JOIN, o `id` fica NULL e o registro é descartado pelos filtros `WHERE id IS NOT NULL`.
- **Armadilha comum**: Usar INNER JOIN em vez de LEFT JOIN. Com INNER JOIN, qualquer município com grafia diferente some silenciosamente dos resultados sem gerar erro.

### CTEs `agregado_municipio`, `agregado_estado`, `agregado_pais` -- A triplicação

- **Objetivo**: Criar as três cópias de cada registro -- uma para cada nível de filtro (município, estado, país). Este é o **núcleo** do template.
- **Por que**: Sem esses três blocos, o Looker só teria dados no nível município. Os filtros "Todos" no dropdown de estado ou município não encontrariam nenhuma linha e o dashboard ficaria vazio.
- **Armadilha comum**: Colocar "Todos" ou "Brasil" nos campos de **exibição** (`estado_nome`, `municipio_nome`). Esses campos devem **sempre** conter o nome real. O valor "Todos" só vai nos campos de **filtro** (`estado`, `municipio`). Veja a seção [[05-armadilhas|armadilhas comuns]].

### CTE `dados_combinados` + SELECT final -- União e labels

- **Objetivo**: Unir os três níveis com `UNION ALL` e gerar os campos `nome_territorio` e `titulo` para exibição nos filtros do Looker.
- **Por que**: O `UNION ALL` é o que de fato materializa a triplicação. O SELECT final adiciona labels legíveis que o Looker usa nos dropdowns.
- **Armadilha comum**: Usar `UNION` (sem ALL) em vez de `UNION ALL`. O `UNION` faz deduplicação, o que pode remover registros legítimos quando dois municípios têm métricas idênticas.

### Código completo

```sql
-- =============================================================================
-- TEMPLATE: Expansão Territorial (Município → Estado → País)
-- Usa filtro_territorio como referência
-- Substitua os placeholders <<...>> pelos valores do seu caso
-- =============================================================================

CREATE OR REPLACE TABLE `<<PROJETO>>.<<DATASET>>.<<TABELA_DESTINO>>` AS
WITH
  -- Referência territorial
  territorio AS (
    SELECT id, municipio, estado, titulo
    FROM `br-mec-segape-dev.projeto_painel_ministro.filtro_territorio`
  ),

  -- Dados de origem com tratamento de município
  dados_de_origem AS (
    SELECT
      CASE
        WHEN <<CAMPO_MUNICIPIO>> = 'Cidade de Goiás' THEN 'Goiás'
        WHEN <<CAMPO_MUNICIPIO>> LIKE 'Combori%' THEN 'Camboriú'
        WHEN <<CAMPO_MUNICIPIO>> = 'Santo Antônio de Leverger' THEN 'Santo Antônio do Leverger'
        ELSE <<CAMPO_MUNICIPIO>>
      END AS no_municipio,
      TRIM(<<CAMPO_UF>>) AS uf,
      CASE
        WHEN TRIM(<<CAMPO_UF>>) IN ('AC', 'AP', 'AM', 'PA', 'RO', 'RR', 'TO') THEN 'Norte'
        WHEN TRIM(<<CAMPO_UF>>) IN ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'Nordeste'
        WHEN TRIM(<<CAMPO_UF>>) IN ('DF', 'GO', 'MT', 'MS') THEN 'Centro-Oeste'
        WHEN TRIM(<<CAMPO_UF>>) IN ('ES', 'MG', 'RJ', 'SP') THEN 'Sudeste'
        WHEN TRIM(<<CAMPO_UF>>) IN ('PR', 'RS', 'SC') THEN 'Sul'
        ELSE 'Indefinido'
      END AS regiao,
      <<DEMAIS_CAMPOS>>
    FROM `<<PROJETO>>.<<DATASET>>.<<TABELA_ORIGEM>>`
  ),

  -- Resolve id territorial via nome do município
  dados_com_id AS (
    SELECT t.id, t.estado AS estado_territorial, d.*
    FROM dados_de_origem d
    LEFT JOIN territorio t
      ON TRIM(CONCAT(d.no_municipio, ' - ', d.uf)) = TRIM(t.municipio)
  ),

  -- =========================================================================
  -- EXPANSÃO TERRITORIAL (TRIPLICAÇÃO)
  --
  -- estado / municipio           → campos de FILTRO (usam "Todos")
  -- estado_nome / municipio_nome → campos de EXIBIÇÃO (sempre nome real)
  -- =========================================================================

  -- Nível 1: Município (id = 7 dígitos)
  agregado_municipio AS (
    SELECT
      id,
      'municipio' AS nivel_territorial,
      -- Filtros
      estado_territorial AS estado,
      CONCAT(no_municipio, ' - ', uf) AS municipio,
      -- Exibição (nome real)
      estado_territorial AS estado_nome,
      no_municipio AS municipio_nome,
      <<CAMPOS_PARA_UNION>>
    FROM dados_com_id
    WHERE id IS NOT NULL AND LENGTH(id) = 7
  ),

  -- Nível 2: Estado (id = 2 primeiros dígitos)
  agregado_estado AS (
    SELECT
      SUBSTR(id, 1, 2) AS id,
      'estado' AS nivel_territorial,
      -- Filtros
      estado_territorial AS estado,
      'Todos' AS municipio,
      -- Exibição (nome real)
      estado_territorial AS estado_nome,
      no_municipio AS municipio_nome,
      <<CAMPOS_PARA_UNION>>
    FROM dados_com_id
    WHERE id IS NOT NULL AND LENGTH(id) = 7
  ),

  -- Nível 3: País (id = '99')
  agregado_pais AS (
    SELECT
      '99' AS id,
      'pais' AS nivel_territorial,
      -- Filtros
      'Todos' AS estado,
      'Todos' AS municipio,
      -- Exibição (nome real — NÃO colocar 'Brasil' aqui!)
      estado_territorial AS estado_nome,
      no_municipio AS municipio_nome,
      <<CAMPOS_PARA_UNION>>
    FROM dados_com_id
    WHERE id IS NOT NULL AND LENGTH(id) = 7
  ),

  dados_combinados AS (
    SELECT * FROM agregado_municipio
    UNION ALL
    SELECT * FROM agregado_estado
    UNION ALL
    SELECT * FROM agregado_pais
  )

SELECT
  d.*,
  CASE
    WHEN d.nivel_territorial = 'municipio' THEN CONCAT(d.municipio_nome, ' - ', d.uf)
    WHEN d.nivel_territorial = 'estado' THEN 'Todos'
    ELSE 'Todos'
  END AS nome_territorio,
  CASE
    WHEN d.nivel_territorial = 'municipio' THEN CONCAT(d.municipio_nome, ' - ', d.uf)
    WHEN d.nivel_territorial = 'estado' THEN d.estado_nome
    ELSE 'Brasil'
  END AS titulo
FROM dados_combinados d;
```

---

## Placeholders

| Placeholder | Descrição | Exemplo |
|-------------|-----------|---------|
| `<<CAMPO_MUNICIPIO>>` | Campo de município na origem | `municipio` |
| `<<CAMPO_UF>>` | Campo de UF na origem | `sigla_uf` |
| `<<DEMAIS_CAMPOS>>` | Campos da tabela origem | `instituicao, campus, turmas, total_matriculas` |
| `<<CAMPOS_PARA_UNION>>` | Mesmos campos para os 3 blocos | `no_municipio, uf, regiao, instituicao, campus, turmas, total_matriculas` |
| `<<PROJETO>>` | Projeto GCP | `br-mec-segape-dev` |
| `<<DATASET>>` | Dataset | `andre_teste` |
| `<<TABELA_ORIGEM>>` | Tabela fonte | `stg_secadi_partiu_if` |
| `<<TABELA_DESTINO>>` | Tabela de saída | `partiu_if_oferta` |

## Estrutura da saída

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `id` | STRING | Código territorial (7 dígitos = município, 2 = estado, 99 = país) |
| `nivel_territorial` | STRING | `'municipio'`, `'estado'` ou `'pais'` |
| `estado` | STRING | **FILTRO**: nome do estado OU `'Todos'` (nível país) |
| `municipio` | STRING | **FILTRO**: `"Município - UF"` OU `'Todos'` (nível estado/país) |
| `estado_nome` | STRING | **EXIBIÇÃO**: sempre o nome real do estado |
| `municipio_nome` | STRING | **EXIBIÇÃO**: sempre o nome real do município/ente |
| `nome_territorio` | STRING | Label formatado para filtro |
| `titulo` | STRING | Label para exibição no filtro |
| `...` | | Demais campos da origem |

---

## Como funciona no Looker

1. **Filtro "Estado: Todos" + "Município: Todos"**:
   - Seleciona nível país (`id = '99'`)
   - Tabela exibe `estado_nome` e `municipio_nome` com nomes reais de cada ente
   - Scorecards somam todos os municípios

2. **Filtro "Estado: Goiás" + "Município: Todos"**:
   - Seleciona nível estado para Goiás (`id = '52'`)
   - Tabela exibe cada município de Goiás via `municipio_nome`
   - Scorecards somam só Goiás

3. **Filtro "Estado: Goiás" + "Município: Goiânia - GO"**:
   - Seleciona nível município (`id = '5208707'`)
   - Tabela exibe só Goiânia

---

## Erros comuns

Esta seção lista os erros que mais aparecem em code reviews. Se você está adaptando o template pela primeira vez, leia cada item -- vai economizar tempo de depuração. Para mais detalhes sobre armadilhas gerais do projeto, veja [[05-armadilhas]].

### 1. Colocar "Todos" ou "Brasil" nos campos de exibição

Os campos `estado_nome` e `municipio_nome` existem para exibir o nome real do município/estado em tabelas e gráficos. Se você colocar `'Todos'` ou `'Brasil'` nesses campos, o Looker vai mostrar "Todos" como nome de município na tabela -- o que não faz sentido para o usuário final.

**Regra**: `'Todos'` só aparece nos campos de **filtro** (`estado`, `municipio`). Nos campos de **exibição** (`estado_nome`, `municipio_nome`), sempre o nome real.

### 2. Não separar campos de filtro dos campos de exibição

Se você usar o mesmo campo tanto para filtro quanto para exibição, vai ter dois problemas: ou o filtro "Todos" não funciona (porque o campo nunca contém "Todos"), ou a tabela exibe "Todos" como nome (porque o campo de exibição herda o valor de filtro). Releia a seção "CONCEITO CHAVE" acima.

### 3. Não tratar métricas fixas com UNNEST (bug de multiplicação)

Se a tabela tem um UNNEST de meses e uma métrica que não varia por mês (ex: total de matrículas), essa métrica será multiplicada pelo número de meses. A seção "Tratamento de métricas fixas com UNNEST de meses" abaixo explica a solução.

### 4. Usar WHERE em vez de filtragem por nível

A triplicação já cuida da filtragem via os campos `estado` e `municipio`. Adicionar `WHERE estado = 'Goiás'` diretamente na query final elimina os registros dos níveis estado e país, quebrando o mecanismo. O filtro deve ser aplicado **no Looker**, não no SQL.

---

## Cuidados

1. **Métricas com valor fixo por ente** (ex: matrículas, fomento total): Se o dado não varia por mês e a tabela tem UNNEST de meses, use `IF(ordem = 1, valor, NULL)` para evitar multiplicação. Veja seção abaixo.
2. **Coordenadas**: Elas propagam para todos os níveis (funciona para mapas).
3. **Deduplicação**: Se a origem tem duplicatas, trate antes da expansão.

---

## Tratamento de métricas fixas com UNNEST de meses

### Por que isso acontece

Quando você usa `UNNEST` para transformar colunas de meses (ex: `valor_out`, `valor_nov`, `valor_dez`, `valor_jan`) em linhas, cada registro original vira N linhas -- uma por mês. Métricas que variam por mês (como `valor_repasse`) ficam corretas, porque cada linha tem o valor daquele mês específico. Porém, métricas que **não variam por mês** (como `matriculas` ou `valor_total_fomento`) são copiadas idênticas em todas as N linhas. Quando o Looker faz `SUM`, essas métricas fixas são somadas N vezes, gerando um total N vezes maior que o real.

**Solução**: Atribuir o valor apenas ao primeiro mês, NULL nos demais:

```sql
registros_repasse AS (
  SELECT
    ...,
    IF(r.ordem = 1, matriculas, NULL) AS matriculas,
    IF(r.ordem = 1, valor_total_fomento, NULL) AS valor_total_fomento,
    r.valor_repasse  -- este varia por mês, fica normal
  FROM base,
  UNNEST([
    STRUCT(1 AS ordem, '2025-10' AS ano_mes_str, valor_out AS valor_repasse),
    STRUCT(2, '2025-11', valor_nov),
    STRUCT(3, '2025-12', valor_dez),
    STRUCT(4, '2026-01', valor_jan)
  ]) AS r
)
```

No Looker, use SUM normalmente -- NULLs são ignorados, o total fica correto.

---

## Fontes com código IBGE de 2 dígitos (redes estaduais)

Se a tabela de origem mistura municípios (código IBGE 7 dígitos) e redes estaduais (código IBGE 2 dígitos), faça JOINs separados:

```sql
-- Municipais: JOIN por id_municipio
dados_municipais AS (
  SELECT ... FROM dados JOIN municipios ON codigo_ibge = id_municipio
  WHERE LENGTH(codigo_ibge) = 7
),
-- Estaduais: JOIN por id_uf (coordenadas da capital)
dados_estaduais AS (
  SELECT ... FROM dados JOIN capitais ON codigo_ibge = id_uf
  WHERE LENGTH(codigo_ibge) = 2
),
-- União
dados_com_id AS (
  SELECT * FROM dados_municipais UNION ALL SELECT * FROM dados_estaduais
)
```

Para entender como a estrutura territorial se encaixa na arquitetura geral do projeto, veja [[02-arquitetura-projeto]].

---

## Navegação

| Documento | Descrição |
|-----------|-----------|
| [Guia 01 - Coordenadas](Guia_01_coordenadas_instituicoes.md) | Integrar lat/long via PNP |
| [Guia 03 - Expansão com município IBGE](Guia_03_expansao_municipio_ibge.md) | Triplicação com centroide IBGE |
| [02 - Arquitetura do Projeto](../02-arquitetura-projeto.md) | Estrutura do projeto dbt |

[Voltar ao índice](../onboarding.md)
