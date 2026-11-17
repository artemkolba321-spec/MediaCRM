import 'package:media_crm/data/models/platform_channel.dart';

class PlatformCapability {
  const PlatformCapability({
    required this.auth,
    required this.limitations,
    required this.availableMetrics,
    required this.unavailableMetrics,
  });

  final String auth;
  final String limitations;
  final List<String> availableMetrics;
  final List<String> unavailableMetrics;
}

const Map<PlatformType, PlatformCapability> platformCapabilities = {
  PlatformType.youtube: PlatformCapability(
    auth:
        'OAuth 2.0 через Google. Нужны scopes youtube.readonly и, для '
        'аналитики, yt-analytics.readonly. Клиентские секреты хранятся только '
        'в Supabase Edge Functions.',
    limitations:
        'YouTube Data API имеет суточную квоту (по умолчанию 10 000 единиц). '
        'YouTube Analytics API отдаёт данные только для каналов, к которым у '
        'аккаунта есть доступ владельца. Доход доступен не всем аккаунтам и '
        'требует monetary-разрешений; без них поле дохода не заполняется.',
    availableMetrics: [
      'Подписчики',
      'Просмотры',
      'Лайки',
      'Комментарии',
      'Публикации (видео)',
      'Демография (если есть доступ Analytics API)',
    ],
    unavailableMetrics: ['Доход без monetary-доступа', 'Приватные данные зрителей'],
  ),
  PlatformType.telegram: PlatformCapability(
    auth:
        'Бот-администратор канала. Токен создаётся у @BotFather и сохраняется '
        'только на сервере. Бот должен быть добавлен в администраторы канала.',
    limitations:
        'Bot API даёт название, описание и число участников канала. Просмотры '
        'и реакции отдельных постов Bot API не отдаёт; для публикаций и '
        'просмотров нужен Telegram MTProto API с пользовательской сессией, '
        'который не используется из-за ограничений приватности и безопасности.',
    availableMetrics: ['Число участников', 'Название и описание канала'],
    unavailableMetrics: [
      'Просмотры постов через Bot API',
      'Демография подписчиков',
      'История подписчиков за прошлые даты',
    ],
  ),
  PlatformType.boosty: PlatformCapability(
    auth:
        'Публичного API Boosty нет. Официальная интеграция недоступна, '
        'поэтому используется ручной импорт или импорт из выгрузки личного '
        'кабинета.',
    limitations:
        'Автоматический сбор статистики невозможен. Все метрики, введённые '
        'вручную, помечаются источником manual, чтобы их нельзя было спутать '
        'с данными API.',
    availableMetrics: ['Всё, что вы вводите вручную'],
    unavailableMetrics: ['Автоматические подписки', 'Платежи', 'Публикации'],
  ),
  PlatformType.vk: PlatformCapability(
    auth:
        'Access token сообщества или пользователя с правами администратора. '
        'Токен сохраняется на сервере; клиент получает только статус '
        'подключения.',
    limitations:
        'VK API требует токен и соблюдения лимитов запросов. Просмотры и '
        'статистика сообщества доступны не для всех типов сообществ и '
        'аккаунтов; часть демографии отдаётся только владельцу. Закрытые '
        'сообщества и данные неадминистраторам недоступны.',
    availableMetrics: [
      'Подписчики сообщества',
      'Публикации на стене',
      'Лайки и комментарии к постам',
      'Просмотры сообщества (при доступе)',
    ],
    unavailableMetrics: ['Персональные данные подписчиков', 'Приватная демография'],
  ),
  PlatformType.github: PlatformCapability(
    auth:
        'OAuth GitHub или fine-grained personal access token. Токен хранится '
        'на сервере; для трафика репозитория нужны права на чтение '
        'администрирования репозитория.',
    limitations:
        'GitHub REST API отдаёт звёзды, форки, подписчиков и релизы. Трафик '
        'просмотров доступен только владельцу репозитория и только за '
        'последние 14 дней. Анонимные запросы ограничены 60 запросами в час, '
        'авторизованные — 5 000 в час.',
    availableMetrics: [
      'Репозитории',
      'Звёзды',
      'Форки',
      'Подписчики',
      'Релизы',
      'Просмотры репозитория (14 дней, при правах)',
    ],
    unavailableMetrics: ['Долгосрочная история трафика', 'Демография'],
  ),
};

String authMethodHint(PlatformType platform, AuthMethod method) {
  if (platform == PlatformType.boosty) return 'Ручной импорт';
  return switch (method) {
    AuthMethod.oauth => 'OAuth 2.0 на сервере',
    AuthMethod.botToken => 'Токен бота на сервере',
    AuthMethod.accessToken => 'Access token на сервере',
    AuthMethod.manual => 'Ручной ввод',
    AuthMethod.none => 'Не подключено',
  };
}
