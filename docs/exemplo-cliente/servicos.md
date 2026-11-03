# Serviços fora do cluster: acme-1-joinville (fictício)

Serviços que o cluster usa, mas que não são gerenciados por este repo.

| Serviço | Onde | Endereço | Quem cuida | Como o cluster usa |
|---|---|---|---|---|
| ERP | Datacenter do cliente | `erp.acme.local:443` | TI do cliente | API REST para ordens de produção |
| Active Directory | VLAN 10 | `10.10.10.5` | TI do cliente | Login dos usuários (LDAP) |
| SMTP | Office 365 | `smtp.office365.com:587` | TI do cliente | E-mails de alerta |
| CLPs da linha 1 | VLAN 30 | `10.10.30.21` a `.28` | Automação | Leitura por Modbus TCP |
| CLPs da linha 2 | VLAN 30 | `10.10.30.31` a `.36` | Automação | Leitura por EtherNet/IP |
| Registro de imagens | Internet | `ghcr.io` | — | Download das imagens das apps |

## Dependências críticas

- Sem o ERP, novas ordens não chegam, mas a produção em andamento continua.
- Sem a VLAN 30, a coleta para. Os dados não são recuperados depois: o CLP não guarda histórico.
- Credenciais desses serviços **não ficam aqui**. Ficam no cofre de segredos.
