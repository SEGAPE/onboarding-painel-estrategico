#!/usr/bin/env bash
# Inicializa o ambiente e executa o gerenciador de assets visuais.
#
# Uso: bash run.sh [comando] [argumentos...]
#
# Se chamado sem argumentos, abre o menu interativo.
# Se chamado com argumentos, passa direto para o gerenciador.
#
# Exemplos:
#   bash run.sh                     — menu interativo
#   bash run.sh organizar           — organiza arquivos soltos
#   bash run.sh urls --programa cnca — lista URLs do programa cnca

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VENV_DIR=".venv"
REQUIREMENTS="requirements.txt"
MAIN="main.py"

# --- Verificação do Python ---
if ! command -v python3 &> /dev/null; then
    echo "Erro: python3 não encontrado no PATH."
    echo "Instale o Python 3.10+ antes de continuar."
    exit 1
fi

# --- Criação do venv se não existir ---
if [ ! -d "$VENV_DIR" ]; then
    echo "Ambiente virtual não encontrado. Criando..."
    python3 -m venv "$VENV_DIR"
    echo "Ambiente virtual criado em $VENV_DIR/"
fi

# --- Ativação do venv ---
source "$VENV_DIR/bin/activate"

# --- Verificação de dependências ---
# Checa se unidecode está instalado como proxy para todas as dependências
if ! python3 -c "import unidecode" &> /dev/null 2>&1; then
    echo "Dependências não encontradas. Instalando..."
    pip install --upgrade pip --quiet
    pip install -r "$REQUIREMENTS" --quiet
    echo "Dependências instaladas."
fi

# --- Execução ---
python3 "$MAIN" "$@"
