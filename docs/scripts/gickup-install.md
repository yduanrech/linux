# `gickup-install.sh`

Instala e atualiza o `gickup` em Linux `amd64`, cria uma configuração base para mirror GitHub -> Codeberg e prepara um serviço `systemd` para manter o processo rodando.

O template inicial é opinativo para GitHub -> Codeberg porque esse é o fluxo mais comum deste repositório. O script não limita o Gickup a esses serviços: depois do `init`, você pode editar `/etc/gickup/conf.yml` e usar qualquer `source` ou `destination` suportado pelo Gickup.

O Gickup usa o `cron:` dentro do `conf.yml` para agendar execuções. O `systemd` criado por este script não agenda o backup; ele apenas inicia o Gickup no boot, mantém o processo ativo e reinicia em caso de falha.

Referências principais:

- Gickup: https://gickup.dev/
- Instalação: https://gickup.dev/installation/
- GitHub source: https://cooperspencer.github.io/gickup-documentation/configuration/source_docu/github/
- Gitea/Codeberg destination: https://gickup.dev/configuration/destination_docu/gitea/
- Mirror para Codeberg: https://gickup.dev/blog/codeberg-mirror/

## Executar

Menu interativo:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)"
```

Modo direto:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- init
```

O `--` após `bash -c` é necessário para passar argumentos ao script baixado.

No menu interativo, o script também pode perguntar:

- qual agendamento `cron` usar
- usuário ou organização de origem no GitHub
- repositório(s) de origem no GitHub
- usuário ou organização de destino no Codeberg

O Gickup cria/atualiza os repositórios no destino usando o mesmo nome da origem. Por exemplo, `github.com/yduanrech/orbys` vira `codeberg.org/yduanrech/orbys`.

## Fluxo recomendado

Primeira execução:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- init
```

Depois edite:

```bash
nano /etc/gickup/gickup.env
nano /etc/gickup/conf.yml
```

Para recriar o `conf.yml` perguntando cron e repositórios:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- configure
```

Valide antes de iniciar:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- validate-config
```

Habilite o serviço:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- enable-service
```

Forçar uma execução agora, sem esperar o próximo `cron`:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- run-now
```

Ver status:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- status
```

## O que o script instala

O `init` faz:

- instala dependências ausentes: `curl`, `ca-certificates`, `tar`, `git`, `git-lfs`
- executa `git lfs install --system`
- baixa o latest release do Gickup para `linux_amd64`
- baixa o arquivo de checksum do release
- valida checksum antes de instalar
- instala o binário em `/usr/local/bin/gickup`
- cria usuário/grupo de serviço `gickup`
- cria `/etc/gickup/conf.yml`
- cria `/etc/gickup/gickup.env`
- cria `/etc/systemd/system/gickup.service`
- cria diretórios de estado, log e backup local opcional

O serviço não é habilitado automaticamente no `init`. Isso evita iniciar o Gickup com placeholders ou tokens ausentes.

Durante `validate-config`, o Gickup pode criar o arquivo de log como `root` porque a validação roda com privilégios administrativos. O script corrige o dono de `/var/log/gickup` e `/var/backups/gickup` de volta para `gickup:gickup` antes de iniciar ou reiniciar o serviço.

## Agendamento

O menu de configuração oferece opções prontas:

| Opção | Cron | Quando roda |
| --- | --- | --- |
| A cada 1 hora | `0 * * * *` | No minuto zero de cada hora |
| Todo dia às 03:00 | `0 3 * * *` | Uma vez por dia às 03:00 |
| A cada 6 horas | `0 */6 * * *` | 00:00, 06:00, 12:00, 18:00 |
| Todo domingo às 03:00 | `0 3 * * 0` | Semanalmente |
| Personalizado | informado no prompt | Conforme expressão cron |

O horário usa o fuso horário do host.

## Arquivos criados

| Caminho | Função | Permissão |
| --- | --- | --- |
| `/usr/local/bin/gickup` | Binário do Gickup | `0755 root:root` |
| `/usr/local/bin/gickup.bak` | Backup do binário anterior, quando existir | `0755 root:root` |
| `/etc/gickup/conf.yml` | Configuração principal do Gickup | `0640 root:gickup` |
| `/etc/gickup/gickup.env` | Tokens como variáveis de ambiente | `0640 root:gickup` |
| `/etc/systemd/system/gickup.service` | Serviço systemd | `0644 root:root` |
| `/var/lib/gickup` | HOME/estado do serviço | `0750 gickup:gickup` |
| `/var/log/gickup` | Logs do Gickup | `0750 gickup:gickup` |
| `/var/backups/gickup` | Destino local opcional | `0750 gickup:gickup` |

