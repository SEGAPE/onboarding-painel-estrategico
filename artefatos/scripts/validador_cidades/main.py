"""Ponto de entrada do Validador de Cidades.

Modo direto (flags):
    python main.py --municipio "Andradina - SP"
    python main.py --municipio "Andradina - SP" --ano 2025 --upstream
    python main.py --gerar-template
    python main.py --dry-run --municipio "Andradina - SP"

Modo interativo (sem flags):
    python main.py
"""

import argparse
import json
import logging
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

from rich.console import Console
from rich.panel import Panel
from rich.prompt import Confirm, IntPrompt, Prompt
from rich.table import Table

import config
from relatorio import gerar_xlsx, imprimir_resumo
from validador import executar_validacao

console = Console()
_ultimo_resultado: list[dict] = []


def _configurar_logging() -> None:
    """Configura logging para arquivo e terminal."""
    config.DIRETORIO_DATA.mkdir(exist_ok=True)
    logging.basicConfig(
        level=logging.WARNING,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.FileHandler(config.DIRETORIO_DATA / "validador.log"),
        ],
    )


def _menu_principal() -> None:
    """Menu interativo principal."""
    global _ultimo_resultado

    console.print(
        Panel(
            "[bold]Validador de Cidades[/bold]\n"
            "Diagnostico automatico do Painel Estrategico Territorial",
            border_style="blue",
            padding=(1, 2),
        )
    )

    while True:
        console.print()
        console.print("[bold]Menu Principal[/bold]")
        console.print("  [cyan]1[/cyan] Validar municipio")
        console.print("  [cyan]2[/cyan] Validar municipio (com upstream)")
        console.print("  [cyan]3[/cyan] Gerar template xlsx")
        console.print("  [cyan]4[/cyan] Ver ultimo resultado")
        console.print("  [cyan]5[/cyan] Detalhar metrica do ultimo resultado")
        console.print("  [cyan]6[/cyan] Exportar diagnostico (.md)")
        console.print("  [cyan]7[/cyan] Configuracoes atuais")
        console.print("  [cyan]q[/cyan] Sair")

        opcao = Prompt.ask(
            "\nOpcao",
            choices=["1", "2", "3", "4", "5", "6", "7", "q"],
            default="1",
        )

        if opcao == "q":
            console.print("[dim]Ate mais.[/dim]")
            break
        elif opcao == "1":
            _ultimo_resultado = _fluxo_validacao(upstream=False)
        elif opcao == "2":
            _ultimo_resultado = _fluxo_validacao(upstream=True)
        elif opcao == "3":
            gerar_xlsx([])
        elif opcao == "4":
            _ver_ultimo_resultado()
        elif opcao == "5":
            _detalhar_metrica()
        elif opcao == "6":
            _exportar_diagnostico()
        elif opcao == "7":
            _mostrar_configuracoes()


def _fluxo_validacao(upstream: bool = False) -> list[dict]:
    """Fluxo interativo de validacao."""
    municipio = Prompt.ask("Municipio (ex: Andradina - SP)")
    if not municipio:
        console.print("[red]Municipio obrigatorio.[/red]")
        return []

    ano = IntPrompt.ask("Ano", default=config.ANO_PADRAO)

    gerar_xlsx_opt = Confirm.ask("Gerar xlsx com resultado?", default=True)

    resultados = executar_validacao(
        municipio=municipio,
        ano=ano,
        upstream=upstream,
    )

    if gerar_xlsx_opt and resultados:
        gerar_xlsx(resultados)

    if resultados:
        imprimir_resumo(resultados)
        _menu_pos_resultado(resultados, municipio)

    return resultados


def _menu_pos_resultado(resultados: list[dict], municipio: str) -> None:
    """Sub-menu apos resultado."""
    while True:
        console.print()
        console.print("[bold]O que deseja?[/bold]")
        console.print("  [cyan]d[/cyan] Detalhar uma metrica")
        console.print("  [cyan]z[/cyan] Ver apenas os zeros")
        console.print("  [cyan]r[/cyan] Repetir para outro municipio")
        console.print("  [cyan]v[/cyan] Voltar ao menu principal")

        opcao = Prompt.ask("Opcao", choices=["d", "z", "r", "v"], default="v")

        if opcao == "v":
            break
        elif opcao == "d":
            _detalhar_metrica_lista(resultados)
        elif opcao == "z":
            _ver_zeros(resultados)
        elif opcao == "r":
            break


