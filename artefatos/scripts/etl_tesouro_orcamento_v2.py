"""
ETL para carga dos TXT V2 do Tesouro Gerencial no BigQuery (dataset andre_teste).

Lê 12 TXT exportados do Tesouro Gerencial, normaliza colunas, converte tipos
e faz upload para BigQuery via pandas-gbq.

Uso:
    .pipelines/bin/python scripts/etl_tesouro_orcamento_v2.py
"""

import logging
import re
import sys
from pathlib import Path

import pandas as pd
import pandas_gbq
from google.oauth2 import service_account

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger(__name__)

PROJECT_ID = "br-mec-segape-dev"
DATASET = "andre_teste"
KEYFILE = Path.home() / "Desenvolvimento/MEC/segape-andre.json"

BASE_DIR = Path.home() / "Desktop/nova_task_orcamento"
DIR_UO = BASE_DIR / "Tabela Lake - tesouro_orcamento_unidade_orcamentaria"
DIR_DESTAQUE = BASE_DIR / "Tabela Lake - tesouro_orcamento_destaque_recebido_instituicao"

COLS_UO_NORMAL = [
    "ano", "id_orgao_uge", "orgao_uge", "id_uo", "unidade_orcamentaria_uo",
    "id_resultado_lei", "resultado_lei", "id_funcao", "funcao",
    "id_subfuncao", "subfuncao", "id_programa", "programa",
    "id_acao", "acao", "id_plano_orcamentario", "plano_orcamentario",
    "id_fonte", "fonte", "id_grupo_despesa", "grupo_despesa",
    "id_elemento", "elemento", "ploa", "loa", "dotacao_atualizada", "despesa_empenhada",
]

COLS_UO_SWAPPED = [
    "ano", "id_uo", "unidade_orcamentaria_uo", "id_orgao_uge", "orgao_uge",
    "id_resultado_lei", "resultado_lei", "id_funcao", "funcao",
    "id_subfuncao", "subfuncao", "id_programa", "programa",
    "id_acao", "acao", "id_plano_orcamentario", "plano_orcamentario",
    "id_fonte", "fonte", "id_grupo_despesa", "grupo_despesa",
    "id_elemento", "elemento", "ploa", "loa", "dotacao_atualizada", "despesa_empenhada",
]

COLS_DESTAQUE_NORMAL = [
    "ano", "id_orgao_uge", "orgao_uge", "id_uo", "unidade_orcamentaria_uo",
    "id_resultado_lei", "resultado_lei", "id_funcao", "funcao",
    "id_subfuncao", "subfuncao", "id_programa", "programa",
    "id_acao", "acao", "id_plano_orcamentario", "plano_orcamentario",
    "id_fonte", "fonte", "id_grupo_despesa", "grupo_despesa",
    "id_elemento", "elemento", "destaque_recebido", "despesa_empenhada",
]

COLS_DESTAQUE_SWAPPED = [
    "ano", "id_uo", "unidade_orcamentaria_uo", "id_orgao_uge", "orgao_uge",
    "id_resultado_lei", "resultado_lei", "id_funcao", "funcao",
    "id_subfuncao", "subfuncao", "id_programa", "programa",
    "id_acao", "acao", "id_plano_orcamentario", "plano_orcamentario",
    "id_fonte", "fonte", "id_grupo_despesa", "grupo_despesa",
    "id_elemento", "elemento", "destaque_recebido", "despesa_empenhada",
]

COLS_UO_FINAL = [
    "ano", "id_orgao_uge", "orgao_uge", "id_uo", "unidade_orcamentaria_uo",
    "id_resultado_lei", "resultado_lei", "id_funcao", "funcao",
    "id_subfuncao", "subfuncao", "id_programa", "programa",
    "id_acao", "acao", "id_plano_orcamentario", "plano_orcamentario",
    "id_fonte", "fonte", "id_grupo_despesa", "grupo_despesa",
    "id_elemento", "elemento", "ploa", "loa", "dotacao_atualizada", "despesa_empenhada",
    "tipo_instituicao",
]

COLS_DESTAQUE_FINAL = [
    "ano", "id_orgao_uge", "orgao_uge", "id_uo", "unidade_orcamentaria_uo",
    "id_resultado_lei", "resultado_lei", "id_funcao", "funcao",
    "id_subfuncao", "subfuncao", "id_programa", "programa",
    "id_acao", "acao", "id_plano_orcamentario", "plano_orcamentario",
    "id_fonte", "fonte", "id_grupo_despesa", "grupo_despesa",
    "id_elemento", "elemento", "destaque_recebido", "despesa_empenhada",
    "tipo_instituicao",
]