## Como selecionar quais repositórios serão clonados

A seleção é feita no `/etc/gickup/conf.yml`, em `source.github`.

Para clonar somente repositórios específicos:

```yaml
source:
  github:
    - token: GICKUP_GITHUB_TOKEN
      user: meu-usuario-ou-org
      include:
        - repo-a
        - repo-b
        - repo-c
```

Para excluir alguns repositórios:

```yaml
source:
  github:
    - token: GICKUP_GITHUB_TOKEN
      user: meu-usuario-ou-org
      exclude:
        - repo-antigo
        - repo-teste
```

Para filtrar organizações:

```yaml
source:
  github:
    - token: GICKUP_GITHUB_TOKEN
      includeorgs:
        - minha-org
```

Regra prática:

- use `include` quando quiser controle explícito
- use `exclude` quando quiser quase tudo, exceto alguns
- use `includeorgs` para restringir organizações
- não omita filtros se o token enxergar mais repositórios do que você quer espelhar

## Tokens

O script separa tokens do YAML.

No `/etc/gickup/conf.yml`, ficam apenas os nomes das variáveis:

```yaml
source:
  github:
    - token: GICKUP_GITHUB_TOKEN

destination:
  gitea:
    - token: GICKUP_CODEBERG_TOKEN
```

Os valores reais ficam em `/etc/gickup/gickup.env`:

```bash
GICKUP_GITHUB_TOKEN=github_pat_xxx
GICKUP_CODEBERG_TOKEN=codeberg_token_xxx
```

O Gickup resolve esses nomes como variáveis de ambiente. Isso evita gravar tokens diretamente no `conf.yml`.

Se algum token tiver caracteres especiais de shell, coloque o valor entre aspas simples:

```bash
GICKUP_CODEBERG_TOKEN='valor-com-caracteres-especiais'
```

### GitHub

Para GitHub, use um **fine-grained personal access token** sempre que possível.

Configuração recomendada:

- **Resource owner**: usuário ou organização de origem
- **Repository access**: **Only select repositories**
- selecione apenas os repositórios que o Gickup deve ler
- **Repository permissions -> Contents**: `Read-only`
- se usar `issues: true`, conceda também permissão de leitura para Issues
- se a organização exigir aprovação de fine-grained PAT, aguarde aprovação antes de testar

Essa é a camada de segurança do GitHub. Mesmo que alguém altere o `include` no `conf.yml`, o token não deve conseguir ler repositórios fora da seleção feita no GitHub.

Documentação oficial: https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token

### Codeberg

O destino Codeberg usa a integração `gitea` do Gickup:

```yaml
destination:
  gitea:
    - url: https://codeberg.org/
      token: GICKUP_CODEBERG_TOKEN
      user: meu-usuario-ou-org-codeberg
      mirror:
        enabled: true
      visibility:
        repositories: private
      force: true
```

O blog do Gickup recomenda `mirror.enabled: true` para Codeberg porque o mirror nativo do Codeberg fica desabilitado por padrão.

Sobre permissões:

- o token precisa ter `read:user`
- o token precisa ter `write:repository` para criar/atualizar repositórios no destino
- se o destino for um usuário, o token normalmente é do próprio usuário
- se o destino for uma organização, prefira um usuário/bot dedicado no Codeberg e adicione também permissão de organização quando a UI/API exigir
- conceda a esse usuário/bot apenas acesso aos repositórios ou à organização de destino
- se o token vazar, revogue e gere outro

Crie o token em:

```text
https://codeberg.org/user/settings/applications
```

Permissões mínimas para este fluxo:

| Permissão | Valor |
| --- | --- |
| `repository` | Ler e escrever |
| `user` | Ler |

Para o erro:

```text
token does not have at least one of required scope(s): [read:user]
```

O problema está no token usado em `GICKUP_CODEBERG_TOKEN`, não no token GitHub. Recrie ou edite o token no Codeberg/Forgejo com pelo menos:

```text
read:user
write:repository
```

`write:repository` já inclui leitura de repositório. Se o destino for uma organização e o Gickup precisar consultar/criar dentro dela, adicione também o escopo de organização correspondente.

Atenção: no Codeberg/Forgejo, tokens com **repositórios específicos selecionados** só podem usar escopos de issue e repository. Como o Gickup também precisa de `read:user`, não use a restrição por repositório específico para este token. Para reduzir o risco, use uma conta dedicada no Codeberg e dê a ela acesso apenas ao destino necessário.

