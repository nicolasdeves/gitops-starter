# Rede: acme-1-joinville (fictício)

## VLANs

| VLAN | Nome | Faixa | Uso |
|---|---|---|---|
| 10 | ADM | 10.10.10.0/24 | Escritório e TI do cliente |
| 20 | SERVIDORES | 10.10.20.0/24 | VMs do cluster |
| 30 | AUTOMACAO | 10.10.30.0/24 | CLPs e equipamentos da linha |

- **IPv4 apenas.** IPv6 desligado em todas as VLANs.
- Gateway de cada VLAN: `.1` (firewall do cliente).
- DNS interno: `10.10.10.5` e `10.10.10.6`. Domínio interno: `acme.local`.

## Firewall

| Origem | Destino | Porta | Motivo |
|---|---|---|---|
| VLAN 10 | 10.10.20.10 | 80, 443 | Usuários acessam o sistema |
| VLAN 20 | VLAN 30 | 502 (Modbus), 44818 (EtherNet/IP) | Coleta dos equipamentos |
| VLAN 20 | Internet | 443 | Só para o registro de imagens e o Git |
| VPN STW | VLAN 20 | 22, 6443, 30443 | Suporte: SSH, API do Kubernetes, ArgoCD |

- A VLAN 30 **não** sai para a internet.
- Qualquer porta nova precisa de chamado com o TI do cliente (prazo de 2 dias úteis).

## Observações

- O MTU da VPN é 1400. Containers com MTU padrão (1500) podem ter problema em pacotes grandes.
- O NTP é o próprio firewall (`10.10.10.1`). Horário errado quebra certificados e logs.
