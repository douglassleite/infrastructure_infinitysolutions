# 🏗️ Personal Trainer - Infrastructure

Infraestrutura Docker para o sistema Personal Trainer, incluindo proxy reverso, banco de dados e cache.

## 📦 Serviços

| Serviço | Imagem | Porta | Descrição |
|---------|--------|-------|-----------|
| **Nginx** | nginx:alpine | 80, 443 | Proxy reverso com SSL |
| **PostgreSQL** | postgres:15-alpine | 5432 | Banco de dados |
| **Redis** | redis:7-alpine | 6379 | Cache e sessões |
| **Certbot** | certbot/certbot | - | Renovação automática SSL |

## 🌐 Subdomínios

- **Website:** `personalweb.infinityitsolutions.com.br`
- **API:** `personalapi.infinityitsolutions.com.br`

## 🚀 Quick Start

### 1. Clone o repositório

```bash
git clone https://github.com/douglassleite/personal_trainer_infrastructure.git
cd personal_trainer_infrastructure
```

### 2. Configure as variáveis de ambiente

```bash
cp .env.example .env
nano .env
```

Edite as variáveis:
```env
POSTGRES_USER=personal_trainer
POSTGRES_PASSWORD=sua_senha_segura
POSTGRES_DB=personal_trainer_db
REDIS_PASSWORD=sua_senha_redis
```

### 3. Inicie os serviços

```bash
# Iniciar Postgres e Redis primeiro
docker compose up -d postgres redis

# Aguarde 10 segundos
sleep 10

# Inicie o Nginx
docker compose up -d nginx
```

> **Nota:** A rede `personal_trainer_infrastructure_app-network` será criada automaticamente.

## 🔒 Configurar SSL

### Primeira vez (obter certificado)

```bash
# Use a configuração inicial (sem SSL)
mv nginx/conf.d/default.conf nginx/conf.d/default.conf.ssl
cp nginx/conf.d/initial.conf.example nginx/conf.d/default.conf

# Reinicie Nginx
docker-compose restart nginx

# Obtenha o certificado
docker-compose run --rm certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  -d personalweb.infinityitsolutions.com.br \
  -d personalapi.infinityitsolutions.com.br \
  --email seu@email.com \
  --agree-tos \
  --no-eff-email

# Restaure a configuração com SSL
rm nginx/conf.d/default.conf
mv nginx/conf.d/default.conf.ssl nginx/conf.d/default.conf

# Reinicie Nginx
docker-compose restart nginx
```

### Renovar certificado

```bash
docker-compose run --rm certbot renew
docker-compose restart nginx
```

## 📁 Estrutura

```
personal_trainer_infrastructure/
├── docker-compose.yml      # Definição dos serviços
├── .env                    # Variáveis de ambiente (não commitar!)
├── .env.example            # Template de variáveis
├── nginx/
│   ├── nginx.conf          # Configuração principal do Nginx
│   └── conf.d/
│       ├── default.conf    # Virtual hosts (com SSL)
│       └── initial.conf.example  # Config inicial (sem SSL)
├── certbot/
│   ├── conf/               # Certificados SSL (gerado)
│   └── www/                # Desafio ACME (gerado)
├── deploy.sh               # Script de deploy automatizado
└── manage.sh               # Comandos de gerenciamento
```

## 🔧 Comandos Úteis

### Usando manage.sh

```bash
chmod +x manage.sh

./manage.sh status          # Ver status dos containers
./manage.sh logs            # Ver logs de todos
./manage.sh logs-nginx      # Ver logs do Nginx
./manage.sh restart-nginx   # Reiniciar Nginx
./manage.sh ssl-renew       # Renovar SSL
./manage.sh ssl-status      # Ver status do SSL
./manage.sh db-shell        # Acessar PostgreSQL
./manage.sh redis-shell     # Acessar Redis
./manage.sh cleanup         # Limpar recursos não utilizados
```

### Comandos Docker diretos

```bash
# Ver status
docker-compose ps

# Ver logs
docker-compose logs -f nginx
docker-compose logs -f postgres
docker-compose logs -f redis

# Reiniciar serviço
docker-compose restart nginx

# Parar tudo
docker-compose down

# Parar e remover volumes (CUIDADO!)
docker-compose down -v
```

## 🔗 Integração com outros projetos

Esta infrastructure é usada pelos seguintes projetos:

- [personal_trainer_backend](https://github.com/douglassleite/personal_trainer_backend) - API Node.js
- [personal_trainer_web](https://github.com/douglassleite/personal_trainer_web) - Frontend Next.js

Todos os projetos se conectam através da rede Docker `app-network`.

## 📊 Monitoramento

```bash
# Recursos dos containers
docker stats

# Espaço em disco
docker system df

# Verificar saúde dos serviços
docker-compose ps
```

## 🆘 Troubleshooting

### Nginx não inicia
```bash
# Verificar configuração
docker-compose exec nginx nginx -t

# Ver logs
docker-compose logs nginx
```

### PostgreSQL não conecta
```bash
# Verificar se está rodando
docker-compose ps postgres

# Ver logs
docker-compose logs postgres

# Testar conexão
docker-compose exec postgres pg_isready
```

### Certificado SSL expirado
```bash
# Renovar manualmente
docker-compose run --rm certbot renew --force-renewal
docker-compose restart nginx
```

## 📝 Licença

MIT
