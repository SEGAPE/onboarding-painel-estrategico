



# 1. Subconsulta com UNION ALL
Cria uma CTE que une as bases de elegíveis do Prouni e do Sisu com `UNION ALL`. Na união, as
colunas de PII (`cpf`, `nome_pessoa`) são removidas com `EXCEPT` e a coluna `origem` é adicionada
para marcar de qual programa veio cada registro.

# 2. Tabela final com LEFT JOIN
O `CREATE OR REPLACE TABLE` envolve todo o processo: pega a CTE do passo 1 (alias `t1`) e faz
`LEFT JOIN` com `filtro_territorio` (alias `t2`) usando `CAST(t1.codigo_ibge_curso AS STRING) = t2.id`
(o CAST alinha os tipos). O resultado é salvo na tabela `pdmlic_elegibilidade_sisu_prouni_territorio`.


```sql
CREATE OR REPLACE TABLE `br-mec-segape-dev.educacao_politica_pdmlic.pdmlic_elegibilidade_sisu_prouni_territorio` AS (
  -- #1
  WITH elegibilidade_unificada AS (
    SELECT
      * EXCEPT(cpf nome_pessoa)
      'prouni' AS origem
    FROM
      `br-mec-segape-dev.educacao_politica_pdmlic.pdmlic_elegibilidade_prouni`
    UNION ALL
    SELECT
      * EXCEPT(cpf nome_pessoa)
      'sisu' AS origem
    FROM
      `br-mec-segape-dev.educacao_politica_pdmlic.pdmlic_elegibilidade_sisu`
  )
  -- #2
  SELECT
    t1.*
    t2.* EXCEPT (id)
  FROM
    elegibilidade_unificada AS t1
  LEFT JOIN
    `br-mec-segape-dev.projeto_painel_ministro.filtro_territorio` AS t2
    ON CAST(t1.codigo_ibge_curso AS STRING) = t2.id
),
```




# Análise das abas de cada planilha:

```csv

"nome_da_aba","uso_no_dashboard","necessario_no_bigquery","status_atual","observacoes_e_proximos_passos"
"pnd_adesao","Essencial. Alimenta o painel ""Prova Nacional Docente"".","Sim","Tabela Mestre","Ação Crítica: Requer tratamento na coluna 'codigo_de_acesso' para diferenciar adesão de Município (IBGE) e Estado (UF) conforme informação recebida."
"bolsista_pdmlic","Essencial. Alimenta o painel ""Pé-de-Meia Licenciaturas"".","Sim","Tabela Mestre","A fonte principal para KPIs de beneficiários valores e análises detalhadas (mensal IES curso). Está pronta para uso."
"pmlic_elegibilidade_sisu","Essencial (como parte da união).","Sim","Tabela Fonte","Já foi unificada na tabela final. É uma fonte primária."
"pdmlic_elegibilidade_prouni","Essencial (como parte da união).","Sim","Tabela Fonte","Já foi unificada na tabela final. É uma fonte primária."
"[DADO AUSENTE]","Essencial. Alimenta o painel ""Bolsa Mais Professores"".","Sim","Ausente","Ação Crítica: É imperativo solicitar ao cliente uma tabela com dados de vagas previstas e valores estimados para este programa. Sem ela o painel ficará incompleto."
"Municípios que aderiram","Fonte de dados brutos.","Não","Dado Consolidado","Os dados desta aba já estão contidos de forma estruturada em pnd_adesao. Não subir."
"Estados que aderiram","Fonte de dados brutos.","Não","Dado Consolidado","Os dados desta aba já estão contidos de forma estruturada em pnd_adesao. Não subir."
"Bolsistas PdM Lic - Março e abr","Fonte de dados brutos.","Não","Dado Consolidado","Memória de uma extração mensal. Os dados consolidados devem estar em bolsista_pdmlic. Não subir."
"Total de elegíveis PdM Lic Sisu","Fonte de dados brutos.","Não","Dado Consolidado","Memória de uma extração. Os dados já estão na tabela pmlic_elegibilidade_sisu. Não subir."
"Total de elegíveis PdM Lic Prou","Fonte de dados brutos.","Não","Dado Consolidado","Memória de uma extração. Os dados já estão na tabela pdmlic_elegibilidade_prouni. Não subir."
"Estimativa de vagas","Fonte de dados brutos.","Não","Dado Ausente","Esta aba parece ser um rascunho para os dados faltantes do ""Bolsa Mais Professores"". Precisamos da fonte oficial e estruturada."
"schemas","Documentação.","Não","Metadados","Útil para consulta manual mas não deve ser ingerida como tabela de dados no BigQuery."
"nomes_tabelas","Documentação.","Não","Metadados","Apenas um índice. Irrelevante para a análise."
"PDML-Bolsistas-Mar-Mai-","Fonte de dados brutos.","Não","Dado Consolidado","Outro dado já representado em bolsista_pdmlic. Não subir."
"PDML-Listagem-Freire-","Fonte de dados brutos.","Não","Dado Consolidado","Provavelmente a origem dos dados de elegíveis. Já representados nas tabelas de Prouni/Sisu. Não subir."
"sigla_if","Tabela de Dimensão/Auxiliar.","Opcional","Dado Auxiliar","Poderia ser útil como uma tabela de dimensão para enriquecer os dados de IES mas a princípio não é essencial para os painéis mostrados."

```
