import { z } from 'zod';

export interface EmailOptions {
  to: string | string[];
  subject: string;
  template?: string;
  html?: string;
  text?: string;
  data?: Record<string, any>;
  from?: string;
  replyTo?: string;
  cc?: string | string[];
  bcc?: string | string[];
  attachments?: Array<{
    filename: string;
    content: string | Buffer;
    contentType?: string;
  }>;
}

const emailSchema = z.object({
  to: z.union([z.string().email(), z.array(z.string().email())]),
  subject: z.string().min(1),
  template: z.string().optional(),
  html: z.string().optional(),
  text: z.string().optional(),
  data: z.record(z.any()).optional(),
  from: z.string().email().optional(),
  replyTo: z.string().email().optional(),
  cc: z.union([z.string().email(), z.array(z.string().email())]).optional(),
  bcc: z.union([z.string().email(), z.array(z.string().email())]).optional(),
});

export class EmailService {
  private provider: string;
  private fromEmail: string;
  private fromName: string;

  constructor() {
    this.provider = process.env.EMAIL_PROVIDER || 'sendgrid';
    this.fromEmail = process.env.SENDGRID_FROM_EMAIL || 'noreply@voiceagent.com';
    this.fromName = process.env.SENDGRID_FROM_NAME || 'Voice Agent Platform';
  }

  async sendEmail(options: EmailOptions): Promise<boolean> {
    try {
      const validated = emailSchema.parse(options);

      // Prepare email data
      const emailData = {
        to: Array.isArray(validated.to) ? validated.to : [validated.to],
        from: validated.from || `${this.fromName} <${this.fromEmail}>`,
        subject: validated.subject,
        html: validated.html || this.renderTemplate(validated.template, validated.data),
        text: validated.text || this.htmlToText(validated.html || ''),
        replyTo: validated.replyTo,
        cc: validated.cc ? (Array.isArray(validated.cc) ? validated.cc : [validated.cc]) : undefined,
        bcc: validated.bcc ? (Array.isArray(validated.bcc) ? validated.bcc : [validated.bcc]) : undefined,
      };

      // Send email based on provider
      switch (this.provider) {
        case 'sendgrid':
          return await this.sendWithSendGrid(emailData);
        case 'ses':
          return await this.sendWithSES(emailData);
        case 'smtp':
          return await this.sendWithSMTP(emailData);
        default:
          console.log('Email (dev mode):', emailData);
          return true;
      }
    } catch (error) {
      console.error('Email service error:', error);
      return false;
    }
  }

