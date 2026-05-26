# Sprint 4 - Diagnostico Automatico e Relatorios

**Status:** NAO INICIADA
**Dependencia:** Sprint 3 (rastreamento)
**Objetivo:** Classificar causa raiz automaticamente e gerar relatorios exportaveis.

## Classificacoes de Diagnostico

| Codigo | Significado | Acao sugerida |
|--------|-------------|---------------|
| OK | Dados presentes na tabela final | Nenhuma |
| DADO_AUSENTE_FONTE | Zero em todas as camadas (raw ate final) | Verificar ingestao/pipeline Prefect |
| JOIN_PERDEU_DADOS | Fonte tem dados, final nao | Revisar JOINs e filtros no dbt |
| FILTRO_EXCLUIU | Dados existem mas filtro WHERE removeu | Revisar condicoes de filtro |
| CAST_QUEBROU | Dados existem mas conversao de tipo anulou | Verificar casts e coalesce |
| TABELA_INACESSIVEL | Erro ao consultar (permissao, tabela inexistente) | Verificar IAM/policy tags |
| DADOS_HISTORICOS | Dados existem em anos anteriores mas nao no atual | Verificar carga do ano corrente |

## Entregas

### 4.1 diagnostico.py - Motor de Classificacao
- [ ] Recebe resultados do scanner + rastreador
- [ ] Aplica regras de classificacao:
  - final=0, fonte=0 -> DADO_AUSENTE_FONTE
  - final=0, fonte>0 -> JOIN_PERDEU_DADOS
  - final=0, fonte_ano_anterior>0, fonte_ano_atual=0 -> DADOS_HISTORICOS
  - final=erro -> TABELA_INACESSIVEL
- [ ] Para JOIN_PERDEU_DADOS, sugere ponto de investigacao (qual CTE verificar)
- [ ] Gera resumo executivo

### 4.2 relatorio.py - Exportacao
- [ ] Saida terminal formatada (cores, tabela alinhada via rich)
- [ ] Exporta CSV com resultados completos
- [ ] Exporta JSON para integracao com outras ferramentas
- [ ] Historico: salva cada execucao em resultados/ com timestamp

### 4.3 Formato do Relatorio Terminal
```
=== VALIDACAO: Andradina - SP ===
Data: 2026-04-06 | Projeto: br-mec-segape-dev
Tabelas escaneadas: 24 | Com dados: 15 | Zeros: 7 | Erros: 2
Custo estimado: 45 MB processados

TABELAS COM DADOS (15):
  painel_escola ................. 38 registros
  painel_matricula_municipio .... 12 registros
  painel_fundeb ................. 48 registros
  ...

ZEROS DIAGNOSTICADOS (7):
  painel_pronatec_completo ...... DADO AUSENTE NA FONTE
    fonte: gaia_pronatec_vaga = 0 registros
    acao: verificar pipeline Prefect de ingestao GAIA

  painel_sisu ................... JOIN PERDEU DADOS
    fonte: sisu_vaga_ofertada = 12 registros
    acao: revisar CTE 'politica' em painel_sisu.sql (linha ~85)

  painel_universidades_graduacao  TABELA INACESSIVEL
    erro: Not found: Table projeto_painel_ministro.painel_universidades_graduacao
    acao: modelo removido do dbt - tabela nao existe mais no BQ

ERROS (2):
  painel_pnp_situacao_matricula . SEM COLUNA MUNICIPIO
    nota: tabela nao tem filtro geografico direto
```

### 4.4 Comparacao Temporal
- [ ] Para tabelas com coluna de ano, verificar ano atual vs. anterior
- [ ] Se ano anterior tinha dados e atual nao: flag DADOS_HISTORICOS
- [ ] Util para identificar se a ingestao do ano corrente ainda nao rodou

## Criterios de Aceite

- Cada tabela ZERO recebe uma classificacao automatica
- Relatorio terminal e legivel e colorido
- CSV exportado contem todos os campos necessarios para analise
- Historico de execucoes preservado em resultados/
