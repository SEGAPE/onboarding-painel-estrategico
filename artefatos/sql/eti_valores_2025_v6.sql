CREATE OR REPLACE TABLE `br-mec-segape-dev.andre_teste.eti_valores_2025_csv` AS
WITH
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

  base_limpa AS (
    SELECT
      TRIM(codigo_ibge) AS codigo_ibge,
      TRIM(uf) AS uf,
      TRIM(ente) AS ente,
      TRIM(rede) AS rede,
      TRIM(registrou_politica_tempo_integral) AS registrou_politica,
      SAFE_CAST(
        REPLACE(REPLACE(REPLACE(REPLACE(TRIM(valor_total_fomento), 'R$', ''), ' ', ''), '.', ''), ',', '.')
      AS FLOAT64) AS valor_total_fomento,
      SAFE_CAST(
        REPLACE(REPLACE(REPLACE(TRIM(quantidade_matriculas), '.', ''), ' ', ''), ',', '.')
      AS INT64) AS quantidade_matriculas,
      SAFE_CAST(
        REPLACE(REPLACE(REPLACE(REPLACE(TRIM(valor_repasse_out_2025), 'R$', ''), ' ', ''), '.', ''), ',', '.')
      AS FLOAT64) AS valor_repasse_out_2025,
      SAFE_CAST(
        REPLACE(REPLACE(REPLACE(REPLACE(TRIM(valor_repasse_nov_2025), 'R$', ''), ' ', ''), '.', ''), ',', '.')
      AS FLOAT64) AS valor_repasse_nov_2025,
      SAFE_CAST(
        REPLACE(REPLACE(REPLACE(REPLACE(TRIM(valor_repasse_dez_2025_retificado), 'R$', ''), ' ', ''), '.', ''), ',', '.')
      AS FLOAT64) AS valor_repasse_dez_2025_retificado,
      SAFE_CAST(
        REPLACE(REPLACE(REPLACE(REPLACE(TRIM(valor_repasse_jan_2026_retificado), 'R$', ''), ' ', ''), '.', ''), ',', '.')
      AS FLOAT64) AS valor_repasse_jan_2026_retificado
    FROM `br-mec-segape-dev.andre_teste.eti-2`
    WHERE TRIM(COALESCE(codigo_ibge, '')) != ''
  ),

  registros_repasse AS (
    SELECT
      codigo_ibge, uf, ente, rede, registrou_politica,
      IF(r.ordem = 1, valor_total_fomento, NULL) AS valor_total_fomento,
      IF(r.ordem = 1, quantidade_matriculas, NULL) AS quantidade_matriculas,
      'repasse' AS tipo_registro,
      CAST(LEFT(r.ano_mes_str, 4) AS INT64) AS ano,
      PARSE_DATE('%Y-%m', r.ano_mes_str) AS ano_mes,
      r.valor_repasse
    FROM base_limpa,
    UNNEST([
      STRUCT(1 AS ordem, '2025-10' AS ano_mes_str, valor_repasse_out_2025 AS valor_repasse),
      STRUCT(2, '2025-11', valor_repasse_nov_2025),
      STRUCT(3, '2025-12', valor_repasse_dez_2025_retificado),
      STRUCT(4, '2026-01', valor_repasse_jan_2026_retificado)
    ]) AS r
  ),

  dados_municipais AS (
    SELECT
      m.id_municipio AS id,
      m.id_uf,
      m.nome_uf,
      m.nome_regiao AS regiao,
      m.latitude,
      m.longitude,
      m.coordenada,
      d.*
    FROM registros_repasse d
    JOIN municipios_ibge m
      ON TRIM(d.codigo_ibge) = TRIM(m.id_municipio)
    WHERE LENGTH(TRIM(d.codigo_ibge)) = 7
  ),

  dados_estaduais AS (
    SELECT
      c.id_uf AS id,
      c.id_uf,
      c.nome_uf,
      c.nome_regiao AS regiao,
      c.latitude,
      c.longitude,
      c.coordenada,
      d.*
    FROM registros_repasse d
    JOIN capitais c
      ON TRIM(d.codigo_ibge) = TRIM(c.id_uf)
    WHERE LENGTH(TRIM(d.codigo_ibge)) = 2
  ),

  dados_com_id AS (
    SELECT * FROM dados_municipais
    UNION ALL
    SELECT * FROM dados_estaduais
  ),

  -- =========================================================================
  -- EXPANSÃO TERRITORIAL (triplicação)
  --
  -- estado / municipio         = para FILTROS ("Todos" nos níveis agregados)
  -- estado_nome / municipio_nome = para EXIBIÇÃO (sempre nome real da linha)
  --
  -- Exemplo:
  --   nivel_municipio: estado=Goiás, municipio=Goiânia,   estado_nome=Goiás, municipio_nome=Goiânia
  --   nivel_estado:    estado=Goiás, municipio=Todos,      estado_nome=Goiás, municipio_nome=Goiânia
  --   nivel_pais:      estado=Todos, municipio=Todos,      estado_nome=Goiás, municipio_nome=Goiânia
  -- =========================================================================

  nivel_municipio AS (
    SELECT
      id,
      id_uf,
      nome_uf,
      regiao,
      latitude,
      longitude,
      coordenada,
      'municipio' AS nivel_territorial,
      CONCAT(ente, ' - ', uf) AS nome_territorio,
      -- Filtros
      nome_uf AS estado,
      ente AS municipio,
      -- Exibição (nome real)
      nome_uf AS estado_nome,
      ente AS municipio_nome,
      CONCAT(ente, ' - ', uf) AS titulo,
      uf,
      rede,
      registrou_politica,
      tipo_registro,
      ano,
      ano_mes,
      valor_repasse,
      valor_total_fomento,
      quantidade_matriculas AS matriculas_fundeb
    FROM dados_com_id
  ),

  nivel_estado AS (
    SELECT
      id_uf AS id,
      id_uf,
      nome_uf,
      regiao,
      latitude,
      longitude,
      coordenada,
      'estado' AS nivel_territorial,
      'Todos' AS nome_territorio,
      -- Filtros
      nome_uf AS estado,
      'Todos' AS municipio,
      -- Exibição (nome real)
      nome_uf AS estado_nome,
      ente AS municipio_nome,
      nome_uf AS titulo,
      uf,
      rede,
      registrou_politica,
      tipo_registro,
      ano,
      ano_mes,
      valor_repasse,
      valor_total_fomento,
      quantidade_matriculas AS matriculas_fundeb
    FROM dados_com_id
  ),

  nivel_pais AS (
    SELECT
      '99' AS id,
      '99' AS id_uf,
      'Brasil' AS nome_uf,
      'Brasil' AS regiao,
      latitude,
      longitude,
      coordenada,
      'pais' AS nivel_territorial,
      'Todos' AS nome_territorio,
      -- Filtros
      'Todos' AS estado,
      'Todos' AS municipio,
      -- Exibição (nome real da linha original)
      nome_uf AS estado_nome,
      ente AS municipio_nome,
      'Brasil' AS titulo,
      'BR' AS uf,
      rede,
      registrou_politica,
      tipo_registro,
      ano,
      ano_mes,
      valor_repasse,
      valor_total_fomento,
      quantidade_matriculas AS matriculas_fundeb
    FROM dados_com_id
  )

SELECT * FROM nivel_municipio
UNION ALL
SELECT * FROM nivel_estado
UNION ALL
SELECT * FROM nivel_pais;
