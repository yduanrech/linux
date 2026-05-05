# Guia: espelhar um repositório do GitHub para o Codeberg usando GitHub Actions

## Resumo

Sim, dá para automatizar o envio de um repositório do GitHub para o Codeberg usando apenas comandos Git dentro do GitHub Actions, sem instalar Gickup ou outra ferramenta externa.

A lógica é:

1. O GitHub Actions inicia uma máquina temporária, chamada runner.
2. O workflow clona o repositório de origem no GitHub.
3. O workflow faz push para um repositório de destino no Codeberg.
4. O runner é encerrado.

Como o backup ou espelho fica no Codeberg, não importa que o ambiente do GitHub Actions seja temporário.

## 1. O que será configurado

Você vai criar um arquivo YAML em:

```text
.github/workflows/mirror-codeberg.yml
```

Esse arquivo define um workflow do GitHub Actions que pode rodar de duas formas:

- manualmente, pelo botão **Run workflow**
- automaticamente, em horário agendado com `cron`

O workflow usará comandos Git comuns:

```bash
git clone --mirror URL_DA_ORIGEM repo.git
cd repo.git
git push --mirror URL_DO_DESTINO
```

## 2. Por que não precisa usar Gickup neste caso

O Gickup é útil quando você quer fazer backup de muitos repositórios, várias contas, várias organizações ou múltiplos destinos usando um arquivo de configuração.

Mas, para copiar um repositório específico do GitHub para um repositório específico no Codeberg, o Git puro já resolve.

O runner padrão do GitHub Actions já vem com `git` instalado. Portanto, você não precisa baixar binário, instalar dependência ou compilar nada.

## 3. Pré-requisitos

Antes de criar o workflow, você precisa ter:

1. Um repositório de origem no GitHub.
2. Um repositório de destino já criado no Codeberg.
3. Um token do Codeberg com permissão de escrita no repositório de destino.
4. Um token do GitHub com permissão de leitura no repositório de origem, principalmente se o repositório for privado.
5. Os tokens salvos como **GitHub Secrets**.

Exemplo de destino no Codeberg:

```text
https://codeberg.org/SEU_USUARIO/REPO_DESTINO
```

O repositório de destino precisa existir antes do primeiro push, a menos que você adicione comandos extras para criá-lo pela API do Codeberg.

## 4. Tokens e GitHub Secrets

Nunca coloque tokens diretamente no arquivo `.yml`. O correto é salvar os valores em **Secrets** no GitHub.

### 4.1 Secrets recomendados

| Secret | Uso |
| --- | --- |
| `GH_SOURCE_TOKEN` | Token do GitHub usado para ler o repositório de origem. Necessário se o repo for privado. |
| `CODEBERG_TOKEN` | Token do Codeberg usado para escrever no repositório de destino. |

Opcionalmente, você também pode salvar o usuário do Codeberg como secret:

| Secret | Uso |
| --- | --- |
| `CODEBERG_USER` | Usuário usado na autenticação HTTPS do Codeberg. |

Mas, se preferir, o usuário pode ficar escrito no YAML, porque ele não é secreto. O token é que deve ficar protegido.

### 4.2 Onde criar os secrets no GitHub

No repositório do GitHub onde o workflow vai rodar:

1. Entre em **Settings**.
2. Vá em **Secrets and variables**.
3. Clique em **Actions**.
4. Clique em **New repository secret**.
5. Crie os secrets:

```text
GH_SOURCE_TOKEN
CODEBERG_TOKEN
```

## 5. Opção recomendada: espelho fiel com `--mirror`

Use esta opção se você quer que o Codeberg seja uma cópia fiel do GitHub.

Ela copia:

- branches
- tags
- histórico de commits
- refs do repositório

### 5.1 Atenção importante sobre `--mirror`

O comando abaixo é agressivo:

```bash
git push --mirror
```

Ele tenta fazer o destino ficar igual à origem.

Isso significa que, se uma branch ou tag existir no Codeberg mas não existir mais no GitHub, ela pode ser removida do Codeberg no próximo push.

Use `--mirror` quando:

- o GitHub é a fonte oficial
- o Codeberg é apenas backup ou espelho
- você não pretende editar diretamente no Codeberg

### 5.2 Workflow completo com `--mirror`

Crie o arquivo:

```text
.github/workflows/mirror-codeberg.yml
```

Conteúdo:

