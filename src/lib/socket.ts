import { Server as HTTPServer } from 'http';
import { Server as SocketServer, Socket } from 'socket.io';
import { verifyToken } from '@/lib/auth/jwt';
import { logger } from '@/lib/logger';

export interface SocketUser {
  id: string;
  email: string;
  role: string;
  sessionId?: string;
}

export interface SocketData {
  user?: SocketUser;
  roomId?: string;
  agentId?: string;
  conversationId?: string;
}

export class WebSocketManager {
  private io: SocketServer | null = null;
  private userSockets: Map<string, Set<string>> = new Map(); // userId -> socketIds
  private socketUsers: Map<string, SocketUser> = new Map(); // socketId -> user

  initialize(server: HTTPServer): SocketServer {
    this.io = new SocketServer(server, {
      cors: {
        origin: process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000',
        credentials: true,
      },
      transports: ['websocket', 'polling'],
      pingTimeout: 60000,
      pingInterval: 25000,
    });

    this.setupMiddleware();
    this.setupEventHandlers();

    logger.info('WebSocket server initialized');
    return this.io;
  }

  private setupMiddleware(): void {
    if (!this.io) return;

    this.io.use(async (socket: Socket, next) => {
      try {
        const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.split(' ')[1];
        
        if (!token) {
          return next(new Error('Authentication required'));
        }

        const payload = await verifyToken(token);
        
        if (!payload) {
          return next(new Error('Invalid token'));
        }

        const user: SocketUser = {
          id: payload.userId,
          email: payload.email,
          role: payload.role,
          sessionId: payload.sessionId,
        };

        (socket.data as SocketData).user = user;
        next();
      } catch (error) {
        logger.error('Socket authentication error', error);
        next(new Error('Authentication failed'));
      }
    });
  }

  private setupEventHandlers(): void {
    if (!this.io) return;

    this.io.on('connection', (socket: Socket) => {
      const user = (socket.data as SocketData).user;
      
      if (!user) {
        socket.disconnect();
        return;
      }

      logger.info(`User connected: ${user.email}`, { userId: user.id, socketId: socket.id });

      // Track user socket
      this.addUserSocket(user.id, socket.id);
      this.socketUsers.set(socket.id, user);

      // Join user-specific room
      socket.join(`user:${user.id}`);

      // Handle joining conversation room
      socket.on('join:conversation', async (conversationId: string) => {
        try {
          // Verify user has access to this conversation
          const hasAccess = await this.verifyConversationAccess(user.id, conversationId);
          
          if (!hasAccess) {
            socket.emit('error', { message: 'Access denied to conversation' });
            return;
          }

          socket.join(`conversation:${conversationId}`);
          (socket.data as SocketData).conversationId = conversationId;
          
          socket.emit('joined:conversation', { conversationId });
          
          // Notify others in the conversation
          socket.to(`conversation:${conversationId}`).emit('user:joined', {
            userId: user.id,
            email: user.email,
          });
        } catch (error) {
          logger.error('Error joining conversation', error, { userId: user.id, conversationId });
          socket.emit('error', { message: 'Failed to join conversation' });
        }
      });

      // Handle leaving conversation room
      socket.on('leave:conversation', (conversationId: string) => {
        socket.leave(`conversation:${conversationId}`);
        (socket.data as SocketData).conversationId = undefined;
        
        socket.to(`conversation:${conversationId}`).emit('user:left', {
          userId: user.id,
          email: user.email,
        });
      });

      // Handle joining agent room (for agent-specific updates)
      socket.on('join:agent', async (agentId: string) => {
        try {
          const hasAccess = await this.verifyAgentAccess(user.id, agentId);
          
          if (!hasAccess) {
            socket.emit('error', { message: 'Access denied to agent' });
            return;
          }

          socket.join(`agent:${agentId}`);
          (socket.data as SocketData).agentId = agentId;
          
          socket.emit('joined:agent', { agentId });
        } catch (error) {
          logger.error('Error joining agent room', error, { userId: user.id, agentId });
          socket.emit('error', { message: 'Failed to join agent room' });
        }
      });

      // Handle sending message
      socket.on('message:send', async (data: {
        conversationId: string;
        content: string;
        type?: 'text' | 'audio';
      }) => {
        try {
          const { conversationId, content, type = 'text' } = data;
          
          // Verify access
          const hasAccess = await this.verifyConversationAccess(user.id, conversationId);
          if (!hasAccess) {
            socket.emit('error', { message: 'Access denied' });
            return;
          }

          // Process and save message (implement your logic here)
          const message = {
            id: crypto.randomUUID(),
            conversationId,
            userId: user.id,
            content,
            type,
            timestamp: new Date().toISOString(),
          };

          // Broadcast to conversation participants
          this.io?.to(`conversation:${conversationId}`).emit('message:received', message);
        } catch (error) {
          logger.error('Error sending message', error, { userId: user.id });
          socket.emit('error', { message: 'Failed to send message' });
        }
      });

      // Handle typing indicators
      socket.on('typing:start', (conversationId: string) => {
        socket.to(`conversation:${conversationId}`).emit('typing:user', {
          userId: user.id,
          email: user.email,
        });
      });

      socket.on('typing:stop', (conversationId: string) => {
        socket.to(`conversation:${conversationId}`).emit('typing:stopped', {
          userId: user.id,
        });
      });

      // Handle voice streaming
      socket.on('voice:stream', (data: {
        conversationId: string;
        chunk: ArrayBuffer;
      }) => {
        socket.to(`conversation:${data.conversationId}`).emit('voice:chunk', {
          userId: user.id,
          chunk: data.chunk,
        });
      });

      // Handle disconnection
      socket.on('disconnect', (reason) => {
        logger.info(`User disconnected: ${user.email}`, { userId: user.id, socketId: socket.id, reason });
        
        // Clean up tracking
        this.removeUserSocket(user.id, socket.id);
        this.socketUsers.delete(socket.id);
        
        // Notify conversation participants
        const conversationId = (socket.data as SocketData).conversationId;
        if (conversationId) {
          socket.to(`conversation:${conversationId}`).emit('user:left', {
            userId: user.id,
            email: user.email,
          });
        }
      });

      // Handle errors
      socket.on('error', (error) => {
        logger.error('Socket error', error, { userId: user.id, socketId: socket.id });
      });
    });
  }

