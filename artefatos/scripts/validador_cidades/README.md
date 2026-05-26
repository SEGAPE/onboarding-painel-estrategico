# Validador de Cidades

Ferramenta de diagnostico automatico para o dashboard "Painel Estrategico - Territorial" (Looker Studio).

Dado um municipio, varre todas as tabelas do dashboard no BigQuery, identifica metricas zeradas e diagnostica a causa: dado ausente na fonte ou problema no JOIN/filtro do dbt.

## Requisitos

- Python 3.10+
- Acesso ao projeto BigQuery `br-mec-segape-dev`
- Arquivo de credenciais da service account (keyfile JSON)

## Instalacao

```bash
chmod +x install.sh
./install.sh
```

## Uso

```bash
# Validacao completa de um municipio
.venv/bin/python main.py --municipio "Andradina - SP"

# Com ano especifico
.venv/bin/python main.py --municipio "Andradina - SP" --ano 2025

# Com verificacao upstream (identifica onde o dado se perdeu)
.venv/bin/python main.py --municipio "Andradina - SP" --upstream

# Completo: ano + upstream
.venv/bin/python main.py --municipio "Andradina - SP" --ano 2025 --upstream

# Estimar custo sem executar
.venv/bin/python main.py --municipio "Andradina - SP" --dry-run

# Gerar template xlsx sem executar queries
.venv/bin/python main.py --gerar-template

# Saida em arquivo especifico
.venv/bin/python main.py --municipio "Andradina - SP" -o resultado.xlsx
```

## Saida

O script gera um arquivo `.xlsx` com duas abas:

- **Input**: metricas mapeadas (pagina do dashboard, tabela BQ, expressao SQL)
- **Output**: resultado da validacao (valor retornado, status, diagnostico, upstream)

### Status possiveis

| Status | Significado |
|--------|-------------|
| OK | Dados presentes e com valor > 0 |
| ZERO_LEGITIMO | Zero confirmado na fonte (municipio nao participa do programa) |
| ZERO_SUSPEITO | Dado existe na fonte mas sumiu no painel (possivel bug) |
| AUSENTE | Municipio nao encontrado na tabela |
| NULL | Metrica retornou NULL |
| ERRO | Erro na execucao da query |

### Colunas upstream (com flag --upstream)

| Coluna | Significado |
|--------|-------------|
| fonte_upstream | Tabelas fonte consultadas e contagens |
| registros_upstream | Total de registros nas fontes |
| diagnostico_upstream | ZERO_CONFIRMADO_FONTE / PERDEU_NO_PAINEL / VALOR_ZERADO |
| camada_falha | Onde o dado se perdeu (nenhuma / painel / politica) |

## Configuracao

Editar `config.py`:

- `PROJETO_BQ`: projeto BigQuery (padrao: `br-mec-segape-dev`)
- `KEYFILE`: caminho do arquivo de credenciais
- `ANO_PADRAO`: ano para filtro (padrao: 2025)
- `LIMITE_BYTES_SESSAO`: limite de custo por sessao (padrao: 500 MB)

## Estrutura

```
validador_cidades/
  main.py               # Ponto de entrada (CLI)
  validador.py           # Core: queries, execucao, classificacao
  executor_bq.py         # Cliente BigQuery
  metricas.py            # Definicao das metricas do dashboard
  linhagem.py            # Mapeamento upstream (fontes de dados)
  relatorio.py           # Geracao de xlsx e output terminal
  config.py              # Configuracao
  requirements.txt       # Dependencias (versoes pinadas)
  install.sh             # Instalacao do venv
  uninstall.sh           # Remocao do venv
  .gitignore
  data/                  # Logs, xlsx e relatorios gerados
  contexto/              # Guias do projeto dbt (referencia)
  sprints/               # Documentacao de sprints
  PDF_DASHBOARD/         # Screenshots do dashboard (referencia)
```

## Desinstalacao

```bash
./uninstall.sh
```
