# Exemplo de contexto de cliente

Dados **fictícios**. Esta pasta mostra como organizar o contexto de um cliente para que uma pessoa nova, ou uma IA, entenda o ambiente antes de mexer em qualquer coisa.

A ideia: uma pasta por cliente (ou fábrica), com o que não está nos YAMLs.

| Arquivo | O que tem |
|---|---|
| [rede.md](rede.md) | VLANs, faixas de IP, IPv4/IPv6, firewall, DNS |
| [vms.md](vms.md) | VMs, papel de cada uma, recursos e hardware |
| [servicos.md](servicos.md) | Serviços fora do cluster e como o cluster fala com eles |

## Cliente

- **Nome:** ACME Alimentos (fictício)
- **Identificador:** `acme-1-joinville` (cliente, número da planta, cidade)
- **Ambientes:** `staging` (testes do cliente) e `production` (chão de fábrica)
- **Acesso:** VPN site-to-site; sem acesso direto pela internet
- **Contato técnico:** TI do cliente, pelo chamado interno (não usar WhatsApp para mudanças)

## Antes de qualquer mudança

- Production só recebe versão que passou por staging.
- Janela de manutenção: domingo, das 6h às 10h. Fora dela, só correção urgente com aviso ao cliente.
- O cliente não permite acesso de saída à internet a partir da VLAN de produção (veja [rede.md](rede.md)).
