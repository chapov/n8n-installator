#!/bin/bash

# Интерактивный скрипт установки n8n с SSL
# Позволяет выбрать домен, email и тип базы данных

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}Интерактивная установка n8n с SSL${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# Проверка прав sudo
if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}Для установки Docker требуются права sudo.${NC}"
    echo -e "${YELLOW}Введите пароль при запросе.${NC}"
    echo ""
fi

# Функция для проверки и установки Docker
install_docker() {
    echo -e "${YELLOW}Проверка Docker...${NC}"
    
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}Docker уже установлен!${NC}"
        docker --version
        return 0
    fi
    
    echo -e "${YELLOW}Docker не найден. Начинаем установку...${NC}"
    
    # Проверка, что мы на Ubuntu
    if ! grep -q "Ubuntu" /etc/os-release; then
        echo -e "${RED}Этот скрипт поддерживает только Ubuntu!${NC}"
        echo -e "${YELLOW}Установите Docker вручную для вашей системы.${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Обновление пакетов...${NC}"
    sudo apt-get update
    
    echo -e "${YELLOW}Установка необходимых пакетов...${NC}"
    sudo apt-get install -y ca-certificates curl
    
    echo -e "${YELLOW}Добавление GPG ключа Docker...${NC}"
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    
    echo -e "${YELLOW}Добавление репозитория Docker...${NC}"
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    echo -e "${YELLOW}Обновление списка пакетов...${NC}"
    sudo apt-get update
    
    echo -e "${YELLOW}Установка Docker...${NC}"
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    echo -e "${YELLOW}Добавление текущего пользователя в группу docker...${NC}"
    sudo usermod -aG docker $USER
    
    echo -e "${GREEN}Docker успешно установлен!${NC}"
    echo -e "${YELLOW}ВНИМАНИЕ: Для применения изменений группы docker необходимо перезайти в систему или выполнить:${NC}"
    echo -e "${BLUE}newgrp docker${NC}"
    echo ""
    
    # Проверка установки
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}Docker версия:${NC}"
        docker --version
        echo -e "${GREEN}Docker Compose версия:${NC}"
        docker compose version
        return 0
    else
        echo -e "${RED}Ошибка установки Docker!${NC}"
        return 1
    fi
}

# Проверка и установка Docker
install_docker
if [ $? -ne 0 ]; then
    echo -e "${RED}Не удалось установить Docker. Установите его вручную и запустите скрипт снова.${NC}"
    exit 1
fi

echo ""