  private addUserSocket(userId: string, socketId: string): void {
    const sockets = this.userSockets.get(userId) || new Set();
    sockets.add(socketId);
    this.userSockets.set(userId, sockets);
  }

  private removeUserSocket(userId: string, socketId: string): void {
    const sockets = this.userSockets.get(userId);
    if (sockets) {
      sockets.delete(socketId);
      if (sockets.size === 0) {
        this.userSockets.delete(userId);
      }
    }
  }

  // Public methods for emitting events
  emitToUser(userId: string, event: string, data: any): void {
    this.io?.to(`user:${userId}`).emit(event, data);
  }

  emitToConversation(conversationId: string, event: string, data: any): void {
    this.io?.to(`conversation:${conversationId}`).emit(event, data);
  }

  emitToAgent(agentId: string, event: string, data: any): void {
    this.io?.to(`agent:${agentId}`).emit(event, data);
  }

  broadcast(event: string, data: any): void {
    this.io?.emit(event, data);
  }

  // Get online users
  getOnlineUsers(): string[] {
    return Array.from(this.userSockets.keys());
  }

  // Get user's active sockets
  getUserSockets(userId: string): string[] {
    const sockets = this.userSockets.get(userId);
    return sockets ? Array.from(sockets) : [];
  }

  // Check if user is online
  isUserOnline(userId: string): boolean {
    return this.userSockets.has(userId);
  }

  // Disconnect user
  disconnectUser(userId: string): void {
    const sockets = this.userSockets.get(userId);
    if (sockets) {
      sockets.forEach((socketId) => {
        this.io?.sockets.sockets.get(socketId)?.disconnect(true);
      });
    }
  }

  // Access verification methods (implement based on your business logic)
  private async verifyConversationAccess(userId: string, conversationId: string): Promise<boolean> {
    // Implement your access control logic here
    // For now, return true for demonstration
    return true;
  }

  private async verifyAgentAccess(userId: string, agentId: string): Promise<boolean> {
    // Implement your access control logic here
    // For now, return true for demonstration
    return true;
  }
}

// Singleton instance
export const socketManager = new WebSocketManager();

// Socket event types for TypeScript
export enum SocketEvents {
  // Connection events
  CONNECTION = 'connection',
  DISCONNECT = 'disconnect',
  ERROR = 'error',
  
  // Room events
  JOIN_CONVERSATION = 'join:conversation',
  LEAVE_CONVERSATION = 'leave:conversation',
  JOIN_AGENT = 'join:agent',
  JOINED_CONVERSATION = 'joined:conversation',
  JOINED_AGENT = 'joined:agent',
  
  // Message events
  MESSAGE_SEND = 'message:send',
  MESSAGE_RECEIVED = 'message:received',
  
  // Typing events
  TYPING_START = 'typing:start',
  TYPING_STOP = 'typing:stop',
  TYPING_USER = 'typing:user',
  TYPING_STOPPED = 'typing:stopped',
  
  // Voice events
  VOICE_STREAM = 'voice:stream',
  VOICE_CHUNK = 'voice:chunk',
  
  // User events
  USER_JOINED = 'user:joined',
  USER_LEFT = 'user:left',
  USER_STATUS = 'user:status',
  
  // Agent events
  AGENT_STATUS = 'agent:status',
  AGENT_RESPONSE = 'agent:response',
  
  // System events
  NOTIFICATION = 'notification',
  UPDATE = 'update',
}