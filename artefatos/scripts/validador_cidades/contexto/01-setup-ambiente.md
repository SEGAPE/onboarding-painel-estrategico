# Guia 01 — Configuração do Ambiente Local

## Requisitos

- Python 3.10
- Google Cloud SDK (`gcloud`, `bq`)
- Git com SSH configurado para `github.com`
- Acesso ao projeto BigQuery `br-mec-segape-dev`

---

## Setup Inicial (9 passos)

### 1. Clonar o repositório

```bash
git clone git@github.com:SEGAPE/pipelines.git pipelines-main
cd pipelines-main
```

### 2. Criar o ambiente virtual

```bash
python3.10 -m venv .pipelines
```

### 3. Ativar o ambiente

```bash
source .pipelines/bin/activate
```

### 4. Instalar dependências

```bash
pip install -r requirements.txt
```

### 5. Instalar pre-commit hooks

```bash
pre-commit install
```

### 6. Configurar credenciais BigQuery

```bash
cp dev/profiles-example.yml dev/profiles.yml
```

Editar `dev/profiles.yml` e preencher:
- `keyfile`: caminho para o arquivo JSON da service account
- `project`: `br-mec-segape-dev`
- `dataset`: `dbt`

### 7. Configurar identidade git

```bash
git config --local user.name "seu-usuario-github"
git config --local user.email "seu-email@mec.gov.br"
```

### 8. Verificar o ambiente

```bash
cd queries/ && ../.pipelines/bin/dbt compile --profiles-dir ../dev
```

Se compilar sem erros, o ambiente está pronto.

### 9. Testar com um modelo simples

```bash
../.pipelines/bin/dbt run --profiles-dir ../dev --select filtro_territorio
```

---

## Comando Padrão

Todos os comandos dbt devem ser executados **de dentro da pasta `queries/`**:

```bash
cd queries/ && ../.pipelines/bin/dbt run --profiles-dir ../dev --select modelo_a modelo_b
```

**Nunca** usar o `dbt` global do sistema — ele não tem o adaptador BigQuery.
O binário correto é `.pipelines/bin/dbt`.

---

## BigQuery CLI (opcional)

Para consultas diretas no BigQuery:

```bash
export PATH="$HOME/google-cloud-sdk/bin:$PATH"
bq query --project_id=br-mec-segape-dev --use_legacy_sql=false "SELECT 1"
```

---

## Verificação Final

| Item | Comando | Resultado esperado |
|------|---------|-------------------|
| dbt compile | `../.pipelines/bin/dbt compile --profiles-dir ../dev` | Exit 0 |
| Identidade git | `git config --local user.email` | Seu email MEC |
| BigQuery | `bq query --project_id=br-mec-segape-dev --use_legacy_sql=false "SELECT 1"` | Retorna 1 |
