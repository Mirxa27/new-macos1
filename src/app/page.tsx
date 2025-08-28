'use client';

import { useSession } from 'next-auth/react';
import { redirect } from 'next/navigation';
import { VoiceAssistant } from '@/components/voice/voice-assistant';
import { DashboardLayout } from '@/components/layout/dashboard-layout';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Mic, MicOff, Settings, Activity, Zap, Shield } from 'lucide-react';
import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';

export default function DashboardPage() {
  const { data: session, status } = useSession();
  const [isListening, setIsListening] = useState(false);
  const [sessionStats, setSessionStats] = useState({
    totalCommands: 0,
    successRate: 0,
    averageResponseTime: 0,
    activeSessions: 0,
  });

  useEffect(() => {
    if (status === 'unauthenticated') {
      redirect('/login');
    }
  }, [status]);

  if (status === 'loading') {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="loading-dots">
          <div></div>
          <div></div>
          <div></div>
        </div>
      </div>
    );
  }

  if (!session) {
    return null;
  }

  return (
    <DashboardLayout>
      <div className="flex flex-col space-y-6 p-6">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between space-y-4 sm:space-y-0">
          <div>
            <h1 className="text-3xl font-bold gradient-text">
              Welcome back, {session.user?.name}
            </h1>
            <p className="text-muted-foreground">
              Your voice-powered AI assistant is ready to help
            </p>
          </div>
          <div className="flex items-center space-x-2">
            <Badge variant={isListening ? 'default' : 'secondary'}>
              {isListening ? 'Listening' : 'Idle'}
            </Badge>
            <Button variant="outline" size="sm">
              <Settings className="h-4 w-4 mr-2" />
              Settings
            </Button>
          </div>
        </div>

        {/* Quick Stats */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1 }}
          >
            <Card className="card-hover">
              <CardContent className="p-6">
                <div className="flex items-center space-x-2">
                  <Activity className="h-5 w-5 text-primary" />
                  <div>
                    <p className="text-2xl font-bold">{sessionStats.totalCommands}</p>
                    <p className="text-sm text-muted-foreground">Commands</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2 }}
          >
            <Card className="card-hover">
              <CardContent className="p-6">
                <div className="flex items-center space-x-2">
                  <Zap className="h-5 w-5 text-green-500" />
                  <div>
                    <p className="text-2xl font-bold">{sessionStats.successRate}%</p>
                    <p className="text-sm text-muted-foreground">Success Rate</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 }}
          >
            <Card className="card-hover">
              <CardContent className="p-6">
                <div className="flex items-center space-x-2">
                  <Shield className="h-5 w-5 text-blue-500" />
                  <div>
                    <p className="text-2xl font-bold">{sessionStats.averageResponseTime}ms</p>
                    <p className="text-sm text-muted-foreground">Avg Response</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4 }}
          >
            <Card className="card-hover">
              <CardContent className="p-6">
                <div className="flex items-center space-x-2">
                  <Mic className="h-5 w-5 text-purple-500" />
                  <div>
                    <p className="text-2xl font-bold">{sessionStats.activeSessions}</p>
                    <p className="text-sm text-muted-foreground">Active Sessions</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          </motion.div>
        </div>

        {/* Main Voice Assistant Interface */}
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.5 }}
        >
          <Card className="glass-morphism">
            <CardHeader>
              <CardTitle className="flex items-center space-x-2">
                {isListening ? (
                  <MicOff className="h-6 w-6 text-red-500" />
                ) : (
                  <Mic className="h-6 w-6 text-primary" />
                )}
                <span>Voice Assistant</span>
              </CardTitle>
              <CardDescription>
                Click the microphone to start voice commands or type your requests below
              </CardDescription>
            </CardHeader>
            <CardContent>
              <VoiceAssistant
                onListeningChange={setIsListening}
                onStatsUpdate={setSessionStats}
              />
            </CardContent>
          </Card>
        </motion.div>

        {/* Recent Activity */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.6 }}
        >
          <Card>
            <CardHeader>
              <CardTitle>Recent Activity</CardTitle>
              <CardDescription>
                Your latest voice commands and system actions
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="flex items-center space-x-4 p-4 rounded-lg bg-muted/50">
                  <div className="w-2 h-2 bg-green-500 rounded-full"></div>
                  <div className="flex-1">
                    <p className="text-sm font-medium">Open Calculator app</p>
                    <p className="text-xs text-muted-foreground">2 minutes ago</p>
                  </div>
                  <Badge variant="outline">Completed</Badge>
                </div>
                <div className="flex items-center space-x-4 p-4 rounded-lg bg-muted/50">
                  <div className="w-2 h-2 bg-blue-500 rounded-full"></div>
                  <div className="flex-1">
                    <p className="text-sm font-medium">Type 'Hello World' in text editor</p>
                    <p className="text-xs text-muted-foreground">5 minutes ago</p>
                  </div>
                  <Badge variant="outline">Completed</Badge>
                </div>
                <div className="flex items-center space-x-4 p-4 rounded-lg bg-muted/50">
                  <div className="w-2 h-2 bg-purple-500 rounded-full"></div>
                  <div className="flex-1">
                    <p className="text-sm font-medium">Screenshot and analyze current screen</p>
                    <p className="text-xs text-muted-foreground">8 minutes ago</p>
                  </div>
                  <Badge variant="outline">Completed</Badge>
                </div>
              </div>
            </CardContent>
          </Card>
        </motion.div>

        {/* Quick Actions */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.7 }}
        >
          <Card>
            <CardHeader>
              <CardTitle>Quick Actions</CardTitle>
              <CardDescription>
                Frequently used commands and shortcuts
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
                <Button variant="outline" className="h-20 flex-col space-y-2">
                  <Activity className="h-6 w-6" />
                  <span className="text-xs">System Info</span>
                </Button>
                <Button variant="outline" className="h-20 flex-col space-y-2">
                  <Shield className="h-6 w-6" />
                  <span className="text-xs">Take Screenshot</span>
                </Button>
                <Button variant="outline" className="h-20 flex-col space-y-2">
                  <Zap className="h-6 w-6" />
                  <span className="text-xs">Quick Note</span>
                </Button>
                <Button variant="outline" className="h-20 flex-col space-y-2">
                  <Settings className="h-6 w-6" />
                  <span className="text-xs">Preferences</span>
                </Button>
              </div>
            </CardContent>
          </Card>
        </motion.div>
      </div>
    </DashboardLayout>
  );
}
