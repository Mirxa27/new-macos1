'use client';

import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  Bot,
  Plus,
  Settings,
  Eye,
  EyeOff,
  Save,
  TestTube,
  CheckCircle,
  XCircle,
  Edit,
} from 'lucide-react';
import { motion } from 'framer-motion';
import { AiProvider, AiModel } from '@/types';
import toast from 'react-hot-toast';

export function AIProviderSettings() {
  const [providers, setProviders] = useState<AiProvider[]>([]);
  const [selectedProvider, setSelectedProvider] = useState<AiProvider | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [showApiKey, setShowApiKey] = useState<{ [key: string]: boolean }>({});
  const [isTestingConnection, setIsTestingConnection] = useState(false);

  useEffect(() => {
    fetchProviders();
  }, []);

  const fetchProviders = async () => {
    try {
      const response = await fetch('/api/admin/providers');
      if (response.ok) {
        const data = await response.json();
        setProviders(data.providers || []);
        if (data.providers?.length > 0) {
          setSelectedProvider(data.providers[0]);
        }
      }
    } catch (error) {
      console.error('Failed to fetch providers:', error);
      toast.error('Failed to load AI providers');
    } finally {
      setIsLoading(false);
    }
  };

  const updateProvider = async (provider: AiProvider) => {
    try {
      const response = await fetch(`/api/admin/providers/${provider.id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(provider),
      });

      if (response.ok) {
        const updatedProvider = await response.json();
        setProviders(providers.map(p => 
          p.id === provider.id ? updatedProvider : p
        ));
        setSelectedProvider(updatedProvider);
        toast.success('Provider updated successfully');
      } else {
        throw new Error('Failed to update provider');
      }
    } catch (error) {
      console.error('Failed to update provider:', error);
      toast.error('Failed to update provider');
    }
  };

  const testConnection = async (providerId: string) => {
    setIsTestingConnection(true);
    try {
      const response = await fetch(`/api/admin/providers/${providerId}/test`, {
        method: 'POST',
      });

      if (response.ok) {
        const result = await response.json();
        if (result.success) {
          toast.success('Connection test successful!');
        } else {
          toast.error(`Connection test failed: ${result.error}`);
        }
      } else {
        throw new Error('Connection test failed');
      }
    } catch (error) {
      console.error('Connection test failed:', error);
      toast.error('Connection test failed');
    } finally {
      setIsTestingConnection(false);
    }
  };

  const toggleApiKeyVisibility = (providerId: string) => {
    setShowApiKey(prev => ({
      ...prev,
      [providerId]: !prev[providerId]
    }));
  };

  const getProviderIcon = (type: string) => {
    // In a real app, you'd have specific icons for each provider
    return Bot;
  };

  const getStatusBadge = (isEnabled: boolean) => {
    return isEnabled ? (
      <Badge variant="default" className="flex items-center space-x-1">
        <CheckCircle className="h-3 w-3" />
        <span>Enabled</span>
      </Badge>
    ) : (
      <Badge variant="secondary" className="flex items-center space-x-1">
        <XCircle className="h-3 w-3" />
        <span>Disabled</span>
      </Badge>
    );
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
          <h2 className="text-2xl font-bold">AI Provider Settings</h2>
          <p className="text-muted-foreground">Configure AI providers and their models</p>
        </div>
        <Button className="mobile-touch-target">
          <Plus className="h-4 w-4 mr-2" />
          Add Provider
        </Button>
      </div>

      <Tabs defaultValue="providers" className="space-y-6">
        <TabsList className="grid w-full grid-cols-3">
          <TabsTrigger value="providers">Providers</TabsTrigger>
          <TabsTrigger value="models">Models</TabsTrigger>
          <TabsTrigger value="settings">Global Settings</TabsTrigger>
        </TabsList>

        <TabsContent value="providers" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Provider List */}
            <Card>
              <CardHeader>
                <CardTitle>AI Providers</CardTitle>
                <CardDescription>
                  Configure your AI service providers
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                {providers.map((provider, index) => {
                  const ProviderIcon = getProviderIcon(provider.providerType);
                  return (
                    <motion.div
                      key={provider.id}
                      initial={{ opacity: 0, x: -20 }}
                      animate={{ opacity: 1, x: 0 }}
                      transition={{ delay: index * 0.1 }}
                      className={`p-4 border rounded-lg cursor-pointer transition-colors ${
                        selectedProvider?.id === provider.id
                          ? 'border-primary bg-primary/5'
                          : 'hover:bg-muted/50'
                      }`}
                      onClick={() => setSelectedProvider(provider)}
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-3">
                          <ProviderIcon className="h-8 w-8 text-primary" />
                          <div>
                            <p className="font-medium">{provider.name}</p>
                            <p className="text-sm text-muted-foreground">
                              {provider.providerType}
                            </p>
                          </div>
                        </div>
                        <div className="flex items-center space-x-2">
                          {getStatusBadge(provider.isEnabled)}
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={(e) => {
                              e.stopPropagation();
                              testConnection(provider.id);
                            }}
                            disabled={isTestingConnection}
                            className="mobile-touch-target"
                          >
                            <TestTube className="h-4 w-4" />
                          </Button>
                        </div>
                      </div>
                    </motion.div>
                  );
                })}
              </CardContent>
            </Card>

            {/* Provider Configuration */}
            {selectedProvider && (
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center space-x-2">
                    <Edit className="h-5 w-5" />
                    <span>Configure {selectedProvider.name}</span>
                  </CardTitle>
                  <CardDescription>
                    Update provider settings and API configuration
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="provider-name">Provider Name</Label>
                    <Input
                      id="provider-name"
                      value={selectedProvider.name}
                      onChange={(e) => setSelectedProvider({
                        ...selectedProvider,
                        name: e.target.value
                      })}
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="base-url">Base URL</Label>
                    <Input
                      id="base-url"
                      value={selectedProvider.baseUrl || ''}
                      onChange={(e) => setSelectedProvider({
                        ...selectedProvider,
                        baseUrl: e.target.value
                      })}
                      placeholder="https://api.provider.com"
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="api-key">API Key</Label>
                    <div className="relative">
                      <Input
                        id="api-key"
                        type={showApiKey[selectedProvider.id] ? 'text' : 'password'}
                        value={selectedProvider.apiKeyEncrypted || ''}
                        onChange={(e) => setSelectedProvider({
                          ...selectedProvider,
                          apiKeyEncrypted: e.target.value
                        })}
                        placeholder="Enter API key"
                      />
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        className="absolute right-0 top-0 h-full px-3"
                        onClick={() => toggleApiKeyVisibility(selectedProvider.id)}
                      >
                        {showApiKey[selectedProvider.id] ? (
                          <EyeOff className="h-4 w-4" />
                        ) : (
                          <Eye className="h-4 w-4" />
                        )}
                      </Button>
                    </div>
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="default-model">Default Model</Label>
                    <Input
                      id="default-model"
                      value={selectedProvider.defaultModel || ''}
                      onChange={(e) => setSelectedProvider({
                        ...selectedProvider,
                        defaultModel: e.target.value
                      })}
                      placeholder="gpt-4"
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="max-tokens">Max Tokens</Label>
                      <Input
                        id="max-tokens"
                        type="number"
                        value={selectedProvider.maxTokens}
                        onChange={(e) => setSelectedProvider({
                          ...selectedProvider,
                          maxTokens: parseInt(e.target.value) || 4000
                        })}
                      />
                    </div>

                    <div className="space-y-2">
                      <Label htmlFor="temperature">Temperature</Label>
                      <Input
                        id="temperature"
                        type="number"
                        step="0.1"
                        min="0"
                        max="2"
                        value={selectedProvider.temperature}
                        onChange={(e) => setSelectedProvider({
                          ...selectedProvider,
                          temperature: parseFloat(e.target.value) || 0.7
                        })}
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="timeout">Timeout (seconds)</Label>
                      <Input
                        id="timeout"
                        type="number"
                        value={selectedProvider.timeoutSeconds}
                        onChange={(e) => setSelectedProvider({
                          ...selectedProvider,
                          timeoutSeconds: parseInt(e.target.value) || 30
                        })}
                      />
                    </div>

                    <div className="space-y-2">
                      <Label htmlFor="rate-limit">Rate Limit (per minute)</Label>
                      <Input
                        id="rate-limit"
                        type="number"
                        value={selectedProvider.rateLimitPerMinute}
                        onChange={(e) => setSelectedProvider({
                          ...selectedProvider,
                          rateLimitPerMinute: parseInt(e.target.value) || 60
                        })}
                      />
                    </div>
                  </div>

                  <div className="flex items-center space-x-4">
                    <label className="flex items-center space-x-2 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={selectedProvider.supportsVision}
                        onChange={(e) => setSelectedProvider({
                          ...selectedProvider,
                          supportsVision: e.target.checked
                        })}
                        className="rounded"
                      />
                      <span className="text-sm">Supports Vision</span>
                    </label>

                    <label className="flex items-center space-x-2 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={selectedProvider.supportsAudio}
                        onChange={(e) => setSelectedProvider({
                          ...selectedProvider,
                          supportsAudio: e.target.checked
                        })}
                        className="rounded"
                      />
                      <span className="text-sm">Supports Audio</span>
                    </label>

                    <label className="flex items-center space-x-2 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={selectedProvider.isEnabled}
                        onChange={(e) => setSelectedProvider({
                          ...selectedProvider,
                          isEnabled: e.target.checked
                        })}
                        className="rounded"
                      />
                      <span className="text-sm">Enabled</span>
                    </label>
                  </div>

                  <div className="flex space-x-3 pt-4">
                    <Button
                      onClick={() => updateProvider(selectedProvider)}
                      className="flex-1 mobile-touch-target"
                    >
                      <Save className="h-4 w-4 mr-2" />
                      Save Changes
                    </Button>
                    <Button
                      variant="outline"
                      onClick={() => testConnection(selectedProvider.id)}
                      disabled={isTestingConnection}
                      className="mobile-touch-target"
                    >
                      <TestTube className="h-4 w-4 mr-2" />
                      Test
                    </Button>
                  </div>
                </CardContent>
              </Card>
            )}
          </div>
        </TabsContent>

        <TabsContent value="models" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>AI Models</CardTitle>
              <CardDescription>
                Manage available models for each provider
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="text-center py-8">
                <Bot className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
                <p className="text-muted-foreground">Model management interface</p>
                <p className="text-sm text-muted-foreground">
                  Configure available models, pricing, and capabilities
                </p>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="settings" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Global AI Settings</CardTitle>
              <CardDescription>
                System-wide AI configuration and defaults
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="text-center py-8">
                <Settings className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
                <p className="text-muted-foreground">Global settings interface</p>
                <p className="text-sm text-muted-foreground">
                  Configure default providers, fallback options, and system limits
                </p>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
