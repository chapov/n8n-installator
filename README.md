# Интерактивная установка n8n

## Что умеет скрипт:

Автоматическая установка Docker на Ubuntu
Запрашивает домен с проверкой DNS
Запрашивает email для Let's Encrypt
Выбор базы данных:
   - PostgreSQL (для продакшена)
   - SQLite (для тестирования, и для мелких проектов)
Настройка таймзоны
Автоматическое создание .env
Обновление конфигурации nginx
Получение SSL сертификата
Запуск всех сервисов

## Использование:

```bash
# Запустите интерактивный скрипт
./setup-interactive.sh
```

**Требования:**
- Ubuntu (автоматически определяется)
- Права sudo для установки Docker
- Интернет-соединение

Скрипт проведёт вас через все настройки:

1. **Проверка Docker** - автоматически установит если не найден
2. **Домен** - введите ваш домен (например: `n8n.example.com`)
3. **Email** - email для уведомлений Let's Encrypt
4. **Таймзона** - по умолчанию `Europe/Moscow`
5. **База данных** - выберите PostgreSQL или SQLite
6. **Подтверждение** - проверьте настройки и подтвердите


## Что происходит дальше:

1. **Установка Docker** (если не установлен)
2. Создаётся файл `.env` с вашими настройками
3. Обновляется конфигурация nginx для вашего домена
4. Получается SSL сертификат от Let's Encrypt
5. Запускаются все необходимые сервисы
6. n8n становится доступен по HTTPS


## Результат:

После успешной установки вы получите:
- **n8n доступен по адресу:** `https://ваш-домен`
- **Автоматическое обновление SSL** каждые 12 часов
- **Готовая база данных** (PostgreSQL или SQLite)
- **Безопасная конфигурация nginx**


## Управление сервисами

### Просмотр логов
```bash
# Все сервисы
docker compose logs -f

# Только n8n
docker compose logs -f n8n

# Только nginx
docker compose logs -f nginx

# Только PostgreSQL (если установлен)
docker compose logs -f postgres
```

### Статус контейнеров
```bash
docker compose ps
```

### Перезапуск сервисов
```bash
# Все сервисы
docker compose restart

# Только n8n
docker compose restart n8n

# Только nginx
docker compose restart nginx
```

### Остановка и запуск
```bash
# Остановка
docker compose down

# Запуск
docker compose up -d

# Запуск с пересборкой
docker compose up -d --build
```

### Обновление n8n
```bash
# Скачать новую версию образа
docker compose pull n8n

# Пересоздать контейнер с новой версией
docker compose up -d n8n
```


## Резервное копирование

### База данных PostgreSQL
```bash
# Создание бэкапа
docker compose exec postgres pg_dump -U n8n n8n > backup_$(date +%Y%m%d_%H%M%S).sql

# Восстановление
docker compose exec -T postgres psql -U n8n n8n < backup.sql
```

### Данные n8n

```bash
# Создание бэкапа
docker run --rm -v n8n_n8n_data:/data -v $(pwd):/backup alpine tar czf /backup/n8n_data_$(date +%Y%m%d_%H%M%S).tar.gz -C /data .

# Восстановление
docker run --rm -v n8n_n8n_data:/data -v $(pwd):/backup alpine tar xzf /backup/n8n_data.tar.gz -C /data
```


## Настройка SMTP (опционально)

Для отправки уведомлений раскомментируйте в `.env`:

```bash
N8N_EMAIL_MODE=smtp
N8N_SMTP_HOST=smtp.gmail.com
N8N_SMTP_PORT=465
N8N_SMTP_USER=your-email@gmail.com
N8N_SMTP_PASS=your-app-password
N8N_SMTP_SENDER="n8n <your-email@gmail.com>"
N8N_SMTP_SSL=true
```
После изменений перезапустите:
```bash
docker compose restart n8n
```


## Мониторинг

n8n предоставляет эндпоинты для мониторинга:

- **Health check**: `https://n8n.domain.ru/healthz`
- **Metrics**: `https://n8n.domain.ru/metrics` (формат Prometheus)


---

## Другие скрипты:

- **`init-letsencrypt.sh`** - Основной скрипт, не интерактивный
- **`get-cert-standalone.sh`** - альтернативный способ получения SSL
- **`setup-interactive.sh`** - интерактивный скрипт

---

## Если что-то пошло не так:

```bash
# Посмотрите логи
docker compose logs -f n8n

# Проверьте статус
docker compose ps

# Перезапустить
docker compose restart
```

