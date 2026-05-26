"""Mapeamento de linhagem: tabela painel -> fontes upstream.

Para cada tabela do dashboard, define as fontes intermediarias (camada 2)
onde o dado pode ser verificado. Usado pelo validador com --upstream.
"""

import logging
from typing import Optional

import config
from executor_bq import ExecutorBQ

logger = logging.getLogger(__name__)

PROJETO = config.PROJETO_BQ

LINHAGEM: dict[str, list[dict]] = {
    "painel_escola": [
        {
            "nome": "censo_escolar_escola",
            "gcp": f"{PROJETO}.educacao_inep_dados_abertos.censo_escolar_escola",
            "coluna_municipio": "id_municipio",
            "formato": "ibge",
            "descricao": "Censo Escolar INEP (source direto)",
        },
    ],
    "painel_matricula_municipio": [
        {
            "nome": "censo_escolar_escola",
            "gcp": f"{PROJETO}.educacao_inep_dados_abertos.censo_escolar_escola",
            "coluna_municipio": "id_municipio",
            "formato": "ibge",
            "descricao": "Censo Escolar INEP (source direto)",
        },
    ],
    "painel_pneerq_infraestrutura_escolar": [
        {
            "nome": "censo_escolar_escola",
            "gcp": f"{PROJETO}.educacao_inep_dados_abertos.censo_escolar_escola",
            "coluna_municipio": "id_municipio",
            "formato": "ibge",
            "descricao": "Censo Escolar INEP (source direto)",
        },
    ],
    "painel_cnca": [
        {
            "nome": "gaia_cnca",
            "gcp": f"{PROJETO}.projeto_gaia.gaia_cnca",
            "coluna_municipio": "cod_ibge",
            "formato": "ibge",
            "descricao": "GAIA - Compromisso Nacional Crianca Alfabetizada",
        },
    ],
    "painel_cnca_investimento": [
        {
            "nome": "painel_cnca",
            "gcp": f"{PROJETO}.projeto_painel_ministro.painel_cnca",
            "coluna_municipio": "id_municipio",
            "formato": "ibge",
            "descricao": "Painel CNCA (camada 3 - depende dele mesmo)",
        },
    ],
    "painel_pnd_adesao": [
        {
            "nome": "simec_adesao_pnd_resposta",
            "gcp": f"{PROJETO}.educacao_politica_simec.simec_adesao_pnd_resposta",
            "coluna_municipio": "codigo_acesso",
            "formato": "ibge",
            "descricao": "SIMEC - Adesao ao Programa Nacional de Docentes",
        },
    ],
    "painel_pdmlic": [
        {
            "nome": "pdmlic_inscricao_prouni",
            "gcp": f"{PROJETO}.educacao_politica_pdmlic.pdmlic_inscricao_prouni",
            "coluna_municipio": "municipio",
            "formato": "nome",
            "descricao": "Inscricoes PROUNI do Pe-de-Meia Licenciaturas",
        },
        {
            "nome": "pdmlic_inscricao_sisu",
            "gcp": f"{PROJETO}.educacao_politica_pdmlic.pdmlic_inscricao_sisu",
            "coluna_municipio": "municipio",
            "formato": "nome",
            "descricao": "Inscricoes SISU do Pe-de-Meia Licenciaturas",
        },
    ],
    "painel_fundeb": [
        {
            "nome": "fundeb_repasse_municipio",
            "gcp": f"{PROJETO}.educacao_politica_fundeb.fundeb_repasse_municipio",
            "coluna_municipio": "id_municipio",
            "formato": "ibge",
            "descricao": "Repasses FUNDEB por municipio",
        },
    ],
    "painel_salario_educacao": [
        {
            "nome": "salario_educacao_base_repasse_estimativa",
            "gcp": f"{PROJETO}.indicador_politica_salario_educacao_base.salario_educacao_base_repasse_estimativa",
            "coluna_municipio": "id_municipio",
            "formato": "ibge",
            "descricao": "Repasses Salario Educacao (base + estimativa)",
        },
    ],
    "painel_ept_sistec": [
        {
            "nome": "sistec_ciclo_matricula",
            "gcp": f"{PROJETO}.educacao_politica_sistec.sistec_ciclo_matricula",
            "coluna_municipio": "id_municipio",
            "formato": "ibge",
            "descricao": "SISTEC - Ciclo de Matricula (Qualificacao Profissional)",
        },
    ],
    "painel_pronatec_completo": [
        {
            "nome": "gaia_pronatec_vaga",
            "gcp": f"{PROJETO}.projeto_gaia.gaia_pronatec_vaga",
            "coluna_municipio": "cod_ibge",
            "formato": "ibge",
            "descricao": "GAIA - Vagas Pronatec",
        },
    ],
    "painel_mulheresmil_completo": [
        {
            "nome": "gaia_mulheres_mil_vaga",
            "gcp": f"{PROJETO}.projeto_gaia.gaia_mulheres_mil_vaga",
            "coluna_municipio": "cod_ibge",
            "formato": "ibge",
            "descricao": "GAIA - Vagas Mulheres Mil",
        },
    ],
    "painel_sisu": [
        {
            "nome": "sisu_vaga_ofertada",
            "gcp": f"{PROJETO}.educacao_sisu_dados_abertos.sisu_vaga_ofertada",
            "coluna_municipio": "municipio_campus",
            "formato": "nome",
            "descricao": "SISU - Vagas Ofertadas",
        },
    ],
    "painel_fnde_fies_investimento": [
        {
            "nome": "fnde_fies",
            "gcp": f"{PROJETO}.educacao_politica_fnde.fnde_fies",
            "coluna_municipio": "cod_ibge",
            "formato": "ibge",
            "descricao": "FNDE - Financiamentos FIES",
        },
    ],
    "painel_novopac_pacto": [
        {
            "nome": "novopac_fnde_pacto_retomada",
            "gcp": f"{PROJETO}.educacao_politica_novopac.novopac_fnde_pacto_retomada",
            "coluna_municipio": "codigo_municipio",
            "formato": "ibge",
            "descricao": "FNDE - Pacto pela Retomada de Obras",
        },
    ],
    "painel_novopac_sesu": [
        {
            "nome": "simec_obra_monitoramento_painelbi",
            "gcp": f"{PROJETO}.educacao_politica_simec.simec_obra_monitoramento_painelbi",
            "coluna_municipio": "municipio",
            "formato": "nome",
            "descricao": "SIMEC - Monitoramento de Obras SESU",
        },
    ],
    "painel_novopac_selecoes_consolidado": [
        {
            "nome": "painel_novopac_selecoes",
            "gcp": f"{PROJETO}.projeto_painel_ministro.painel_novopac_selecoes",
            "coluna_municipio": "municipio_obra",
            "formato": "cidade - UF",
            "descricao": "Sub-modelo Selecoes Edital 1",
        },
    ],
    "painel_novopac_consolidado": [],
    "eti_valores_2025_csv": [],
}