UO_FILES = [
    ("Orçamento_Universidades_UO_2015_2025.txt", "Universidades"),
    ("Orçamento_Universidades_UO_2026.txt", "Universidades"),
    ("Orçamento_Institutos_UO_2015_2025.txt", "Institutos"),
    ("Orçamento_Institutos_UO_2026.txt", "Institutos"),
    ("Orçamento_Hospitais_UO_2015_2025.txt", "Hospitais"),
    ("Orçamento_Hospitais_UO_2026.txt", "Hospitais"),
]

DESTAQUE_FILES = [
    ("Evolução_Destaques_Recebidos_Universidades_2015_2025.txt", "Universidades"),
    ("Destaques_Recebidos_Universidades_2026.txt", "Universidades"),
    ("Evolução_Destaques_Recebidos_Institutos_2015_2025.txt", "Institutos"),
    ("Destaques_Recebidos_Institutos_2026.txt", "Institutos"),
    ("Evolução_Destaques_Recebidos_Hospitais_2015_2025.txt", "Hospitais"),
    ("Destaques_Recebidos_Hospitais_2026.txt", "Hospitais"),
]

ID_COLS = [
    "id_orgao_uge", "id_uo", "id_resultado_lei", "id_funcao",
    "id_subfuncao", "id_programa", "id_acao", "id_plano_orcamentario",
    "id_fonte", "id_grupo_despesa", "id_elemento",
]


def _parse_br_number(value: str) -> float | None:
    """Converte número formato BR (1.234,56) ou (1.234,56) para float."""
    if pd.isna(value):
        return None
    text = str(value).strip()
    if not text:
        return None
    negative = text.startswith("(") and text.endswith(")")
    if negative:
        text = text[1:-1]
    text = text.replace(".", "").replace(",", ".")
    try:
        result = float(text)
        return -result if negative else result
    except ValueError:
        return None


def _detect_column_order(filepath: Path) -> bool:
    """Retorna True se colunas UO/UGE estão invertidas (UO antes de UGE no header)."""
    with open(filepath, "r", encoding="latin-1") as f:
        for i, line in enumerate(f):
            if i == 6:
                lower = line.lower()
                uge_pos = lower.find("rgão uge") if "rgão uge" in lower.lower() else lower.find("rg")
                uo_pos = lower.find("unidade or")
                if uo_pos >= 0 and uge_pos >= 0:
                    return uo_pos < uge_pos
                return False
            if i > 6:
                break
    return False


def _read_txt(filepath: Path, expected_cols: int) -> pd.DataFrame:
    """Lê TXT do Tesouro Gerencial, pulando 8 linhas de cabeçalho."""
    df = pd.read_csv(
        filepath,
        sep="\t",
        skiprows=8,
        header=None,
        encoding="latin-1",
        dtype=str,
        on_bad_lines="warn",
    )
    df = df.iloc[:, :expected_cols]
    trailing_empty = df.iloc[:, -1].isna().all() or (df.iloc[:, -1].str.strip() == "").all()
    if df.shape[1] > expected_cols and trailing_empty:
        df = df.iloc[:, :expected_cols]
    return df


def _process_uo_file(filepath: Path, tipo: str) -> pd.DataFrame:
    """Processa um arquivo UO: lê, renomeia colunas, converte tipos."""
    logger.info("Processando UO: %s (%s)", filepath.name, tipo)
    swapped = _detect_column_order(filepath)
    col_names = COLS_UO_SWAPPED if swapped else COLS_UO_NORMAL
    if swapped:
        logger.info("  Colunas UO/UGE invertidas — normalizando")

    df = _read_txt(filepath, len(col_names))

    if df.shape[1] < len(col_names):
        logger.warning(
            "  Arquivo tem %d colunas, esperado %d. Adicionando colunas vazias.",
            df.shape[1], len(col_names),
        )
        for _ in range(len(col_names) - df.shape[1]):
            df[df.shape[1]] = None

    df.columns = col_names
    df = df[COLS_UO_NORMAL]

    valor_cols = ["ploa", "loa", "dotacao_atualizada", "despesa_empenhada"]
    for col in valor_cols:
        df[col] = df[col].apply(_parse_br_number)

    df["ano"] = pd.to_numeric(df["ano"], errors="coerce").astype("Int64")
    df["tipo_instituicao"] = tipo

    for col in ID_COLS:
        df[col] = df[col].astype(str).str.strip()

    df = df[COLS_UO_FINAL]
    df = df.dropna(subset=["ano"])

    logger.info("  Linhas: %d", len(df))
    return df


