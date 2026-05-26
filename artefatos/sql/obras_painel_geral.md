### Notas de implementação

1. **`CREATE OR REPLACE TABLE`**: Cria ou substitui a tabela `painel_obras_geral`.

2. **`territorio` e Filtro de Nulos**: Mantemos nosso mapa territorial e o filtro inicial que tira os registros sem nome ou código

3. **`obra_id_map` Esta CTE cria a tabela de mapeamento.

    - Ela primeiro seleciona apenas os `nome_obra` e `sigla_unidade` distintos.

    -  `DENSE_RANK()` **sem partição**, ordenando pela `sigla_unidade` e depois pelo `nome_obra`. (IFSP 1, 2, 3... UNILA 4... Unifesp 5, 6, 7...).

4. **`obra_tratada`**: Esta CTE bruta e faz um `JOIN`  (`obra_id_map`) para atribuir a cada linha o `id_variacao_obra` correto e definitivo.

5. **CTEs Territoriais e `SELECT` Final**: A estrutura de união e o `JOIN` com o `territorio`

```sql
-- #1
CREATE OR REPLACE TABLE `br-mec-segape-dev.projeto_painel_ministro.painel_obras_geral` AS
-- #2
WITH
  territorio AS (
  SELECT
    *
  FROM
    `br-mec-segape-dev.projeto_painel_ministro`.`filtro_territorio`
  ),
  -- #3
  obra_id_map AS (
    SELECT
      nome_obra,
      DENSE_RANK() OVER(ORDER BY sigla_unidade, nome_obra) as id_variacao_obra
    FROM (
      SELECT DISTINCT sigla_unidade, nome_obra
      FROM `br-mec-segape-dev.projeto_painel_ministro.raw_obras_geral`
      WHERE nome_obra IS NOT NULL AND ibge_cod IS NOT NULL
    )
  ),
  -- #4
  obra_tratada AS (
  SELECT
    raw.id_obra,
    raw.uf,
    raw.ibge_cod,
    raw.municipio,
    raw.secretaria,
    raw.sigla_unidade,
    raw.nome_obra,
    raw.situacao,
    raw.fonte_recurso,
    SAFE.PARSE_DATE('%d/%m/%Y', raw.inicio) AS inicio,
    SAFE_CAST(raw.previsao_conclusao AS DATE) AS previsao_conclusao,
    SAFE_CAST(raw.valor_estimado_total AS NUMERIC) AS valor_estimado_total,
    SAFE_CAST(raw.valor_total_da_obra AS NUMERIC) AS valor_total_da_obra,
    SAFE_CAST(raw.valor_recurso AS NUMERIC) AS valor_recurso,
    SAFE_CAST(raw.data_recurso AS DATE) AS data_recurso,
    SAFE.PARSE_DATE('%Y-%m-%d', raw.mes_referencia) AS mes_referencia,
    SAFE_CAST(raw.valor_previsto_nesse_mes AS NUMERIC) AS valor_previsto_nesse_mes,
    SAFE_CAST(raw.valor_pago_neste_mes_total AS NUMERIC) AS valor_pago_neste_mes_total,
    map.id_variacao_obra
  FROM
    `br-mec-segape-dev.projeto_painel_ministro.raw_obras_geral` AS raw
  JOIN
    obra_id_map AS map ON raw.nome_obra = map.nome_obra
  WHERE
    raw.nome_obra IS NOT NULL AND raw.ibge_cod IS NOT NULL
  ),
  obra_municipio AS (
  SELECT
    ibge_cod AS id,
    *
  FROM
    obra_tratada
  ),
  obra_estado AS (
  SELECT
    SUBSTR(ibge_cod, 1, 2) AS id,
    *
  FROM
    obra_tratada
  ),
  obra_pais AS (
  SELECT
    '99' AS id,
    *
  FROM
    obra_tratada
  ),
  obra_combinado AS (
  SELECT * FROM obra_municipio
  UNION ALL
  SELECT * FROM obra_estado
  UNION ALL
  SELECT * FROM obra_pais
  )
-- #5
SELECT
  ter.*,
  oc.* EXCEPT (id, ibge_cod, uf, municipio),
  CONCAT(oc.municipio, ' - ', oc.uf) AS municipio_obra
FROM
  territorio ter
LEFT JOIN
  obra_combinado oc
ON
  ter.id = oc.id;



```
