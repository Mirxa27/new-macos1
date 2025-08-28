'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { 
  Users, 
  Mic, 
  Activity, 
  Server, 
  TrendingUp, 
  AlertTriangle,
  CheckCircle,
  XCircle
} from 'lucide-react';
import { motion } from 'framer-motion';
import { SystemMetrics } from '@/components/admin/system-metrics';
import { UserManagement } from '@/components/admin/user-management';
import { AIProviderSettings } from '@/components/admin/ai-provider-settings';
import { SessionMonitoring } from '@/components/admin/session-monitoring';

export default function AdminDashboard() {
  const [systemHealth, setSystemHealth] = useState({
    status: 'healthy',
    uptime: '99.9%',
    activeUsers: 42,
    activeSessions: 15,
    totalCommands: 1247,
    errorRate: 0.2,
  });

  const [recentAlerts, setRecentAlerts] = useState([
    {
      id: '1',
      type: 'warning',
      message: 'High API usage detected for OpenAI provider',
      timestamp: '2 minutes ago',
    },
    {
      id: '2',
      type: 'info',
      message: 'New user registration: john.doe@example.com',
      timestamp: '15 minutes ago',
    },
    {
      id: '3',
      type: 'success',
      message: 'Database backup completed successfully',
      timestamp: '1 hour ago',
    },
  ]);

  const statsCards = [
    {
      title: 'Active Users',
      value: systemHealth.activeUsers,
      change: '+12%',
      icon: Users,
      color: 'text-blue-600',
    },
    {
      title: 'Voice Sessions',
      value: systemHealth.activeSessions,
      change: '+5%',
      icon: Mic,
      color: 'text-green-600',
    },
    {
      title: 'Total Commands',
      value: systemHealth.totalCommands,
      change: '+23%',
      icon: Activity,
      color: 'text-purple-600',
    },
    {
      title: 'System Uptime',
      value: systemHealth.uptime,
      change: 'Stable',
      icon: Server,
      color: 'text-orange-600',
    },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold gradient-text">Admin Dashboard</h1>
          <p className="text-muted-foreground">
            Monitor and manage your Voice Agent Pro system
          </p>
        </div>
        <div className="flex items-center space-x-2">
          <Badge 
            variant={systemHealth.status === 'healthy' ? 'default' : 'destructive'}
            className="text-sm"
          >
            System {systemHealth.status}
          </Badge>
          <Button variant="outline" size="sm">
            <TrendingUp className="h-4 w-4 mr-2" />
            Generate Report
          </Button>
        </div>
      </div>

      {/* Quick Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {statsCards.map((stat, index) => (
          <motion.div
            key={stat.title}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.1 }}
          >
            <Card className="card-hover">
              <CardContent className="p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">
                      {stat.title}
                    </p>
                    <p className="text-2xl font-bold">{stat.value}</p>
                    <p className="text-xs text-green-600">{stat.change}</p>
                  </div>
                  <stat.icon className={`h-8 w-8 ${stat.color}`} />
                </div>
              </CardContent>
            </Card>
          </motion.div>
        ))}
      </div>

      {/* Recent Alerts */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.5 }}
      >
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center space-x-2">
              <AlertTriangle className="h-5 w-5" />
              <span>Recent Alerts</span>
            </CardTitle>
            <CardDescription>
              System notifications and important events
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {recentAlerts.map((alert) => (
                <div key={alert.id} className="flex items-center space-x-4 p-4 rounded-lg bg-muted/50">
                  {alert.type === 'warning' && (
                    <AlertTriangle className="h-5 w-5 text-yellow-500" />
                  )}
                  {alert.type === 'info' && (
                    <Activity className="h-5 w-5 text-blue-500" />
                  )}
                  {alert.type === 'success' && (
                    <CheckCircle className="h-5 w-5 text-green-500" />
                  )}
                  {alert.type === 'error' && (
                    <XCircle className="h-5 w-5 text-red-500" />
                  )}
                  <div className="flex-1">
                    <p className="text-sm font-medium">{alert.message}</p>
                    <p className="text-xs text-muted-foreground">{alert.timestamp}</p>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </motion.div>

      {/* Main Admin Tabs */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.6 }}
      >
        <Tabs defaultValue="metrics" className="space-y-6">
          <TabsList className="grid w-full grid-cols-4">
            <TabsTrigger value="metrics">System Metrics</TabsTrigger>
            <TabsTrigger value="users">User Management</TabsTrigger>
            <TabsTrigger value="providers">AI Providers</TabsTrigger>
            <TabsTrigger value="sessions">Session Monitoring</TabsTrigger>
          </TabsList>

          <TabsContent value="metrics" className="space-y-6">
            <SystemMetrics />
          </TabsContent>

          <TabsContent value="users" className="space-y-6">
            <UserManagement />
          </TabsContent>

          <TabsContent value="providers" className="space-y-6">
            <AIProviderSettings />
          </TabsContent>

          <TabsContent value="sessions" className="space-y-6">
            <SessionMonitoring />
          </TabsContent>
        </Tabs>
      </motion.div>
    </div>
  );
}
