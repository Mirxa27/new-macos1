import { NextRequest, NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { authOptions, requireRole } from '@/lib/auth';
import { prisma } from '@/lib/db';

export async function GET(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions);
    
    if (!session?.user?.id) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    requireRole(session.user.role, 'admin');

    const { searchParams } = new URL(request.url);
    const page = parseInt(searchParams.get('page') || '1');
    const pageSize = parseInt(searchParams.get('pageSize') || '20');
    const status = searchParams.get('status') || '';
    const userId = searchParams.get('userId') || '';

    const skip = (page - 1) * pageSize;

    const where: any = {};
    
    if (status && status !== 'all') {
      where.sessionStatus = status.toUpperCase();
    }

    if (userId) {
      where.userId = userId;
    }

    const [sessions, total] = await Promise.all([
      prisma.voiceSession.findMany({
        where,
        include: {
          user: {
            select: {
              id: true,
              fullName: true,
              email: true,
            },
          },
          aiProvider: {
            select: {
              id: true,
              name: true,
              providerType: true,
            },
          },
          aiModel: {
            select: {
              id: true,
              modelName: true,
              displayName: true,
            },
          },
          voiceCommands: {
            select: {
              id: true,
              commandText: true,
              aiResponse: true,
              executionStatus: true,
              createdAt: true,
            },
            orderBy: { createdAt: 'desc' },
            take: 5,
          },
          _count: {
            select: {
              voiceCommands: true,
            },
          },
        },
        orderBy: { startedAt: 'desc' },
        skip,
        take: pageSize,
      }),
      prisma.voiceSession.count({ where }),
    ]);

    // Format the response
    const formattedSessions = sessions.map(session => ({
      ...session,
      sessionStatus: session.sessionStatus.toLowerCase(),
      aiProvider: session.aiProvider ? {
        ...session.aiProvider,
        providerType: session.aiProvider.providerType.toLowerCase(),
      } : null,
      voiceCommands: session.voiceCommands.map(cmd => ({
        ...cmd,
        executionStatus: cmd.executionStatus.toLowerCase(),
      })),
    }));

    return NextResponse.json({
      success: true,
      sessions: formattedSessions,
      pagination: {
        page,
        pageSize,
        total,
        totalPages: Math.ceil(total / pageSize),
      },
    });

  } catch (error) {
    console.error('Error fetching sessions:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
