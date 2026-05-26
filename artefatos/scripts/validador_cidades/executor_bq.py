"""Cliente BigQuery otimizado para validacao de metricas."""

import logging
from typing import Optional

from google.cloud import bigquery
from google.oauth2 import service_account

import config

logger = logging.getLogger(__name__)


class ExecutorBQ:
    """Executa queries no BigQuery com controle de custo."""

    def __init__(self, keyfile: Optional[str] = None, projeto: Optional[str] = None):
        self._keyfile = keyfile or str(config.KEYFILE)
        self._projeto = projeto or config.PROJETO_BQ
        self._bytes_acumulados: int = 0
        self._queries_executadas: int = 0
        self._cliente: Optional[bigquery.Client] = None

    @property
    def cliente(self) -> bigquery.Client:
        if self._cliente is None:
            credenciais = service_account.Credentials.from_service_account_file(
                self._keyfile,
                scopes=["https://www.googleapis.com/auth/cloud-platform"],
            )
            self._cliente = bigquery.Client(
                project=self._projeto, credentials=credenciais
            )
        return self._cliente

    @property
    def bytes_acumulados(self) -> int:
        return self._bytes_acumulados

    @property
    def queries_executadas(self) -> int:
        return self._queries_executadas

    def executar(self, sql: str, timeout: int = 0) -> list[dict]:
        """Executa query e retorna lista de dicts com os resultados."""
        timeout = timeout or config.TIMEOUT_SEGUNDOS

        if self._bytes_acumulados >= config.LIMITE_BYTES_SESSAO:
            raise RuntimeError(
                f"Limite de bytes atingido: {self._bytes_acumulados:,} bytes"
            )

        logger.debug("Executando: %s", sql[:200])

        job_config = bigquery.QueryJobConfig(use_legacy_sql=False)
        job = self.cliente.query(sql, job_config=job_config, timeout=timeout)
        resultados = list(job.result())

        bytes_processados = job.total_bytes_processed or 0
        self._bytes_acumulados += bytes_processados
        self._queries_executadas += 1

        logger.debug(
            "Query %d: %s bytes processados (acumulado: %s)",
            self._queries_executadas,
            f"{bytes_processados:,}",
            f"{self._bytes_acumulados:,}",
        )

        return [dict(row) for row in resultados]

    def dry_run(self, sql: str) -> int:
        """Estima bytes que serao processados sem executar."""
        job_config = bigquery.QueryJobConfig(
            use_legacy_sql=False, dry_run=True
        )
        job = self.cliente.query(sql, job_config=job_config)
        return job.total_bytes_processed or 0

    def tabela_existe(self, tabela_gcp: str) -> bool:
        """Verifica se uma tabela existe no BigQuery."""
        try:
            self.cliente.get_table(tabela_gcp)
            return True
        except Exception:
            return False

    def resumo_custo(self) -> str:
        """Retorna resumo de custo da sessao."""
        mb = self._bytes_acumulados / (1024 * 1024)
        return (
            f"{self._queries_executadas} queries, "
            f"{mb:.1f} MB processados"
        )


# "Nao ha nada tao inutil quanto fazer com grande eficiencia algo que nao deveria ser feito." - Peter Drucker
