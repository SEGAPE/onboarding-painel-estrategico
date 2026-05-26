# Sprint 6 - Validacao Upstream: "O dado existe na fonte?"

**Status:** NAO INICIADA
**Dependencia:** Sprint 2 (scanner) + correcoes v2
**Objetivo:** Para cada metrica com valor 0 ou AUSENTE, verificar automaticamente
se o dado existe nas tabelas de origem (data lake) e identificar ONDE ele se perdeu.

## Problema

O validador hoje responde: "Andradina tem 0 vagas Pronatec".
Mas nao responde: "Isso e correto? Na fonte de dados tem vagas Pronatec pra Andradina?"

O usuario precisa saber:
- O dado NUNCA existiu na fonte (zero legitimo, nada a fazer)
- O dado EXISTE na fonte mas nao chegou ao dashboard (bug no pipeline)
- O dado EXISTIA antes mas sumiu (regressao)

## Arquitetura de Camadas

```
Camada 1: RAW (data lake)
  br-mec-segape-dev.raw_csv_*.stg_*
  br-mec-segape-dev.raw_api_*.stg_*

Camada 2: POLITICA (logica de negocio)
  br-mec-segape-dev.educacao_politica_*.*

Camada 3: PAINEL (dashboard)
  br-mec-segape-dev.projeto_painel_ministro.painel_*
```

O validador atual verifica a camada 3. Esta sprint adiciona verificacao das camadas 1 e 2.

## Fluxo Automatico

```
python validador.py --municipio "Andradina - SP" --upstream

Para cada metrica com status ZERO ou AUSENTE:
  1. Identifica tabelas fonte (via linhagem.json ou SQL do modelo)
  2. Executa COUNT na camada 2 (politica)
  3. Se zero na camada 2, executa COUNT na camada 1 (raw)
  4. Compara e classifica:
     - Camada 1 = 0, Camada 2 = 0, Camada 3 = 0 -> ZERO_CONFIRMADO_FONTE
     - Camada 1 > 0, Camada 2 = 0 -> PERDEU_NA_POLITICA (bug no JOIN educacao_politica)
     - Camada 1 > 0, Camada 2 > 0, Camada 3 = 0 -> PERDEU_NO_PAINEL (bug no JOIN painel)
     - Camada 1 > 0, Camada 2 > 0, Camada 3 > 0 -> FILTRO_EXCLUIU (filtro do dashboard)
```

## Mapeamento de Linhagem

Para cada tabela do painel, definir suas fontes upstream:

```json
{
  "painel_pronatec_completo": {
    "camada_2": {
      "tabela": "educacao_politica_gaia.gaia_pronatec_vaga",
      "coluna_municipio": "id_municipio",
      "formato": "ibge"
    },
    "camada_1": {
      "tabela": "raw_csv_gaia.stg_gaia_pronatec_vaga",
      "coluna_municipio": "id_municipio",
      "formato": "ibge"
    }
  },
  "painel_sisu": {
    "camada_2": {
      "tabela": "educacao_politica_gaia.sisu_vaga_ofertada",
      "coluna_municipio": "id_municipio",
      "formato": "ibge"
    }
  }
}
```

Nota: coluna de municipio na fonte usa id_municipio IBGE (3502101),
nao o nome formatado.

## Saida no Output (colunas adicionais)

| Coluna | Descricao |
|--------|-----------|
| fonte_camada_2 | Nome da tabela intermediaria verificada |
| registros_camada_2 | COUNT(*) na camada 2 |
| fonte_camada_1 | Nome da tabela raw verificada |
| registros_camada_1 | COUNT(*) na camada 1 |
| diagnostico_upstream | ZERO_CONFIRMADO_FONTE / PERDEU_NA_POLITICA / PERDEU_NO_PAINEL |
| camada_falha | raw / politica / painel / nenhuma |

## Exemplo de Output Completo

```
Metrica: Pronatec Vagas
Valor Dashboard: 0
Valor Script: 0
Status: ZERO_LEGITIMO

  Upstream:
    Camada 3 (painel_pronatec_completo): 0 vagas
    Camada 2 (gaia_pronatec_vaga): 0 registros
    Camada 1 (stg_gaia_pronatec_vaga): 0 registros

  Diagnostico: ZERO_CONFIRMADO_FONTE
  Explicacao: Andradina nao tem dados Pronatec em nenhuma camada.
  Acao: Nenhuma. Zero e real.

---

Metrica: SISTEC Matriculas
Valor Dashboard: 0
Valor Script: AUSENTE

  Upstream:
    Camada 3 (painel_ept_sistec): 0 registros para Andradina-SP
    Camada 2 (sistec_ciclo_matricula): 15 registros para id_municipio 3502101
    Camada 1 (stg_sistec_ciclo_matricula): 15 registros

  Diagnostico: PERDEU_NO_PAINEL
  Explicacao: Dado existe na fonte (15 registros) mas nao aparece no painel.
  Acao: Verificar JOIN em painel_ept_sistec.sql, CTE filtro_territorio.
```

## Entregas

### 6.1 linhagem.json
- [ ] Mapear fontes upstream para cada uma das 18 tabelas ativas
- [ ] Incluir nome da tabela, coluna de municipio, formato (ibge/nome)
- [ ] Gerar automaticamente parseando os SQLs em queries_originais/

### 6.2 rastreador.py
- [ ] Recebe lista de metricas com status ZERO/AUSENTE
- [ ] Para cada uma, consulta camada 2 e camada 1
- [ ] Traduz municipio entre formatos (nome -> id IBGE -> uppercase)
- [ ] Retorna resultado estruturado

### 6.3 Integracao com validador.py
- [ ] Flag --upstream no CLI
- [ ] Colunas adicionais no Output do xlsx
- [ ] Diagnostico upstream no terminal (rich)

### 6.4 Documentacao
- [ ] Atualizar README com flag --upstream
- [ ] Atualizar sprints com resultados

## Desafios

1. **Coluna de municipio muda entre camadas**: painel usa "Andradina - SP",
   politica usa "Andradina" ou id_municipio 3502101, raw pode usar codigo string.

2. **Linhagem complexa**: alguns paineis dependem de 3+ tabelas fonte
   (ex: painel_pdmlic depende de pdmlic_inscricao_prouni + pdmlic_inscricao_sisu +
   pdmlic_beneficiario).

3. **Tabelas fonte podem ter policy tags**: colunas protegidas causam Access Denied.

## Criterios de Aceite

- `python validador.py --municipio "Andradina - SP" --upstream` executa validacao completa
- Para cada ZERO/AUSENTE, mostra se o dado existe na fonte
- Classifica corretamente: ZERO_CONFIRMADO_FONTE vs PERDEU_NA_POLITICA vs PERDEU_NO_PAINEL
- Output xlsx tem colunas upstream preenchidas
- Funciona para qualquer municipio do Brasil
