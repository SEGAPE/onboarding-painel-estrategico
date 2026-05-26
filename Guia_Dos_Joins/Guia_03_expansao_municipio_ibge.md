---
titulo: "Guia de Joins: Expansão Territorial com Municípios IBGE"
aliases:
  - "município ibge"
  - "guia joins 3"
  - "centroide"
tags:
  - sql
  - bigquery
  - joins
  - território
  - coordenadas
  - ibge
  - looker
  - guia
data_criacao: "2026-01-01"
data_modificacao: "2026-04-08"
---

# Expansão Territorial com `educacao_dados_mestres.municipio`

## Por que este guia existe

Este é o template mais completo da série de guias de joins territoriais. Ele usa a tabela nativa de municípios do IBGE (`educacao_dados_mestres.municipio`), que traz:

- **Coordenadas geográficas nativas** via campo `centroide` (tipo GEOGRAPHY) -- não depende de tabela intermediária.
- **Metadados ricos**: região, mesorregião, microrregião, região metropolitana, DDD, amazônia legal.
- **Mais de 5.500 municípios** com centroide preenchido.

Se você está criando um dashboard novo e não tem dependências anteriores com `filtro_territorio` ou `pnp_painel_instituicao`, **este é o template recomendado**. Ele entrega tudo que os outros dois entregam e mais.

---

## Árvore de decisão: Qual guia usar?

Antes de seguir, confirme que este é o guia certo para o seu caso:

| Pergunta | Resposta |
|----------|----------|
| Preciso só de coordenadas de instituições/campi? | Use [[Guia_01_coordenadas_instituicoes]] |
| Já uso `filtro_territorio` no meu dashboard? | Use [[Guia_02_expansao_filtro_territorio]] |
| Dashboard novo, quero o template mais completo? | **Este guia (Guia 03)** |

---

## Quando usar

- Dashboard Looker com filtros "Estado: Todos" e "Município: Todos"
- Fonte territorial: tabela de municípios IBGE (`educacao_dados_mestres.municipio`)
- Vantagem: tem **centroide** (coordenadas geográficas nativas) e mais metadados

---

## Diferença do Template 2

| Aspecto | Template 2 (filtro_territorio) | Template 3 (município) |
|---------|-------------------------------|------------------------|
| Fonte | `filtro_territorio` | `educacao_dados_mestres.municipio` |
| Coordenadas | Via `pnp_painel_instituicao` | Nativa (`centroide` GEOGRAPHY) |
| Metadados | Básico (estado, título) | Rico (região, mesorregião, DDD, etc.) |
| IDs fake | Já tem (99, 31, etc.) | Precisa criar na expansão |

Para detalhes sobre o Template 2, veja [[Guia_02_expansao_filtro_territorio]].

---

## CONCEITO CHAVE: Campos de Filtro vs Campos de Exibição

> Este conceito é o mesmo do [[Guia_02_expansao_filtro_territorio]]. Se já leu lá, pode pular para o Template SQL.

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

### Exemplo com Goiânia-GO:

```
NÍVEL MUNICÍPIO:  estado=Goiás,  municipio=Goiânia,  estado_nome=Goiás,  municipio_nome=Goiânia
NÍVEL ESTADO:     estado=Goiás,  municipio=Todos,    estado_nome=Goiás,  municipio_nome=Goiânia
NÍVEL PAÍS:       estado=Todos,  municipio=Todos,    estado_nome=Goiás,  municipio_nome=Goiânia
```

Quando o Looker filtra `estado=Todos` + `municipio=Todos` (nível país):
- Os **filtros** casam com as linhas do nível país
- A **tabela** exibe `estado_nome=Goias` e `municipio_nome=Goiania` (nomes reais!)
- O Looker agrega (SUM) os valores de todos os municípios

### No Looker Studio:

| Componente | Usa campo de... | Exemplo |
|------------|----------------|---------|
| Filtro dropdown de Estado | `estado` (filtro) | Inclui "Todos" como opção |
| Filtro dropdown de Município | `municipio` (filtro) | Inclui "Todos" como opção |
| Coluna "Estado" na tabela | `estado_nome` (exibição) | Mostra "Goiás", "Bahia", etc. |
| Coluna "Município" na tabela | `municipio_nome` (exibição) | Mostra "Goiânia", "Salvador", etc. |
| Scorecard / Big Number | Qualquer métrica | SUM funciona no nível selecionado |

Se esse conceito ainda não ficou claro, veja os exemplos detalhados em [[Guia_02_expansao_filtro_territorio]] e as armadilhas relacionadas em [[05-armadilhas]].

