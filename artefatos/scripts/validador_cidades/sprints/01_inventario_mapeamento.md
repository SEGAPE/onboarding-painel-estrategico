# Sprint 1 - Inventario e Mapeamento

**Status:** EM ANDAMENTO
**Objetivo:** Base de dados completa para alimentar o scanner automatico.

## Entregas

### 1.1 CSV Inventario (CONCLUIDA)
- [x] 24 tabelas mapeadas em inventario.csv
- [x] Colunas: query, objeto, localizacao_dbt, localizacao_gcp, status_modelo
- [x] Colunas geograficas identificadas (municipio, estado, ano)
- [x] Colunas principais listadas por tabela

### 1.2 Copias de Referencia
- [ ] queries_originais/ com os 18 SQLs ativos
- [ ] schemas_originais/ com definicoes de colunas relevantes

### 1.3 Mapeamento de Linhagem (linhagem.json)
- [ ] Para cada tabela final, extrair as tabelas fonte (ref/source no SQL)
- [ ] Mapear: tabela_final -> [tabela_fonte_1, tabela_fonte_2, ...]
- [ ] Incluir localizacao GCP das fontes (projeto.dataset.tabela)
- [ ] Incluir coluna de municipio equivalente na fonte

Formato do linhagem.json:
```json
{
  "painel_escola": {
    "fontes": [
      {
        "nome": "inep_base_censo_escolar",
        "gcp": "br-mec-segape-dev.indicador_politica_inep_base.inep_base_censo_escolar",
        "coluna_municipio": "id_municipio",
        "tipo": "source"
      }
    ],
    "joins_criticos": ["filtro_territorio LEFT JOIN censo ON id_municipio"]
  }
}
```

### 1.4 Mapeamento Dashboard x Tabela
- [ ] Vincular cada secao do PDF do dashboard a tabela correspondente
- [ ] Identificar qual coluna gera qual metrica visivel

## Criterios de Aceite

- inventario.csv abre sem erros em qualquer editor
- linhagem.json cobre as 18 tabelas ativas
- Fontes upstream identificadas com localizacao GCP correta
- queries_originais/ contem copia identica dos SQLs atuais
