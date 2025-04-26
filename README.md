# unattended-upgrades-install.sh

**Para executar o script, use:**
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/unattended-upgrades-install.sh)" 
```


**Descrição:**  
Script em bash para automatizar a instalação e configuração do sistema de atualizações automáticas (`unattended-upgrades`) no Ubuntu/Debian, incluindo notificações por e-mail utilizando Postfix via SMTP relay.

## Características

- **Automação completa** para configurar:
  - Pacotes essenciais:
    - `unattended-upgrades`
    - `postfix`
    - `mailutils`
    - `update-notifier-common`
  - Arquivos de configuração:
    - `50unattended-upgrades`
    - `20auto-upgrades`
    - - `10periodic` (Criado automaticamente)
  - Agendamento diário do serviço de atualização (cron às `01:00`).

- **Notificação automática por e-mail**:
  - Notifica sobre atualizações realizadas ou erros encontrados durante o processo.
  - Utiliza servidor SMTP externo para envio.

- **Segurança aprimorada**:
  - Usa variáveis externas através de um arquivo de configuração `/etc/unattend.conf`.
  - Realiza exclusão automática e segura do arquivo após o uso, protegendo credenciais sensíveis.
  - Armazena credenciais temporariamente em arquivos protegidos (`chmod 600`), deletando-os logo após o uso.

## Requisitos do arquivo auxiliar (`unattend.conf`)

O arquivo auxiliar deve ser criado previamente em `/etc/unattend.conf` com permissões seguras (`chmod 600`), contendo as seguintes variáveis:

```bash
MAIL_TO="email@destino.com"
GENERIC_FROM="email@remetente.com"
RELAY="smtp.servidor.com:465"
SMTP_USER="usuario_smtp" # Geralmente usuario@dominio.com.br
SMTP_PASS="senha_smtp" # Recomendasse usar senha de aplicativo
```

## Pós-execução

Após a execução bem-sucedida do script, ocorrerá automaticamente:

- Exclusão permanente e segura (`shred`) do arquivo `/etc/unattend.conf`.
- Habilitação e ativação imediata do serviço `unattended-upgrades`.

Você pode testar o envio de e-mails pelo postfix com o comando:

```bash
echo "E-mail de teste $(date)" | mail -s "Teste e-mail $(hostname -s) $(date)" email@empresa.net.br
```

Para executar os updates pode se utilizar o comando:

```bash
sudo unattended-upgrade -v
```

## Compatibilidade

- Testado no Ubuntu 22.04 LTS.

---
