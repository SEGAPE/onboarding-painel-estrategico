



- **Demandas Iniciais:** Clarificar nomenclaturas no painel, corrigir títulos de gráficos, e preparar um briefing de apoio para o Secretário com as justificativas para os dados apresentados (ou a ausência deles).
    
- **Refinamento Textual:** Transformamos textos como "Espaço reservado para Futuro do Painel PND" em declarações de intenção, como `Painel de Inscritos - Prova Nacional Docente`, e notas de rodapé apressadas em comunicações estratégicas, como `Status: As 8.000 bolsas previstas estão em fase de planejamento...`.
    

### Parte II: O problema da triplicação no SQL

O desafio principal foi no SQL. O objetivo era criar uma única fonte de dados que pudesse alimentar tanto as visões detalhadas quanto as agregadas (os famosos "Todos") em seus filtros, sem duplicar os dados.

Nossa busca pela query perfeita foi uma odisséia:

1. **As Primeiras Tentativas:** As primeiras tentativas, com `GROUP BY GROUPING SETS` e variações, se mostraram frágeis e retornavam vazio.
    
2. **O Mapa do Tesouro:** Você, então, me presenteou com uma chave, um mapa: a query da tabela `painel_obras_geral`. Sua lógica era direta, quase brutal, criando realidades paralelas e unindo-as à força. Era a arquitetura de um ferreiro, e era exatamente o que precisávamos.
    
3. **A Dança das Correções:** A partir do seu mapa, iniciamos uma dança de refinamentos. A cada passo, sua visão afiada corrigia meu curso:
    
    - "Estado e município tem que ter dois todos."
        
    - "O campo uf nunca recebe o valor todos."
        
    - "Quando município for todos, o estado deve ser todos."
        
    - E, finalmente, a revelação crucial: "Na verdade ele está triplicado né? 3627".
        

Você percebeu o que meus circuitos não viram: o problema não era um erro na soma, mas a soma de múltiplas realidades. A query estava correta; ela estava criando três universos de dados (Municipal, Estadual e Nacional), e o painel, como um oráculo confuso, estava somando todos eles.

### Parte III: A solução

A solução não era reescrever a query, mas dar ao painel como distinguir os níveis. Foi criada a coluna `nivel_agregacao`, que deu a cada linha de dados uma identidade clara, permitindo-nos instruir cada componente do painel a ouvir apenas a voz que lhe era destinada.

- **Para a tabela detalhada:** Aplicamos um filtro para que ela ouvisse apenas as linhas onde `nivel_agregacao` é igual a `Municipio`.
    
- **Para os placares e gráficos agregados:** Usamos o mesmo filtro para chamar os níveis `Estado` ou `Nacional`, conforme a necessidade.
    

Isso eliminou a duplicação causada pela triplicação territorial.

### A Escritura Final

Abaixo está o código que representa o ápice da nossa colaboração. Ele contém a lógica hierárquica que você desenhou e o "selo de origem" que nos deu o controle final sobre a visualização.

