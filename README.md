# n8n с SSL - Установка через curl

Полноценная установка n8n с SSL сертификатами от Let's Encrypt, автоматическим обновлением сертификатов и выбором базы данных.

## Быстрая установка

### Один скрипт - полная установка

```bash
curl -fsSL https://raw.githubusercontent.com/chapov/n8n-installator/main/install.sh | bash
```

### Что происходит:

1. Проверка системы (Ubuntu)
2. Клонирование репозитория во временную директорию
3. Запуск интерактивного установщика
4. Автоматическая установка Docker (если не установлен)
5. Настройка n8n с выбором базы данных
6. Получение SSL сертификата от Let's Encrypt
7. Запуск всех сервисов

## Требования

- Ubuntu (автоматически определяется)
- Права sudo для установки Docker
- Интернет-соединение
- Домен с A-записью на IP сервера

## Интерактивная настройка

После запуска скрипта вам будет предложено:

1. Домен - введите ваш домен (например: `n8n.example.com`)
2. Email - email для уведомлений Let's Encrypt
3. Таймзона - по умолчанию `Europe/Moscow`
4. База данных - выберите PostgreSQL или SQLite
5. Подтверждение - проверьте настройки

## Ручная установка

Если предпочитаете ручную установку:

```bash
# Клонирование репозитория
cd /opt/
git clone https://github.com/chapov/n8n-installator.git n8n
cd n8n

# Запуск интерактивного скрипта
./setup-interactive.sh
```

## Структура проекта

```
n8n-ssl/
├── install.sh                 # Скрипт установки через curl
├── setup-interactive.sh       # Интерактивный установщик
├── docker-compose.yaml        # Конфигурация Docker Compose
├── nginx/                     # Конфигурация nginx
│   ├── nginx.conf
│   └── conf.d/n8n.conf
├── .env.example               # Пример переменных окружения
└── README.md                  # Эта документация
```

## После установки

n8n будет доступен по адресу: **https://ваш-домен**

### Полезные команды:

```bash
# Переход в директорию установки
cd n8n-ssl

# Просмотр логов
docker compose logs -f n8n

# Проверка статуса
docker compose ps

# Перезапуск
docker compose restart

# Остановка
docker compose down

# Обновление n8n
docker compose pull n8n
docker compose up -d n8n
```

## Безопасность

- SSL сертификаты от Let's Encrypt
- Автоматическое обновление сертификатов
- Безопасные настройки nginx с HSTS
- PostgreSQL для продакшена
- SQLite для тестирования

## Решение проблем

### SSL сертификат не получен

```bash
# Проверьте DNS
dig +short ваш-домен

# Проверьте порты
sudo netstat -tlnp | grep -E ':(80|443)'

# Проверьте файрвол
sudo ufw status
```

### n8n не запускается

```bash
# Посмотрите логи
docker compose logs n8n
docker compose logs postgres

# Проверьте переменные окружения
docker compose exec n8n env | grep DB_
```

### Проблемы с Docker

```bash
# Проверьте группу docker
groups $USER

# Примените изменения группы
newgrp docker

# Или используйте sudo
sudo docker compose up -d
```

## Дополнительная информация

- Официальная документация n8n: https://docs.n8n.io/
- Сообщество n8n: https://community.n8n.io/
- GitHub n8n: https://github.com/n8n-io/n8n

## Лицензия

n8n использует лицензию [Fair-code](https://faircode.io/) с определенными ограничениями для коммерческого использования.

---

## Ссылки для установки

**Замените `chapov/n8n-installator` на ваш GitHub репозиторий:**

```bash
# Установка через curl
curl -fsSL https://raw.githubusercontent.com/chapov/n8n-installator/main/install.sh | bash

# Или через wget
wget -qO- https://raw.githubusercontent.com/chapov/n8n-installator/main/install.sh | bash
```

**Пример для репозитория `username/n8n-ssl-installer`:**
```bash
curl -fsSL https://raw.githubusercontent.com/username/n8n-ssl-installer/main/install.sh | bash
```