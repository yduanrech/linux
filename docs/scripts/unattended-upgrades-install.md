# `unattended-upgrades-install.sh`

Configura atualizações automáticas (`unattended-upgrades`) com ou sem e-mail.

## Executar

Com e-mail:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/unattended-upgrades-install.sh)"
```

Sem e-mail:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/unattended-upgrades-install.sh)" -- --skip-email
```

Ajuda:

```bash
bash unattended-upgrades-install.sh --help
```

## Arquivo de configuração (`/etc/unattend.conf`)

```bash
sudo bash -c 'cat > /etc/unattend.conf <<EOF
MAIL_TO="email@destino.com"
GENERIC_FROM="email@remetente.com"
MAIL_SENDER="Servidor Linux <email@remetente.com>"
RELAY="smtp.zeptomail.com:587"
SMTP_USER="emailapikey"
SMTP_PASS="sua_senha_ou_token"
EOF
chmod 600 /etc/unattend.conf'
```

TLS por porta (automático):

- `465`: SSL wrapper
- `587` (ou `25`): STARTTLS

`MAIL_SENDER` é opcional. Se não for definido, o script usa `GENERIC_FROM`.

## Teste de envio de e-mail

```bash
printf "Subject: Teste ZeptoMail\n\nTeste de envio via Postfix em $(date)\n" | sendmail -v email@empresa.net.br
```

Verificação de log:

```bash
sudo tail -n 100 /var/log/mail.log
```
