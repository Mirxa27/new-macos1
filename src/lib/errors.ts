export class AppError extends Error {
  public readonly statusCode: number;
  public readonly isOperational: boolean;
  public readonly details?: any;

  constructor(
    message: string,
    statusCode: number = 500,
    isOperational: boolean = true,
    details?: any
  ) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = isOperational;
    this.details = details;

    Object.setPrototypeOf(this, AppError.prototype);
    Error.captureStackTrace(this, this.constructor);
  }
}

export class ValidationError extends AppError {
  constructor(message: string, details?: any) {
    super(message, 400, true, details);
  }
}

export class AuthenticationError extends AppError {
  constructor(message: string = 'Authentication failed') {
    super(message, 401, true);
  }
}

export class AuthorizationError extends AppError {
  constructor(message: string = 'Insufficient permissions') {
    super(message, 403, true);
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string) {
    super(`${resource} not found`, 404, true);
  }
}

export class ConflictError extends AppError {
  constructor(message: string) {
    super(message, 409, true);
  }
}

export class RateLimitError extends AppError {
  constructor(message: string = 'Too many requests') {
    super(message, 429, true);
  }
}

export class ExternalServiceError extends AppError {
  constructor(service: string, originalError?: any) {
    super(`External service error: ${service}`, 503, false, originalError);
  }
}

export function isAppError(error: any): error is AppError {
  return error instanceof AppError;
}

export function handleError(error: any): {
  message: string;
  statusCode: number;
  details?: any;
} {
  if (isAppError(error)) {
    return {
      message: error.message,
      statusCode: error.statusCode,
      details: error.details,
    };
  }

  // Prisma errors
  if (error.code === 'P2002') {
    return {
      message: 'A record with this value already exists',
      statusCode: 409,
      details: error.meta,
    };
  }

  if (error.code === 'P2025') {
    return {
      message: 'Record not found',
      statusCode: 404,
    };
  }

  // Zod validation errors
  if (error.name === 'ZodError') {
    return {
      message: 'Validation error',
      statusCode: 400,
      details: error.errors,
    };
  }

  // JWT errors
  if (error.name === 'JsonWebTokenError') {
    return {
      message: 'Invalid token',
      statusCode: 401,
    };
  }

  if (error.name === 'TokenExpiredError') {
    return {
      message: 'Token expired',
      statusCode: 401,
    };
  }

  // Default error
  return {
    message: process.env.NODE_ENV === 'production' 
      ? 'An unexpected error occurred' 
      : error.message || 'Unknown error',
    statusCode: 500,
    details: process.env.NODE_ENV === 'development' ? error : undefined,
  };
}