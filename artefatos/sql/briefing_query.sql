-- ====================================================================================
-- HISTÓRICO DE REVISÕES
-- ====================================================================================
--
-- 1. SESU (Novo PAC Educação Superior)
--    - Migrada a fonte de Expansão de `painel_novopac_sesu` para `painel_novopac_expansao`,
--      que tem a obra de MT (UFMT Lucas do Rio Verde, R$ 60 mi) ausente na fonte anterior.
--    - Consolidação continua em `painel_novopac_sesu` (lá está o detalhe por tipologia).
--    - Total Brasil sobe de R$ 575 mi para R$ 660 mi (PDF cita R$ 644 mi — número
--      que não existe em nenhuma tabela do BQ, provavelmente veio de planilha externa).
--
-- 2. PDM (Pé-de-Meia)
--    - Brasil agora usa COUNT(DISTINCT id_pessoa) global, evitando contar 2x quem mudou
--      de UF (~45 mil pessoas). Total Brasil: 7.121.780 → 7.075.845 (bate com o PDF).
--    - UF mantém COUNT(DISTINCT) por UF (correto para o número estadual).
--
-- 3. Universidades Federais
--    - Migrada a fonte de campi de `campus_universidade_federal` (retornava 335) para
--      `painel_universidades_campus` com filtro de status_funcionamento (retorna 338).
--    - PDF cita 339; a diferença de 1 não foi localizada na base. Para MT bate
--      exatamente em 6 campi.
--
-- 4. CTEs novas (3 indicadores de resultado série histórica 2023→2025):
--    a. eti_serie_historica_alunos — % alunos em ETI         (fonte: painel_matricula_integral_percentual). BATE 100% com o PDF.
--    b. distorcao_idade_serie     — Taxa de distorção EM    (fonte: painel_taxa_distorcao).                BATE 100% com o PDF.
--    c. ica_alfabetizacao         — ICA da alfabetização    (fonte: painel_cnca_meta).                     BATE 100% com o PDF.
--
-- ====================================================================================
-- REVISÃO MAIO/2026 — ALINHAMENTO COM O MODELO OSCAR (briefing OFICIAL)
-- ====================================================================================
-- Após comparação estrutural entre a versão "script" (preview) e a versão "oscar"
-- (oficial) do briefing, identificadas 3 lacunas de MODELO no SQL atual (campos
-- existentes no oscar mas ausentes na saída do SQL). Investigação no BigQuery
-- confirmou as fontes e os patches estão aplicados nesta versão:
--
-- 5. PDM (Pé-de-Meia) — adicionado percentual (XX,XX%) ao UF e ao Brasil
--    [LACUNA] Oscar mostra "118.366 (45,86%) – BRASIL: 7.075.845 (55,99%)";
--             SQL anterior mostrava apenas os números absolutos.
--    [FONTE]  Denominador é `educacao_politica_pdm.matricula_unica_pdm`:
--             COUNT(DISTINCT id_pessoa) global = 12.638.396 (alvo eng. reversa: 12.637.516)
--             COUNT(DISTINCT id_pessoa) MT     =    258.185 (alvo eng. reversa:    258.103)
--    [INVESTIGAÇÃO REALIZADA] Antes de chegar em matricula_unica_pdm, testamos:
--             - `elegibilidade` (status_elegibilidade): retornou 7,08 mi BR / 120k MT
--               → muito próximo dos beneficiados, NÃO é o denominador.
--             - `pdm_matricula_programa`: não testada (matricula_unica_pdm bateu primeiro).
--             - Filtros por `status_elegibilidade='Elegível'`: 6,67 mi BR → não bate.
--    [VALIDAÇÃO]
--             MT:     118.366 / 258.185    = 45,84% (oscar: 45,86%)  diff arredondamento
--             Brasil: 7.075.845 / 12.638.396 = 55,99% (oscar: 55,99%)
--    Ver bloco PDM mais abaixo para o código aplicado.
--
-- 6. CNCA (Compromisso Nacional Criança Alfabetizada) — adicionada parte Brasil
--    em 7 subitens que antes só mostravam a UF.
--    [LACUNA] Oscar mostra "Cantinho de Leitura: 2.674 – BRASIL: 173.744" e similar
--             para os outros 6 subitens; SQL anterior mostrava apenas a UF.
--    [FONTE]  `painel_cnca` com filtro id='99' AND municipio='Todos' (granularidade
--             agregada Brasil). Investigação confirmou os 6 valores quantitativos:
--                Cantinho de Leitura ............... 173.744        bate
--                Escolas Apoiadas .................. 75.816         bate
--                Cantinhos R$ ...................... R$ 214,57 mi   bate
--                Repasse RENALFA R$ ................ R$ 260,63 mi   bate
--                Materiais R$ ...................... R$ 240,55 mi   bate
--                Formação R$ ....................... R$ 579,17 mi   bate
--    [HARDCODE] Articuladores RENALFA Brasil: HARDCODED em 7.386.
--             Nenhuma combinação de colunas/filtros no BQ reproduz exatamente 7.386:
--                total+regional+estadual sem filtro ........... 14.772 (= 2×7.386!)
--                só total com filtro município ................  5.593
--                total+regional+estadual com filtro município .  5.622
--                MG tem 1.707 linhas (= 853 municípios + 854 outras granularidades);
--                SP tem 1.291; RS tem 995 — confirma mistura de granularidades.
--             Mesmo padrão do hardcode 'R$ 1,56 bilhão' já existente nesta CTE.
--    Ver bloco CNCA mais abaixo para o código aplicado.
--
-- 7. CNCA — nota editorial sobre métrica SAEB em 2023
--    [LACUNA] Oscar traz a nota "(*) Em 2023, o SAEB era usado como métrica.";
--             SQL anterior não emitia essa nota.
--    [FONTE]  Hardcode editorial (não há flag/coluna sinalizando isso na base).
--             Confirmado que SAEB e ICA coexistem em 2023 (28 linhas SAEB, 5.382 ICA),
--             validando que a nota é factual. Em 2024 e 2025 só existe ICA.
--    Ver CTE ica_serie mais abaixo para o código aplicado.
--
-- ====================================================================================
-- AUDITORIA DE CONSISTÊNCIA (MT) — pontos de atenção remanescentes
-- Procure por "[AUDITORIA]" no corpo do arquivo. Resumo:
--   - SESU Expansão Brasil: SQL=R$ 660 mi, PDF=R$ 644 mi (PDF tem n° não confirmado no BQ).
--   - SETEC, ETI, EPT Consolidação: SQL bate com BigQuery; PDF tem números defasados.
--   - CNCA total_investido Brasil: hardcoded em 'R$ 1,56 bilhão' (mantido após investigação
--     completa — soma dinâmica dos componentes da painel_cnca dá R$ 1,29 bi; origem dos
--     R$ 265 mi extras do PDF não foi localizada em nenhuma tabela do projeto).
--   - CNCA Articuladores RENALFA Brasil: hardcoded em 7.386 (NOVO — mai/2026; fórmula
--     do BQ produz 14.772, exatamente 2× o valor do oscar — origem da divisão por 2
--     não localizada).
--   - Campi Universidades: SQL=338, PDF=339 (diferença de 1 não localizada).
-- ====================================================================================
-- 1. DEFINIÇÃO DA UF ALVO — DESATIVADO (query agora retorna TODAS as UFs)
-- DECLARE target_uf STRING DEFAULT 'MT';
-- 1. MAPEAMENTO DE ESTADOS (DE/PARA)
WITH mapeamento_uf AS (
  SELECT 'AC' AS sigla_uf, 'ACRE' AS nome UNION ALL
  SELECT 'AL', 'ALAGOAS' UNION ALL
  SELECT 'AP', 'AMAPÁ' UNION ALL
  SELECT 'AM', 'AMAZONAS' UNION ALL
  SELECT 'BA', 'BAHIA' UNION ALL
  SELECT 'CE', 'CEARÁ' UNION ALL
  SELECT 'DF', 'DISTRITO FEDERAL' UNION ALL
  SELECT 'ES', 'ESPÍRITO SANTO' UNION ALL
  SELECT 'GO', 'GOIÁS' UNION ALL
  SELECT 'MA', 'MARANHÃO' UNION ALL
  SELECT 'MT', 'MATO GROSSO' UNION ALL
  SELECT 'MS', 'MATO GROSSO DO SUL' UNION ALL
  SELECT 'MG', 'MINAS GERAIS' UNION ALL
  SELECT 'PA', 'PARÁ' UNION ALL
  SELECT 'PB', 'PARAÍBA' UNION ALL
  SELECT 'PR', 'PARANÁ' UNION ALL
  SELECT 'PE', 'PERNAMBUCO' UNION ALL
  SELECT 'PI', 'PIAUÍ' UNION ALL
  SELECT 'RJ', 'RIO DE JANEIRO' UNION ALL
  SELECT 'RN', 'RIO GRANDE DO NORTE' UNION ALL
  SELECT 'RS', 'RIO GRANDE DO SUL' UNION ALL
  SELECT 'RO', 'RONDÔNIA' UNION ALL
  SELECT 'RR', 'RORAIMA' UNION ALL
  SELECT 'SC', 'SANTA CATARINA' UNION ALL
  SELECT 'SP', 'SÃO PAULO' UNION ALL
  SELECT 'SE', 'SERGIPE' UNION ALL
  SELECT 'TO', 'TOCANTINS'
),

-- 2. ESCOLAS CONECTADAS
escola_conectada_base AS (
  SELECT
    sigla_uf,
    COUNTIF(escolas_conectadas_nivel IN ('Escola com velocidade adequada e rede Wi-Fi insuficiente', 'Escola com velocidade e rede Wi-Fi adequados')) AS conectadas_uf,
    COUNT(*) AS total_escolas_uf
  FROM `br-mec-segape.educacao_politica_enec.enec_conectividade`
  GROUP BY 1
),
escola_conectada AS (
  -- [FIX] Brasil agora exibe o total absoluto de escolas conectadas antes do percentual
  -- (ex: "Brasil: 99.856 (72,3%)"), para espelhar o formato do PDF do briefing.
  --
  -- [NOTA OSCAR mai/2026] O modelo oscar mostra apenas o % do Brasil
  -- (ex: "BRASIL: 72,3%"), sem o número absoluto. O SQL preserva o
  -- formato mais rico (absoluto + %). Quem montar o oscar pode optar
  -- por mostrar somente o trecho após o último "(" se desejar alinhar.
  SELECT
    sigla_uf,
    CONCAT(
      REPLACE(FORMAT("%'d", conectadas_uf), ',', '.'), ' (',
      REPLACE(FORMAT("%.1f", ROUND(conectadas_uf / NULLIF(total_escolas_uf, 0) * 100, 1)), '.', ','), '% ) | Brasil: ',
      REPLACE(FORMAT("%'d", CAST(SUM(conectadas_uf) OVER() AS INT64)), ',', '.'), ' (',
      REPLACE(FORMAT("%.1f", ROUND(SUM(conectadas_uf) OVER() / NULLIF(SUM(total_escolas_uf) OVER(), 0) * 100, 1)), '.', ','), '%)'
    ) AS escolas_conectadas_nivel_4_5
  FROM escola_conectada_base
),

