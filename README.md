# MediaCRM — Creator Workspace

**Единая CRM для управления медиасетью**: YouTube, Telegram, Boosty, ВКонтакте и GitHub.

## Возможности

- **Дашборд** — общая сводка: аудитория, просмотры, доходы, прирост, публикации, рекламодатели, партнёры
- **Аналитика** — 4 раздела: Обзор, Охват, Доход, Аудитория с графиками и диаграммами
- **Мои каналы** — подключение площадок через OAuth, ручной ввод метрик, история синхронизаций
- **Аудитория и контакты** — база контактов, сегменты, история взаимодействий
- **Публикации** —统一管理 всех публикаций со всех платформ со статистикой
- **Финансы** — доходы, расходы, переводы, возвраты, валюты, P&L, категории
- **Рекламодатели** — карточки компаний, рекламные кампании, бюджеты, документы
- **Партнёры** — реферальная система, промокоды, трекинг конверсий, комиссии
- **Воронки** — CRM-воронки продаж с этапами, сделками и метриками конверсии
- **Задачи** — список, доска, календарь, напоминания, привязка к сущностям
- **Уведомления** — центр уведомлений о синхронизациях, ошибках, финансовых событиях
- **Настройки** — профиль, тема, валюта, синхронизация, резервное копирование

## Архитектура

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter Client                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐  │
│  │  Features │  │Providers │  │   Core (theme,       │  │
│  │ (screens) │  │(Riverpod)│  │   charts, utils)     │  │
│  └────┬─────┘  └────┬─────┘  └──────────┬───────────┘  │
│       │              │                   │              │
│  ┌────▼──────────────▼───────────────────▼───────────┐  │
│  │           Repository Layer                         │  │
│  │  (CRUD + business logic + activity logging)        │  │
│  └────────────────────┬──────────────────────────────┘  │
│                       │                                 │
│  ┌────────────────────▼──────────────────────────────┐  │
│  │           Data Layer                               │  │
│  │  ┌──────────────┐  ┌──────────────────────────┐   │  │
│  │  │ LocalStore    │  │   CloudService           │   │  │
│  │  │ (SharedPreferences) │ (Supabase PostgreSQL) │   │  │
│  │  └──────────────┘  └──────────────────────────┘   │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│              Supabase Backend                           │
│  ┌─────────────┐  ┌────────────┐  ┌─────────────────┐  │
│  │  PostgreSQL │  │  Auth      │  │  Edge Functions  │  │
│  │  (RLS)      │  │  (email)   │  │  (OAuth, Sync)  │  │
│  └─────────────┘  └────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Offline-first**: все данные хранятся локально (SharedPreferences). При наличии облачного аккаунта изменения синхронизируются с PostgreSQL через Supabase.

## Технологии

| Слой | Технология |
|------|-----------|
| Клиент | Flutter 3.x (Android, iOS, Windows, macOS, Web) |
| Состояние | Riverpod 2.x |
| Локальное хранилище | SharedPreferences |
| Облако | Supabase (PostgreSQL + Auth + Edge Functions) |
| Графики | CustomPainter (без внешних библиотек) |
| Навигация | Feature-first, sidebar + bottom nav |

## Поддерживаемые платформы

| Платформа | Метод подключения | Доступные метрики |
|-----------|------------------|-------------------|
| **YouTube** | OAuth 2.0 (Google) | Подписчики, просмотры, лайки, комментарии, публикации, демография |
| **Telegram** | Bot API (бот-администратор) | Число участников, название, описание |
| **Boosty** | Ручной ввод | Всё, что вводится вручную (помечается как `manual`) |
| **ВКонтакте** | Access token сообщества | Подписчики, публикации, лайки, комментарии, просмотры |
| **GitHub** | OAuth / fine-grained token | Репозитории, звёзды, форки, подписчики, релизы, просмотры (14 дней) |

## Установка и запуск

### Предварительные требования

- Flutter SDK >= 3.5.0
- Dart SDK >= 3.5.0
- Supabase проект (бесплатный tier подходит)
- Аккаунты платформ для OAuth (Google, VK, GitHub)

### 1. Клонирование

```bash
git clone <repository-url>
cd mediaCRM
```

### 2. Настройка конфигурации (.env)

Приложение читает Supabase-учётные данные из файла `.env` при запуске.

1. Скопируйте шаблон в реальный файл:

   ```bash
   cp .env.example .env
   ```

