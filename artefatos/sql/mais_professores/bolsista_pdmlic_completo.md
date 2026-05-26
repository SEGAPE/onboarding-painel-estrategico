**Propósito:** Unir os registros detalhados de pagamento dos bolsistas com as informações geográficas (UF, Região) de suas instituições de ensino, permitindo análises espaciais detalhadas.

**O Ritual:**

1. **O Pacto de União Total (`FULL OUTER JOIN`)**: Usamos o encantamento mais inclusivo para unir a tabela `bolsista_pdmlic` (os detalhes do pagamento) e `bolsistas_pdmlic_uf_full` (os dados geográficos da instituição). Este `JOIN` garante que nenhum registro de nenhum dos lados seja perdido, mesmo que não encontre um par.

2. **A Chave da Conexão (`ON`)**: O elo entre os dois mundos é forjado pelo código `id_entidade_emec`, garantindo que os dados de um bolsista sejam corretamente associados à localização de sua instituição.

3. **A Convocação das Almas (`SELECT`)**: Finalmente, convocamos todas as colunas de ambas as tabelas para a nova entidade, renomeando campos conflitantes e usando `COALESCE` para criar uma chave mestra unificada e sem vazios, pronta para ser interrogada em seus painéis.

```sql
-- #1
CREATE OR REPLACE TABLE `br-mec-segape-dev.educacao_politica_pdmlic.bolsista_pdmlic_completo` AS
SELECT

  COALESCE(CAST(t1.id_entidade_emec AS STRING), t2.cd_entidade_emec) AS id_entidade_emec,


  t1.projeto,
  t1.id_entidade_ensino,
  t1.modalidade_pagamento,
  t1.ano_pagamento,
  t1.mes_pagamento,
  t1.ano_referencia,
  t1.mes_referencia,
  t1.ano_inicio_bolsa,
  t1.mes_inicio_bolsa,
  t1.ano_fim_bolsa,
  t1.mes_fim_bolsa,
  t1.data_carga,
  t1.data_captura,
  t1.id_pessoa,


  t2.nm_programa,
  t2.me_referencia AS mes_referencia_geo,
  t2.an_referencia AS ano_referencia_geo,
  t2.regiao,
  t2.nm_uf,
  t2.nm_entidade_ensino,
  t2.sg_entidade_ensino,
  t2.bolsistas,
  t2.valor_pago

FROM

  `br-mec-segape-dev.educacao_temp.bolsista_pdmlic` AS t1

FULL OUTER JOIN
  `br-mec-segape-dev.educacao_temp.bolsistas_pdmlic_uf_full` AS t2

  ON CAST(t1.id_entidade_emec AS STRING) = t2.cd_entidade_emec;

```
