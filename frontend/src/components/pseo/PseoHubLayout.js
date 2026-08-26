import Link from 'next/link';
import { Roboto, Roboto_Slab } from 'next/font/google';
import LandingHeader from '@/views/landing/LandingHeader';
import Footer from '@/views/landing/Footer';
import { getPseoImageUrl } from '@/lib/pseo/pseo-images';

const roboto = Roboto({ subsets: ['latin'], weight: ['300', '400', '500', '700'], display: 'swap' });
const robotoSlab = Roboto_Slab({ subsets: ['latin'], weight: ['400', '700', '800'], display: 'swap' });


export default function PseoHubLayout({ title, description, badge, pages }) {
  return (
    <div style={roboto.style}>
      <LandingHeader />

      <main>

        {/* Hero */}
        <section style={{ background: '#f5f5f5', padding: '80px 24px 60px', textAlign: 'center' }}>
          <div style={{ maxWidth: 700, margin: '0 auto' }}>
            <span
              style={{
                display: 'inline-block',
                padding: '4px 14px',
                fontSize: 12,
                border: '1px solid #e5e5e5',
                borderRadius: 20,
                color: '#646464',
                marginBottom: 20,
                background: '#fff',
              }}
            >
              {badge}
            </span>
            <h1
              style={{
                ...robotoSlab.style,
                fontSize: 'clamp(26px, 4vw, 42px)',
                fontWeight: 800,
                color: '#000',
                lineHeight: 1.3,
                marginBottom: 20,
                marginTop: 0,
              }}
            >
              {title}
            </h1>
            <p style={{ fontSize: 16, color: '#646464', lineHeight: 1.7, maxWidth: 560, margin: '0 auto' }}>
              {description}
            </p>
          </div>
        </section>

        {/* Post grid — 2 colonnes comme le template Home One */}
        <section style={{ maxWidth: 1250, margin: '0 auto', padding: '80px 24px 100px' }}>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))',
              gap: '60px 40px',
            }}
          >
            {pages.map((page) => {

              return (
                <div key={page.slug} className="entry-post">

                  {/* Thumbnail */}
                  <Link href={page.slug} style={{ display: 'block', marginBottom: 24, textDecoration: 'none' }}>
                    <div style={{ width: '100%', height: 220, borderRadius: 4, overflow: 'hidden', backgroundColor: '#f5f5f5' }}>
                      <img
                        src={getPseoImageUrl(page.data?.slug_key ?? page.slug, 600, 300)}
                        alt={page.title}
                        style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block', transition: 'transform 0.3s ease' }}
                        className="hover:scale-105"
                      />
                    </div>
                  </Link>

                  {/* Content */}
                  <div className="entry-content">
                    <h2 style={{ marginBottom: 14, marginTop: 0 }}>
                      <Link
                        href={page.slug}
                        style={{
                          ...robotoSlab.style,
                          fontSize: 20,
                          fontWeight: 800,
                          color: '#000',
                          lineHeight: 1.4,
                          textDecoration: 'none',
                        }}
                        className="hover:opacity-70 transition-opacity"
                      >
                        {page.title}
                      </Link>
                    </h2>

                    {/* Meta */}
                    <div style={{ display: 'flex', gap: 8, fontSize: 13, color: '#646464', marginBottom: 14, flexWrap: 'wrap' }}>
                      <span>2025</span>
                      <span>·</span>
                      <span style={{ color: '#466cf3' }}>{page.data?.slug_key_label || badge}</span>
                    </div>

                    <p style={{ fontSize: 14, color: '#646464', lineHeight: 1.7, marginBottom: 16, marginTop: 0 }}>
                      {page.description}
                    </p>

                    <Link
                      href={page.slug}
                      style={{
                        ...robotoSlab.style,
                        fontSize: 14,
                        fontWeight: 700,
                        color: '#000',
                        textDecoration: 'none',
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 6,
                      }}
                      className="hover:opacity-60 transition-opacity"
                    >
                      Lire l&apos;article <span style={{ fontSize: 16 }}>→</span>
                    </Link>
                  </div>

                </div>
              );
            })}
          </div>
        </section>

      </main>

      <Footer />
    </div>
  );
}