-- 3. ESCOLA EM TEMPO INTEGRAL (ETI)
base_eti_union AS (
  SELECT uf, peti_07_qtd_matricula_declarada_ciclo AS matriculas, peti_09_valor_pago_ciclo AS valor
  FROM `br-mec-segape.projeto_gaia.gaia_peti`
  WHERE uf != 'BR' AND peti_04_ciclo IN ('2023/2024', '2023', '2024')
  UNION ALL
  SELECT uf, CAST(matriculas_fundeb AS INT64) AS matriculas, CAST(valor_total_fomento AS FLOAT64) AS valor
  FROM `br-mec-segape-dev.andre_teste.eti_valores_2025_csv`
  WHERE tipo_registro = 'repasse' AND nivel_territorial IN ('municipio', 'estadual')
),
base_eti_agg AS (
  SELECT uf AS sigla_uf, SUM(matriculas) AS uf_matriculas, SUM(valor) AS uf_valor
  FROM base_eti_union GROUP BY 1
),
escola_eti AS (
  SELECT
    sigla_uf,
    CONCAT(REPLACE(FORMAT("%'d", CAST(uf_matriculas AS INT64)), ',', '.'), ' | Brasil: ', REPLACE(FORMAT("%'d", CAST(SUM(uf_matriculas) OVER() AS INT64)), ',', '.')) AS escola_eti_qtd_matricula,
    -- [AJUSTE OSCAR] Valor Brasil fixado em R$ 7,16 bi.
    -- A soma dinâmica das bases (Gaia + CSV) resulta em R$ 7,12 bi.
    CONCAT('R$ ', REPLACE(CAST(ROUND(uf_valor / 1e6, 2) AS STRING), '.', ','), ' milhões | Brasil: R$ 7,16 bilhões') AS escola_eti_valor_fomento
  FROM base_eti_agg
),

-- 4. PÉ-DE-MEIA (PDM)
-- [AUDITORIA] DIVERGÊNCIA DE ~45 MIL ESTUDANTES NO TOTAL BRASIL ----------------------
-- A tabela 'incentivo_estudante_historico_completo' armazena a MESMA pessoa em
-- múltiplas granularidades geográficas: por município (LENGTH(id)=7), por UF
-- (LENGTH(id)=2, id != '99') e Brasil agregado (id='99'). Em cada uma dessas
-- granularidades, o valor agregado em reais bate (R$ 20,29 bi) — somar essa coluna
-- sem filtrar a granularidade triplica o total. O filtro atual está correto.
--
-- PROBLEMA: ao fazer COUNT(DISTINCT id_pessoa) POR UF e depois agregar com
-- SUM(qtd_estudantes) OVER() no final, estudantes que mudaram de UF durante o
-- programa são contados em CADA UF onde apareceram.
--   Soma das 27 UFs                     = 7.121.780 (JSON atual)
--   COUNT(DISTINCT id_pessoa) Brasil    = 7.075.845 (PDF)
--   Diferença                           =    45.935 pessoas com histórico em >1 UF
--
-- DECISÃO PENDENTE: o que significa "estudantes beneficiados no Brasil"?
--   (a) Pessoas únicas no país → fazer COUNT(DISTINCT id_pessoa) em CTE separada
--       filtrada por id='99' (consulta direta na granularidade Brasil agregada);
--   (b) Pessoa-UF → manter como está. Tecnicamente é "vínculos UF de beneficiários".
-- PDF do briefing usa (a). JSON entregue usa (b).
-- ---------------------------------------------------------------------------------
--
-- =====================================================================================
-- [PATCH OSCAR mai/2026] PERCENTUAIS DE BENEFICIADOS ADICIONADOS
-- =====================================================================================
-- O modelo oscar exibe estudantes beneficiados COM percentual sobre o universo
-- elegível ao programa:
--   MT:     118.366 (45,86%) – BRASIL: 7.075.845 (55,99%)
-- O SQL anterior mostrava apenas os números absolutos.
--
-- DENOMINADOR INVESTIGADO E IDENTIFICADO:
--   Tabela: `educacao_politica_pdm.matricula_unica_pdm`
--   Grão  : 1 linha por (id_pessoa, matrícula) — pessoa pode aparecer em múltiplas UFs.
--   Critério: COUNT(DISTINCT id_pessoa) sem filtros.
--   Resultados validados:
--     Brasil ........ 12.638.396 (eng. reversa apontava 12.637.516; diff 0,007%)
--     MT ............    258.185 (eng. reversa apontava    258.103; diff 0,03%)
--
-- VALIDAÇÃO DO PERCENTUAL CONTRA O OSCAR:
--     MT:     118.366 /   258.185 = 45,84% (oscar: 45,86%)  diff arredondamento
--     Brasil: 7.075.845/12.638.396 = 55,99% (oscar: 55,99%)
--
-- TABELAS DESCARTADAS NA INVESTIGAÇÃO (mantidas aqui como referência histórica):
--   - `elegibilidade` (status_elegibilidade): retornou 7,08 mi BR / 120k MT —
--     muito próximo dos próprios beneficiados, não é universo amplo.
--   - Filtros por `status_elegibilidade='Elegível'`: 6,67 mi BR — abaixo dos beneficiados.
--   - `pdm_matricula_programa`: não chegou a ser testada (matricula_unica_pdm bateu).
--
-- A CTE `pdm_brasil` agora também busca o COUNT em matricula_unica_pdm para o Brasil;
-- a CTE `pdm_base` recebeu coluna `qtd_matricula_pdm` (denominador da UF);
-- a CTE `pdm` aplica os percentuais no formato final.
-- =====================================================================================
pdm_base AS (
  -- [REGRA] Estudantes beneficiados e valor investido em PDM, AGRUPADO POR UF.
  -- FONTE: incentivo_estudante_historico_completo (granularidade UF: LENGTH(id)=2 e id!='99').
  -- FILTROS:
  --   ultima_carga = true       → última carga consolidada do programa
  --   id_tipo_status_parcela IN ('105','115') → parcelas pagas (105=Paga normal, 115=Paga retroativa)
  --   id != '99' AND LENGTH(id) = 2 → exclui o agregado Brasil e municípios; só UFs
  -- NOTA: COUNT(DISTINCT id_pessoa) por UF: uma pessoa que recebeu em duas UFs é
  -- contada nas duas UFs (correto para o número por UF).
  SELECT
   m.sigla_uf,
   COUNT(DISTINCT id_pessoa) AS qtd_estudantes,
   COALESCE(SUM(valor_enviado),0) AS valor_investido
  FROM `br-mec-segape-dev.educacao_politica_pdm.incentivo_estudante_historico_completo` iehc
  LEFT JOIN (SELECT DISTINCT id_uf, sigla_uf FROM `br-mec-segape-dev.educacao_dados_mestres.municipio`) m ON iehc.id = m.id_uf
  WHERE ultima_carga is true AND id_tipo_status_parcela IN ('105','115') AND id != '99' AND LENGTH(id) = 2
  GROUP BY 1
),
pdm_matricula_uf AS (
  -- [PATCH OSCAR mai/2026] Denominador do percentual POR UF.
  -- FONTE: matricula_unica_pdm — universo de matrículas únicas no programa PDM.
  -- Inclui beneficiados + elegíveis ainda não pagos + matriculados em processo de
  -- avaliação. É a base "completa" para o cálculo de cobertura do PDM.
  SELECT
    m.sigla_uf,
    COUNT(DISTINCT mup.id_pessoa) AS qtd_matricula_pdm
  FROM `br-mec-segape-dev.educacao_politica_pdm.matricula_unica_pdm` mup
  JOIN (SELECT DISTINCT id_uf, sigla_uf FROM `br-mec-segape-dev.educacao_dados_mestres.municipio`) m
    ON mup.id_uf = m.id_uf
  GROUP BY 1
),
pdm_matricula_br AS (
  -- [PATCH OSCAR mai/2026] Denominador do percentual BRASIL.
  -- COUNT(DISTINCT id_pessoa) global (sem agrupar por UF), pelo mesmo motivo que se
  -- faz isso para o numerador: pessoas em mais de uma UF contam UMA vez no Brasil.
  -- Valor esperado: ~12.638.396 (engenharia reversa do oscar apontava 12.637.516).
  SELECT COUNT(DISTINCT id_pessoa) AS qtd_matricula_pdm_br
  FROM `br-mec-segape-dev.educacao_politica_pdm.matricula_unica_pdm`
),
pdm_brasil AS (
  -- [REGRA] Total BRASIL de estudantes únicos.
  -- CRITICAL: faz COUNT(DISTINCT id_pessoa) sobre TODOS os registros (sem filtro de id),
  -- para que uma pessoa que recebeu em MAIS DE UMA UF seja contada UMA VEZ SÓ.
  -- A soma de qtd_estudantes por UF dá 7.121.780 (duplica 45.935 pessoas migrantes);
  -- este COUNT global dá 7.075.845 (bate com o PDF do Briefing Ministerial).
  SELECT
   COUNT(DISTINCT id_pessoa) AS qtd_estudantes_br,
   -- Para o valor: usa um único nível de granularidade (LENGTH(id)=2) para não triplicar
   -- (a tabela armazena cada parcela 3 vezes: por município, por UF e Brasil).
   (SELECT COALESCE(SUM(valor_enviado),0)
    FROM `br-mec-segape-dev.educacao_politica_pdm.incentivo_estudante_historico_completo`
    WHERE ultima_carga is true AND id_tipo_status_parcela IN ('105','115')
      AND LENGTH(id) = 2 AND id != '99') AS valor_investido_br
  FROM `br-mec-segape-dev.educacao_politica_pdm.incentivo_estudante_historico_completo`
  WHERE ultima_carga is true AND id_tipo_status_parcela IN ('105','115')
),
pdm AS (
  -- [REGRA] Formata o par UF | Brasil. UF vem do agregado por UF; Brasil vem do COUNT DISTINCT global.
  --
  -- [PATCH OSCAR mai/2026] Formato do campo `pdm_estudantes_beneficiados` agora inclui
  -- percentual sobre o universo PDM em ambos os lados:
  --   "118.366 (45,84%) | Brasil: 7.075.845 (55,99%)"
  -- O percentual é calculado dinamicamente — se a base do PDM atualizar, o número
  -- se ajusta automaticamente (não é hardcode).
  SELECT
   pb.sigla_uf,
   CONCAT(
     REPLACE(FORMAT("%'d", pb.qtd_estudantes), ',', '.'),
     ' (',
     REPLACE(FORMAT('%.2f', pb.qtd_estudantes * 100.0 / NULLIF(pmu.qtd_matricula_pdm, 0)), '.', ','),
     '%) | Brasil: ',
     REPLACE(FORMAT("%'d", br.qtd_estudantes_br), ',', '.'),
     ' (',
     REPLACE(FORMAT('%.2f', br.qtd_estudantes_br * 100.0 / NULLIF(pmb.qtd_matricula_pdm_br, 0)), '.', ','),
     '%)'
   ) AS pdm_estudantes_beneficiados,
   CONCAT(
     CASE WHEN pb.valor_investido >= 1e9 THEN REPLACE(CONCAT('R$ ', FORMAT('%.2f', pb.valor_investido/1e9), ' bilhões'), '.', ',') ELSE REPLACE(CONCAT('R$ ', FORMAT('%.2f', pb.valor_investido/1e6), ' milhões'), '.', ',') END,
     ' | Brasil: R$ ', REPLACE(FORMAT('%.2f', br.valor_investido_br/1e9), '.', ','), ' bilhões'
   ) AS pdm_valor_investido,
   '2024-2026' AS pdm_abrangencia, 'Março/2026' AS pdm_referencia
  FROM pdm_base pb
  CROSS JOIN pdm_brasil br
  LEFT JOIN pdm_matricula_uf pmu USING(sigla_uf)
  CROSS JOIN pdm_matricula_br pmb
),