def _ver_ultimo_resultado() -> None:
    """Exibe o ultimo resultado gerado."""
    if not _ultimo_resultado:
        console.print("[yellow]Nenhum resultado disponivel. Execute uma validacao primeiro.[/yellow]")
        return

    municipio = _ultimo_resultado[0].get("municipio", "?")
    console.print(f"\n[bold]Ultimo resultado: {municipio}[/bold]\n")

    tabela = Table(show_header=True, header_style="bold blue")
    tabela.add_column("#", width=3)
    tabela.add_column("Metrica", width=35)
    tabela.add_column("Valor", justify="right", width=15)
    tabela.add_column("Status", width=20)
    tabela.add_column("Upstream", width=30)

    for idx, res in enumerate(_ultimo_resultado, 1):
        valor = res["valor_metrica"]
        if valor is not None:
            try:
                valor_fmt = f"{float(valor):,.2f}"
            except (TypeError, ValueError):
                valor_fmt = str(valor)
        else:
            valor_fmt = "NULL"

        cor = {
            "OK": "green", "ZERO_LEGITIMO": "yellow",
            "ZERO_SUSPEITO": "red", "AUSENTE": "red",
        }.get(res["status"], "white")

        upstream_info = res.get("fonte_upstream", "")
        if len(upstream_info) > 28:
            upstream_info = upstream_info[:28] + ".."

        tabela.add_row(
            str(idx),
            res["nome_metrica"],
            f"[{cor}]{valor_fmt}[/{cor}]",
            f"[{cor}]{res['status']}[/{cor}]",
            upstream_info,
        )

    console.print(tabela)


def _detalhar_metrica() -> None:
    """Detalha uma metrica do ultimo resultado."""
    if not _ultimo_resultado:
        console.print("[yellow]Nenhum resultado disponivel.[/yellow]")
        return
    _detalhar_metrica_lista(_ultimo_resultado)


def _detalhar_metrica_lista(resultados: list[dict]) -> None:
    """Permite escolher e detalhar uma metrica."""
    console.print()
    for idx, res in enumerate(resultados, 1):
        cor = {"OK": "green", "ZERO_SUSPEITO": "red", "AUSENTE": "red"}.get(res["status"], "yellow")
        console.print(f"  [{cor}]{idx:2d}[/{cor}] {res['nome_metrica']}")

    escolha = Prompt.ask("\nNumero da metrica (ou 'v' para voltar)")
    if escolha.lower() == "v":
        return

    try:
        idx = int(escolha) - 1
        if 0 <= idx < len(resultados):
            _exibir_detalhe(resultados[idx])
        else:
            console.print("[red]Numero fora do intervalo.[/red]")
    except ValueError:
        console.print("[red]Entrada invalida.[/red]")


def _exibir_detalhe(res: dict) -> None:
    """Exibe detalhe completo de uma metrica."""
    valor = res["valor_metrica"]
    if valor is not None:
        try:
            valor_fmt = f"{float(valor):,.2f}"
        except (TypeError, ValueError):
            valor_fmt = str(valor)
    else:
        valor_fmt = "NULL"

    painel = (
        f"[bold]{res['nome_metrica']}[/bold]\n\n"
        f"Tabela: {res['query']}\n"
        f"GCP: {res['gcp']}\n"
        f"Pagina: {res['pagina']}\n"
        f"Secao: {res['secao']}\n"
        f"Ano filtro: {res.get('ano_filtro', 'nenhum')}\n\n"
        f"Registros: {res['total_registros']}\n"
        f"Valor: {valor_fmt}\n"
        f"Status: {res['status']}\n\n"
        f"Diagnostico: {res['diagnostico']}\n"
    )

    upstream = res.get("fonte_upstream", "")
    if upstream:
        painel += (
            f"\n--- Upstream ---\n"
            f"Fontes: {upstream}\n"
            f"Registros upstream: {res.get('registros_upstream', 'N/A')}\n"
            f"Diagnostico upstream: {res.get('diagnostico_upstream', '')}\n"
            f"Camada de falha: {res.get('camada_falha', '')}\n"
        )

    painel += f"\n--- Query executada ---\n{res['query_executada']}"

    console.print(Panel(painel, border_style="blue", title=res["nome_metrica"]))


def _ver_zeros(resultados: list[dict]) -> None:
    """Exibe apenas metricas com zero ou ausente."""
    zeros = [
        r for r in resultados
        if r["status"] in ("ZERO_SUSPEITO", "ZERO_LEGITIMO", "AUSENTE", "NULL")
    ]

    if not zeros:
        console.print("[green]Nenhum zero encontrado.[/green]")
        return

    tabela = Table(title="Metricas zeradas", show_header=True, header_style="bold red")
    tabela.add_column("Metrica", width=35)
    tabela.add_column("Status", width=18)
    tabela.add_column("Upstream", width=25)
    tabela.add_column("Camada falha", width=22)

    for res in zeros:
        cor = "yellow" if res["status"] == "ZERO_LEGITIMO" else "red"
        tabela.add_row(
            res["nome_metrica"],
            f"[{cor}]{res['status']}[/{cor}]",
            res.get("fonte_upstream", ""),
            res.get("camada_falha", ""),
        )

    console.print(tabela)