def _process_destaque_file(filepath: Path, tipo: str) -> pd.DataFrame:
    """Processa um arquivo Destaque: lê, renomeia colunas, converte tipos."""
    logger.info("Processando Destaque: %s (%s)", filepath.name, tipo)
    swapped = _detect_column_order(filepath)
    col_names = COLS_DESTAQUE_SWAPPED if swapped else COLS_DESTAQUE_NORMAL
    if swapped:
        logger.info("  Colunas UO/UGE invertidas — normalizando")

    df = _read_txt(filepath, len(col_names))

    if df.shape[1] < len(col_names):
        logger.warning(
            "  Arquivo tem %d colunas, esperado %d. Adicionando colunas vazias.",
            df.shape[1], len(col_names),
        )
        for _ in range(len(col_names) - df.shape[1]):
            df[df.shape[1]] = None

    df.columns = col_names
    df = df[COLS_DESTAQUE_NORMAL]

    valor_cols = ["destaque_recebido", "despesa_empenhada"]
    for col in valor_cols:
        df[col] = df[col].apply(_parse_br_number)

    df["ano"] = pd.to_numeric(df["ano"], errors="coerce").astype("Int64")
    df["tipo_instituicao"] = tipo

    for col in ID_COLS:
        df[col] = df[col].astype(str).str.strip()

    df = df[COLS_DESTAQUE_FINAL]
    df = df.dropna(subset=["ano"])

    logger.info("  Linhas: %d", len(df))
    return df


def _upload_to_bq(df: pd.DataFrame, table_name: str, credentials) -> None:
    """Faz upload do DataFrame para BigQuery."""
    destination = f"{DATASET}.{table_name}"
    logger.info("Upload para %s.%s (%d linhas)...", PROJECT_ID, destination, len(df))
    pandas_gbq.to_gbq(
        df,
        destination_table=destination,
        project_id=PROJECT_ID,
        credentials=credentials,
        if_exists="replace",
    )
    logger.info("Upload concluido: %s", destination)


def _validate(df: pd.DataFrame, table_name: str) -> None:
    """Validações pós-processamento."""
    logger.info("Validando %s...", table_name)

    by_year_tipo = df.groupby(["ano", "tipo_instituicao"]).size()
    logger.info("Contagem por ano/tipo:\n%s", by_year_tipo.to_string())

    valor_cols = [c for c in df.columns if c in [
        "ploa", "loa", "dotacao_atualizada", "despesa_empenhada", "destaque_recebido"
    ]]

    for col in valor_cols:
        neg = df[col].dropna()
        neg_count = (neg < 0).sum()
        if neg_count > 0:
            logger.warning("  %s: %d valores negativos", col, neg_count)

    all_null = df[valor_cols].isna().all(axis=1).sum()
    if all_null > 0:
        logger.warning("  %d linhas com TODOS os valores monetários NULL", all_null)

    logger.info("Validação concluída para %s", table_name)


def main() -> None:
    credentials = service_account.Credentials.from_service_account_file(
        str(KEYFILE),
        scopes=["https://www.googleapis.com/auth/bigquery"],
    )

    logger.info("=== Processando arquivos UO ===")
    uo_frames = []
    for filename, tipo in UO_FILES:
        filepath = DIR_UO / filename
        if not filepath.exists():
            logger.warning("Arquivo não encontrado: %s", filepath)
            continue
        uo_frames.append(_process_uo_file(filepath, tipo))

    if uo_frames:
        df_uo = pd.concat(uo_frames, ignore_index=True)
        logger.info("Total UO: %d linhas", len(df_uo))
        _validate(df_uo, "tesouro_orcamento_unidade_orcamentaria")
        _upload_to_bq(df_uo, "tesouro_orcamento_unidade_orcamentaria", credentials)

    logger.info("=== Processando arquivos Destaque ===")
    dest_frames = []
    for filename, tipo in DESTAQUE_FILES:
        filepath = DIR_DESTAQUE / filename
        if not filepath.exists():
            logger.warning("Arquivo não encontrado: %s", filepath)
            continue
        dest_frames.append(_process_destaque_file(filepath, tipo))

    if dest_frames:
        df_dest = pd.concat(dest_frames, ignore_index=True)
        logger.info("Total Destaque: %d linhas", len(df_dest))
        _validate(df_dest, "tesouro_destaque_recebido_instituicao")
        _upload_to_bq(df_dest, "tesouro_destaque_recebido_instituicao", credentials)

    logger.info("=== ETL concluído ===")


if __name__ == "__main__":
    main()

# "A riqueza consiste muito mais no desfrute do que na posse." — Aristóteles