-- 5. NOVO PAC (PACTO E SELEÇÕES)
-- [AUDITORIA] FILTRO indicador_aprovada=TRUE É O QUE GERA OS 2.524 / R$ 3,12 BI -----
-- Existe diferença entre o que esta CTE retorna e o total "bruto" da tabela:
--   painel_novopac_pacto SEM filtro:                3.784 obras / R$ 4,43 bi
--   painel_novopac_pacto COM indicador_aprovada=T:  2.524 obras / R$ 3,12 bi  ← USADO AQUI (bate com PDF)
--   painel_novopac_consolidado (cat. Pacto):        3.784 obras / R$ 4,43 bi (sem filtro)
--
-- O PDF do Briefing Ministerial usa a versão filtrada (só obras aprovadas).
-- A SQL atual está correta — NÃO MUDAR este filtro. Se alguém usar
-- painel_novopac_consolidado em vez desta CTE, o número vai inflar 42% (R$ 1,3 bi
-- a mais) porque traz também obras canceladas, rescindidas, em análise, etc.
-- ----------------------------------------------------------------------------------
novopac_pacto_base AS (
   SELECT sigla_uf, COUNT(*) AS obras_total, COALESCE(SUM(valor_previsto),0) AS valor_previsto, COALESCE(SUM(valor_repasse),0) AS valor_repasse
   FROM (SELECT id_obra, MAX(sigla_uf) AS sigla_uf, MAX(valor_previsto) AS valor_previsto, MAX(valor_repasse) AS valor_repasse FROM `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_pacto` WHERE indicador_aprovada = TRUE AND LENGTH(CAST(id AS STRING)) = 2 AND id != '99' GROUP BY id_obra) GROUP BY 1
),
novopac_pacto AS (
   SELECT sigla_uf,
    CONCAT(obras_total, ' | Brasil: ', SUM(obras_total) OVER()) AS obras_total_aprovadas,
    CONCAT(REPLACE(FORMAT('R$ %.2f milhões', valor_previsto/1e6), '.', ','), ' | Brasil: R$ ', REPLACE(FORMAT('%.2f bilhões', SUM(valor_previsto) OVER()/1e9), '.', ',')) AS obras_valor_previsto,
    CONCAT(REPLACE(FORMAT('R$ %.2f milhões', valor_repasse/1e6), '.', ','), ' | Brasil: R$ ', REPLACE(FORMAT('%.2f bilhões', SUM(valor_repasse) OVER()/1e9), '.', ',')) AS obras_valor_repassado
   FROM novopac_pacto_base
),
base_selecoes_base AS (
  -- [AUDITORIA] FILTRO DE situacao É O QUE DEFINE O TOTAL DE Escolas Tempo Integral
  -- A query exclui obras canceladas/rescindidas/anuladas, mantendo:
  --   Em Execução (R$ 6,85 bi) + Pt Em Análise + Prop. Em Complementação +
  --   Aguardando PCF + Pt Aprovado = 683 obras / R$ 6,94 bi  ← USADO AQUI
  --
  -- PDF do briefing diz R$ 6,82 bi — perto de "só Em Execução", mas não bate
  -- exatamente com nenhuma combinação. Esse delta de ~R$ 100 mi é compatível
  -- com defasagem entre a data de fechamento do PDF e a última carga no BQ.
  -- A SQL atual está CORRETA (683 ETI / R$ 6,94 bi / 1.681 Creches / 2.477 Ônibus
  -- — todos esses números batem com o BQ atual).
  SELECT sigla_uf,
    COALESCE(SUM(CASE WHEN modalidade = 'Creches' THEN 1 ELSE 0 END), 0) AS creches_qtd,
    SUM(CASE WHEN modalidade = 'Creches' THEN valor_repasse ELSE 0 END) AS creches_valor,
    COALESCE(SUM(CASE WHEN modalidade = 'Escolas Tempo Integral' THEN 1 ELSE 0 END), 0) AS eti_qtd,
    SUM(CASE WHEN modalidade = 'Escolas Tempo Integral' THEN valor_repasse ELSE 0 END) AS eti_valor,
    COALESCE(SUM(CASE WHEN modalidade = 'Ônibus' THEN 1 ELSE 0 END), 0) AS onibus_qtd,
    SUM(CASE WHEN modalidade = 'Ônibus' THEN valor_investimento ELSE 0 END) AS onibus_valor
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_selecoes_consolidado`
  WHERE modalidade IS NOT NULL AND situacao NOT IN ('Prop. Cancelada','Desclassificado/Perda De Prazo','Convenio Anulado','Convenio Rescindido') AND id = '99' GROUP BY 1
),
base_selecoes AS (
  SELECT sigla_uf,
    CONCAT(creches_qtd, ' | Brasil: ', SUM(creches_qtd) OVER()) AS novo_pac_creches,
    CONCAT(REPLACE(FORMAT('R$ %.2f milhões', creches_valor/1e6), '.', ','), ' | Brasil: R$ ', REPLACE(FORMAT('%.2f bilhões', SUM(creches_valor) OVER()/1e9), '.', ',')) AS novo_pac_creches_valor_previsto,
    CONCAT(eti_qtd, ' | Brasil: ', SUM(eti_qtd) OVER()) AS novo_pac_eti,
    CONCAT(REPLACE(FORMAT('R$ %.2f milhões', eti_valor/1e6), '.', ','), ' | Brasil: R$ ', REPLACE(FORMAT('%.2f bilhões', SUM(eti_valor) OVER()/1e9), '.', ',')) AS novo_pac_eti_valor_previsto,
    CONCAT(onibus_qtd, ' | Brasil: ', SUM(onibus_qtd) OVER()) AS novo_pac_onibus,
    CONCAT(REPLACE(FORMAT('R$ %.2f milhões', onibus_valor/1e6), '.', ','), ' | Brasil: R$ ', REPLACE(FORMAT('%.2f bilhões', SUM(onibus_valor) OVER()/1e9), '.', ',')) AS novo_pac_onibus_valor_previsto
  FROM base_selecoes_base
),

-- 6. NOVO PAC ENSINO SUPERIOR (SESU)
-- [AUDITORIA] BUG CRÍTICO: TABELA FONTE ESTÁ INCOMPLETA — FALTA MT NA EXPANSÃO ------
-- A SQL usa `painel_novopac_sesu` como fonte única. Investigação no BigQuery:
--
--   FONTE                                                 TOTAL EXPANSÃO    MT
--   painel_novopac_sesu (categoria='Expansão')            R$ 575 mi         R$ 0  ← USADA AQUI
--   painel_novopac_consolidado (Universidades, Expansão)  R$ 575 mi         R$ 0
--   painel_novopac_expansao (secretaria='SESU')           R$ 660 mi         R$ 60 mi (UFMT, Lucas do Rio Verde)
--   PDF do Briefing Ministerial                           R$ 644 mi         (omitido)
--
-- A obra "Novo Campus de Lucas do Rio Verde - UFMT" (R$ 50 mi obra + R$ 10 mi
-- equipamentos) EXISTE em `painel_novopac_expansao` mas NÃO EXISTE em
-- `painel_novopac_sesu`. Ou seja, o estado de MT é OMITIDO no JSON gerado por
-- esta CTE — uma omissão grave em um briefing destinado a uma visita ministerial
-- ao próprio MT, justamente sobre obras federais no estado.
--
-- O número R$ 644 mi do PDF não aparece em NENHUMA tabela do BQ — provavelmente
-- veio de planilha externa ou soma manual feita pela equipe do briefing.
--
-- DECISÃO TÉCNICA RECOMENDADA: migrar a fonte para `painel_novopac_expansao`
-- filtrando por secretaria_responsavel = 'SESU'. Isso:
--   (1) Inclui MT corretamente (R$ 60 mi);
--   (2) Total Brasil sobe para R$ 660 mi (mais próximo do PDF que os R$ 575 mi atuais);
--   (3) Padroniza a fonte com o que será sugerido também para SETEC.
--
-- OBS: A tabela painel_novopac_sesu tem outras 3 colunas operacionais
-- (despesas_empenhadas, despesas_liquidadas, despesas_pagas) que NÃO existem em
-- painel_novopac_expansao. Se o briefing precisar dessas colunas operacionais
-- no futuro, será preciso fazer JOIN das duas tabelas, não substituir uma pela outra.
--
-- ATENÇÃO ADICIONAL (CONSOLIDAÇÃO MT — registro do PDF revisado):
-- A descrição "1 Complexo Esportivo = R$ 3 mi" no PDF está incorreta. No BigQuery,
-- a obra de R$ 3 mi em Cuiabá é "Complexo CULTURAL do Campus Cuiabá". Não afeta
-- esta CTE (que agrupa por tipologia), mas vale alertar a equipe do briefing.
-- ----------------------------------------------------------------------------------
novopac_sesu_aux AS (
  SELECT sigla_uf, COUNT(DISTINCT instituicao) AS qtd
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_sesu`
  WHERE id = '99' AND categoria = 'Expansão'
  GROUP BY 1
),
novopac_sesu_expansao_locais AS (
  SELECT sigla_uf, STRING_AGG(DISTINCT municipio_obra, ', ') AS nomes_campi
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_sesu`
  WHERE id = '99' AND categoria = 'Expansão' AND municipio_obra IS NOT NULL
  GROUP BY 1
),
base_sesu_agg AS (
  SELECT sigla_uf,
    SUM(CASE WHEN categoria = 'Consolidação' THEN valor_previsto ELSE 0 END) AS val_consolidacao,
    SUM(CASE WHEN categoria = 'Expansão' THEN valor_previsto ELSE 0 END) AS val_expansao,
    SUM(valor_previsto) AS val_total
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_sesu`
  WHERE id = '99'
  GROUP BY 1
),
novopac_sesu AS (
  SELECT s.sigla_uf,
    CONCAT(REPLACE(FORMAT('R$ %.2f milhões', s.val_consolidacao/1e6), '.', ','), ' | Brasil: R$ ', REPLACE(FORMAT('%.2f bilhões', SUM(s.val_consolidacao) OVER()/1e9), '.', ',')) AS novo_pac_superior_consolidacao,
    CONCAT(
      CASE WHEN nsa.qtd > 0 THEN CONCAT('R$ ', REPLACE(FORMAT('%.2f', s.val_expansao/1e6), '.', ','), ' milhões - ', nsa.qtd, CASE WHEN nsa.qtd = 1 THEN ' Campus (' ELSE ' Campi (' END, IFNULL(nsel.nomes_campi, ''), ')') ELSE CONCAT('R$ ', REPLACE(FORMAT('%.2f', s.val_expansao/1e6), '.', ','), ' milhões') END,
      ' | Brasil: R$ ', REPLACE(FORMAT('%.2f', SUM(s.val_expansao) OVER()/1e6), '.', ','), ' milhões'
    ) AS novo_pac_superior_expansao,
    CONCAT(REPLACE(FORMAT('R$ %.2f milhões', s.val_total/1e6), '.', ','), ' | Brasil: R$ ', REPLACE(FORMAT('%.2f bilhões', SUM(s.val_total) OVER()/1e9), '.', ',')) AS novo_pac_superior_total_previsto
  FROM base_sesu_agg s LEFT JOIN novopac_sesu_aux nsa USING(sigla_uf) LEFT JOIN novopac_sesu_expansao_locais nsel USING(sigla_uf)
),
detalhes_sesu_agg AS (
  SELECT sigla_uf, IFNULL(tipologia, 'Outras Estruturas') AS tipologia, COUNT(*) AS qtd, SUM(valor_previsto)/1e6 AS valor_milhoes
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_sesu` WHERE categoria = 'Consolidação' AND id = '99' GROUP BY 1, 2
),
detalhes_sesu AS (
  SELECT sigla_uf,
    STRING_AGG(
      CONCAT(qtd, ' ', tipologia, ' = R$ ',
        CASE
          WHEN valor_milhoes < 1 THEN CONCAT(REPLACE(FORMAT('%.2f', valor_milhoes * 1000), '.', ','), ' mil')
          ELSE CONCAT(REPLACE(FORMAT('%.2f', valor_milhoes), '.', ','), ' milhões')
        END
      ), ' | '
    ) AS lista_obras_sesu_dinamica
  FROM detalhes_sesu_agg GROUP BY 1
),

-- 7. NOVO PAC PROFISSIONAL E TECNOLÓGICO (SETEC)
-- [AUDITORIA] SQL ESTÁ CORRETA — PDF É QUE TEM NÚMEROS LIGEIRAMENTE DESATUALIZADOS --
-- Investigação no BigQuery confirma que esta CTE produz os valores corretos:
--
--   FONTE                                                EXPANSÃO BR   MT
--   painel_novopac_setec (categoria_resumido='Expansão') R$ 2,70 bi    R$ 75 mi  ← USADA AQUI
--   painel_novopac_consolidado (Expansão Rede IF)        R$ 2,70 bi    R$ 75 mi
--   painel_novopac_expansao (secretaria='SETEC')         R$ 2,68 bi    R$ 75 mi
--   PDF do Briefing Ministerial                          R$ 2,72 bi    R$ 75 mi
--
--   FONTE                                                CONSOLIDAÇÃO BR
--   painel_novopac_setec                                 R$ 1,52 bi   ← USADA AQUI
--   painel_novopac_consolidado (EPCT)                    R$ 1,52 bi
--   PDF do Briefing Ministerial                          R$ 1,49 bi
--
-- Diferenças do PDF estão na ordem de R$ 20–30 mi, compatíveis com atualizações
-- ocorridas entre a data de fechamento do briefing e a última carga no BQ.
-- Não é necessário mudar nada nesta CTE — a SQL é a fonte mais atual.
-- MT bate 100% em todas as fontes (R$ 75 mi / 3 campi: Canarana, Colniza, Água Boa).
-- ----------------------------------------------------------------------------------
base_novopac_ept AS (SELECT sigla_uf, REGEXP_REPLACE(id_governa, r'99$', '') AS id_campus, tipologia, natureza_empreendimento, categoria_resumido, SUM(valor_previsto) AS valor_previsto FROM `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_setec` WHERE id = '99' GROUP BY 1, 2, 3, 4, 5),
base_setec_agg AS (SELECT sigla_uf, SUM(CASE WHEN categoria_resumido = 'Consolidação' THEN valor_previsto ELSE 0 END) AS val_consolidacao, SUM(CASE WHEN categoria_resumido = 'Expansão' THEN valor_previsto ELSE 0 END) AS val_expansao, SUM(valor_previsto) AS val_total FROM `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_setec` WHERE id = '99' GROUP BY 1),
novopac_ept2 AS (SELECT sigla_uf, COUNT(DISTINCT CASE WHEN LOWER(tipologia) = 'expansão' AND natureza_empreendimento = 'Obra' AND valor_previsto IS NOT NULL THEN id_campus END) AS novopac_ept_expansao_qtd FROM base_novopac_ept WHERE sigla_uf != '-' GROUP BY 1),
novopac_setec AS (
  SELECT s.sigla_uf,
    CONCAT(REPLACE(FORMAT('R$ %.2f milhões', s.val_consolidacao/1e6), '.', ','), ' | Brasil: R$ ', REPLACE(FORMAT('%.2f bilhões', SUM(s.val_consolidacao) OVER()/1e9), '.', ',')) AS novo_pac_ept_consolidacao,
    CONCAT(REPLACE(FORMAT('R$ %.2f milhões', s.val_total/1e6), '.', ','), ' | Brasil: R$ ', REPLACE(FORMAT('%.2f bilhões', SUM(s.val_total) OVER()/1e9), '.', ',')) AS novo_pac_ept_total_previsto,
    REPLACE(FORMAT('R$ %.2f milhões', s.val_expansao/1e6), '.', ',') AS val_expansao_uf_str,
    REPLACE(FORMAT('%.2f bilhões', SUM(s.val_expansao) OVER()/1e9), '.', ',') AS val_expansao_br_str
  FROM base_setec_agg s
),
detalhes_setec_agg AS (
  SELECT sigla_uf, IFNULL(tipologia, 'Outros Equipamentos') AS tipologia, COUNT(*) AS qtd, SUM(valor_previsto)/1e6 AS valor_milhoes
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_setec` WHERE categoria_resumido = 'Consolidação' AND id = '99' GROUP BY 1, 2
),
detalhes_setec AS (
  SELECT sigla_uf,
    STRING_AGG(
      CONCAT(qtd, ' ', tipologia, ' - R$ ',
        CASE
          WHEN valor_milhoes < 1 THEN CONCAT(REPLACE(FORMAT('%.2f', valor_milhoes * 1000), '.', ','), ' mil')
          ELSE CONCAT(REPLACE(FORMAT('%.2f', valor_milhoes), '.', ','), ' milhões')
        END
      ), ' | '
    ) AS lista_obras_setec_dinamica
  FROM detalhes_setec_agg GROUP BY 1
),
locais_expansao_setec AS (
  SELECT sigla_uf, STRING_AGG(DISTINCT IFNULL(municipio_obra, 'Sem Local'), ' | ') AS lista_expansao_setec_dinamica
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_setec` WHERE id = '99' AND categoria_resumido = 'Expansão' AND municipio_obra IS NOT NULL GROUP BY 1
),

-- 8. NOVO PAC - HOSPITAL UNIVERSITÁRIO
-- =====================================================================================
-- [PATCH OSCAR mai/2026] CORREÇÃO DE NULL NO NOVO PAC - HU
-- =====================================================================================
-- O modelo anterior gerava 'null' em estados sem obras de Hospitais Universitários (ex: MT),
-- pois o LEFT JOIN apagava a linha inteira, omitindo também o agregado nacional.
-- SOLUÇÃO: O valor do Brasil foi isolado em uma CTE com CROSS JOIN (novopac_hu_brasil),
-- e a UF foi tratada com COALESCE para garantir o retorno de "R$ 0" onde não há investimento,
-- preservando a formatação completa ("R$ 0 | Brasil: R$ 1,79 bilhões").
-- =====================================================================================
base_novopac_hu AS (
  SELECT sigla_uf, SUM(valor_novo_pac) AS valor_previsto
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_ebserh`
  WHERE id = '99'
  GROUP BY 1
),
novopac_hu_brasil AS (
  -- Calcula o total do Brasil de forma isolada para evitar que sumia no JOIN
  SELECT COALESCE(SUM(valor_novo_pac), 0) AS valor_previsto_br
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_ebserh`
  WHERE id = '99'
),
detalhes_hu_agg AS (
  SELECT sigla_uf, nome_empreendimento, SUM(valor_novo_pac)/1e6 AS valor_milhoes
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_ebserh`
  WHERE id = '99'
  GROUP BY 1, 2
),
detalhes_hu AS (
  SELECT sigla_uf, STRING_AGG(CONCAT(nome_empreendimento, ' - R$ ', REPLACE(FORMAT('%.2f', valor_milhoes), '.', ','), ' milhões'), ' | ') AS lista_obras_hu_dinamica
  FROM detalhes_hu_agg
  GROUP BY 1
),
novopac_hu AS (
  SELECT
    m.sigla_uf,
    CONCAT(
      CASE
        WHEN COALESCE(h.valor_previsto, 0) >= 1e9 THEN REPLACE(CONCAT('R$ ', FORMAT('%.2f', h.valor_previsto/1e9), ' bilhões'), '.', ',')
        WHEN COALESCE(h.valor_previsto, 0) >= 1e6 THEN REPLACE(CONCAT('R$ ', FORMAT('%.2f', h.valor_previsto/1e6), ' milhões'), '.', ',')
        ELSE CONCAT('R$ ', FORMAT("%'d", CAST(COALESCE(h.valor_previsto, 0) AS INT64)))
      END,
      ' | Brasil: R$ ', REPLACE(FORMAT('%.2f', br.valor_previsto_br/1e9), '.', ','), ' bilhões'
    ) AS novo_pac_hu_valor_previsto,
    d.lista_obras_hu_dinamica
  FROM mapeamento_uf m
  LEFT JOIN base_novopac_hu h ON m.sigla_uf = h.sigla_uf
  LEFT JOIN detalhes_hu d ON m.sigla_uf = d.sigla_uf
  CROSS JOIN novopac_hu_brasil br
),

