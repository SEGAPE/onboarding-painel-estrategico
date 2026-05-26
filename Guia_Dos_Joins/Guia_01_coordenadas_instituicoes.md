---
titulo: "Guia de Joins: Coordenadas de Instituições"
aliases:
  - "coordenadas"
  - "guia joins 1"
  - "latitude longitude"
tags:
  - sql
  - bigquery
  - joins
  - territorio
  - coordenadas
  - pnp
  - guia
data_criacao: "2026-01-01"
data_modificacao: "2026-04-08"
---

# Guia 01 -- Integração de Coordenadas de Instituições

## Por que este guia existe

Vários dashboards do MEC precisam exibir dados em mapas -- pontos no Looker Studio, camadas geográficas, filtros por região. Porém, a maioria das tabelas de origem (SECADI, CAPES, FNDE, etc.) traz apenas o nome do município e a sigla da UF, sem latitude nem longitude.

O problema é simples: sem coordenadas, não há como plotar nada em um mapa.

Este template resolve exatamente isso. Ele conecta qualquer tabela que tenha município e UF às coordenadas da tabela `pnp_painel_instituicao`, passando pela `filtro_territorio` para resolver o código IBGE. O resultado é uma query pronta para alimentar mapas no Looker, com latitude, longitude e o campo concatenado `coordenada` que o Looker Maps espera.

---

## Árvore de decisão: Qual guia usar?

Antes de aplicar este template, verifique se ele é o guia certo para o seu caso:

- **Preciso só de coordenadas (latitude/longitude) para um mapa?**
  Use este guia (Guia 01).

- **Preciso de filtros "Todos" no Looker e já uso `filtro_territorio`?**
  Use [[Guia_02_expansao_filtro_territorio]].

- **Dashboard novo, quero tudo (filtros territoriais + coordenadas nativas IBGE)?**
  Use [[Guia_03_expansao_municipio_ibge]].

---

## Quando usar

- Adicionar latitude/longitude a qualquer tabela que tenha **município** e **UF**
- Fonte de coordenadas: `pnp_painel_instituicao` (via `id_ibge`)

## Pré-requisitos

- Tabela de origem com campos de município e UF
- Tabela `filtro_territorio` para resolver `id` territorial a partir de `"Município - UF"`
- Tabela `pnp_painel_instituicao` com coordenadas e `id_ibge`

---

## Template SQL -- Explicação CTE por CTE

O template abaixo é composto por cinco CTEs encadeadas. Antes de cada uma, você encontra uma explicação do que ela faz, por que existe e qual erro comum deve evitar.

### CTE 1: `territorio`

- **Objetivo**: Carregar a tabela de referência territorial que mapeia o nome do município para o código IBGE (`id`).
- **Por que**: Sem essa CTE, não há como ligar o nome textual do município (que vem na tabela de origem) ao `id_ibge` numérico que a tabela de coordenadas usa. É a "ponte" entre texto e código.
- **Armadilha comum**: Assumir que o campo `municipio` na `filtro_territorio` contém apenas o nome da cidade. Na verdade, ele armazena no formato `"Município - UF"` (com espaços e hífen). Se você tentar fazer join direto pelo nome da cidade, nenhum registro vai casar.

### CTE 2: `coordenadas`

- **Objetivo**: Extrair uma coordenada única por município a partir da `pnp_painel_instituicao`, já corrigindo o separador decimal.
- **Por que**: A tabela `pnp_painel_instituicao` pode ter várias instituições no mesmo município. Sem deduplicação, o join posterior geraria um produto cartesiano -- cada registro da sua tabela apareceria multiplicado por N instituições daquele município.
- **Armadilha comum**: Esquecer o `REPLACE(latitude, ',', '.')`. Os campos de coordenada na PNP usam vírgula como separador decimal (padrão brasileiro). O Looker e o BigQuery esperam ponto. Sem o `REPLACE`, o campo `coordenada` fica com duas vírgulas (ex: `-19,87,-43,96`) e o mapa não renderiza.

### CTE 3: `dados_de_origem`

- **Objetivo**: Selecionar e tratar os dados da sua tabela de origem, corrigindo grafias de município conhecidamente divergentes.
- **Por que**: Algumas cidades têm nomes diferentes entre fontes (ex: "Cidade de Goiás" vs. "Goiás", "Comborié" vs. "Camboriú"). Sem esse `CASE`, o join com `filtro_territorio` falha silenciosamente para esses municípios -- eles ficam sem coordenada e você não percebe.
- **Armadilha comum**: Não aplicar `TRIM` na UF. Algumas tabelas de origem trazem espaços antes ou depois da sigla ("SP " ou " SP"). Sem `TRIM`, a concatenação `"Município - UF"` não casa com a `filtro_territorio`.

