import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import Fastify, { type FastifyInstance } from 'fastify';
import { ZodError } from 'zod';

import { corsOrigins, env, isProduction } from './config.js';
import { AppError } from './lib/errors.js';
import { registerAuthRoutes } from './routes/auth.js';
import { registerPlatformRoutes } from './routes/platform.js';
import { registerSyncRoutes } from './routes/sync.js';

export async function buildApp(): Promise<FastifyInstance> {
  const app = Fastify({
    logger: {
      level: env.LOG_LEVEL,
      redact: {
        paths: [
          'req.headers.authorization',
          'req.body.password',
          'req.body.current_password',
          'req.body.new_password',
          'req.body.refresh_token',
          'req.body.credential',
        ],
        censor: '[redacted]',
      },
    },
    bodyLimit: 1_048_576,
    trustProxy: false,
  });

  await app.register(helmet, {
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'none'"],
        frameAncestors: ["'none'"],
      },
    },
  });
  await app.register(cors, {
    origin: corsOrigins.length > 0 ? corsOrigins : true,
    credentials: false,
    methods: ['GET', 'POST', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['content-type', 'authorization'],
    maxAge: 86_400,
  });
  await app.register(rateLimit, {
    global: false,
    max: 240,
    timeWindow: '1 minute',
  });

  app.setErrorHandler((error, request, reply) => {
    if (error instanceof ZodError) {
      const first = error.issues[0];
      reply.code(400).send({
        error: {
          code: 'validation_error',
          message: first?.message ?? 'Некорректный запрос',
          details: error.issues.map((issue) => ({
            path: issue.path.join('.'),
            message: issue.message,
          })),
        },
      });
      return;
    }
    if (error instanceof AppError) {
      reply.code(error.statusCode).send({
        error: {
          code: error.code,
          message: error.message,
          ...(error.details === undefined ? {} : { details: error.details }),
        },
      });
      return;
    }
    const failure = error as { statusCode?: number; message?: string };
    const statusCode =
      typeof failure.statusCode === 'number' && failure.statusCode >= 400
        ? failure.statusCode
        : 500;
    if (statusCode === 429) {
      reply.code(429).send({
        error: {
          code: 'rate_limited',
          message: 'Слишком много запросов. Повторите через минуту.',
        },
      });
      return;
    }
    request.log.error({ error }, 'unhandled request error');
    reply.code(statusCode).send({
      error: {
        code: statusCode >= 500 ? 'internal_error' : 'request_error',
        message:
          statusCode >= 500 && isProduction
            ? 'Внутренняя ошибка сервера'
            : (failure.message ?? 'Ошибка запроса'),
      },
    });
  });

  app.setNotFoundHandler((_request, reply) => {
    reply.code(404).send({
      error: { code: 'not_found', message: 'Маршрут не найден' },
    });
  });

  app.get('/health', async () => ({
    ok: true,
    service: 'mediacrm-api',
    uptime_seconds: Math.round(process.uptime()),
  }));

  app.get('/', async () => ({
    service: 'MediaCRM API',
    version: '2.0.0',
    docs: '/health',
  }));

  await registerAuthRoutes(app);
  await registerSyncRoutes(app);
  await registerPlatformRoutes(app);

  return app;
}