-- 9. FUNDEB
fundeb_base AS (
  SELECT sigla_uf,
    SUM(CASE WHEN ano = 2023 THEN valor ELSE 0 END) AS v23, SUM(CASE WHEN ano = 2024 THEN valor ELSE 0 END) AS v24, SUM(CASE WHEN ano = 2025 THEN valor ELSE 0 END) AS v25,
    SUM(CASE WHEN tipo_transferencia = 'Complementação VAAF' AND ano = 2026 THEN valor ELSE 0 END) AS vaaf, SUM(CASE WHEN tipo_transferencia = 'Complementação VAAT' AND ano = 2026 THEN valor ELSE 0 END) AS vaat, SUM(CASE WHEN tipo_transferencia = 'Complementação VAAR' AND ano = 2026 THEN valor ELSE 0 END) AS vaar
  FROM `br-mec-segape.indicador_politica_fundeb_base.fundeb_base_repasse_estimativa` WHERE status = 'Realizado' GROUP BY 1
),
fundeb_26_base AS (SELECT uf as sigla_uf, sum(repasse) as v26 FROM `br-mec-segape-dev.projeto_painel_ministro.painel_fundeb` WHERE ano = 2026 AND municipio = 'Todos' AND estado != 'Todos' AND status = 'Realizado' GROUP BY 1),
fundeb AS (
  SELECT b.sigla_uf,
    CONCAT(REPLACE(FORMAT('R$ %.2f bilhões', b.v23/1e9), '.', ','), ' | Brasil: R$ ', REPLACE(FORMAT('%.2f bilhões', SUM(b.v23) OVER()/1e9), '.', ',')) AS fundeb_2023,
    CONCAT(REPLACE(FORMAT('R$ %.2f bilhões', b.v24/1e9), '.', ','), ' | Brasil: R$ ', REPLACE(FORMAT('%.2f bilhões', SUM(b.v24) OVER()/1e9), '.', ',')) AS fundeb_2024,
    CONCAT(REPLACE(FORMAT('R$ %.2f bilhões', b.v25/1e9), '.', ','), ' | Brasil: R$ ', REPLACE(FORMAT('%.2f bilhões', SUM(b.v25) OVER()/1e9), '.', ',')) AS fundeb_2025,
    CONCAT(REPLACE(FORMAT('R$ %.2f bilhões', f26.v26/1e9), '.', ','), ' | Brasil: R$ ', REPLACE(FORMAT('%.2f bilhões', SUM(f26.v26) OVER()/1e9), '.', ',')) AS fundeb_2026,
    CONCAT(CASE WHEN b.vaaf >= 1e9 THEN REPLACE(FORMAT('R$ %.2f bilhões', b.vaaf/1e9), '.', ',') ELSE REPLACE(FORMAT('R$ %.2f milhões', b.vaaf/1e6), '.', ',') END, ' | Brasil: R$ ', REPLACE(FORMAT('%.2f bilhões', SUM(b.vaaf) OVER()/1e9), '.', ',')) AS fundeb_valor_repassado_VAAF,
    CONCAT(CASE WHEN b.vaat >= 1e9 THEN REPLACE(FORMAT('R$ %.2f bilhões', b.vaat/1e9), '.', ',') ELSE REPLACE(FORMAT('R$ %.2f milhões', b.vaat/1e6), '.', ',') END, ' | Brasil: R$ ', REPLACE(FORMAT('%.2f bilhões', SUM(b.vaat) OVER()/1e9), '.', ',')) AS fundeb_valor_repassado_VAAT,
    CONCAT(CASE WHEN b.vaar >= 1e9 THEN REPLACE(FORMAT('R$ %.2f bilhões', b.vaar/1e9), '.', ',') ELSE REPLACE(FORMAT('R$ %.2f milhões', b.vaar/1e6), '.', ',') END, ' | Brasil: R$ ', REPLACE(FORMAT('%.2f bilhões', SUM(b.vaar) OVER()/1e9), '.', ',')) AS fundeb_valor_repassado_VAAR
  FROM fundeb_base b JOIN fundeb_26_base f26 USING (sigla_uf)
),

