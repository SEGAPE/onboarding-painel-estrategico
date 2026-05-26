---
Autoral: André
Código: SQL
---
### Arquitetura do Script

#### #1. Fontes de Dados

Nesta primeira etapa, definimos as fontes primárias de nossos dados. As tabelas `territorio`, `municipio` e `censo` são usadas como cte, formando a base.

#### #2. Lógica de Negócio e Agregação

Na CTE `politica`, transformamos os dados brutos do censo. Criamos novas colunas, calculamos métricas como o `indice_infraestrutura_elementar` e o `porte_escola`, e aplicamos os filtros de `ano`, `tipo_localizacao_diferenciada` e `escolarizacao`.

#### #3. Combinação de Políticas (Município, Estado, País)

Preparando os dados para diferentes níveis de granularidade geográfica. As CTEs `politica_municipio`, `politica_estado` e `politica_pais` agregam os dados em seus respectivos níveis. A CTE `politica_combinado` então une essas três visões em uma única tabela.

#### #4. Seleção Final

O ato final. Unimos a tabela `territorio` com os dados processados e combinados da `politica_combinado`. O `SELECT` final escolhe as colunas que vão formar a tabela de saída.


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