  private async sendWithSendGrid(data: any): Promise<boolean> {
    if (!process.env.SENDGRID_API_KEY) {
      console.warn('SendGrid API key not configured');
      return false;
    }

    try {
      const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${process.env.SENDGRID_API_KEY}`,
        },
        body: JSON.stringify({
          personalizations: [
            {
              to: data.to.map((email: string) => ({ email })),
              cc: data.cc?.map((email: string) => ({ email })),
              bcc: data.bcc?.map((email: string) => ({ email })),
            },
          ],
          from: { email: this.fromEmail, name: this.fromName },
          subject: data.subject,
          content: [
            { type: 'text/plain', value: data.text },
            { type: 'text/html', value: data.html },
          ],
          reply_to: data.replyTo ? { email: data.replyTo } : undefined,
        }),
      });

      return response.ok;
    } catch (error) {
      console.error('SendGrid error:', error);
      return false;
    }
  }

  private async sendWithSES(data: any): Promise<boolean> {
    // AWS SES implementation
    console.log('SES email sending not implemented yet');
    return false;
  }

  private async sendWithSMTP(data: any): Promise<boolean> {
    // SMTP implementation
    console.log('SMTP email sending not implemented yet');
    return false;
  }

  private renderTemplate(template?: string, data?: Record<string, any>): string {
    if (!template) return '';

    const templates: Record<string, (data: any) => string> = {
      'email-verification': (data) => `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Verify Your Email</title>
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="background: linear-gradient(to right, #0ea5e9, #3b82f6); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
            <h1 style="color: white; margin: 0;">Voice Agent Platform</h1>
          </div>
          <div style="background: white; padding: 30px; border: 1px solid #e5e5e5; border-radius: 0 0 10px 10px;">
            <h2>Hello ${data.name}!</h2>
            <p>Thank you for signing up. Please verify your email address to activate your account.</p>
            <div style="text-align: center; margin: 30px 0;">
              <a href="${data.verificationUrl}" style="background: #0ea5e9; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block;">Verify Email</a>
            </div>
            <p style="color: #666; font-size: 14px;">Or copy and paste this link into your browser:</p>
            <p style="color: #0ea5e9; word-break: break-all; font-size: 14px;">${data.verificationUrl}</p>
            <hr style="border: none; border-top: 1px solid #e5e5e5; margin: 30px 0;">
            <p style="color: #999; font-size: 12px; text-align: center;">This link will expire in 24 hours. If you didn't create an account, you can safely ignore this email.</p>
          </div>
        </body>
        </html>
      `,
      'password-reset': (data) => `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Reset Your Password</title>
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="background: linear-gradient(to right, #0ea5e9, #3b82f6); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
            <h1 style="color: white; margin: 0;">Password Reset</h1>
          </div>
          <div style="background: white; padding: 30px; border: 1px solid #e5e5e5; border-radius: 0 0 10px 10px;">
            <h2>Hello ${data.name}!</h2>
            <p>We received a request to reset your password. Click the button below to create a new password:</p>
            <div style="text-align: center; margin: 30px 0;">
              <a href="${data.resetUrl}" style="background: #0ea5e9; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block;">Reset Password</a>
            </div>
            <p style="color: #666; font-size: 14px;">Or copy and paste this link into your browser:</p>
            <p style="color: #0ea5e9; word-break: break-all; font-size: 14px;">${data.resetUrl}</p>
            <hr style="border: none; border-top: 1px solid #e5e5e5; margin: 30px 0;">
            <p style="color: #999; font-size: 12px; text-align: center;">This link will expire in 1 hour. If you didn't request a password reset, you can safely ignore this email.</p>
          </div>
        </body>
        </html>
      `,
      'welcome': (data) => `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Welcome to Voice Agent Platform</title>
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="background: linear-gradient(to right, #0ea5e9, #3b82f6); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
            <h1 style="color: white; margin: 0;">Welcome to Voice Agent Platform!</h1>
          </div>
          <div style="background: white; padding: 30px; border: 1px solid #e5e5e5; border-radius: 0 0 10px 10px;">
            <h2>Hello ${data.name}!</h2>
            <p>Your account has been successfully created. Here's what you can do next:</p>
            <ul style="color: #666;">
              <li>Create your first voice agent</li>
              <li>Explore our documentation</li>
              <li>Join our community</li>
              <li>Configure your settings</li>
            </ul>
            <div style="text-align: center; margin: 30px 0;">
              <a href="${data.dashboardUrl}" style="background: #0ea5e9; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; display: inline-block;">Go to Dashboard</a>
            </div>
            <hr style="border: none; border-top: 1px solid #e5e5e5; margin: 30px 0;">
            <p style="color: #999; font-size: 12px; text-align: center;">Need help? Contact our support team at support@voiceagent.com</p>
          </div>
        </body>
        </html>
      `,
    };

    const templateFunc = templates[template];
    return templateFunc ? templateFunc(data) : '';
  }

  private htmlToText(html: string): string {
    return html
      .replace(/<style[^>]*>.*?<\/style>/gi, '')
      .replace(/<script[^>]*>.*?<\/script>/gi, '')
      .replace(/<[^>]+>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  async sendVerificationEmail(email: string, token: string): Promise<boolean> {
    return this.sendEmail({
      to: email,
      subject: 'Verify your email address',
      template: 'email-verification',
      data: {
        name: email.split('@')[0],
        verificationUrl: `${process.env.NEXT_PUBLIC_APP_URL}/verify-email?token=${token}`,
      },
    });
  }

  async sendPasswordResetEmail(email: string, token: string): Promise<boolean> {
    return this.sendEmail({
      to: email,
      subject: 'Reset your password',
      template: 'password-reset',
      data: {
        name: email.split('@')[0],
        resetUrl: `${process.env.NEXT_PUBLIC_APP_URL}/reset-password?token=${token}`,
      },
    });
  }

  async sendWelcomeEmail(email: string, name?: string): Promise<boolean> {
    return this.sendEmail({
      to: email,
      subject: 'Welcome to Voice Agent Platform',
      template: 'welcome',
      data: {
        name: name || email.split('@')[0],
        dashboardUrl: `${process.env.NEXT_PUBLIC_APP_URL}/dashboard`,
      },
    });
  }
}

export const emailService = new EmailService();
export const sendEmail = (options: EmailOptions) => emailService.sendEmail(options);