```yaml
name: Mirror para Codeberg

on:
  workflow_dispatch:
  schedule:
    - cron: "0 3 * * *"

jobs:
  mirror:
    runs-on: ubuntu-latest

    steps:
      - name: Espelhar GitHub para Codeberg
        env:
          GH_SOURCE_TOKEN: ${{ secrets.GH_SOURCE_TOKEN }}
          CODEBERG_TOKEN: ${{ secrets.CODEBERG_TOKEN }}
          CODEBERG_USER: SEU_USUARIO_CODEBERG
        run: |
          git clone --mirror https://x-access-token:${GH_SOURCE_TOKEN}@github.com/USUARIO_GITHUB/REPO_ORIGEM.git repo.git
          cd repo.git
          git push --mirror https://${CODEBERG_USER}:${CODEBERG_TOKEN}@codeberg.org/USUARIO_CODEBERG/REPO_DESTINO.git
```

### 5.3 O que trocar no exemplo

| Texto no exemplo | Substituir por |
| --- | --- |
| `USUARIO_GITHUB` | Seu usuário ou organização no GitHub. |
| `REPO_ORIGEM` | Nome do repositório original no GitHub. |
| `SEU_USUARIO_CODEBERG` | Usuário usado para autenticar no Codeberg. Normalmente é seu usuário Codeberg. |
| `USUARIO_CODEBERG` | Usuário ou organização onde está o repositório de destino no Codeberg. |
| `REPO_DESTINO` | Nome do repositório já criado no Codeberg. |

## 6. Opção menos agressiva: copiar branches e tags

Use esta opção se você não quer que o workflow apague branches ou tags extras existentes no Codeberg.

Ela faz:

```bash
git push codeberg --all
git push codeberg --tags
```

Isso envia branches e tags da origem para o destino, mas não tenta deixar o destino idêntico à origem.

### 6.1 Workflow completo com `--all` e `--tags`

```yaml
name: Copiar para Codeberg

on:
  workflow_dispatch:
  schedule:
    - cron: "0 3 * * *"

jobs:
  copy:
    runs-on: ubuntu-latest

    steps:
      - name: Copiar branches e tags para Codeberg
        env:
          GH_SOURCE_TOKEN: ${{ secrets.GH_SOURCE_TOKEN }}
          CODEBERG_TOKEN: ${{ secrets.CODEBERG_TOKEN }}
          CODEBERG_USER: SEU_USUARIO_CODEBERG
        run: |
          git clone https://x-access-token:${GH_SOURCE_TOKEN}@github.com/USUARIO_GITHUB/REPO_ORIGEM.git repo
          cd repo
          git remote add codeberg https://${CODEBERG_USER}:${CODEBERG_TOKEN}@codeberg.org/USUARIO_CODEBERG/REPO_DESTINO.git
          git push codeberg --all
          git push codeberg --tags
```

## 7. Quando usar cada opção

| Situação | Melhor opção |
| --- | --- |
| Quero um backup ou espelho fiel do GitHub no Codeberg | `--mirror` |
| Quero evitar apagar coisas que só existem no Codeberg | `--all` + `--tags` |
| Vou editar tanto no GitHub quanto no Codeberg | Evite `--mirror`; escolha uma origem oficial ou faça fluxo manual |
| Codeberg será apenas cópia de segurança | `--mirror` |

## 8. Como funciona o agendamento

Este trecho faz o workflow rodar todos os dias às 03:00 UTC:

```yaml
schedule:
  - cron: "0 3 * * *"
```

A sintaxe é:

```text
minuto hora dia-do-mes mês dia-da-semana
```

Exemplos:

| Cron | Quando roda |
| --- | --- |
| `0 3 * * *` | Todos os dias às 03:00 UTC |
| `0 */6 * * *` | A cada 6 horas |
| `30 2 * * 1` | Toda segunda-feira às 02:30 UTC |
| `0 0 * * 0` | Todo domingo à meia-noite UTC |

O horário do GitHub Actions usa UTC. Se você estiver no Brasil, precisa converter para o horário local.

## 9. Como rodar manualmente

O trecho abaixo adiciona o botão manual:

```yaml
workflow_dispatch:
```

Depois que o arquivo estiver no repositório:

1. Abra o repositório no GitHub.
2. Clique em **Actions**.
3. Selecione o workflow.
4. Clique em **Run workflow**.

Isso é útil para testar antes de depender do agendamento.

## 10. HTTPS com token no Codeberg

A URL de destino segue este formato:

```text
https://USUARIO:TOKEN@codeberg.org/USUARIO_OU_ORG/REPO.git
```

No workflow, usando variáveis:

```bash
git push --mirror https://${CODEBERG_USER}:${CODEBERG_TOKEN}@codeberg.org/USUARIO_CODEBERG/REPO_DESTINO.git
```

O token não aparece diretamente no YAML porque vem de:

```yaml
CODEBERG_TOKEN: ${{ secrets.CODEBERG_TOKEN }}
```

Mesmo assim, evite imprimir URLs com token nos logs.

## 11. Sobre segurança dos tokens

Boas práticas:

- use tokens com o menor nível de permissão possível
- não coloque token dentro do YAML
- não dê permissão administrativa se só precisa de escrita Git
- se o token vazar, revogue e gere outro
- evite usar token pessoal principal em muitos workflows diferentes

## 12. Erros comuns

### 12.1 Authentication failed

Mensagem típica:

```text
fatal: Authentication failed
```

Causas comuns:

- token incorreto
- token expirado
- token sem permissão de leitura ou escrita
- usuário do Codeberg errado
- URL de destino escrita incorretamente

### 12.2 Repository not found

Mensagem típica:

```text
repository not found
```

Causas comuns:

- o repositório de destino ainda não foi criado no Codeberg
- nome do usuário, organização ou repositório está errado
- token não tem acesso ao repositório privado

### 12.3 Remote rejected

Mensagem típica:

```text
remote rejected
```

Causas comuns:

- branch protegida no destino
- token sem permissão suficiente
- repositório configurado para bloquear force push
- uso de `--mirror` tentando alterar refs protegidas

### 12.4 Push apagou branch ou tag no Codeberg

Isso pode acontecer com:

```bash
git push --mirror
```

Se você não quer esse comportamento, use a opção menos agressiva:

```bash
git push codeberg --all
git push codeberg --tags
```

## 13. Teste recomendado

Antes de usar no repositório importante:

1. Crie um repositório pequeno de teste no GitHub.
2. Crie um repositório vazio de teste no Codeberg.
3. Configure o workflow no GitHub.
4. Rode manualmente com **Run workflow**.
5. Verifique no Codeberg se branches, tags e commits chegaram corretamente.
6. Só depois aplique no repositório real.

## 14. Exemplo final recomendado

Para backup fiel do GitHub para Codeberg, este é o modelo recomendado:

```yaml
name: Mirror para Codeberg

on:
  workflow_dispatch:
  schedule:
    - cron: "0 3 * * *"

jobs:
  mirror:
    runs-on: ubuntu-latest

    steps:
      - name: Espelhar GitHub para Codeberg
        env:
          GH_SOURCE_TOKEN: ${{ secrets.GH_SOURCE_TOKEN }}
          CODEBERG_TOKEN: ${{ secrets.CODEBERG_TOKEN }}
          CODEBERG_USER: SEU_USUARIO_CODEBERG
        run: |
          git clone --mirror https://x-access-token:${GH_SOURCE_TOKEN}@github.com/USUARIO_GITHUB/REPO_ORIGEM.git repo.git
          cd repo.git
          git push --mirror https://${CODEBERG_USER}:${CODEBERG_TOKEN}@codeberg.org/USUARIO_CODEBERG/REPO_DESTINO.git
```

Use este modelo quando o GitHub for a fonte principal e o Codeberg for apenas espelho ou backup.

## 15. Checklist rápido

Antes de considerar pronto, confirme:

- [ ] O repositório de destino existe no Codeberg.
- [ ] O secret `GH_SOURCE_TOKEN` foi criado no GitHub.
- [ ] O secret `CODEBERG_TOKEN` foi criado no GitHub.
- [ ] O YAML está em `.github/workflows/mirror-codeberg.yml`.
- [ ] Os nomes de usuário, organização e repositório foram substituídos corretamente.
- [ ] O workflow foi testado manualmente.
- [ ] O Codeberg recebeu commits, branches e tags como esperado.

## 16. Conclusão

Para o seu caso, não é necessário usar Gickup.

Se a intenção é mandar o repositório para o Codeberg como backup ou espelho, o melhor caminho é usar GitHub Actions com `git clone --mirror` e `git push --mirror`.

Se você quer evitar apagamentos no Codeberg, use `git push --all` e `git push --tags`.

A escolha principal é:

```text
Backup fiel:      use --mirror
Cópia sem apagar: use --all + --tags
```