def _exportar_diagnostico() -> None:
    """Exporta diagnostico do ultimo resultado como .md."""
    if not _ultimo_resultado:
        console.print("[yellow]Nenhum resultado disponivel.[/yellow]")
        return

    municipio = _ultimo_resultado[0].get("municipio", "desconhecido")
    slug = municipio.lower().replace(" - ", "_").replace(" ", "_")
    nome_arquivo = f"diagnostico_{slug}_{datetime.now().strftime('%Y-%m-%d')}.md"
    caminho = config.DIRETORIO_DATA / nome_arquivo

    linhas = [
        f"# Diagnostico: {municipio}",
        f"# Data: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        "",
        "| Metrica | Valor | Status | Upstream | Camada |",
        "|---|---|---|---|---|",
    ]

    for res in _ultimo_resultado:
        valor = res["valor_metrica"]
        if valor is not None:
            try:
                valor = f"{float(valor):,.2f}"
            except (TypeError, ValueError):
                pass
        else:
            valor = "NULL"

        linhas.append(
            f"| {res['nome_metrica']} | {valor} | {res['status']} | "
            f"{res.get('fonte_upstream', '')} | {res.get('camada_falha', '')} |"
        )

    caminho.write_text("\n".join(linhas), encoding="utf-8")
    console.print(f"[green]Diagnostico exportado: {caminho}[/green]")


def _mostrar_configuracoes() -> None:
    """Exibe configuracoes atuais."""
    console.print(
        Panel(
            f"Projeto BQ: {config.PROJETO_BQ}\n"
            f"Keyfile: {config.KEYFILE}\n"
            f"Ano padrao: {config.ANO_PADRAO}\n"
            f"Limite bytes: {config.LIMITE_BYTES_SESSAO / (1024*1024):.0f} MB\n"
            f"Arquivo xlsx: {config.ARQUIVO_XLSX}\n"
            f"Diretorio data: {config.DIRETORIO_DATA}",
            title="Configuracoes",
            border_style="dim",
        )
    )


def _modo_direto(args: argparse.Namespace) -> None:
    """Executa em modo direto (via flags)."""
    if args.gerar_template:
        gerar_xlsx([], Path(args.output) if args.output else None)
        return

    if not args.municipio:
        console.print("[red]Informe --municipio ou use sem flags para menu interativo.[/red]")
        return

    resultados = executar_validacao(
        municipio=args.municipio,
        ano=args.ano,
        dry_run=args.dry_run,
        upstream=args.upstream,
    )

    if not args.dry_run and resultados:
        caminho_saida = Path(args.output) if args.output else config.ARQUIVO_XLSX
        gerar_xlsx(resultados, caminho_saida)
        imprimir_resumo(resultados)

        if args.json_output:
            _salvar_json(resultados)


def _salvar_json(resultados: list[dict]) -> None:
    """Salva resultados em JSON."""
    municipio = resultados[0].get("municipio", "desconhecido") if resultados else "vazio"
    slug = municipio.lower().replace(" - ", "_").replace(" ", "_")
    caminho = config.DIRETORIO_DATA / f"resultado_{slug}.json"

    dados_serializaveis = []
    for r in resultados:
        copia = dict(r)
        valor = copia.get("valor_metrica")
        if valor is not None:
            try:
                copia["valor_metrica"] = float(valor)
            except (TypeError, ValueError):
                copia["valor_metrica"] = str(valor)
        dados_serializaveis.append(copia)

    caminho.write_text(json.dumps(dados_serializaveis, ensure_ascii=False, indent=2), encoding="utf-8")
    console.print(f"[green]JSON salvo: {caminho}[/green]")


def main() -> None:
    """Ponto de entrada: menu interativo se sem flags, modo direto se com flags."""
    _configurar_logging()

    parser = argparse.ArgumentParser(
        description="Validador de Cidades - Diagnostico de metricas do dashboard.\n"
        "Execute sem argumentos para o menu interativo.",
    )
    parser.add_argument("--municipio", "-m", type=str, help="Municipio a validar")
    parser.add_argument("--ano", "-a", type=int, default=config.ANO_PADRAO, help="Ano para filtro")
    parser.add_argument("--dry-run", action="store_true", help="Estima custo sem executar")
    parser.add_argument("--upstream", "-u", action="store_true", help="Verificar fontes upstream")
    parser.add_argument("--gerar-template", action="store_true", help="Gera template xlsx")
    parser.add_argument("--output", "-o", type=str, help="Caminho do xlsx de saida")
    parser.add_argument("--json", dest="json_output", action="store_true", help="Exportar JSON")

    args = parser.parse_args()

    tem_flags = args.municipio or args.gerar_template or args.dry_run
    if tem_flags:
        _modo_direto(args)
    else:
        _menu_principal()


if __name__ == "__main__":
    main()


# "A duvida e o principio da sabedoria." - Aristoteles
