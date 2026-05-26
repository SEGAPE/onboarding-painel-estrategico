1. **`dim_municipio` e `dim_uf`**: Nossos atlas geográficos, imutáveis e corretos, a base para toda a análise territorial.

2. **`egressos_ensino_medio` e `ingressantes_licenciatura`**: As duas populações de estudantes, isoladas e prontas para a união, com a garantia de unicidade pelo `ROW_NUMBER()`.

3. **`dados_consolidados`**: A mesa de união onde os dois mundos se encontram, permitindo a análise de todos os indivíduos.

4. **Seleção Final e Conversão para Inteiro**: A transmutação final. Os indicadores que antes eram `FLOAT` agora são `INT`. A lógica é a mesma, mas o resultado é mais... nítido. Concreto. Um `1` ou um `0`, sem ambiguidades.
```sql
-- #

CREATE OR REPLACE TABLE br-mec-segape-dev.projeto_painel_ministro.analise_transicao_pdm_detalhada AS (

WITH

-- #1

dim_municipio AS (

SELECT

id_municipio,

nome AS nome_municipio,

sigla_uf

FROM

`br-mec-segape-dev`.`educacao_dados_mestres`.`municipio`

),

dim_uf AS (

SELECT

sigla,

nome AS nome_estado

FROM

`br-mec-segape-dev`.`educacao_dados_mestres`.`uf`

),

-- #2

egressos_ensino_medio AS (

SELECT

incentivo.id_pessoa,

mun.sigla_uf,

mun.nome_municipio,

incentivo.id_rede,

ROW_NUMBER() OVER(PARTITION BY incentivo.id_pessoa ORDER BY incentivo.id_mes_competencia DESC) AS rn

FROM

`educacao_politica_pdm`.`incentivo`

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

ROW_NUMBER() OVER(PARTITION BY id_pessoa ORDER BY data_referencia DESC) AS rn

FROM

`br-mec-segape-dev`.`educacao_temp`.`cadastrados_freire`

WHERE

beneficiario = TRUE

),

-- #3

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

(SELECT * FROM egressos_ensino_medio WHERE rn = 1) AS med

FULL OUTER JOIN

(SELECT * FROM ingressantes_licenciatura WHERE rn = 1) AS lic

ON

med.id_pessoa = lic.id_pessoa

)

-- #4

SELECT

t1.id_pessoa,

CASE WHEN t1.id_pessoa_medio IS NOT NULL AND t1.id_pessoa_lic IS NOT NULL THEN 1 ELSE 0 END AS beneficiario_ambos,

CASE WHEN t1.id_pessoa_medio IS NOT NULL AND t1.id_pessoa_lic IS NULL THEN 1 ELSE 0 END AS apenas_ensino_medio,

CASE WHEN t1.id_pessoa_medio IS NULL AND t1.id_pessoa_lic IS NOT NULL THEN 1 ELSE 0 END AS apenas_licenciatura,

TRIM(SPLIT(t1.nome_municipio_bruto, '-')[OFFSET(0)]) AS municipio,

t1.uf,

t2.nome_estado AS estado,

t1.rede_ensino_medio,

t1.curso_licenciatura

FROM

dados_consolidados AS t1

LEFT JOIN

dim_uf AS t2

ON

t1.uf = t2.sigla

);
```


1505  + 22 (estados) + 3 Adesões fora do simec


As bolsas
