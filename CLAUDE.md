# Padrões do gitops-starter

Este arquivo é lido por assistentes de IA (Claude Code e similares) antes de mexer no repo. Ele também serve para qualquer pessoa nova no projeto.

## O que é este repo

Repo de GitOps: o ArgoCD aplica no cluster o que está aqui. **O Git é a fonte da verdade.** Nenhuma mudança vai direto ao cluster.

## Estrutura

- `bootstrap/`: configuração do ArgoCD. Um ApplicationSet por ambiente e a Application de infra.
- `apps/<app>/base/`: o que é igual em todos os ambientes (Deployment, Service, ConfigMap gerado).
- `apps/<app>/environments/<ambiente>/`: overlay do Kustomize com o que muda no ambiente.
- `infra/`: YAML puro, sem Kustomize. Um `ingress-<ambiente>.yaml` por ambiente.
- `docs/`: contexto de clientes e ambientes (rede, VMs, serviços). Leia antes de propor mudanças de infraestrutura.

## Convenções

- Ambientes: `staging` e `production`. O namespace tem o mesmo nome do ambiente.
- Nome da Application no ArgoCD: `<app>-<ambiente>` (ex.: `podinfo-staging`). É gerado pelo ApplicationSet; não crie Applications à mão.
- Nome dos recursos dentro do namespace: o nome da app, sem sufixo (ex.: Service `podinfo`).
- Versão da imagem: só no overlay, em `images[].newTag`. Nunca use `latest`.
- Variáveis de ambiente: `configMapGenerator` no base, com `behavior: merge` no overlay. Assim, mudar um valor recria os pods.
- Toda app tem `resources` (requests e limits), `livenessProbe` e `readinessProbe`.
- Rotas: uma por app em cada `infra/ingress-<ambiente>.yaml`, com o caminho `/<ambiente>` ou um `host`.
- Comentários em português.

## Regras

- **Nunca** rode `kubectl apply`, `edit`, `scale` ou `delete` para mudar o estado desejado. Mude o Git; o ArgoCD aplica. `kubectl get`, `describe` e `logs` podem ser usados para diagnosticar.
- **Nunca** coloque senhas, tokens ou chaves no repo. Ele é público.
- Promoção de versão: primeiro staging, depois production, em commits separados.
- Um commit por mudança, com mensagem dizendo o quê e onde. Ex.: `podinfo(production): versão 6.17.0`.

## Como validar antes do push

```bash
kubectl kustomize apps/<app>/environments/<ambiente>
```

O comando precisa gerar o YAML sem erro. Confira a imagem, as réplicas e o ConfigMap no resultado.

## Tarefas comuns

- **Nova app:** copie `apps/podinfo`, troque os nomes, crie os overlays de `staging` e `production` e adicione as rotas em `infra/`.
- **Promover versão:** copie a `newTag` do overlay de staging para o de production.
- **Rollback:** `git revert` do commit que causou o problema.
