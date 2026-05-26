```php

CREATE OR REPLACE TABLE br-mec-segape-dev.andre_teste.partiu_if_valores

(

    elementos STRING,

    regra_calculo_pessoal STRING,

    qtd_pessoal INT64,

    meses_por_ano INT64,

    valor_unitario FLOAT64,

    investimento_anual FLOAT64

) AS

SELECT * FROM UNNEST([

    STRUCT(

        'Coordenador de Gestão' AS elementos,

        '1 por Instituição Executora' AS regra_calculo_pessoal,

        41 AS qtd_pessoal,

        12 AS meses_por_ano,

        1430.00 AS valor_unitario,

        703560.00 AS investimento_anual

    ),

    STRUCT('Coordenador Pedagógico', '1 por Instituição Ofertante', 650, 12, 1430.00, 11154000.00),

    STRUCT('Psicólogo / Pedagogo / Assistente Social', '1 por Instituição Ofertante', 650, 8, 1430.00, 7436000.00),

    STRUCT('Professores', '3 por Instituição Ofertante', 1950, 12, 1430.00, 33462000.00),

    STRUCT('Monitores', '3 por Instituição Ofertante', 1950, 8, 700.00, 10920000.00),

    STRUCT('Bolsistas', '40 por Instituição Ofertante', 26000, 8, 200.00, 41600000.00),

    STRUCT('Taxas administrativas (10%)', '-', NULL, NULL, NULL, 10527556.00);
```


---