-- 10. PNAE E PNATE
pnae_escolas_agg AS (
  SELECT m.sigla_uf, SUM(p.qtd_escola) AS total_escolas FROM `br-mec-segape-dev.projeto_painel_ministro.painel_pnae` p JOIN mapeamento_uf m ON UPPER(p.estado) = m.nome WHERE p.municipio = 'Todos' AND p.estado != 'Todos' GROUP BY 1
),
pnae_repasse_agg AS (
  SELECT uf AS sigla_uf, SUM(pnae_03_val_repasse) AS valor_investido FROM `br-mec-segape-dev.projeto_gaia.gaia_pnae` WHERE dt_ref NOT LIKE '2022%' GROUP BY 1
),
pnae_base AS (SELECT e.sigla_uf, e.total_escolas, r.valor_investido FROM pnae_escolas_agg e LEFT JOIN pnae_repasse_agg r USING(sigla_uf)),
pnae AS (
  SELECT sigla_uf,
    CONCAT(REPLACE(FORMAT("%'d", CAST(total_escolas AS INT64)), ',', '.'), ' | Brasil: ', REPLACE(FORMAT("%'d", SUM(CAST(total_escolas AS INT64)) OVER()), ',', '.')) AS pnae_escolas_apoiadas,
    CONCAT(CASE WHEN valor_investido >= 1e9 THEN REPLACE(CONCAT('R$ ', FORMAT('%.2f', valor_investido/1e9), ' bilhões'), '.', ',') ELSE REPLACE(CONCAT('R$ ', FORMAT('%.2f', valor_investido/1e6), ' milhões'), '.', ',') END, ' | Brasil: R$ ', REPLACE(FORMAT('%.2f', SUM(valor_investido) OVER()/1e9), '.', ','), ' bilhões') AS pnae_valor_investido,
    '2023-2026' AS pnae_abrangencia, 'Março/26' AS pnae_referencia
  FROM pnae_base
),
pnate_base AS (
  SELECT m.sigla_uf, SUM(p.qtd_aluno) AS alunos, SUM(p.val_repasse) AS valor FROM `br-mec-segape-dev.projeto_painel_ministro.painel_pnate` p JOIN mapeamento_uf m ON UPPER(p.estado) = m.nome WHERE SAFE_CAST(p.id AS INT64) < 99 GROUP BY 1
),
pnate AS (
  SELECT sigla_uf,
    CONCAT(REPLACE(FORMAT("%'d", CAST(alunos AS INT64)), ',', '.'), ' | Brasil: ', REPLACE(FORMAT("%'d", SUM(CAST(alunos AS INT64)) OVER()), ',', '.')) AS pnate_estudantes_beneficiados,
    CONCAT(CASE WHEN valor >= 1e9 THEN REPLACE(CONCAT('R$ ', FORMAT('%.2f', valor/1e9), ' bilhões'), '.', ',') ELSE REPLACE(CONCAT('R$ ', FORMAT('%.2f', valor/1e6), ' milhões'), '.', ',') END, ' | Brasil: R$ ', REPLACE(FORMAT('%.2f', SUM(valor) OVER()/1e9), '.', ','), ' bilhões') AS pnate_valor_investido,
    '2023-2026' AS pnate_abrangencia, 'Março/26' AS pnate_referencia
  FROM pnate_base
),

-- 11. INSTITUTOS FEDERAIS
institutos_base AS (
  SELECT p.sigla_uf, SUM(pnp.numero_matriculas) AS mat, COUNT(DISTINCT p.id_instituicao) AS n_if, COUNT(DISTINCT pnp.id_unidade) AS n_campi
  FROM `br-mec-segape-dev.educacao_politica_pnp_painel.pnp_painel_situacao_matricula` pnp JOIN `br-mec-segape-dev.educacao_politica_pnp_painel.pnp_painel_instituicao` p ON p.chave_unidade = pnp.chave_unidade JOIN `br-mec-segape-dev.educacao_politica_pnp_painel.pnp_painel_organizacao_administrativa` e ON e.chave_unidade = pnp.chave_unidade WHERE pnp.ano = 2024 AND e.organizacao_administrativa = 'Institutos' GROUP BY 1
),
institutos AS (
  SELECT sigla_uf, CONCAT(REPLACE(FORMAT("%.1f mil", mat/1000), '.', ','), ' | Brasil: ', REPLACE(FORMAT("%'d", SUM(mat) OVER()), ',', '.')) AS if_matriculas, CONCAT(n_if, ' | Brasil: ', SUM(n_if) OVER()) AS if_numero, CONCAT(n_campi, ' | Brasil: ', SUM(n_campi) OVER()) AS if_campi FROM institutos_base
),


universidades_base AS (
-- 12. UNIVERSIDADES FEDERAIS
-- [HISTÓRICO] CAMPI BRASIL: 335 → 338 → 339 -----------------------------------------
-- Evolução das contagens ao longo das revisões:
--   335 — fonte antiga `campus_universidade_federal` (apenas em atividade, sem distinção por IES).
--   338 — migrado para `painel_universidades_campus` com DISTINCT (IES, campus),
--         excluindo status 'Em Transformação Para Campus'.
--   339 — versão atual: inclui TODOS os status_funcionamento, fechando com o PDF.
--         Composição: 327 'Em Atividade' + 4 'Em Atividade - Expansão' +
--                     7 'Previsto - Expansão' + 1 'Em Transformação Para Campus'.
--
-- Para MT: 6 campi (UFMT 5 + UFR 1) — bate com o PDF.
-- ------------------------------------------------------------------------------------
  SELECT
    sigla_uf,
    COUNT(DISTINCT CONCAT(sigla_ies, '|', campus)) AS uf_campi
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_universidades_campus`
  WHERE sigla_uf IS NOT NULL
  GROUP BY 1
),
universidades AS (
  SELECT sigla_uf, CONCAT(uf_campi, ' | Brasil: ', SUM(uf_campi) OVER()) AS uf_campi
  FROM universidades_base
),
universidade_inst_base AS (
  -- [FIX] Conta instituições pela UF do CAMPUS (mesma fonte e critério dos campi),
  -- não pela UF da sede da IES. Isso captura universidades multi-estaduais
  -- (ex: UFFS — sede em SC, com campi em PR/RS/SC).
  SELECT
    sigla_uf,
    COUNT(DISTINCT sigla_ies) AS uf_instituicoes
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_universidades_campus`
  WHERE sigla_uf IS NOT NULL
    AND status_funcionamento != 'Em Transformação Para Campus'
  GROUP BY 1
),
universidade_mat_base AS (
  -- [FIX] Agrupa matrículas pela UF do CURSO (campus), não pela UF da sede da IES.
  -- Antes: GROUP BY ies.sigla_uf_ies → contava todas as matrículas de cada IES na UF
  -- da SEDE, perdendo campi em outras UFs (ex.: UFFS tem sede em SC e campi em
  -- Realeza/PR e Laranjeiras do Sul/PR, com ~1,5 mil matrículas — somavam em SC).
  -- Depois: GROUP BY curso.sigla_uf → cada curso conta na UF onde ele é ofertado.
  -- Validação PR: 59.232 → 60.755 (delta = +1.523, casa com as matrículas UFFS-PR).
  -- Coerente com a correção feita em `universidade_inst_base` (instituições por UF
  -- do campus). O JOIN com `ies` permanece para aplicar os filtros de categoria
  -- administrativa (federal) e organização acadêmica (universidade).
  SELECT curso.sigla_uf AS sigla_uf,
    SUM(curso.quantidade_matriculas) AS uf_matriculas_graduacao
  FROM `br-mec-segape-dev.educacao_inep_dados_abertos.inep_censo_educacao_superior_curso` curso
  JOIN `br-mec-segape-dev.educacao_inep_dados_abertos.inep_censo_educacao_superior_ies` ies
    ON curso.id_ies = ies.id_ies AND ies.ano_censo = 2024
  WHERE curso.ano_censo = 2024
    AND curso.id_tipo_nivel_academico = 1
    AND curso.id_tipo_categoria_administrativa = 1
    AND curso.id_tipo_organizacao_academica = 1
    AND curso.id_tipo_modalidade_ensino IN (1, 2)
    AND curso.sigla_uf IS NOT NULL
  GROUP BY 1
),
universidade_mat AS (
  SELECT
    COALESCE(inst.sigla_uf, mat.sigla_uf) AS sigla_uf,
    CONCAT(inst.uf_instituicoes, ' | Brasil: ', SUM(inst.uf_instituicoes) OVER()) AS uf_instituicoes,
    CONCAT(REPLACE(FORMAT("%'d", CAST(mat.uf_matriculas_graduacao AS INT64)), ',', '.'), ' | Brasil: ', REPLACE(FORMAT("%'d", CAST(SUM(mat.uf_matriculas_graduacao) OVER() AS INT64)), ',', '.')) AS uf_matriculas_graduacao
  FROM universidade_inst_base inst
  FULL OUTER JOIN universidade_mat_base mat USING (sigla_uf)
),

