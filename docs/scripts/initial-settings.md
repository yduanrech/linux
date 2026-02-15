# `initial-settings.sh`

Menu interativo para configuração inicial de servidor.

## Executar

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/initial-settings.sh)"
```

## Opções do Menu

- `1`: Fuso horário, locale e SSH
- `2`: Limites do `journald`
- `3`: Autologout (15 min)
- `4`: Unattended-upgrades com e-mail
- `5`: Unattended-upgrades sem e-mail
- `A`: Executa tudo

## Rodar só a parte de e-mail

- No menu, selecione apenas `4`.
- Execução não interativa (opcional):

```bash
printf "4\n" | sudo bash initial-settings.sh
```

## E-mail para unattended-upgrades

Quando usar a opção `4`, criar antes `/etc/unattend.conf`:

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

Porta no relay:

- `465`: SSL wrapper
- `587`: STARTTLS

`MAIL_SENDER` é opcional. Se não for definido, o script usa `GENERIC_FROM`.

## Teste de envio de e-mail

```bash
printf "Subject: Teste ZeptoMail\n\nTeste de envio via Postfix em $(date)\n" | sendmail -v email@empresa.net.br
```

Verificação de log:

```bash
sudo tail -n 100 /var/log/mail.log
```
