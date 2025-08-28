'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import {
  Search,
  Filter,
  Download,
  RefreshCw,
  Play,
  Pause,
  Square,
  Clock,
  MessageSquare,
  User,
  Activity,
} from 'lucide-react';
import { motion } from 'framer-motion';
import { VoiceSession, VoiceCommand } from '@/types';

export function SessionMonitoring() {
  const [sessions, setSessions] = useState<VoiceSession[]>([]);
  const [selectedSession, setSelectedSession] = useState<VoiceSession | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);

  useEffect(() => {
    fetchSessions();
    // Auto-refresh every 30 seconds
    const interval = setInterval(fetchSessions, 30000);
    return () => clearInterval(interval);
  }, []);

  const fetchSessions = async () => {
    try {
      const response = await fetch('/api/admin/sessions');
      if (response.ok) {
        const data = await response.json();
        setSessions(data.sessions || []);
      }
    } catch (error) {
      console.error('Failed to fetch sessions:', error);
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  };

  const refreshSessions = () => {
    setIsRefreshing(true);
    fetchSessions();
  };

  const filteredSessions = sessions.filter(session => {
    const matchesSearch = 
      session.sessionName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      session.user?.fullName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      session.user?.email?.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesStatus = statusFilter === 'all' || session.sessionStatus === statusFilter;
    
    return matchesSearch && matchesStatus;
  });

  const getStatusBadge = (status: string) => {
    const variants = {
      active: 'default',
      paused: 'secondary',
      completed: 'outline',
      error: 'destructive',
    } as const;

    return (
      <Badge variant={variants[status as keyof typeof variants] || 'outline'}>
        {status.charAt(0).toUpperCase() + status.slice(1)}
      </Badge>
    );
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'active':
        return <Play className="h-3 w-3" />;
      case 'paused':
        return <Pause className="h-3 w-3" />;
      case 'completed':
        return <Square className="h-3 w-3" />;
      case 'error':
        return <Square className="h-3 w-3" />;
      default:
        return <Clock className="h-3 w-3" />;
    }
  };

  const formatDuration = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    
    if (hours > 0) {
      return `${hours}h ${minutes}m ${secs}s`;
    }
    return `${minutes}m ${secs}s`;
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="loading-dots">
          <div></div>
          <div></div>
          <div></div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between space-y-4 sm:space-y-0">
        <div>
          <h2 className="text-2xl font-bold">Session Monitoring</h2>
          <p className="text-muted-foreground">Monitor active and historical voice sessions</p>
        </div>
        <div className="flex space-x-2">
          <Button
            variant="outline"
            size="sm"
            onClick={refreshSessions}
            disabled={isRefreshing}
            className="mobile-touch-target"
          >
            <RefreshCw className={`h-4 w-4 mr-2 ${isRefreshing ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
          <Button variant="outline" size="sm" className="mobile-touch-target">
            <Download className="h-4 w-4 mr-2" />
            Export
          </Button>
        </div>
      </div>

      {/* Session Statistics */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        {[
          {
            title: 'Active Sessions',
            value: sessions.filter(s => s.sessionStatus === 'active').length,
            icon: Play,
            color: 'text-green-600',
          },
          {
            title: 'Total Sessions',
            value: sessions.length,
            icon: Activity,
            color: 'text-blue-600',
          },
          {
            title: 'Total Commands',
            value: sessions.reduce((sum, s) => sum + (s.voiceCommands?.length || 0), 0),
            icon: MessageSquare,
            color: 'text-purple-600',
          },
          {
            title: 'Average Duration',
            value: sessions.length > 0 
              ? Math.round(sessions.reduce((sum, s) => sum + s.totalDurationSeconds, 0) / sessions.length)
              : 0,
            icon: Clock,
            color: 'text-orange-600',
            format: (val: number) => formatDuration(val),
          },
        ].map((stat, index) => (
          <motion.div
            key={stat.title}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.1 }}
          >
            <Card>
              <CardContent className="p-6">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-muted-foreground">{stat.title}</p>
                    <p className="text-2xl font-bold">
                      {stat.format ? stat.format(stat.value) : stat.value}
                    </p>
                  </div>
                  <stat.icon className={`h-8 w-8 ${stat.color}`} />
                </div>
              </CardContent>
            </Card>
          </motion.div>
        ))}
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col sm:flex-row space-y-4 sm:space-y-0 sm:space-x-4">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Search sessions by name, user, or email..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-9"
              />
            </div>
            <div className="flex space-x-2">
              {['all', 'active', 'paused', 'completed', 'error'].map((status) => (
                <Button
                  key={status}
                  variant={statusFilter === status ? 'default' : 'outline'}
                  size="sm"
                  onClick={() => setStatusFilter(status)}
                  className="mobile-touch-target"
                >
                  {status === 'all' ? 'All' : status.charAt(0).toUpperCase() + status.slice(1)}
                </Button>
              ))}
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Sessions List */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Sessions */}
        <Card>
          <CardHeader>
            <CardTitle>Voice Sessions ({filteredSessions.length})</CardTitle>
            <CardDescription>
              Click on a session to view details
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3 max-h-96 overflow-y-auto">
              {filteredSessions.map((session, index) => (
                <motion.div
                  key={session.id}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: index * 0.05 }}
                  className={`p-4 border rounded-lg cursor-pointer transition-colors ${
                    selectedSession?.id === session.id
                      ? 'border-primary bg-primary/5'
                      : 'hover:bg-muted/50'
                  }`}
                  onClick={() => setSelectedSession(session)}
                >
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <div className="flex items-center space-x-2 mb-2">
                        {getStatusIcon(session.sessionStatus)}
                        <p className="font-medium">
                          {session.sessionName || `Session ${session.id.slice(0, 8)}`}
                        </p>
                        {getStatusBadge(session.sessionStatus)}
                      </div>
                      
                      <div className="text-sm text-muted-foreground space-y-1">
                        <p className="flex items-center space-x-1">
                          <User className="h-3 w-3" />
                          <span>{session.user?.fullName || 'Unknown User'}</span>
                        </p>
                        <p className="flex items-center space-x-1">
                          <Clock className="h-3 w-3" />
                          <span>{formatDuration(session.totalDurationSeconds)}</span>
                        </p>
                        <p className="flex items-center space-x-1">
                          <MessageSquare className="h-3 w-3" />
                          <span>{session.voiceCommands?.length || 0} commands</span>
                        </p>
                        <p className="text-xs">
                          Started: {new Date(session.startedAt).toLocaleString()}
                        </p>
                      </div>
                    </div>
                  </div>
                </motion.div>
              ))}

              {filteredSessions.length === 0 && (
                <div className="text-center py-8">
                  <Activity className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
                  <p className="text-muted-foreground">No sessions found</p>
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Session Details */}
        {selectedSession ? (
          <Card>
            <CardHeader>
              <CardTitle>Session Details</CardTitle>
              <CardDescription>
                {selectedSession.sessionName || `Session ${selectedSession.id.slice(0, 8)}`}
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <p className="font-medium">Status</p>
                  <div className="flex items-center space-x-2">
                    {getStatusIcon(selectedSession.sessionStatus)}
                    {getStatusBadge(selectedSession.sessionStatus)}
                  </div>
                </div>
                <div>
                  <p className="font-medium">User</p>
                  <p className="text-muted-foreground">
                    {selectedSession.user?.fullName || 'Unknown'}
                  </p>
                </div>
                <div>
                  <p className="font-medium">Duration</p>
                  <p className="text-muted-foreground">
                    {formatDuration(selectedSession.totalDurationSeconds)}
                  </p>
                </div>
                <div>
                  <p className="font-medium">Commands</p>
                  <p className="text-muted-foreground">
                    {selectedSession.voiceCommands?.length || 0}
                  </p>
                </div>
                <div>
                  <p className="font-medium">Total Cost</p>
                  <p className="text-muted-foreground">
                    ${selectedSession.totalCost.toFixed(4)}
                  </p>
                </div>
                <div>
                  <p className="font-medium">Tokens Used</p>
                  <p className="text-muted-foreground">
                    {selectedSession.totalTokensUsed.toLocaleString()}
                  </p>
                </div>
              </div>

              <div>
                <p className="font-medium mb-2">Configuration</p>
                <div className="text-sm text-muted-foreground space-y-1">
                  <p>Language: {selectedSession.languageCode}</p>
                  <p>Wake Word: {selectedSession.wakeWord || 'None'}</p>
                  <p>Voice Feedback: {selectedSession.voiceFeedbackEnabled ? 'Enabled' : 'Disabled'}</p>
                  <p>Screen Monitoring: {selectedSession.screenMonitoringEnabled ? 'Enabled' : 'Disabled'}</p>
                  <p>Continuous Listening: {selectedSession.continuousListening ? 'Enabled' : 'Disabled'}</p>
                </div>
              </div>

              <div>
                <p className="font-medium mb-2">Recent Commands</p>
                <div className="space-y-2 max-h-40 overflow-y-auto">
                  {selectedSession.voiceCommands?.slice(0, 5).map((command) => (
                    <div key={command.id} className="text-sm p-2 bg-muted rounded">
                      <p className="font-medium">{command.commandText}</p>
                      <p className="text-xs text-muted-foreground">
                        {new Date(command.createdAt).toLocaleTimeString()}
                      </p>
                    </div>
                  )) || (
                    <p className="text-sm text-muted-foreground">No commands yet</p>
                  )}
                </div>
              </div>
            </CardContent>
          </Card>
        ) : (
          <Card>
            <CardContent className="p-8">
              <div className="text-center text-muted-foreground">
                <Activity className="h-12 w-12 mx-auto mb-4" />
                <p>Select a session to view details</p>
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  );
}
