---
titulo: "Armadilhas Conhecidas"
aliases:
  - "armadilhas"
  - "pitfalls"
tags:
  - dbt
  - bigquery
  - git
  - policy-tags
  - armadilha
data_criacao: "2026-01-01"
data_modificacao: "2026-04-08"
---

# Guia 05 — Armadilhas Conhecidas

Erros que já causaram problemas reais no projeto. Leia com atenção antes de começar. Para os padrões de código que previnem esses erros, veja [[04-padroes-codigo]]. Para o fluxo de trabalho seguro, veja [[03-fluxo-trabalho]].

---

## dbt

### `--profiles-dir` é relativo ao diretório atual

```bash
# Errado (executado da raiz do projeto)
.pipelines/bin/dbt run --profiles-dir dev

# Correto (executado de dentro de queries/)
cd queries/ && ../.pipelines/bin/dbt run --profiles-dir ../dev
```

### `dbt compile` não detecta erros de runtime

`dbt compile` valida apenas: sintaxe SQL, refs existentes, sources definidos.

**Não detecta**: coluna inexistente, type mismatch, policy tag IAM, erros de JOIN.

Esses erros só aparecem no `dbt run`. Fluxo correto:

```
compile → run → verificar dados no BigQuery
```

### Nunca usar `+` no seletor para `projeto_painel_ministro`

```bash
# PERIGOSO — re-materializa TODOS os modelos upstream
../.pipelines/bin/dbt run --select +painel_pdm_incentivo_estudante_completo

# CORRETO — executa apenas os modelos listados
../.pipelines/bin/dbt run --select painel_pdm_incentivo_estudante_completo
```

O prefixo `+` faz o dbt executar toda a cadeia de dependências. No `projeto_painel_ministro`,
isso inclui schemas de outros projetos. Re-criar essas tabelas **apaga policy tags IAM**,
que só podem ser restauradas pela equipe de engenharia. Veja [[02-arquitetura-projeto]] para a lista de policy tags do projeto. #dbt #policy-tags

### `generate_schema_name` ignora `--target`

A macro `generate_schema_name.sql` usa o `+schema` definido no `dbt_project.yml`.
Isso sobrescreve o dataset do target.

Na prática: trocar `--target` não muda o dataset de destino para modelos que têm
`+schema` configurado. Não existe isolamento por target neste projeto.

### `dbt ls` requer conexão BigQuery

Para listar modelos localmente sem conexão, usar:

```bash
find queries/models/ -name "*.sql" | sort
```

---

## BigQuery e Policy Tags

### Colunas com policy tags bloqueiam o run

Colunas como `sexo`, `cor_raca` em tabelas do ENEM têm policy tags (`media:genero`, `media:etnia`).

Se a service account não tiver permissão para ler essas colunas, o `dbt run` falha com:

```
Access Denied: BigQuery: No column-level permission to read column
```

**Solução**: excluir o modelo afetado do PR atual e abrir issue separada.

### Re-criar tabelas apaga policy tags

Ao executar `dbt run` para uma tabela que já tem policy tags, o dbt derruba a tabela
e recria do zero — as tags são perdidas.

Por isso a regra de **nunca usar `+`** no seletor. Executar apenas os modelos que você
realmente precisa alterar.

---

## Git e PRs

### Hook de pre-push bloqueia branches novas

Ao criar uma branch nova a partir de `develop` e tentar fazer o primeiro push,
o hook de pre-push pode bloquear com a mensagem:

```
[pre-push] BLOQUEADO: Commits com author email incorreto para contexto MEC
```

Isso acontece porque, para branches que ainda não existem no remoto, o hook
percorre **toda a história** do repositório (incluindo commits de outros autores).

**Solução**: o hook precisa usar `merge-base` como referência para branches novas,
verificando apenas os commits da feature branch — não toda a história do develop.

No trecho do hook que define o `RANGE`:

```bash
# Correção: usar merge-base para branches novas
if [[ "$REMOTE_SHA" == "0000000000000000000000000000000000000000" ]]; then
    MERGE_BASE=$(git merge-base origin/develop "$LOCAL_SHA" 2>/dev/null \
      || git merge-base origin/main "$LOCAL_SHA" 2>/dev/null || echo "")
    if [[ -n "$MERGE_BASE" ]]; then
        RANGE="$MERGE_BASE..$LOCAL_SHA"
    else
        RANGE="$LOCAL_SHA"
    fi
else
    RANGE="$REMOTE_SHA..$LOCAL_SHA"
fi
```

### PR para `main` é bloqueado pelo CI

O workflow `.github/workflows/main_protected.yaml` rejeita PRs para `main` que não venham de `develop`.

Fluxo obrigatório:

```
feature/xxx → PR → develop → PR → main
```

### Branch sem upstream

```bash
# Falha se a branch não tem upstream configurado
git rev-list --count @{u}..HEAD

# Seguro
git rev-list --count @{u}..HEAD 2>/dev/null || echo "0"
```

---

## Dados Específicos

### Tabelas do Censo Escolar — 3 fontes diferentes

O projeto tem 3 fontes de dados do Censo Escolar. **Usar sempre a mais recente**:

| Fonte | Schema | Status |
|-------|--------|--------|
| `censo_escolar_escola` | `educacao_inep_dados_abertos` | Legada — sem dados 2025 |
| `inep_censo_escolar_educacao_basica` | `educacao_inep_dados_abertos` | Intermediária — dados até 2024 |
| `inep_base_censo_escolar` | `indicador_politica_inep_base` | **Atual** — dados 2007-2025 |

A terceira fonte foi criada porque o Censo 2025 mudou nomes de variáveis em relação ao 2024.

### Indicadores booleanos podem ser NULL em anos novos

O campo `indicador_especial` está 100% NULL em 2025 na `inep_base_censo_escolar`.

```sql
-- Errado (retorna 0 em 2025)
WHERE indicador_especial = TRUE

-- Correto (funciona em todos os anos)
WHERE quantidade_matricula_especial > 0
```

**Regra geral**: ao migrar modelos para dados de um ano novo, verificar se os indicadores
booleanos estão preenchidos antes de usá-los em filtros.

### Nomenclaturas de colunas mudam entre fontes

Exemplo do Censo Escolar:

| censo_escolar_escola | inep_censo_escolar | inep_base_censo |
|---------------------|-------------------|----------------|
| `_branca` | `_cor_branca` | `_cor_branca` |
| `_especial` | `_educacao_especial` | `_especial` |
| `_educacao_fundamental_*` | `_ensino_fundamental_*` | `_ensino_fundamental_*` |

Sempre verificar a nomenclatura da fonte sendo utilizada.

---

## Prevenção

| Risco | Como evitar |
|-------|------------|
| Duplicação por novo edital | Incluir `sigla_edital` ou equivalente como chave de diferenciação |
| Soma incorreta entre editais | Usar campo de edital no JOIN e como filtro no dashboard |
| Policy tags destruídas | Nunca usar `+` no seletor dbt |
| Dados incorretos em ano novo | Verificar indicadores booleanos antes de usar em filtros |
| PR rejeitada pelo CI | Sempre apontar para `develop` |

---

## Navegação

| Documento | Descrição |
|-----------|-----------|
| [02 - Arquitetura do Projeto](02-arquitetura-projeto.md) | Estrutura do projeto e policy tags |
| [03 - Fluxo de Trabalho](03-fluxo-trabalho.md) | Git workflow seguro |
| [04 - Padrões de Código](04-padroes-codigo.md) | Standards que previnem esses erros |

[Voltar ao índice](onboarding.md)
