## Ordem de leitura recomendada

### Fase 1: Preparação

1. [[01-setup-ambiente]] -- Configure seu ambiente local (Python, dbt, BigQuery, Git)
2. [[08-plugins-navegador]] -- Instale os plugins de navegador usados pela equipe

### Fase 2: Entendimento

3. [[02-arquitetura-projeto]] -- Entenda a estrutura do projeto, camadas de dados e fontes
4. [[03-fluxo-trabalho]] -- Aprenda o fluxo de trabalho com Git, branches e PRs

### Fase 3: Padrões

5. [[04-padroes-codigo]] -- Conheça os padrões de código e revisão exigidos
6. [[07-erros-comuns-review]] -- Evite os erros mais flagrados em code reviews
7. [[05-armadilhas]] -- Armadilhas que já causaram problemas reais em produção

### Fase 4: Cultura

8. [[06-cultura-desenvolvimento]] -- Princípios e cultura da equipe SEGAPE

### Referência (consulte quando precisar)

Os guias de joins são templates SQL para integrar dados territoriais em dashboards Looker. Consulte quando precisar criar ou modificar painéis com filtros de estado e município.

- [[Guia_01_coordenadas_instituicoes]] -- Como adicionar latitude/longitude a tabelas
- [[Guia_02_expansao_filtro_territorio]] -- Expansão territorial com `filtro_territorio`
- [[Guia_03_expansao_municipio_ibge]] -- Expansão territorial com municípios IBGE

---

## Navegação completa (GitHub)

| # | Documento | Descrição |
|---|-----------|-----------|
| 1 | [01 - Setup do Ambiente](01-setup-ambiente.md) | Configuração do ambiente local |
| 2 | [02 - Arquitetura do Projeto](02-arquitetura-projeto.md) | Estrutura do projeto dbt e camadas de dados |
| 3 | [03 - Fluxo de Trabalho](03-fluxo-trabalho.md) | Git workflow, branches e PRs |
| 4 | [04 - Padrões de Código](04-padroes-codigo.md) | Standards de SQL, schema.yml, commits |
| 5 | [05 - Armadilhas](05-armadilhas.md) | Erros conhecidos e como evitá-los |
| 6 | [06 - Cultura de Desenvolvimento](06-cultura-desenvolvimento.md) | Princípios e práticas da equipe |
| 7 | [07 - Erros Comuns em Review](07-erros-comuns-review.md) | Padrões de erro flagrados em PRs |
| 8 | [08 - Plugins de Navegador](08-plugins-navegador.md) | Extensões recomendadas |

### Guias de Joins (Referência SQL)

| Guia | Descrição |
|------|-----------|
| [Guia 01 - Coordenadas](Guia_Dos_Joins/Guia_01_coordenadas_instituicoes.md) | Integrar lat/long via tabela PNP |
| [Guia 02 - Expansão com filtro_territorio](Guia_Dos_Joins/Guia_02_expansao_filtro_territorio.md) | Triplicação territorial para Looker |
| [Guia 03 - Expansão com município IBGE](Guia_Dos_Joins/Guia_03_expansao_municipio_ibge.md) | Triplicação territorial com centroide IBGE |

### Handover do Painel Estratégico

Documentação do trabalho desenvolvido no Painel Estratégico, para apoiar a continuidade e a
migração das tabelas para PROD.

| Documento | Descrição |
|-----------|-----------|
| [09 - Handover do Painel Estratégico](09-handover-painel-estrategico.md) | Branches/PRs, tabelas do sandbox, o que cada coisa faz, pendências |
| [artefatos/sql/](artefatos/sql/) | Queries `CREATE OR REPLACE` por tema (ETI, PNEERQ, Obras, Mais Professores, Partiu IF, Briefing, Orçamento) |
| [artefatos/planilhas/](artefatos/planilhas/) | Mapa do Projeto Painel Estratégico (planilha-mestra de navegação do painel) |
| [artefatos/pdfs/](artefatos/pdfs/) | PDFs de referência (tutorial de tratamento de dados, dashboard de ETI) |

### Ferramentas (repositórios próprios na SEGAPE)

| Repositório | O que é |
|---|---|
| [extrator-documentos-tabelas](https://github.com/SEGAPE/extrator-documentos-tabelas) | Extrai tabelas de PDF/DOCX (tabula, unstructured, pdfplumber) |
| [territorial-guard](https://github.com/SEGAPE/territorial-guard) | Diagnostica métricas zeradas por município e rastreia a linhagem |
| [etl-tesouro-orcamento](https://github.com/SEGAPE/etl-tesouro-orcamento) | ETL dos TXT do Tesouro Gerencial para o BigQuery |
| [painel-etl-acompanhamento](https://github.com/SEGAPE/painel-etl-acompanhamento) | Carga da planilha de acompanhamento do painel para o BigQuery |
| [imagens_ux_ui](https://github.com/SEGAPE/imagens_ux_ui) | Gerencia imagens/logos do Looker (CDN + fórmula CASE/WHEN) |
