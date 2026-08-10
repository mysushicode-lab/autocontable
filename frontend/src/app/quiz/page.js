import { HOME_METADATA } from '@/lib/seo/pages-metadata';
import QuizPage from './QuizPage';

export const metadata = {
  ...HOME_METADATA,
  title: 'Diagnostic Comptabilité - Combien de temps perdez-vous ? | Autocontable',
  description: 'Découvrez en 2 minutes combien de temps et d\'argent votre comptabilité vous fait perdre. Quiz gratuit + guide offert.',
};

export default function Quiz() {
  return <QuizPage />;
}
