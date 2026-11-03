#!/usr/bin/env bash
#
# gitops-starter: instala k3s + ArgoCD numa VM e conecta ao seu repo de GitOps.
#
# Uso:
#   sudo bash install.sh                                   # pergunta a URL do repo
#   sudo bash install.sh --repo https://github.com/<usuario>/gitops-starter.git
#
# Pode rodar de novo quantas vezes quiser: o que já está instalado é mantido.

set -euo pipefail

# ── Versões (fixadas para o tutorial funcionar igual para todo mundo) ─────────
K3S_VERSION="${K3S_VERSION:-v1.36.5+k3s1}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v3.5.6}"
ARGOCD_NODEPORT="${ARGOCD_NODEPORT:-30443}"
REPO_URL="${REPO_URL:-}"

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# ── Saída ─────────────────────────────────────────────────────────────────────
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

etapa() { echo -e "\n${CYAN}── $* ${NC}"; }
ok()    { echo -e "${GREEN}✔ $*${NC}"; }
aviso() { echo -e "${YELLOW}! $*${NC}"; }
erro()  { echo -e "${RED}✘ $*${NC}" >&2; exit 1; }

uso() {
  sed -n '3,8p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

# Repete um comando até dar certo ou acabar o tempo (em segundos)
esperar() {
  local descricao="$1" limite="$2"
  shift 2
  local inicio=$SECONDS
  until "$@" >/dev/null 2>&1; do
    if (( SECONDS - inicio > limite )); then
      erro "Tempo esgotado esperando: ${descricao}"
    fi
    sleep 3
  done
}

# ── Argumentos ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)    REPO_URL="${2:-}"; shift 2 ;;
    -h|--help) uso ;;
    *)         erro "Opção desconhecida: $1 (use --help)" ;;
  esac
done

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════╗"
echo "║        gitops-starter: k3s + ArgoCD      ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ── 1. Verificações ───────────────────────────────────────────────────────────
etapa "Verificando a máquina"

[[ "$(uname -s)" == "Linux" ]] || erro "Este script roda só em Linux."
[[ $EUID -eq 0 ]] || erro "Rode como root: sudo bash install.sh"
command -v curl >/dev/null || erro "Instale o curl primeiro (ex.: apt install -y curl)."
command -v systemctl >/dev/null || erro "O k3s precisa de systemd."

CPUS=$(nproc)
MEMORIA_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
(( CPUS >= 2 ))          || aviso "A VM tem ${CPUS} CPU. O recomendado são 2."
(( MEMORIA_MB >= 1800 )) || aviso "A VM tem ${MEMORIA_MB} MB de RAM. O recomendado são 2 GB."
ok "Linux, root, ${CPUS} CPU, ${MEMORIA_MB} MB de RAM"

# ── 2. Repo de GitOps ─────────────────────────────────────────────────────────
etapa "Repositório de GitOps"

if [[ -z "$REPO_URL" ]]; then
  [[ -t 0 ]] || erro "Informe o repo com --repo https://github.com/<usuario>/gitops-starter.git"
  echo "Informe a URL do SEU fork (ex.: https://github.com/fulano/gitops-starter.git)"
  read -rp "URL: " REPO_URL
fi

