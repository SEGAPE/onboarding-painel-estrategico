# Sprint 3 - Rastreamento Upstream

**Status:** NAO INICIADA
**Dependencia:** Sprint 1 (linhagem.json) + Sprint 2 (scanner)
**Objetivo:** Para cada tabela com ZERO, verificar automaticamente se o dado existe nas fontes.

## Conceito

A pergunta central: "o dado morreu no JOIN do dbt ou nunca chegou ao data lake?"

```
FONTE (data lake/raw)  -->  dbt (JOIN/filtro)  -->  TABELA FINAL (dashboard)
        ?                       ?                        ZERO
```

Se a fonte tem dado e o final nao: problema no dbt (JOIN, filtro, cast).
Se a fonte tambem nao tem: problema na ingestao ou o dado realmente nao existe.

## Entregas

### 3.1 Parser de Linhagem Automatico
- [ ] Ler cada SQL em queries_originais/
- [ ] Extrair chamadas ref('modelo') e source('schema', 'tabela')
- [ ] Montar arvore de dependencias ate o nivel raw/source
- [ ] Salvar em linhagem.json automaticamente
- [ ] Identificar coluna de municipio equivalente em cada nivel

### 3.2 rastreador.py - Busca Upstream
- [ ] Recebe lista de tabelas com status ZERO do scanner
- [ ] Para cada uma, consulta linhagem.json para obter fontes
- [ ] Executa query na(s) fonte(s):
  ```sql
  SELECT COUNT(*) as total
  FROM `projeto.dataset.tabela_fonte`
  WHERE LOWER(coluna_municipio_fonte) LIKE '%andradina%'
  ```
- [ ] Se fonte tem multiplos niveis (raw -> indicador -> painel), verifica cada nivel
- [ ] Retorna resultado por nivel da cadeia

### 3.3 Saida do Rastreamento
```python
{
  "painel_pronatec_completo": {
    "final": {"total": 0, "status": "ZERO"},
    "upstream": [
      {
        "nivel": "educacao_politica",
        "tabela": "gaia_pronatec_vaga",
        "gcp": "br-mec-segape-dev.educacao_politica_gaia.gaia_pronatec_vaga",
        "total": 0,
        "status": "ZERO"
      },
      {
        "nivel": "raw",
        "tabela": "stg_gaia_pronatec_vaga",
        "gcp": "br-mec-segape-dev.raw_csv_gaia.stg_gaia_pronatec_vaga",
        "total": 0,
        "status": "ZERO"
      }
    ],
    "diagnostico": "DADO_AUSENTE_FONTE"
  },
  "painel_sisu": {
    "final": {"total": 0, "status": "ZERO"},
    "upstream": [
      {
        "nivel": "educacao_politica",
        "tabela": "sisu_vaga_ofertada",
        "gcp": "br-mec-segape-dev.educacao_politica_gaia.sisu_vaga_ofertada",
        "total": 12,
        "status": "OK"
      }
    ],
    "diagnostico": "JOIN_PERDEU_DADOS"
  }
}
```

## Desafios

- Coluna de municipio muda nome entre camadas (municipio, nome_municipio, id_municipio)
- Algumas fontes nao tem municipio direto (usam id_municipio numerico IBGE)
- Precisamos do id_municipio IBGE de Andradina (3501004) para queries em fontes com codigo
- Fontes particionadas por ano podem ter dados em anos diferentes

## Criterios de Aceite

- Para cada tabela ZERO, o rastreador identifica pelo menos 1 fonte upstream
- Query na fonte retorna contagem correta
- Diagnostico automatico: DADO_AUSENTE_FONTE ou JOIN_PERDEU_DADOS
- Tempo < 30s por tabela rastreada
