# Infraestrutura Infinity IT Solutions

Infraestrutura Docker centralizada para todos os projetos da Infinity IT Solutions. Gerencia nginx, PostgreSQL, Redis e containers de aplicacoes.

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
├── docker-compose.yml          # Compose principal
├── .env                        # Variaveis de ambiente
├── manage.sh                   # Script de gerenciamento
├── nginx/
│   ├── nginx.conf              # Config principal
│   ├── conf.d/                 # Configs ativas dos sites
│   │   ├── 00-base.conf        # Upstreams
│   │   ├── 01-certbot.conf     # HTTP + certbot
│   │   ├── infinityitsolutions.conf
│   │   ├── personalweb.conf
│   │   ├── personalapi.conf
│   │   ├── wedding.conf
│   │   └── vanessaemarlo.conf
│   ├── sites-available/        # Configs desabilitadas
│   └── templates/              # Templates para novos sites
├── certbot/
│   ├── conf/                   # Certificados SSL
│   └── www/                    # Challenge ACME
├── wedding-sites/              # Sites de casamento estaticos
│   └── vanessaemarlo/
│       ├── docker-compose.yml
│       ├── nginx.conf
│       └── site/
└── docs/
    └── DEPLOY_EVOLLY.md
```

## Servicos

| Container | Porta | Descricao |
|-----------|-------|-----------|
| nginx-proxy | 80, 443 | Proxy reverso e SSL |
| infinity-postgres-db | 5432 | Banco de dados |
| infinity-redis-cache | 6379 | Cache |
| infinity-website | 3002 | Site institucional |
| personal-trainer-backend | 3001 | API Personal Trainer |
| personal-trainer-web | 3000 | Web Personal Trainer |
| evolly | 8004 | Sistema de eventos |
| evolly-vanessaemarlo | 80 | Site vanessaemarlo.com.br |

## Comandos Principais

### Gerenciamento Geral

```bash
./manage.sh status              # Ver status dos containers
./manage.sh logs                # Ver todos os logs
./manage.sh restart-all         # Reiniciar tudo
./manage.sh cleanup             # Limpar imagens nao usadas
./manage.sh disk                # Ver uso de disco
```

### Por Servico

```bash
# Evolly
./manage.sh logs-evolly         # Logs
./manage.sh restart-evolly      # Reiniciar
./manage.sh update-evolly       # Atualizar (git pull + rebuild)
./manage.sh migrate-evolly      # Migrations
./manage.sh db-evolly           # Acesso ao banco

# Personal Trainer
./manage.sh logs-backend        # Logs backend
./manage.sh logs-web            # Logs frontend
./manage.sh restart-backend     # Reiniciar backend
./manage.sh restart-web         # Reiniciar frontend
./manage.sh update-backend      # Atualizar backend
./manage.sh update-web          # Atualizar frontend
./manage.sh migrate             # Migrations Prisma

# Site Institucional
./manage.sh logs-website        # Logs
./manage.sh restart-website     # Reiniciar
./manage.sh update-website      # Atualizar

# Nginx
./manage.sh logs-nginx          # Logs
./manage.sh restart-nginx       # Reiniciar

# Banco de Dados
./manage.sh db-shell            # PostgreSQL Personal Trainer
./manage.sh db-evolly           # PostgreSQL Evolly
./manage.sh redis-shell         # Redis
```

### Gerenciamento de SSL/Dominios

```bash
./manage.sh ssl-add <dominio>      # Gerar SSL e habilitar site
./manage.sh ssl-remove <dominio>   # Desabilitar site
./manage.sh ssl-list               # Listar sites
./manage.sh ssl-renew              # Renovar certificados
./manage.sh ssl-status             # Status dos certificados
```

## Arquitetura Nginx Modular

O nginx usa configs separadas para cada site, permitindo que um problema em um dominio nao afete os outros:

```
nginx/conf.d/
├── 00-base.conf           # Upstreams (carrega primeiro)
├── 01-certbot.conf        # HTTP server + certbot
├── infinityitsolutions.conf
├── personalweb.conf
├── personalapi.conf
├── wedding.conf
└── vanessaemarlo.conf
```

### Adicionar Novo Site

1. Criar config em `nginx/sites-available/novo-site.conf`
2. Rodar `./manage.sh ssl-add novo-site.com.br`
3. O comando gera o certificado e copia a config para `conf.d/`

### Desabilitar Site

```bash
./manage.sh ssl-remove dominio.com.br
# Move config de conf.d/ para sites-available/
# Certificado e mantido para futuro uso
```

## Volumes Persistentes

| Volume | Uso |
|--------|-----|
| postgres_data | Dados do PostgreSQL |
| redis_data | Dados do Redis |
| certbot_conf | Certificados SSL |
| certbot_www | Challenge ACME |
| evolly_uploads | Uploads do Evolly |

## Variaveis de Ambiente (.env)

```env
# Paths dos projetos
WEBSITE_PATH=../website
PERSONAL_PATH=../apps/personal-trainer
EVOLLY_PATH=../apps/evolly

# PostgreSQL
POSTGRES_USER=postgres
POSTGRES_PASSWORD=xxxxx
POSTGRES_DB=infinity_db

# Redis
REDIS_PASSWORD=xxxxx

# JWT
JWT_SECRET=xxxxx
```

## Dominios Configurados

| Dominio | Servico |
|---------|---------|
| infinityitsolutions.com.br | Site institucional |
| personalweb.infinityitsolutions.com.br | Personal Trainer Web |
| personalapi.infinityitsolutions.com.br | Personal Trainer API |
| wedding.infinityitsolutions.com.br | Evolly Admin |
| vanessaemarlo.com.br | Site de casamento |

## Troubleshooting

### Nginx nao inicia

```bash
# Testar config
docker exec nginx-proxy nginx -t

# Ver logs
docker logs nginx-proxy --tail 50

# Se certificado nao existe, desabilitar site
./manage.sh ssl-remove dominio-com-problema.com.br
docker compose restart nginx
```

### Container nao conecta na rede

```bash
# Verificar rede
docker network inspect infinityitsolutions-network

# Recriar rede se necessario
docker compose down
docker network rm infinityitsolutions-network
docker compose up -d
```

### Certificado SSL expirado

```bash
./manage.sh ssl-renew
./manage.sh restart-nginx
```

### Banco de dados nao conecta

```bash
# Verificar se container esta rodando
docker ps | grep postgres

# Ver logs
docker logs infinity-postgres-db --tail 50

# Reiniciar
docker compose restart postgres
```

## Regras de Manutencao

**OBRIGATORIO: Ao fazer alteracoes na infraestrutura, atualizar a documentacao correspondente.**

| Tipo de Alteracao | Arquivo a Atualizar |
|-------------------|---------------------|
| Novo dominio/site | Este CLAUDE.md e DEPLOY_EVOLLY.md |
| Novo container/servico | Este CLAUDE.md e docker-compose.yml |
| Mudancas em manage.sh | Este CLAUDE.md |
| Mudancas no nginx | Este CLAUDE.md |
| Deploy de novo projeto | Criar doc em docs/ |