### CTE 4: `dados_com_id`

- **Objetivo**: Fazer o join entre os dados de origem e a tabela de território para obter o `id` IBGE de cada município.
- **Por que**: O `id` IBGE é a chave que conecta município e coordenada. Sem ele, não há como chegar na latitude/longitude.
- **Armadilha comum**: Usar `INNER JOIN` em vez de `LEFT JOIN`. Com `INNER JOIN`, qualquer município que não esteja na `filtro_territorio` (grafia diferente, município novo, erro de digitação) desaparece dos resultados. Use sempre `LEFT JOIN` e depois valide quantos registros ficaram com `id` NULL -- isso revela problemas de casamento.

### CTE 5: `dados_com_coordenadas`

- **Objetivo**: Unir os dados já identificados com as coordenadas, produzindo o resultado final com latitude, longitude e o campo concatenado.
- **Por que**: Esta é a etapa final que entrega os campos que o Looker Maps precisa. Sem ela, você tem o `id` IBGE mas ainda não tem lat/long.
- **Armadilha comum**: Assumir que todo município terá coordenada. A `pnp_painel_instituicao` não cobre 100% dos municípios brasileiros. Registros sem coordenada terão `latitude`, `longitude` e `coordenada` como NULL. Trate isso no dashboard (filtre NULLs no mapa, mas mantenha-os em tabelas e totalizadores).

---

### Código completo

```sql
-- =============================================================================
-- TEMPLATE: Integração de Coordenadas via PNP
-- Substitua os placeholders <<...>> pelos valores do seu caso
-- =============================================================================

WITH
  -- Referência territorial (resolve nome município → id IBGE)
  territorio AS (
    SELECT id, municipio, estado, titulo
    FROM `br-mec-segape-dev.projeto_painel_ministro.filtro_territorio`
  ),

  -- Coordenadas: 1 por município, decimal corrigido (vírgula → ponto)
  coordenadas AS (
    SELECT
      CAST(id_ibge AS STRING) AS id_ibge_str,
      REPLACE(latitude, ',', '.') AS latitude,
      REPLACE(longitude, ',', '.') AS longitude,
      CONCAT(REPLACE(latitude, ',', '.'), ',', REPLACE(longitude, ',', '.')) AS coordenada
    FROM
      `educacao_politica_pnp_painel.pnp_painel_instituicao`
    WHERE
      latitude IS NOT NULL
      AND longitude IS NOT NULL
      AND TRIM(latitude) != ''
      AND TRIM(longitude) != ''
      AND id_ibge IS NOT NULL
    QUALIFY
      ROW_NUMBER() OVER (PARTITION BY CAST(id_ibge AS STRING) ORDER BY unidade) = 1
  ),

  -- Dados de origem com tratamento de município
  dados_de_origem AS (
    SELECT
      -- Correções de grafia conhecidas
      CASE
        WHEN <<CAMPO_MUNICIPIO>> = 'Cidade de Goiás' THEN 'Goiás'
        WHEN <<CAMPO_MUNICIPIO>> LIKE 'Combori%' THEN 'Camboriú'
        WHEN <<CAMPO_MUNICIPIO>> = 'Santo Antônio de Leverger' THEN 'Santo Antônio do Leverger'
        ELSE <<CAMPO_MUNICIPIO>>
      END AS no_municipio,
      TRIM(<<CAMPO_UF>>) AS uf,

      -- Classificação de região (opcional)
      CASE
        WHEN TRIM(<<CAMPO_UF>>) IN ('AC', 'AP', 'AM', 'PA', 'RO', 'RR', 'TO') THEN 'Norte'
        WHEN TRIM(<<CAMPO_UF>>) IN ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'Nordeste'
        WHEN TRIM(<<CAMPO_UF>>) IN ('DF', 'GO', 'MT', 'MS') THEN 'Centro-Oeste'
        WHEN TRIM(<<CAMPO_UF>>) IN ('ES', 'MG', 'RJ', 'SP') THEN 'Sudeste'
        WHEN TRIM(<<CAMPO_UF>>) IN ('PR', 'RS', 'SC') THEN 'Sul'
        ELSE 'Indefinido'
      END AS regiao,

      -- Demais campos da sua tabela
      <<DEMAIS_CAMPOS>>
    FROM
      `<<PROJETO>>.<<DATASET>>.<<TABELA_ORIGEM>>`
  ),

  -- JOIN com território para obter id IBGE
  dados_com_id AS (
    SELECT
      t.id,
      d.*
    FROM dados_de_origem d
    LEFT JOIN territorio t
      ON TRIM(CONCAT(d.no_municipio, ' - ', d.uf)) = TRIM(t.municipio)
  ),

  -- JOIN com coordenadas
  dados_com_coordenadas AS (
    SELECT
      d.*,
      c.latitude,
      c.longitude,
      c.coordenada
    FROM dados_com_id d
    LEFT JOIN coordenadas c
      ON d.id = c.id_ibge_str
  )

SELECT * FROM dados_com_coordenadas;
```

