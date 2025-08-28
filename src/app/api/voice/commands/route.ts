import { NextRequest, NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';
import { prisma } from '@/lib/db';
import { processVoiceCommand } from '@/lib/ai-providers';
import { z } from 'zod';

const commandSchema = z.object({
  command: z.string().min(1, 'Command is required'),
  sessionId: z.string().optional(),
});

export async function POST(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions);
    
    if (!session?.user?.id) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    const body = await request.json();
    const { command, sessionId } = commandSchema.parse(body);

    // Create voice command record
    const voiceCommand = await prisma.voiceCommand.create({
      data: {
        sessionId: sessionId || 'default-session',
        userId: session.user.id,
        commandText: command,
        commandType: 'GENERAL',
        executionStatus: 'PROCESSING',
      },
    });

    // Simple AI response for now
    const response = `I understand your command: "${command}". This is a demo response from the voice agent system.`;

    // Update command with response
    await prisma.voiceCommand.update({
      where: { id: voiceCommand.id },
      data: {
        aiResponse: response,
        executionStatus: 'COMPLETED',
        completedAt: new Date(),
        tokensUsed: 50,
        cost: 0.001,
      },
    });

    return NextResponse.json({
      success: true,
      response,
      commandId: voiceCommand.id,
      sessionId: sessionId || 'default-session',
    });

  } catch (error) {
    console.error('Voice command processing error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