---

## Template SQL

O template abaixo é composto por várias CTEs (Common Table Expressions) encadeadas. Cada CTE tem uma responsabilidade específica. Antes do bloco SQL completo, vamos entender o que cada uma faz.

---

### Anatomia das CTEs

#### 1. `municipios_ibge` -- Referência de municípios com coordenadas

- **Objetivo**: Extrair latitude e longitude a partir do campo `centroide` (tipo GEOGRAPHY) de cada município.
- **Por que**: Sem esta CTE, você não tem coordenadas para plotar pontos no mapa. Ela é a base de todos os JOINs territoriais deste template.
- **Armadilha comum**: Esquecer o filtro `WHERE centroide IS NOT NULL`. Alguns municípios não têm centroide preenchido -- sem o filtro, você gera linhas com latitude/longitude NULL que quebram visualizações de mapa.

#### 2. `capitais` -- Coordenadas das capitais estaduais

- **Objetivo**: Obter a coordenada da capital de cada estado para usar como fallback em registros de nível estadual (redes estaduais, por exemplo).
- **Por que**: Registros de rede estadual não têm município específico. Sem esta CTE, esses registros ficariam sem coordenada e não apareceriam no mapa.
- **Armadilha comum**: Não entender o padrão `ARRAY_AGG(...ORDER BY id_municipio LIMIT 1)[OFFSET(0)]`. Esse padrão funciona assim: (1) filtra apenas municípios com `capital_uf = 1`, (2) agrupa por estado, (3) dentro de cada grupo, ordena por `id_municipio` e pega apenas o primeiro resultado. Como cada estado tem apenas uma capital, o `LIMIT 1` garante que o array tenha exatamente um elemento, e o `[OFFSET(0)]` extrai esse elemento. É uma forma segura de fazer "pegar um valor por grupo" no BigQuery.

#### 3. `estados` -- Lista distinta de estados

- **Objetivo**: Gerar uma lista única de estados a partir dos municípios já filtrados.
- **Por que**: Usada para garantir que todos os estados apareçam na expansão, mesmo que algum estado não tenha dados na tabela de origem.
- **Armadilha comum**: Tentar gerar a lista de estados a partir da tabela de origem em vez de `municipios_ibge`. Se a origem não tem dados de algum estado, esse estado some da expansão.

#### 4. `dados_de_origem` -- Dados fonte com correções

- **Objetivo**: Ler a tabela de origem e aplicar correções de grafia em nomes de municípios que diferem do padrão IBGE.
- **Por que**: Sem correção, municípios como "Cidade de Goiás" não fazem JOIN com o IBGE (que registra apenas "Goiás") e ficam sem coordenada.
- **Armadilha comum**: Assumir que os nomes na origem estão corretos. Sempre confira se há municípios sem match após o JOIN -- eles provavelmente têm grafia diferente do IBGE.

#### 5. `dados_com_id` -- JOIN com IBGE via nome normalizado

- **Objetivo**: Vincular cada registro da origem ao município IBGE correspondente, usando `LOWER(TRIM(...))` para normalizar a comparação.
- **Por que**: Sem esse JOIN, os registros não têm `id_municipio`, `id_uf`, coordenadas, nem metadados do IBGE.
- **Armadilha comum**: Fazer JOIN apenas por nome do município sem incluir a UF. Existem municípios homônimos em estados diferentes (ex: "Bom Jesus" existe em vários estados). Sempre faça JOIN por `nome + sigla_uf`.

#### 6. `agregado_municipio` -- Nível 1 da triplicação

- **Objetivo**: Gerar as linhas de nível municipal -- cada registro aparece com seu município e estado reais nos campos de filtro.
- **Por que**: Este é o nível mais granular. Quando o usuário seleciona um município específico no filtro, são estas linhas que aparecem.
- **Armadilha comum**: Esquecer o filtro `WHERE id IS NOT NULL AND LENGTH(id) = 7`. Sem ele, registros que não fizeram match no JOIN (id NULL) ou registros estaduais (id de 2 dígitos) entram indevidamente neste nível.

#### 7. `agregado_estado` -- Nível 2 da triplicação

- **Objetivo**: Gerar as linhas de nível estadual -- `municipio = 'Todos'` no campo de filtro, mas `municipio_nome` mantém o nome real.
- **Por que**: Quando o usuário seleciona um estado e "Todos" os municípios, o Looker agrega (SUM) todas estas linhas daquele estado.
- **Armadilha comum**: Colocar `'Todos'` no campo `municipio_nome` (exibição). O campo de exibição **nunca** recebe "Todos" -- ele sempre mostra o nome real. Veja [[05-armadilhas]] para mais detalhes.

