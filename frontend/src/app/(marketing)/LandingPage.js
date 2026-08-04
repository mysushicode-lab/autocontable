'use client';

import LandingHeader from '@/views/landing/LandingHeader';
import HeroSection from '@/views/landing/HeroSection';
import FeaturesSection from '@/views/landing/FeaturesSection';
import ToolsSection from '@/views/landing/ToolsSection';
import CoreFeaturesSection from '@/views/landing/CoreFeaturesSection';
import ReformeSection from '@/views/landing/ReformeSection';
import TestimonialsSection from '@/views/landing/TestimonialsSection';
import PricingSection from '@/components/landing/PricingSection';
import VideoSection from '@/views/landing/VideoSection';
import FAQSection from '@/views/landing/FAQSection';
import CTASection from '@/views/landing/CTASection';
import Footer from '@/views/landing/Footer';
import { useAuth } from '@/context/AuthContext';

export default function LandingPage() {
  const { user, logout } = useAuth();

  return (
    <div className="min-h-screen flex flex-col bg-white">
      <LandingHeader isAuthenticated={!!user} onLogout={logout} />
      <main className="flex-1">
        <HeroSection />
        <FeaturesSection />
        <ToolsSection />
        <CoreFeaturesSection />
        <ReformeSection />
        <TestimonialsSection />
        <PricingSection />
        <VideoSection />
        <FAQSection />
        <CTASection />
      </main>
      <Footer />
    </div>
  );
}
