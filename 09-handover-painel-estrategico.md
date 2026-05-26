# Handover - Painel Estratégico

Este documento reúne o trabalho que desenvolvi no Painel Estratégico, para apoiar a
continuidade e a migração das tabelas para PROD. Organizei por: branches/PRs, tabelas
criadas no sandbox `andre_teste`, o que cada coisa faz, onde estão as queries para recriar
e as ferramentas de apoio. As queries e scripts estão na pasta `artefatos/`.

## 1. O que precisa de atenção primeiro (PROD)

- **`br-mec-segape-dev.andre_teste.eti`** - a dashboard de produção aponta para essa tabela.
  Foi criada manualmente a partir de um CSV gerado de um PDF do edital. Já existe a
  equivalente oficial `br-mec-segape-dev.projeto_gaia.gaia_peti_fundeb`, mas com dados
  desatualizados. Precisa formalizar essa versão e tirar a dashboard do schema pessoal.
- **PNEERQ e Obras** foram criadas com `CREATE OR REPLACE TABLE` direto em
  `projeto_painel_ministro` (schema de produção), sem modelo dbt. As queries estão em
  `artefatos/sql/`. Ideal virar modelo dbt no DBT do painel.
- **Orçamento (PRs #959/#956)** ficaram fechadas sem merge - as versões finais foram
  desenvolvidas pelo Nicholas. Confirmar o que está no `develop`/PROD antes de subir.

## 2. Branches e PRs (SEGAPE/pipelines)

| PR | Estado | Branch | Tema |
|---|---|---|---|
| #1158 | aberta | feature/briefing_visita_ministerial_eb | Briefing Visita Ministerial - Ed. Básica |
| #1133 | aberta | feature/painel_universidades_graduacao_censo_superior | Universidades graduação (Censo Superior) |
| #1112 | aberta | feature/painel_novopac_indigena | Novo PAC indígena + base monitoramento |
| #1111 | fechada | feature/painel_pdmlic_fies | PDMLIC editais + FIES (substitui a #1046) |
| #1089 | merged | feature/mudanca_tabela_inep_censo_educacao_basica_v2 | Migração censo escolar (painel) |
| #1046 | fechada | feature/painel_pdm_lic | PDMLIC diferenciação por edital |
| #959 | fechada | feature/painel_orcamento_universidade_federal | Orçamento universidades federais |
| #956 | fechada | feature/painel_orcamento_universidade_federal | Orçamento (versão anterior) |
| #955 | fechada | feature/mudanca_tabela_inep_censo_educacao_basica | Migração censo (9 modelos) |
| #954 | fechada | feature/mudanca_tabela_inep_censo_educacao_basica | Migração censo (10 modelos) |
| #727 | fechada | feature/painel-matriculas | Painéis de matrícula (anual, integral, município) |
| #688 | fechada | feature/criacao-tabela-painel-mais-profs | Painel Mais Professores |
| #590 | fechada | feature/novo-painel-pneerq-infraestrutura | PNEERQ infraestrutura |
| #584 | merged | feature/painel-pneerq-quilombolas | PNEERQ infraestrutura escola |

## 3. Tabelas criadas no `andre_teste`

`br-mec-segape-dev.andre_teste` - 22 tabelas, ~530 MB. As que importam para PROD:

| Tabela | Linhas | O que é | Destino sugerido |
|---|---|---|---|
| eti | 4.138 | ETI/FUNDEB que a dashboard usa em PROD | projeto_gaia.gaia_peti_fundeb |
| eti_valores_2025_csv | 49.608 | ETI valores 2025 com expansão territorial | idem (insumo) |
| painel_peti_ano | 33.516 | PETI/FUNDEB por ano | gaia/pdm |
| tesouro_orcamento_unidade_orcamentaria | 218.623 | Orçamento V2 (crédito originário) - testes com o Bento | educacao_politica_tesouro |
| tesouro_destaque_recebido_instituicao | 201.956 | Orçamento V2 (TEDs/destaques) - testes | educacao_politica_tesouro |
| tesouro_orcamento_destaque_recebido_instituicao | 201.956 | Versão consolidada dos destaques | educacao_politica_tesouro |
| fnde_obras_selecoes_raw | 34.469 | xlsx FNDE p/ sandbox Novo PAC indígena | source oficial Novo PAC |
| pdde_consolidado | 24.024 | PDDE consolidado | educacao_politica_pdde |
| painel_novopac_selecoes | 13.716 | Sandbox seleções Novo PAC | projeto_painel_ministro |
| partiu_if_* (questionario, oferta, valores, tratado) | até 45.394 | Partiu IF (SECADI) - testes | a definir |

As de obras (TRD, complexo_alemao_obras, todas_abas_empilhadas, etc.) podem ser descartadas -
eram base de Excel para um problema pontual de urgência.

## 4. O que cada trabalho faz

- **Briefing Visita Ministerial (EB)** - consolida as métricas do mock-up oficial do briefing
  (Escolas Conectadas, ETI, CNCA, Pé-de-Meia, Distorção) numa tabela long triplicada
  (município/estado/Brasil). 3 valores de Brasil são hardcode oficial; o resto é calculado.
  Modelo: `briefing_visita_ministerial_eb`. PR #1158.
- **Universidades graduação** - formaliza no dbt o painel ES09 (Universidades Federais).
  Troquei a fonte DIFES/SESu 2023 pelo Censo da Educação Superior (série 2009-2024, 122 federais).
  Antes só existia como tabela manual no BigQuery. PR #1133.
- **Novo PAC indígena** - adiciona Escolas Indígenas como 4ª categoria em
  `painel_novopac_selecoes` e cria `painel_novopac_base_monitoramento` (base manual FNDE).
  Tem um sandbox em `andre_teste` que reproduz os números do painel FNDE V2.7. PR #1112.
- **PDMLIC editais + FIES** - separa os editais (PDML-2025/2026) para não somar errado os
  big numbers e inclui o FIES como fonte de elegibilidade. PR #1111.
- **Migração censo escolar** - troca da fonte `censo_escolar_escola` (legada) por
  `inep_censo_escolar_educacao_basica` em vários modelos do painel. PR #1089 (merged), #955, #954.
- **Orçamento universidades federais** - 4 modelos a partir do Tesouro Gerencial V2
  (`painel_orcamento_base`, `painel_orcamento_universidade_federal`, `painel_credito_recebido`,
  `painel_assistencia_estudantil`). Unifica crédito originário + descentralizado, inclui hospitais
  (EBSERH) e remove double-counting. Carga via [etl-tesouro-orcamento](https://github.com/SEGAPE/etl-tesouro-orcamento).
  As versões finais foram concluídas pelo Nicholas. PRs #959/#956.
- **PNEERQ** - 3 tabelas de infraestrutura escolar (geral, censo, quilombolas) a partir do
  Censo Escolar, com índice de infraestrutura elementar (água/esgoto/energia/internet/prédio)
  e recortes raciais. Criadas via `CREATE OR REPLACE` direto em `projeto_painel_ministro`.
- **Obras Prioritárias** - painéis de UNILA, UNIFESP, Tiradentes e Complexo do Alemão. Bases
  vieram de Excel (`obras_bq_raw.xlsx`) carregado como CSV. Tabelas: `painel_obras_geral`,
  `painel_obras_localizacao`, `painel_novopac_unila`, `painel_novopac_unifesp`.
- **Mais Professores (Pé-de-Meia Licenciaturas)** - duas tabelas finais:
  `pnd_adesao_territorio_completo` (adesão à Prova Nacional Docente) e
  `painel_licenciatura_visao_completa` (bolsistas, investimento, curso, turno, IES). As tabelas
  `bolsista_pdmlic_completo` e `pdmlic_elegibilidade_sisu_prouni_territorio` são insumo.
  Pendência: bloco "Bolsa Mais Professores" (vagas previstas/valor estimado) ainda sem fonte.
- **Partiu IF (SECADI)** - questionário, oferta e valores do programa, em `andre_teste` (testes).
- **ETI** - tabela de Educação em Tempo Integral 2025 com valores de fomento, matrículas FUNDEB
  e repasses mensais, expandida por município/estado/Brasil.

## 5. Onde estão as queries para recriar

Tudo em `artefatos/sql/`:

- ETI: `artefatos/sql/eti_valores_2025_v6.sql` (gera `andre_teste.eti_valores_2025_csv`)
- PNEERQ: `artefatos/sql/pneerq_bases_em_uso.md` (3 CREATE OR REPLACE) e `pneerq_censo_escolar.md`
- Obras: `artefatos/sql/obras_bases_em_uso.md`, `obras_painel_geral.md`, `obras_novopac_unila.md`, `obras_novopac_unifesp.md`
- Mais Professores: `artefatos/sql/mais_professores/`
- Partiu IF: `artefatos/sql/partiu_if_querys.md`
- Orçamento: `artefatos/sql/orcamento/`
- Briefing: `artefatos/sql/briefing_query.sql` e `briefing_consulta_documentada.sql`
- Modelos já no repo SEGAPE/pipelines: `queries/models/projeto_painel_ministro/`

## 6. Ferramentas (cada uma com repositório próprio na SEGAPE)

- **[extrator-documentos-tabelas](https://github.com/SEGAPE/extrator-documentos-tabelas)** -
  extrai tabelas de PDF/DOCX (tabula-py, unstructured e pdfplumber com empilhamento de páginas).
  Usado para transformar PDFs (edital ETI, obras) em planilha antes de subir para o BigQuery.
- **[territorial-guard](https://github.com/SEGAPE/territorial-guard)** - diagnóstico das
  métricas do painel por município; diz se um zero é real ou bug no pipeline (rastreia a
  linhagem até a fonte e controla o custo das consultas).
- **[etl-tesouro-orcamento](https://github.com/SEGAPE/etl-tesouro-orcamento)** - carga dos
  TXT do Tesouro Gerencial para o BigQuery (orçamento das universidades e institutos federais).
- **[painel-etl-acompanhamento](https://github.com/SEGAPE/painel-etl-acompanhamento)** - carga
  da planilha de acompanhamento do painel (status das páginas) para o BigQuery.
- **[imagens_ux_ui](https://github.com/SEGAPE/imagens_ux_ui)** - gerenciador de imagens/logos
  para o Looker Studio (publica no CDN e gera a fórmula CASE/WHEN com as URLs).

## 7. Pendências conhecidas

- Bloco "Bolsa Mais Professores" sem fonte de vagas previstas/valor estimado.
- Briefing: M02/M03 usam só `gaia_peti` 2023/2024; o valor Brasil do ETI é hardcode oficial.
- PRs de orçamento fechadas sem merge - confirmar o que está no develop.

## 8. Links

Pull Requests e branches em `https://github.com/SEGAPE/pipelines` (lista completa de PRs:
#1158, #1133, #1112, #1111, #1089, #1046, #959, #956, #955, #954, #727, #688, #590, #584).
