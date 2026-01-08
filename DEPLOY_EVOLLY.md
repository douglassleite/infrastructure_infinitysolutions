# Deploy Evolly + vanessaemarlo.com.br - Passo a Passo

## Pre-requisitos

- Acesso SSH ao servidor
- DNS do domínio `vanessaemarlo.com.br` apontando para o IP do servidor
- Repositório `git@github.com:douglassleite/evolly.git` criado no GitHub

---

## Passo 1: Conectar no servidor

```bash
ssh usuario@seu-servidor
cd ~/infinityitsolutions/infrastructure_infinitysolutions
```

---

## Passo 2: Parar containers antigos

```bash
# Parar containers com nome antigo
docker stop wedding-system-models 2>/dev/null || true
docker rm wedding-system-models 2>/dev/null || true

# Verificar se parou
docker ps | grep wedding
```

---

## Passo 3: Atualizar código da infraestrutura

```bash
cd ~/infinityitsolutions/infrastructure_infinitysolutions
git pull origin master
```

---

## Passo 4: Atualizar/Clonar o projeto Evolly

```bash
# Se a pasta ainda se chama wedding-system-models, renomear
cd ~/infinityitsolutions/apps
if [ -d "wedding-system-models" ]; then
    mv wedding-system-models evolly
fi

# Se não existir, clonar
if [ ! -d "evolly" ]; then
    git clone git@github.com:douglassleite/evolly.git evolly
fi

# Atualizar
cd evolly
git remote set-url origin git@github.com:douglassleite/evolly.git
git pull origin master
```

---

## Passo 5: Atualizar variáveis de ambiente

```bash
cd ~/infinityitsolutions/infrastructure_infinitysolutions

# Editar .env para atualizar o path
nano .env

# Mudar de:
#   WEDDING_PATH=../apps/wedding-system-models
# Para:
#   EVOLLY_PATH=../apps/evolly
```

Ou via comando:
```bash
sed -i 's/WEDDING_PATH=.*/EVOLLY_PATH=..\/apps\/evolly/' .env
```

---

## Passo 6: Rebuild e subir o Evolly

```bash
cd ~/infinityitsolutions/infrastructure_infinitysolutions

# Build do novo container
docker compose build evolly

# Subir
docker compose up -d evolly

# Verificar se está rodando
docker ps | grep evolly

# Ver logs
docker logs evolly -f --tail 50
```

---

## Passo 7: Executar migrations

```bash
docker exec evolly npm run migrate
```

---

## Passo 8: Configurar domínio vanessaemarlo.com.br

### 8.1 Copiar arquivos do site

```bash
cd ~/infinityitsolutions/infrastructure_infinitysolutions/wedding-sites/vanessaemarlo

# Criar pasta site se não existir
mkdir -p site

# Copiar modelo-9 do Evolly
cp -r ~/infinityitsolutions/apps/evolly/src/custom-sites/vanessaemarlo/modelo-9/* site/

# Verificar
ls -la site/
```

### 8.2 Build e subir container do site

```bash
cd ~/infinityitsolutions/infrastructure_infinitysolutions/wedding-sites/vanessaemarlo

# Build
docker compose build

# Subir
docker compose up -d

# Verificar
docker ps | grep evolly-vanessaemarlo
```

---

## Passo 9: Gerar certificado SSL para vanessaemarlo.com.br

### Metodo Recomendado: Usar manage.sh

```bash
cd ~/infinityitsolutions/infrastructure_infinitysolutions

# Gerar SSL e habilitar site automaticamente
./manage.sh ssl-add vanessaemarlo.com.br

# Verificar sites habilitados
./manage.sh ssl-list
```

O comando `ssl-add` faz automaticamente:
1. Cria diretorios necessarios
2. Gera certificado via Let's Encrypt
3. Copia config do site para nginx/conf.d/
4. Reinicia nginx

### Metodo Manual (se necessario)

```bash
cd ~/infinityitsolutions/infrastructure_infinitysolutions

# Gerar certificado
docker run --rm \
  -v $(pwd)/certbot/conf:/etc/letsencrypt \
  -v $(pwd)/certbot/www:/var/www/certbot \
  certbot/certbot certonly --webroot \
  -w /var/www/certbot \
  -d vanessaemarlo.com.br \
  -d www.vanessaemarlo.com.br \
  --email contato@infinityitsolutions.com.br \
  --agree-tos \
  --no-eff-email \
  --non-interactive

# Copiar config do site
cp nginx/sites-available/vanessaemarlo.conf nginx/conf.d/

# Reiniciar nginx
docker compose restart nginx
```

### Arquitetura Modular do Nginx

O nginx usa arquitetura modular com configs separadas:

```
nginx/
├── conf.d/                    # Configs ativas
│   ├── 00-base.conf           # Upstreams
│   ├── 01-certbot.conf        # HTTP + certbot
│   ├── infinityitsolutions.conf
│   ├── personalweb.conf
│   ├── personalapi.conf
│   ├── wedding.conf
│   └── vanessaemarlo.conf     # Habilitado via ssl-add
├── sites-available/           # Configs disponiveis (desabilitadas)
│   └── novo-site.conf
└── templates/
    └── wedding-site.conf.template
```