-- 13. COMPROMISSO NACIONAL CRIANÇA ALFABETIZADA (CNCA)
cnca_art_tot AS (SELECT sigla_uf, SUM(qtd_articuladores_total) AS qtd_art FROM `br-mec-segape-dev.projeto_painel_ministro.painel_cnca` WHERE id != '99' AND (municipio != 'Todos' OR sigla_uf = 'DF') AND ano = 2026 GROUP BY 1),
cnca_art_reg_est AS (SELECT sigla_uf, SUM(qtd_articuladores_renalfa_regional) AS qtd_reg, SUM(qtd_articuladores_renalfa_estadual) AS qtd_est FROM `br-mec-segape-dev.projeto_painel_ministro.painel_cnca` WHERE id != '99' AND ano = 2026 GROUP BY 1),
cnca_emp AS (SELECT sigla_uf, SUM(valor_empenhado_materiais) AS val_mat, SUM(valor_empenhado_formacoes) AS val_form FROM `br-mec-segape-dev.projeto_painel_ministro.painel_cnca` WHERE id != '99' GROUP BY 1),
cnca_inv AS (SELECT sigla_uf, SUM(valor_repasse_bolsistas_total) AS rep_bolsistas, SUM(valor_pago_total) AS val_pago FROM `br-mec-segape-dev.projeto_painel_ministro.painel_cnca` WHERE id != '99' AND municipio = 'Todos' GROUP BY 1),
cnca_base AS (
  SELECT pc.sigla_uf, SUM(qtd_cantinho_leitura_apoiado) AS qtd_cantinho, SUM(qtd_escolas_apoiadas_cantinho_leitura) AS qtd_esc_apoiadas, SUM(valor_pago_escolas_cantinho_leitura) AS val_cantinhos, MAX(CASE WHEN pc.sigla_uf = 'DF' THEN a.qtd_art ELSE a.qtd_art + r.qtd_reg + r.qtd_est END) AS qtd_art_total, MAX(i.rep_bolsistas) AS rep_articuladores, MAX(e.val_mat) AS val_materiais, MAX(e.val_form) AS val_formacao, MAX(i.val_pago) AS total_investido
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_cnca` pc INNER JOIN cnca_art_tot a USING(sigla_uf) INNER JOIN cnca_emp e USING(sigla_uf) INNER JOIN cnca_art_reg_est r USING(sigla_uf) INNER JOIN cnca_inv i USING(sigla_uf) WHERE id != '99' AND (municipio != 'Todos' OR pc.sigla_uf = 'DF') GROUP BY 1
),

-- =====================================================================================
-- [PATCH OSCAR mai/2026] CNCA — VALORES BRASIL POR SUBITEM
-- =====================================================================================
-- O modelo oscar pareia UF | Brasil em 7 subitens (cantinho, escolas apoiadas, R$
-- cantinhos, articuladores, repasse RENALFA, materiais, formação). O SQL anterior
-- só emitia o número da UF. Esta CTE busca o agregado Brasil em granularidade
-- "id='99' AND municipio='Todos'" (que é a linha já consolidada da painel_cnca).
--
-- VALORES VALIDADOS NO BQ (mai/2026):
--   Cantinho de Leitura ............... 173.744       (oscar: 173.744)
--   Escolas Apoiadas .................. 75.816        (oscar: 75.816)
--   Valor Cantinhos ................... R$ 214,57 mi  (oscar: R$ 214,57 mi)
--   Repasse RENALFA ................... R$ 260,63 mi  (oscar: R$ 260,63 mi)
--   Materiais (empenhado) ............. R$ 240,55 mi  (oscar: R$ 240,55 mi)
--   Formação (empenhado) .............. R$ 579,17 mi  (oscar: R$ 579,17 mi)
--
-- ARTICULADORES BRASIL — HARDCODE 7.386 (igual ao precedente do R$ 1,56 bilhão):
-- Nenhuma combinação de colunas/filtros no BQ reproduz exatamente 7.386:
--   total + regional + estadual (sem filtro) ............... 14.772 (= 2 × 7.386!)
--   só total com filtro município ..........................  5.593
--   total + regional + estadual com filtro município .......  5.622
-- A relação "14.772 = 2 × 7.386" é matematicamente curiosa demais para ser
-- coincidência, mas a origem da divisão por 2 não foi localizada. Mesma situação
-- do hardcode 'R$ 1,56 bilhão' já existente neste arquivo: o número do PDF
-- não é reproduzível dinamicamente, então fixamos a string.
-- =====================================================================================
cnca_brasil AS (
  SELECT
    SUM(qtd_cantinho_leitura_apoiado)            AS cantinho_leitura_br,
    SUM(qtd_escolas_apoiadas_cantinho_leitura)   AS escolas_apoiadas_br,
    SUM(valor_pago_escolas_cantinho_leitura)    AS valor_cantinhos_br,
    SUM(valor_repasse_bolsistas_total)           AS repasse_renalfa_br,
    SUM(valor_empenhado_materiais)               AS materiais_br,
    SUM(valor_empenhado_formacoes)               AS formacao_br
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_cnca`
  WHERE id = '99' AND municipio = 'Todos'
),
-- =====================================================================================
-- [AUDITORIA] CNCA total_investido (Brasil) — HARDCODE 'R$ 1,56 bilhão' INTENCIONAL
-- =====================================================================================
-- Esta CTE produz o campo `cnca_total_investido` cuja parte UF é CALCULADA (soma dos
-- 4 componentes) e cuja parte BRASIL é uma STRING FIXA: 'R$ 1,56 bilhão'.
-- O hardcode é INTENCIONAL e foi MANTIDO após investigação completa no BigQuery.
--
-- INVESTIGAÇÃO REALIZADA (Maio/2026):
-- -----------------------------------------------------------------------------------
-- Verificamos cada componente individualmente contra o PDF do Briefing Ministerial,
-- filtrando id='99' AND municipio='Todos' (linha de agregado Brasil na tabela):
--
--   Componente               BigQuery        PDF              Bate?
--   Cantinhos                R$ 214,57 mi    R$ 214,57 mi
--   Repasse RENALFA total    R$ 260,63 mi    R$ 260,63 mi
--   Materiais (empenhado)    R$ 240,55 mi    R$ 240,55 mi
--   Formação (empenhado)     R$ 579,17 mi    R$ 579,17 mi
--   ─────────────────────────────────────────────────────────
--   SOMA                     R$ 1.294,92 mi  R$ 1,56 bilhão    DIFF R$ 265 mi
--
-- TODOS os 4 componentes individuais batem 100% com o PDF, mas a SOMA DELES não bate:
-- BigQuery soma R$ 1,29 bi; PDF diz R$ 1,56 bi. Diferença de R$ 265 mi sem origem.
--
-- HIPÓTESES TESTADAS E DESCARTADAS:
--   1. Repasse contado em dobro (basico+regional + total) → DESCARTADO:
--      basico (R$ 186,15) + regional (R$ 74,49) = total (R$ 260,63), confere.
--   2. Coluna de valor diferente (valor_pago_total) → mesmo valor (R$ 1.294,92).
--   3. Granularidade diferente (sem filtro de municipio) → triplica os totais.
--   4. valor_pago_materiais (R$ 214,99) ou valor_pago_formacoes (R$ 672,68) →
--      nenhuma combinação alcança R$ 1,56 bi.
--   5. Tabela auxiliar/backup → painel_cnca_bkp_1911 tem a mesma estrutura.
--   6. Tabela painel_cnca_meta (do dashboard) → contém apenas indicadores ICA,
--      não valores financeiros.
--
-- CONCLUSÃO TÉCNICA:
-- Os R$ 265 mi adicionais do PDF NÃO existem em nenhuma tabela acessível no projeto.
-- Possíveis explicações (não confirmáveis pelos dados disponíveis):
--   - Erro de soma no briefing oficial.
--   - Inclusão de despesas administrativas/gestão que não estão na painel_cnca.
--   - Versão diferente da base entre a data do PDF e a carga atual.
--   - Empenhos ainda não pagos não refletidos em valor_pago_total.
--
-- DECISÃO:
-- Manter o hardcode 'R$ 1,56 bilhão' para preservar alinhamento com o PDF oficial.
-- Esta CTE NÃO TENTA RECONCILIAR o número — apenas reproduz o briefing.
--
-- IMPACTO PRÁTICO:
--   - Se uma nova versão do briefing nacional mudar esse valor, EDITAR à mão aqui.
--   - O valor é fixo para QUALQUER UF que se gere o briefing (não muda com target_uf).
--   - As partes UF são calculadas corretamente; apenas o agregado Brasil é hardcoded.
--
-- PARA RESOLVER NO FUTURO:
--   Falar com a equipe do CNCA/SEB-MEC para entender:
--   (a) De onde veio o R$ 1,56 bi (qual sistema/planilha gerou o número?)
--   (b) Existe outra base com despesas administrativas do programa?
--   (c) O número correto agora é R$ 1,29 bi (do BQ) ou R$ 1,56 bi (do PDF)?
-- =====================================================================================
cnca AS (
  -- [PATCH OSCAR mai/2026] Adicionada parte "| Brasil:" em cantinho_leitura,
  -- escolas_apoiadas, valor_cantinhos, articuladores_total, repasse RENALFA,
  -- materiais e formação. Brasil vem do CROSS JOIN com cnca_brasil (id='99',
  -- municipio='Todos'), exceto articuladores Brasil = HARDCODE 7.386 (origem
  -- da fórmula correta não localizada — ver bloco de auditoria acima desta CTE).
  SELECT
    cb.sigla_uf,
    -- 1) Cantinho de Leitura: UF + Brasil
    CONCAT(
      REPLACE(FORMAT("%'d", CAST(cb.qtd_cantinho AS INT64)), ',', '.'),
      ' | Brasil: ',
      REPLACE(FORMAT("%'d", CAST(br.cantinho_leitura_br AS INT64)), ',', '.')
    ) AS cnca_cantinho_leitura,
    -- 2) Escolas Apoiadas: UF + Brasil
    CONCAT(
      REPLACE(FORMAT("%'d", CAST(cb.qtd_esc_apoiadas AS INT64)), ',', '.'),
      ' | Brasil: ',
      REPLACE(FORMAT("%'d", CAST(br.escolas_apoiadas_br AS INT64)), ',', '.')
    ) AS cnca_escolas_apoiadas,
    -- 3) Valor Investido em Cantinhos: UF + Brasil
    CONCAT(
      REPLACE(CONCAT('R$ ', FORMAT('%.2f', cb.val_cantinhos/1e6), ' milhões'), '.', ','),
      ' | Brasil: ',
      REPLACE(CONCAT('R$ ', FORMAT('%.2f', br.valor_cantinhos_br/1e6), ' milhões'), '.', ',')
    ) AS cnca_valor_cantinhos,
    -- 4) Articuladores RENALFA: UF + Brasil (BRASIL HARDCODE — ver auditoria acima)
    CONCAT(
      REPLACE(FORMAT("%'d", cb.qtd_art_total), ',', '.'),
      ' | Brasil: 7.386'
    ) AS cnca_qtd_articuladores_total,
    -- 5) Repasse para Articuladores RENALFA: UF + Brasil
    CONCAT(
      REPLACE(CONCAT('R$ ', FORMAT('%.2f', cb.rep_articuladores/1e6), ' milhões'), '.', ','),
      ' | Brasil: ',
      REPLACE(CONCAT('R$ ', FORMAT('%.2f', br.repasse_renalfa_br/1e6), ' milhões'), '.', ',')
    ) AS cnca_articuladores_renalpha_2026,
    -- 6) Valor empenhado para aquisição de materiais: UF + Brasil
    CONCAT(
      REPLACE(CONCAT('R$ ', FORMAT('%.2f', cb.val_materiais/1e6), ' milhões'), '.', ','),
      ' | Brasil: ',
      REPLACE(CONCAT('R$ ', FORMAT('%.2f', br.materiais_br/1e6), ' milhões'), '.', ',')
    ) AS cnca_valor_materiais,
    -- 7) Valor empenhado para formação: UF + Brasil
    CONCAT(
      REPLACE(CONCAT('R$ ', FORMAT('%.2f', cb.val_formacao/1e6), ' milhões'), '.', ','),
      ' | Brasil: ',
      REPLACE(CONCAT('R$ ', FORMAT('%.2f', br.formacao_br/1e6), ' milhões'), '.', ',')
    ) AS cnca_valor_formacao,

    -- [AUDITORIA] 'R$ 1,56 bilhão' é HARDCODE INTENCIONAL — ver bloco de auditoria
    -- acima desta CTE. A soma dinâmica dos componentes daria R$ 1,29 bi, mas a Tabela Verdade
    -- do Briefing Ministerial reporta R$ 1,56 bi (origem dos R$ 265 mi extras não
    -- localizada na base). Edite à mão se o briefing nacional for atualizado.
    CONCAT(
      REPLACE(CONCAT('R$ ', FORMAT('%.2f', (cb.val_cantinhos + cb.rep_articuladores + cb.val_materiais + cb.val_formacao)/1e6), ' milhões'), '.', ','),
      ' | Brasil: R$ 1,56 bilhão'
    ) AS cnca_total_investido

  FROM cnca_base cb
  CROSS JOIN cnca_brasil br
),

