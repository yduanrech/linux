# Plano: `gickup-install.sh` para Linux AMD64

## Resumo

Criar um script novo na raiz, `gickup-install.sh`, no padrão do repositório: menu interativo por padrão, subcomandos para uso direto, `--dry-run`, foco em Debian/Ubuntu e instalação do binário oficial `linux_amd64` do Gickup.

Como você quer seguir o modelo do próprio projeto, o plano fecha com:
- `cron:` no `conf.yml`
- `gickup` executado como processo contínuo
- `systemd service` simples para subir no boot e manter o processo vivo

## Mudanças principais

- Adicionar `gickup-install.sh` com estes fluxos:
  - `init`: instala dependências, baixa o latest release `linux_amd64`, valida checksum, instala `/usr/local/bin/gickup`, cria usuário `gickup`, diretórios, config base e unit do `systemd`.
  - `update-binary`: garante dependências mínimas, atualiza apenas o binário e preserva config/serviço.
  - `validate-config`: falha se ainda houver placeholders `CHANGE_ME`; depois executa `gickup --dryrun /etc/gickup/conf.yml`.
  - `enable-service`: valida config antes de `systemctl enable --now gickup`.
  - `restart-service`: reinicia o serviço.
  - `status`: mostra versão instalada e estado do serviço.
  - `-h|--help`: ajuda.
- Menu interativo:
  - `1) Init / instalar base`
  - `2) Atualizar binário`
  - `3) Validar config`
  - `4) Habilitar/iniciar serviço`
  - `5) Reiniciar serviço`
  - `6) Ver status/versão`
  - `7) Ajuda`
  - `0) Sair`
- Instalação de dependências:
  - Detectar Debian/Ubuntu com `apt-get`.
  - Instalar, se faltarem: `curl`, `ca-certificates`, `tar`, `git`, `git-lfs`.
  - Executar `git lfs install --system`.
- Instalação do binário:
  - Consultar o latest release do GitHub em tempo de execução.
  - Selecionar o asset `linux_amd64.tar.gz`.
  - Baixar checksums e validar antes do `install`.
  - Extrair apenas o binário `gickup`.
  - Instalar em `/usr/local/bin/gickup` com `0755 root:root`.
  - Manter backup anterior em `/usr/local/bin/gickup.bak` quando existir.
- Estrutura criada no sistema:
  - `/etc/gickup/conf.yml`
  - `/etc/systemd/system/gickup.service`
  - `/var/lib/gickup`
  - `/var/log/gickup`
  - `/var/backups/gickup`
- Serviço `systemd`:
  - `User=gickup`, `Group=gickup`
  - `WorkingDirectory=/etc/gickup`
  - `Environment=HOME=/var/lib/gickup`
  - `ExecStart=/usr/local/bin/gickup /etc/gickup/conf.yml`
  - `Restart=on-failure`
  - sem timer; o agendamento fica no `cron:` do YAML
- Config base gerada:
  - Cabeçalho `Managed by gickup-install.sh`.
  - Permissão `0640`, dono `root:gickup`.
  - Template mínimo para edição posterior:
    - `cron: "0 3 * * *"`
    - diretório de logs em `/var/log/gickup`
    - `source` comentado com placeholders `CHANGE_ME`
    - `destination.local` apontando para `/var/backups/gickup`
  - O script só cria o arquivo se ele não existir; recriação exige `--force`.
- Proteção contra sobrescrita:
  - `update-binary` nunca altera `conf.yml`.
  - `init` reusa `conf.yml` existente; só regrava com `--force`.
  - A unit do `systemd` pode ser regravada por ser artefato gerenciado.
- Documentação do repo:
  - adicionar `docs/scripts/gickup-install.md`
  - incluir entrada na tabela do `README.md`

## Interfaces públicas

- Novo script público: `gickup-install.sh`
- Uso esperado:
  - `bash -c "$(curl -fsSL .../gickup-install.sh)"`
  - `bash -c "$(curl -fsSL .../gickup-install.sh)" -- init`
  - `bash -c "$(curl -fsSL .../gickup-install.sh)" -- update-binary`
  - `bash -c "$(curl -fsSL .../gickup-install.sh)" -- validate-config`
  - `bash -c "$(curl -fsSL .../gickup-install.sh)" -- enable-service`
- Flags globais:
  - `--dry-run`
  - `--force`

## Testes e validação

- `init --dry-run` mostra:
  - instalação das dependências
  - descoberta do latest release
  - asset `linux_amd64`
  - validação de checksum
  - criação de usuário, diretórios, config e service
- `init` real em host limpo:
  - instala `curl`, `ca-certificates`, `tar`, `git`, `git-lfs` se faltarem
  - executa `git lfs install --system`
  - instala o binário em `/usr/local/bin/gickup`
  - cria `gickup` user
  - cria `conf.yml` com `0640 root:gickup`
  - cria `gickup.service`
- `validate-config`:
  - falha com template intacto
  - passa após config válida
- `enable-service`:
  - recusa start com config template/inválida
  - habilita e inicia com config válida
- `status`:
  - mostra `gickup --version`
  - mostra `systemctl status gickup` resumido
- `update-binary`:
  - preserva `conf.yml`
  - preserva o service
  - mantém backup `.bak`

## Assunções e padrões escolhidos

- Escopo é Linux AMD64 apenas.
- A atualização sempre busca o release mais recente em tempo de execução.
- O modelo escolhido segue o fluxo documentado do projeto: `cron:` dentro do YAML.
- O `systemd` existe apenas para manter o processo do `gickup` rodando de forma estável no host.
- A config inicial será uma base genérica comentada para edição manual posterior.
