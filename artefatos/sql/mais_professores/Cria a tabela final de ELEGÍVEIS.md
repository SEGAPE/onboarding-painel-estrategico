-- #1: Cria a tabela final de ELEGÍVEIS, contendo o registro completo mais recente de cada ID único.

-- A tabela será criada no dataset 'educacao_temp'.

CREATE OR REPLACE TABLE `br-mec-segape-dev.educacao_temp.elegiveis_freire` AS

SELECT

*

FROM

`br-mec-segape-dev.educacao_temp.cadastrado_freire_pdmlic_new`

QUALIFY ROW_NUMBER() OVER(PARTITION BY id_pessoa ORDER BY data_carga DESC) = 1;

  
  

-- #2: Cria a tabela final de CADASTRADOS, contendo o registro completo mais recente de cada ID único com status 'APROVADO'.

-- A tabela será criada no dataset 'educacao_temp'.

CREATE OR REPLACE TABLE `br-mec-segape-dev.educacao_temp.cadastrados_freire` AS

SELECT

*

FROM

`br-mec-segape-dev.educacao_temp.cadastrado_freire_pdmlic_new`

WHERE

sclr_7 = 'APROVADO'

QUALIFY ROW_NUMBER() OVER(PARTITION BY id_pessoa ORDER BY data_carga DESC) = 1;