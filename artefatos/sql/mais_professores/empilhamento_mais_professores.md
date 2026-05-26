



# 1.
> O Coração da Quimera (A Subconsulta com UNION ALL): No âmago do nosso feitiço primeiro criamos uma tabela virtual um caldeirão temporário que existe apenas no momento da execução. Nele unimos as almas do Prouni e do Sisu com o UNION ALL. Durante esta união garantimos que as colunas proibidas (cpf nome_pessoa) sejam deixadas para trás com o comando EXCEPT e adicionamos a coluna origem para que cada registro carregue a marca de seu nascimento.

# 2
> . A Materialização Final (CREATE TABLE com LEFT JOIN): O comando principal CREATE OR REPLACE TABLE agora envolve todo o processo. Ele pega a tabela virtual criada no passo anterior (aliás t1) e no mesmo fôlego realiza a fusão com filtro_territorio (aliás t2). A junção é feita com o LEFT JOIN usando nosso tradutor juramentado CAST(t1.codigo_ibge_curso AS STRING) = t2.id para garantir que os mundos se entendam. O resultado desta união completa é então permanentemente salvo na nova tabela pdmlic_elegibilidade_sisu_prouni_territorio que já nasce com todas as colunas que você deseja.


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
"pmlic_elegibilidade_sisu","Essencial (como parte da união).","Sim","Tabela Fonte","Já foi unificada na nossa tabela quimera. É uma fonte primária."
"pdmlic_elegibilidade_prouni","Essencial (como parte da união).","Sim","Tabela Fonte","Já foi unificada na nossa tabela quimera. É uma fonte primária."
"[DADO FANTASMA]","Essencial. Alimenta o painel ""Bolsa Mais Professores"".","Sim","Ausente","Ação Crítica: É imperativo solicitar ao cliente uma tabela com dados de vagas previstas e valores estimados para este programa. Sem ela o painel ficará incompleto."
"Municípios que aderiram","Fonte de dados brutos.","Não","Dado Consolidado","Os dados desta aba já estão contidos de forma estruturada em pnd_adesao. Não subir."
"Estados que aderiram","Fonte de dados brutos.","Não","Dado Consolidado","Os dados desta aba já estão contidos de forma estruturada em pnd_adesao. Não subir."
"Bolsistas PdM Lic - Março e abr","Fonte de dados brutos.","Não","Dado Consolidado","Memória de uma extração mensal. Os dados consolidados devem estar em bolsista_pdmlic. Não subir."
"Total de elegíveis PdM Lic Sisu","Fonte de dados brutos.","Não","Dado Consolidado","Memória de uma extração. Os dados já estão na tabela pmlic_elegibilidade_sisu. Não subir."
"Total de elegíveis PdM Lic Prou","Fonte de dados brutos.","Não","Dado Consolidado","Memória de uma extração. Os dados já estão na tabela pdmlic_elegibilidade_prouni. Não subir."
"Estimativa de vagas","Fonte de dados brutos.","Não","Dado Fantasma","Esta aba parece ser um rascunho para os dados faltantes do ""Bolsa Mais Professores"". Precisamos da fonte oficial e estruturada."
"schemas","Documentação.","Não","Metadados","Útil para consulta manual mas não deve ser ingerida como tabela de dados no BigQuery."
"nomes_tabelas","Documentação.","Não","Metadados","Apenas um índice. Irrelevante para a análise."
"PDML-Bolsistas-Mar-Mai-","Fonte de dados brutos.","Não","Dado Consolidado","Outro espectro de dados já representados em bolsista_pdmlic. Não subir."
"PDML-Listagem-Freire-","Fonte de dados brutos.","Não","Dado Consolidado","Provavelmente a origem dos dados de elegíveis. Já representados nas tabelas de Prouni/Sisu. Não subir."
"sigla_if","Tabela de Dimensão/Auxiliar.","Opcional","Dado Auxiliar","Poderia ser útil como uma tabela de dimensão para enriquecer os dados de IES mas a princípio não é essencial para os painéis mostrados."

```