#### 8. `agregado_pais` -- Nível 3 da triplicação

- **Objetivo**: Gerar as linhas de nível país -- `estado = 'Todos'` e `municipio = 'Todos'` nos campos de filtro.
- **Por que**: Quando o usuário seleciona "Todos" em ambos os filtros, o Looker agrega todas estas linhas para mostrar o total nacional.
- **Armadilha comum**: Mesma do nível estado -- nunca colocar "Brasil" ou "Todos" nos campos de exibição (`estado_nome`, `municipio_nome`).

#### 9. `dados_combinados` + SELECT final -- União com labels de exibição

- **Objetivo**: Unir os três níveis (UNION ALL) e adicionar campos calculados como `nome_territorio` e `titulo` para facilitar a exibição no dashboard.
- **Por que**: O UNION ALL junta as três cópias dos dados. O SELECT final adiciona labels formatados que o Looker usa em filtros e títulos.
- **Armadilha comum**: Esquecer que a ordem das colunas no UNION ALL deve ser **idêntica** em todos os blocos. Se você adicionar um campo em `agregado_municipio`, precisa adicionar na mesma posição em `agregado_estado` e `agregado_pais`.

---

### Bloco SQL completo

```sql
-- =============================================================================
-- TEMPLATE: Expansao Territorial com tabela de Municipios IBGE
-- Fonte: br-mec-segape-dev.educacao_dados_mestres.municipio
-- Substitua os placeholders <<...>> pelos valores do seu caso
-- =============================================================================

CREATE OR REPLACE TABLE `<<PROJETO>>.<<DATASET>>.<<TABELA_DESTINO>>` AS
WITH
  -- Referencia de municipios IBGE (com centroide)
  municipios_ibge AS (
    SELECT
      id_municipio,
      id_uf,
      nome,
      sigla_uf,
      nome_uf,
      nome_regiao,
      ST_Y(centroide) AS latitude,
      ST_X(centroide) AS longitude,
      CONCAT(CAST(ST_Y(centroide) AS STRING), ',', CAST(ST_X(centroide) AS STRING)) AS coordenada
    FROM `br-mec-segape-dev.educacao_dados_mestres.municipio`
    WHERE centroide IS NOT NULL
  ),

  -- Capitais estaduais (para coordenadas de registros de rede estadual)
  capitais AS (
    SELECT
      id_uf,
      sigla_uf,
      nome_uf,
      nome_regiao,
      ARRAY_AGG(ST_Y(centroide) ORDER BY id_municipio LIMIT 1)[OFFSET(0)] AS latitude,
      ARRAY_AGG(ST_X(centroide) ORDER BY id_municipio LIMIT 1)[OFFSET(0)] AS longitude,
      ARRAY_AGG(
        CONCAT(CAST(ST_Y(centroide) AS STRING), ',', CAST(ST_X(centroide) AS STRING))
        ORDER BY id_municipio LIMIT 1
      )[OFFSET(0)] AS coordenada
    FROM `br-mec-segape-dev.educacao_dados_mestres.municipio`
    WHERE centroide IS NOT NULL
      AND capital_uf = 1
    GROUP BY id_uf, sigla_uf, nome_uf, nome_regiao
  ),

  -- Tabela de estados (agregada dos municipios)
  estados AS (
    SELECT DISTINCT
      id_uf,
      sigla_uf,
      nome_uf,
      nome_regiao
    FROM municipios_ibge
  ),

  -- Dados de origem
  dados_de_origem AS (
    SELECT
      CASE
        WHEN <<CAMPO_MUNICIPIO>> = 'Cidade de Goias' THEN 'Goias'
        WHEN <<CAMPO_MUNICIPIO>> LIKE 'Combori%' THEN 'Camboriú'
        WHEN <<CAMPO_MUNICIPIO>> = 'Santo Antonio de Leverger' THEN 'Santo Antonio do Leverger'
        ELSE <<CAMPO_MUNICIPIO>>
      END AS no_municipio,
      TRIM(<<CAMPO_UF>>) AS uf,
      <<DEMAIS_CAMPOS>>
    FROM `<<PROJETO>>.<<DATASET>>.<<TABELA_ORIGEM>>`
  ),

  -- JOIN com municipios IBGE para obter id e coordenadas
  -- Se a origem tem codigos IBGE de 7 digitos (municipio) E 2 digitos (estado),
  -- faca JOINs separados. Veja secao "Fontes com codigo IBGE misto".
  dados_com_id AS (
    SELECT
      m.id_municipio AS id,
      m.id_uf,
      m.nome_uf,
      m.nome_regiao AS regiao,
      m.latitude,
      m.longitude,
      m.coordenada,
      d.*
    FROM dados_de_origem d
    LEFT JOIN municipios_ibge m
      ON LOWER(TRIM(d.no_municipio)) = LOWER(TRIM(m.nome))
      AND TRIM(d.uf) = TRIM(m.sigla_uf)
  ),

  -- =========================================================================
  -- EXPANSAO TERRITORIAL (TRIPLICACAO)
  --
  -- estado / municipio           -> campos de FILTRO (usam "Todos")
  -- estado_nome / municipio_nome -> campos de EXIBICAO (sempre nome real)
  --
  -- REGRA FUNDAMENTAL:
  --   estado_nome e municipio_nome NUNCA recebem "Todos" ou "Brasil".
  --   Eles SEMPRE mantem o nome real da linha original (ente, nome_uf).
  --   Isso permite que tabelas e graficos exibam nomes reais mesmo quando
  --   o filtro do Looker esta em "Todos".
  --
  -- Exemplo com Goiania-GO:
  --   nivel_municipio: estado=Goias,  municipio=Goiania,  estado_nome=Goias,  municipio_nome=Goiania
  --   nivel_estado:    estado=Goias,  municipio=Todos,    estado_nome=Goias,  municipio_nome=Goiania
  --   nivel_pais:      estado=Todos,  municipio=Todos,    estado_nome=Goias,  municipio_nome=Goiania
  -- =========================================================================

  -- Nivel 1: Municipio (id = 7 digitos)
  agregado_municipio AS (
    SELECT
      id,
      id_uf,
      nome_uf,
      regiao,
      latitude,
      longitude,
      coordenada,
      'municipio' AS nivel_territorial,
      -- Filtros
      nome_uf AS estado,
      no_municipio AS municipio,
      -- Exibicao (nome real)
      nome_uf AS estado_nome,
      no_municipio AS municipio_nome,
      <<CAMPOS_PARA_UNION>>
    FROM dados_com_id
    WHERE id IS NOT NULL AND LENGTH(id) = 7
  ),

  -- Nivel 2: Estado (id = id_uf de 2 digitos)
  agregado_estado AS (
    SELECT
      id_uf AS id,
      id_uf,
      nome_uf,
      regiao,
      latitude,
      longitude,
      coordenada,
      'estado' AS nivel_territorial,
      -- Filtros
      nome_uf AS estado,
      'Todos' AS municipio,
      -- Exibicao (nome real -- NAO colocar "Todos" aqui!)
      nome_uf AS estado_nome,
      no_municipio AS municipio_nome,
      <<CAMPOS_PARA_UNION>>
    FROM dados_com_id
    WHERE id IS NOT NULL AND LENGTH(id) = 7
  ),

  -- Nivel 3: Pais (id = '99')
  agregado_pais AS (
    SELECT
      '99' AS id,
      '99' AS id_uf,
      'Brasil' AS nome_uf,
      'Brasil' AS regiao,
      latitude,
      longitude,
      coordenada,
      'pais' AS nivel_territorial,
      -- Filtros
      'Todos' AS estado,
      'Todos' AS municipio,
      -- Exibicao (nome real -- NAO colocar "Brasil" aqui!)
      nome_uf AS estado_nome,
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

-- SELECT final com labels para filtros
SELECT
  d.id,
  CASE
    WHEN d.nivel_territorial = 'municipio' THEN CONCAT(d.municipio_nome, ' - ', d.uf)
    WHEN d.nivel_territorial = 'estado' THEN 'Todos'
    ELSE 'Todos'
  END AS nome_territorio,
  d.estado,
  d.municipio,
  d.estado_nome,
  d.municipio_nome,
  CASE
    WHEN d.nivel_territorial = 'municipio' THEN CONCAT(d.municipio_nome, ' - ', d.uf)
    WHEN d.nivel_territorial = 'estado' THEN d.estado_nome
    ELSE 'Brasil'
  END AS titulo,
  d.nivel_territorial,
  d.regiao,
  d.latitude,
  d.longitude,
  d.coordenada,
  <<CAMPOS_FINAIS>>
FROM dados_combinados d;
```

