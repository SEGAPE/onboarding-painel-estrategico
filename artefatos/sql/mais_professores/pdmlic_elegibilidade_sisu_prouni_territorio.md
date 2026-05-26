
**Propósito:** Criar uma entidade unificada de todos os estudantes elegíveis pelos programas Sisu e Prouni, enriquecendo seus registros com dados geográficos detalhados.

**O Ritual:**

1. **O Coração da Quimera (Subconsulta com `UNION ALL`)**: No âmago do feitiço, unimos as almas do Prouni (`pdmlic_elegibilidade_prouni`) e do Sisu (`pmlic_elegibilidade_sisu`). Durante esta união, expurgamos as colunas proibidas (`cpf`, `nome_pessoa`) e adicionamos a coluna `origem` para que cada registro carregue a marca de seu nascimento.

2. **A Materialização Final (`LEFT JOIN`)**: Em seguida, tomamos esta legião unificada de elegíveis e a fundimos com a tabela `filtro_territorio`. A junção é feita usando o `codigo_ibge_curso`, garantindo que cada estudante elegível herde os dados geográficos de seu local de estudo.


```sql
CREATE OR REPLACE TABLE `br-mec-segape-dev.educacao_politica_pdmlic.pdmlic_elegibilidade_sisu_prouni_territorio` AS (
  -- #1
  WITH elegibilidade_unificada AS (
    SELECT
      * EXCEPT(cpf, nome_pessoa),
      'prouni' AS origem
    FROM
      `br-mec-segape-dev.educacao_politica_pdmlic.pdmlic_elegibilidade_prouni`
    UNION ALL
    SELECT
      * EXCEPT(cpf, nome_pessoa),
      'sisu' AS origem
    FROM
      `br-mec-segape-dev.educacao_politica_pdmlic.pdmlic_elegibilidade_sisu`
  )
  -- #2
  SELECT
    t1.*,
    t2.* EXCEPT (id)
  FROM
    elegibilidade_unificada AS t1
  LEFT JOIN
    `br-mec-segape-dev.projeto_painel_ministro.filtro_territorio` AS t2
    ON CAST(t1.codigo_ibge_curso AS STRING) = t2.id
);
```