2. Откройте `.env` и заполните значения:

   | Переменная | Что вставить | Где найти |
   |------------|-------------|-----------|
   | `SUPABASE_URL` | Project URL | Supabase Dashboard → Settings → API → **Project URL** |
   | `SUPABASE_ANON_KEY` | anon public key | Supabase Dashboard → Settings → API → **anon public key** |

   Пример заполненного `.env`:

   ```env
   SUPABASE_URL=https://abcdefgh.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

3. **Никогда не коммитьте `.env`** — он добавлен в `.gitignore`. Шаблон `.env.example` безопасен для Git: в нём только пустые значения.

4. Если `.env` отсутствует или значения пусты, приложение автоматически запускается в **локальном режиме** — все данные хранятся на устройстве без облака.

### 3. Локальный запуск (без облака)

```bash
flutter pub get
flutter run -d <device>
```

Приложение запустится в **локальном режиме** — все данные хранятся на устройстве, работает полностью без интернета.

### 4. Настройка Supabase

#### 4.1 Создание проекта

1. Создайте проект на [supabase.com](https://supabase.com)
2. Скопируйте `Project URL` и `anon public key`

#### 4.2 Применение миграций

Выполните SQL-миграцию в SQL Editor Supabase или через CLI:

```bash
# Через Supabase CLI
supabase db push

# Или вручную в SQL Editor:
# Скопируйте содержимое sql/migrations/001_initial_schema.sql
```

#### 4.3 Развёртывание Edge Functions

```bash
# Установите Supabase CLI
npm install -g supabase

# Войдите в CLI
supabase login

# Привяжите проект
supabase link --project-ref <your-project-ref>

# Разверните Edge Functions
supabase functions deploy platform-sync
supabase functions deploy platform-oauth-start
supabase functions deploy platform-connect
supabase functions deploy platform-disconnect
supabase functions deploy platform-oauth-callback
```

#### 4.4 Настройка переменных окружения

В панели Supabase → Settings → Edge Functions добавьте:

```
# YouTube
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
YOUTUBE_API_KEY=your-youtube-api-key

# Telegram
TELEGRAM_BOT_TOKEN=your-telegram-bot-token

# VK
VK_CLIENT_ID=your-vk-app-id
VK_CLIENT_SECRET=your-vk-secret
VK_ACCESS_TOKEN=your-vk-access-token

# GitHub
GITHUB_CLIENT_ID=your-github-client-id
GITHUB_CLIENT_SECRET=your-github-client-secret
GITHUB_TOKEN=your-github-token

# Общие
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
APP_REDIRECT_URL=mediacrm://oauth-callback
```

#### 4.5 Настройка OAuth

**Google / YouTube:**
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create OAuth 2.0 credentials
3. Add redirect URI: `https://your-project.supabase.co/functions/v1/platform-oauth-callback`
4. Copy Client ID and Secret to Edge Functions env vars

