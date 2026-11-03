# gitops-starter

Seu primeiro cluster com GitOps: **um script** instala Kubernetes (k3s) e ArgoCD numa VM e conecta tudo a este repositório. Daí em diante, quem manda no cluster é o Git: você muda um arquivo, dá push, e o cluster muda sozinho.

Feito para a talk **"GitOps: do código ao usuário"**, no Tech Talks Day da Univates.

## Como funciona

```
install.sh ──cria──► Application "bootstrap" ──lê──► bootstrap/  (no seu fork)
                                                       ├── applicationset-staging    ──lê──► apps/*/environments/staging
                                                       ├── applicationset-production ──lê──► apps/*/environments/production
                                                       └── infra                     ──lê──► infra/
```

- O `install.sh` instala o k3s e o ArgoCD e cria **uma única Application**, a `bootstrap`, apontando para a pasta `bootstrap/` do seu repo.
- O ArgoCD lê `bootstrap/` e cria dois **ApplicationSets** (um por ambiente) e a Application de **infra**.
- Cada ApplicationSet procura as pastas `apps/<app>/environments/<ambiente>` e cria uma Application para cada uma (ex.: `podinfo-staging`).
- A Application de infra aplica as rotas (`infra/`), que levam `http://<IP>/staging` e `http://<IP>/production` até a app certa.

## Estrutura

```
gitops-starter/
├── install.sh                  # roda na VM: k3s + ArgoCD + conexão com o repo
├── uninstall.sh                # roda na VM: remove tudo
├── bootstrap/                  # configuração do ArgoCD (lida pelo próprio ArgoCD)
│   ├── applicationset-staging.yaml
│   ├── applicationset-production.yaml
│   └── infra.yaml
├── apps/
│   └── podinfo/
│       ├── base/               # o que é igual em todos os ambientes
│       └── environments/
│           ├── staging/        # o que muda em staging (versão, cor, réplicas)
│           └── production/     # o que muda em production
├── infra/                      # rotas de cada ambiente (Ingress do Traefik)
├── docs/exemplo-cliente/       # exemplo de contexto para usar com IA
└── CLAUDE.md                   # padrões do repo, para pessoas e para IA
```

A app de exemplo é o [podinfo](https://github.com/stefanprodan/podinfo), uma app feita para demonstrações de Kubernetes. A página mostra a versão, o nome do pod e uma mensagem e cor que você controla pelo Git.

## Pré-requisitos

- Uma VM Linux com **2 CPU e 2 GB de RAM** (Ubuntu, Debian, Rocky...). Pode ser Multipass, VirtualBox, WSL com systemd ou uma VM de nuvem.
- Acesso root (`sudo`) e internet na VM.
- Uma conta no GitHub.

## Passo a passo

### 1. Faça um fork

Clique em **Fork** no topo desta página. O ArgoCD vai ler o **seu** fork, porque é nele que você vai dar push.

### 2. Aponte o bootstrap para o seu fork

Nos três arquivos de `bootstrap/`, troque `SEU_USUARIO` pelo seu usuário do GitHub:

- `bootstrap/applicationset-staging.yaml` (duas vezes)
- `bootstrap/applicationset-production.yaml` (duas vezes)
- `bootstrap/infra.yaml`

Dá para editar direto no site do GitHub (ícone de lápis) e fazer o commit por lá.

> Se pular este passo, o ArgoCD procura um repo que não existe e as apps não aparecem.

### 3. Leve o script para a VM

Só o script vai para a VM; o repo fica no GitHub, onde o ArgoCD vai lê-lo.

```bash
curl -sLO https://raw.githubusercontent.com/SEU_USUARIO/gitops-starter/main/install.sh
```

Leia o script antes de rodar. É uma boa prática com qualquer script baixado da internet.

### 4. Rode

```bash
sudo bash install.sh --repo https://github.com/SEU_USUARIO/gitops-starter.git
```

Sem o `--repo`, o script pergunta a URL. Leva de 3 a 5 minutos. No fim ele mostra:

- a URL do ArgoCD (`https://<IP>:30443`), o usuário `admin` e a senha;
- as URLs do podinfo: `http://<IP>/staging` e `http://<IP>/production`.

## Exercícios

O ArgoCD confere o Git a cada ~3 minutos. Para ver na hora, clique em **Refresh** na app dentro do ArgoCD.

**1. Mude a cor.** Em `apps/podinfo/environments/production/kustomization.yaml`, troque `PODINFO_UI_COLOR` e dê push. Os pods são recriados e a página muda.

**2. Promova uma versão.** Staging roda uma versão mais nova que production. Copie a `newTag` de staging para production e dê push. É assim que uma versão testada chega ao usuário.

**3. Escale.** Mude `count` em `replicas` para 3 e dê push. Atualize a página algumas vezes: o nome do pod vai mudando.

**4. Tente quebrar.** Apague um pod na mão:

```bash
sudo kubectl -n production delete pod -l app=podinfo
```

O Kubernetes cria outro. Agora mude as réplicas na mão:

```bash
sudo kubectl -n production scale deploy podinfo --replicas=5
```

O ArgoCD volta para o que está no Git (`selfHeal`). **O Git é a fonte da verdade.**

**5. Volte atrás.** Desfaça o último commit e dê push:

```bash
git revert HEAD
git push
```

O cluster volta para o estado anterior. Rollback é um commit.

**6. Crie uma app nova.** Copie `apps/podinfo` para `apps/outra-app`, ajuste os nomes e dê push. Os ApplicationSets encontram a pasta nova e criam `outra-app-staging` e `outra-app-production`. Para ela ter URL, crie as rotas em `infra/`.

## Desinstalar

```bash
curl -sLO https://raw.githubusercontent.com/SEU_USUARIO/gitops-starter/main/uninstall.sh
sudo bash uninstall.sh
```

Remove o k3s, o ArgoCD e todas as apps da VM. O seu repo no GitHub não é tocado.

## Problemas comuns

| Sintoma | O que fazer |
|---|---|
| Só a app `bootstrap` aparece no ArgoCD, com erro | Os arquivos de `bootstrap/` ainda estão com `SEU_USUARIO`. Veja o passo 2. |
| A app `infra` fica em erro no começo | Normal: ela espera os namespaces que os ApplicationSets criam, e tenta de novo sozinha. |
| `404` em `http://<IP>/staging` | O podinfo ainda está subindo, ou a app `infra` ainda não sincronizou. Espere um minuto. |
| Mudei o Git e nada aconteceu | Clique em **Refresh** no ArgoCD, ou espere até 3 minutos. Confira se o push foi para a branch `main`. |
| O navegador avisa que a conexão do ArgoCD não é segura | Esperado: o certificado é autoassinado. Pode continuar. |

## Versões

| Componente | Versão |
|---|---|
| k3s | v1.36.5+k3s1 |
| ArgoCD | v3.5.6 |
| podinfo | 6.17.0 (staging), 6.16.0 (production) |

Para trocar o k3s ou o ArgoCD, use as variáveis `K3S_VERSION` e `ARGOCD_VERSION` ao rodar o script.