A documentação do Codeberg sobre access tokens informa que tokens dão acesso à conta. Para menor privilégio real, use uma conta dedicada e controle o acesso dessa conta via permissões de repositório, colaborador ou equipe.

Documentação:

- Access tokens: https://docs.codeberg.org/advanced/access-token/
- Repository permissions: https://docs.codeberg.org/collaborating/repo-permissions/

## Exemplo completo: GitHub para Codeberg

`/etc/gickup/gickup.env`:

```bash
GICKUP_GITHUB_TOKEN=github_pat_xxx
GICKUP_CODEBERG_TOKEN=codeberg_token_xxx
```

`/etc/gickup/conf.yml`:

```yaml
cron: "0 3 * * *"

log:
  file-logging:
    dir: /var/log/gickup
    file: gickup.log
    maxage: 7

source:
  github:
    - token: GICKUP_GITHUB_TOKEN
      user: meu-usuario-github
      include:
        - repo-a
        - repo-b
      wiki: false
      issues: false
      starred: false
      filter:
        excludearchived: false
        excludeforks: false

destination:
  gitea:
    - url: https://codeberg.org/
      token: GICKUP_CODEBERG_TOKEN
      user: meu-usuario-codeberg
      mirror:
        enabled: true
      visibility:
        repositories: private
        organizations: private
      force: true
      lfs: false
```

## Outros providers

O script cria apenas um template GitHub -> Codeberg. Para outros cenários, edite `/etc/gickup/conf.yml` conforme a documentação do Gickup.

Exemplos de mudança:

- GitHub -> backup local: remova `destination.gitea` e habilite `destination.local`.
- GitHub -> outro Gitea: mantenha `destination.gitea`, mas troque `url`, `token` e `user`.
- GitLab/Gitea/Codeberg como origem: troque `source.github` pelo bloco de origem suportado pelo Gickup.

O serviço `systemd` continua igual, porque ele só executa:

```bash
/usr/local/bin/gickup /etc/gickup/conf.yml
```

## Git LFS

Seu repositório atual não usa LFS, então o template deixa `lfs: false`.

Se algum repositório usar LFS:

- mantenha `git-lfs` instalado
- defina `lfs: true` no destino quando aplicável
- teste com `validate-config`
- confirme no Codeberg se os objetos LFS foram enviados corretamente

O Gickup documenta suporte a LFS para destino local e opção `lfs` em destinos Gitea. Ainda assim, LFS merece teste real antes de confiar como backup definitivo.

## Subcomandos

- `init`: instala dependências, baixa o binário, cria usuário, diretórios, config, env e service.
- `configure`: pergunta cron, origem GitHub, repositórios e destino Codeberg, depois recria `/etc/gickup/conf.yml`.
- `update-binary`: atualiza apenas `/usr/local/bin/gickup`; não altera config.
- `validate-config`: recusa placeholders e executa `gickup --dryrun` com o `cron:` removido temporariamente para validar uma execução única.
- `run-now`: executa backup/mirror imediatamente com o `cron:` removido temporariamente.
- `enable-service`: valida e roda `systemctl enable --now gickup.service`.
- `restart-service`: valida e reinicia `gickup.service`.
- `status`: mostra versão do Gickup e status do serviço.

## Atualizar o Gickup

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- update-binary
```

Se o serviço estiver rodando, reinicie depois:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/yduanrech/linux/refs/heads/main/gickup-install.sh)" -- restart-service
```

## Logs

Logs configurados no Gickup:

```bash
tail -f /var/log/gickup/gickup.log
```

Logs do serviço:

```bash
journalctl -u gickup -n 100 --no-pager
journalctl -u gickup -f
```

## Checklist

Antes de habilitar:

- [ ] `/etc/gickup/gickup.env` não tem `CHANGE_ME`
- [ ] `/etc/gickup/conf.yml` não tem `CHANGE_ME`
- [ ] token GitHub é fine-grained e só acessa os repositórios necessários
- [ ] token GitHub tem `Contents: Read-only`
- [ ] token Codeberg pertence ao usuário/conta correta
- [ ] token Codeberg tem `read:user`
- [ ] token Codeberg tem `write:repository`
- [ ] usuário/conta Codeberg tem permissão de escrita no destino
- [ ] `include` lista apenas os repositórios desejados
- [ ] `validate-config` passou

## Observações

- Requer Debian/Ubuntu.
- Requer Linux `amd64`.
- Requer execução como root.
- O `cron:` usa o fuso horário do host.
- O serviço nasce desabilitado até você rodar `enable-service`.
- Use `--dry-run` para ver as ações sem alterar o sistema.
- Use `--force` para recriar arquivos gerenciados existentes.
