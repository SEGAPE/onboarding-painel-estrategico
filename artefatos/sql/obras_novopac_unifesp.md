	1. **`CREATE OR REPLACE TABLE`**: Nosso alvo agora é a nova tabela `painel_novopac_unifesp`, que conterá os dados da obra da UNIFESP, prontos para o painel.

2. **`obra` CTE**: agora se conecta à fonte de dados `raw_novopac_obra_prioritaria_unifesp`. As operações de `CAST` foram ajustadas para corresponder exatamente aos campos de valor presentes nesta tabela, que são `valor_estimado_total`, `valor_total_da_obra`, `valor_do_recurso_r`, `valor_previsto_neste_mes_total` e `valor_pago_neste_mes_total`.

3. **CTEs Territoriais (`obra_municipio`, `obra_estado`, `obra_pais`)**: Reutilizamos a mesma lógica. A identidade do município é o `codigo_ibge` completo; a do estado é o código numérico extraído com `SUBSTR(codigo_ibge, 1, 2)`; e a do país é o código `'99'`.

4. **`obra_combinado` e `SELECT` Final**: A união das camadas e o `JOIN` final com a tabela `territorio`
```sql
-- #1
CREATE OR REPLACE TABLE `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_unifesp` AS
WITH
  territorio AS (
  SELECT
    *
  FROM
    `br-mec-segape-dev`.`projeto_painel_ministro`.`filtro_territorio`
  ),
  -- #2
  obra AS (
  SELECT
    data_carga,
    id_obra,
    uf,
    codigo_ibge,
    municipio,
    secretaria,
    sigla_unidade,
    nome_obra,
    situacao,
    inicio,
    previsao_conclusao,
    fonte_do_recurso,
    data_do_recurso,
    mes_referencia,
    letreiro,
    data_captura,
    CAST(valor_estimado_total AS FLOAT64) AS valor_estimado_total,
    CAST(valor_total_da_obra AS FLOAT64) AS valor_total_da_obra,
    CAST(valor_do_recurso_r AS FLOAT64) AS valor_do_recurso_r,
    CAST(valor_previsto_neste_mes_total AS FLOAT64) AS valor_previsto_neste_mes_total,
    CAST(valor_pago_neste_mes_total AS FLOAT64) AS valor_pago_neste_mes_total
  FROM
    `br-mec-segape-dev.educacao_temp.raw_novopac_obra_prioritaria_unifesp`
  ),
  -- #3
  obra_municipio AS (
  SELECT
    codigo_ibge AS id,
    *
  FROM
    obra
  ),
  obra_estado AS (
  SELECT
    SUBSTR(codigo_ibge, 1, 2) AS id,
    *
  FROM
    obra
  ),
  obra_pais AS (
  SELECT
    '99' AS id,
    *
  FROM
    obra
  ),
  -- #4
  obra_combinado AS (
  SELECT * FROM obra_municipio
  UNION ALL
  SELECT * FROM obra_estado
  UNION ALL
  SELECT * FROM obra_pais
  )
SELECT
  ter.*,
  oc.* EXCEPT (id, codigo_ibge, uf, municipio),
  CONCAT(oc.municipio, ' - ', oc.uf) AS municipio_obra
FROM
  territorio ter
LEFT JOIN
  obra_combinado oc
ON
  ter.id = oc.id;
```