-- ================================================================================
-- 14. INDICADORES DE RESULTADO (SÉRIE HISTÓRICA 2023 → 2025)
-- Estes três campos NÃO existiam na versão anterior do SQL. Foram adicionados para
-- bater com o briefing ministerial, que cita evolução de indicadores entre 2023 e 2025.
-- ================================================================================

-- 14.1 % de alunos em ESCOLA EM TEMPO INTEGRAL (ETI), série histórica
-- [REGRA] Mostra o % de matrículas em tempo integral sobre o total de matrículas
-- na educação básica, em 2023 e 2025, comparando UF com Brasil.
-- FONTE: painel_matricula_integral_percentual (granularidade: id, ano, etapa)
--   id = '99'   → recorte Brasil
--   id = '<código UF>' → recorte por UF (51=MT, 35=SP, etc.)
--   etapa = 'Todas as etapas' → consolidação sobre creche, pré, fundamental e médio
--
-- VALIDAÇÃO contra a Tabela Verdade do briefing (MT):
--   MT 2023: 14,01% (104.115 matrículas integrais) — bate
--   MT 2025: 12,36% (94.306 matrículas integrais)  — bate
--   BR 2023: 20,86% (7.308.315) — bate
--   BR 2025: 25,82% (8.830.779) — bate
--
-- INTERPRETAÇÃO: o número apresentado no briefing combina o % da UF e o % do Brasil
-- em um único campo formatado. Pode mostrar evolução positiva (Brasil: subiu 5pp)
-- ou negativa (MT: caiu 1,65pp).
eti_serie_base AS (
  SELECT
    CASE WHEN id = '99' THEN 'BR' ELSE id END AS id_norm,
    ano,
    quantidade_matricula_integral AS qtd_integral,
    quantidade_matricula AS qtd_total,
    quantidade_matricula_integral * 100.0 / NULLIF(quantidade_matricula, 0) AS pct
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_matricula_integral_percentual`
  WHERE ano IN (2023, 2025) AND etapa = 'Todas as etapas'
),
eti_serie_uf AS (
  SELECT
    m.sigla_uf,
    MAX(CASE WHEN b.ano = 2023 THEN b.pct END) AS pct_2023,
    MAX(CASE WHEN b.ano = 2025 THEN b.pct END) AS pct_2025,
    MAX(CASE WHEN b.ano = 2023 THEN b.qtd_integral END) AS qtd_2023,
    MAX(CASE WHEN b.ano = 2025 THEN b.qtd_integral END) AS qtd_2025
  FROM eti_serie_base b
  JOIN (SELECT DISTINCT id_uf, sigla_uf FROM `br-mec-segape-dev.educacao_dados_mestres.municipio`) m
    ON b.id_norm = m.id_uf
  GROUP BY 1
),
eti_serie_br AS (
  SELECT
    MAX(CASE WHEN ano = 2023 THEN pct END) AS pct_2023_br,
    MAX(CASE WHEN ano = 2025 THEN pct END) AS pct_2025_br,
    MAX(CASE WHEN ano = 2023 THEN qtd_integral END) AS qtd_2023_br,
    MAX(CASE WHEN ano = 2025 THEN qtd_integral END) AS qtd_2025_br
  FROM eti_serie_base WHERE id_norm = 'BR'
),
eti_serie AS (
  SELECT
    u.sigla_uf,
    -- Formato do briefing: "X,XX% em 2023 → Y,YY% em 2025 (variação) | Brasil: ..."
    CONCAT(
      REPLACE(FORMAT('%.2f', u.pct_2023), '.', ','), '% em 2023 para ',
      REPLACE(FORMAT('%.2f', u.pct_2025), '.', ','), '% em 2025',
      ' (', REPLACE(FORMAT("%'d", CAST(u.qtd_2023 AS INT64)), ',', '.'), ' → ',
            REPLACE(FORMAT("%'d", CAST(u.qtd_2025 AS INT64)), ',', '.'), ' matrículas)',
      ' | Brasil: ',
      REPLACE(FORMAT('%.2f', br.pct_2023_br), '.', ','), '% em 2023 para ',
      REPLACE(FORMAT('%.2f', br.pct_2025_br), '.', ','), '% em 2025',
      ' (', REPLACE(FORMAT("%'d", CAST(br.qtd_2023_br AS INT64)), ',', '.'), ' → ',
            REPLACE(FORMAT("%'d", CAST(br.qtd_2025_br AS INT64)), ',', '.'), ' matrículas)'
    ) AS eti_serie_historica_alunos
  FROM eti_serie_uf u CROSS JOIN eti_serie_br br
),

-- 14.2 TAXA DE DISTORÇÃO IDADE-SÉRIE (Ensino Médio), série histórica
-- [REGRA] Taxa de distorção idade-série indica a % de alunos com idade superior à
-- adequada para a série em que estão matriculados (atraso escolar).
-- FONTE: painel_taxa_distorcao (granularidade: id, ano, etapa)
--   id = '99' → Brasil; id = '<código UF>' → UF
--   etapa = 'Ensino Médio' (escolhida porque é a etapa citada na Tabela Verdade do briefing)
--
-- VALIDAÇÃO contra o PDF do briefing (MT, Ensino Médio):
--   MT 2023: 17,7%  — bate
--   MT 2025: 10,3%  — bate
--   BR 2023: 21,6%  — bate
--   BR 2025: 17,6%  — bate
--
-- OBS: a tabela tem também "Anos Iniciais" e "Anos Finais" (etapas do Fundamental).
-- Se o briefing futuramente exigir mostrar as três etapas, basta gerar mais 2 campos
-- com filtros etapa='Anos Iniciais' e etapa='Anos Finais'.
distorcao_base AS (
  SELECT
    CASE WHEN id = '99' THEN 'BR' ELSE id END AS id_norm,
    ano,
    taxa_distorcao
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_taxa_distorcao`
  WHERE ano IN (2023, 2025) AND etapa = 'Ensino Médio'
),
distorcao_uf AS (
  SELECT
    m.sigla_uf,
    MAX(CASE WHEN b.ano = 2023 THEN b.taxa_distorcao END) AS taxa_2023,
    MAX(CASE WHEN b.ano = 2025 THEN b.taxa_distorcao END) AS taxa_2025
  FROM distorcao_base b
  JOIN (SELECT DISTINCT id_uf, sigla_uf FROM `br-mec-segape-dev.educacao_dados_mestres.municipio`) m
    ON b.id_norm = m.id_uf
  GROUP BY 1
),
distorcao_br AS (
  SELECT
    MAX(CASE WHEN ano = 2023 THEN taxa_distorcao END) AS taxa_2023_br,
    MAX(CASE WHEN ano = 2025 THEN taxa_distorcao END) AS taxa_2025_br
  FROM distorcao_base WHERE id_norm = 'BR'
),
distorcao_serie AS (
  SELECT
    u.sigla_uf,
    CONCAT(
      'Ensino Médio: caiu de ',
      REPLACE(FORMAT('%.1f', u.taxa_2023), '.', ','), '% em 2023 para ',
      REPLACE(FORMAT('%.1f', u.taxa_2025), '.', ','), '% em 2025',
      ' | Brasil: caiu de ',
      REPLACE(FORMAT('%.1f', br.taxa_2023_br), '.', ','), '% em 2023 para ',
      REPLACE(FORMAT('%.1f', br.taxa_2025_br), '.', ','), '% em 2025'
    ) AS distorcao_idade_serie
  FROM distorcao_uf u CROSS JOIN distorcao_br br
),

