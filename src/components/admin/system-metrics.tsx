'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
  Activity,
  Database,
  Server,
  Users,
  Cpu,
  HardDrive,
  Network,
  RefreshCw,
} from 'lucide-react';
import { motion } from 'framer-motion';

interface SystemMetric {
  name: string;
  value: string;
  status: 'healthy' | 'warning' | 'error';
  icon: React.ElementType;
  description: string;
}

export function SystemMetrics() {
  const [metrics, setMetrics] = useState<SystemMetric[]>([
    {
      name: 'CPU Usage',
      value: '23%',
      status: 'healthy',
      icon: Cpu,
      description: 'Average CPU utilization',
    },
    {
      name: 'Memory Usage',
      value: '67%',
      status: 'warning',
      icon: HardDrive,
      description: 'RAM utilization',
    },
    {
      name: 'Database',
      value: 'Connected',
      status: 'healthy',
      icon: Database,
      description: 'PostgreSQL connection status',
    },
    {
      name: 'API Response',
      value: '120ms',
      status: 'healthy',
      icon: Network,
      description: 'Average API response time',
    },
    {
      name: 'Active Users',
      value: '42',
      status: 'healthy',
      icon: Users,
      description: 'Currently active users',
    },
    {
      name: 'System Load',
      value: '1.2',
      status: 'healthy',
      icon: Server,
      description: 'System load average',
    },
  ]);

  const [isRefreshing, setIsRefreshing] = useState(false);

  const refreshMetrics = async () => {
    setIsRefreshing(true);
    try {
      const response = await fetch('/api/admin/metrics');
      if (response.ok) {
        const data = await response.json();
        // Update metrics with real data
        console.log('Metrics updated:', data);
      }
    } catch (error) {
      console.error('Failed to refresh metrics:', error);
    } finally {
      setTimeout(() => setIsRefreshing(false), 1000);
    }
  };

  useEffect(() => {
    // Auto-refresh metrics every 30 seconds
    const interval = setInterval(refreshMetrics, 30000);
    return () => clearInterval(interval);
  }, []);

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'healthy':
        return 'bg-green-500';
      case 'warning':
        return 'bg-yellow-500';
      case 'error':
        return 'bg-red-500';
      default:
        return 'bg-gray-500';
    }
  };

  const getStatusVariant = (status: string) => {
    switch (status) {
      case 'healthy':
        return 'default';
      case 'warning':
        return 'secondary';
      case 'error':
        return 'destructive';
      default:
        return 'outline';
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold">System Metrics</h2>
          <p className="text-muted-foreground">Real-time system performance monitoring</p>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={refreshMetrics}
          disabled={isRefreshing}
          className="mobile-touch-target"
        >
          <RefreshCw className={`h-4 w-4 mr-2 ${isRefreshing ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {metrics.map((metric, index) => (
          <motion.div
            key={metric.name}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.1 }}
          >
            <Card className="card-hover">
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">{metric.name}</CardTitle>
                <div className="flex items-center space-x-2">
                  <div className={`w-2 h-2 rounded-full ${getStatusColor(metric.status)}`} />
                  <metric.icon className="h-4 w-4 text-muted-foreground" />
                </div>
              </CardHeader>
              <CardContent>
                <div className="flex items-center justify-between">
                  <div className="text-2xl font-bold">{metric.value}</div>
                  <Badge variant={getStatusVariant(metric.status) as any}>
                    {metric.status}
                  </Badge>
                </div>
                <p className="text-xs text-muted-foreground mt-2">
                  {metric.description}
                </p>
              </CardContent>
            </Card>
          </motion.div>
        ))}
      </div>

      {/* Detailed Performance Chart */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center space-x-2">
            <Activity className="h-5 w-5" />
            <span>Performance Overview</span>
          </CardTitle>
          <CardDescription>
            System performance metrics over the last 24 hours
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="h-64 flex items-center justify-center text-muted-foreground">
            <div className="text-center">
              <Activity className="h-12 w-12 mx-auto mb-4 opacity-50" />
              <p>Performance chart would be displayed here</p>
              <p className="text-sm">Integration with charting library needed</p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* System Alerts */}
      <Card>
        <CardHeader>
          <CardTitle>Recent System Events</CardTitle>
          <CardDescription>
            Important system events and alerts
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {[
              {
                type: 'info',
                message: 'System backup completed successfully',
                time: '2 minutes ago',
              },
              {
                type: 'warning',
                message: 'High memory usage detected (67%)',
                time: '15 minutes ago',
              },
              {
                type: 'success',
                message: 'Database optimization completed',
                time: '1 hour ago',
              },
            ].map((event, index) => (
              <div key={index} className="flex items-start space-x-3 p-3 rounded-lg bg-muted/50">
                <div className={`w-2 h-2 rounded-full mt-2 ${
                  event.type === 'success' ? 'bg-green-500' :
                  event.type === 'warning' ? 'bg-yellow-500' :
                  event.type === 'error' ? 'bg-red-500' : 'bg-blue-500'
                }`} />
                <div className="flex-1">
                  <p className="text-sm font-medium">{event.message}</p>
                  <p className="text-xs text-muted-foreground">{event.time}</p>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
