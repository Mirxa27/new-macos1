'use client';

import { useEffect, useState } from 'react';
import { zodResolver } from '@hookform/resolvers/zod';
import { useForm } from 'react-hook-form';
import * as z from 'zod';
import { Save, RefreshCw, Globe, Shield, Info } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { toast } from 'sonner';

const configSchema = z.object({
  appName: z.string().min(1, 'Application name is required'),
  appUrl: z.string().url('Must be a valid URL'),
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

type ConfigFormData = z.infer<typeof configSchema>;

export default function GeneralConfigPage() {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const {
    register,
    handleSubmit,
    reset,
    watch,
    formState: { errors, isDirty },
  } = useForm<ConfigFormData>({
    resolver: zodResolver(configSchema),
    defaultValues: {
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
    },
  });

  const maintenanceMode = watch('maintenanceMode');

  useEffect(() => {
    fetchConfig();
  }, []);

  const fetchConfig = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/admin/config/general', {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch configuration');
      }

      const data = await response.json();
      reset(data);
    } catch (error) {
      console.error('Error fetching configuration:', error);
      toast.error('Failed to load configuration');
    } finally {
      setLoading(false);
    }
  };

  const onSubmit = async (data: ConfigFormData) => {
    setSaving(true);
    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/admin/config/general', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(data),
      });

      if (!response.ok) {
        throw new Error('Failed to save configuration');
      }

      toast.success('Configuration saved successfully');
      reset(data);
    } catch (error) {
      console.error('Error saving configuration:', error);
      toast.error('Failed to save configuration');
    } finally {
      setSaving(false);
    }
  };

  const handleReset = () => {
    fetchConfig();
    toast.info('Configuration reset to saved values');
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  return (
    <div className="p-4 sm:p-6 lg:p-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2">General Configuration</h1>
        <p className="text-muted-foreground">
          Configure general application settings and preferences
        </p>
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
        {/* Application Settings */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <Globe className="h-5 w-5 mr-2" />
              Application Settings
            </CardTitle>
            <CardDescription>
              Basic application configuration and branding
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <label htmlFor="appName" className="text-sm font-medium">
                  Application Name
                </label>
                <input
                  {...register('appName')}
                  type="text"
                  id="appName"
                  className="input-mobile"
                />
                {errors.appName && (
                  <p className="text-sm text-destructive">{errors.appName.message}</p>
                )}
              </div>

              <div className="space-y-2">
                <label htmlFor="appUrl" className="text-sm font-medium">
                  Application URL
                </label>
                <input
                  {...register('appUrl')}
                  type="url"
                  id="appUrl"
                  className="input-mobile"
                />
                {errors.appUrl && (
                  <p className="text-sm text-destructive">{errors.appUrl.message}</p>
                )}
              </div>
            </div>

            <div className="space-y-2">
              <label htmlFor="appDescription" className="text-sm font-medium">
                Application Description
              </label>
              <textarea
                {...register('appDescription')}
                id="appDescription"
                rows={3}
                className="input-mobile min-h-[80px]"
              />
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <label htmlFor="logoUrl" className="text-sm font-medium">
                  Logo URL
                </label>
                <input
                  {...register('logoUrl')}
                  type="url"
                  id="logoUrl"
                  placeholder="https://example.com/logo.png"
                  className="input-mobile"
                />
              </div>

              <div className="space-y-2">
                <label htmlFor="faviconUrl" className="text-sm font-medium">
                  Favicon URL
                </label>
                <input
                  {...register('faviconUrl')}
                  type="url"
                  id="faviconUrl"
                  placeholder="https://example.com/favicon.ico"
                  className="input-mobile"
                />
              </div>
            </div>

            <div className="space-y-2">
              <label htmlFor="primaryColor" className="text-sm font-medium">
                Primary Color
              </label>
              <div className="flex items-center space-x-2">
                <input
                  {...register('primaryColor')}
                  type="color"
                  id="primaryColor"
                  className="h-10 w-20"
                />
                <input
                  {...register('primaryColor')}
                  type="text"
                  placeholder="#0ea5e9"
                  className="input-mobile flex-1"
                />
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Maintenance Mode */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center">
              <Shield className="h-5 w-5 mr-2" />
              Maintenance Mode
            </CardTitle>
            <CardDescription>
              Enable maintenance mode to prevent user access
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center space-x-2">
              <input
                {...register('maintenanceMode')}
                type="checkbox"
                id="maintenanceMode"
                className="h-4 w-4 rounded border-input"
              />
              <label htmlFor="maintenanceMode" className="text-sm font-medium">
                Enable Maintenance Mode
              </label>
            </div>

            {maintenanceMode && (
              <div className="space-y-2">
                <label htmlFor="maintenanceMessage" className="text-sm font-medium">
                  Maintenance Message
                </label>
                <textarea
                  {...register('maintenanceMessage')}
                  id="maintenanceMessage"
                  rows={3}
                  className="input-mobile min-h-[80px]"
                  placeholder="Enter the message to display during maintenance"
                />
              </div>
            )}

            <div className="rounded-lg bg-muted p-4">
              <div className="flex items-start space-x-2">
                <Info className="h-4 w-4 text-muted-foreground mt-0.5" />
                <div className="text-sm text-muted-foreground">
                  When maintenance mode is enabled, only administrators can access the application.
                  All other users will see the maintenance message.
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Registration & Authentication */}
        <Card>
          <CardHeader>
            <CardTitle>Registration & Authentication</CardTitle>
            <CardDescription>
              Configure user registration and authentication settings
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-3">
              <div className="flex items-center space-x-2">
                <input
                  {...register('allowRegistration')}
                  type="checkbox"
                  id="allowRegistration"
                  className="h-4 w-4 rounded border-input"
                />
                <label htmlFor="allowRegistration" className="text-sm font-medium">
                  Allow New User Registration
                </label>
              </div>

              <div className="flex items-center space-x-2">
                <input
                  {...register('requireEmailVerification')}
                  type="checkbox"
                  id="requireEmailVerification"
                  className="h-4 w-4 rounded border-input"
                />
                <label htmlFor="requireEmailVerification" className="text-sm font-medium">
                  Require Email Verification
                </label>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Localization */}
        <Card>
          <CardHeader>
            <CardTitle>Localization</CardTitle>
            <CardDescription>
              Configure language and regional settings
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <label htmlFor="defaultLanguage" className="text-sm font-medium">
                  Default Language
                </label>
                <select
                  {...register('defaultLanguage')}
                  id="defaultLanguage"
                  className="input-mobile"
                >
                  <option value="en">English</option>
                  <option value="es">Spanish</option>
                  <option value="fr">French</option>
                  <option value="de">German</option>
                  <option value="ja">Japanese</option>
                  <option value="zh">Chinese</option>
                </select>
              </div>

              <div className="space-y-2">
                <label htmlFor="timezone" className="text-sm font-medium">
                  Default Timezone
                </label>
                <select
                  {...register('timezone')}
                  id="timezone"
                  className="input-mobile"
                >
                  <option value="UTC">UTC</option>
                  <option value="America/New_York">Eastern Time</option>
                  <option value="America/Chicago">Central Time</option>
                  <option value="America/Denver">Mountain Time</option>
                  <option value="America/Los_Angeles">Pacific Time</option>
                  <option value="Europe/London">London</option>
                  <option value="Europe/Paris">Paris</option>
                  <option value="Asia/Tokyo">Tokyo</option>
                </select>
              </div>

              <div className="space-y-2">
                <label htmlFor="dateFormat" className="text-sm font-medium">
                  Date Format
                </label>
                <select
                  {...register('dateFormat')}
                  id="dateFormat"
                  className="input-mobile"
                >
                  <option value="MM/DD/YYYY">MM/DD/YYYY</option>
                  <option value="DD/MM/YYYY">DD/MM/YYYY</option>
                  <option value="YYYY-MM-DD">YYYY-MM-DD</option>
                </select>
              </div>

              <div className="space-y-2">
                <label htmlFor="timeFormat" className="text-sm font-medium">
                  Time Format
                </label>
                <select
                  {...register('timeFormat')}
                  id="timeFormat"
                  className="input-mobile"
                >
                  <option value="12h">12-hour (AM/PM)</option>
                  <option value="24h">24-hour</option>
                </select>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* SEO Settings */}
        <Card>
          <CardHeader>
            <CardTitle>SEO Settings</CardTitle>
            <CardDescription>
              Search engine optimization and analytics
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <label htmlFor="googleAnalyticsId" className="text-sm font-medium">
                Google Analytics ID
              </label>
              <input
                {...register('googleAnalyticsId')}
                type="text"
                id="googleAnalyticsId"
                placeholder="G-XXXXXXXXXX"
                className="input-mobile"
              />
            </div>

            <div className="space-y-2">
              <label htmlFor="metaDescription" className="text-sm font-medium">
                Meta Description
              </label>
              <textarea
                {...register('metaDescription')}
                id="metaDescription"
                rows={3}
                className="input-mobile min-h-[80px]"
                placeholder="Default meta description for SEO"
              />
            </div>

            <div className="space-y-2">
              <label htmlFor="metaKeywords" className="text-sm font-medium">
                Meta Keywords
              </label>
              <input
                {...register('metaKeywords')}
                type="text"
                id="metaKeywords"
                placeholder="voice ai, conversational ai, voice agent"
                className="input-mobile"
              />
            </div>
          </CardContent>
        </Card>

        {/* Action Buttons */}
        <div className="flex flex-col sm:flex-row gap-3 sticky bottom-4 bg-background/95 backdrop-blur-md p-4 rounded-lg border">
          <Button
            type="submit"
            disabled={saving || !isDirty}
            className="flex-1 sm:flex-none"
          >
            {saving ? (
              <>
                <RefreshCw className="mr-2 h-4 w-4 animate-spin" />
                Saving...
              </>
            ) : (
              <>
                <Save className="mr-2 h-4 w-4" />
                Save Changes
              </>
            )}
          </Button>
          <Button
            type="button"
            variant="outline"
            onClick={handleReset}
            disabled={saving || !isDirty}
            className="flex-1 sm:flex-none"
          >
            <RefreshCw className="mr-2 h-4 w-4" />
            Reset
          </Button>
        </div>
      </form>
    </div>
  );
}