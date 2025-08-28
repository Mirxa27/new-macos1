'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { motion, AnimatePresence } from 'framer-motion';
import { 
  ArrowRight, 
  Mic, 
  MessageSquare, 
  Zap, 
  Shield, 
  Globe, 
  BarChart,
  ChevronDown,
  Play,
  Users,
  Sparkles,
  Check,
  Star
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';

const features = [
  {
    icon: Mic,
    title: 'Real-time Voice Processing',
    description: 'Advanced speech recognition and synthesis with ultra-low latency for natural conversations.',
  },
  {
    icon: MessageSquare,
    title: 'Multi-Modal Interactions',
    description: 'Seamlessly switch between voice, text, and visual inputs for flexible communication.',
  },
  {
    icon: Zap,
    title: 'Lightning Fast Response',
    description: 'Optimized AI models deliver instant responses with sub-second latency.',
  },
  {
    icon: Shield,
    title: 'Enterprise Security',
    description: 'Bank-grade encryption and compliance with GDPR, HIPAA, and SOC 2 standards.',
  },
  {
    icon: Globe,
    title: 'Global Language Support',
    description: 'Support for 100+ languages with automatic detection and translation.',
  },
  {
    icon: BarChart,
    title: 'Advanced Analytics',
    description: 'Deep insights into conversations, sentiment analysis, and performance metrics.',
  },
];

const pricingPlans = [
  {
    name: 'Free',
    price: '$0',
    period: 'forever',
    description: 'Perfect for trying out our platform',
    features: [
      '1 Voice Agent',
      '100 conversations/month',
      'Basic analytics',
      'Community support',
      'Standard voices',
    ],
    cta: 'Start Free',
    highlighted: false,
  },
  {
    name: 'Starter',
    price: '$49',
    period: '/month',
    description: 'Ideal for small teams and projects',
    features: [
      '5 Voice Agents',
      '1,000 conversations/month',
      'Advanced analytics',
      'Priority support',
      'Premium voices',
      'Custom branding',
      'API access',
    ],
    cta: 'Start Trial',
    highlighted: true,
  },
  {
    name: 'Professional',
    price: '$199',
    period: '/month',
    description: 'For growing businesses',
    features: [
      '20 Voice Agents',
      '10,000 conversations/month',
      'Real-time analytics',
      '24/7 phone support',
      'All voice options',
      'White labeling',
      'Advanced API access',
      'Custom integrations',
      'SLA guarantee',
    ],
    cta: 'Start Trial',
    highlighted: false,
  },
  {
    name: 'Enterprise',
    price: 'Custom',
    period: 'pricing',
    description: 'Tailored for large organizations',
    features: [
      'Unlimited Voice Agents',
      'Unlimited conversations',
      'Custom analytics',
      'Dedicated support team',
      'Custom voice cloning',
      'On-premise deployment',
      'Custom AI models',
      'Compliance packages',
      'Custom SLA',
    ],
    cta: 'Contact Sales',
    highlighted: false,
  },
];

const testimonials = [
  {
    name: 'Sarah Chen',
    role: 'CTO at TechCorp',
    content: 'The voice agents have transformed our customer service. Response times are down 70% and satisfaction is up 45%.',
    rating: 5,
    avatar: 'SC',
  },
  {
    name: 'Michael Rodriguez',
    role: 'Product Manager at InnovateCo',
    content: 'Incredibly easy to integrate and the quality of voice interactions is unmatched. Our users love it!',
    rating: 5,
    avatar: 'MR',
  },
  {
    name: 'Emily Watson',
    role: 'CEO at StartupX',
    content: 'The analytics dashboard provides insights we never had before. It\'s been a game-changer for our business.',
    rating: 5,
    avatar: 'EW',
  },
];

export default function HomePage() {
  const [isScrolled, setIsScrolled] = useState(false);
  const [activeFeature, setActiveFeature] = useState(0);

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 20);
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  useEffect(() => {
    const interval = setInterval(() => {
      setActiveFeature((prev) => (prev + 1) % features.length);
    }, 3000);

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="min-h-screen bg-gradient-to-b from-background to-muted/20">
      {/* Navigation */}
      <nav className={`fixed top-0 w-full z-50 transition-all duration-300 ${
        isScrolled ? 'bg-background/95 backdrop-blur-md border-b' : 'bg-transparent'
      }`}>
        <div className="container-responsive flex items-center justify-between h-16 sm:h-20">
          <div className="flex items-center space-x-2">
            <Mic className="h-6 w-6 sm:h-8 sm:w-8 text-primary" />
            <span className="text-lg sm:text-xl font-bold">Voice Agent</span>
          </div>
          
          <div className="hidden md:flex items-center space-x-8">
            <Link href="#features" className="text-sm font-medium hover:text-primary transition-colors">
              Features
            </Link>
            <Link href="#pricing" className="text-sm font-medium hover:text-primary transition-colors">
              Pricing
            </Link>
            <Link href="#testimonials" className="text-sm font-medium hover:text-primary transition-colors">
              Testimonials
            </Link>
            <Link href="/docs" className="text-sm font-medium hover:text-primary transition-colors">
              Documentation
            </Link>
          </div>

          <div className="flex items-center space-x-2 sm:space-x-4">
            <Link href="/login">
              <Button variant="ghost" size="sm" className="hidden sm:inline-flex">
                Sign In
              </Button>
            </Link>
            <Link href="/register">
              <Button size="sm" className="btn-responsive">
                Get Started
                <ArrowRight className="ml-2 h-4 w-4" />
              </Button>
            </Link>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="pt-24 sm:pt-32 pb-12 sm:pb-20 px-4">
        <div className="container-responsive">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            className="text-center max-w-4xl mx-auto"
          >
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-primary/10 text-primary text-xs sm:text-sm font-medium mb-4 sm:mb-6">
              <Sparkles className="h-3 w-3 sm:h-4 sm:w-4" />
              <span>Powered by GPT-4 & Claude 3</span>
            </div>
            
            <h1 className="text-4xl sm:text-5xl md:text-6xl lg:text-7xl font-bold mb-4 sm:mb-6 bg-gradient-to-r from-primary to-primary/60 bg-clip-text text-transparent">
              Build Intelligent Voice Agents in Minutes
            </h1>
            
            <p className="text-lg sm:text-xl md:text-2xl text-muted-foreground mb-6 sm:mb-8 max-w-2xl mx-auto">
              Create, deploy, and manage AI-powered voice agents that understand context, speak naturally, and scale infinitely.
            </p>

            <div className="flex flex-col sm:flex-row items-center justify-center gap-3 sm:gap-4 mb-8 sm:mb-12">
              <Link href="/register">
                <Button size="lg" className="w-full sm:w-auto text-base sm:text-lg px-6 sm:px-8 py-5 sm:py-6">
                  Start Free Trial
                  <ArrowRight className="ml-2 h-5 w-5" />
                </Button>
              </Link>
              <Link href="/demo">
                <Button size="lg" variant="outline" className="w-full sm:w-auto text-base sm:text-lg px-6 sm:px-8 py-5 sm:py-6">
                  <Play className="mr-2 h-5 w-5" />
                  Watch Demo
                </Button>
              </Link>
            </div>

            <div className="flex flex-wrap items-center justify-center gap-4 sm:gap-8 text-sm text-muted-foreground">
              <div className="flex items-center gap-2">
                <Users className="h-4 w-4" />
                <span>10,000+ Users</span>
              </div>
              <div className="flex items-center gap-2">
                <Star className="h-4 w-4 text-yellow-500" />
                <span>4.9/5 Rating</span>
              </div>
              <div className="flex items-center gap-2">
                <Globe className="h-4 w-4" />
                <span>100+ Countries</span>
              </div>
            </div>
          </motion.div>

          {/* Interactive Demo */}
          <motion.div
            initial={{ opacity: 0, y: 40 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.2 }}
            className="mt-12 sm:mt-20"
          >
            <Card className="p-4 sm:p-8 bg-gradient-to-br from-primary/5 to-primary/10 border-primary/20">
              <div className="aspect-video rounded-lg bg-black/5 flex items-center justify-center">
                <div className="text-center">
                  <div className="inline-flex items-center justify-center w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-primary/20 mb-4">
                    <Mic className="h-8 w-8 sm:h-10 sm:w-10 text-primary animate-pulse" />
                  </div>
                  <p className="text-sm sm:text-base text-muted-foreground">Interactive demo coming soon</p>
                </div>
              </div>
            </Card>
          </motion.div>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="py-12 sm:py-20 px-4 bg-muted/30">
        <div className="container-responsive">
          <motion.div
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            transition={{ duration: 0.5 }}
            viewport={{ once: true }}
            className="text-center mb-8 sm:mb-12"
          >
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4">
              Everything You Need to Build Voice AI
            </h2>
            <p className="text-lg sm:text-xl text-muted-foreground max-w-2xl mx-auto">
              Powerful features designed for developers, loved by businesses
            </p>
          </motion.div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6">
            <AnimatePresence mode="wait">
              {features.map((feature, index) => (
                <motion.div
                  key={index}
                  initial={{ opacity: 0, y: 20 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  transition={{ duration: 0.5, delay: index * 0.1 }}
                  viewport={{ once: true }}
                  whileHover={{ scale: 1.02 }}
                  className={`group`}
                >
                  <Card className={`p-4 sm:p-6 h-full transition-all duration-300 hover:shadow-lg hover:border-primary/50 ${
                    activeFeature === index ? 'border-primary bg-primary/5' : ''
                  }`}>
                    <div className="flex items-start space-x-4">
                      <div className={`flex-shrink-0 w-12 h-12 rounded-lg flex items-center justify-center transition-colors ${
                        activeFeature === index ? 'bg-primary text-primary-foreground' : 'bg-primary/10 text-primary'
                      }`}>
                        <feature.icon className="h-6 w-6" />
                      </div>
                      <div className="flex-1">
                        <h3 className="text-lg font-semibold mb-2">{feature.title}</h3>
                        <p className="text-sm text-muted-foreground">{feature.description}</p>
                      </div>
                    </div>
                  </Card>
                </motion.div>
              ))}
            </AnimatePresence>
          </div>
        </div>
      </section>

      {/* Pricing Section */}
      <section id="pricing" className="py-12 sm:py-20 px-4">
        <div className="container-responsive">
          <motion.div
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            transition={{ duration: 0.5 }}
            viewport={{ once: true }}
            className="text-center mb-8 sm:mb-12"
          >
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4">
              Simple, Transparent Pricing
            </h2>
            <p className="text-lg sm:text-xl text-muted-foreground max-w-2xl mx-auto">
              Choose the perfect plan for your needs. Always flexible to scale.
            </p>
          </motion.div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
            {pricingPlans.map((plan, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5, delay: index * 0.1 }}
                viewport={{ once: true }}
              >
                <Card className={`p-4 sm:p-6 h-full flex flex-col ${
                  plan.highlighted ? 'border-primary shadow-lg scale-105' : ''
                }`}>
                  {plan.highlighted && (
                    <div className="inline-flex items-center justify-center px-3 py-1 rounded-full bg-primary text-primary-foreground text-xs font-medium mb-4">
                      Most Popular
                    </div>
                  )}
                  <div className="mb-4">
                    <h3 className="text-xl font-bold mb-2">{plan.name}</h3>
                    <div className="flex items-baseline mb-2">
                      <span className="text-3xl font-bold">{plan.price}</span>
                      <span className="text-muted-foreground ml-2">{plan.period}</span>
                    </div>
                    <p className="text-sm text-muted-foreground">{plan.description}</p>
                  </div>
                  
                  <ul className="space-y-2 mb-6 flex-1">
                    {plan.features.map((feature, featureIndex) => (
                      <li key={featureIndex} className="flex items-start">
                        <Check className="h-4 w-4 text-primary mt-0.5 mr-2 flex-shrink-0" />
                        <span className="text-sm">{feature}</span>
                      </li>
                    ))}
                  </ul>
                  
                  <Link href="/register" className="w-full">
                    <Button 
                      className="w-full" 
                      variant={plan.highlighted ? 'default' : 'outline'}
                    >
                      {plan.cta}
                    </Button>
                  </Link>
                </Card>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Testimonials Section */}
      <section id="testimonials" className="py-12 sm:py-20 px-4 bg-muted/30">
        <div className="container-responsive">
          <motion.div
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            transition={{ duration: 0.5 }}
            viewport={{ once: true }}
            className="text-center mb-8 sm:mb-12"
          >
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4">
              Loved by Teams Worldwide
            </h2>
            <p className="text-lg sm:text-xl text-muted-foreground max-w-2xl mx-auto">
              See what our customers have to say about their experience
            </p>
          </motion.div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 sm:gap-6">
            {testimonials.map((testimonial, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5, delay: index * 0.1 }}
                viewport={{ once: true }}
              >
                <Card className="p-4 sm:p-6 h-full">
                  <div className="flex items-center mb-4">
                    {[...Array(testimonial.rating)].map((_, i) => (
                      <Star key={i} className="h-4 w-4 text-yellow-500 fill-current" />
                    ))}
                  </div>
                  <p className="text-sm sm:text-base mb-4">&ldquo;{testimonial.content}&rdquo;</p>
                  <div className="flex items-center">
                    <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center mr-3">
                      <span className="text-sm font-medium">{testimonial.avatar}</span>
                    </div>
                    <div>
                      <p className="text-sm font-semibold">{testimonial.name}</p>
                      <p className="text-xs text-muted-foreground">{testimonial.role}</p>
                    </div>
                  </div>
                </Card>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-12 sm:py-20 px-4">
        <div className="container-responsive">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            viewport={{ once: true }}
            className="text-center max-w-3xl mx-auto"
          >
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4">
              Ready to Transform Your Business?
            </h2>
            <p className="text-lg sm:text-xl text-muted-foreground mb-6 sm:mb-8">
              Join thousands of companies using Voice Agent to deliver exceptional customer experiences.
            </p>
            <div className="flex flex-col sm:flex-row items-center justify-center gap-3 sm:gap-4">
              <Link href="/register">
                <Button size="lg" className="w-full sm:w-auto text-base sm:text-lg px-6 sm:px-8 py-5 sm:py-6">
                  Start Your Free Trial
                  <ArrowRight className="ml-2 h-5 w-5" />
                </Button>
              </Link>
              <Link href="/contact">
                <Button size="lg" variant="outline" className="w-full sm:w-auto text-base sm:text-lg px-6 sm:px-8 py-5 sm:py-6">
                  Talk to Sales
                </Button>
              </Link>
            </div>
          </motion.div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t py-8 sm:py-12 px-4">
        <div className="container-responsive">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-6 sm:gap-8 mb-8">
            <div className="col-span-2 md:col-span-1">
              <div className="flex items-center space-x-2 mb-4">
                <Mic className="h-6 w-6 text-primary" />
                <span className="text-lg font-bold">Voice Agent</span>
              </div>
              <p className="text-sm text-muted-foreground">
                Building the future of voice AI, one conversation at a time.
              </p>
            </div>
            
            <div>
              <h4 className="font-semibold mb-3">Product</h4>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li><Link href="/features" className="hover:text-primary">Features</Link></li>
                <li><Link href="/pricing" className="hover:text-primary">Pricing</Link></li>
                <li><Link href="/docs" className="hover:text-primary">Documentation</Link></li>
                <li><Link href="/api" className="hover:text-primary">API Reference</Link></li>
              </ul>
            </div>
            
            <div>
              <h4 className="font-semibold mb-3">Company</h4>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li><Link href="/about" className="hover:text-primary">About</Link></li>
                <li><Link href="/blog" className="hover:text-primary">Blog</Link></li>
                <li><Link href="/careers" className="hover:text-primary">Careers</Link></li>
                <li><Link href="/contact" className="hover:text-primary">Contact</Link></li>
              </ul>
            </div>
            
            <div>
              <h4 className="font-semibold mb-3">Legal</h4>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li><Link href="/privacy" className="hover:text-primary">Privacy Policy</Link></li>
                <li><Link href="/terms" className="hover:text-primary">Terms of Service</Link></li>
                <li><Link href="/security" className="hover:text-primary">Security</Link></li>
                <li><Link href="/compliance" className="hover:text-primary">Compliance</Link></li>
              </ul>
            </div>
          </div>
          
          <div className="border-t pt-8 flex flex-col sm:flex-row items-center justify-between text-sm text-muted-foreground">
            <p>&copy; 2024 Voice Agent Platform. All rights reserved.</p>
            <div className="flex items-center space-x-4 mt-4 sm:mt-0">
              <Link href="https://twitter.com" className="hover:text-primary">Twitter</Link>
              <Link href="https://github.com" className="hover:text-primary">GitHub</Link>
              <Link href="https://linkedin.com" className="hover:text-primary">LinkedIn</Link>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}