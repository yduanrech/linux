# `n8n-install.sh`

Instala ou atualiza o `n8n` e configura serviço `systemd`.

## Executar

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/n8n-install.sh)"
```

## Comportamento

- Se `n8n.service` não existir: instala
- Se `n8n.service` existir: atualiza com reinstalação global limpa do `n8n`
- Garante Node.js 22.x
- Cria usuário de serviço `n8n`
- Configura `n8n.service` em `/etc/systemd/system/n8n.service`
- Regrava o `n8n.service` também durante update
- Faz backup prévio do `database.sqlite` quando existir
- Valida o binário antes de reiniciar o serviço

## Variáveis úteis (opcionais)

- `HOST_IP`
- `GENERIC_TIMEZONE`
- `N8N_HOST`
- `N8N_PROTOCOL`
- `N8N_PORT`

Exemplo:

```bash
sudo HOST_IP="10.0.0.20" N8N_PROTOCOL="http" N8N_PORT="5678" bash n8n-install.sh
```

## Validação

```bash
sudo systemctl status n8n
sudo journalctl -u n8n -n 50 --no-pager
sudo n8n --version
```
