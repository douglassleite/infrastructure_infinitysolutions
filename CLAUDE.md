# Infraestrutura Infinity IT Solutions

Infraestrutura Docker centralizada para todos os projetos da Infinity IT Solutions. Gerencia **APENAS** servicos de infraestrutura: nginx (proxy reverso), PostgreSQL, Redis e SSL.

## Arquitetura

```
infrastructure_infinitysolutions/     <- APENAS INFRA
├── nginx + certbot + postgres + redis

evolly/                               <- Projeto separado (sistema de eventos)
├── docker-compose.yml proprio

web_infinitysolutions/                <- Projeto separado (site institucional)
├── docker-compose.yml proprio

evolly-clients/                       <- Sites de clientes Evolly
├── vanessaemarlo/
├── outrocasal/
└── deploy-client.sh
```

## Configuracao

| Item | Valor |
|------|-------|
| Nginx | Porta 80/443 |
| PostgreSQL | Porta 5432 |
| Redis | Porta 6379 |
| Rede | infinityitsolutions-network |

## Estrutura do Projeto

```
infrastructure_infinitysolutions/
├── docker-compose.yml          # Compose principal (apenas infra)
├── docker-compose.local.yml    # Desenvolvimento local
├── .env                        # Variaveis de ambiente
├── manage.sh                   # Script de gerenciamento
├── nginx/
│   ├── nginx.conf              # Config principal
│   ├── conf.d/                 # Configs estaticas dos sites
│   │   ├── 00-base.conf        # Upstreams
│   │   ├── 01-certbot.conf     # HTTP + certbot
│   │   ├── infinityitsolutions.conf
│   │   ├── personalweb.conf
│   │   ├── personalapi.conf
│   │   └── evolly.conf
│   ├── sites/                  # Configs dinamicas (clientes evolly)
│   │   └── vanessaemarlo.conf
│   ├── sites-available/        # Configs desabilitadas
│   └── templates/              # Templates para novos sites
├── certbot/
│   ├── conf/                   # Certificados SSL
│   └── www/                    # Challenge ACME
└── init-scripts/
    └── 01-create-databases.sql
```

## Servicos da Infraestrutura

| Container | Porta | Descricao |
|-----------|-------|-----------|
| nginx-proxy | 80, 443 | Proxy reverso e SSL |
| infinity-postgres-db | 5432 | Banco de dados |
| infinity-redis-cache | 6379 | Cache |
| certbot | - | Renovacao SSL |

## Projetos Externos (docker-compose proprio)

| Projeto | Container | Porta | Repositorio |
|---------|-----------|-------|-------------|
| Evolly | evolly | 8004 | ../evolly |
| Website | infinity-website | 80 | ../web_infinitysolutions |
| Personal Trainer API | personal-trainer-backend | 3001 | Separado |
| Personal Trainer Web | personal-trainer-web | 3000 | Separado |
| Clientes Evolly | evolly-* | 80 | ../evolly-clients |

## Comandos Principais

### Gerenciamento Geral

```bash
./manage.sh status              # Ver status dos containers
./manage.sh logs                # Ver todos os logs
./manage.sh restart-all         # Reiniciar tudo
./manage.sh cleanup             # Limpar imagens nao usadas
./manage.sh disk                # Ver uso de disco
```

### Nginx

```bash
./manage.sh logs-nginx          # Ver logs
./manage.sh restart-nginx       # Reiniciar
docker exec nginx-proxy nginx -t  # Testar config
docker exec nginx-proxy nginx -s reload  # Recarregar
```

### Banco de Dados

```bash
./manage.sh db-shell            # PostgreSQL shell
./manage.sh redis-shell         # Redis shell
```

### Gerenciamento de SSL/Dominios

```bash
./manage.sh ssl-add <dominio>      # Gerar SSL e habilitar site
./manage.sh ssl-remove <dominio>   # Desabilitar site
./manage.sh ssl-list               # Listar sites
./manage.sh ssl-renew              # Renovar certificados
./manage.sh ssl-status             # Status dos certificados
```

## Arquitetura Nginx

### Estrutura de Configs

```
nginx/
├── conf.d/           # Configs estaticas (sempre ativas)
│   ├── 00-base.conf  # Upstreams
│   └── *.conf        # Sites fixos
└── sites/            # Configs dinamicas (clientes evolly)
    └── *.conf        # Geradas por evolly-clients/deploy-client.sh
```

### Adicionar Novo Cliente Evolly

Usar o script em `../evolly-clients/deploy-client.sh`:

```bash
cd ../evolly-clients

# Subdominio
./deploy-client.sh novocliente subdomain novocliente modelo-9

# Dominio proprio
./deploy-client.sh novocliente custom dominio.com.br modelo-9
```

## Volumes Persistentes

| Volume | Uso |
|--------|-----|
| postgres_data | Dados do PostgreSQL |
| redis_data | Dados do Redis |

## Variaveis de Ambiente (.env)

```env
# PostgreSQL
POSTGRES_USER=infinityitsolutions
POSTGRES_PASSWORD=xxxxx
POSTGRES_DB=infinitysolutions_db

# Redis
REDIS_PASSWORD=xxxxx
```

## Dominios Configurados

| Dominio | Servico | Config |
|---------|---------|--------|
| infinityitsolutions.com.br | Site institucional | conf.d/ |
| personalweb.infinityitsolutions.com.br | Personal Trainer Web | conf.d/ |
| personalapi.infinityitsolutions.com.br | Personal Trainer API | conf.d/ |
| evolly.infinityitsolutions.com.br | Evolly Admin | conf.d/ |
| vanessaemarlo.com.br | Cliente Evolly | sites/ |

## Redes Docker

| Rede | Uso |
|------|-----|
| infinityitsolutions-network | Rede principal compartilhada |
| personal_trainer_infrastructure_app-network | Personal Trainer backend |
| personal-trainer-network | Personal Trainer frontend |

## Troubleshooting

### Nginx nao inicia

```bash
# Testar config
docker exec nginx-proxy nginx -t

# Ver logs
docker logs nginx-proxy --tail 50

# Se certificado nao existe, comentar o site temporariamente
mv nginx/sites/problema.conf nginx/sites/problema.conf.disabled
docker compose restart nginx
```

### Container nao conecta na rede

```bash
# Verificar rede
docker network inspect infinityitsolutions-network

# Recriar rede se necessario
docker compose down
docker network rm infinityitsolutions-network
docker network create infinityitsolutions-network
docker compose up -d
```

### Certificado SSL expirado

```bash
./manage.sh ssl-renew
./manage.sh restart-nginx
```

## Regras de Manutencao

| Tipo de Alteracao | Arquivo a Atualizar |
|-------------------|---------------------|
| Novo servico infra | Este CLAUDE.md e docker-compose.yml |
| Novo dominio fixo | Este CLAUDE.md e conf.d/ |
| Novo cliente evolly | Usar deploy-client.sh |
| Mudancas no nginx | Este CLAUDE.md |
