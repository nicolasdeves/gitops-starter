# VMs: acme-1-joinville (fictício)

Virtualização: VMware ESXi do cliente, em dois hosts físicos.

| Hostname | IP | Papel | vCPU | RAM | Disco | Label no Kubernetes |
|---|---|---|---|---|---|---|
| acme-mes-node-master-1 | 10.10.20.10 | Control plane | 2 | 4 GB | 60 GB | — |
| acme-mes-node-worker-1 | 10.10.20.11 | Apps (stateless) | 4 | 8 GB | 80 GB | `role=stateless` |
| acme-mes-node-worker-2 | 10.10.20.12 | Apps (stateless) | 4 | 8 GB | 80 GB | `role=stateless` |
| acme-mes-node-worker-3 | 10.10.20.13 | Banco de dados | 4 | 16 GB | 500 GB (SSD) | `role=stateful` |

- Sistema: Ubuntu Server 24.04 LTS em todas.
- Nomenclatura: `<cliente>-mes-node-<função>-<ordem>`.
- O disco do worker-3 fica no storage SSD do cliente; os demais, no storage padrão.

## Hardware dos hosts

| Host | Modelo | CPU | RAM | Observação |
|---|---|---|---|---|
| esxi-01 | Dell PowerEdge R650 | 2× Xeon Silver 4314 | 256 GB | Master e workers 1 e 3 |
| esxi-02 | Dell PowerEdge R650 | 2× Xeon Silver 4314 | 256 GB | Worker 2 |

- Se o esxi-01 cair, cai o control plane e o banco. Ponto de atenção já registrado com o cliente.

## Backup

- Snapshot das VMs pelo Veeam do cliente, todo dia às 2h.
- O banco tem backup próprio, enviado para o storage de objetos. Snapshot de VM não substitui backup de banco.
