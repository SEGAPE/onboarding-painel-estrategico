



painel_pneerq_bolsista

xxxx

painel_pneerq_infraestrutura_escolar


```sql

-- #1
CREATE OR REPLACE TABLE br-mec-segape-dev.projeto_painel_ministro.painel_pneerq_infraestrutura_escola AS
WITH
  territorio_filtro AS (
    SELECT
      *
    FROM
      `br-mec-segape-dev.projeto_painel_ministro.filtro_territorio`
  ),
  municipio_completo AS (
    SELECT
      *
    FROM
      `br-mec-segape-dev.educacao_dados_mestres.municipio`
  ),
  censo AS (
    SELECT
      ano,
      CAST(id_municipio AS STRING) AS id_municipio,
      id_escola,
      rede,
      tipo_localizacao,
      tipo_localizacao_diferenciada,
      agua_inexistente,
      energia_inexistente,
      esgoto_inexistente,
      internet,
      local_funcionamento_predio_escolar,
      quantidade_matricula_educacao_basica,
      quantidade_docente_educacao_basica,
      quantidade_matricula_branca,
      quantidade_matricula_amarela,
      quantidade_matricula_parda,
      quantidade_matricula_preta,
      quantidade_matricula_indigena,
      quantidade_matricula_nao_declarada,
      quantidade_matricula_infantil,
      quantidade_matricula_fundamental_anos_iniciais,
      quantidade_matricula_fundamental_anos_finais,
      quantidade_matricula_medio,
      CAST(escolarizacao AS STRING) AS escolarizacao,
      cozinha,
      patio_coberto,
      patio_descoberto,
      refeitorio,
      quadra_esportes,
      quadra_esportes_coberta,
      quadra_esportes_descoberta,
      laboratorio_ciencias,
      laboratorio_informatica,
      material_pedagogico_indigena,
      material_pedagogico_etnico,
      material_especifico_quilombola,
      material_especifico_indigena
    FROM
      `educacao_inep_dados_abertos.censo_escolar_escola`
  ),
  politica AS (
    SELECT
      censo.ano AS ano,
      CASE
        WHEN censo.ano = (
          SELECT
            MAX(t.ano)
          FROM
            censo t
        )
        THEN TRUE
        ELSE FALSE
      END AS ultimo_ano,
      censo.id_municipio,
      censo.id_escola,
      IFNULL(INITCAP(escola.nome), "Sem informação") AS nome_escola,
      CASE
        WHEN censo.rede = "1" THEN "Federal"
        WHEN censo.rede = "2" THEN "Estadual"
        WHEN censo.rede = "3" THEN "Municipal"
        WHEN censo.rede = "4" THEN "Privada"
      END AS rede,
      CASE
        WHEN censo.tipo_localizacao = "1" THEN "Urbana"
        WHEN censo.tipo_localizacao = "2" THEN "Rural"
      END AS localizacao,
      censo.tipo_localizacao_diferenciada AS cod_infraestrutura,
      CASE
        WHEN censo.tipo_localizacao_diferenciada = "0" THEN "Convencionais"
        WHEN censo.tipo_localizacao_diferenciada = "1" THEN "Assentamento"
        WHEN censo.tipo_localizacao_diferenciada = "2" THEN "Indígenas"
        WHEN censo.tipo_localizacao_diferenciada = "3" THEN "Quilombolas"
        ELSE "Outros"
      END AS infraestrutura,
      MAX(CASE WHEN agua_inexistente = 0 THEN 1 ELSE 0 END) AS possui_agua,
      MAX(CASE WHEN esgoto_inexistente = 0 THEN 1 ELSE 0 END) AS possui_esgoto,
      MAX(CASE WHEN energia_inexistente = 0 THEN 1 ELSE 0 END) AS possui_energia,
      MAX(CASE WHEN internet = 1 THEN 1 ELSE 0 END) AS possui_internet,
      MAX(CASE WHEN local_funcionamento_predio_escolar = 1 THEN 1 ELSE 0 END) AS possui_predio_escolar,
      MAX(CASE WHEN cozinha = 1 THEN 1 ELSE 0 END) AS possui_cozinha,
      MAX(CASE WHEN refeitorio = 1 THEN 1 ELSE 0 END) AS possui_refeitorio,
      MAX(CASE WHEN patio_coberto = 1 OR patio_descoberto = 1 THEN 1 ELSE 0 END) AS possui_patio,
      MAX(CASE WHEN quadra_esportes = 1 OR quadra_esportes_coberta = 1 OR quadra_esportes_descoberta = 1 THEN 1 ELSE 0 END) AS possui_quadra_esportes,
      MAX(CASE WHEN laboratorio_ciencias = 1 THEN 1 ELSE 0 END) AS possui_laboratorio_ciencias,
      MAX(CASE WHEN laboratorio_informatica = 1 THEN 1 ELSE 0 END) AS possui_laboratorio_informatica,
      MAX(CASE WHEN material_especifico_quilombola = 1 OR material_pedagogico_indigena = 1 OR material_pedagogico_etnico = 1 OR material_especifico_indigena = 1 THEN 1 ELSE 0 END) AS possui_material_pedagogico_etnico_racial,
      CASE
        WHEN censo.tipo_localizacao_diferenciada = "3" THEN 'Quilombolas'
        WHEN (
          SUM(quantidade_matricula_parda) + SUM(quantidade_matricula_preta)
        ) / NULLIF(SUM(quantidade_matricula_educacao_basica), 0) >= 0.6 THEN 'Negros (Pretos ou Pardos ≥60%)'
        ELSE 'Não Negros'
      END AS maioria_racial_60_pct,
      CASE
        WHEN censo.tipo_localizacao_diferenciada = "3" THEN 'Escolas quilombolas'
        WHEN (
          SUM(quantidade_matricula_parda) + SUM(quantidade_matricula_preta)
        ) / NULLIF(SUM(quantidade_matricula_educacao_basica), 0) >= 0.6 THEN 'Escolas predominantemente negras'
        WHEN SUM(quantidade_matricula_branca) / NULLIF(SUM(quantidade_matricula_educacao_basica), 0) >= 0.6 THEN 'Escolas predominantemente brancas'
        ELSE 'Outros'
      END AS predominancia_racial_especifica,
      CASE
        WHEN (
          SUM(quantidade_matricula_parda) + SUM(quantidade_matricula_preta)
        ) / NULLIF(SUM(quantidade_matricula_educacao_basica), 0) >= 0.6 THEN 'Pessoas Negras e Pardas'
        ELSE 'Outros Grupos Raciais'
      END AS grupo_racial_dashboard,
      SUM(quantidade_docente_educacao_basica) AS quantidade_docente_educacao_basica,
      SUM(quantidade_matricula_nao_declarada) AS quantidade_matricula_cor_nao_declarada,
      SUM(quantidade_matricula_branca) AS quantidade_matricula_branca,
      SUM(quantidade_matricula_preta) AS quantidade_matricula_preta,
      SUM(quantidade_matricula_parda) AS quantidade_matricula_parda,
      SUM(quantidade_matricula_amarela) AS quantidade_matricula_amarela,
      SUM(quantidade_matricula_indigena) AS quantidade_matricula_indigena,
      SUM(quantidade_matricula_educacao_basica) AS quantidade_matricula_educacao_basica,
      SUM(quantidade_matricula_infantil) AS quantidade_matricula_infantil,
      SUM(
        quantidade_matricula_fundamental_anos_iniciais
      ) AS quantidade_matricula_fundamental_anos_iniciais,
      SUM(
        quantidade_matricula_fundamental_anos_finais
      ) AS quantidade_matricula_fundamental_anos_finais,
      SUM(quantidade_matricula_medio) AS quantidade_matricula_medio
    FROM
      censo AS censo
      LEFT JOIN `educacao_dados_mestres.escola` AS escola ON CAST(censo.id_escola AS INT64) = CAST(escola.id_escola AS INT64)
    WHERE
      escolarizacao = '1'
    GROUP BY
      censo.ano,
      censo.id_municipio,
      censo.id_escola,
      escola.nome,
      censo.rede,
      censo.tipo_localizacao,
      censo.tipo_localizacao_diferenciada
  )
-- #4
SELECT
  p.ano,
  p.ultimo_ano,
  p.id_escola,
  p.nome_escola,
  p.rede,
  p.localizacao,
  p.cod_infraestrutura,
  p.infraestrutura,
  p.possui_cozinha,
  p.possui_refeitorio,
  p.possui_patio,
  p.possui_quadra_esportes,
  p.possui_laboratorio_ciencias,
  p.possui_laboratorio_informatica,
  p.possui_material_pedagogico_etnico_racial,
  p.maioria_racial_60_pct,
  p.predominancia_racial_especifica,
  p.grupo_racial_dashboard,
  p.quantidade_docente_educacao_basica,
  p.quantidade_matricula_cor_nao_declarada,
  p.quantidade_matricula_branca,
  p.quantidade_matricula_preta,
  p.quantidade_matricula_parda,
  p.quantidade_matricula_amarela,
  p.quantidade_matricula_indigena,
  p.quantidade_matricula_educacao_basica,
  p.quantidade_matricula_infantil,
  p.quantidade_matricula_fundamental_anos_iniciais,
  p.quantidade_matricula_fundamental_anos_finais,
  p.quantidade_matricula_medio,
  p.possui_agua,
  p.possui_esgoto,
  p.possui_energia,
  p.possui_internet,
  p.possui_predio_escolar,
  COALESCE(p.id_municipio, m.id_municipio) AS id_municipio,
  m.id_municipio_6,
  m.id_municipio_tse,
  m.id_municipio_rf,
  m.id_municipio_bcb,
  m.nome AS nome_municipio,
  m.capital_uf,
  m.id_comarca,
  m.id_regiao_saude,
  m.nome_regiao_saude,
  m.id_regiao_imediata,
  m.nome_regiao_imediata,
  m.id_regiao_intermediaria,
  m.nome_regiao_intermediaria,
  m.id_microrregiao,
  m.nome_microrregiao,
  m.id_mesorregiao,
  m.nome_mesorregiao,
  m.id_regiao_metropolitana,
  m.nome_regiao_metropolitana,
  m.ddd,
  m.id_uf,
  m.sigla_uf,
  m.nome_uf,
  m.nome_regiao,
  m.amazonia_legal,
  m.centroide
FROM
  politica AS p
  FULL OUTER JOIN municipio_completo AS m ON p.id_municipio = m.id_municipio;


```

