'use client';

import { useState, useEffect } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import Link from 'next/link';
import {
  LayoutDashboard,
  Users,
  Settings,
  Shield,
  Mic,
  BarChart3,
  Webhook,
  Key,
  Bell,
  LogOut,
  Menu,
  X,
  ChevronDown,
  Database,
  Mail,
  CreditCard,
  Globe,
  Lock,
  Server,
  Activity,
  FileText,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { toast } from 'sonner';

const sidebarItems = [
  {
    title: 'Dashboard',
    href: '/admin',
    icon: LayoutDashboard,
  },
  {
    title: 'Users',
    href: '/admin/users',
    icon: Users,
  },
  {
    title: 'Voice Agents',
    href: '/admin/agents',
    icon: Mic,
  },
  {
    title: 'Analytics',
    href: '/admin/analytics',
    icon: BarChart3,
  },
  {
    title: 'API Keys',
    href: '/admin/api-keys',
    icon: Key,
  },
  {
    title: 'Webhooks',
    href: '/admin/webhooks',
    icon: Webhook,
  },
  {
    title: 'System Config',
    href: '/admin/config',
    icon: Settings,
    subItems: [
      { title: 'General', href: '/admin/config/general', icon: Settings },
      { title: 'Authentication', href: '/admin/config/auth', icon: Shield },
      { title: 'AI Providers', href: '/admin/config/ai', icon: Server },
      { title: 'Database', href: '/admin/config/database', icon: Database },
      { title: 'Email', href: '/admin/config/email', icon: Mail },
      { title: 'Storage', href: '/admin/config/storage', icon: Server },
      { title: 'Billing', href: '/admin/config/billing', icon: CreditCard },
      { title: 'Security', href: '/admin/config/security', icon: Lock },
      { title: 'Webhooks', href: '/admin/config/webhooks', icon: Webhook },
      { title: 'Limits', href: '/admin/config/limits', icon: Activity },
    ],
  },
  {
    title: 'Audit Logs',
    href: '/admin/audit',
    icon: FileText,
  },
  {
    title: 'Notifications',
    href: '/admin/notifications',
    icon: Bell,
  },
];

export default function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [expandedItems, setExpandedItems] = useState<string[]>([]);
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    // Check authentication
    const token = localStorage.getItem('token');
    if (!token) {
      router.push('/login');
      return;
    }

    // Fetch user data
    fetchUser();
  }, []);

  const fetchUser = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/auth/me', {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch user');
      }

      const data = await response.json();
      
      // Check if user is admin or super admin
      if (data.role !== 'ADMIN' && data.role !== 'SUPER_ADMIN') {
        toast.error('Access denied. Admin privileges required.');
        router.push('/dashboard');
        return;
      }

      setUser(data);
    } catch (error) {
      console.error('Error fetching user:', error);
      router.push('/login');
    }
  };

  const handleLogout = async () => {
    try {
      const token = localStorage.getItem('token');
      await fetch('/api/auth/logout', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });
    } catch (error) {
      console.error('Logout error:', error);
    } finally {
      localStorage.removeItem('token');
      localStorage.removeItem('refreshToken');
      router.push('/login');
    }
  };

  const toggleExpanded = (title: string) => {
    setExpandedItems((prev) =>
      prev.includes(title)
        ? prev.filter((item) => item !== title)
        : [...prev, title]
    );
  };

  const isActive = (href: string) => {
    return pathname === href || pathname.startsWith(href + '/');
  };

  if (!user) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Mobile Header */}
      <div className="lg:hidden fixed top-0 left-0 right-0 z-50 bg-background border-b">
        <div className="flex items-center justify-between p-4">
          <button
            onClick={() => setSidebarOpen(!sidebarOpen)}
            className="p-2 hover:bg-muted rounded-lg"
          >
            {sidebarOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
          </button>
          <div className="flex items-center space-x-2">
            <Shield className="h-5 w-5 text-primary" />
            <span className="font-semibold">Admin Panel</span>
          </div>
          <div className="w-9" />
        </div>
      </div>

      {/* Sidebar */}
      <aside
        className={cn(
          'fixed top-0 left-0 z-40 h-full w-64 bg-card border-r transition-transform lg:translate-x-0',
          sidebarOpen ? 'translate-x-0' : '-translate-x-full'
        )}
      >
        <div className="flex flex-col h-full">
          {/* Logo */}
          <div className="p-6 border-b">
            <Link href="/admin" className="flex items-center space-x-2">
              <Shield className="h-8 w-8 text-primary" />
              <div>
                <h2 className="text-lg font-bold">Admin Panel</h2>
                <p className="text-xs text-muted-foreground">
                  {user.role === 'SUPER_ADMIN' ? 'Super Admin' : 'Admin'}
                </p>
              </div>
            </Link>
          </div>

          {/* Navigation */}
          <nav className="flex-1 overflow-y-auto p-4 space-y-1">
            {sidebarItems.map((item) => (
              <div key={item.title}>
                {item.subItems ? (
                  <>
                    <button
                      onClick={() => toggleExpanded(item.title)}
                      className={cn(
                        'w-full flex items-center justify-between px-3 py-2 text-sm font-medium rounded-lg transition-colors',
                        isActive(item.href)
                          ? 'bg-primary/10 text-primary'
                          : 'hover:bg-muted'
                      )}
                    >
                      <div className="flex items-center">
                        <item.icon className="h-4 w-4 mr-3" />
                        {item.title}
                      </div>
                      <ChevronDown
                        className={cn(
                          'h-4 w-4 transition-transform',
                          expandedItems.includes(item.title) && 'rotate-180'
                        )}
                      />
                    </button>
                    {expandedItems.includes(item.title) && (
                      <div className="ml-4 mt-1 space-y-1">
                        {item.subItems.map((subItem) => (
                          <Link
                            key={subItem.href}
                            href={subItem.href}
                            className={cn(
                              'flex items-center px-3 py-2 text-sm rounded-lg transition-colors',
                              isActive(subItem.href)
                                ? 'bg-primary/10 text-primary'
                                : 'hover:bg-muted text-muted-foreground'
                            )}
                            onClick={() => setSidebarOpen(false)}
                          >
                            <subItem.icon className="h-3 w-3 mr-3" />
                            {subItem.title}
                          </Link>
                        ))}
                      </div>
                    )}
                  </>
                ) : (
                  <Link
                    href={item.href}
                    className={cn(
                      'flex items-center px-3 py-2 text-sm font-medium rounded-lg transition-colors',
                      isActive(item.href)
                        ? 'bg-primary/10 text-primary'
                        : 'hover:bg-muted'
                    )}
                    onClick={() => setSidebarOpen(false)}
                  >
                    <item.icon className="h-4 w-4 mr-3" />
                    {item.title}
                  </Link>
                )}
              </div>
            ))}
          </nav>

          {/* User Section */}
          <div className="p-4 border-t">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center">
                <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center mr-3">
                  <span className="text-xs font-medium">
                    {user.firstName?.[0]}{user.lastName?.[0]}
                  </span>
                </div>
                <div>
                  <p className="text-sm font-medium">
                    {user.firstName} {user.lastName}
                  </p>
                  <p className="text-xs text-muted-foreground">{user.email}</p>
                </div>
              </div>
            </div>
            <Button
              variant="outline"
              size="sm"
              className="w-full"
              onClick={handleLogout}
            >
              <LogOut className="h-4 w-4 mr-2" />
              Logout
            </Button>
          </div>
        </div>
      </aside>

      {/* Main Content */}
      <main className={cn('transition-all lg:ml-64', sidebarOpen && 'blur-sm lg:blur-none')}>
        <div className="min-h-screen pt-16 lg:pt-0">
          {children}
        </div>
      </main>

      {/* Mobile Overlay */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-30 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}
    </div>
  );
}