**VK:**
1. Create app at [vk.com/myapp](https://vk.com/myapp)
2. Set type: «Stand-alone application»
3. Copy Client ID and Secret

**GitHub:**
1. Create OAuth App at GitHub Settings → Developer settings
2. Set callback URL: `https://your-project.supabase.co/functions/v1/platform-oauth-callback`

### 5. Запуск с облаком

После заполнения `.env` приложение автоматически подхватит Supabase-конфигурацию:

```bash
flutter pub get
flutter run -d <device>
```

Для production-сборки тоже достаточно:

```bash
flutter build apk --release
```

Передавать `--dart-define` больше не нужно — ключи читаются из `.env` при запуске.

## Структура проекта

```
lib/
├── main.dart                    # Точка входа, инициализация
├── app.dart                     # MaterialApp, роутинг
├── core/
│   ├── analytics/               # Расчёты аналитики и финансов
│   ├── config/                  # Конфигурация (Supabase URL)
│   ├── platform/                # Ограничения и возможности платформ
│   ├── theme/                   # Тема (светлая/тёмная)
│   ├── utils/                   # Утилиты (форматирование, JSON)
│   └── widgets/                 # Виджеты (графики, фильтры, UI)
├── data/
│   ├── cloud/                   # CloudService (Supabase sync)
│   ├── local/                   # LocalStore (SharedPreferences)
│   ├── models/                  # Модели данных
│   └── repositories/            # Репозитории (CRUD + бизнес-логика)
├── features/                    # Экраны по фичам
│   ├── auth/
│   ├── dashboard/
│   ├── analytics/
│   ├── channels/
│   ├── audience/
│   ├── publications/
│   ├── finance/
│   ├── advertisers/
│   ├── partners/
│   ├── funnels/
│   ├── tasks/
│   ├── notifications/
│   ├── settings/
│   └── shell/                   # MainShell (навигация)
└── providers/                   # Riverpod providers

supabase/
└── functions/                   # Edge Functions
    ├── platform-sync/
    ├── platform-oauth-start/
    ├── platform-connect/
    ├── platform-disconnect/
    └── platform-oauth-callback/

sql/
└── migrations/
    └── 001_initial_schema.sql   # Схема БД (15+ таблиц, RLS)
```

## База данных

### Основные таблицы

| Таблица | Назначение |
|---------|-----------|
| `profiles` | Профили пользователей |
| `platform_channels` | Подключённые каналы/площадки |
| `analytics_snapshots` | История метрик (подписчики, просмотры) |
| `financial_operations` | Финансовые операции |
| `partners` | Партнёры и рефералы |
| `partner_events` | События партнёров (клики, продажи) |
| `contacts` | База контактов |
| `publications` | Публикации со всех платформ |
| `publication_stats` | Статистика публикаций |
| `funnels` | Воронки продаж |
| `funnel_stages` | Этапы воронок |
| `funnel_deals` | Сделки |
| `advertisers` | Рекламодатели |
| `ad_campaigns` | Рекламные кампании |
| `tasks` | Задачи |
| `notifications` | Уведомления |
| `user_settings` | Настройки пользователя |
| `activity_log` | Журнал действий |
| `currency_rates` | Курсы валют |

Все таблицы защищены **Row Level Security (RLS)** — каждый пользователь видит только свои данные.

## Безопасность

- **OAuth-токены** хранятся только на сервере (Edge Functions)
- **Flutter-клиент** никогда не содержит секретов
- **RLS** изолирует данные разных пользователей
- **Минимальные разрешения** API — запрашиваются только необходимые scopes
- **Валидация** входных данных на всех уровнях
- **Секреты** не выводятся в логи

## Тестирование

```bash
# Запуск всех тестов
flutter test

# Тесты бизнес-логики
flutter test test/finance_calculator_test.dart
flutter test test/analytics_calculator_test.dart
flutter test test/funnel_test.dart

# Тесты моделей
flutter test test/model_serialization_test.dart

# Widget-тесты
flutter test test/widget_test.dart
```

## Резервное копирование

Встроенная система экспорта/импорта данных в JSON:

1. Настройки → Резервное копирование → Экспорт
2. Файл сохраняется на устройство
3. Для восстановления: Настройки → Импорт → выбрать файл

Данные включают: каналы, метрики, финансы, контакты, публикации, задачи, воронки, партнёров, рекламодателей.

## Ограничения API

### YouTube
- Квота API: 10 000 единиц/день (бесплатный tier)
- YouTube Analytics API: только для каналов с доступом владельца
- Доход: только при наличии monetary-разрешений

### Telegram
- Bot API: только публичные каналы
- Просмотры постов: недоступны через Bot API
- Демография: недоступна

### Boosty
- Публичного API нет
- Только ручной ввод метрик
- Все данные помечаются как `manual`

### ВКонтакте
- Лимит запросов: зависит от типа токена
- Статистика: не для всех типов сообществ
- Закрытые сообщества: недоступны не-администраторам

### GitHub
- Квота: 5 000 запросов/час (авторизованные), 60 (анонимные)
- Трафик просмотров: только за 14 дней
- Долгосрочная история: недоступна

## Разработка

### Добавление новой платформы

1. Добавьте `PlatformType` в `lib/data/models/platform_channel.dart`
2. Добавьте Edge Function в `supabase/functions/platform-sync/`
3. Добавьте таблицу миграции в `sql/migrations/`
4. Добавьте модель в `lib/data/models/`
5. Добавьте репозиторий в `lib/data/repositories/`
6. Добавьте экран в `lib/features/`

### Конфигурация

Переменные конфигурации задаются при сборке через `--dart-define`:

```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

Секреты (client secrets, API keys) никогда не передаются клиенту.

## Лицензия

© 2024 MediaCRM. Все права защищены.
