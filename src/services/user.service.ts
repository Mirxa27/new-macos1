import { User, UserRole, UserStatus, Prisma } from '@prisma/client';
import { prisma } from '@/lib/prisma';
import { hashPassword } from '@/lib/auth/password';
import { generateEmailVerificationToken } from '@/lib/auth/jwt';
import { sendEmail } from '@/services/email.service';
import { z } from 'zod';

export interface CreateUserDto {
  email: string;
  password: string;
  firstName?: string;
  lastName?: string;
  username?: string;
  role?: UserRole;
}

export interface UpdateUserDto {
  firstName?: string;
  lastName?: string;
  username?: string;
  avatar?: string;
  status?: UserStatus;
  role?: UserRole;
}

export interface UserFilter {
  search?: string;
  role?: UserRole;
  status?: UserStatus;
  emailVerified?: boolean;
  page?: number;
  limit?: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}

const createUserSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  firstName: z.string().optional(),
  lastName: z.string().optional(),
  username: z.string().min(3).optional(),
  role: z.nativeEnum(UserRole).optional(),
});

const updateUserSchema = z.object({
  firstName: z.string().optional(),
  lastName: z.string().optional(),
  username: z.string().min(3).optional(),
  avatar: z.string().url().optional(),
  status: z.nativeEnum(UserStatus).optional(),
  role: z.nativeEnum(UserRole).optional(),
});

export class UserService {
  async createUser(data: CreateUserDto): Promise<User> {
    const validated = createUserSchema.parse(data);
    
    // Check if user already exists
    const existingUser = await prisma.user.findFirst({
      where: {
        OR: [
          { email: validated.email.toLowerCase() },
          validated.username ? { username: validated.username } : {},
        ],
      },
    });

    if (existingUser) {
      throw new Error('User with this email or username already exists');
    }

    // Hash password
    const hashedPassword = await hashPassword(validated.password);

    // Create user
    const user = await prisma.user.create({
      data: {
        email: validated.email.toLowerCase(),
        password: hashedPassword,
        firstName: validated.firstName,
        lastName: validated.lastName,
        username: validated.username,
        role: validated.role || UserRole.USER,
        status: UserStatus.INACTIVE,
      },
    });

    // Send verification email
    if (process.env.NODE_ENV === 'production') {
      const token = await generateEmailVerificationToken(user.email);
      await sendEmail({
        to: user.email,
        subject: 'Verify your email address',
        template: 'email-verification',
        data: {
          name: user.firstName || user.email,
          verificationUrl: `${process.env.NEXT_PUBLIC_APP_URL}/verify-email?token=${token}`,
        },
      });
    }

    return user;
  }

  async updateUser(id: string, data: UpdateUserDto): Promise<User> {
    const validated = updateUserSchema.parse(data);

    // Check if username is taken
    if (validated.username) {
      const existingUser = await prisma.user.findFirst({
        where: {
          username: validated.username,
          NOT: { id },
        },
      });

      if (existingUser) {
        throw new Error('Username is already taken');
      }
    }

    return prisma.user.update({
      where: { id },
      data: validated,
    });
  }

  async deleteUser(id: string, hardDelete = false): Promise<void> {
    if (hardDelete) {
      await prisma.user.delete({
        where: { id },
      });
    } else {
      await prisma.user.update({
        where: { id },
        data: {
          status: UserStatus.DELETED,
          deletedAt: new Date(),
        },
      });
    }
  }

  async getUser(id: string): Promise<User | null> {
    return prisma.user.findUnique({
      where: { id },
    });
  }

  async getUserByEmail(email: string): Promise<User | null> {
    return prisma.user.findUnique({
      where: { email: email.toLowerCase() },
    });
  }

  async getUsers(filter: UserFilter): Promise<{
    users: User[];
    total: number;
    page: number;
    totalPages: number;
  }> {
    const page = filter.page || 1;
    const limit = filter.limit || 10;
    const skip = (page - 1) * limit;

    const where: Prisma.UserWhereInput = {};

    if (filter.search) {
      where.OR = [
        { email: { contains: filter.search, mode: 'insensitive' } },
        { firstName: { contains: filter.search, mode: 'insensitive' } },
        { lastName: { contains: filter.search, mode: 'insensitive' } },
        { username: { contains: filter.search, mode: 'insensitive' } },
      ];
    }

    if (filter.role) {
      where.role = filter.role;
    }

    if (filter.status) {
      where.status = filter.status;
    }

    if (filter.emailVerified !== undefined) {
      where.emailVerified = filter.emailVerified;
    }

    const [users, total] = await Promise.all([
      prisma.user.findMany({
        where,
        skip,
        take: limit,
        orderBy: {
          [filter.sortBy || 'createdAt']: filter.sortOrder || 'desc',
        },
      }),
      prisma.user.count({ where }),
    ]);

    return {
      users,
      total,
      page,
      totalPages: Math.ceil(total / limit),
    };
  }

  async verifyEmail(userId: string): Promise<void> {
    await prisma.user.update({
      where: { id: userId },
      data: {
        emailVerified: true,
        emailVerifiedAt: new Date(),
        status: UserStatus.ACTIVE,
      },
    });
  }

  async changePassword(userId: string, newPassword: string): Promise<void> {
    const hashedPassword = await hashPassword(newPassword);
    
    await prisma.user.update({
      where: { id: userId },
      data: { password: hashedPassword },
    });
  }

  async updateLastLogin(userId: string, ip: string): Promise<void> {
    await prisma.user.update({
      where: { id: userId },
      data: {
        lastLoginAt: new Date(),
        lastLoginIp: ip,
        failedLoginAttempts: 0,
        lockedUntil: null,
      },
    });
  }

  async incrementFailedLoginAttempts(userId: string): Promise<number> {
    const user = await prisma.user.update({
      where: { id: userId },
      data: {
        failedLoginAttempts: { increment: 1 },
      },
    });

    return user.failedLoginAttempts;
  }

  async lockAccount(userId: string, minutes: number): Promise<void> {
    await prisma.user.update({
      where: { id: userId },
      data: {
        lockedUntil: new Date(Date.now() + minutes * 60 * 1000),
        failedLoginAttempts: 0,
      },
    });
  }

  async getUserStats(): Promise<{
    total: number;
    active: number;
    inactive: number;
    suspended: number;
    byRole: Record<string, number>;
  }> {
    const [total, active, inactive, suspended, byRole] = await Promise.all([
      prisma.user.count(),
      prisma.user.count({ where: { status: UserStatus.ACTIVE } }),
      prisma.user.count({ where: { status: UserStatus.INACTIVE } }),
      prisma.user.count({ where: { status: UserStatus.SUSPENDED } }),
      prisma.user.groupBy({
        by: ['role'],
        _count: true,
      }),
    ]);

    return {
      total,
      active,
      inactive,
      suspended,
      byRole: byRole.reduce((acc, item) => {
        acc[item.role] = item._count;
        return acc;
      }, {} as Record<string, number>),
    };
  }
}

export const userService = new UserService();