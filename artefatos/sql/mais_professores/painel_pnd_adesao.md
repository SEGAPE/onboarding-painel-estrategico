## painel_pnd_adesao


```sql
CREATE OR REPLACE TABLE projeto_painel_ministro.painel_pnd_adesao CLUSTER BY estado, municipio AS
WITH
  territorio AS (
    SELECT
      *
    FROM
      `br-mec-segape-dev`.`projeto_painel_ministro`.`filtro_territorio`
    CROSS JOIN (
      SELECT
        DISTINCT dt_ref AS ano
      FROM
        projeto_gaia.gaia_cnca
    )
  ),
  municipio AS (
    SELECT
      *
    FROM
      `br-mec-segape-dev`.`educacao_dados_mestres`.`municipio`
  ),
  pnd_adesao AS (
    SELECT
      *
    FROM
      educacao_politica_simec.simec_adesao_pnd_resposta
    WHERE
      submissao IS TRUE
  ),
  pnd_estimativa AS (
    SELECT
      codigo_acesso,
      estimativa_vaga,
      CASE
        estimativa_vaga
        WHEN 'Até 100 professores' THEN 'AO01'
        WHEN 'Mais de 100 professores' THEN 'AO02'
        WHEN 'Mais de 500 professores' THEN 'AO03'
        WHEN 'Mais de 1000 professores' THEN 'AO04'
        WHEN 'Mais de 5000 professores' THEN 'AO05'
        WHEN 'Ainda não tenho estimativa' THEN 'AO06'
      END AS cod_estimativa
    FROM
      `br-mec-segape-dev.educacao_politica_simec.simec_estimativa_vaga_resposta`
    WHERE
      submissao = TRUE
  ),
  pnd_municipio AS (
    SELECT DISTINCT
      codigo_acesso AS cod_ibge,
      estimativa_vaga,
      cod_estimativa,
      submissao
    FROM
      pnd_adesao
      LEFT JOIN pnd_estimativa USING (codigo_acesso)
    WHERE
      LENGTH(codigo_acesso) > 2
  ),
  pnd_estado AS (
    SELECT DISTINCT
      codigo_acesso AS sigla_uf,
      estimativa_vaga,
      cod_estimativa,
      submissao
    FROM
      pnd_adesao
      LEFT JOIN pnd_estimativa USING (codigo_acesso)
    WHERE
      LENGTH(codigo_acesso) = 2
  ),
  politica AS (
    SELECT DISTINCT
      COALESCE(p.cod_ibge, m.id_municipio) cod_ibge,
      m.sigla_uf,
      CONCAT(m.nome, ' - ', m.sigla_uf) AS nome,
      estimativa_vaga,
      cod_estimativa,
      submissao,
      TRUE AS indicador_municipio,
      FALSE AS indicador_uf
    FROM
      municipio AS m
      LEFT JOIN pnd_municipio p ON p.cod_ibge = m.id_municipio
    UNION ALL
    SELECT DISTINCT
      m.id_uf AS cod_ibge,
      m.sigla_uf,
      COALESCE(p.sigla_uf, m.sigla_uf) sigla_uf,
      estimativa_vaga,
      cod_estimativa,
      submissao,
      FALSE AS indicador_municipio,
      TRUE AS indicador_uf
    FROM
      municipio AS m
      LEFT JOIN pnd_estado p ON p.sigla_uf = m.sigla_uf
  ),
  politica_municipio AS (
    SELECT
      cod_ibge AS id,
      sigla_uf,
      cod_ibge,
      nome,
      estimativa_vaga,
      cod_estimativa,
      submissao,
      indicador_municipio,
      indicador_uf
    FROM
      politica
    WHERE
      CAST(cod_ibge AS INT64) > 99
  ),
  politica_estado AS (
    SELECT
      SUBSTR(cod_ibge, 1, 2) AS id,
      sigla_uf,
      cod_ibge,
      nome,
      estimativa_vaga,
      cod_estimativa,
      submissao,
      indicador_municipio,
      indicador_uf
    FROM
      politica
  ),
  politica_pais AS (
    SELECT
      "99" AS id,
      sigla_uf,
      cod_ibge,
      nome,
      estimativa_vaga,
      cod_estimativa,
      submissao,
      indicador_municipio,
      indicador_uf
    FROM
      politica
  ),
  politica_combinado AS (
    SELECT
      *
    FROM
      politica_municipio
    UNION ALL
    SELECT
      *
    FROM
      politica_estado
    UNION ALL
    SELECT
      *
    FROM
      politica_pais
  )
SELECT DISTINCT
  t.id,
  t.estado,
  t.municipio,
  pc.sigla_uf,
  pc.cod_ibge,
  pc.nome,
  CASE
    WHEN pc.submissao IS TRUE AND pc.estimativa_vaga IS NULL THEN 'Sem resposta'
    WHEN pc.estimativa_vaga = 'Ainda não tenho estimativa' THEN 'Ainda sem estimativa'
    ELSE pc.estimativa_vaga
  END AS estimativa_vaga,
  CASE
    WHEN pc.submissao IS TRUE AND pc.cod_estimativa IS NULL THEN 'AO99'
    ELSE pc.cod_estimativa
  END AS id_estimativa,
  pc.submissao,
  pc.indicador_municipio,
  pc.indicador_uf
FROM
  territorio t
  LEFT JOIN politica_combinado pc USING (id);
```
