#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

if [ -d "$VENV_DIR" ]; then
    echo "Ambiente virtual ja existe em $VENV_DIR"
    echo "Para reinstalar, execute uninstall.sh primeiro."
    exit 1
fi

echo "Criando ambiente virtual Python 3.10+..."
python3.10 -m venv "$VENV_DIR" 2>/dev/null || python3 -m venv "$VENV_DIR"

echo "Instalando dependencias..."
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet -r "$SCRIPT_DIR/requirements.txt"

echo "Instalacao concluida."
echo "Uso: $VENV_DIR/bin/python main.py --municipio 'Andradina - SP'"
