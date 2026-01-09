#!/bin/bash

# ===========================================
# Infinity IT Solutions - Comandos de Gerenciamento
# ===========================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Diretório raiz baseado na localização do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
INFRA_DIR="$SCRIPT_DIR"
WEBSITE_DIR="$ROOT_DIR/website"
PERSONAL_DIR="$ROOT_DIR/apps/personal-trainer"
EVOLLY_DIR="$ROOT_DIR/apps/evolly"

show_help() {
    echo ""
    echo -e "${BLUE}Infinity IT Solutions - Comandos de Gerenciamento${NC}"
    echo ""
    echo "Uso: ./manage.sh [comando]"
    echo ""
    echo "Comandos disponíveis:"
    echo ""
    echo -e "  ${GREEN}status${NC}          - Ver status de todos os containers"
    echo -e "  ${GREEN}logs${NC}            - Ver logs de todos os serviços"
    echo -e "  ${GREEN}logs-backend${NC}    - Ver logs do backend"
    echo -e "  ${GREEN}logs-web${NC}        - Ver logs do frontend"
    echo -e "  ${GREEN}logs-website${NC}    - Ver logs do site institucional"
    echo -e "  ${GREEN}logs-evolly${NC}     - Ver logs do Evolly"
    echo -e "  ${GREEN}logs-nginx${NC}      - Ver logs do nginx"
    echo ""
    echo -e "  ${GREEN}restart-backend${NC} - Reiniciar apenas o backend"
    echo -e "  ${GREEN}restart-web${NC}     - Reiniciar apenas o frontend"
    echo -e "  ${GREEN}restart-website${NC} - Reiniciar site institucional"
    echo -e "  ${GREEN}restart-evolly${NC}  - Reiniciar Evolly"
    echo -e "  ${GREEN}restart-nginx${NC}   - Reiniciar apenas o nginx"
    echo -e "  ${GREEN}restart-all${NC}     - Reiniciar todos os serviços"
    echo ""
    echo -e "  ${GREEN}update-backend${NC}  - Atualizar backend (git pull + rebuild)"
    echo -e "  ${GREEN}update-web${NC}      - Atualizar frontend (git pull + rebuild)"
    echo -e "  ${GREEN}update-website${NC}  - Atualizar site institucional"
    echo -e "  ${GREEN}update-evolly${NC}   - Atualizar Evolly (git pull + rebuild + migrate)"
    echo -e "  ${GREEN}update-all${NC}      - Atualizar todos"
    echo ""
    echo -e "  ${GREEN}db-shell${NC}        - Acessar PostgreSQL (personal trainer)"
    echo -e "  ${GREEN}db-evolly${NC}       - Acessar PostgreSQL (Evolly)"
    echo -e "  ${GREEN}redis-shell${NC}     - Acessar Redis"
    echo -e "  ${GREEN}migrate${NC}         - Executar migrations do Prisma (personal trainer)"
    echo -e "  ${GREEN}migrate-evolly${NC}  - Executar migrations do Evolly"
    echo ""
    echo -e "  ${GREEN}ssl-add <domain>${NC}    - Gerar SSL e habilitar site (ex: ssl-add vanessaemarlo.com.br)"
    echo -e "  ${GREEN}ssl-remove <domain>${NC} - Desabilitar site (remove config, mantém certificado)"
    echo -e "  ${GREEN}ssl-list${NC}            - Listar sites habilitados/desabilitados"
    echo -e "  ${GREEN}ssl-renew${NC}           - Renovar todos os certificados SSL"
    echo -e "  ${GREEN}ssl-status${NC}          - Ver status dos certificados SSL"
    echo ""
    echo -e "  ${GREEN}change-evolly-domain <novo-dominio>${NC} - Mudar domínio do painel Evolly"
    echo -e "                                         (ex: change-evolly-domain evolly.com.br)"
    echo ""
    echo -e "  ${GREEN}cleanup${NC}         - Limpar imagens e containers não utilizados"
    echo -e "  ${GREEN}disk${NC}            - Ver uso de disco do Docker"
    echo ""
}

# Função para extrair nome do site do domínio (ex: vanessaemarlo.com.br -> vanessaemarlo)
get_site_name() {
    echo "$1" | sed 's/\.com\.br$//' | sed 's/\.com$//' | sed 's/\./-/g'
}