---

## Placeholders

| Placeholder | Descrição | Exemplo |
|-------------|-----------|---------|
| `<<CAMPO_MUNICIPIO>>` | Nome do campo de município na origem | `municipio` |
| `<<CAMPO_UF>>` | Nome do campo de UF na origem | `sigla_uf` |
| `<<DEMAIS_CAMPOS>>` | Lista dos outros campos que você precisa | `instituicao, campus, turmas` |
| `<<PROJETO>>` | Projeto GCP | `br-mec-segape-dev` |
| `<<DATASET>>` | Dataset | `raw_csv_secadi` |
| `<<TABELA_ORIGEM>>` | Tabela de origem | `stg_secadi_partiu_if` |

## Saída

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `latitude` | STRING | Latitude com ponto decimal (ex: `-19.87177955`) |
| `longitude` | STRING | Longitude com ponto decimal (ex: `-43.96312543`) |
| `coordenada` | STRING | Formato `lat,long` para Looker Maps (ex: `-19.87177955,-43.96312543`) |

---

## Erros comuns

### 1. Esquecer o REPLACE do separador decimal

**Sintoma**: O mapa do Looker não exibe nenhum ponto, ou os pontos aparecem em localizações absurdas (oceano, outro continente).

**Causa**: A `pnp_painel_instituicao` armazena coordenadas com vírgula como separador decimal (padrão brasileiro). Sem o `REPLACE(latitude, ',', '.')`, o valor `-19,87177955` é interpretado como texto inválido ou é truncado em `-19`.

**Correção**: Sempre aplicar `REPLACE(campo, ',', '.')` em latitude e longitude antes de qualquer uso. Confira a CTE `coordenadas` no template acima.

### 2. Não fazer QUALIFY para deduplicação

**Sintoma**: A query retorna muito mais linhas do que a tabela de origem. Um município que deveria ter 1 registro aparece com 5, 10 ou mais.

**Causa**: A `pnp_painel_instituicao` tem múltiplas instituições por município. Sem o `QUALIFY ROW_NUMBER() OVER (PARTITION BY ... ) = 1`, o join gera um produto cartesiano -- cada registro da origem é multiplicado pela quantidade de instituições daquele município.

**Correção**: Manter o `QUALIFY` na CTE `coordenadas`. Se precisar de coordenadas por instituição (e não por município), ajuste o `PARTITION BY` para incluir a chave da instituição.

### 3. Usar INNER JOIN em vez de LEFT JOIN

**Sintoma**: A query retorna menos linhas do que a tabela de origem. Registros "sumiram" sem explicação aparente.

**Causa**: Com `INNER JOIN`, qualquer registro cujo município não case com a `filtro_territorio` (ou que não tenha coordenada na PNP) é silenciosamente descartado. Você perde dados sem perceber.

**Correção**: Usar `LEFT JOIN` em ambos os joins (CTEs `dados_com_id` e `dados_com_coordenadas`). Depois, validar quantos registros ficaram com `id` NULL ou `latitude` NULL para entender a cobertura. Para padrões de código SQL do projeto, consulte [[04-padroes-codigo]].

---

## Notas importantes

1. **Decimal**: A `pnp_painel_instituicao` usa vírgula como separador decimal. O `REPLACE` corrige para ponto.
2. **Deduplicação**: `ROW_NUMBER()` garante 1 coordenada por município (evita produto cartesiano).
3. **LEFT JOIN**: Registros sem coordenada são mantidos com NULL.
4. **Tipo no Looker**: O campo `coordenada` deve ser **Texto (ABC)**, não Geo.

Para entender como este modelo se encaixa na arquitetura geral do projeto dbt, consulte [[02-arquitetura-projeto]]. Se precisar de filtros territoriais além das coordenadas, veja [[Guia_02_expansao_filtro_territorio]] ou [[Guia_03_expansao_municipio_ibge]].

---

## Navegação

| Documento | Descrição |
|-----------|-----------|
| [Guia 02 - Expansão com filtro_territorio](Guia_02_expansao_filtro_territorio.md) | Triplicação territorial para Looker |
| [Guia 03 - Expansão com município IBGE](Guia_03_expansao_municipio_ibge.md) | Triplicação territorial com centroide |
| [02 - Arquitetura do Projeto](../02-arquitetura-projeto.md) | Estrutura do projeto dbt |

[Voltar ao índice](../onboarding.md)