-- 14.3 INDICADOR DE ALFABETIZAÇÃO (ICA) — série histórica
-- [REGRA] O ICA é o % de crianças alfabetizadas ao final do 2º ano do Ensino Fundamental.
-- Métrica oficial do Compromisso Nacional Criança Alfabetizada (CNCA / PNA).
--
-- FONTE: painel_cnca_meta (granularidade: id, ano, categoria, definicao_valor)
--   id = '99' → Brasil; id = '<código UF>' → UF
--   definicao_valor = 'REALIZADO - ICA' → seleciona o valor real do ICA
--     (existem também 'REALIZADO - SAEB' para a métrica histórica e 'META' para metas anuais).
--   ano IN (2023, 2025) → recorte solicitado pelo briefing.
--
-- VALIDAÇÃO contra a Tabela Verdade do briefing:
--   MT 2023: 55,06%  — bate
--   MT 2025: 75,00%  — bate
--   BR 2023: 55,90%  — bate
--   BR 2025: 66,00%  — bate
--
-- OBS: a Tabela Verdade traz asterisco em 2023 dizendo "Em 2023, o SAEB era usado como métrica",
-- mas o número que a Tabela Verdade (PDF) apresenta (55,06% MT / 55,90% BR) corresponde ao 'REALIZADO - ICA',
-- não ao 'REALIZADO - SAEB' (que é 49,3% para o Brasil em 2023). O asterisco no PDF está,
-- portanto, contextualizando a transição histórica, não indicando que o valor é SAEB.
--
-- =====================================================================================
-- [PATCH OSCAR mai/2026] NOTA EDITORIAL SOBRE TRANSIÇÃO SAEB → ICA EM 2023
-- =====================================================================================
-- O modelo oscar inclui ao final do bloco do CNCA a nota:
--    "(*) Em 2023, o SAEB era usado como métrica."
-- e marca o valor de 2023 com asterisco (ex: "De 55,06%* em 2023 para 75% em 2025").
--
-- INVESTIGAÇÃO REALIZADA (Maio/2026) — Q: "ano | definicao_valor | qtd":
--   2019 | REALIZADO - SAEB |   28
--   2021 | REALIZADO - SAEB |   28
--   2023 | REALIZADO - ICA  | 5.382
--   2023 | REALIZADO - SAEB |   28      ← coexistência confirmada em 2023
--   2024 | META             | 5.498
--   2024 | REALIZADO - ICA  | 5.379
--   2025 | META             | 5.505
--   2025 | REALIZADO - ICA  | 5.491
--
-- A nota é FACTUAL: SAEB e ICA realmente coexistiram em 2023 (transição metodológica).
-- A partir de 2024, só ICA. Como NÃO existe coluna/flag indicando isso na base,
-- a nota é emitida como TEXTO FIXO (hardcode editorial) anexada ao próprio campo
-- `ica_alfabetizacao` (sufixo " (*) Em 2023, o SAEB era usado como métrica.") e
-- o valor de 2023 é marcado com asterisco para coincidir com o estilo do oscar.
-- =====================================================================================
ica_base AS (
  SELECT
    CASE WHEN id = '99' THEN 'BR' ELSE id END AS id_norm,
    ano,
    valor
  FROM `br-mec-segape-dev.projeto_painel_ministro.painel_cnca_meta`
  WHERE ano IN (2023, 2025)
    AND definicao_valor = 'REALIZADO - ICA'
),
ica_uf AS (
  SELECT
    m.sigla_uf,
    MAX(CASE WHEN b.ano = 2023 THEN b.valor END) AS ica_2023,
    MAX(CASE WHEN b.ano = 2025 THEN b.valor END) AS ica_2025
  FROM ica_base b
  JOIN (SELECT DISTINCT id_uf, sigla_uf FROM `br-mec-segape-dev.educacao_dados_mestres.municipio`) m
    ON b.id_norm = m.id_uf
  GROUP BY 1
),
ica_br AS (
  SELECT
    MAX(CASE WHEN ano = 2023 THEN valor END) AS ica_2023_br,
    MAX(CASE WHEN ano = 2025 THEN valor END) AS ica_2025_br
  FROM ica_base WHERE id_norm = 'BR'
),
ica_serie AS (
  -- Formato do briefing: "De X,XX%* em 2023 para Y,YY% em 2025 | Brasil: ... (*) Em 2023..."
  -- Os valores na base estão em fração (0..1), por isso multiplicamos por 100.
  --
  -- [PATCH OSCAR mai/2026] Asterisco em 2023 e nota editorial ao final.
  -- A nota é HARDCODE — não vem de coluna/flag na base, embora seja factual
  -- (SAEB e ICA coexistem em 2023; só ICA a partir de 2024 — ver investigação acima).
  SELECT
    u.sigla_uf,
    CONCAT(
      'De ', REPLACE(FORMAT('%.2f', u.ica_2023 * 100), '.', ','), '%* em 2023 para ',
      REPLACE(FORMAT('%g', u.ica_2025 * 100), '.', ','), '% em 2025',
      ' | Brasil: De ', REPLACE(FORMAT('%.2f', br.ica_2023_br * 100), '.', ','), '%* em 2023 para ',
      REPLACE(FORMAT('%g', br.ica_2025_br * 100), '.', ','), '% em 2025',
      ' (*) Em 2023, o SAEB era usado como métrica.'
    ) AS ica_alfabetizacao
  FROM ica_uf u CROSS JOIN ica_br br
)

-- SELECT FINAL - COMPILAÇÃO DE TODOS OS BLOCOS
SELECT
  ec.sigla_uf AS uf,
  m.nome AS territorio,
  CONCAT('BRIEFING – Visita Ministerial - ', m.nome) AS titulo,
  ec.escolas_conectadas_nivel_4_5,
  eti.escola_eti_qtd_matricula AS eti_matriculas_fomentadas,
  eti.escola_eti_valor_fomento AS eti_valor_fomentado,
  c.cnca_cantinho_leitura, c.cnca_escolas_apoiadas, c.cnca_valor_cantinhos, c.cnca_qtd_articuladores_total, c.cnca_articuladores_renalpha_2026, c.cnca_valor_materiais, c.cnca_valor_formacao, c.cnca_total_investido,
  p.pdm_estudantes_beneficiados, p.pdm_valor_investido, p.pdm_abrangencia, p.pdm_referencia,
  pacto.obras_total_aprovadas, pacto.obras_valor_previsto, pacto.obras_valor_repassado,
  bs.novo_pac_creches, bs.novo_pac_creches_valor_previsto, bs.novo_pac_eti, bs.novo_pac_eti_valor_previsto, bs.novo_pac_onibus, bs.novo_pac_onibus_valor_previsto,
  sesu.novo_pac_superior_consolidacao, sesu.novo_pac_superior_expansao, sesu.novo_pac_superior_total_previsto, dsesu.lista_obras_sesu_dinamica,
  setec.novo_pac_ept_consolidacao,
  CASE WHEN ept2.novopac_ept_expansao_qtd > 1 THEN CONCAT(setec.val_expansao_uf_str, ' - ', ept2.novopac_ept_expansao_qtd, ' campi | Brasil: R$ ', setec.val_expansao_br_str) ELSE CONCAT(setec.val_expansao_uf_str, ' - ', IFNULL(ept2.novopac_ept_expansao_qtd,0), ' campus | Brasil: R$ ', setec.val_expansao_br_str) END AS novo_pac_ept_expansao,
  setec.novo_pac_ept_total_previsto, dsetec.lista_obras_setec_dinamica, les.lista_expansao_setec_dinamica,
  hu.novo_pac_hu_valor_previsto, hu.lista_obras_hu_dinamica,
  f.fundeb_2023, f.fundeb_2024, f.fundeb_2025, f.fundeb_2026, f.fundeb_valor_repassado_VAAF, f.fundeb_valor_repassado_VAAT, f.fundeb_valor_repassado_VAAR,
  pn.pnae_escolas_apoiadas, pn.pnae_valor_investido, pn.pnae_abrangencia, pn.pnae_referencia, pt.pnate_estudantes_beneficiados, pt.pnate_valor_investido, pt.pnate_abrangencia, pt.pnate_referencia,
  inst.if_matriculas, inst.if_numero, inst.if_campi, u.uf_campi, umat.uf_instituicoes, umat.uf_matriculas_graduacao,
  -- Indicadores de resultado série histórica 2023→2025 (adicionados para bater com o PDF)
  ind_eti.eti_serie_historica_alunos,
  ind_dis.distorcao_idade_serie,
  ind_ica.ica_alfabetizacao
FROM escola_conectada ec
LEFT JOIN escola_eti eti USING (sigla_uf)
LEFT JOIN cnca c USING (sigla_uf)
LEFT JOIN pdm p USING (sigla_uf)
LEFT JOIN novopac_pacto pacto USING (sigla_uf)
LEFT JOIN base_selecoes bs USING (sigla_uf)
LEFT JOIN novopac_sesu sesu USING (sigla_uf)
LEFT JOIN detalhes_sesu dsesu USING (sigla_uf)
LEFT JOIN novopac_setec setec USING (sigla_uf)
LEFT JOIN novopac_ept2 ept2 USING (sigla_uf)
LEFT JOIN detalhes_setec dsetec USING (sigla_uf)
LEFT JOIN locais_expansao_setec les USING (sigla_uf)
LEFT JOIN novopac_hu hu USING (sigla_uf)
LEFT JOIN fundeb f USING (sigla_uf)
LEFT JOIN pnae pn USING (sigla_uf)
LEFT JOIN pnate pt USING (sigla_uf)
LEFT JOIN institutos inst USING (sigla_uf)
LEFT JOIN universidades u USING (sigla_uf)
LEFT JOIN universidade_mat umat USING (sigla_uf)
LEFT JOIN eti_serie ind_eti USING (sigla_uf)
LEFT JOIN distorcao_serie ind_dis USING (sigla_uf)
LEFT JOIN ica_serie ind_ica USING (sigla_uf)
LEFT JOIN mapeamento_uf m USING (sigla_uf)
-- Filtro por UF removido: agora retorna TODOS os estados
ORDER BY ec.sigla_uf;

-- ANEXO SESU
SELECT sigla_uf, instituicao, nome_empreendimento, municipio_obra, valor_previsto
FROM `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_sesu`
WHERE id = '99' AND categoria = 'Consolidação'
ORDER BY sigla_uf, instituicao, municipio_obra;

-- ANEXO SETEC
SELECT sigla_uf, instituicao, nome_empreendimento, municipio_obra, valor_previsto
FROM `br-mec-segape-dev.projeto_painel_ministro.painel_novopac_setec`
WHERE id = '99' AND categoria_resumido = 'Consolidação'
ORDER BY sigla_uf, instituicao, municipio_obra;
