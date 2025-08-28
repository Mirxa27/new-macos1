import { NextRequest, NextResponse } from 'next/server';
import { verifyToken, extractTokenFromHeader } from '@/lib/auth/jwt';
import { prisma } from '@/lib/prisma';
import { UserRole } from '@prisma/client';

export interface AuthenticatedRequest extends NextRequest {
  user?: {
    id: string;
    email: string;
    role: UserRole;
    sessionId?: string;
  };
}

export async function authenticate(
  req: NextRequest,
  requiredRoles?: UserRole[]
): Promise<{ authenticated: boolean; user?: any; error?: string }> {
  try {
    const token = extractTokenFromHeader(req.headers.get('authorization'));
    
    if (!token) {
      return { authenticated: false, error: 'No token provided' };
    }

    const payload = await verifyToken(token);
    
    if (!payload) {
      return { authenticated: false, error: 'Invalid token' };
    }

    // Check if session is still valid
    if (payload.sessionId) {
      const session = await prisma.session.findUnique({
        where: { id: payload.sessionId },
        include: { user: true },
      });

      if (!session || session.expiresAt < new Date()) {
        return { authenticated: false, error: 'Session expired' };
      }

      // Update last activity
      await prisma.session.update({
        where: { id: payload.sessionId },
        data: { lastActivity: new Date() },
      });
    }

    // Check role permissions
    if (requiredRoles && requiredRoles.length > 0) {
      if (!requiredRoles.includes(payload.role)) {
        return { authenticated: false, error: 'Insufficient permissions' };
      }
    }

    const user = {
      id: payload.userId,
      email: payload.email,
      role: payload.role,
      sessionId: payload.sessionId,
    };

    return { authenticated: true, user };
  } catch (error) {
    console.error('Authentication error:', error);
    return { authenticated: false, error: 'Authentication failed' };
  }
}

export function withAuth(
  handler: (req: AuthenticatedRequest) => Promise<NextResponse>,
  requiredRoles?: UserRole[]
) {
  return async (req: NextRequest): Promise<NextResponse> => {
    const { authenticated, user, error } = await authenticate(req, requiredRoles);

    if (!authenticated) {
      return NextResponse.json(
        { error: error || 'Unauthorized' },
        { status: 401 }
      );
    }

    (req as AuthenticatedRequest).user = user;
    return handler(req as AuthenticatedRequest);
  };
}

export function requireRole(...roles: UserRole[]) {
  return (handler: (req: AuthenticatedRequest) => Promise<NextResponse>) => {
    return withAuth(handler, roles);
  };
}

export function requireSuperAdmin() {
  return requireRole(UserRole.SUPER_ADMIN);
}

export function requireAdmin() {
  return requireRole(UserRole.SUPER_ADMIN, UserRole.ADMIN);
}

export function requireManager() {
  return requireRole(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.MANAGER);
}