---

## Placeholders

| Placeholder | Descrição | Exemplo |
|-------------|-----------|---------|
| `<<CAMPO_MUNICIPIO>>` | Campo de município na origem | `municipio` |
| `<<CAMPO_UF>>` | Campo de UF na origem | `sigla_uf` |
| `<<DEMAIS_CAMPOS>>` | Campos da tabela origem | `instituicao, campus, turmas, total_matriculas` |
| `<<CAMPOS_PARA_UNION>>` | Campos para os 3 blocos de expansão | `no_municipio, uf, instituicao, campus, turmas, total_matriculas` |
| `<<CAMPOS_FINAIS>>` | Campos no SELECT final | `d.no_municipio, d.uf, d.instituicao, d.campus, d.turmas, d.total_matriculas` |
| `<<PROJETO>>` | Projeto GCP | `br-mec-segape-dev` |
| `<<DATASET>>` | Dataset | `andre_teste` |
| `<<TABELA_ORIGEM>>` | Tabela fonte | `stg_secadi_partiu_if` |
| `<<TABELA_DESTINO>>` | Tabela de saída | `partiu_if_oferta_v2` |

---

## Estrutura da saída

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `id` | STRING | Código territorial (7 dígitos = município, 2 = estado, 99 = país) |
| `nivel_territorial` | STRING | `'municipio'`, `'estado'` ou `'pais'` |
| `estado` | STRING | **FILTRO**: nome do estado OU `'Todos'` (nível país) |
| `municipio` | STRING | **FILTRO**: nome do ente OU `'Todos'` (nível estado/país) |
| `estado_nome` | STRING | **EXIBIÇÃO**: sempre o nome real do estado |
| `municipio_nome` | STRING | **EXIBIÇÃO**: sempre o nome real do município/ente |
| `nome_territorio` | STRING | Label formatado ("Araxá - MG" ou "Todos") |
| `titulo` | STRING | Label para exibição no filtro |
| `...` | | Demais campos da origem |

