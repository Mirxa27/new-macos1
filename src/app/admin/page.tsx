'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import {
  Users,
  Mic,
  MessageSquare,
  TrendingUp,
  Activity,
  DollarSign,
  Server,
  AlertCircle,
  CheckCircle,
  Clock,
  ArrowUp,
  ArrowDown,
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { formatNumber, formatCurrency } from '@/lib/utils';

interface DashboardStats {
  users: {
    total: number;
    active: number;
    new: number;
    growth: number;
  };
  agents: {
    total: number;
    active: number;
    conversations: number;
    growth: number;
  };
  revenue: {
    total: number;
    monthly: number;
    growth: number;
  };
  system: {
    uptime: number;
    apiCalls: number;
    errors: number;
    latency: number;
  };
}

const statCards = [
  {
    title: 'Total Users',
    key: 'users.total',
    icon: Users,
    color: 'text-blue-500',
    bgColor: 'bg-blue-500/10',
    format: 'number',
  },
  {
    title: 'Active Agents',
    key: 'agents.active',
    icon: Mic,
    color: 'text-green-500',
    bgColor: 'bg-green-500/10',
    format: 'number',
  },
  {
    title: 'Conversations',
    key: 'agents.conversations',
    icon: MessageSquare,
    color: 'text-purple-500',
    bgColor: 'bg-purple-500/10',
    format: 'number',
  },
  {
    title: 'Monthly Revenue',
    key: 'revenue.monthly',
    icon: DollarSign,
    color: 'text-yellow-500',
    bgColor: 'bg-yellow-500/10',
    format: 'currency',
  },
];

const activityItems = [
  {
    id: 1,
    type: 'user_signup',
    message: 'New user registration',
    details: 'john.doe@example.com',
    time: '2 minutes ago',
    icon: Users,
    color: 'text-blue-500',
  },
  {
    id: 2,
    type: 'agent_created',
    message: 'New voice agent created',
    details: 'Customer Support Bot',
    time: '15 minutes ago',
    icon: Mic,
    color: 'text-green-500',
  },
  {
    id: 3,
    type: 'payment',
    message: 'Payment received',
    details: '$49.00 - Starter Plan',
    time: '1 hour ago',
    icon: DollarSign,
    color: 'text-yellow-500',
  },
  {
    id: 4,
    type: 'error',
    message: 'API error detected',
    details: 'Rate limit exceeded',
    time: '2 hours ago',
    icon: AlertCircle,
    color: 'text-red-500',
  },
];

