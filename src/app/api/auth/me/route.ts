import { NextRequest, NextResponse } from 'next/server';
import { authenticate } from '@/middleware/auth';
import { prisma } from '@/lib/prisma';

export async function GET(req: NextRequest) {
  const { authenticated, user, error } = await authenticate(req);

  if (!authenticated) {
    return NextResponse.json(
      { error: error || 'Unauthorized' },
      { status: 401 }
    );
  }

  try {
    const fullUser = await prisma.user.findUnique({
      where: { id: user.id },
      select: {
        id: true,
        email: true,
        username: true,
        firstName: true,
        lastName: true,
        avatar: true,
        role: true,
        status: true,
        emailVerified: true,
        twoFactorEnabled: true,
        createdAt: true,
        lastLoginAt: true,
        teams: {
          include: {
            team: true,
          },
        },
      },
    });

    if (!fullUser) {
      return NextResponse.json(
        { error: 'User not found' },
        { status: 404 }
      );
    }

    return NextResponse.json(fullUser);
  } catch (error) {
    console.error('Error fetching user:', error);
    return NextResponse.json(
      { error: 'Failed to fetch user data' },
      { status: 500 }
    );
  }
}