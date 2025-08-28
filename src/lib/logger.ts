import { prisma } from '@/lib/prisma';

export enum LogLevel {
  DEBUG = 'DEBUG',
  INFO = 'INFO',
  WARN = 'WARN',
  ERROR = 'ERROR',
  FATAL = 'FATAL',
}

export interface LogContext {
  userId?: string;
  sessionId?: string;
  requestId?: string;
  ip?: string;
  userAgent?: string;
  method?: string;
  path?: string;
  statusCode?: number;
  duration?: number;
  [key: string]: any;
}

class Logger {
  private isDevelopment = process.env.NODE_ENV === 'development';
  private logLevel: LogLevel = (process.env.LOG_LEVEL as LogLevel) || LogLevel.INFO;

  private shouldLog(level: LogLevel): boolean {
    const levels = [LogLevel.DEBUG, LogLevel.INFO, LogLevel.WARN, LogLevel.ERROR, LogLevel.FATAL];
    const currentLevelIndex = levels.indexOf(this.logLevel);
    const messageLevelIndex = levels.indexOf(level);
    return messageLevelIndex >= currentLevelIndex;
  }

  private formatMessage(level: LogLevel, message: string, context?: LogContext): string {
    const timestamp = new Date().toISOString();
    const contextStr = context ? ` ${JSON.stringify(context)}` : '';
    return `[${timestamp}] [${level}] ${message}${contextStr}`;
  }

  private async saveToDatabase(
    level: LogLevel,
    message: string,
    context?: LogContext,
    error?: Error
  ): Promise<void> {
    if (process.env.NODE_ENV === 'test') return;

    try {
      await prisma.auditLog.create({
        data: {
          userId: context?.userId,
          action: level,
          entity: 'System',
          entityId: context?.requestId,
          metadata: {
            message,
            context,
            error: error ? {
              name: error.name,
              message: error.message,
              stack: error.stack,
            } : undefined,
          },
          ipAddress: context?.ip,
          userAgent: context?.userAgent,
        },
      });
    } catch (dbError) {
      console.error('Failed to save log to database:', dbError);
    }
  }

  debug(message: string, context?: LogContext): void {
    if (!this.shouldLog(LogLevel.DEBUG)) return;
    
    const formattedMessage = this.formatMessage(LogLevel.DEBUG, message, context);
    console.debug(formattedMessage);
  }

  info(message: string, context?: LogContext): void {
    if (!this.shouldLog(LogLevel.INFO)) return;
    
    const formattedMessage = this.formatMessage(LogLevel.INFO, message, context);
    console.info(formattedMessage);
    
    if (!this.isDevelopment) {
      this.saveToDatabase(LogLevel.INFO, message, context);
    }
  }

  warn(message: string, context?: LogContext): void {
    if (!this.shouldLog(LogLevel.WARN)) return;
    
    const formattedMessage = this.formatMessage(LogLevel.WARN, message, context);
    console.warn(formattedMessage);
    
    this.saveToDatabase(LogLevel.WARN, message, context);
  }

  error(message: string, error?: Error | any, context?: LogContext): void {
    if (!this.shouldLog(LogLevel.ERROR)) return;
    
    const formattedMessage = this.formatMessage(LogLevel.ERROR, message, context);
    console.error(formattedMessage, error);
    
    this.saveToDatabase(LogLevel.ERROR, message, context, error);
  }

  fatal(message: string, error?: Error | any, context?: LogContext): void {
    const formattedMessage = this.formatMessage(LogLevel.FATAL, message, context);
    console.error(formattedMessage, error);
    
    this.saveToDatabase(LogLevel.FATAL, message, context, error);
    
    // In production, you might want to send alerts for fatal errors
    if (!this.isDevelopment) {
      this.sendAlert(message, error, context);
    }
  }

  private async sendAlert(message: string, error?: Error | any, context?: LogContext): Promise<void> {
    // Implement alert mechanism (email, Slack, PagerDuty, etc.)
    // This is a placeholder for alert functionality
    try {
      // Example: Send to monitoring service
      if (process.env.SENTRY_DSN) {
        // Sentry integration would go here
      }
      
      // Example: Send critical alert email
      if (process.env.ALERT_EMAIL) {
        // Email alert would go here
      }
    } catch (alertError) {
      console.error('Failed to send alert:', alertError);
    }
  }

  // HTTP request logging
  async logRequest(
    method: string,
    path: string,
    statusCode: number,
    duration: number,
    context?: LogContext
  ): Promise<void> {
    const level = statusCode >= 500 ? LogLevel.ERROR : 
                  statusCode >= 400 ? LogLevel.WARN : 
                  LogLevel.INFO;
    
    const message = `${method} ${path} ${statusCode} ${duration}ms`;
    
    if (this.shouldLog(level)) {
      const formattedMessage = this.formatMessage(level, message, {
        ...context,
        method,
        path,
        statusCode,
        duration,
      });
      
      if (level === LogLevel.ERROR) {
        console.error(formattedMessage);
      } else if (level === LogLevel.WARN) {
        console.warn(formattedMessage);
      } else {
        console.info(formattedMessage);
      }
    }
    
    // Only save to database for non-200 responses in production
    if (!this.isDevelopment && statusCode !== 200) {
      await this.saveToDatabase(level, message, {
        ...context,
        method,
        path,
        statusCode,
        duration,
      });
    }
  }

  // Performance logging
  startTimer(label: string): () => void {
    const start = Date.now();
    return () => {
      const duration = Date.now() - start;
      this.debug(`Performance: ${label} took ${duration}ms`, { duration, label });
    };
  }

  // Audit logging
  async audit(
    userId: string,
    action: string,
    entity: string,
    entityId?: string,
    oldValue?: any,
    newValue?: any,
    context?: LogContext
  ): Promise<void> {
    const message = `User ${userId} performed ${action} on ${entity}${entityId ? ` (${entityId})` : ''}`;
    
    this.info(message, { ...context, userId, action, entity, entityId });
    
    await prisma.auditLog.create({
      data: {
        userId,
        action,
        entity,
        entityId,
        oldValue,
        newValue,
        metadata: context,
        ipAddress: context?.ip,
        userAgent: context?.userAgent,
      },
    });
  }
}

export const logger = new Logger();

// Middleware for request logging
export function requestLogger(req: Request): LogContext {
  const requestId = crypto.randomUUID();
  const context: LogContext = {
    requestId,
    method: req.method,
    path: new URL(req.url).pathname,
    ip: req.headers.get('x-forwarded-for') || req.headers.get('x-real-ip') || 'unknown',
    userAgent: req.headers.get('user-agent') || 'unknown',
  };
  
  return context;
}

// Error boundary for unhandled errors
if (typeof window === 'undefined') {
  process.on('uncaughtException', (error: Error) => {
    logger.fatal('Uncaught Exception', error);
    process.exit(1);
  });

  process.on('unhandledRejection', (reason: any, promise: Promise<any>) => {
    logger.fatal('Unhandled Rejection', reason, { promise: promise.toString() });
  });
}