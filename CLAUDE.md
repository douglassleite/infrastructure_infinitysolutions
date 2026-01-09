# Infraestrutura Infinity IT Solutions

Infraestrutura Docker centralizada para todos os projetos da Infinity IT Solutions. Gerencia **APENAS** servicos de infraestrutura: nginx (proxy reverso), PostgreSQL, Redis e SSL.

## Arquitetura

```
infrastructure_infinitysolutions/     <- APENAS INFRA
├── nginx + certbot + postgres + redis
├── deploy.sh                         <- Deploy completo do zero
├── cleanup-server.sh                 <- Backup e limpeza

evolly/                               <- Projeto separado (sistema de eventos)
├── docker-compose.yml proprio

web_infinitysolutions/                <- Projeto separado (site institucional)
├── docker-compose.yml proprio

personal_trainer_backend/             <- API Personal Trainer
├── docker-compose.prod.yml proprio

personal_trainer_web/                 <- Frontend Personal Trainer
├── docker-compose.prod.yml proprio

evolly-clients/                       <- Sites de clientes Evolly
├── clients.conf                      <- Lista de clientes para deploy automatico
├── deploy-client.sh
└── vanessaemarlo/
```

## Deploy Completo (Do Zero)

O `deploy.sh` faz deploy automatico de toda a infraestrutura:

```bash
# 1. Cleanup opcional (faz backup antes de deletar tudo)
./cleanup-server.sh

# 2. Clone e deploy
git clone git@github.com:douglassleite/infrastructure_infinitysolutions.git
cd infrastructure_infinitysolutions
./deploy.sh
```

### O que o deploy.sh faz:

1. Instala Docker se necessario
2. Cria estrutura de diretorios
3. Clona todos os repositorios (web, personal trainer, evolly, evolly-clients)
4. Cria redes Docker
5. Inicia PostgreSQL e Redis
6. Configura bancos de dados (personal_trainer_db, evolly_db)
7. Build e deploy de cada projeto
8. Deploy automatico de clientes Evolly (do clients.conf)
9. Configura Nginx:
   - Se SSL nao existe: move configs SSL para conf.d-disabled/ e sites-disabled/
   - Copia default.conf.nossl para default.conf
   - Inicia Nginx em modo HTTP
10. Gera certificados SSL para todos os dominios (--entrypoint certbot)
11. Restaura configs SSL e reinicia Nginx com HTTPS

### Requisitos de Rede

**IMPORTANTE:** Todos os projetos devem estar na rede `infinityitsolutions-network`:

```yaml
# Em cada docker-compose.yml
networks:
  - infinityitsolutions-network

networks:
  infinityitsolutions-network:
    external: true
```

## Configuracao

| Item | Valor |
|------|-------|
| Nginx | Porta 80/443 |
| PostgreSQL | Porta 5432 |
| Redis | Porta 6378 (externo) / 6379 (interno) |
| Rede | infinityitsolutions-network |

## Estrutura do Projeto

```
infrastructure_infinitysolutions/
├── docker-compose.yml          # Compose principal (apenas infra)
├── docker-compose.local.yml    # Desenvolvimento local
├── deploy.sh                   # Deploy completo automatizado
├── cleanup-server.sh           # Backup e limpeza do servidor
├── manage.sh                   # Script de gerenciamento
├── .env                        # Variaveis de ambiente
├── nginx/
│   ├── nginx.conf              # Config principal
│   ├── conf.d/                 # Configs estaticas dos sites
│   │   ├── 00-base.conf        # Upstreams
│   │   ├── 01-certbot.conf     # HTTP + certbot
│   │   ├── default.conf.nossl  # Config HTTP (todos os sites, sem SSL)
│   │   └── default.conf.ssl    # Config HTTPS (todos os sites, com SSL)
│   ├── conf.d-disabled/        # Configs temporariamente desabilitadas
│   ├── sites/                  # Configs dinamicas (clientes evolly)
│   │   └── vanessaemarlo.conf
│   └── sites-disabled/         # Configs de sites temporariamente desabilitadas
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
| infinity-redis-cache | 6378 | Cache |
| certbot | - | Geracao/renovacao SSL |

## Projetos Externos (docker-compose proprio)

| Projeto | Container | Porta | Repositorio |
|---------|-----------|-------|-------------|
| Website | infinityit-website | 80 | web_infinitysolutions |
| Personal Trainer API | personal-trainer-backend | 3001 | personal_trainer_backend |
| Personal Trainer Web | personal-trainer-web | 3000 | personal_trainer_web |
| Evolly | evolly | 8004 | evolly |
| Clientes Evolly | evolly-* | 80 | evolly-clients |

## Comandos Principais

### Deploy e Cleanup

```bash
./deploy.sh              # Deploy completo do zero
./cleanup-server.sh      # Backup e limpeza (DELETA TUDO!)
```

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
./manage.sh db-evolly           # Acessar banco evolly_db
```

