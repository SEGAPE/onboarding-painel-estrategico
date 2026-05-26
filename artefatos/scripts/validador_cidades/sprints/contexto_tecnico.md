# Contexto Tecnico - Padroes dos JOINs do Dashboard

## filtro_territorio: o ponto central

Praticamente todos os modelos `painel_*` comecam com a CTE `filtro_territorio`.
Ela fornece as colunas padrao: `id`, `municipio`, `estado`, `titulo`.

```sql
filtro_territorio AS (
  SELECT id, municipio, estado, titulo
  FROM {{ ref('filtro_territorio') }}
)
```

O JOIN entre `filtro_territorio` e os dados de cada politica publica e o ponto
mais critico. Se o municipio nao casa nesse JOIN, o dado desaparece do dashboard.

### Causas comuns de perda no JOIN

1. **Nome do municipio diferente** — "Andradina" vs "ANDRADINA" vs "Andradina - SP"
2. **id_municipio IBGE ausente ou diferente** — 3501004 pode vir como "3501004" (string)
3. **CROSS JOIN com dimensoes** — muitos modelos fazem CROSS JOIN de filtro_territorio
   com anos ou categorias. Se a dimensao nao tem o ano/categoria, o municipio some.
4. **LEFT vs INNER JOIN** — LEFT preserva o territorio mesmo sem dados; INNER descarta.
5. **SAFE_CAST silencioso** — converte para NULL, que some na agregacao.

## Niveis do dashboard

O dashboard tem 3 niveis pre-filtrados:
- **Todos (pais)**: id = 99 (filtro_id_brasil)
- **Estado**: ex: "Sao Paulo"
- **Municipio**: ex: "Andradina - SP"

Quando o usuario seleciona um municipio, o Looker Studio filtra por `municipio = 'Andradina - SP'`.
Se a tabela nao tem essa linha, aparece 0 ou vazio.

## Padroes de JOIN por tipo de modelo

### Tipo 1: CROSS JOIN territorio x dimensao (mais comum)
```sql
filtro_territorio CROSS JOIN anos
LEFT JOIN politica ON territorio.id = politica.id AND anos.ano = politica.ano
```
Modelos: painel_cnca, painel_pronatec_completo, painel_mulheresmil_completo, painel_sisu

**Armadilha**: se a dimensao (anos, categorias) nao tem o valor esperado, o CROSS JOIN
nao gera a linha e o LEFT JOIN nao encontra match.

### Tipo 2: JOIN direto territorio x dados
```sql
filtro_territorio
LEFT JOIN dados_politica ON territorio.id_municipio = dados.id_municipio
```
Modelos: painel_escola, painel_matricula_municipio, painel_fundeb

**Armadilha**: se o id_municipio e CAST diferente (INT vs STRING), o JOIN falha silenciosamente.

### Tipo 3: FULL OUTER JOIN entre fontes
```sql
fonte_a FULL OUTER JOIN fonte_b ON a.id_pessoa = b.id_pessoa AND a.edital = b.edital
```
Modelos: painel_pdmlic

**Armadilha**: sem a chave de edital, registros duplicam ou se perdem.

## Camadas de dados (validacao bottom-up)

```
Camada 1: SOURCE (data lake / staging)
  → br-mec-segape-dev.raw_csv_*.stg_*
  → br-mec-segape-dev.raw_api_*.stg_*
  → br-mec-segape-dev.raw_bd_*.*

Camada 2: POLITICA (logica de negocio)
  → br-mec-segape-dev.educacao_politica_*.*

Camada 3: INDICADOR (KPIs)
  → br-mec-segape-dev.indicador_politica_*.*

Camada 4: PAINEL (dashboard - tabela final)
  → br-mec-segape-dev.projeto_painel_ministro.painel_*
```

O validador deve ser capaz de descer da camada 4 ate a camada 1 automaticamente.

## Coluna de municipio por camada

| Camada | Coluna tipica | Exemplo |
|--------|--------------|---------|
| raw/staging | id_municipio (IBGE) | 3501004 |
| politica | id_municipio ou nome_municipio | 3501004 ou "Andradina" |
| painel | municipio (formatado) | "Andradina - SP" |

**Critico**: ao rastrear upstream, o validador precisa traduzir entre formatos.
O id IBGE de Andradina e 3501004. O nome pode vir como "ANDRADINA", "Andradina"
ou "Andradina - SP" dependendo da camada.

## Tabelas que usam filtro_territorio

Todas as 18 tabelas ativas do projeto_painel_ministro usam filtro_territorio
como CTE base. A excecao e painel_pnp_situacao_matricula (movido para outro schema)
que usa id_unidade em vez de municipio.

## Impacto no validador

O scanner precisa:
1. Buscar por municipio na tabela final (camada 4)
2. Se ZERO, buscar por id_municipio IBGE na camada 2 (politica)
3. Se ZERO na camada 2, buscar na camada 1 (raw/staging)
4. Se a camada 2 tem dado mas a 4 nao: JOIN do painel perdeu o registro
5. Se a camada 1 tem dado mas a 2 nao: JOIN da politica perdeu o registro
6. Se nenhuma camada tem: dado nunca chegou ao data lake

Essa cadeia de verificacao e automatica — o usuario so informa o municipio.
