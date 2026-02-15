# `qemu-agent-install.sh`

Instala e habilita `qemu-guest-agent`.

## Executar

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/qemu-agent-install.sh)"
```

## O que o script faz

- Executa `apt-get update`
- Instala `qemu-guest-agent`
- Habilita e inicia o serviço
- Agenda reboot em 1 minuto

## Comandos úteis

Status do serviço:

```bash
systemctl status qemu-guest-agent
```

Cancelar reboot agendado:

```bash
shutdown -c
```