# Функция для проверки валидности email
validate_email() {
    local email=$1
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Функция для проверки валидности домена
validate_domain() {
    local domain=$1
    # Простая проверка домена - только базовые символы
    if [[ $domain =~ ^[a-zA-Z0-9.-]+$ ]] && [[ ${#domain} -ge 3 ]] && [[ ${#domain} -le 253 ]]; then
        # Проверяем, что домен не начинается и не заканчивается точкой или дефисом
        if [[ $domain =~ ^[a-zA-Z0-9] ]] && [[ $domain =~ [a-zA-Z0-9]$ ]]; then
            return 0
        fi
    fi
    return 1
}

# Проверка интерактивности - убираем, так как bash -i должен работать

# Запрос домена
while true; do
    echo -e "${YELLOW}Введите домен для n8n (например: n8n.example.com):${NC}"
    read -p "Домен: " N8N_DOMAIN
    
    if [ -z "$N8N_DOMAIN" ]; then
        echo -e "${RED}Домен не может быть пустым!${NC}"
        continue
    fi
    
    if ! validate_domain "$N8N_DOMAIN"; then
        echo -e "${RED}Неверный формат домена!${NC}"
        echo -e "${YELLOW}Домен должен содержать только буквы, цифры, точки и дефисы.${NC}"
        echo -e "${YELLOW}Примеры: n8n.example.com, my-n8n.domain.org${NC}"
        continue
    fi
    
    echo -e "${BLUE}Проверка DNS записи для $N8N_DOMAIN...${NC}"
    DOMAIN_IP=$(dig +short $N8N_DOMAIN | tail -n1)
    if [ -z "$DOMAIN_IP" ]; then
        echo -e "${RED}Внимание: Домен $N8N_DOMAIN не резолвится!${NC}"
        echo -e "${YELLOW}Убедитесь, что DNS запись указывает на этот сервер.${NC}"
        read -p "Продолжить все равно? (yes/no): " CONTINUE
        if [ "$CONTINUE" != "yes" ]; then
            continue
        fi
    else
        echo -e "${GREEN}DNS запись найдена: $DOMAIN_IP${NC}"
    fi
    
    break
done

echo ""

# Запрос email
while true; do
    echo -e "${YELLOW}Введите email для уведомлений Let's Encrypt:${NC}"
    read -p "Email: " SSL_EMAIL
    
    if [ -z "$SSL_EMAIL" ]; then
        echo -e "${RED}Email не может быть пустым!${NC}"
        continue
    fi
    
    if ! validate_email "$SSL_EMAIL"; then
        echo -e "${RED}Неверный формат email!${NC}"
        continue
    fi
    
    break
done

echo ""

# Запрос таймзоны
echo -e "${YELLOW}Введите таймзону (по умолчанию: Europe/Moscow):${NC}"
read -p "Таймзона: " TIMEZONE
TIMEZONE=${TIMEZONE:-Europe/Moscow}

echo ""

# Выбор базы данных
echo -e "${YELLOW}Выберите тип базы данных:${NC}"
echo "1) PostgreSQL (рекомендуется для продакшена)"
echo "2) SQLite (проще для тестирования)"
echo ""
read -p "Выберите (1 или 2): " DB_CHOICE

case $DB_CHOICE in
    1)
        DB_TYPE="postgresdb"
        echo -e "${GREEN}Выбрана PostgreSQL${NC}"
        
        # Настройки PostgreSQL
        echo -e "${YELLOW}Настройки PostgreSQL:${NC}"
        read -p "Имя базы данных (по умолчанию: n8n): " POSTGRES_DB
        POSTGRES_DB=${POSTGRES_DB:-n8n}
        
        read -p "Пользователь базы данных (по умолчанию: n8n): " POSTGRES_USER
        POSTGRES_USER=${POSTGRES_USER:-n8n}
        
        while true; do
            read -s -p "Пароль для базы данных: " POSTGRES_PASSWORD
            echo ""
            if [ -z "$POSTGRES_PASSWORD" ]; then
                echo -e "${RED}Пароль не может быть пустым!${NC}"
                continue
            fi
            if [ ${#POSTGRES_PASSWORD} -lt 8 ]; then
                echo -e "${RED}Пароль должен содержать минимум 8 символов!${NC}"
                continue
            fi
            break
        done
        ;;
    2)
        DB_TYPE="sqlite"
        echo -e "${GREEN}Выбрана SQLite${NC}"
        ;;
    *)
        echo -e "${RED}Неверный выбор! Используется PostgreSQL по умолчанию.${NC}"
        DB_TYPE="postgresdb"
        POSTGRES_DB="n8n"
        POSTGRES_USER="n8n"
        POSTGRES_PASSWORD="ChangeThisToSecurePassword123!"
        ;;
esac

echo ""

# Показ выбранной конфигурации
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Выбранная конфигурация:${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "Домен: ${GREEN}$N8N_DOMAIN${NC}"
echo -e "Email: ${GREEN}$SSL_EMAIL${NC}"
echo -e "Таймзона: ${GREEN}$TIMEZONE${NC}"
echo -e "База данных: ${GREEN}$DB_TYPE${NC}"
if [ "$DB_TYPE" = "postgresdb" ]; then
    echo -e "PostgreSQL DB: ${GREEN}$POSTGRES_DB${NC}"
    echo -e "PostgreSQL User: ${GREEN}$POSTGRES_USER${NC}"
fi
echo ""

read -p "Продолжить установку? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Установка отменена.${NC}"
    exit 0
fi

echo ""

# Создание .env файла
echo -e "${YELLOW}Создание файла .env...${NC}"
cat > .env << EOF
# ==============================================
# Конфигурация n8n
# ==============================================

# Домен для доступа к n8n
N8N_DOMAIN=$N8N_DOMAIN

# Email для уведомлений Let's Encrypt
SSL_EMAIL=$SSL_EMAIL

# Таймзона
TIMEZONE=$TIMEZONE

# ==============================================
# База данных
# ==============================================

DB_TYPE=$DB_TYPE

EOF

if [ "$DB_TYPE" = "postgresdb" ]; then
    cat >> .env << EOF
POSTGRES_DB=$POSTGRES_DB
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
EOF
else
    cat >> .env << EOF
# SQLite не требует дополнительных переменных
EOF
fi

cat >> .env << EOF

# ==============================================
# Дополнительные настройки (опционально)
# ==============================================

# Настройки SMTP для отправки уведомлений
# N8N_EMAIL_MODE=smtp
# N8N_SMTP_HOST=smtp.gmail.com
# N8N_SMTP_PORT=465
# N8N_SMTP_USER=your-email@gmail.com
# N8N_SMTP_PASS=your-app-password
# N8N_SMTP_SENDER="n8n <your-email@gmail.com>"
# N8N_SMTP_SSL=true
EOF

echo -e "${GREEN}Файл .env создан!${NC}"

# Обновление конфигурации nginx
echo -e "${YELLOW}Обновление конфигурации nginx...${NC}"
cat > ./nginx/conf.d/n8n.conf << EOF
# Перенаправление с HTTP на HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $N8N_DOMAIN;
    
    # Локация для проверки Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # Перенаправление всех остальных запросов на HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS конфигурация
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $N8N_DOMAIN;

    # SSL сертификаты
    ssl_certificate /etc/letsencrypt/live/$N8N_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$N8N_DOMAIN/privkey.pem;
    
    # SSL настройки для безопасности
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    
    # HSTS (загружать только через HTTPS в течение 1 года)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Другие заголовки безопасности
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Логи
    access_log /var/log/nginx/n8n_access.log;
    error_log /var/log/nginx/n8n_error.log;

    # Проксирование к n8n
    location / {
        proxy_pass http://n8n:5678;
        proxy_http_version 1.1;
        
        # Заголовки для правильной работы n8n
        proxy_set_header Connection "upgrade";
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        
        # Таймауты для длительных операций
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
        proxy_send_timeout 300s;
        
        # Буферизация
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
EOF

echo -e "${GREEN}Конфигурация nginx обновлена!${NC}"

# Создание необходимых директорий
echo -e "${YELLOW}Создание необходимых директорий...${NC}"
mkdir -p ./certbot/conf
mkdir -p ./certbot/www
mkdir -p ./nginx/conf.d
mkdir -p ./local-files

# Создание временной nginx конфигурации для получения сертификата
echo -e "${YELLOW}Создание временной конфигурации nginx...${NC}"
cat > ./nginx/conf.d/n8n-temp.conf << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $N8N_DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 200 'OK - Waiting for SSL certificate';
        add_header Content-Type text/plain;
    }
}
EOF

# Временно переименовываем основную конфигурацию n8n
echo -e "${YELLOW}Временное отключение основной конфигурации n8n...${NC}"
if [ -f "./nginx/conf.d/n8n.conf" ]; then
    mv ./nginx/conf.d/n8n.conf ./nginx/conf.d/n8n.conf.backup
fi

# Запуск только nginx для получения сертификата
echo -e "${YELLOW}Запуск nginx для получения SSL сертификата...${NC}"
docker compose up -d nginx

echo -e "${YELLOW}Ожидание запуска nginx...${NC}"
sleep 5

# Получение сертификата
echo -e "${YELLOW}Запрос SSL сертификата от Let's Encrypt...${NC}"
docker run --rm \
    -v $(pwd)/certbot/conf:/etc/letsencrypt \
    -v $(pwd)/certbot/www:/var/www/certbot \
    certbot/certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email $SSL_EMAIL \
    --agree-tos \
    --no-eff-email \
    --force-renewal \
    -d $N8N_DOMAIN

if [ $? -eq 0 ]; then
    echo -e "${GREEN}SSL сертификат успешно получен!${NC}"
    
    # Удаление временной конфигурации
    echo -e "${YELLOW}Удаление временной конфигурации...${NC}"
    rm -f ./nginx/conf.d/n8n-temp.conf
    
    # Восстановление основной конфигурации n8n
    echo -e "${YELLOW}Восстановление основной конфигурации n8n...${NC}"
    if [ -f "./nginx/conf.d/n8n.conf.backup" ]; then
        mv ./nginx/conf.d/n8n.conf.backup ./nginx/conf.d/n8n.conf
    fi
    
    # Остановка временного nginx
    echo -e "${YELLOW}Остановка временного nginx...${NC}"
    docker compose down
    
    # Запуск всех сервисов
    echo -e "${GREEN}Запуск всех сервисов n8n...${NC}"
    if [ "$DB_TYPE" = "postgresdb" ]; then
        docker compose --profile postgres up -d
    else
        docker compose up -d nginx n8n certbot
    fi
    
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}Установка завершена успешно!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${GREEN}n8n доступен по адресу: https://$N8N_DOMAIN${NC}"
    echo ""
    echo -e "${YELLOW}Полезные команды:${NC}"
    echo -e "  docker compose logs -f n8n     - просмотр логов n8n"
    echo -e "  docker compose ps              - статус контейнеров"
    echo -e "  docker compose restart         - перезапуск всех сервисов"
    echo -e "  docker compose down            - остановка всех сервисов"
    echo ""
    echo -e "${YELLOW}Сертификат будет автоматически обновляться каждые 12 часов.${NC}"
    echo ""
else
    echo -e "${RED}Ошибка при получении SSL сертификата!${NC}"
    echo -e "${YELLOW}Убедитесь, что:${NC}"
    echo -e "  1. Домен $N8N_DOMAIN указывает на этот сервер"
    echo -e "  2. Порты 80 и 443 открыты в файрволе"
    echo -e "  3. На портах 80 и 443 не запущены другие сервисы"
    echo ""
    
    # Восстановление основной конфигурации даже при ошибке
    if [ -f "./nginx/conf.d/n8n.conf.backup" ]; then
        mv ./nginx/conf.d/n8n.conf.backup ./nginx/conf.d/n8n.conf
    fi
    
    docker compose down
    exit 1
fi
