


1. **#1. A Tabela Final (`CREATE OR REPLACE TABLE`)**: Cria a tabela `painel_licenciatura_visao_completa`.

2. **#2. O Ponto de Partida (`FROM`)**: Começamos com a `bolsista_pdmlic_completo`, nossa tabela que já contém os dados do beneficiário e a geografia de sua instituição.

3. **#3. A Conexão com a Origem (`LEFT JOIN`)**: Usamos um `LEFT JOIN` para conectar cada bolsista ao seu passado, à sua ficha de elegibilidade na tabela `pdmlic_elegibilidade_sisu_prouni_territorio`. Um `LEFT JOIN` garante que manteremos todos os bolsistas, mesmo que, por alguma anomalia, seu registro de elegibilidade tenha se perdido na névoa do tempo.

4. **#4. Chave de junção (`ON`)**: o elo entre as tabelas é o `id_pessoa`, identificador único do estudante, que permite rastrear o histórico completo.

5. **#5. Seleção final (`SELECT`)**: Seleciona todas as colunas da tabela de bolsistas (`t1.*`) e as que faltavam da tabela de elegibilidade (`t2`): o `curso`, o `turno_curso`, a `ies` (que nos dará a "Rede de Ensino") e a `sigla_ies`.

```sql
-- #1
CREATE OR REPLACE TABLE `br-mec-segape-dev.educacao_politica_pdmlic.painel_licenciatura_visao_completa` AS
SELECT
  -- #5
  t1.*, -- Todas as colunas da tabela de bolsistas
  t2.curso,
  t2.turno_curso,
  t2.ies,
  t2.sigla_ies,
  t2.origem AS origem_elegibilidade -- Trazendo a origem (Sisu/Prouni)

FROM
  -- #2: Partimos do presente, a tabela de bolsistas já enriquecida com geo
  `br-mec-segape-dev.educacao_politica_pdmlic.bolsista_pdmlic_completo` AS t1
-- #3: Unimos com o passado, a tabela de elegibilidade
LEFT JOIN
  `br-mec-segape-dev.educacao_politica_pdmlic.pdmlic_elegibilidade_sisu_prouni_territorio` AS t2
  -- #4: Usando a chave id_pessoa do estudante
  ON t1.id_pessoa = t2.id_pessoa;

```
t
