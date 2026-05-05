# Gickup para Linux AMD64

O plano foi implementado no script:

```text
gickup-install.sh
```

A documentação completa de uso, tokens, permissões por repositório, seleção de repositórios no Gickup, Codeberg e serviço systemd está em:

```text
docs/scripts/gickup-install.md
```

Fluxo rápido:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- init
nano /etc/gickup/gickup.env
nano /etc/gickup/conf.yml
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- validate-config
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- enable-service
```
