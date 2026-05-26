---
titulo: "Erros Comuns em Revisão de PRs"
aliases:
  - "erros review"
  - "checklist PR"
  - "erros comuns"
tags:
  - sql
  - dbt
  - jinja
  - padrao
  - armadilha
  - referencia
data_criacao: "2026-04-08"
data_modificacao: "2026-04-08"
---

# Erros Comuns em Revisão de PRs

Este guia documenta os padrões de erro mais flagrados em code reviews no projeto. Cada seção explica o erro, por que está errado, e como corrigir. Baseado em revisões reais de PRs da equipe.

Para os padrões completos de código, consulte [[04-padroes-codigo]].

---

## 1. SAFE_CAST em vez de CAST #sql #armadilha

### O que é

Usar `SAFE_CAST(campo AS tipo)` em vez de `CAST(campo AS tipo)`.

### Por que está errado

`SAFE_CAST` retorna `NULL` quando a conversão falha, em vez de gerar erro. Isso **mascara dados inválidos** que deveriam ser tratados explicitamente.

Na prática: se um campo de CPF vem com letras misturadas, `SAFE_CAST(cpf AS INT64)` retorna `NULL` silenciosamente. Esse `NULL` é descartado nas agregações (`SUM`, `COUNT`), fazendo o dashboard exibir números **menores que o real** sem nenhum alerta.

### Antes (errado)

```sql
SELECT
  SAFE_CAST(id_pessoa AS INT64) AS id_pessoa,
  SAFE_CAST(valor_repasse AS FLOAT64) AS valor_repasse
FROM {{ ref('stg_incentivo') }}
```

### Depois (correto)

```sql
SELECT
  CAST(id_pessoa AS INT64) AS id_pessoa,
  CAST(valor_repasse AS FLOAT64) AS valor_repasse
FROM {{ ref('stg_incentivo') }}
```

Se o `CAST` falhar, o `dbt run` retorna erro explícito -- você investiga e corrige a origem do problema em vez de descobrir meses depois que os números estavam errados.

---

## 2. Comentários SQL em vez de Jinja #jinja #armadilha

### O que é

Usar `--` (comentário SQL) em vez de `{# #}` (comentário Jinja) nos modelos dbt.

### Por que está errado

O dbt gera documentação automática a partir dos modelos SQL. Comentários com `--` são incluídos na documentação gerada e no SQL compilado. Comentários com `{# #}` são removidos antes da compilação.

Resultado: comentários internos de desenvolvimento (`-- TODO`, `-- campo removido temporariamente`, `-- teste da Karine`) aparecem na documentação pública do catálogo de dados.

### Antes (errado)

```sql
-- Filtro por ano base do governo atual
WHERE ano > {{ var('ano_base') }}

-- Removido: campo não existe mais em 2025
-- AND indicador_especial = TRUE
```

### Depois (correto)

```sql
{# Filtro por ano base do governo atual #}
WHERE ano > {{ var('ano_base') }}

{# Campo removido: indicador_especial não existe em 2025.
   Substituído por quantidade_matricula_especial > 0 #}
```

---

## 3. Caminhos hardcoded em vez de ref()/source() #dbt #armadilha

### O que é

Referenciar tabelas pelo caminho completo no BigQuery em vez de usar as macros `{{ ref() }}` e `{{ source() }}`.

### Por que está errado

O dbt constrói um grafo de dependências entre modelos. Quando você usa `{{ ref('modelo') }}`, o dbt sabe que seu modelo depende de `modelo` e executa na ordem correta.

Com caminhos hardcoded, o dbt **não sabe** que a dependência existe. Consequências:
- `dbt run --select +seu_modelo` não inclui o modelo referenciado
- `dbt docs` não mostra a conexão no grafo
- Mudar o dataset de destino (dev -> prod) não atualiza a referência

### Antes (errado)

```sql
SELECT *
FROM `br-mec-segape-dev.projeto_painel_ministro.filtro_territorio`
```

### Depois (correto)

```sql
SELECT *
FROM {{ ref('filtro_territorio') }}
```

Para tabelas externas ao dbt (sources):

```sql
{# Errado #}
FROM `br-mec-segape-dev.raw_bd_pdm_staging.raw_incentivo`

{# Correto #}
FROM {{ source('raw_pdm', 'raw_incentivo') }}
```

---

## 4. Divergência de dados entre dev e prod #dbt #armadilha

### O que é

Tabelas auxiliares (dicionários, referências) estão em versões diferentes entre os ambientes dev (`br-mec-segape-dev`) e prod (`br-mec-segape`).

### Por que está errado

Seu modelo pode funcionar perfeitamente em dev porque a tabela auxiliar está atualizada, mas falhar ou retornar dados incorretos em prod onde a tabela está desatualizada.

Exemplo real: a tabela `censo_escolar_dicionario` estava mais recente em dev do que em produção. Modelos que dependiam dela apresentaram resultados diferentes na validação entre ambientes, bloqueando o merge da PR.

### Como verificar

Antes de abrir a PR, comparar as tabelas auxiliares entre os ambientes:

```sql
{# Verificar se a tabela auxiliar tem os mesmos dados em dev e prod #}
SELECT 'dev' AS ambiente, COUNT(*) AS registros
FROM `br-mec-segape-dev.schema.tabela_dicionario`
UNION ALL
SELECT 'prod', COUNT(*)
FROM `br-mec-segape.schema.tabela_dicionario`
```

Se houver divergência, reportar à equipe de engenharia para sincronizar antes do merge.

---

## Checklist rápida de auto-revisão

Antes de abrir a PR, passe por cada item. Consulte [[04-padroes-codigo]] para detalhes e [[05-armadilhas]] para contexto sobre cada regra.

- [ ] Sem `SAFE_CAST` -- usar `CAST` em todos os modelos
- [ ] Comentários com `{# #}` -- nenhum `--` de desenvolvimento no SQL
- [ ] Referências com `{{ ref() }}` e `{{ source() }}` -- nenhum caminho hardcoded
- [ ] Dados validados em dev E prod -- tabelas auxiliares sincronizadas
- [ ] Comparações de string com `UPPER()` ou `LOWER()`
- [ ] Sem CASTs redundantes (campo já tem o tipo correto)
- [ ] CTEs sem `{{ ref() }}` duplicado
- [ ] schema.yml com formato `//` separadores e 6 campos obrigatórios
- [ ] Acentuação correta em todo o código e descrições
- [ ] Commit com mensagem PT-BR descritiva, sem emojis

---

## Navegação

| Documento | Descrição |
|-----------|-----------|
| [04 - Padrões de Código](04-padroes-codigo.md) | Standards completos de SQL, schema.yml, commits |
| [05 - Armadilhas](05-armadilhas.md) | Mais armadilhas conhecidas do projeto |
| [06 - Cultura](06-cultura-desenvolvimento.md) | Princípios e casos reais |

[Voltar ao índice](onboarding.md)