**Vantagem:** Se um site tiver problema de SSL, os outros continuam funcionando.

---

## Passo 10: Verificar tudo

### 10.1 Verificar containers rodando

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Deve mostrar:
- `evolly` (porta 8004)
- `evolly-vanessaemarlo` (porta 80 interna)
- `nginx-proxy` (portas 80 e 443)
- `infinity-postgres-db`
- `infinity-redis-cache`

### 10.2 Testar endpoints

```bash
# Health check do Evolly
curl -s http://localhost:8004/health

# Health check do site vanessaemarlo (via container)
docker exec evolly-vanessaemarlo wget -qO- http://localhost/health

# Testar via domínio (se DNS já propagou)
curl -s https://vanessaemarlo.com.br/health
curl -s https://wedding.infinityitsolutions.com.br/health
```

### 10.3 Verificar logs

```bash
# Logs do Evolly
docker logs evolly --tail 50

# Logs do site
docker logs evolly-vanessaemarlo --tail 50

# Logs do nginx
docker logs nginx-proxy --tail 50
```

---

## Comandos úteis pós-deploy

```bash
cd ~/infinityitsolutions/infrastructure_infinitysolutions

# Ver status
./manage.sh status

# Ver logs do Evolly
./manage.sh logs-evolly

# Reiniciar Evolly
./manage.sh restart-evolly

# Atualizar Evolly (futuras atualizações)
./manage.sh update-evolly

# Ver logs do nginx
./manage.sh logs-nginx

# Gerenciamento de SSL/Dominios
./manage.sh ssl-add <dominio>      # Gerar SSL e habilitar site
./manage.sh ssl-remove <dominio>   # Desabilitar site (mantem certificado)
./manage.sh ssl-list               # Listar sites habilitados/desabilitados
./manage.sh ssl-renew              # Renovar todos os certificados
./manage.sh ssl-status             # Ver status dos certificados

# Banco de dados
./manage.sh db-evolly              # Acessar PostgreSQL do Evolly
./manage.sh migrate-evolly         # Rodar migrations
```

---

## Troubleshooting

### Container não sobe
```bash
# Ver logs detalhados
docker logs evolly 2>&1

# Verificar se porta está em uso
netstat -tlnp | grep 8004
```

### Erro de certificado SSL
```bash
# Verificar se certificado foi gerado
ls -la certbot/conf/live/vanessaemarlo.com.br/

# Se não existir, tentar gerar novamente
# Certifique-se que o DNS está apontando para o servidor
dig vanessaemarlo.com.br +short
```

### Site não carrega API
```bash
# Verificar se Evolly está acessível da rede Docker
docker exec evolly-vanessaemarlo wget -qO- http://evolly:8004/health

# Se falhar, verificar rede
docker network inspect infinityitsolutions-network
```

### Nginx não inicia
```bash
# Testar configuração
docker exec nginx-proxy nginx -t

# Se erro de certificado não encontrado, voltar para nossl
cp nginx/conf.d/default.conf.nossl nginx/conf.d/default.conf
docker compose restart nginx
```

---

## Resumo rápido (copy-paste)

```bash
# Conectar no servidor
ssh usuario@servidor

# Ir para infra
cd ~/infinityitsolutions/infrastructure_infinitysolutions

# Atualizar tudo
git pull

# Renomear pasta do projeto (se necessário)
cd ../apps && mv wedding-system-models evolly 2>/dev/null; cd evolly && git pull; cd ../../infrastructure_infinitysolutions

# Parar container antigo
docker stop wedding-system-models 2>/dev/null; docker rm wedding-system-models 2>/dev/null

# Subir Evolly
docker compose build evolly && docker compose up -d evolly

# Migrations
docker exec evolly npm run migrate

# Copiar site vanessaemarlo
cd wedding-sites/vanessaemarlo && mkdir -p site && cp -r ~/infinityitsolutions/apps/evolly/src/custom-sites/vanessaemarlo/modelo-9/* site/

# Subir site
docker compose build && docker compose up -d

# SSL (usar nossl primeiro, gerar cert, depois restaurar)
cd ~/infinityitsolutions/infrastructure_infinitysolutions
cp nginx/conf.d/default.conf.nossl nginx/conf.d/default.conf
docker compose restart nginx

# Gerar certificado
docker run --rm -v $(pwd)/certbot/conf:/etc/letsencrypt -v $(pwd)/certbot/www:/var/www/certbot certbot/certbot certonly --webroot -w /var/www/certbot -d vanessaemarlo.com.br -d www.vanessaemarlo.com.br --email contato@infinityitsolutions.com.br --agree-tos --no-eff-email --non-interactive

# Restaurar SSL config e reiniciar
git checkout nginx/conf.d/default.conf
docker compose restart nginx

# Verificar
docker ps
curl -s https://vanessaemarlo.com.br/health
```
