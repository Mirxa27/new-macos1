import { SignJWT, jwtVerify, type JWTPayload } from 'jose';
import { User, UserRole } from '@prisma/client';

interface TokenPayload extends JWTPayload {
  userId: string;
  email: string;
  role: UserRole;
  sessionId?: string;
}

const secret = new TextEncoder().encode(
  process.env.JWT_SECRET || 'your-secret-key-change-in-production'
);

const alg = 'HS256';

export async function signToken(payload: Omit<TokenPayload, 'iat' | 'exp'>): Promise<string> {
  const token = await new SignJWT(payload)
    .setProtectedHeader({ alg })
    .setIssuedAt()
    .setExpirationTime('24h')
    .sign(secret);
  
  return token;
}

export async function verifyToken(token: string): Promise<TokenPayload | null> {
  try {
    const { payload } = await jwtVerify(token, secret);
    return payload as TokenPayload;
  } catch (error) {
    console.error('JWT verification failed:', error);
    return null;
  }
}

export async function generateAccessToken(user: Pick<User, 'id' | 'email' | 'role'>, sessionId?: string): Promise<string> {
  return signToken({
    userId: user.id,
    email: user.email,
    role: user.role,
    sessionId,
  });
}

export async function generateRefreshToken(userId: string): Promise<string> {
  const token = await new SignJWT({ userId, type: 'refresh' })
    .setProtectedHeader({ alg })
    .setIssuedAt()
    .setExpirationTime('30d')
    .sign(secret);
  
  return token;
}

export async function generatePasswordResetToken(email: string): Promise<string> {
  const token = await new SignJWT({ email, type: 'password-reset' })
    .setProtectedHeader({ alg })
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(secret);
  
  return token;
}

export async function generateEmailVerificationToken(email: string): Promise<string> {
  const token = await new SignJWT({ email, type: 'email-verification' })
    .setProtectedHeader({ alg })
    .setIssuedAt()
    .setExpirationTime('24h')
    .sign(secret);
  
  return token;
}

export async function generate2FAToken(userId: string): Promise<string> {
  const token = await new SignJWT({ userId, type: '2fa' })
    .setProtectedHeader({ alg })
    .setIssuedAt()
    .setExpirationTime('5m')
    .sign(secret);
  
  return token;
}

export function extractTokenFromHeader(authHeader?: string): string | null {
  if (!authHeader) return null;
  
  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') return null;
  
  return parts[1];
}