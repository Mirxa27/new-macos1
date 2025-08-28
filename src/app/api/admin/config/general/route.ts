import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdmin } from '@/middleware/auth';
import { prisma } from '@/lib/prisma';

const configSchema = z.object({
  appName: z.string().min(1),
  appUrl: z.string().url(),
  appDescription: z.string().optional(),
  maintenanceMode: z.boolean(),
  maintenanceMessage: z.string().optional(),
  allowRegistration: z.boolean(),
  requireEmailVerification: z.boolean(),
  defaultLanguage: z.string(),
  timezone: z.string(),
  dateFormat: z.string(),
  timeFormat: z.string(),
  logoUrl: z.string().url().optional().or(z.literal('')),
  faviconUrl: z.string().url().optional().or(z.literal('')),
  primaryColor: z.string(),
  googleAnalyticsId: z.string().optional(),
  metaDescription: z.string().optional(),
  metaKeywords: z.string().optional(),
});

export const GET = requireAdmin()(async (req: NextRequest) => {
  try {
    // Fetch all general configuration items
    const configs = await prisma.systemConfig.findMany({
      where: {
        category: 'general',
      },
    });

    // Transform to key-value object
    const configMap: any = {
      appName: 'Voice Agent Platform',
      appUrl: process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000',
      appDescription: 'Enterprise-grade voice AI agent platform',
      maintenanceMode: false,
      maintenanceMessage: 'We are currently performing maintenance. Please check back later.',
      allowRegistration: true,
      requireEmailVerification: true,
      defaultLanguage: 'en',
      timezone: 'UTC',
      dateFormat: 'MM/DD/YYYY',
      timeFormat: '12h',
      logoUrl: '',
      faviconUrl: '',
      primaryColor: '#0ea5e9',
      googleAnalyticsId: '',
      metaDescription: '',
      metaKeywords: '',
    };

    configs.forEach((config) => {
      const key = config.key.replace('app.', '').replace('auth.', '');
      try {
        configMap[key] = JSON.parse(config.value as string);
      } catch {
        configMap[key] = config.value;
      }
    });

    return NextResponse.json(configMap);
  } catch (error) {
    console.error('Error fetching configuration:', error);
    return NextResponse.json(
      { error: 'Failed to fetch configuration' },
      { status: 500 }
    );
  }
});

export const PUT = requireAdmin()(async (req: NextRequest) => {
  try {
    const body = await req.json();
    const data = configSchema.parse(body);

    // Map configuration to database keys
    const configMappings = [
      { key: 'app.name', value: data.appName, category: 'general' },
      { key: 'app.url', value: data.appUrl, category: 'general' },
      { key: 'app.description', value: data.appDescription || '', category: 'general' },
      { key: 'app.maintenance_mode', value: data.maintenanceMode, category: 'general' },
      { key: 'app.maintenance_message', value: data.maintenanceMessage || '', category: 'general' },
      { key: 'auth.allow_registration', value: data.allowRegistration, category: 'authentication' },
      { key: 'auth.require_email_verification', value: data.requireEmailVerification, category: 'authentication' },
      { key: 'app.default_language', value: data.defaultLanguage, category: 'general' },
      { key: 'app.timezone', value: data.timezone, category: 'general' },
      { key: 'app.date_format', value: data.dateFormat, category: 'general' },
      { key: 'app.time_format', value: data.timeFormat, category: 'general' },
      { key: 'app.logo_url', value: data.logoUrl || '', category: 'general' },
      { key: 'app.favicon_url', value: data.faviconUrl || '', category: 'general' },
      { key: 'app.primary_color', value: data.primaryColor, category: 'general' },
      { key: 'analytics.google_analytics_id', value: data.googleAnalyticsId || '', category: 'analytics' },
      { key: 'app.meta_description', value: data.metaDescription || '', category: 'general' },
      { key: 'app.meta_keywords', value: data.metaKeywords || '', category: 'general' },
    ];

    // Update configurations in database
    for (const config of configMappings) {
      await prisma.systemConfig.upsert({
        where: { key: config.key },
        update: {
          value: JSON.stringify(config.value),
          updatedAt: new Date(),
        },
        create: {
          key: config.key,
          value: JSON.stringify(config.value),
          category: config.category,
          description: `${config.key} configuration`,
          isEditable: true,
        },
      });
    }

    // Create audit log
    const user = (req as any).user;
    await prisma.auditLog.create({
      data: {
        userId: user.id,
        action: 'UPDATE_CONFIG',
        entity: 'SystemConfig',
        entityId: 'general',
        newValue: data,
        metadata: {
          category: 'general',
        },
        ipAddress: req.headers.get('x-forwarded-for') || req.headers.get('x-real-ip') || 'unknown',
        userAgent: req.headers.get('user-agent') || 'unknown',
      },
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { error: 'Invalid configuration data', details: error.errors },
        { status: 400 }
      );
    }

    console.error('Error updating configuration:', error);
    return NextResponse.json(
      { error: 'Failed to update configuration' },
      { status: 500 }
    );
  }
});