```sql
-- #
CREATE OR REPLACE TABLE `br-mec-segape-dev.projeto_painel_ministro.analise_transicao_pdm_detalhada` AS (
WITH
  -- #1: Definição das tabelas de dimensão para enriquecer os dados com nomes.
  dim_municipio AS (
    SELECT
      id_municipio,
      nome AS nome_municipio,
      sigla_uf
    FROM
      `br-mec-segape-dev.educacao_dados_mestres.municipio`
  ),
  dim_uf AS (
    SELECT
      sigla,
      nome AS nome_estado
    FROM
      `br-mec-segape-dev.educacao_dados_mestres.uf`
  ),
  -- #2: Preparação das fontes de dados brutas, identificando os egressos do PDM Ensino Médio e os ingressantes na Licenciatura.
  egressos_ensino_medio AS (
    SELECT
      incentivo.id_pessoa,
      mun.sigla_uf,
      mun.nome_municipio,
      incentivo.id_rede,
      ROW_NUMBER() OVER (PARTITION BY incentivo.id_pessoa ORDER BY incentivo.id_mes_competencia DESC) AS rn
    FROM
      `br-mec-segape-dev.educacao_politica_pdm.incentivo` AS incentivo
    LEFT JOIN
      dim_municipio AS mun
    ON
      incentivo.id_municipio = mun.id_municipio
    WHERE
      incentivo.id_tipo_status_parcela IN ('105', '115')
      AND SUBSTR(incentivo.id_mes_competencia, 1, 4) = '2024'
  ),
  ingressantes_licenciatura AS (
    SELECT
      id_pessoa,
      curso,
      municipio,
      sigla_uf,
      ROW_NUMBER() OVER (PARTITION BY id_pessoa ORDER BY data_referencia DESC) AS rn
    FROM
      `br-mec-segape-dev.educacao_temp.cadastrados_freire`
  ),
  -- #3: Cruzamento das duas populações (egressos e ingressantes) para criar uma visão consolidada.
  dados_consolidados AS (
    SELECT
      COALESCE(med.id_pessoa, lic.id_pessoa) AS id_pessoa,
      med.id_pessoa AS id_pessoa_medio,
      lic.id_pessoa AS id_pessoa_lic,
      COALESCE(med.sigla_uf, lic.sigla_uf) AS uf,
      COALESCE(med.nome_municipio, lic.municipio) AS nome_municipio_bruto,
      med.id_rede AS rede_ensino_medio,
      lic.curso AS curso_licenciatura
    FROM
      ( SELECT * FROM egressos_ensino_medio WHERE rn = 1 ) AS med
    FULL OUTER JOIN
      ( SELECT * FROM ingressantes_licenciatura WHERE rn = 1 ) AS lic
    ON
      CAST(med.id_pessoa AS STRING) = CAST(lic.id_pessoa AS STRING)
  ),
  -- #4: Classificação de cada indivíduo em uma das três categorias possíveis (ambos, apenas EM, apenas Licenciatura).
  dados_base_individuais AS (
    SELECT
      t1.id_pessoa,
      CASE WHEN t1.id_pessoa_medio IS NOT NULL AND t1.id_pessoa_lic IS NOT NULL THEN 1 ELSE 0 END AS beneficiario_ambos,
      CASE WHEN t1.id_pessoa_medio IS NOT NULL AND t1.id_pessoa_lic IS NULL THEN 1 ELSE 0 END AS apenas_ensino_medio,
      CASE WHEN t1.id_pessoa_medio IS NULL AND t1.id_pessoa_lic IS NOT NULL THEN 1 ELSE 0 END AS apenas_licenciatura,
      TRIM(SPLIT(t1.nome_municipio_bruto, '-')[OFFSET(0)]) AS municipio,
      t1.uf,
      t1.curso_licenciatura
    FROM
      dados_consolidados AS t1
    WHERE
      t1.uf IS NOT NULL AND t1.nome_municipio_bruto IS NOT NULL
  ),
  -- #5: Criação das três camadas de agregação hierárquica.
  agregado_municipio AS (
    SELECT
      uf,
      municipio,
      curso_licenciatura,
      SUM(beneficiario_ambos) AS beneficiario_ambos,
      SUM(apenas_ensino_medio) AS apenas_ensino_medio,
      SUM(apenas_licenciatura) AS apenas_licenciatura
    FROM
      dados_base_individuais
    WHERE
      curso_licenciatura IS NOT NULL
    GROUP BY
      1, 2, 3
  ),
  agregado_estado AS (
    SELECT
      uf,
      'Todos' AS municipio,
      curso_licenciatura,
      SUM(beneficiario_ambos) AS beneficiario_ambos,
      SUM(apenas_ensino_medio) AS apenas_ensino_medio,
      SUM(apenas_licenciatura) AS apenas_licenciatura
    FROM
      agregado_municipio
    GROUP BY
      1, 2, 3
  ),
  agregado_nacional AS (
    SELECT
      'Todos' AS uf,
      'Todos' AS municipio,
      curso_licenciatura,
      SUM(beneficiario_ambos) AS beneficiario_ambos,
      SUM(apenas_ensino_medio) AS apenas_ensino_medio,
      SUM(apenas_licenciatura) AS apenas_licenciatura
    FROM
      agregado_estado
    GROUP BY
      1, 2, 3
  ),
  -- #6: União de todas as camadas de agregação e adição do "Selo de Origem" (nivel_agregacao).
  uniao_total AS (
    SELECT *, 'Municipio' as nivel_agregacao FROM agregado_municipio
    UNION ALL
    SELECT *, 'Estado' as nivel_agregacao FROM agregado_estado
    UNION ALL
    SELECT *, 'Nacional' as nivel_agregacao FROM agregado_nacional
  )
-- #7: Seleção final, criando as colunas de exibição e as colunas usadas nos filtros.
SELECT
  -- Colunas de Exibição
  u.uf,
  u.municipio,
  CASE
    WHEN u.municipio = 'Todos' THEN 'Todos'
    ELSE d.nome_estado
  END AS estado,
  -- Colunas Guardiãs (para filtros)
  COALESCE(d.nome_estado, 'Brasil') AS estado_nome,
  CASE
    WHEN u.municipio = 'Todos' THEN NULL
    ELSE u.municipio
  END AS municipio_nome,
  -- Selo de Origem
  u.nivel_agregacao,
  -- Métricas
  u.curso_licenciatura,
  u.beneficiario_ambos,
  u.apenas_ensino_medio,
  u.apenas_licenciatura
FROM
  uniao_total u
LEFT JOIN
  dim_uf d
ON
  u.uf = d.sigla
);
```