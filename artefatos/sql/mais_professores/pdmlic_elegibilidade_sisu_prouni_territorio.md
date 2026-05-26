
**Propósito:** Criar uma entidade unificada de todos os estudantes elegíveis pelos programas Sisu e Prouni, enriquecendo seus registros com dados geográficos detalhados.

**Como funciona:**

1. **Unificação (`UNION ALL`)**: junta as bases de elegíveis do Prouni (`pdmlic_elegibilidade_prouni`) e do Sisu (`pdmlic_elegibilidade_sisu`). Na união, remove as colunas de PII (`cpf`, `nome_pessoa`) com `EXCEPT` e adiciona a coluna `origem` para marcar de qual programa veio cada registro.

2. **Enriquecimento geográfico (`LEFT JOIN`)**: junta o resultado com `filtro_territorio` pelo `codigo_ibge_curso`, de modo que cada estudante herde os dados geográficos do município onde estuda.


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
