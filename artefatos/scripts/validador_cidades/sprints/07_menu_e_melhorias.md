# Sprint 7 - Menu Dinamico, UX e Melhorias

**Status:** NAO INICIADA
**Dependencia:** Sprint 6 (upstream) concluida
**Objetivo:** Menu interativo no terminal, correcao de bugs e melhorias de QoL.

## 7.1 Menu Dinamico (main.py)

### Fluxo principal

```
$ python validador.py

  Validador de Cidades v2
  =======================

  [1] Validar municipio
  [2] Validar estado (todos os municipios)
  [3] Ver ultimo resultado
  [4] Gerar template xlsx
  [5] Configuracoes
  [q] Sair

  > 1

  Municipio: Andradina - SP
  Ano [2025]:
  Incluir upstream? [S/n]:
  Formato: [xlsx / terminal / ambos]: ambos

  Executando 36 metricas...
  [========================================] 36/36

  Escolas .......................... 38     OK
  Matriculas ....................... 8.897  OK
  SISTEC .......................... NULL    PERDEU_NO_PAINEL
    fonte: sistec_ciclo_matricula = 6.593 registros
    acao: verificar JOIN em painel_ept_sistec.sql
  ...

  Resumo: 19 OK | 6 ZERO_LEGITIMO | 11 ZERO_SUSPEITO
  XLSX salvo: data/Projeto_Validador_Visao_Municipal.xlsx

  [d] Detalhar metrica
  [u] Ver upstream de um ZERO
  [e] Exportar diagnostico .md
  [r] Repetir outro municipio
  [q] Sair
```

### Sub-menus

**[d] Detalhar metrica**
```
  Qual metrica? (numero ou nome): 23

  SISTEC Matriculas
  Tabela: painel_ept_sistec
  GCP: br-mec-segape-dev.projeto_painel_ministro.painel_ept_sistec
  Filtro: CAST(id AS STRING) = '3502101' AND ano = 2025
  Registros: 0
  Valor: NULL

  Upstream:
    sistec_ciclo_matricula: 6.593 registros
    GCP: br-mec-segape-dev.educacao_politica_sistec.sistec_ciclo_matricula
    WHERE: CAST(id_municipio AS STRING) = '3502101'

  Diagnostico: PERDEU_NO_PAINEL
  O dado existe na fonte (6.593 registros de matriculas SISTEC)
  mas NAO aparece no painel. O JOIN entre filtro_territorio e
  sistec_ciclo_matricula provavelmente falhou para este municipio.

  Acao sugerida: Verificar painel_ept_sistec.sql, CTE qualificacao_profissional_publica

  [c] Copiar query pro clipboard
  [v] Voltar
```

**[2] Validar estado**
```
  Estado (sigla): SP
  Ano [2025]:

  Buscando municipios de SP... 645 encontrados.
  Executar para todos? Custo estimado: ~3.6 GB
  [s/N]: s

  Executando... (645 municipios x 36 metricas)
  [==============                          ] 187/645

  (ao final, gera relatorio consolidado por estado)
```

## 7.2 Bugs Identificados

| # | Severidade | Descricao | Correcao |
|---|-----------|-----------|----------|
| 1 | Media | Escolas Quilombolas classificado ZERO_SUSPEITO — Andradina nao tem quilombos, e zero real | Upstream corrigiu para VALOR_ZERADO (fonte tem dados, metrica=0). Diagnostico correto. |
| 2 | Baixa | FIES classificado ZERO_SUSPEITO — upstream confirma 0 na fonte. Deveria ser ZERO_LEGITIMO | Upstream ja corrigiu quando fonte=0 |
| 3 | Alta | PDMLIC: 2 inscricoes SISU na fonte, 0 no painel — dado PERDIDO no JOIN | Investigar filtro de ano/edital no painel_pdmlic.sql |
| 4 | Alta | SISTEC: 6.593 matriculas na fonte, 0 no painel — JOIN falhou | painel_ept_sistec usa nome_municipio. Se formato diferir, perde o municipio |
| 5 | Media | SISU: 567 vagas na fonte, 0 no painel — registros existem mas valor=0 | Possivel filtro de municipio vs municipio_campus |
| 6 | Media | SESU NovoPAC: 28 obras na fonte, 0 no painel — municipio nao encontrado | simec_obra usa 'municipio' (nome), filtro pode nao casar |
| 7 | Baixa | Selecoes: 3 linhas duplicadas para mesma obra ETI | MAX resolve, mas a duplicacao existe na tabela |
| 8 | Info | Docentes: 608 vs 519 — deduplicacao no Looker Studio | Documentado, nao e bug |

## 7.3 Melhorias Planejadas

### UX / Terminal
| # | Melhoria | Prioridade |
|---|----------|-----------|
| 1 | Progress bar com rich durante execucao | Alta |
| 2 | Cores consistentes (verde/vermelho/amarelo/cinza) | Alta |
| 3 | Resumo com recomendacao de acao no final | Media |
| 4 | Autocomplete de municipio (lista IBGE) | Baixa |
| 5 | Modo silencioso (--quiet) para scripts | Baixa |

### Performance / Custo
| # | Melhoria | Prioridade |
|---|----------|-----------|
| 6 | Cache de resultados (JSON com TTL 24h) | Alta |
| 7 | Protecao de custo com alerta ao atingir limite | Alta |
| 8 | Execucao paralela de queries (ThreadPoolExecutor) | Media |
| 9 | Dry-run com custo estimado POR tabela | Media |

### Funcionalidades
| # | Melhoria | Prioridade |
|---|----------|-----------|
| 10 | Filtro por estado (todos os municipios) | Alta |
| 11 | Comparacao temporal (2025 vs 2024) | Media |
| 12 | --json flag para integracao com ferramentas | Media |
| 13 | Modo batch (arquivo com lista de municipios) | Media |
| 14 | Exportar diagnostico como .md (markdown) | Baixa |

### Qualidade de Dados
| # | Melhoria | Prioridade |
|---|----------|-----------|
| 15 | Classificacao INCONCLUSIVO -> ZERO_CONFIRMADO quando fonte=0 e painel=0 | Alta |
| 16 | Deteccao automatica de CROSS JOIN (esqueletos) | Media |
| 17 | Validar se tabelas inativas ainda existem no BQ | Media |

## 7.4 Criterios de Aceite

- `python validador.py` sem argumentos abre menu interativo
- Menu permite navegar entre opcoes sem sair
- [d] mostra detalhes de qualquer metrica
- [u] mostra upstream de qualquer ZERO
- Progress bar visivel durante execucao
- Cache evita re-query no mesmo dia
- Cores consistentes em todo o terminal
- Funciona para qualquer municipio do Brasil
