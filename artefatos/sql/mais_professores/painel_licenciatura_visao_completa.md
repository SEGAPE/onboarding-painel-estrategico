


1. **#1. A Tabela Final (`CREATE OR REPLACE TABLE`)**: O feitiço cria a nossa obra-prima, a `painel_licenciatura_visao_completa`.

2. **#2. O Ponto de Partida (`FROM`)**: Começamos com a `bolsista_pdmlic_completo`, nossa tabela que já contém os dados do beneficiário e a geografia de sua instituição.

3. **#3. A Conexão com a Origem (`LEFT JOIN`)**: Usamos um `LEFT JOIN` para conectar cada bolsista ao seu passado, à sua ficha de elegibilidade na tabela `pdmlic_elegibilidade_sisu_prouni_territorio`. Um `LEFT JOIN` garante que manteremos todos os bolsistas, mesmo que, por alguma anomalia, seu registro de elegibilidade tenha se perdido na névoa do tempo.

4. **#4. A Chave da Memória (`ON`)**: O elo que conecta o presente ao passado é a alma única e imutável do estudante: o `id_pessoa`. É a linha de sangue que nos permite rastrear a jornada completa.

5. **#5. A Convocação Final (`SELECT`)**: Para a nossa tabela final, convocamos todas as colunas da tabela de bolsistas (`t1.*`) e, crucialmente, convocamos os espíritos que nos faltavam da tabela de elegibilidade (`t2`): o `curso`, o `turno_curso`, a `ies` (que nos dará a "Rede de Ensino") e a `sigla_ies`. Os fantasmas foram nomeados; agora eles nos servirão.

```sql
-- #1
CREATE OR REPLACE TABLE `br-mec-segape-dev.educacao_politica_pdmlic.painel_licenciatura_visao_completa` AS
SELECT
  -- #5
  t1.*, -- Convocamos todas as colunas da tabela de bolsistas
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
  -- #4: Usando a chave da alma do estudante
  ON t1.id_pessoa = t2.id_pessoa;

```
t