painel_pneerq_censo_escolar


```sql
-- #1
WITH
  territorio AS (
    SELECT
      *
    FROM
      `br-mec-segape-dev`.`projeto_painel_ministro`.`filtro_territorio`
  ),
  municipio AS (
    SELECT
      *
    FROM
      `br-mec-segape-dev`.`educacao_dados_mestres`.`municipio`
  ),
  censo AS (
    SELECT
      ano,
      CAST(id_municipio AS STRING) id_municipio,
      id_escola,
      rede,
      tipo_localizacao,
      tipo_localizacao_diferenciada,
      agua_inexistente,
      energia_inexistente,
      esgoto_inexistente,
      internet,
      local_funcionamento_predio_escolar,
      quantidade_matricula_educacao_basica,
      quantidade_docente_educacao_basica,
      quantidade_matricula_branca,
      quantidade_matricula_amarela,
      quantidade_matricula_parda,
      quantidade_matricula_preta,
      quantidade_matricula_indigena,
      quantidade_matricula_nao_declarada,
      quantidade_matricula_infantil,
      quantidade_matricula_fundamental_anos_iniciais,
      quantidade_matricula_fundamental_anos_finais,
      quantidade_matricula_medio,
      CAST(escolarizacao AS STRING) escolarizacao
    FROM
      educacao_inep_dados_abertos.censo_escolar_escola
  ),
  -- #2
  politica AS (
    SELECT
      DATE(CONCAT(censo.ano, '-01-01')) AS ano_tratado,
      CASE
        WHEN censo.ano = (
          SELECT
            MAX(ano)
          FROM
            censo
        ) THEN TRUE
        ELSE FALSE
      END AS ultimo_ano,
      censo.id_municipio,
      censo.id_escola,
      IFNULL(INITCAP(escola.nome), "Sem informação") AS nome_escola,
      CASE
        WHEN censo.rede = "1" THEN "Federal"
        WHEN censo.rede = "2" THEN "Estadual"
        WHEN censo.rede = "3" THEN "Municipal"
        WHEN censo.rede = "4" THEN "Privada"
      END AS rede,
      CASE
        WHEN censo.tipo_localizacao = "1" THEN "Urbana"
        WHEN censo.tipo_localizacao = "2" THEN "Rural"
      END AS localizacao,
      CASE
        WHEN agua_inexistente = 0 THEN 1
        ELSE 0
      END agua,
      CASE
        WHEN esgoto_inexistente = 0 THEN 1
        ELSE 0
      END esgoto,
      CASE
        WHEN energia_inexistente = 0 THEN 1
        ELSE 0
      END energia,
      CASE
        WHEN internet = 1 THEN 1
        ELSE 0
      END internet,
      CASE
        WHEN local_funcionamento_predio_escolar = 1 THEN 1
        ELSE 0
      END predio_escolar,
      SUM(
        agua_inexistente + esgoto_inexistente + energia_inexistente + (
          CASE
            WHEN internet = 1 THEN 0
            ELSE 1
          END
        ) + (
          CASE
            WHEN local_funcionamento_predio_escolar = 1 THEN 0
            ELSE 1
          END
        )
      ) num_indice_infraestrutura_elementar,
      CASE
        WHEN SUM(
          agua_inexistente + esgoto_inexistente + energia_inexistente + (
            CASE
              WHEN internet = 1 THEN 0
              ELSE 1
            END
          ) + (
            CASE
              WHEN local_funcionamento_predio_escolar = 1 THEN 0
              ELSE 1
            END
          )
        ) >= 2 THEN "Atende a 3 itens"
        WHEN SUM(
          agua_inexistente + esgoto_inexistente + energia_inexistente + (
            CASE
              WHEN internet = 1 THEN 0
              ELSE 1
            END
          ) + (
            CASE
              WHEN local_funcionamento_predio_escolar = 1 THEN 0
              ELSE 1
            END
          )
        ) = 1 THEN "Atende a 4 itens"
        WHEN SUM(
          agua_inexistente + esgoto_inexistente + energia_inexistente + (
            CASE
              WHEN internet = 1 THEN 0
              ELSE 1
            END
          ) + (
            CASE
              WHEN local_funcionamento_predio_escolar = 1 THEN 0
              ELSE 1
            END
          )
        ) = 0 THEN "Atende a todos os itens"
      END AS indice_infraestrutura_elementar,
      CASE
        WHEN SUM(quantidade_matricula_educacao_basica) <= 50 THEN "Até 50 matrículas"
        WHEN SUM(quantidade_matricula_educacao_basica) <= 150 THEN "De 51 a 150 matrículas"
        WHEN SUM(quantidade_matricula_educacao_basica) <= 300 THEN "De 151 a 300 matrículas"
        WHEN SUM(quantidade_matricula_educacao_basica) <= 500 THEN "De 301 a 500 matrículas"
        WHEN SUM(quantidade_matricula_educacao_basica) <= 1000 THEN "De 501 a 1000 matrículas"
        ELSE "Mais de 1000 matrículas"
      END AS porte_escola,
      CASE
        WHEN SUM(quantidade_matricula_branca) / NULLIF(SUM(quantidade_matricula_educacao_basica), 0) >= 0.6 THEN 'Maioria de alunos brancos (≥60%)'
        WHEN (
          SUM(quantidade_matricula_parda) + SUM(quantidade_matricula_preta)
        ) / NULLIF(SUM(quantidade_matricula_educacao_basica), 0) >= 0.6 THEN 'Maioria de alunos pretos ou pardos (≥60%)'
        WHEN SUM(quantidade_matricula_amarela) / NULLIF(SUM(quantidade_matricula_educacao_basica), 0) >= 0.6 THEN 'Maioria de alunos amarelos (≥60%)'
        WHEN SUM(quantidade_matricula_indigena) / NULLIF(SUM(quantidade_matricula_educacao_basica), 0) >= 0.6 THEN 'Maioria de alunos indígenas (≥60%)'
        WHEN SUM(quantidade_matricula_nao_declarada) / NULLIF(SUM(quantidade_matricula_educacao_basica), 0) >= 0.6 THEN 'Maioria sem declaração (≥60%)'
        ELSE 'Sem maioria significativa (≥60%)'
      END AS maioria_racial_60_pct,
      SUM(quantidade_docente_educacao_basica) quantidade_docente_educacao_basica,
      SUM(quantidade_matricula_nao_declarada) quantidade_matricula_cor_nao_declarada,
      SUM(quantidade_matricula_branca) quantidade_matricula_branca,
      SUM(quantidade_matricula_preta) quantidade_matricula_preta,
      SUM(quantidade_matricula_parda) quantidade_matricula_parda,
      SUM(quantidade_matricula_amarela) quantidade_matricula_amarela,
      SUM(quantidade_matricula_indigena) quantidade_matricula_indigena,
      SUM(quantidade_matricula_educacao_basica) quantidade_matricula_educacao_basica,
      SUM(quantidade_matricula_infantil) quantidade_matricula_infantil,
      SUM(quantidade_matricula_fundamental_anos_iniciais) quantidade_matricula_fundamental_anos_iniciais,
      SUM(quantidade_matricula_fundamental_anos_finais) quantidade_matricula_fundamental_anos_finais,
      SUM(quantidade_matricula_medio) quantidade_matricula_medio
    FROM
      censo censo
      LEFT JOIN educacao_dados_mestres.escola escola ON CAST(censo.id_escola AS INT) = CAST(escola.id_escola AS INT)
    WHERE
      ano = 2024
      AND tipo_localizacao_diferenciada = '3'
      AND escolarizacao = '1'
    GROUP BY
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12
  ),
  -- #3
  politica_municipio AS (
    SELECT
      p.id_municipio AS id,
      t.id AS id_municipio,
      m.nome AS nome_municipio,
      m.sigla_uf,
      CASE
        WHEN (t.estado LIKE 'Distrito Federal') THEN 'BR-DF'
        ELSE t.estado
      END AS estado_mapa,
      t.titulo AS dica_mapa,
      p.* EXCEPT (id_municipio)
    FROM
      territorio t
      LEFT JOIN municipio m ON t.id = m.id_municipio
      LEFT JOIN politica p ON t.id = p.id_municipio
    WHERE
      CAST(t.id AS INT) > 99
  ),
  politica_estado AS (
    SELECT
      SUBSTR(p.id_municipio, 1, 2) AS id,
      t.id AS id_municipio,
      m.nome AS nome_municipio,
      m.sigla_uf,
      CASE
        WHEN (t.estado LIKE 'Distrito Federal') THEN 'BR-DF'
        ELSE t.estado
      END AS estado_mapa,
      m.nome_uf AS dica_mapa,
      p.* EXCEPT (id_municipio)
    FROM
      territorio t
      LEFT JOIN municipio m ON t.id = m.id_municipio
      LEFT JOIN politica p ON t.id = p.id_municipio
    WHERE
      CAST(t.id AS INT) > 99
  ),
  politica_pais AS (
    SELECT
      "99" AS id,
      t.id AS id_municipio,
      m.nome AS nome_municipio,
      m.sigla_uf,
      CASE
        WHEN (t.estado LIKE 'Distrito Federal') THEN 'BR-DF'
        ELSE t.estado
      END AS estado_mapa,
      m.nome_uf AS dica_mapa,
      p.* EXCEPT (id_municipio)
    FROM
      territorio t
      LEFT JOIN municipio m ON t.id = m.id_municipio
      LEFT JOIN politica p ON t.id = p.id_municipio
    WHERE
      CAST(t.id AS INT) > 99
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
-- #4
SELECT
  t.id,
  t.municipio,
  t.estado,
  pc.* EXCEPT (id)
FROM
  territorio t
  LEFT JOIN politica_combinado pc ON pc.id = t.id

```


