# unattended-upgrades-install.sh

**Para executar o script, use:**
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/unattended-upgrades-install.sh)" 
```

**Para executar sem configuração de email:**
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/unattended-upgrades-install.sh)" -- --skip-email
```


**Descrição:**  
Script em bash para automatizar a instalação e configuração do sistema de atualizações automáticas (`unattended-upgrades`) no Ubuntu/Debian, com opção de notificações por e-mail utilizando Postfix via SMTP relay.

## Parâmetros

| Parâmetro | Descrição |
|-----------|-----------|
| `--skip-email` ou `-y` | Ignora o arquivo de configuração e instala sem notificações por email |
| `-h` ou `--help` | Exibe ajuda |

## Características

- **Automação completa** para configurar:
  - Pacotes essenciais:
    - `unattended-upgrades`
    - `postfix` (apenas com email)
    - `mailutils` (apenas com email)
    - `update-notifier-common`
  - Arquivos de configuração:
    - `50unattended-upgrades`
    - `20auto-upgrades`
  - Agendamento diário do serviço de atualização (cron às `01:00`).

- **Notificação automática por e-mail** (opcional):
  - Notifica sobre atualizações realizadas ou erros encontrados durante o processo.
  - Utiliza servidor SMTP externo para envio.

- **Re-verificação de arquivo de configuração**:
  - Se o arquivo `/etc/unattend.conf` não for encontrado, o script oferece:
    - `[Y]` Continuar sem email
    - `[R]` Re-verificar (permite criar o arquivo em outro terminal)
    - `[N]` Cancelar

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


# qemu-agent-install.sh

**Para executar o script, use:**

```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/qemu-agent-install.sh)"
```

**Descrição:**
Script em bash para automatizar a instalação e configuração do QEMU Guest Agent no Ubuntu/Debian, permitindo uma integração aprimorada entre máquinas virtuais e o hipervisor Proxmox ou KVM.

## Características

* **Automação completa** para configurar:

  * Atualização da lista de pacotes do sistema (`apt-get update`).
  * Instalação do pacote:

    * `qemu-guest-agent`
  * Ativação e inicialização automática do serviço:

    * Serviço `qemu-guest-agent`

* **Facilidade de uso**:

  * Mensagens claras e informativas durante o processo.
  * Tratamento automático e eficiente de possíveis erros na instalação.

* **Reinicialização programada**:

  * Agendamento automático para reinicialização em 60 segundos após instalação.
  * Aviso claro sobre como cancelar a reinicialização caso necessário.

## Pós-execução

Após a execução bem-sucedida do script, ocorrerá automaticamente:

* Ativação imediata e persistente do serviço `qemu-guest-agent`.
* Reinicialização agendada para aplicar corretamente as alterações necessárias.

Você pode verificar o status do serviço com o comando:

```bash
systemctl status qemu-guest-agent
```

Para cancelar a reinicialização agendada, execute:

```bash
shutdown -c
```

## Compatibilidade

- Testado no Ubuntu 22.04 LTS.

---


# autologout-install.sh

**Para executar o script, use:**
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/autologout-install.sh)"
```

**Descrição:**  
Script em bash para automatizar a configuração de logout automático após um período de inatividade em servidores Linux, melhorando a segurança ao encerrar sessões ociosas.

## Características

* **Configuração automática de timeout**:
  * Define TMOUT=900 (15 minutos de inatividade)
  * Configura a variável como somente leitura para evitar que usuários desativem o recurso
  * Implementa o recurso via `/etc/profile.d/`, aplicando-se a todos os usuários do sistema

* **Segurança aprimorada**:
  * Encerra automaticamente sessões de terminal inativas
  * Reduz o risco de acessos não autorizados através de terminais abandonados
  * Implementação limpa usando mecanismos padrão do sistema

* **Facilidade de uso**:
  * Instalação simples através de um único comando
  * Não requer reinicialização do sistema

## Pós-execução

Após a execução bem-sucedida do script:

* A configuração estará ativa para novas sessões de terminal
* Usuários com sessões existentes precisarão fazer logout e login novamente para que a configuração seja aplicada
* Todas as novas sessões de terminal serão automaticamente encerradas após 15 minutos de inatividade

Você pode verificar se a configuração está ativa em sua sessão com o comando:

```bash
echo $TMOUT
```

## Compatibilidade

- Testado no Ubuntu 22.04 LTS.

---

# initial-settings.sh

**Para executar o script, use:**
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/initial-settings.sh)"
```

