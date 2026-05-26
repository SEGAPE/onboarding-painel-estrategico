1. **`CREATE OR REPLACE TABLE`**: Mantemos o início, o resultado final na tabela `painel_novopac_unila`.

2. **`obra` CTE**: Permanece como nosso filtrador de dados, convertendo os valores para `FLOAT64` diretamente da fonte.

3. **CTEs Territoriais Ajustadas**:

    - `obra_municipio`: Sem alterações, o `id` continua sendo o `codigo_ibge` completo (7 dígitos).

    - `obra_estado`:  `id` é gerado com `SUBSTR(codigo_ibge, 1, 2)`. Isso extrai os dois primeiros dígitos do código do município, que correspondem ao código numérico do estado

    - `obra_pais`:  O `id` foi alterado de `'BR'` para `'99'`, a identidade numérica que seu filtro usa para representar "Brasil".

4. **`obra_combinado` e `SELECT` Final**: A lógica de união e o `JOIN` final permanecem os mesmos, mas agora a conexão será perfeita, pois as chaves (`id`) de ambos os lados da união falam o mesmo idioma.
```sql
-- #1
CREATE OR REPLACE TABLE `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_unila` AS
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
    CAST(valor_estimado_total AS FLOAT64) AS valor_estimado_total,
    CAST(valor_total_da_obra AS FLOAT64) AS valor_total_da_obra,
    fonte_do_recurso,
    CAST(valor_do_recurso_r AS FLOAT64) AS valor_do_recurso_r,
    mes_referencia,
    CAST(valor_previsto_neste_mes_total AS FLOAT64) AS valor_previsto_neste_mes_total,
    CAST(valor_pago_neste_mes_total AS FLOAT64) AS valor_pago_neste_mes_total,
    CAST(valor_previsto_neste_mes_adminstracao_central AS FLOAT64) AS valor_previsto_neste_mes_adminstracao_central,
    CAST(valor_pago_neste_mes_adminstracao_central AS FLOAT64) AS valor_pago_neste_mes_adminstracao_central,
    CAST(valor_previsto_neste_mes_edificio_central AS FLOAT64) AS valor_previsto_neste_mes_edificio_central,
    CAST(valor_pago_neste_mes_edificio_central AS FLOAT64) AS valor_pago_neste_mes_edificio_central,
    CAST(valor_previsto_neste_mes_salas_de_aulas AS FLOAT64) AS valor_previsto_neste_mes_salas_de_aulas,
    CAST(valor_pago_neste_mes_salas_de_aulas AS FLOAT64) AS valor_pago_neste_mes_salas_de_aulas,
    CAST(valor_previsto_neste_mes_restaurante AS FLOAT64) AS valor_previsto_neste_mes_restaurante,
    CAST(valor_pago_neste_mes_restaurante AS FLOAT64) AS valor_pago_neste_mes_restaurante,
    CAST(valor_previsto_neste_mes_central_de_utilidades AS FLOAT64) AS valor_previsto_neste_mes_central_de_utilidades,
    CAST(valor_pago_neste_mes_central_de_utilidades AS FLOAT64) AS valor_pago_neste_mes_central_de_utilidades,
    CAST(valor_previsto_neste_mes_areas_externas AS FLOAT64) AS valor_previsto_neste_mes_areas_externas,
    CAST(valor_pago_neste_mes_areas_externas AS FLOAT64) AS valor_pago_neste_mes_areas_externas,
    letreiro,
    data_captura
  FROM
    `br-mec-segape-dev.educacao_temp.raw_novopac_obra_prioritaria_unila`
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
-- #5
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