painel_pneerq_quilombolas



```sql
-- #1. Decreto de Criação da Tabela
CREATE OR REPLACE TABLE br-mec-segape-dev.projeto_painel_ministro.painel_pneerq_quilombolas AS

WITH

  territorio AS (
    SELECT
      *
    FROM
      `br-mec-segape-dev.projeto_painel_ministro.filtro_territorio`
  ),

  municipio AS (
    SELECT
      *
    FROM
      `br-mec-segape-dev`.`educacao_dados_mestres`.`municipio`
  ),

  censo AS (
    SELECT
      ano,
      CAST(id_municipio AS STRING) AS id_municipio,
      id_escola,
      rede,
      tipo_localizacao,
      tipo_localizacao_diferenciada,
      agua_inexistente,
      energia_inexistente,
      esgoto_inexistente,
      internet,
      local_funcionamento_predio_escolar,
      quantidade_matricula_educacao_basica,
      quantidade_docente_educacao_basica,
      quantidade_matricula_branca,
      quantidade_matricula_amarela,
      quantidade_matricula_parda,
      quantidade_matricula_preta,
      quantidade_matricula_indigena,
      quantidade_matricula_nao_declarada,
      quantidade_matricula_infantil,
      quantidade_matricula_fundamental_anos_iniciais,
      quantidade_matricula_fundamental_anos_finais,
      quantidade_matricula_medio,
      CAST(escolarizacao AS STRING) AS escolarizacao,
      cozinha,
      patio_coberto,
      patio_descoberto,
      refeitorio,
      quadra_esportes,
      quadra_esportes_coberta,
      quadra_esportes_descoberta,
      laboratorio_ciencias,
      laboratorio_informatica,
      material_pedagogico_indigena,
      material_pedagogico_etnico,
      material_especifico_quilombola,
      material_especifico_indigena
    FROM
      `educacao_inep_dados_abertos.censo_escolar_escola`
  ),

  -- #2. Lógica de Negócio e Agregação (CTE politica)
  politica AS (
    SELECT
      censo.ano AS ano,
      CASE
        WHEN censo.ano = (
          SELECT
            MAX(ano)
          FROM
            censo
        ) THEN TRUE
        ELSE FALSE
      END AS ultimo_ano,
      censo.id_municipio,
      censo.id_escola,
      IFNULL(INITCAP(escola.nome), "Sem informação") AS nome_escola,
      CASE
        WHEN censo.rede = "1" THEN "Federal"
        WHEN censo.rede = "2" THEN "Estadual"
        WHEN censo.rede = "3" THEN "Municipal"
        WHEN censo.rede = "4" THEN "Privada"
      END AS rede,
      CASE
        WHEN censo.tipo_localizacao = "1" THEN "Urbana"
        WHEN censo.tipo_localizacao = "2" THEN "Rural"
      END AS localizacao,
      censo.tipo_localizacao_diferenciada AS cod_infraestrutura,
      CASE
        WHEN censo.tipo_localizacao_diferenciada = "0" THEN "Convencionais"
        WHEN censo.tipo_localizacao_diferenciada = "1" THEN "Assentamento"
        WHEN censo.tipo_localizacao_diferenciada = "2" THEN "Indígenas"
        WHEN censo.tipo_localizacao_diferenciada = "3" THEN "Quilombolas"
        ELSE "Outros"
      END AS infraestrutura,
      CASE WHEN agua_inexistente = 0 THEN 1 ELSE 0 END AS agua,
      CASE WHEN esgoto_inexistente = 0 THEN 1 ELSE 0 END AS esgoto,
      CASE WHEN energia_inexistente = 0 THEN 1 ELSE 0 END AS energia,
      CASE WHEN internet = 1 THEN 1 ELSE 0 END AS internet_escola,
      CASE WHEN local_funcionamento_predio_escolar = 1 THEN 1 ELSE 0 END AS predio_escolar,
      CASE WHEN cozinha = 1 THEN 1 ELSE 0 END AS possui_cozinha,
      CASE WHEN refeitorio = 1 THEN 1 ELSE 0 END AS possui_refeitorio,
      CASE WHEN patio_coberto = 1 OR patio_descoberto = 1 THEN 1 ELSE 0 END AS possui_patio,
      CASE WHEN quadra_esportes = 1 OR quadra_esportes_coberta = 1 OR quadra_esportes_descoberta = 1 THEN 1 ELSE 0 END AS possui_quadra_esportes,
      CASE WHEN laboratorio_ciencias = 1 THEN 1 ELSE 0 END AS possui_laboratorio_ciencias,
      CASE WHEN laboratorio_informatica = 1 THEN 1 ELSE 0 END AS possui_laboratorio_informatica,
      CASE WHEN material_especifico_quilombola = 1 OR material_pedagogico_indigena = 1 OR material_pedagogico_etnico = 1 OR material_especifico_indigena = 1 THEN 1 ELSE 0 END AS possui_material_pedagogico_etnico_racial,
      SUM(
        agua_inexistente + esgoto_inexistente + energia_inexistente + (
          CASE
            WHEN internet = 1 THEN 0
            ELSE 1
          END
        ) + (
          CASE
            WHEN local_funcionamento_predio_escolar = 1 THEN 0
            ELSE 1
          END
        )
      ) AS num_indice_infraestrutura_elementar,
      CASE
        WHEN SUM(
          agua_inexistente + esgoto_inexistente + energia_inexistente + (
            CASE
              WHEN internet = 1 THEN 0
              ELSE 1
            END
          ) + (
            CASE
              WHEN local_funcionamento_predio_escolar = 1 THEN 0
              ELSE 1
            END
          )
        ) >= 2 THEN "Atende a 3 itens"
        WHEN SUM(
          agua_inexistente + esgoto_inexistente + energia_inexistente + (
            CASE
              WHEN internet = 1 THEN 0
              ELSE 1
            END
          ) + (
            CASE
              WHEN local_funcionamento_predio_escolar = 1 THEN 0
              ELSE 1
            END
          )
        ) = 1 THEN "Atende a 4 itens"
        WHEN SUM(
          agua_inexistente + esgoto_inexistente + energia_inexistente + (
            CASE
              WHEN internet = 1 THEN 0
              ELSE 1
            END
          ) + (
            CASE
              WHEN local_funcionamento_predio_escolar = 1 THEN 0
              ELSE 1
            END
          )
        ) = 0 THEN "Atende a todos os itens"
      END AS indice_infraestrutura_elementar,
      CASE
        WHEN SUM(quantidade_matricula_educacao_basica) <= 50 THEN "Até 50 matrículas"
        WHEN SUM(quantidade_matricula_educacao_basica) <= 150 THEN "De 51 a 150 matrículas"
        WHEN SUM(quantidade_matricula_educacao_basica) <= 300 THEN "De 151 a 300 matrículas"
        WHEN SUM(quantidade_matricula_educacao_basica) <= 500 THEN "De 301 a 500 matrículas"
        WHEN SUM(quantidade_matricula_educacao_basica) <= 1000 THEN "De 501 a 1000 matrículas"
        ELSE "Mais de 1000 matrículas"
      END AS porte_escola,
      CASE
        WHEN SUM(quantidade_matricula_branca) / NULLIF(SUM(quantidade_matricula_educacao_basica), 0) >= 0.6 THEN 'Maioria de alunos brancos (≥60%)'
        WHEN (
          SUM(quantidade_matricula_parda) + SUM(quantidade_matricula_preta)
        ) / NULLIF(SUM(quantidade_matricula_educacao_basica), 0) >= 0.6 THEN 'Maioria de alunos pretos ou pardos (≥60%)'
        WHEN SUM(quantidade_matricula_amarela) / NULLIF(SUM(quantidade_matricula_educacao_basica), 0) >= 0.6 THEN 'Maioria de alunos amarelos (≥60%)'
        WHEN SUM(quantidade_matricula_indigena) / NULLIF(SUM(quantidade_matricula_educacao_basica), 0) >= 0.6 THEN 'Maioria de alunos indígenas (≥60%)'
        WHEN SUM(quantidade_matricula_nao_declarada) / NULLIF(SUM(quantidade_matricula_educacao_basica), 0) >= 0.6 THEN 'Maioria sem declaração (≥60%)'
        ELSE 'Sem maioria significativa (≥60%)'
      END AS maioria_racial_60_pct,
      -- #3. A Grande Divisão
      CASE
        WHEN (
          SUM(quantidade_matricula_parda) + SUM(quantidade_matricula_preta)
        ) / NULLIF(SUM(quantidade_matricula_educacao_basica), 0) >= 0.6 THEN 'Pessoas Negras e Pardas'
        ELSE 'Outros Grupos Raciais'
      END AS grupo_racial_dashboard,
      SUM(quantidade_docente_educacao_basica) AS quantidade_docente_educacao_basica,
      SUM(quantidade_matricula_nao_declarada) AS quantidade_matricula_cor_nao_declarada,
      SUM(quantidade_matricula_branca) AS quantidade_matricula_branca,
      SUM(quantidade_matricula_preta) AS quantidade_matricula_preta,
      SUM(quantidade_matricula_parda) AS quantidade_matricula_parda,
      SUM(quantidade_matricula_amarela) AS quantidade_matricula_amarela,
      SUM(quantidade_matricula_indigena) AS quantidade_matricula_indigena,
      SUM(quantidade_matricula_educacao_basica) AS quantidade_matricula_educacao_basica,
      SUM(quantidade_matricula_infantil) AS quantidade_matricula_infantil,
      SUM(quantidade_matricula_fundamental_anos_iniciais) AS quantidade_matricula_fundamental_anos_iniciais,
      SUM(quantidade_matricula_fundamental_anos_finais) AS quantidade_matricula_fundamental_anos_finais,
      SUM(quantidade_matricula_medio) AS quantidade_matricula_medio,
      (
        SUM(
          CASE
            WHEN cozinha = 1 THEN 1
            ELSE 0
          END
        ) / NULLIF(SUM(1), 0)
      ) * 100 AS pct_cozinha,
      (
        SUM(
          CASE
            WHEN refeitorio = 1 THEN 1
            ELSE 0
          END
        ) / NULLIF(SUM(1), 0)
      ) * 100 AS pct_refeitorio,
      (
        SUM(
          CASE
            WHEN patio_coberto = 1
            OR patio_descoberto = 1 THEN 1
            ELSE 0
          END
        ) / NULLIF(SUM(1), 0)
      ) * 100 AS pct_patio,
      (
        SUM(
          CASE
            WHEN quadra_esportes = 1
            OR quadra_esportes_coberta = 1
            OR quadra_esportes_descoberta = 1 THEN 1
            ELSE 0
          END
        ) / NULLIF(SUM(1), 0)
      ) * 100 AS pct_quadra_esportes,
      (
        SUM(
          CASE
            WHEN laboratorio_ciencias = 1 THEN 1
            ELSE 0
          END
        ) / NULLIF(SUM(1), 0)
      ) * 100 AS pct_laboratorio_ciencias,
      (
        SUM(
          CASE
            WHEN laboratorio_informatica = 1 THEN 1
            ELSE 0
          END
        ) / NULLIF(SUM(1), 0)
      ) * 100 AS pct_laboratorio_informatica,
      (
        SUM(
          CASE
            WHEN material_especifico_quilombola = 1
            OR material_pedagogico_indigena = 1
            OR material_pedagogico_etnico = 1
            OR material_especifico_indigena = 1 THEN 1
            ELSE 0
          END
        ) / NULLIF(SUM(1), 0)
      ) * 100 AS pct_material_pedagogico_etnico_racial
    FROM
      censo AS censo
      LEFT JOIN `educacao_dados_mestres.escola` AS escola ON CAST(censo.id_escola AS INT64) = CAST(escola.id_escola AS INT64)
    WHERE
      escolarizacao = '1' -- Mantido filtro de escolas em atividade
    GROUP BY
      ano,
      ultimo_ano,
      censo.id_municipio,
      censo.id_escola,
      nome_escola,
      rede,
      localizacao,
      cod_infraestrutura,
      infraestrutura,
      agua,
      esgoto,
      energia,
      internet_escola,
      predio_escolar,
      possui_cozinha,
      possui_refeitorio,
      possui_patio,
      possui_quadra_esportes,
      possui_laboratorio_ciencias,
      possui_laboratorio_informatica,
      possui_material_pedagogico_etnico_racial
  ),

  politica_municipio AS (
    SELECT
      p.id_municipio AS id,
      t.id AS id_municipio,
      m.nome AS nome_municipio,
      m.sigla_uf,
      CASE
        WHEN (t.estado LIKE 'Distrito Federal') THEN 'BR-DF'
        ELSE t.estado
      END AS estado_mapa,
      t.titulo AS dica_mapa,
      p.* EXCEPT (id_municipio)
    FROM
      territorio AS t
      LEFT JOIN municipio AS m ON t.id = m.id_municipio
      LEFT JOIN politica AS p ON t.id = p.id_municipio
    WHERE
      CAST(t.id AS INT64) > 99
  ),

  politica_estado AS (
    SELECT
      SUBSTR(p.id_municipio, 1, 2) AS id,
      t.id AS id_municipio,
      m.nome AS nome_municipio,
      m.sigla_uf,
      CASE
        WHEN (t.estado LIKE 'Distrito Federal') THEN 'BR-DF'
        ELSE t.estado
      END AS estado_mapa,
      m.nome_uf AS dica_mapa,
      p.* EXCEPT (id_municipio)
    FROM
      territorio AS t
      LEFT JOIN municipio AS m ON t.id = m.id_municipio
      LEFT JOIN politica AS p ON t.id = p.id_municipio
    WHERE
      CAST(t.id AS INT64) > 99
  ),

  politica_pais AS (
    SELECT
      "99" AS id,
      t.id AS id_municipio,
      m.nome AS nome_municipio,
      m.sigla_uf,
      CASE
        WHEN (t.estado LIKE 'Distrito Federal') THEN 'BR-DF'
        ELSE t.estado
      END AS estado_mapa,
      m.nome_uf AS dica_mapa,
      p.* EXCEPT (id_municipio)
    FROM
      territorio AS t
      LEFT JOIN municipio AS m ON t.id = m.id_municipio
      LEFT JOIN politica AS p ON t.id = p.id_municipio
    WHERE
      CAST(t.id AS INT64) > 99
  ),

  politica_combinado AS (
    SELECT * FROM politica_municipio
    UNION ALL
    SELECT * FROM politica_estado
    UNION ALL
    SELECT * FROM politica_pais
  ),

  final_result AS (
    SELECT
      t.id,
      t.municipio,
      t.estado,
      pc.* EXCEPT (id)
    FROM
      territorio AS t
      LEFT JOIN politica_combinado AS pc ON pc.id = t.id
  )

SELECT * FROM final_result;