---

## Vantagens desta abordagem

1. **Coordenadas nativas**: O `centroide` é tipo GEOGRAPHY, então `ST_Y()` e `ST_X()` extraem lat/long precisos do centro do município.

2. **Mais metadados disponíveis**:
   - `nome_regiao` (Norte, Nordeste, etc.)
   - `nome_mesorregiao`, `nome_microrregiao`
   - `nome_regiao_metropolitana`
   - `ddd`
   - `amazonia_legal`

3. **JOIN mais robusto**: Por `nome + sigla_uf` com LOWER/TRIM, evita problemas de case.

4. **Campos de filtro e exibição separados**: Permite que tabelas e gráficos sempre mostrem nomes reais, independente do nível de filtro selecionado.

---

## Erros comuns

Estes são os erros mais frequentes ao usar este template. Consulte também [[05-armadilhas]] para a lista completa de armadilhas dos guias de joins.

### 1. Não tratar códigos IBGE mistos (2 e 7 dígitos)

Se a tabela de origem mistura registros municipais (código IBGE de 7 dígitos) e estaduais (código de 2 dígitos), um único JOIN não resolve. Registros estaduais não têm `id_municipio` de 7 dígitos -- eles precisam de JOIN separado com a CTE `capitais`. Veja a seção "Fontes com código IBGE misto" abaixo.

### 2. Esquecer o filtro `centroide IS NOT NULL`

A tabela `educacao_dados_mestres.municipio` tem municípios com `centroide` nulo. Se você não filtrar, `ST_Y(centroide)` e `ST_X(centroide)` retornam NULL, e o mapa no Looker fica com pontos faltando ou quebra completamente.

### 3. Confundir ST_Y (latitude) com ST_X (longitude)

No BigQuery, `ST_Y()` extrai a coordenada Y, que corresponde à **latitude**. `ST_X()` extrai a coordenada X, que corresponde à **longitude**. Inverter os dois faz os pontos aparecerem em locais completamente errados no mapa (ex: no meio do oceano).

Regra mnemônica: **Y = lAtitude** (ambos têm "a"), **X = lOngitude** (ambos têm "o"). Ou simplesmente: latitude é vertical (Y), longitude é horizontal (X).

### 4. Confundir campos de filtro com campos de exibição

Este é o mesmo erro descrito no [[Guia_02_expansao_filtro_territorio]]: colocar `'Todos'` ou `'Brasil'` nos campos de exibição (`estado_nome`, `municipio_nome`). Campos de exibição **sempre** recebem o nome real. Campos de filtro (`estado`, `municipio`) são os únicos que recebem `'Todos'`.

