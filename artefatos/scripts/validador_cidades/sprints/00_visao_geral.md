# Validador de Cidades - Visao Geral do Projeto

## Problema

O dashboard "Painel Estrategico - Territorial" (Looker Studio) exibe metricas por municipio.
Algumas cidades retornam 0 em metricas que antes tinham valor (ex: Andradina-SP).
Nao sabemos se o dado morreu no JOIN do dbt ou se nunca chegou ao data lake.

## Objetivo

Ferramenta Python automatizada que, dado um municipio:
1. Varre TODAS as tabelas do dashboard automaticamente
2. Identifica quais metricas retornam 0 ou NULL
3. Compara com valores do dashboard real
4. Para cada zero, rastreia a(s) tabela(s) fonte upstream (Sprint 6)
5. Diagnostica: dado ausente na fonte OU JOIN/filtro perdeu o dado
6. Gera xlsx com Input (metricas) e Output (resultados + diagnostico)

## Estado Atual

| Sprint | Titulo | Status |
|--------|--------|--------|
| 1 | Inventario e Mapeamento | CONCLUIDA |
| 2 | Scanner Automatico | CONCLUIDA (integrado no validador.py) |
| 3 | Rastreamento Upstream | Substituida pela Sprint 6 |
| 4 | Diagnostico Automatico | CONCLUIDA (integrado no validador.py) |
| 5 | CLI Interativo | PARCIAL (argparse funcional, rich para output) |
| 6 | Validacao Upstream | NAO INICIADA |

## Correcoes Criticas Descobertas (v2)

1. **Triplicacao por filtro_territorio**: tabelas com formato "cidade"/"CIDADE"
   geram 3 linhas por municipio (nivel mun/estado/brasil). Fix: filtrar por id IBGE.

2. **CNCA sem filtro de ano**: dashboard mostra acumulado, nao so 2025.

3. **FUNDEB filtro status**: precisa `status = 'Realizado'`.

4. **Salario Educacao filtro id_status**: precisa `id_status = 1`.

5. **NovoPAC deduplicacao**: usar COUNT(DISTINCT id_governa) ou COUNT(DISTINCT proposta).

6. **Selecoes duplicadas**: 3 linhas identicas para mesma obra. MAX resolve.

## Uso

```bash
cd ~/Desenvolvimento/MEC/validador_cidades
./install.sh
.venv/bin/python validador.py --municipio "Andradina - SP" --ano 2025
```

## Estrutura

```
validador_cidades/
  validador.py              <- CLI + metricas + execucao + xlsx
  executor_bq.py            <- cliente BigQuery
  config.py                 <- configuracao
  requirements.txt
  install.sh / uninstall.sh
  README.md
  data/
    Projeto_Validador_Visao_Municipal.xlsx  <- input/output
    diagnostico_*.md                        <- relatorios
    validador.log                           <- log de execucao
  contexto/                 <- guias do projeto dbt
  sprints/                  <- documentacao de sprints
  PDF_DASHBOARD/            <- screenshots do dashboard
```
