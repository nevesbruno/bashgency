#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${AI_ALIAS_DIR:-$HOME/.config/ai-alias}"

echo "[+] Configurando AI Alias em $CONFIG_DIR"

mkdir -p "$CONFIG_DIR/modules" "$CONFIG_DIR/backups"

if [ ! -f "$CONFIG_DIR/env" ]; then
    cp "$ROOT/env.example" "$CONFIG_DIR/env"
    chmod 600 "$CONFIG_DIR/env"
    echo "[*] Criado $CONFIG_DIR/env -- edite e adicione DEEPSEEK_API_KEY"
else
    echo "[*] $CONFIG_DIR/env ja existe (nao sobrescrito)"
fi

if ! grep -q '^AI_ALIAS_TARGET=' "$CONFIG_DIR/env" 2>/dev/null; then
    if [ ! -f "$CONFIG_DIR/aliases.sh" ]; then
        touch "$CONFIG_DIR/aliases.sh"
        echo "[*] Criado $CONFIG_DIR/aliases.sh (destino padrao de aliases)"
    fi
fi

echo ""
echo "[+] Instalacao de dados concluida."
echo "[*] Codigo do modulo: $ROOT/modules/ai-alias-cli.sh"
echo "[*] Carregue no shell, por exemplo no alias.sh do bash-stuffs:"
echo "    source \"\$HOME/lab/ai-alias/modules/ai-alias-cli.sh\""
echo ""
echo "[*] Garanta aliases no shell (se usar destino padrao):"
echo "    [ -f \"\$HOME/.config/ai-alias/aliases.sh\" ] && source \"\$HOME/.config/ai-alias/aliases.sh\""