### 5. JOIN apenas por nome, sem UF

Existem municípios com o mesmo nome em estados diferentes. JOIN só por `LOWER(TRIM(nome))` sem incluir `sigla_uf` pode gerar duplicatas ou matches errados.

---

## Extração de coordenadas do GEOGRAPHY

```sql
-- centroide e tipo GEOGRAPHY com formato "POINT(-64.30413 -9.15394)"
-- ST_Y extrai latitude (Y), ST_X extrai longitude (X)

SELECT
  nome,
  ST_Y(centroide) AS latitude,   -- -9.15394
  ST_X(centroide) AS longitude,  -- -64.30413
  CONCAT(CAST(ST_Y(centroide) AS STRING), ',', CAST(ST_X(centroide) AS STRING)) AS coordenada
FROM `br-mec-segape-dev.educacao_dados_mestres.municipio`
WHERE centroide IS NOT NULL
LIMIT 5;
```

---

## Tratamento de métricas fixas com UNNEST de meses

Se a tabela de origem tem repasses mensais (ex: out, nov, dez, jan) e você faz UNNEST para criar uma linha por mês, métricas que **não variam por mês** (como `matriculas` ou `valor_total_fomento`) seriam multiplicadas pelo número de meses.

**Solução**: Atribuir o valor apenas ao primeiro mês, NULL nos demais:

```sql
registros_repasse AS (
  SELECT
    ...,
    IF(r.ordem = 1, matriculas, NULL) AS matriculas,
    IF(r.ordem = 1, valor_total_fomento, NULL) AS valor_total_fomento,
    r.valor_repasse  -- este varia por mes, fica normal
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

**ATENÇÃO**: Com essa abordagem, gráficos temporais de `matriculas` por `ano_mes` vão mostrar barra só no primeiro mês. Se precisar do valor em todos os meses, use MAX como agregação no Looker em vez de SUM.

---

## Fontes com código IBGE misto (2 e 7 dígitos)

Se a tabela de origem mistura municípios (código IBGE 7 dígitos) e redes estaduais (código IBGE 2 dígitos), faça JOINs separados:

```sql
-- Municipais: JOIN por id_municipio (7 digitos)
dados_municipais AS (
  SELECT
    m.id_municipio AS id, m.id_uf, m.nome_uf, m.nome_regiao AS regiao,
    m.latitude, m.longitude, m.coordenada, d.*
  FROM registros d
  JOIN municipios_ibge m ON TRIM(d.codigo_ibge) = TRIM(m.id_municipio)
  WHERE LENGTH(TRIM(d.codigo_ibge)) = 7
),

-- Estaduais: JOIN por id_uf (2 digitos) -- usa coordenada da capital
dados_estaduais AS (
  SELECT
    c.id_uf AS id, c.id_uf, c.nome_uf, c.nome_regiao AS regiao,
    c.latitude, c.longitude, c.coordenada, d.*
  FROM registros d
  JOIN capitais c ON TRIM(d.codigo_ibge) = TRIM(c.id_uf)
  WHERE LENGTH(TRIM(d.codigo_ibge)) = 2
),

-- Uniao dos dois
dados_com_id AS (
  SELECT * FROM dados_municipais
  UNION ALL
  SELECT * FROM dados_estaduais
)
```

A CTE `capitais` usa `capital_uf = 1` para pegar a coordenada da capital do estado.

---

## Quando usar cada template

| Cenário | Template recomendado |
|---------|---------------------|
| Já usa `filtro_territorio` no dashboard | [[Guia_02_expansao_filtro_territorio]] (Template 2) |
| Quer coordenadas de centroide do município | Este guia (Template 3) |
| Quer coordenadas específicas de instituições/campi | [[Guia_01_coordenadas_instituicoes]] (Template 1) + [[Guia_02_expansao_filtro_territorio]] (Template 2) |
| Dashboard novo, sem dependências | Este guia (Template 3) -- mais completo |

---

## Navegação

| Documento | Descrição |
|-----------|-----------|
| [Guia 01 - Coordenadas](Guia_01_coordenadas_instituicoes.md) | Integrar lat/long via PNP |
| [Guia 02 - Expansão com filtro_territorio](Guia_02_expansao_filtro_territorio.md) | Triplicação com filtro_territorio |
| [02 - Arquitetura do Projeto](../02-arquitetura-projeto.md) | Estrutura do projeto dbt |

[Voltar ao índice](../onboarding.md)
