'use client';

import { useState } from 'react';
import { usePathname } from 'next/navigation';
import Link from 'next/link';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  LayoutDashboard,
  Users,
  Bot,
  Settings,
  Activity,
  Database,
  Shield,
  BarChart3,
  Bell,
  HelpCircle,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react';

const navigation = [
  { name: 'Overview', href: '/admin', icon: LayoutDashboard },
  { name: 'Users', href: '/admin/users', icon: Users },
  { name: 'AI Providers', href: '/admin/providers', icon: Bot },
  { name: 'Sessions', href: '/admin/sessions', icon: Activity },
  { name: 'System', href: '/admin/system', icon: Settings },
  { name: 'Database', href: '/admin/database', icon: Database },
  { name: 'Security', href: '/admin/security', icon: Shield },
  { name: 'Analytics', href: '/admin/analytics', icon: BarChart3 },
  { name: 'Notifications', href: '/admin/notifications', icon: Bell },
  { name: 'Help', href: '/admin/help', icon: HelpCircle },
];

export function AdminSidebar() {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);

  return (
    <div className={cn(
      'flex flex-col h-full bg-background border-r border-border transition-all duration-300',
      collapsed ? 'w-16' : 'w-64'
    )}>
      {/* Header */}
      <div className="flex items-center justify-between p-4 border-b border-border">
        {!collapsed && (
          <div className="flex items-center space-x-2">
            <Shield className="h-6 w-6 text-primary" />
            <span className="font-bold text-lg gradient-text">Admin Panel</span>
          </div>
        )}
        <Button
          variant="ghost"
          size="sm"
          onClick={() => setCollapsed(!collapsed)}
          className="mobile-touch-target"
        >
          {collapsed ? (
            <ChevronRight className="h-4 w-4" />
          ) : (
            <ChevronLeft className="h-4 w-4" />
          )}
        </Button>
      </div>

      {/* Navigation */}
      <nav className="flex-1 p-4 space-y-2">
        {navigation.map((item) => {
          const isActive = pathname === item.href;
          return (
            <Link
              key={item.name}
              href={item.href}
              className={cn(
                'flex items-center rounded-lg px-3 py-2 text-sm font-medium transition-colors mobile-touch-target',
                isActive
                  ? 'bg-primary text-primary-foreground'
                  : 'hover:bg-accent hover:text-accent-foreground',
                collapsed && 'justify-center'
              )}
            >
              <item.icon className={cn('h-5 w-5', !collapsed && 'mr-3')} />
              {!collapsed && <span>{item.name}</span>}
              {collapsed && (
                <span className="sr-only">{item.name}</span>
              )}
            </Link>
          );
        })}
      </nav>

      {/* Status */}
      {!collapsed && (
        <div className="p-4 border-t border-border">
          <div className="space-y-2">
            <div className="flex items-center justify-between text-xs">
              <span className="text-muted-foreground">System Status</span>
              <Badge variant="default" className="text-xs">
                Healthy
              </Badge>
            </div>
            <div className="flex items-center justify-between text-xs">
              <span className="text-muted-foreground">Active Users</span>
              <span className="font-medium">42</span>
            </div>
            <div className="flex items-center justify-between text-xs">
              <span className="text-muted-foreground">Uptime</span>
              <span className="font-medium">99.9%</span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
