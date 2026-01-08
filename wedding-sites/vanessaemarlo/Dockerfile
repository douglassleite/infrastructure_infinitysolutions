FROM nginx:alpine

# Copiar configuração do nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Copiar arquivos do site
COPY site/ /usr/share/nginx/html/

# Expor porta
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1