### Gerenciamento de SSL/Dominios

```bash
./manage.sh ssl-add <dominio>      # Gerar SSL e habilitar site
./manage.sh ssl-remove <dominio>   # Desabilitar site
./manage.sh ssl-list               # Listar sites
./manage.sh ssl-renew              # Renovar certificados
./manage.sh ssl-status             # Status dos certificados
```

## Clientes Evolly

### Deploy Automatico

Clientes listados em `evolly-clients/clients.conf` sao deployados automaticamente pelo `deploy.sh`:

```bash
# Formato: nome|tipo|dominio|modelo
vanessaemarlo|custom|vanessaemarlo.com.br|modelo-9
novocliente|subdomain|novocliente|modelo-5
```

### Deploy Manual

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

# Personal Trainer
PERSONAL_TRAINER_DB=personal_trainer_db
PERSONAL_TRAINER_USER=personal_trainer
PERSONAL_TRAINER_PASSWORD=xxxxx

# Evolly
EVOLLY_DB=evolly_db
EVOLLY_USER=evolly
EVOLLY_PASSWORD=xxxxx

# Redis
REDIS_PASSWORD=xxxxx

# JWT (gerados automaticamente)
JWT_SECRET=xxxxx
JWT_REFRESH_SECRET=xxxxx
EVOLLY_JWT_SECRET=xxxxx
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

**IMPORTANTE:** Todos os containers devem estar na rede `infinityitsolutions-network` para que o nginx possa se comunicar com eles.

| Rede | Uso |
|------|-----|
| infinityitsolutions-network | **Rede principal (OBRIGATORIA para todos)** |
| personal_trainer_infrastructure_app-network | Compatibilidade backend |
| personal-trainer-network | Compatibilidade frontend |

## Troubleshooting

### Nginx nao inicia (host not found)

Significa que algum container nao esta na rede correta:

```bash
# Verificar containers na rede
docker network inspect infinityitsolutions-network --format '{{range .Containers}}{{.Name}} {{end}}'

# Conectar container manualmente
docker network connect infinityitsolutions-network <container_name>

# Reiniciar nginx
docker restart nginx-proxy
```

### Nginx nao inicia (certificado nao existe)

O deploy.sh desabilita configs SSL automaticamente se certificados nao existem. Para corrigir manualmente:

```bash
# Mover config SSL para desabilitado
mv nginx/sites/problema.conf nginx/sites-disabled/

# Usar config HTTP
cp nginx/conf.d/default.conf.nossl nginx/conf.d/default.conf

# Reiniciar nginx
docker compose restart nginx

# Gerar certificado
docker compose run --rm certbot certonly --webroot -w /var/www/certbot -d dominio.com.br --email seu@email.com --agree-tos --non-interactive

# Restaurar config SSL
mv nginx/sites-disabled/problema.conf nginx/sites/
cp nginx/conf.d/default.conf.ssl nginx/conf.d/default.conf
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

### Backup e Restauracao

O `cleanup-server.sh` faz backup automatico antes de limpar:

```bash
# Restaurar banco completo
cat ~/infinityitsolutions/backups/YYYYMMDD_HHMMSS/all_databases.sql | docker exec -i infinity-postgres-db psql -U infinityitsolutions -d postgres

# Restaurar banco individual
cat ~/infinityitsolutions/backups/YYYYMMDD_HHMMSS/evolly_db.sql | docker exec -i infinity-postgres-db psql -U evolly -d evolly_db

# Restaurar certificados SSL
sudo cp -r ~/infinityitsolutions/backups/YYYYMMDD_HHMMSS/certbot-conf/* certbot/conf/
```

## Regras de Manutencao

| Tipo de Alteracao | Arquivo a Atualizar |
|-------------------|---------------------|
| Novo servico infra | Este CLAUDE.md e docker-compose.yml |
| Novo dominio fixo | Este CLAUDE.md e conf.d/ |
| Novo cliente evolly | Adicionar em evolly-clients/clients.conf |
| Mudancas no deploy | Este CLAUDE.md e deploy.sh |
| Mudancas no nginx | Este CLAUDE.md |
