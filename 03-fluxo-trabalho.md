---
titulo: "Fluxo de Trabalho com Git"
aliases:
  - "fluxo"
  - "workflow"
  - "git-flow"
tags:
  - git
  - dbt
  - workflow
data_criacao: "2026-01-01"
data_modificacao: "2026-04-08"
---

# Guia 03 — Fluxo de Trabalho

## Fluxo de Branches

```
feature/xxx  ──PR──>  develop  ──PR──>  main
```

- Toda feature branch nasce de `develop`.
- PRs sempre apontam para `develop`, **nunca para `main`**.
- O CI rejeita automaticamente PRs que apontem direto para `main`.

---

## Passo a Passo Obrigatório

### 1. Abrir o projeto

```bash
cd ~/Desenvolvimento/MEC/pipelines-main
```

### 2. Sincronizar com o remoto

```bash
git fetch origin
git pull --rebase
```

### 3. Criar branch de trabalho

```bash
git checkout origin/develop -b feature/nome-descritivo
```

Convenções de nome:
- `feature/nome` — funcionalidade nova
- `fix/nome` — correção de bug
- `refactor/nome` — refatoração sem mudança funcional

### 4. Fazer alterações

Editar os modelos SQL e arquivos YAML necessários em `queries/models/`.

### 5. Executar dbt run (validar no BigQuery)

```bash
cd queries/ && ../.pipelines/bin/dbt run --profiles-dir ../dev --select modelo_a modelo_b
```

**Regra crítica**: listar os modelos explicitamente com `--select`. **Nunca** usar o prefixo `+` no seletor para modelos de `projeto_painel_ministro` -- isso re-materializa todos os modelos upstream e pode destruir policy tags IAM. Veja [[05-armadilhas]] para detalhes. #dbt #armadilha

### 6. Verificar dados no BigQuery

Executar queries de validação para confirmar que os dados estão corretos:

```bash
export PATH="$HOME/google-cloud-sdk/bin:$PATH"
bq query --project_id=br-mec-segape-dev --use_legacy_sql=false \
  "SELECT COUNT(*) FROM \`br-mec-segape-dev.schema.tabela\`"
```

### 7. Executar pre-commit (hooks instalados no [[01-setup-ambiente|setup]])

```bash
pre-commit run --all-files
```

Corrigir qualquer problema reportado antes de prosseguir.

### 8. Commitar

**Importante**: adicionar apenas os arquivos do escopo da mudança. Nunca `git add .` ou `git add -A`.

```bash
# Correto — arquivos específicos
git add queries/models/pasta/arquivo.sql queries/models/pasta/schema.yml

# Errado — adiciona tudo, incluindo arquivos fora do escopo
git add .
```

Uma PR de código (SQL/schema) **não deve incluir** documentação, guias ou arquivos de outros contextos.
Se precisar de uma PR de documentação, crie uma branch separada.

```bash
git commit -m "feat: descrição imperativa da mudança"
```

Regras de commit (detalhes em [[04-padroes-codigo]]):
- Mensagem em **PT-BR** com acentuação correta
- Formato: `tipo: descrição imperativa`
- Tipos: `feat`, `fix`, `refactor`, `docs`, `test`, `perf`, `chore`
- **Sem emojis**
- Exemplos corretos:
  - `feat: adiciona diferenciação por edital no PDMLIC`
  - `fix: corrige acentuação nos modelos de orçamento`
  - `refactor: unifica crédito originário e descentralizado`

### 9. Push

```bash
git push -u origin feature/nome-descritivo
```

### 10. Abrir PR

Criar PR no GitHub apontando para `develop`:

```bash
gh pr create --base develop --title "feat: descrição" --body "Resumo das mudanças"
```

---

## Ordem Obrigatória

A sequência importa:

```
alterações → dbt run → verificação BigQuery → pre-commit → commit → push → PR
```

| Etapa | Por quê nesta ordem |
|-------|-------------------|
| dbt run **antes** do pre-commit | Validar dados antes de se preocupar com formatação |
| pre-commit **antes** do commit | Garantir que o código passa no linting |
| `git add` **específico** | Só os arquivos do escopo — nunca `git add .` |
| PR para `develop` | CI bloqueia PRs para `main` que não venham de `develop` |

---

## Escopo de PRs

Cada PR deve ter um escopo bem definido. Não misturar mudanças de naturezas diferentes.

| Tipo | O que incluir | O que NÃO incluir |
|------|--------------|-------------------|
| PR de código (SQL/schema) | Modelos alterados + schema.yml | Documentação, guias, scripts |
| PR de documentação | Guias, README, contexto | Mudanças em SQL |
| PR de infraestrutura | CI/CD, hooks, configs | Modelos de dados |

Se durante uma feature você perceber que precisa documentar algo, faça em uma branch/PR separada.
Misturar escopos dificulta a revisão e pode atrasar a aprovação. Veja [[06-cultura-desenvolvimento]] para mais sobre escopo atômico.

---

## Verificação de Identidade

Antes de commitar, confirmar que a identidade git está correta:

```bash
git config user.name   # Deve mostrar seu usuário GitHub MEC
git config user.email  # Deve mostrar seu email @mec.gov.br
gh auth status         # Deve mostrar a conta MEC ativa
```

---

## Comandos dbt Essenciais

Todos executados de dentro de `queries/`:

```bash
# Compilar (valida SQL sem executar)
../.pipelines/bin/dbt compile --profiles-dir ../dev

# Rodar modelos específicos
../.pipelines/bin/dbt run --profiles-dir ../dev --select modelo_a modelo_b

# Build completo (run + test)
../.pipelines/bin/dbt build --profiles-dir ../dev

# Testes de qualidade
../.pipelines/bin/dbt test --profiles-dir ../dev

# Listar modelos (requer conexão BigQuery)
../.pipelines/bin/dbt ls --profiles-dir ../dev
```

---

## Navegação

| Documento | Descrição |
|-----------|-----------|
| [01 - Setup do Ambiente](01-setup-ambiente.md) | Configuração do ambiente local |
| [04 - Padrões de Código](04-padroes-codigo.md) | Standards de SQL, schema.yml, commits |
| [05 - Armadilhas](05-armadilhas.md) | Erros conhecidos e como evitá-los |
| [06 - Cultura](06-cultura-desenvolvimento.md) | Princípios e práticas da equipe |

[Voltar ao índice](onboarding.md)
