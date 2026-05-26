# Sprint 2 - Scanner Automatico

**Status:** NAO INICIADA
**Dependencia:** Sprint 1 concluida
**Objetivo:** Dado um municipio, varrer automaticamente todas as tabelas e identificar zeros.

## Fluxo de Input

O usuario preenche no inventario.csv:
- `coluna_metrica`: nome do campo no BigQuery a validar (ex: quantidade_escola, repasse, qtd_vagas_ofertadas)
- `nome_metrica`: nome legivel da metrica (ex: "Escolas", "Valor FUNDEB", "Vagas SISU")

O scanner le o CSV e para cada tabela com coluna_metrica preenchida, executa a validacao automatica.
Tabelas sem coluna_metrica preenchida: o scanner faz apenas COUNT(*) como verificacao basica.

## Entregas

### 2.1 executor_bq.py - Cliente BigQuery
- [ ] Conexao via service account (keyfile configuravel)
- [ ] Metodo query() com timeout e retry
- [ ] Metodo dry_run() para estimar bytes antes de executar
- [ ] Cache local de resultados (evita re-scan no mesmo dia)
- [ ] Logging de custo acumulado por sessao

### 2.2 scanner.py - Varredura Automatica
- [ ] Le inventario.csv para obter lista de tabelas e metricas
- [ ] Para cada tabela COM coluna_metrica preenchida, gera query otimizada:
  ```sql
  SELECT
    COUNT(*) as total_registros,
    SUM(CASE WHEN coluna_metrica IS NOT NULL AND coluna_metrica > 0 THEN 1 ELSE 0 END) as com_valor,
    SUM(COALESCE(coluna_metrica, 0)) as soma_metrica
  FROM `projeto.dataset.tabela`
  WHERE LOWER(coluna_municipio) LIKE '%andradina%'
    AND coluna_ano = 2025  -- se aplicavel
  ```
- [ ] Para tabelas SEM coluna_metrica, faz apenas:
  ```sql
  SELECT COUNT(*) as total_registros
  FROM `projeto.dataset.tabela`
  WHERE LOWER(coluna_municipio) LIKE '%andradina%'
  ```
- [ ] Executa em paralelo (ThreadPoolExecutor, max 5 conexoes)
- [ ] Classifica resultado: OK (>0), ZERO (=0), ERRO (query falhou)
- [ ] Retorna lista estruturada de resultados

### 2.3 config.py - Configuracao
- [ ] Projeto BQ padrao: br-mec-segape-dev
- [ ] Caminho keyfile
- [ ] Limite de bytes por query (protetor de custo)
- [ ] Timeout padrao
- [ ] Diretorio de cache e resultados

### 2.4 Saida do Scanner
Formato de retorno:
```python
[
  {
    "tabela": "painel_escola",
    "total_registros": 38,
    "status": "OK",
    "bytes_processados": 1024,
    "tempo_ms": 450
  },
  {
    "tabela": "painel_pronatec_completo",
    "total_registros": 0,
    "status": "ZERO",
    "bytes_processados": 2048,
    "tempo_ms": 380
  }
]
```

## Otimizacao de Custo

- COUNT(*) com WHERE e sempre melhor que SELECT *
- Usar LIMIT 1 quando so precisa saber se existe (mais barato)
- Filtrar por particao (ano) reduz bytes escaneados drasticamente
- Cache: nao re-escanear tabela que ja foi verificada no mesmo dia
- Limite global: abortar se custo acumulado ultrapassar threshold

## Criterios de Aceite

- `python scanner.py --municipio "Andradina - SP"` retorna status de todas as 24 tabelas
- Tabelas com dados mostram contagem
- Tabelas sem dados mostram ZERO
- Tabelas inacessiveis mostram ERRO com mensagem
- Custo total da varredura < 100MB processados
- Tempo total < 60 segundos
