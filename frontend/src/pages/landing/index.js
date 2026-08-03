import { useAuth } from '../../context/AuthContext';
import LandingHeader from './LandingHeader';
import HeroSection from './HeroSection';
import FeaturesSection from './FeaturesSection';
import ToolsSection from './ToolsSection';
import CoreFeaturesSection from './CoreFeaturesSection';
import ReformeSection from './ReformeSection';
import PricingSection from '../../components/landing/PricingSection';
import TestimonialsSection from './TestimonialsSection';
import VideoSection from './VideoSection';
import FAQSection from './FAQSection';
import CTASection from './CTASection';
import Footer from './Footer';

export default function Landing() {
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
