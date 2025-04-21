# Cloud AutoDroid: Um Sistema Distribuído Escalável para Execução de Ferramentas de IA Generativa

A Cloud AutoDroid foi desenvolvida para resolver problemas de escalabilidade na execução de experimentos com redes neurais complexas, como a MalSynGen, que exigem alto poder computacional. Com uma arquitetura distribuída, a ferramenta permite a execução autoescalável de tarefas de IA. Disponível como um serviço SaaS (Software as a Service), a Cloud AutoDroid oferece uma plataforma para experimentação em larga escala, embora ainda requeira intervenção para a alocação inicial de nós.

# Estrutura <a name="estrutura"></a>

Por se tratar de um sistema distribuído, a Cloud AutoDroid foi desenvolvida em repositórios separados para cada componente:

- [AutoDroid API](https://github.com/MalwareDataLab/autodroid-api): API REST/GraphQL para gerenciamento de datasets, ferramentas de IA e experimentos, além da conexão com os nós de execução (worker) e as funcionalidades necessárias para o [MalwareDataLab](https://mdl.unihacker.club/).
- [AutoDroid Worker](https://github.com/MalwareDataLab/autodroid-worker): Serviço de execução de experimentos.

Para a elaboração deste artigo, foi desenvolvida uma aplicação de telemetria para monitoramento e solicitação dos experimentos, baseados em uma arquitetura cliente-servidor.

- [AutoDroid Watcher Server](https://github.com/MalwareDataLab/autodroid-watcher-server): Servidor de telemetria para monitoramento e solicitação dos experimentos.
- [AutoDroid Watcher Client](https://github.com/MalwareDataLab/autodroid-watcher-client): Aplicação cliente a ser iniciada no host de cada nó de execução (worker).

Cada repositório possui estrutura e documentação própria, acesse cada um para mais detalhes.

# Selos Considerados

Os autores julgam como considerados no processo de avaliação os selos:

- Artefatos Disponíveis (SeloD)
- Artefatos Funcionais (SeloF)
- Artefatos Sustentáveis (SeloS)
- Experimentos Reprodutíveis (SeloR)

Com base nos códigos e documentação disponibilizados neste e nos repositórios relacionados.

# Dependências <a name="dependências"></a>

A seguir, são listadas as dependências necessárias para a execução dos serviços da Cloud AutoDroid.

## Hardware

- Sistema operacional Linux (por exemplo, Ubuntu 20.04+, Debian 11+)
- Virtualização habilitada na BIOS
- CPU: Mínimo 2 cores (Recomendado: 4+ cores)
- RAM: Mínimo 4GB (Recomendado: 8GB+)
- Armazenamento: Mínimo 10GB livre (Recomendado: 20GB+ dependendo do volume de dados)

## Software

- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) instalado
- [Git](https://git-scm.com/downloads) instalado
- [Docker](https://docs.docker.com/get-docker/) instalado
- [Node.js](https://nodejs.org/en/download/) instalado

### Script de instalação do Git (https://git-scm.com/downloads)

```bash
sudo apt-get update
sudo apt-get install git
```

### Script de instalação Docker (https://docs.docker.com/get-docker/)

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### Script de instalação Node.js (https://nodejs.org/en/download)

```bash
# Download and install fnm:
curl -o- https://fnm.vercel.app/install | bash

# Download and install Node.js:
fnm install 22

# Important: restart the terminal to apply the changes.

# Verify the Node.js version:
node -v # Should print "v22.14.0".

# Verify npm version:
npm -v # Should print "10.9.2".
```

## Serviços

> **Observação aos revisores do SBRC25**: para facilitar o processo de revisão, foi disponibilizada uma máquina virtual pré-configurada com o arquivo .ova já com todas as credenciais configuradas, incluindo o projeto Firebase, bastando importar o arquivo e simplesmente prosseguir para os [experimentos](#experimentos), caso não consiga encontrá-lo/acessá-lo, favor entrar em contato com [luiz@laviola.dev](mailto:luiz@laviola.dev).

É necessário um projeto no [Firebase](https://firebase.google.com/) para a execução dos serviços da Cloud AutoDroid com as API Firebase Auth e Firebase Storage habilitadas.

As instruções para a criação e configuração do projeto Firebase estão disponíveis no [repositório da AutoDroid API](https://github.com/MalwareDataLab/autodroid-api?tab=readme-ov-file#firebase), contendo inclusive um passo a passo com capturas de tela.

> **Nota sobre o Firebase Storage**: O Firebase pode solicitar um cartão de crédito para habilitar o Storage, mesmo que você não ultrapasse o limite gratuito. No momento da escrita desta documentação, o Firebase oferece 5GB de armazenamento gratuito, o que é mais que suficiente para executar esta aplicação. Para mais detalhes sobre preços e limites, consulte a [documentação oficial do Firebase](https://firebase.google.com/pricing).

# Preocupações com segurança

- Portas: por padrão a porta 3333 é disponibilizada para a API, e a porta 3000 para o watcher. Estas portas estarão expostas na máquina local e podem ser acessadas externamente dependendo das configurações de sua máquina, firewall, rede, etc. Você pode alterar essas portas nas variáveis ambiente no arquivo `docker-compose.yml` ou `.env` no valor de `APP_PORT` na API e utilizando o parâmetro `-p` no watcher.

- Firebase: 
  - As credenciais do projeto Firebase são armazenadas no arquivo `docker-compose.yml` ou `.env` da API
  - Remova os valores após o uso
  - Certifique-se de encerrar o projeto ou desativar as configurações de cobrança
  - Use variáveis de ambiente em produção ao invés de hardcoding

- Dados:
  - Considere a privacidade e segurança dos dados processados
  - Implemente políticas de retenção de dados quando necessário
  - Utilize conexões seguras (HTTPS/SSL) em ambientes de produção

- Script: caso esteja utilizando o script de demonstração com o parâmetro `-p` (senha da sua conta no projeto Firebase), certifique-se de limpar o histórico de comandos do terminal utilizando o comando `history -c` ou similar.

- Desativação: 
  - Encerre todas as instâncias do backend e workers após o uso
  - Verifique se todos os containers Docker foram removidos
  - Limpe dados sensíveis dos volumes Docker quando aplicável

# Instalação

Existem duas maneiras de configurar o ambiente para executar os serviços da Cloud AutoDroid:

## Opção 1: Usando a VM Pré-configurada (Recomendado)

Para facilitar o processo de instalação e configuração, disponibilizamos uma máquina virtual (.ova) pré-configurada com todas as dependências necessárias. Esta é a maneira mais rápida e simples de começar pois a VM já possui todas as dependências instaladas e configuradas.

> **Observação aos revisores do SBRC25**: para facilitar o processo de revisão, foi disponibilizada uma máquina virtual pré-configurada com o arquivo .ova já com todas as credenciais configuradas, incluindo o projeto Firebase, bastando importar o arquivo e simplesmente prosseguir para os [experimentos](#experimentos), caso não consiga encontrá-lo/acessá-lo, favor entrar em contato com [luiz@laviola.dev](mailto:luiz@laviola.dev).

1. Baixe a VM do VirtualBox disponível em [https://github.com/MalwareDataLab/autodroid-sbrc25/releases/download/v0.0.1/autodroid-sbrc25-vm.zip](https://github.com/MalwareDataLab/autodroid-sbrc25/releases/download/v0.0.1/autodroid-sbrc25-vm.zip)
2. Importe o arquivo .ova no VirtualBox
3. Inicie a VM
4. Acesse o diretório do projeto:
   ```
   cd ~/autodroid-sbrc25
   ```

Prossiga para a execução dos experimentos [experimentos](#experimentos).

## Opção 2: Instalação Manual

Se preferir configurar manualmente o ambiente, certifique-se que as dependências listadas em [Dependências](#dependências) estão instaladas e operacionais, especialmente o Docker.

Estão disponibilizados um arquivo `docker-compose.yml` e um script `run.sh` para a execução dos serviços da Cloud AutoDroid. Este script contém todos os passos utilizados para um teste completo da ferramenta.

Alternativamente, você pode executar os serviços manualmente seguindo as instruções de cada repositório apresentado em [Estrutura](#estrutura).

A seguir, são apresentadas as instruções para a execução dos serviços utilizando o script `run.sh`.

Clone este repositório na máquina que irá executar os serviços:
```
git clone https://github.com/MalwareDataLab/autodroid-sbrc25.git
```

Acesse o diretório do projeto:

```
cd autodroid-sbrc25
```

## Configuração

### Autenticação e Armazenamento

Configure o projeto Firebase no arquivo `docker-compose.yml`, alterando as linhas conforme apresentado no [repositório da AutoDroid API](https://github.com/MalwareDataLab/autodroid-api?tab=readme-ov-file#firebase). Pode-se utilizar contas/projetos distintos entre os dois serviços (Authentication e Storage).

```yaml
# Providers
- FIREBASE_AUTHENTICATION_PROVIDER_PROJECT_ID=your-project-id
- FIREBASE_AUTHENTICATION_PROVIDER_CLIENT_EMAIL=your-service-account-email
- FIREBASE_AUTHENTICATION_PROVIDER_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYour Private Key Here\n-----END PRIVATE KEY-----\n"

- GOOGLE_STORAGE_PROVIDER_PROJECT_ID=your-project-id
- GOOGLE_STORAGE_PROVIDER_CLIENT_EMAIL=your-service-account-email
- GOOGLE_STORAGE_PROVIDER_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYour Private Key Here\n-----END PRIVATE KEY-----\n"
- GOOGLE_STORAGE_PROVIDER_BUCKET_NAME=your-project-id.appspot.com
```

### Conta do Usuário

Crie uma conta de usuário ou utilize uma conta existente no projeto Firebase, esta conta será utilizada para acessar a aplicação e para a execução dos experimentos.

```
curl --location 'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=YOUR_FIREBASE_API_KEY_HERE' \
--header 'Content-Type: application/json' \
--data-raw '
{
    "email": "your-email@example.com",
    "password": "your-password",
    "returnSecureToken": true
}'
```

Adicione o e-mail da conta criada na chave `ADMIN_EMAILS` no arquivo `docker-compose.yml`.

```yaml
- ADMIN_EMAILS=your-email@example.com
```

### Chave de API do Firebase

Obtenha a chave pública da API do Firebase no projeto Firebase, esta chave será utilizada para acessar o projeto Firebase e para a execução dos experimentos.

Esta chave pode ser encontrada no projeto Firebase, no console de desenvolvimento, no ícone de engrenagem ⚙ e depois na aba "Configuração do projeto", na aba "Geral", na seção "Chave de API da Web".

Guarde esta chave para ser utilizada como parâmetro `-k` no script de demonstração `run.sh`.

# Teste mínimo

Uma vez que todas as dependências e configurações necessárias estão realizadas, você pode executar o script de demonstração `run.sh` para testar o sistema.

## Uso

O script principal `run.sh` fornece um fluxo completo para executar o sistema. Ele suporta tanto workers locais quanto remotos.

### Uso Básico

```bash
./run.sh -k SUA_CHAVE_API_FIREBASE -u SEU_EMAIL -p SUA_SENHA
```

### Uso Avançado

```bash
./run.sh -k SUA_CHAVE_API_FIREBASE -u SEU_EMAIL -p SUA_SENHA -n NUM_WORKERS_LOCAIS -e TOTAL_WORKERS_ESPERADOS -w NUM_WATCHERS_ESPERADOS
```

#### Parâmetros

- `-k, --firebasekey`: Sua chave da API do Firebase (obrigatório)
- `-u, --username`: Seu email do Firebase (obrigatório)
- `-p, --password`: Sua senha do Firebase (obrigatório)
- `-n, --num-workers`: Número de containers worker a serem iniciados localmente (padrão: 1)
- `-e, --expected-workers`: Total de workers esperados (locais + remotos) (padrão: 1)
- `-w, --expected-watchers`: Número de watchers esperados (conexões do cliente de telemetria) (padrão: 1)
- `-h, --help`: Mostra a mensagem de ajuda

### Configuração de Workers Remotos

Ao usar workers remotos, o script exibirá instruções para configurar cada worker remoto. Você precisará:

1. Instalar o watcher client em cada máquina remota
2. Iniciar o container worker em cada máquina remota
3. Pressionar Enter no script principal para continuar após todos os workers estarem prontos

O script aguardará até que todos os workers esperados (locais + remotos) estejam disponíveis antes de prosseguir com o processamento do dataset.

### Telemetria

Durante a execução, o script gera um token de telemetria único para rastrear as métricas do experimento. Este token é gerado automaticamente e pode ser encontrado nos logs de execução. As métricas coletadas incluem:

- Uso de CPU por worker
- Tempo de processamento
- Distribuição de tarefas
- Status das requisições

Os dados de telemetria são armazenados localmente e podem ser analisados posteriormente na pasta `experiments`. Os dados estão organizados por data de execução e a iteração do experimento. Cada arquivo .csv representa um worker. O arquivo `statistics.csv` dentro da pasta de iteração contém as métricas agregadas de todos os workers, da iteração. A pasta `globalStatistics` contém as métricas agregadas de todos os workers de todas as iterações. Caso deseje desconsiderar um conjunto de iterações, você pode apenas excluir a pasta correspondente antes de executar o script de demonstração.

# Experimentos <a name="experimentos"></a>

Este trabalho realizou três ciclos de experimentos, conforme apresentados no artigo, Y solicitações de experimentos para X workers, sendo que o primeiro X=Y, o segundo X=2Y e o terceiro X=3Y.

Cada comando executa um ciclo de experimentos. O script inicia o backend e os bancos de dados, cria o dataset e registra a ferramenta de IA a ser utilizada, logo após, inicia o watcher e a quantidade de workers configurada no parâmetro `-n`, e solicita Y requisições conforme o parâmetro `-r`.

Conforme apresentado no artigo, o dataset, ferramenta de IA e parâmetros de configuração são constantes e estão configurados no script de demonstração `run.sh`. Além disso, o backend e os workers foram executados em máquinas distintas.

O script de demonstração, por padrão, irá iniciar o backend e os workers localmente, caso deseje uma execução remota para uma experimentação de maior fidelidade, defina o parâmetro `-n 0`, logo o script irá gerar o comando para que você inicie os workers remotos utilizando apenas o Docker, pressione para continuar apenas após iniciar os workers remotos. Caso deseje executar todos os serviços localmente, defina o parâmetro `-n` com o número de workers desejados.

Considerando que o objetivo foi analisar a escalabilidade do sistema (distribuição de trabalhos entre os workers), os resultados de tempo de execução e utilização de recursos irão variar conforme as características de cada máquina e a quantidade de workers utilizados nelas. As especificações de hardware/software das máquinas utilizadas no artigo estão apresentadas no mesmo.

As seções a seguir apresentam os comandos para executar os experimentos, respectivamente com X=Y, X=2Y e X=3Y.

Observação: ajuste os parâmetros `-n` e `-r` conforme a quantidade de workers (X) e requisições (Y) desejadas, respeitando a proporção Y/X da etapa.

## Reivindicação "Distribuição com balanceamento uniforme das tarefas"

Pode ser verificado que o backend distribui as tarefas igualmente entre os workers disponíveis, conforme apresentado no artigo.

```bash
./run.sh -k "sua-chave-de-api-do-firebase" -u "seu-email@exemplo.com" -p "sua-senha" -n 3 -r 9
```

Este script irá iniciar 3 workers localmente e solicitar 9 requisições para o backend.

## Experimento #1: X=Y

Nesta etapa, serão solicitados Y requisições para quantidade X de workers.

```bash
./run.sh -k "sua-chave-de-api-do-firebase" -u "seu-email@exemplo.com" -p "sua-senha" -n 3 -r 3
```

O backend deve ser capaz de processar as requisições e distribuir as tarefas igualmente entre os workers disponíveis (1 por worker).

## Experimento #2: X=2Y

Nesta etapa, serão solicitados 2Y requisições para quantidade X de workers.

```bash
./run.sh -k "sua-chave-de-api-do-firebase" -u "seu-email@exemplo.com" -p "sua-senha" -n 3 -r 6
```

O backend deve ser capaz de processar as requisições e distribuir as tarefas igualmente entre os workers disponíveis (2 por worker).

## Experimento #3: X=3Y

Nesta etapa, serão solicitados 3Y requisições para quantidade X de workers.

```bash
./run.sh -k "sua-chave-de-api-do-firebase" -u "seu-email@exemplo.com" -p "sua-senha" -n 3 -r 9
```

O backend deve ser capaz de processar as requisições e distribuir as tarefas igualmente entre os workers disponíveis (3 por worker).

### Experimentos extras (não apresentados no artigo)

Cenários de Exemplo

1. **Configuração apenas local** (1 worker):
```bash
./run.sh -k SUA_CHAVE_API_FIREBASE -u SEU_EMAIL -p SUA_SENHA
```

2. **Configuração apenas local** (múltiplos workers):
```bash
./run.sh -k SUA_CHAVE_API_FIREBASE -u SEU_EMAIL -p SUA_SENHA -n 3 -e 3
```

3. **Configuração híbrida** (2 workers locais, 3 workers remotos esperados):
```bash
./run.sh -k SUA_CHAVE_API_FIREBASE -u SEU_EMAIL -p SUA_SENHA -n 2 -e 5
```

4. **Configuração apenas remota** (sem workers locais, 3 workers remotos esperados):
```bash
./run.sh -k SUA_CHAVE_API_FIREBASE -u SEU_EMAIL -p SUA_SENHA -n 0 -e 3 -w 1
```

5. **Configuração com múltiplos watchers** (2 workers locais, 3 workers remotos esperados, 2 watchers):
```bash
./run.sh -k SUA_CHAVE_API_FIREBASE -u SEU_EMAIL -p SUA_SENHA -n 2 -e 5 -w 2
```

### Estastísticas e gráficos dos experimentos

Após a execução dos experimentos, os dados são armazenados na pasta `./experiments`, onde é possível verificar as pastas de cada iteração, contendo os arquivos de estatísticas e gráficos, além da pasta `globalStatistics` contendo as estatísticas agregadas de todos os workers de todas as iterações e os gráficos gerados.

## Considerações Finais

Os resultados de tempo de execução e utilização de recursos irão variar conforme as características de cada máquina e a quantidade de workers utilizados nelas. Espera-se que o backend seja capaz de processar as requisições e distribuir as tarefas igualmente entre os workers disponíveis. Assim, é possível analisar a escalabilidade do sistema, foco deste trabalho.

Adicionalmente, os resultados analisados no artigo estão disponíveis na pasta `./samples/article`.

Além dos gráficos preliminares gerados pelo script de demonstração, este repositório inclui um notebook Jupyter (`plots_sf_sbrc25.ipynb`) que contém análises mais detalhadas dos dados e estatísticas dos experimentos. Este notebook permite uma análise mais profunda dos resultados, incluindo visualizações personalizadas e cálculos estatísticos adicionais.

Para executar o notebook, você precisará ter o Jupyter instalado e as dependências Python necessárias. O notebook está localizado na raiz do repositório e pode ser aberto com:

```bash
jupyter notebook plots_sf_sbrc25.ipynb
```

Convido você a conhecer o projeto [MalwareDataLab](https://mdl.unihacker.club/).

Caso deseje ver detalhes sobre a implementação e a documentação de cada componente, além de verificar a `Dockerfile` de cada projeto para mais detalhes sobre a configuração e a execução dos serviços, acesse os repositórios de cada componente:

- [AutoDroid API](https://github.com/MalwareDataLab/autodroid-api)
- [AutoDroid Worker](https://github.com/MalwareDataLab/autodroid-worker)
- [AutoDroid Watcher Server](https://github.com/MalwareDataLab/autodroid-watcher-server)
- [AutoDroid Watcher Client](https://github.com/MalwareDataLab/autodroid-watcher-client)

O autor/desenvolvedor deste projeto se coloca a disposição para responder quaisquer questões e fornecer maiores detalhes sobre o projeto através do e-mail [luiz@laviola.dev](mailto:luiz@laviola.dev) ou através de issues deste repositório.

# LICENSE

Este projeto está licenciado sob a licença MIT. Consulte o arquivo [LICENSE](LICENSE) para mais detalhes.