REPO_URL="${REPO_URL%/}"
[[ "$REPO_URL" == https://* ]] || erro "Use a URL https do repositório, não a de SSH."
[[ "$REPO_URL" == *.git ]] || REPO_URL="${REPO_URL}.git"
[[ "$REPO_URL" != *SEU_USUARIO* ]] || erro "Troque SEU_USUARIO pelo seu usuário do GitHub."

# Pergunta ao servidor Git se o repo existe e é público, sem baixar nada
if ! curl -fsS -o /dev/null "${REPO_URL}/info/refs?service=git-upload-pack"; then
  erro "Não consegui acessar ${REPO_URL}. Confira a URL e se o repositório é público."
fi
ok "Repo acessível: ${REPO_URL}"

# ── 3. k3s ────────────────────────────────────────────────────────────────────
etapa "Kubernetes (k3s ${K3S_VERSION})"

if command -v k3s >/dev/null && systemctl is-active --quiet k3s; then
  ok "k3s já instalado: $(k3s --version | head -1)"
else
  curl -sfL https://get.k3s.io \
    | INSTALL_K3S_VERSION="$K3S_VERSION" K3S_KUBECONFIG_MODE="644" sh -
  ok "k3s instalado"
fi

echo "Esperando o node ficar pronto..."
esperar "node registrado" 120 bash -c "kubectl get nodes --no-headers | grep -q ."
kubectl wait --for=condition=Ready nodes --all --timeout=180s >/dev/null
ok "Node pronto: $(kubectl get nodes --no-headers | awk '{print $1}')"

# Atalho "k" para o kubectl, para quem for mexer no terminal depois
cat > /etc/profile.d/gitops-starter.sh <<'EOF'
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
alias k=kubectl
EOF

# ── 4. ArgoCD ─────────────────────────────────────────────────────────────────
etapa "ArgoCD ${ARGOCD_VERSION}"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" >/dev/null
ok "Manifestos aplicados"

echo "Esperando os componentes do ArgoCD subirem (pode levar alguns minutos)..."
kubectl wait --for=condition=Established --timeout=120s \
  crd/applications.argoproj.io crd/applicationsets.argoproj.io >/dev/null
for componente in deploy/argocd-server deploy/argocd-repo-server \
                  deploy/argocd-applicationset-controller statefulset/argocd-application-controller; do
  kubectl -n argocd rollout status "$componente" --timeout=600s >/dev/null
  ok "${componente#*/}"
done

# Expõe a interface web numa porta fixa da VM
kubectl -n argocd patch service argocd-server -p \
  "{\"spec\":{\"type\":\"NodePort\",\"ports\":[{\"name\":\"https\",\"port\":443,\"nodePort\":${ARGOCD_NODEPORT}}]}}" >/dev/null
ok "Interface web na porta ${ARGOCD_NODEPORT}"

# ── 5. Conexão com o repo ─────────────────────────────────────────────────────
etapa "Conectando o ArgoCD ao repo"

# A única coisa que fica fora do Git: uma Application que aponta para a pasta
# bootstrap/ do repo. Dali o ArgoCD lê os ApplicationSets e a infra.
kubectl apply -f - >/dev/null <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bootstrap
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${REPO_URL}
    targetRevision: main
    path: bootstrap
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
ok "Application bootstrap criada → ${REPO_URL} (pasta bootstrap/)"

# ── 6. Resumo ─────────────────────────────────────────────────────────────────
esperar "senha inicial do ArgoCD" 120 \
  kubectl -n argocd get secret argocd-initial-admin-secret
SENHA=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
IP=$(hostname -I | awk '{print $1}')

echo -e "\n${GREEN}${BOLD}Pronto!${NC}\n"
echo -e "${BOLD}ArgoCD${NC}"
echo "  URL:     https://${IP}:${ARGOCD_NODEPORT}  (o navegador vai avisar do certificado; pode continuar)"
echo "  Usuário: admin"
echo "  Senha:   ${SENHA}"
echo ""
echo -e "${BOLD}podinfo${NC} (sobe em 1 ou 2 minutos)"
echo "  staging:    http://${IP}/staging"
echo "  production: http://${IP}/production"
echo ""
echo -e "${YELLOW}Lembre-se:${NC} os arquivos de bootstrap/ no seu fork precisam apontar para"
echo "  ${REPO_URL}"
echo "  Se ainda estiverem com SEU_USUARIO, as apps não vão aparecer no ArgoCD."
echo ""
echo "O ArgoCD confere o Git a cada ~3 minutos. Para ver uma mudança na hora,"
echo "clique em Refresh na app, dentro do ArgoCD."
echo ""
echo "Para usar o atalho 'k' do kubectl, abra um terminal novo ou rode: source /etc/profile.d/gitops-starter.sh"
