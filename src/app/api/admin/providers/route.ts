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

    const providers = await prisma.aiProvider.findMany({
      include: {
        models: {
          where: { isEnabled: true },
          orderBy: { modelName: 'asc' },
        },
        _count: {
          select: {
            apiUsageLogs: true,
            voiceSessions: true,
          },
        },
      },
      orderBy: { name: 'asc' },
    });

    // Format the response
    const formattedProviders = providers.map(provider => ({
      ...provider,
      providerType: provider.providerType.toLowerCase(),
      // Don't expose the actual API key, just indicate if it's set
      apiKeyEncrypted: provider.apiKeyEncrypted ? '••••••••' : '',
      hasApiKey: !!provider.apiKeyEncrypted,
    }));

    return NextResponse.json({
      success: true,
      providers: formattedProviders,
    });

  } catch (error) {
    console.error('Error fetching providers:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions);
    
    if (!session?.user?.id) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    requireRole(session.user.role, 'super_admin');

    const body = await request.json();
    
    const provider = await prisma.aiProvider.create({
      data: {
        ...body,
        providerType: body.providerType.toUpperCase(),
        createdBy: session.user.id,
      },
      include: {
        models: true,
      },
    });

    return NextResponse.json({
      success: true,
      provider: {
        ...provider,
        providerType: provider.providerType.toLowerCase(),
      },
    });

  } catch (error) {
    console.error('Error creating provider:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