def buscar_upstream(
    executor: ExecutorBQ,
    tabela_painel: str,
    id_municipio: str,
    municipio_formatado: str,
    ano: Optional[int] = None,
) -> list[dict]:
    """Busca dados nas fontes upstream de uma tabela do painel.

    Retorna lista de dicts com resultado de cada fonte consultada.
    """
    fontes = LINHAGEM.get(tabela_painel, [])
    if not fontes:
        return [{"fonte": "(sem linhagem mapeada)", "registros": None, "erro": None}]

    resultados = []
    for fonte in fontes:
        coluna = fonte["coluna_municipio"]
        formato = fonte["formato"]
        gcp = fonte["gcp"]

        cidade = municipio_formatado.rsplit(" - ", 1)[0] if " - " in municipio_formatado else municipio_formatado

        if formato == "ibge":
            where = f"CAST({coluna} AS STRING) = '{id_municipio}'"
        elif formato == "cidade - UF":
            where = f"{coluna} = '{municipio_formatado}'"
        elif formato == "nome":
            where = f"LOWER(CAST({coluna} AS STRING)) LIKE '%{cidade.lower()}%'"
        else:
            where = f"CAST({coluna} AS STRING) = '{id_municipio}'"

        tem_ano = fonte.get("tem_ano", False)
        if ano and tem_ano:
            where += f" AND CAST(ano AS INT64) = {ano}"

        sql = f"SELECT COUNT(*) as total FROM `{gcp}` WHERE {where}"

        resultado = {
            "fonte": fonte["nome"],
            "gcp": gcp,
            "descricao": fonte["descricao"],
            "registros": None,
            "query": sql,
            "erro": None,
        }

        try:
            rows = executor.executar(sql)
            if rows:
                resultado["registros"] = rows[0].get("total", 0)
        except Exception as exc:
            resultado["erro"] = str(exc)[:200]
            logger.warning("Erro upstream %s: %s", fonte["nome"], exc)

        resultados.append(resultado)

    return resultados


def classificar_upstream(
    registros_painel: int,
    valor_painel,
    resultados_upstream: list[dict],
) -> tuple[str, str]:
    """Classifica diagnostico com base na comparacao painel vs upstream."""
    if not resultados_upstream or resultados_upstream[0].get("registros") is None:
        if resultados_upstream and resultados_upstream[0].get("erro"):
            return "UPSTREAM_ERRO", f"Erro ao consultar fonte: {resultados_upstream[0]['erro'][:100]}"
        return "SEM_LINHAGEM", "Linhagem nao mapeada para esta tabela."

    total_upstream = sum(
        r.get("registros", 0) or 0 for r in resultados_upstream if r.get("erro") is None
    )

    if registros_painel == 0 and total_upstream == 0:
        return (
            "ZERO_CONFIRMADO_FONTE",
            "Dado ausente em TODAS as camadas. Zero e real — municipio nao participa.",
        )

    if registros_painel == 0 and total_upstream > 0:
        fontes_com_dado = [
            f"{r['fonte']}({r['registros']})" for r in resultados_upstream
            if (r.get("registros") or 0) > 0
        ]
        return (
            "PERDEU_NO_PAINEL",
            f"Dado EXISTE na fonte ({', '.join(fontes_com_dado)}) "
            f"mas NAO aparece no painel. Verificar JOINs no modelo dbt.",
        )

    try:
        valor_num = float(valor_painel) if valor_painel is not None else 0
    except (TypeError, ValueError):
        valor_num = 0

    if registros_painel > 0 and valor_num == 0 and total_upstream > 0:
        return (
            "VALOR_ZERADO_NO_PAINEL",
            f"Registros existem no painel ({registros_painel}) e na fonte ({total_upstream}), "
            f"mas o VALOR da metrica e 0. Verificar filtros/expressao.",
        )

    if total_upstream > 0:
        return "OK_CONFIRMADO_FONTE", f"Dado presente na fonte ({total_upstream} registros)."

    if registros_painel > 0 and valor_num == 0 and total_upstream == 0:
        return (
            "ZERO_CONFIRMADO_FONTE",
            "Registros esqueleto no painel (CROSS JOIN), zero confirmado na fonte.",
        )

    return "INCONCLUSIVO", "Situacao nao mapeada."


# "O que nao se pode medir nao se pode melhorar." - William Thomson (Lord Kelvin)