```sql
CREATE OR REPLACE TABLE `br-mec-segape-dev.andre_teste.partiu_if_oferta` AS
WITH
  territorio AS (
    SELECT
      id,
      municipio,
      estado,
      titulo
    FROM
      `br-mec-segape-dev.projeto_painel_ministro.filtro_territorio`
  ),
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
      ROW_NUMBER() OVER (
        PARTITION BY CAST(id_ibge AS STRING)
        ORDER BY unidade
      ) = 1
  ),

  dados_de_origem AS (
    SELECT
      CASE
        WHEN municipio = 'Cidade de Goiás' THEN 'Goiás'
        WHEN municipio LIKE 'Combori%' THEN 'Camboriú'
        WHEN municipio = 'Santo Antônio de Leverger' THEN 'Santo Antônio do Leverger'
        ELSE municipio
      END AS no_municipio,
      TRIM(sigla_uf) AS uf,
      CASE
        WHEN TRIM(sigla_uf) IN ('AC', 'AP', 'AM', 'PA', 'RO', 'RR', 'TO') THEN 'Norte'
        WHEN TRIM(sigla_uf) IN ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'Nordeste'
        WHEN TRIM(sigla_uf) IN ('DF', 'GO', 'MT', 'MS') THEN 'Centro-Oeste'
        WHEN TRIM(sigla_uf) IN ('ES', 'MG', 'RJ', 'SP') THEN 'Sudeste'
        WHEN TRIM(sigla_uf) IN ('PR', 'RS', 'SC') THEN 'Sul'
        ELSE 'Indefinido'
      END AS regiao,
      instituicao,
      campus,
      turmas,
      total_matriculas
    FROM
      `br-mec-segape-dev.raw_csv_secadi.stg_secadi_partiu_if`
  ),
  dados_com_id AS (
    SELECT
      t.id,
      pr.*
    FROM
      dados_de_origem AS pr
    LEFT JOIN
      territorio AS t
    ON
      TRIM(CONCAT(pr.no_municipio, ' - ', pr.uf)) = TRIM(t.municipio)
  ),
  dados_com_coordenadas AS (
    SELECT
      d.*,
      c.latitude,
      c.longitude,
      c.coordenada
    FROM
      dados_com_id AS d
    LEFT JOIN
      coordenadas AS c
    ON
      d.id = c.id_ibge_str
  ),

  agregado_municipio AS (
    SELECT
      id,
      no_municipio, uf, regiao, instituicao, campus,
      turmas, total_matriculas,
      latitude, longitude, coordenada
    FROM dados_com_coordenadas
    WHERE id IS NOT NULL AND LENGTH(id) = 7
  ),
  agregado_estado AS (
    SELECT
      SUBSTR(id, 1, 2) AS id,
      no_municipio, uf, regiao, instituicao, campus,
      turmas, total_matriculas,
      latitude, longitude, coordenada
    FROM dados_com_coordenadas
    WHERE id IS NOT NULL AND LENGTH(id) = 7
  ),
  agregado_pais AS (
    SELECT
      '99' AS id,
      no_municipio, uf, regiao, instituicao, campus,
      turmas, total_matriculas,
      latitude, longitude, coordenada
    FROM dados_com_coordenadas
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
  ter.id,
  ter.municipio AS nome_territorio,
  ter.estado,
  ter.titulo,
  pc.no_municipio,
  pc.uf,
  pc.regiao,
  pc.instituicao,
  pc.campus,
  pc.turmas,
  pc.total_matriculas,
  pc.latitude,
  pc.longitude,
  pc.coordenada
FROM
  territorio AS ter
RIGHT JOIN
  dados_combinados AS pc
USING
  (id);


```sql
CREATE OR REPLACE TABLE `br-mec-segape-dev.andre_teste.partiu_if_questionario` AS
WITH
  territorio_norm AS (
    SELECT
      id,
      municipio,
      UPPER(TRIM(NORMALIZE(SPLIT(municipio, ' - ')[SAFE_OFFSET(0)], NFD))) AS join_cidade_limpa,
      SPLIT(municipio, ' - ')[SAFE_OFFSET(1)] AS join_uf,
      titulo,
      estado
    FROM `br-mec-segape-dev.projeto_painel_ministro.filtro_territorio`
  ),
  dados_origem AS (
    SELECT
      id AS id_resposta,
      id_pessoa,
      cpf,
      CAST(data_hora_inicio AS DATE) AS data_referencia,
      UPPER(TRIM(NORMALIZE(municipio_residencia, NFD))) AS cidade_join,
      INITCAP(TRIM(municipio_residencia)) AS no_municipio_display,
      CASE
        WHEN UPPER(TRIM(estado_residencia)) IN ('ACRE', 'AC') THEN 'AC'
        WHEN UPPER(TRIM(estado_residencia)) IN ('ALAGOAS', 'AL') THEN 'AL'
        WHEN UPPER(TRIM(estado_residencia)) IN ('AMAPÁ', 'AMAPA', 'AP') THEN 'AP'
        WHEN UPPER(TRIM(estado_residencia)) IN ('AMAZONAS', 'AM') THEN 'AM'
        WHEN UPPER(TRIM(estado_residencia)) IN ('BAHIA', 'BA') THEN 'BA'
        WHEN UPPER(TRIM(estado_residencia)) IN ('CEARÁ', 'CEARA', 'CE') THEN 'CE'
        WHEN UPPER(TRIM(estado_residencia)) IN ('DISTRITO FEDERAL', 'DF') THEN 'DF'
        WHEN UPPER(TRIM(estado_residencia)) IN ('ESPÍRITO SANTO', 'ESPIRITO SANTO', 'ES') THEN 'ES'
        WHEN UPPER(TRIM(estado_residencia)) IN ('GOIÁS', 'GOIAS', 'GO') THEN 'GO'
        WHEN UPPER(TRIM(estado_residencia)) IN ('MARANHÃO', 'MARANHAO', 'MA') THEN 'MA'
        WHEN UPPER(TRIM(estado_residencia)) IN ('MATO GROSSO', 'MT') THEN 'MT'
        WHEN UPPER(TRIM(estado_residencia)) IN ('MATO GROSSO DO SUL', 'MS') THEN 'MS'
        WHEN UPPER(TRIM(estado_residencia)) IN ('MINAS GERAIS', 'MG') THEN 'MG'
        WHEN UPPER(TRIM(estado_residencia)) IN ('PARÁ', 'PARA', 'PA') THEN 'PA'
        WHEN UPPER(TRIM(estado_residencia)) IN ('PARAÍBA', 'PARAIBA', 'PB') THEN 'PB'
        WHEN UPPER(TRIM(estado_residencia)) IN ('PARANÁ', 'PARANA', 'PR') THEN 'PR'
        WHEN UPPER(TRIM(estado_residencia)) IN ('PERNAMBUCO', 'PE') THEN 'PE'
        WHEN UPPER(TRIM(estado_residencia)) IN ('PIAUÍ', 'PIAUI', 'PI') THEN 'PI'
        WHEN UPPER(TRIM(estado_residencia)) IN ('RIO DE JANEIRO', 'RJ') THEN 'RJ'
        WHEN UPPER(TRIM(estado_residencia)) IN ('RIO GRANDE DO NORTE', 'RN') THEN 'RN'
        WHEN UPPER(TRIM(estado_residencia)) IN ('RIO GRANDE DO SUL', 'RS') THEN 'RS'
        WHEN UPPER(TRIM(estado_residencia)) IN ('RONDÔNIA', 'RONDONIA', 'RO') THEN 'RO'
        WHEN UPPER(TRIM(estado_residencia)) IN ('RORAIMA', 'RR') THEN 'RR'
        WHEN UPPER(TRIM(estado_residencia)) IN ('SANTA CATARINA', 'SC') THEN 'SC'
        WHEN UPPER(TRIM(estado_residencia)) IN ('SÃO PAULO', 'SAO PAULO', 'SP') THEN 'SP'
        WHEN UPPER(TRIM(estado_residencia)) IN ('SERGIPE', 'SE') THEN 'SE'
        WHEN UPPER(TRIM(estado_residencia)) IN ('TOCANTINS', 'TO') THEN 'TO'
        WHEN LENGTH(TRIM(estado_residencia)) = 2 THEN UPPER(TRIM(estado_residencia))
        ELSE NULL
      END AS uf,
      CASE
        WHEN SAFE_CAST(idade AS INT64) BETWEEN 10 AND 90 THEN SAFE_CAST(idade AS INT64)
        ELSE NULL
      END AS idade,
      sexo AS genero,
      cor_raca,
      instituicao_curso AS instituicao,
      turno_curso AS turno,
      COALESCE(
        campus_cefet_mg, campus_cpii, campus_if_baiano, campus_ifc, campus_iffar,
        campus_if_goiano, campus_if_sertao_pe, campus_if_sudeste_mg, campus_ifac,
        campus_ifal, campus_ifam, campus_ifap, campus_ifba, campus_ifce,
        campus_ifes, campus_iff, campus_ifg, campus_ifma, campus_ifmg,
        campus_ifms, campus_ifmt, campus_ifnmg, campus_ifpa, campus_ifpb,
        campus_ifpe, campus_ifpi, campus_ifpr, campus_ifrj, campus_ifrn,
        campus_ifro, campus_ifrr, campus_ifrs, campus_ifs, campus_ifsc,
        campus_ifsp, campus_ifsul, campus_ifsuldeminas, campus_iftm, campus_ifto
      ) AS campus,
      avaliacao_efetividade_aula AS avaliacao_aprendizado,
      1 AS qtd_matricula,
      CAST(NULL AS FLOAT64) AS valor_investimento,
      CAST(NULL AS INT64) AS qtd_profissionais
    FROM `br-mec-segape-dev.raw_csv_secadi.stg_secadi_partiu_if_questionario`
  ),
  dados_com_match AS (
    SELECT
      d.*,
      COALESCE(t1.id, t2.id) AS id_territorio_final,
      CASE
        WHEN COALESCE(t1.join_uf, t2.join_uf, d.uf) IN ('AC', 'AP', 'AM', 'PA', 'RO', 'RR', 'TO') THEN 'Norte'
        WHEN COALESCE(t1.join_uf, t2.join_uf, d.uf) IN ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'Nordeste'
        WHEN COALESCE(t1.join_uf, t2.join_uf, d.uf) IN ('DF', 'GO', 'MT', 'MS') THEN 'Centro-Oeste'
        WHEN COALESCE(t1.join_uf, t2.join_uf, d.uf) IN ('ES', 'MG', 'RJ', 'SP') THEN 'Sudeste'
        WHEN COALESCE(t1.join_uf, t2.join_uf, d.uf) IN ('PR', 'RS', 'SC') THEN 'Sul'
        ELSE 'Indefinido'
      END AS regiao,
      TO_HEX(SHA256(CONCAT(
        IFNULL(instituicao, ''),
        IFNULL(campus, ''),
        IFNULL(turno, '')
      ))) AS id_turma_estimada
    FROM dados_origem d
    LEFT JOIN territorio_norm t1
      ON d.cidade_join = t1.join_cidade_limpa
      AND d.uf = t1.join_uf
    LEFT JOIN territorio_norm t2
      ON d.cidade_join = t2.join_cidade_limpa
      AND t1.id IS NULL
  ),
  expansao AS (
    SELECT
      id_territorio_final AS id,
      p.* EXCEPT(id_territorio_final, cidade_join)
    FROM dados_com_match p
    WHERE id_territorio_final IS NOT NULL

    UNION ALL

    SELECT
      SUBSTR(id_territorio_final, 1, 2) AS id,
      p.* EXCEPT(id_territorio_final, cidade_join)
    FROM dados_com_match p
    WHERE id_territorio_final IS NOT NULL

    UNION ALL

    SELECT
      '99' AS id,
      p.* EXCEPT(id_territorio_final, cidade_join)
    FROM dados_com_match p
  )
SELECT
  t.id,
  t.municipio AS nome_territorio,
  t.estado,
  t.titulo,
  e.* EXCEPT(id)
FROM expansao e
LEFT JOIN `br-mec-segape-dev.projeto_painel_ministro.filtro_territorio` t
  ON e.id = t.id
```
