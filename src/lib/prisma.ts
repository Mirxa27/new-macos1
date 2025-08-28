import { PrismaClient } from '@prisma/client';

declare global {
  // eslint-disable-next-line no-var
  var prisma: PrismaClient | undefined;
}

export const prisma = global.prisma || new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
  errorFormat: 'pretty',
});

if (process.env.NODE_ENV !== 'production') {
  global.prisma = prisma;
}

// Middleware for soft deletes
prisma.$use(async (params, next) => {
  // Soft delete handling for findUnique and findFirst
  if (params.model === 'User') {
    if (params.action === 'findUnique' || params.action === 'findFirst') {
      params.action = 'findFirst';
      params.args.where = { ...params.args.where, deletedAt: null };
    }
    
    if (params.action === 'findMany') {
      if (params.args.where) {
        if (params.args.where.deletedAt === undefined) {
          params.args.where = { ...params.args.where, deletedAt: null };
        }
      } else {
        params.args.where = { deletedAt: null };
      }
    }
  }

  // Update handling for updatedAt
  if (params.action === 'update' || params.action === 'updateMany') {
    if (!params.args.data.updatedAt) {
      params.args.data.updatedAt = new Date();
    }
  }

  return next(params);
});

export default prisma;