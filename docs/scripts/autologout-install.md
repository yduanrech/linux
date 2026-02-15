# `individuais/autologout-install.sh`

Configura autologout para shells Bash inativos (`TMOUT=900`).

## Executar

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/individuais/autologout-install.sh)"
```

## O que o script faz

- Cria `/etc/profile.d/autologout.sh`
- Define:
  - `TMOUT=900`
  - `readonly TMOUT`
  - `export TMOUT`

## Validação

Após abrir nova sessão:

```bash
echo $TMOUT
```

