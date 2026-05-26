#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

if [ ! -d "$VENV_DIR" ]; then
    echo "Ambiente virtual nao encontrado em $VENV_DIR"
    exit 0
fi

echo "Removendo ambiente virtual..."
rm -rf "$VENV_DIR"
echo "Ambiente virtual removido."