export default function AdminDashboard() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchDashboardStats();
    const interval = setInterval(fetchDashboardStats, 30000); // Refresh every 30 seconds
    return () => clearInterval(interval);
  }, []);

  const fetchDashboardStats = async () => {
    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/admin/dashboard/stats', {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch stats');
      }

      const data = await response.json();
      setStats(data);
    } catch (error) {
      console.error('Error fetching dashboard stats:', error);
      // Set mock data for now
      setStats({
        users: { total: 1234, active: 892, new: 45, growth: 12.5 },
        agents: { total: 56, active: 42, conversations: 8934, growth: 8.3 },
        revenue: { total: 45678, monthly: 12345, growth: 15.2 },
        system: { uptime: 99.9, apiCalls: 234567, errors: 12, latency: 45 },
      });
    } finally {
      setLoading(false);
    }
  };

  const getNestedValue = (obj: any, path: string) => {
    return path.split('.').reduce((acc, part) => acc && acc[part], obj);
  };

  const formatValue = (value: any, format: string) => {
    if (format === 'currency') {
      return formatCurrency(value);
    }
    return formatNumber(value);
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
        <h1 className="text-3xl font-bold mb-2">Admin Dashboard</h1>
        <p className="text-muted-foreground">
          Monitor your platform's performance and manage system resources
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        {statCards.map((card, index) => {
          const value = getNestedValue(stats, card.key);
          const growthKey = card.key.split('.')[0] + '.growth';
          const growth = getNestedValue(stats, growthKey);

          return (
            <motion.div
              key={card.key}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.3, delay: index * 0.1 }}
            >
              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">
                    {card.title}
                  </CardTitle>
                  <div className={`${card.bgColor} p-2 rounded-lg`}>
                    <card.icon className={`h-4 w-4 ${card.color}`} />
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">
                    {formatValue(value, card.format)}
                  </div>
                  {growth !== undefined && (
                    <div className="flex items-center mt-2">
                      {growth > 0 ? (
                        <ArrowUp className="h-4 w-4 text-green-500 mr-1" />
                      ) : (
                        <ArrowDown className="h-4 w-4 text-red-500 mr-1" />
                      )}
                      <span
                        className={`text-sm ${
                          growth > 0 ? 'text-green-500' : 'text-red-500'
                        }`}
                      >
                        {Math.abs(growth)}%
                      </span>
                      <span className="text-sm text-muted-foreground ml-1">
                        from last month
                      </span>
                    </div>
                  )}
                </CardContent>
              </Card>
            </motion.div>
          );
        })}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* System Status */}
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>System Status</CardTitle>
            <CardDescription>Real-time system performance metrics</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center">
                  <Server className="h-4 w-4 mr-2 text-muted-foreground" />
                  <span className="text-sm font-medium">API Status</span>
                </div>
                <div className="flex items-center">
                  <CheckCircle className="h-4 w-4 mr-1 text-green-500" />
                  <span className="text-sm text-green-500">Operational</span>
                </div>
              </div>

              <div className="flex items-center justify-between">
                <div className="flex items-center">
                  <Activity className="h-4 w-4 mr-2 text-muted-foreground" />
                  <span className="text-sm font-medium">Uptime</span>
                </div>
                <span className="text-sm font-mono">{stats?.system.uptime}%</span>
              </div>

              <div className="flex items-center justify-between">
                <div className="flex items-center">
                  <TrendingUp className="h-4 w-4 mr-2 text-muted-foreground" />
                  <span className="text-sm font-medium">API Calls (24h)</span>
                </div>
                <span className="text-sm font-mono">
                  {formatNumber(stats?.system.apiCalls || 0)}
                </span>
              </div>

              <div className="flex items-center justify-between">
                <div className="flex items-center">
                  <Clock className="h-4 w-4 mr-2 text-muted-foreground" />
                  <span className="text-sm font-medium">Avg Latency</span>
                </div>
                <span className="text-sm font-mono">{stats?.system.latency}ms</span>
              </div>

              <div className="flex items-center justify-between">
                <div className="flex items-center">
                  <AlertCircle className="h-4 w-4 mr-2 text-muted-foreground" />
                  <span className="text-sm font-medium">Errors (24h)</span>
                </div>
                <span className="text-sm font-mono text-red-500">
                  {stats?.system.errors}
                </span>
              </div>
            </div>

            <div className="mt-6 pt-6 border-t">
              <div className="grid grid-cols-3 gap-4 text-center">
                <div>
                  <p className="text-2xl font-bold text-green-500">
                    {formatNumber(892)}
                  </p>
                  <p className="text-xs text-muted-foreground">Active Sessions</p>
                </div>
                <div>
                  <p className="text-2xl font-bold text-blue-500">
                    {formatNumber(45)}
                  </p>
                  <p className="text-xs text-muted-foreground">Agents Online</p>
                </div>
                <div>
                  <p className="text-2xl font-bold text-purple-500">
                    {formatNumber(234)}
                  </p>
                  <p className="text-xs text-muted-foreground">Active Conversations</p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Recent Activity */}
        <Card>
          <CardHeader>
            <CardTitle>Recent Activity</CardTitle>
            <CardDescription>Latest platform events</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {activityItems.map((item) => (
                <div key={item.id} className="flex items-start space-x-3">
                  <div className={`p-2 rounded-lg bg-muted`}>
                    <item.icon className={`h-4 w-4 ${item.color}`} />
                  </div>
                  <div className="flex-1 space-y-1">
                    <p className="text-sm font-medium">{item.message}</p>
                    <p className="text-xs text-muted-foreground">{item.details}</p>
                    <p className="text-xs text-muted-foreground">{item.time}</p>
                  </div>
                </div>
              ))}
            </div>
            <Button variant="outline" className="w-full mt-4">
              View All Activity
            </Button>
          </CardContent>
        </Card>
      </div>

      {/* Quick Actions */}
      <Card className="mt-6">
        <CardHeader>
          <CardTitle>Quick Actions</CardTitle>
          <CardDescription>Common administrative tasks</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
            <Button variant="outline" className="h-auto flex-col py-4">
              <Users className="h-5 w-5 mb-2" />
              <span className="text-xs">Add User</span>
            </Button>
            <Button variant="outline" className="h-auto flex-col py-4">
              <Mic className="h-5 w-5 mb-2" />
              <span className="text-xs">Create Agent</span>
            </Button>
            <Button variant="outline" className="h-auto flex-col py-4">
              <Server className="h-5 w-5 mb-2" />
              <span className="text-xs">System Backup</span>
            </Button>
            <Button variant="outline" className="h-auto flex-col py-4">
              <AlertCircle className="h-5 w-5 mb-2" />
              <span className="text-xs">View Logs</span>
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}