case "$1" in
    status)
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;

    logs)
        docker logs -f --tail 100 personal-trainer-backend &
        docker logs -f --tail 100 personal-trainer-web &
        docker logs -f --tail 100 nginx-proxy
        ;;

    logs-backend)
        docker logs -f --tail 200 personal-trainer-backend
        ;;

    logs-web)
        docker logs -f --tail 200 personal-trainer-web
        ;;

    logs-nginx)
        docker logs -f --tail 200 nginx-proxy
        ;;

    logs-website)
        docker logs -f --tail 200 infinity-website
        ;;

    logs-evolly)
        docker logs -f --tail 200 evolly
        ;;

    restart-backend)
        echo -e "${BLUE}Reiniciando backend Personal Trainer...${NC}"
        cd $PERSONAL_DIR/backend
        docker-compose -f docker-compose.prod.yml restart
        echo -e "${GREEN}Backend reiniciado${NC}"
        ;;

    restart-web)
        echo -e "${BLUE}Reiniciando frontend Personal Trainer...${NC}"
        cd $PERSONAL_DIR/web
        docker-compose -f docker-compose.prod.yml restart
        echo -e "${GREEN}Frontend reiniciado${NC}"
        ;;

    restart-nginx)
        echo -e "${BLUE}Reiniciando Nginx...${NC}"
        cd $INFRA_DIR
        docker compose restart nginx
        echo -e "${GREEN}Nginx reiniciado${NC}"
        ;;

    restart-website)
        echo -e "${BLUE}Reiniciando site institucional...${NC}"
        cd $INFRA_DIR
        docker compose restart infinity-website
        echo -e "${GREEN}Site institucional reiniciado${NC}"
        ;;

    restart-evolly)
        echo -e "${BLUE}Reiniciando Evolly...${NC}"
        cd $INFRA_DIR
        docker compose restart evolly
        echo -e "${GREEN}Evolly reiniciado${NC}"
        ;;

    restart-all)
        echo -e "${BLUE}Reiniciando todos os serviços...${NC}"
        cd $PERSONAL_DIR/backend && docker-compose -f docker-compose.prod.yml restart
        cd $PERSONAL_DIR/web && docker-compose -f docker-compose.prod.yml restart
        cd $INFRA_DIR && docker compose restart
        echo -e "${GREEN}Todos os serviços reiniciados${NC}"
        ;;

    update-backend)
        echo -e "${BLUE}Atualizando backend Personal Trainer...${NC}"
        cd $PERSONAL_DIR/backend
        git pull
        docker-compose -f docker-compose.prod.yml build
        docker-compose -f docker-compose.prod.yml run --rm backend npx prisma migrate deploy
        docker-compose -f docker-compose.prod.yml up -d
        echo -e "${GREEN}Backend atualizado${NC}"
        ;;

    update-web)
        echo -e "${BLUE}Atualizando frontend Personal Trainer...${NC}"
        cd $PERSONAL_DIR/web
        git pull
        docker-compose -f docker-compose.prod.yml build
        docker-compose -f docker-compose.prod.yml up -d
        echo -e "${GREEN}Frontend atualizado${NC}"
        ;;

    update-website)
        echo -e "${BLUE}Atualizando site institucional...${NC}"
        cd $WEBSITE_DIR
        git pull
        cd $INFRA_DIR
        docker compose build infinity-website
        docker compose up -d infinity-website
        echo -e "${GREEN}Site institucional atualizado${NC}"
        ;;

    update-evolly)
        echo -e "${BLUE}Atualizando Evolly...${NC}"
        cd $EVOLLY_DIR
        git pull
        cd $INFRA_DIR
        docker compose build evolly
        docker compose up -d evolly
        echo -e "${YELLOW}Executando migrations...${NC}"
        docker exec evolly npm run migrate
        echo -e "${GREEN}Evolly atualizado${NC}"
        ;;

    update-all)
        $0 update-backend
        $0 update-web
        $0 update-website
        $0 update-evolly
        ;;

    db-shell)
        docker exec -it infinity-postgres-db psql -U ${POSTGRES_USER:-personal_trainer} -d ${POSTGRES_DB:-personal_trainer_db}
        ;;

    db-evolly)
        docker exec -it infinity-postgres-db psql -U evolly -d evolly_db
        ;;

    redis-shell)
        docker exec -it redis-cache redis-cli
        ;;

    migrate)
        echo -e "${BLUE}Executando migrations Personal Trainer...${NC}"
        cd $PERSONAL_DIR/backend
        docker-compose -f docker-compose.prod.yml run --rm backend npx prisma migrate deploy
        echo -e "${GREEN}Migrations executadas${NC}"
        ;;

    migrate-evolly)
        echo -e "${BLUE}Executando migrations Evolly...${NC}"
        docker exec evolly npm run migrate
        echo -e "${GREEN}Migrations executadas${NC}"
        ;;

    ssl-add)
        DOMAIN="$2"
        if [ -z "$DOMAIN" ]; then
            echo -e "${RED}Erro: Domínio não especificado${NC}"
            echo "Uso: ./manage.sh ssl-add <dominio>"
            echo "Exemplo: ./manage.sh ssl-add vanessaemarlo.com.br"
            exit 1
        fi

        SITE_NAME=$(get_site_name "$DOMAIN")
        echo -e "${BLUE}Adicionando SSL para ${DOMAIN}...${NC}"
        cd $INFRA_DIR

        # Criar diretórios necessários
        mkdir -p certbot/conf certbot/www/.well-known/acme-challenge

        # Verificar se nginx está rodando
        if ! docker ps | grep -q nginx-proxy; then
            echo -e "${YELLOW}Nginx não está rodando. Iniciando...${NC}"
            docker compose up -d nginx
            sleep 5
        fi

        # Verificar se já existe certificado
        if [ -d "certbot/conf/live/$DOMAIN" ]; then
            echo -e "${YELLOW}Certificado já existe para $DOMAIN${NC}"
        else
            # Gerar certificado
            echo -e "${YELLOW}Gerando certificado SSL para $DOMAIN...${NC}"
            docker run --rm \
                -v $INFRA_DIR/certbot/conf:/etc/letsencrypt \
                -v $INFRA_DIR/certbot/www:/var/www/certbot \
                certbot/certbot certonly --webroot \
                -w /var/www/certbot \
                -d $DOMAIN \
                -d www.$DOMAIN \
                --email contato@infinityitsolutions.com.br \
                --agree-tos \
                --no-eff-email \
                --non-interactive

            # Verificar se certificado foi gerado (usar sudo pois diretório é root)
            if ! sudo test -d "certbot/conf/live/$DOMAIN"; then
                echo -e "${RED}✗ Falha ao gerar certificado para $DOMAIN${NC}"
                echo -e "${YELLOW}Possíveis causas:${NC}"
                echo "  - DNS não está apontando para este servidor"
                echo "  - Domínio não está acessível pela internet"
                echo "  - Limite de requisições Let's Encrypt atingido"
                echo ""
                echo -e "${YELLOW}O site permanece desabilitado. Outros sites continuam funcionando.${NC}"
                exit 1
            fi
        fi

        echo -e "${GREEN}✓ Certificado OK${NC}"

        # Verificar se existe config em sites-available
        if [ -f "nginx/sites-available/${SITE_NAME}.conf" ]; then
            echo -e "${YELLOW}Habilitando configuração do site...${NC}"
            cp "nginx/sites-available/${SITE_NAME}.conf" "nginx/conf.d/${SITE_NAME}.conf"
        else
            echo -e "${YELLOW}Config não encontrada em sites-available/${SITE_NAME}.conf${NC}"
            echo -e "${YELLOW}Criando config a partir do template...${NC}"

            if [ -f "nginx/templates/evolly-site.conf.template" ]; then
                # Substituir placeholders no template
                sed -e "s/{{DOMAIN}}/$DOMAIN/g" \
                    -e "s/{{SITE_NAME}}/$SITE_NAME/g" \
                    -e "s/{{UPSTREAM}}/$SITE_NAME/g" \
                    "nginx/templates/evolly-site.conf.template" > "nginx/conf.d/${SITE_NAME}.conf"

                # Salvar também em sites-available para referência
                cp "nginx/conf.d/${SITE_NAME}.conf" "nginx/sites-available/${SITE_NAME}.conf"
            else
                echo -e "${RED}✗ Template não encontrado${NC}"
                exit 1
            fi
        fi

        # Testar configuração do nginx
        echo -e "${YELLOW}Testando configuração do nginx...${NC}"
        docker compose restart nginx
        sleep 2

        if docker ps | grep -q nginx-proxy; then
            echo -e "${GREEN}✓ Site $DOMAIN habilitado com sucesso!${NC}"
            echo -e "${GREEN}  https://$DOMAIN${NC}"
        else
            echo -e "${RED}✗ Nginx falhou ao iniciar${NC}"
            echo -e "${YELLOW}Removendo config problemática...${NC}"
            rm -f "nginx/conf.d/${SITE_NAME}.conf"
            docker compose restart nginx
            echo -e "${YELLOW}Config removida. Outros sites continuam funcionando.${NC}"
            exit 1
        fi
        ;;

    ssl-remove)
        DOMAIN="$2"
        if [ -z "$DOMAIN" ]; then
            echo -e "${RED}Erro: Domínio não especificado${NC}"
            echo "Uso: ./manage.sh ssl-remove <dominio>"
            exit 1
        fi

        SITE_NAME=$(get_site_name "$DOMAIN")
        echo -e "${BLUE}Desabilitando site ${DOMAIN}...${NC}"
        cd $INFRA_DIR

        if [ -f "nginx/conf.d/${SITE_NAME}.conf" ]; then
            # Mover para sites-available (backup)
            mv "nginx/conf.d/${SITE_NAME}.conf" "nginx/sites-available/${SITE_NAME}.conf"
            docker compose restart nginx
            echo -e "${GREEN}✓ Site $DOMAIN desabilitado${NC}"
            echo -e "${YELLOW}  Config salva em nginx/sites-available/${SITE_NAME}.conf${NC}"
            echo -e "${YELLOW}  Certificado mantido em certbot/conf/live/$DOMAIN/${NC}"
        else
            echo -e "${YELLOW}Site $DOMAIN já está desabilitado${NC}"
        fi
        ;;

    ssl-list)
        echo -e "${BLUE}Sites configurados:${NC}"
        echo ""
        cd $INFRA_DIR

        echo -e "${GREEN}Habilitados (nginx/conf.d/):${NC}"
        for f in nginx/conf.d/*.conf; do
            if [ -f "$f" ]; then
                name=$(basename "$f" .conf)
                # Ignorar arquivos base
                if [[ "$name" != "00-base" && "$name" != "01-certbot" ]]; then
                    echo "  ✓ $name"
                fi
            fi
        done

        echo ""
        echo -e "${YELLOW}Desabilitados (nginx/sites-available/):${NC}"
        for f in nginx/sites-available/*.conf; do
            if [ -f "$f" ]; then
                name=$(basename "$f" .conf)
                # Verificar se não está habilitado
                if [ ! -f "nginx/conf.d/${name}.conf" ]; then
                    echo "  ○ $name"
                fi
            fi
        done

        echo ""
        echo -e "${BLUE}Certificados existentes:${NC}"
        if [ -d "certbot/conf/live" ]; then
            for d in certbot/conf/live/*/; do
                if [ -d "$d" ]; then
                    domain=$(basename "$d")
                    if [ "$domain" != "README" ]; then
                        echo "  🔒 $domain"
                    fi
                fi
            done
        else
            echo "  Nenhum certificado encontrado"
        fi
        ;;

    ssl-renew)
        echo -e "${BLUE}Renovando certificados SSL...${NC}"
        cd $INFRA_DIR
        docker run --rm \
            -v $INFRA_DIR/certbot/conf:/etc/letsencrypt \
            -v $INFRA_DIR/certbot/www:/var/www/certbot \
            certbot/certbot renew
        docker compose restart nginx
        echo -e "${GREEN}Certificados renovados${NC}"
        ;;

    ssl-status)
        echo -e "${BLUE}Status dos certificados SSL:${NC}"
        cd $INFRA_DIR
        docker run --rm -v $INFRA_DIR/certbot/conf:/etc/letsencrypt certbot/certbot certificates
        ;;

    change-evolly-domain)
        NEW_DOMAIN="$2"
        OLD_DOMAIN="evolly.infinityitsolutions.com.br"

        if [ -z "$NEW_DOMAIN" ]; then
            echo -e "${RED}Erro: Novo domínio não especificado${NC}"
            echo "Uso: ./manage.sh change-evolly-domain <novo-dominio>"
            echo "Exemplo: ./manage.sh change-evolly-domain evolly.com.br"
            exit 1
        fi

        echo ""
        echo -e "${YELLOW}============================================${NC}"
        echo -e "${YELLOW}  Mudança de Domínio do Evolly Admin${NC}"
        echo -e "${YELLOW}============================================${NC}"
        echo ""
        echo -e "Domínio antigo: ${RED}$OLD_DOMAIN${NC}"
        echo -e "Domínio novo:   ${GREEN}$NEW_DOMAIN${NC}"
        echo ""
        echo -e "${YELLOW}IMPORTANTE: O DNS de $NEW_DOMAIN deve estar apontando para este servidor!${NC}"
        echo ""
        read -p "Deseja continuar? (s/N) " -n 1 -r
        echo ""

        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            echo "Operação cancelada."
            exit 0
        fi

        cd $INFRA_DIR

        # Backup da config atual
        echo -e "${GREEN}Fazendo backup da configuração...${NC}"
        cp nginx/conf.d/default.conf.ssl nginx/conf.d/default.conf.ssl.backup.$(date +%Y%m%d_%H%M%S)

        # Atualizar server_name do evolly
        echo -e "${GREEN}Atualizando configuração nginx...${NC}"
        sed -i.bak "s|server_name evolly.infinityitsolutions.com.br;|server_name $NEW_DOMAIN www.$NEW_DOMAIN;|g" nginx/conf.d/default.conf.ssl

        # Atualizar certificados SSL
        sed -i.bak "s|/etc/letsencrypt/live/evolly.infinityitsolutions.com.br/|/etc/letsencrypt/live/$NEW_DOMAIN/|g" nginx/conf.d/default.conf.ssl

        # Adicionar novo domínio ao bloco HTTP redirect (linha do server_name)
        if ! grep -q "$NEW_DOMAIN" nginx/conf.d/default.conf.ssl; then
            # Já foi atualizado pelo sed acima
            echo -e "${GREEN}Domínio atualizado na configuração${NC}"
        fi

        # Adicionar ao HTTP redirect block (primeira ocorrência de server_name com listen 80)
        sed -i.bak "s|server_name www.infinityitsolutions.com.br infinityitsolutions.com.br personalweb.infinityitsolutions.com.br personalapi.infinityitsolutions.com.br evolly.infinityitsolutions.com.br;|server_name www.infinityitsolutions.com.br infinityitsolutions.com.br personalweb.infinityitsolutions.com.br personalapi.infinityitsolutions.com.br $NEW_DOMAIN www.$NEW_DOMAIN;|g" nginx/conf.d/default.conf.ssl

        # Gerar certificado SSL
        echo -e "${GREEN}Gerando certificado SSL para $NEW_DOMAIN...${NC}"
        docker compose run --rm --entrypoint certbot certbot certonly --webroot \
            -w /var/www/certbot \
            -d $NEW_DOMAIN \
            -d www.$NEW_DOMAIN \
            --email admin@infinityitsolutions.com.br \
            --agree-tos --non-interactive

        # Verificar se certificado foi gerado
        if docker compose run --rm --entrypoint "" certbot test -d /etc/letsencrypt/live/$NEW_DOMAIN; then
            echo -e "${GREEN}✓ Certificado gerado com sucesso${NC}"
        else
            echo -e "${RED}✗ Falha ao gerar certificado${NC}"
            echo -e "${YELLOW}Restaurando backup...${NC}"
            cp nginx/conf.d/default.conf.ssl.backup.* nginx/conf.d/default.conf.ssl 2>/dev/null || true
            exit 1
        fi

        # Copiar para default.conf (arquivo que nginx usa)
        echo -e "${GREEN}Aplicando configuração...${NC}"
        cp nginx/conf.d/default.conf.ssl nginx/conf.d/default.conf

        # Testar e reiniciar nginx
        echo -e "${GREEN}Testando configuração nginx...${NC}"
        if docker exec nginx-proxy nginx -t; then
            docker compose restart nginx
            echo ""
            echo -e "${GREEN}============================================${NC}"
            echo -e "${GREEN}  Domínio alterado com sucesso!${NC}"
            echo -e "${GREEN}============================================${NC}"
            echo ""
            echo -e "Novo endereço: ${GREEN}https://$NEW_DOMAIN${NC}"
            echo ""
            echo -e "${YELLOW}Lembre-se de atualizar:${NC}"
            echo "  - Bookmarks e links salvos"
            echo "  - Documentação (CLAUDE.md)"
            echo "  - Variáveis de ambiente se houver"
            echo ""
        else
            echo -e "${RED}✗ Configuração nginx inválida${NC}"
            echo -e "${YELLOW}Restaurando backup...${NC}"
            cp nginx/conf.d/default.conf.ssl.backup.* nginx/conf.d/default.conf.ssl 2>/dev/null || true
            docker compose restart nginx
            exit 1
        fi
        ;;

    cleanup)
        echo -e "${YELLOW}Removendo containers parados e imagens não utilizadas...${NC}"
        docker system prune -f
        echo -e "${GREEN}Limpeza concluída${NC}"
        docker system df
        ;;

    disk)
        docker system df
        ;;

    *)
        show_help
        ;;
esac