**Descrição:**  
Script em bash com menu interativo para automatizar a configuração inicial de servidores Linux.

## Menu de Opções

```
═══════════════════════════════════════
    CONFIGURAÇÕES INICIAIS LINUX
═══════════════════════════════════════

 Configurações Básicas:
   1) Fuso horário, locale e SSH
   2) Limitar uso do journald
   3) Configurar autologout (15 min)

 Atualizações Automáticas:
   4) Unattended-upgrades (com email)
   5) Unattended-upgrades (sem email)

 Executar Múltiplas:
   A) TODAS as opções (1-5, upgrades sem email)
   0) Sair
```

## Características

* **Configurações Básicas:**
  * Fuso horário: `America/Sao_Paulo`
  * Locale: `pt_BR.UTF-8`
  * Segurança SSH: Opção para permitir/restringir login root

* **Limites do Journald:**
  * `SystemMaxUse=300M`
  * `MaxRetentionSec=1month`

* **Autologout:**
  * Encerra sessões inativas após 15 minutos

* **Atualizações Automáticas:**
  * Integração com `unattended-upgrades-install.sh`
  * Opção com email (requer `/etc/unattend.conf`) ou sem email

## Pós-execução

É recomendada a reinicialização do sistema para aplicar completamente todas as configurações.

## Compatibilidade

- Testado no Ubuntu 22.04 LTS.

---

# btop-install.sh

**Para executar o script, use:**
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/btop-install.sh)"
```

**Descrição:**  
Script em bash para automatizar a instalação do btop, um monitor avançado de sistema para Linux com interface TUI moderna e recursos completos de monitoramento de CPU, memória, discos e rede.

## Características

* **Detecção automática de arquitetura**:
  * Suporte para arquiteturas x86_64 e aarch64/arm64
  * Seleção automática do pacote correto para download

* **Instalação completa**:
  * Download da versão estável mais recente (v1.4.2)
  * Extração e instalação via make
  * Limpeza automática de arquivos temporários após instalação

* **Tratamento de erros**:
  * Verificação de permissões de administrador
  * Validação de cada etapa do processo de instalação
  * Mensagens informativas sobre o progresso

## Pós-execução

Após a execução bem-sucedida do script:

* O btop estará instalado e pronto para uso
* Você poderá iniciar o monitor de sistema digitando `btop` no terminal

## Compatibilidade

- Testado no Ubuntu 22.04 LTS.
- Suporta arquiteturas x86_64 e aarch64/arm64.

---


# n8n-install.sh

**Para executar o script, use:**
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/n8n-install.sh)"
```

**Descrição:**  
Script em bash para instalar ou atualizar o n8n (plataforma de automação de workflows) em servidores Linux bare-metal, com configuração segura e automatizada via arquivo externo.

## Características

- **Instalação e atualização automática** do n8n via npm global
- **Criação de usuário de serviço dedicado** (`n8n`) e diretórios de dados/logs
- **Configuração automática do serviço systemd** para inicialização e gerenciamento
- **Instalação automática do Node.js 22.x** caso não esteja presente
- **Mensagens informativas** durante todo o processo

## Pós-execução

Após a execução bem-sucedida do script:

- O serviço `n8n` estará instalado, ativo e configurado para iniciar automaticamente
- O acesso estará disponível em `http://<IP_DO_SERVIDOR>:5678`
- O serviço pode ser gerenciado via systemd:
  - `sudo systemctl status n8n`
  - `sudo systemctl restart n8n`

## Compatibilidade

- Testado no Ubuntu/Debian
- Requer privilégios de root (sudo)
- Instala Node.js 22.x automaticamente, se necessário




