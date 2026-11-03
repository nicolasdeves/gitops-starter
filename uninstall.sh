#!/usr/bin/env bash
#
# gitops-starter: remove o k3s, o ArgoCD e tudo o que rodava no cluster.
# O seu repo no GitHub não é tocado.
#
# Uso:
#   sudo bash uninstall.sh        # pede confirmação
#   sudo bash uninstall.sh --sim  # sem confirmação

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

[[ $EUID -eq 0 ]] || { echo -e "${RED}✘ Rode como root: sudo bash uninstall.sh${NC}" >&2; exit 1; }

if [[ ! -x /usr/local/bin/k3s-uninstall.sh ]]; then
  echo -e "${YELLOW}! k3s não está instalado nesta máquina. Nada a fazer.${NC}"
  exit 0
fi

if [[ "${1:-}" != "--sim" ]]; then
  echo -e "${YELLOW}Isto apaga o cluster inteiro desta VM: k3s, ArgoCD e todas as apps.${NC}"
  read -rp "Digite 'sim' para continuar: " resposta
  [[ "$resposta" == "sim" ]] || { echo "Cancelado."; exit 0; }
fi

/usr/local/bin/k3s-uninstall.sh
rm -f /etc/profile.d/gitops-starter.sh

echo -e "${GREEN}✔ Tudo removido. Para instalar de novo: sudo bash install.sh${NC}"
