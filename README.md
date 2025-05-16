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
    - `10periodic` (Criado automaticamente)
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
Script em bash para automatizar a configuração inicial de servidores Linux, definindo o fuso horário para São Paulo/Brasil, configurando o locale para pt_BR.UTF-8 e implementando configurações de segurança SSH.

## Características

* **Automação completa** para configurar:

  * Fuso horário:
    * Configura para `America/Sao_Paulo`
  
  * Locale:
    * Gera o locale `pt_BR.UTF-8`
    * Define `pt_BR.UTF-8` como locale padrão do sistema
    
  * Segurança SSH:
    * Opção para restringir login SSH do usuário root (permite apenas login com chaves)
    * Configuração interativa com confirmação do usuário
    * Reinício automático do serviço SSH para aplicar as alterações

* **Facilidade de uso**:
  * Mensagens claras e informativas durante o processo
  * Verificação de permissões para garantir execução como root
  * Processo interativo para decisões de segurança

## Pós-execução

Após a execução bem-sucedida do script:

* O sistema estará configurado com fuso horário de São Paulo/Brasil
* O locale padrão será pt_BR.UTF-8
* Se selecionado, o login SSH para root será restrito apenas para autenticação com chaves

Você pode verificar as configurações com os comandos:

```bash
# Verificar fuso horário
timedatectl

# Verificar locale
locale

# Verificar configurações SSH
grep PermitRootLogin /etc/ssh/sshd_config
```

Para adicionar sua chave SSH pública ao servidor (caso tenha restringido login de root):

```bash
echo "SUA_CHAVE_SSH_PUBLICA" >> /root/.ssh/authorized_keys
```

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




