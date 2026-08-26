import Link from 'next/link';
import { Roboto, Roboto_Slab } from 'next/font/google';
import LandingHeader from '@/views/landing/LandingHeader';
import Footer from '@/views/landing/Footer';
import { getPseoContent } from '@/lib/pseo/pseo-content';
import { getPseoImageUrl } from '@/lib/pseo/pseo-images';
import PseoFaq from './PseoFaq';

// ---------------------------------------------------------------------------
// Fonts
// ---------------------------------------------------------------------------

const roboto = Roboto({
  subsets: ['latin'],
  weight: ['300', '400', '500', '700'],
  display: 'swap',
});

const robotoSlab = Roboto_Slab({
  subsets: ['latin'],
  weight: ['400', '600', '700', '800'],
  display: 'swap',
});

// ---------------------------------------------------------------------------
// Hub routing map
// ---------------------------------------------------------------------------

const HUB_PATHS = {
  industry:   { href: '/comptabilite', label: 'Secteurs' },
  'use-case': { href: '/cas-usage',    label: "Cas d'usage" },
  comparison: { href: '/compare',      label: 'Comparatifs' },
};

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export default function PseoPageLayout({ page }) {
  const content = getPseoContent(page);
  const hub = HUB_PATHS[page.kind] ?? { href: '/', label: 'Hub' };
  const competitorName = page.data?.slug_key_label ?? '';

  const widgetTitleStyle = {
    ...robotoSlab.style,
    fontSize: 18,
    fontWeight: 800,
    color: '#000',
    paddingBottom: 12,
    marginBottom: 20,
    marginTop: 0,
    borderBottom: '3px solid #000',
    display: 'block',
  };

  return (
    <div className="bg-white min-h-screen" style={roboto.style}>

      {/* Header */}
      <LandingHeader />

      {/* Breadcrumb */}
      <nav aria-label="Fil d'Ariane" className="max-w-[1250px] mx-auto px-6 pt-6">
        <ol className="flex items-center gap-1.5" style={{ fontSize: 12, color: '#646464' }}>
          <li>
            <Link href="/" style={{ color: '#646464' }} className="hover:text-black transition-colors">
              Accueil
            </Link>
          </li>
          <li aria-hidden="true" className="select-none">/</li>
          <li>
            <Link href={hub.href} style={{ color: '#646464' }} className="hover:text-black transition-colors">
              {hub.label}
            </Link>
          </li>
          <li aria-hidden="true" className="select-none">/</li>
          <li style={{ color: '#646464' }} className="truncate max-w-[200px] sm:max-w-none">
            {page.title}
          </li>
        </ol>
      </nav>

      {/* ================================================================== */}
      {/* Main Section                                                        */}
      {/* ================================================================== */}
      <section className="post-details-area py-16 lg:py-24 bg-white">
        <div className="max-w-[1250px] mx-auto px-4 sm:px-6">
          <div className="grid lg:grid-cols-[1fr_300px] gap-x-16 xl:gap-x-24 items-start">

            {/* ============================================================ */}
            {/* MAIN ARTICLE (left)                                           */}
            {/* ============================================================ */}
            <div className="post-details">

              {/* A. Entry Header */}
              <div className="entry-header text-center" style={{ paddingBottom: 60 }}>
                <h1
                  className="title"
                  style={{
                    ...robotoSlab.style,
                    fontSize: 'clamp(28px, 4vw, 40px)',
                    fontWeight: 800,
                    color: '#000',
                    lineHeight: 1.4,
                    marginBottom: 30,
                    marginTop: 0,
                  }}
                >
                  {page.title}
                </h1>

                <ul
                  className="post-meta"
                  style={{
                    maxWidth: 380,
                    margin: '0 auto',
                    fontSize: 13,
                    color: '#646464',
                    listStyle: 'none',
                    padding: 0,
                  }}
                >
                  <li>
                    {page.data?.slug_key_label && (
                      <Link
                        href="#"
                        style={{ color: '#646464', textDecoration: 'none', marginRight: 8 }}
                        className="hover:text-black transition-colors"
                      >
                        {page.data.slug_key_label}
                      </Link>
                    )}
                    <Link
                      href="#"
                      style={{ color: '#646464', textDecoration: 'none' }}
                      className="hover:text-black transition-colors"
                    >
                      {content.category}
                    </Link>
                  </li>
                </ul>

                <p
                  className="short-desc"
                  style={{
                    fontSize: 16,
                    fontWeight: 500,
                    maxWidth: 560,
                    margin: '30px auto 0',
                    lineHeight: 1.7,
                    color: '#3d3d3d',
                  }}
                >
                  {page.description}
                </p>
              </div>

              {/* B. Entry Media */}
              <div
                className="entry-media text-center"
                style={{ marginBottom: 50, borderRadius: 4, overflow: 'hidden', backgroundColor: '#f5f5f5' }}
              >
                <img
                  src={getPseoImageUrl(page.data?.slug_key ?? page.slug, 1000, 400)}
                  alt={page.title}
                  style={{ width: '100%', height: 360, objectFit: 'cover', display: 'block' }}
                />
              </div>

              {/* C. Entry Content */}
              <div
                className="entry-content px-6 lg:px-[60px]"
                style={{
                  paddingTop: 50,
                  paddingBottom: 50,
                  fontSize: 16,
                  lineHeight: 1.7,
                  color: '#3d3d3d',
                }}
              >
                {content.sections.map((section, idx) => (
                  <section key={idx}>

                    <h2
                      style={{
                        ...robotoSlab.style,
                        fontSize: 22,
                        fontWeight: 700,
                        color: '#000',
                        marginTop: idx === 0 ? 0 : 40,
                        marginBottom: 12,
                      }}
                    >
                      {section.heading}
                    </h2>

                    {/* First paragraph gets drop cap via span wrapper */}
                    {idx === 0 && section.body ? (
                      <p
                        className="has-dropcap"
                        style={{ fontSize: 15, lineHeight: 1.8, marginBottom: 20 }}
                      >
                        <span
                          style={{
                            ...robotoSlab.style,
                            float: 'left',
                            fontSize: 52,
                            fontWeight: 800,
                            lineHeight: 0.8,
                            marginRight: 8,
                            marginTop: 6,
                            color: '#000',
                          }}
                        >
                          {section.body[0]}
                        </span>
                        {section.body.slice(1)}
                      </p>
                    ) : (
                      <p style={{ fontSize: 15, lineHeight: 1.8, marginBottom: 20 }}>
                        {section.body}
                      </p>
                    )}

                    {/* Bullets */}
                    {section.bullets && (
                      <ul style={{ listStyle: 'none', padding: 0, margin: '0 0 20px 0' }}>
                        {section.bullets.map((bullet, bIdx) => (
                          <li
                            key={bIdx}
                            style={{
                              display: 'flex',
                              alignItems: 'flex-start',
                              marginBottom: 10,
                              color: '#3d3d3d',
                            }}
                          >
                            <span
                              style={{
                                display: 'inline-block',
                                width: 6,
                                height: 6,
                                borderRadius: '50%',
                                backgroundColor: '#000',
                                marginRight: 12,
                                marginTop: '0.45em',
                                flexShrink: 0,
                                verticalAlign: 'middle',
                              }}
                            />
                            <span>{bullet}</span>
                          </li>
                        ))}
                      </ul>
                    )}


                    {/* Comparison table */}
                    {section.comparison && (
                      <div className="overflow-x-auto" style={{ marginTop: 24, marginBottom: 24 }}>
                        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 14 }}>
                          <thead>
                            <tr style={{ backgroundColor: '#f9f9f9' }}>
                              <th
                                style={{
                                  ...robotoSlab.style,
                                  fontWeight: 700,
                                  textAlign: 'left',
                                  padding: '10px 14px',
                                  borderBottom: '1px solid #e5e5e5',
                                  color: '#000',
                                }}
                              >
                                Fonctionnalité
                              </th>
                              <th
                                style={{
                                  ...robotoSlab.style,
                                  fontWeight: 700,
                                  textAlign: 'center',
                                  padding: '10px 14px',
                                  borderBottom: '1px solid #e5e5e5',
                                  color: '#000',
                                }}
                              >
                                FactPilot
                              </th>
                              <th
                                style={{
                                  ...robotoSlab.style,
                                  fontWeight: 700,
                                  textAlign: 'center',
                                  padding: '10px 14px',
                                  borderBottom: '1px solid #e5e5e5',
                                  color: '#000',
                                }}
                              >
                                {competitorName}
                              </th>
                            </tr>
                          </thead>
                          <tbody>
                            {section.comparison.map((row, rIdx) => (
                              <tr key={rIdx}>
                                <td
                                  style={{
                                    padding: '10px 14px',
                                    borderBottom: '1px solid #e5e5e5',
                                    color: '#3d3d3d',
                                  }}
                                >
                                  {row.feature}
                                </td>
                                <td
                                  style={{
                                    padding: '10px 14px',
                                    borderBottom: '1px solid #e5e5e5',
                                    textAlign: 'center',
                                    fontWeight: 700,
                                    color: '#000',
                                  }}
                                >
                                  ✓
                                </td>
                                <td
                                  style={{
                                    padding: '10px 14px',
                                    borderBottom: '1px solid #e5e5e5',
                                    textAlign: 'center',
                                  }}
                                >
                                  {row.competitor ? (
                                    <span style={{ fontWeight: 700, color: '#000' }}>✓</span>
                                  ) : (
                                    <span style={{ color: '#cacaca' }}>✗</span>
                                  )}
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    )}

                  </section>
                ))}
              </div>

              {/* D. Entry Footer */}
              <div
                className="entry-footer px-6 lg:px-[60px] text-center"
                style={{ paddingTop: 40, paddingBottom: 0 }}
              >
                {/* Date */}
                <p style={{ fontSize: 12, color: '#989898', marginBottom: 16 }}>Mis à jour 2025</p>

                {/* Tags */}
                <div className="post-tags">
                  <span style={{ fontSize: 13, color: '#3d3d3d', fontWeight: 600 }}>Tag :</span>
                  {[page.data?.slug_key_label, 'FactPilot', 'Automatisation comptable']
                    .filter(Boolean)
                    .map((tag, i) => (
                      <Link
                        key={i}
                        href="#"
                        style={{
                          fontSize: 13,
                          color: '#5a5959',
                          marginLeft: 4,
                          textDecoration: 'none',
                        }}
                        className="hover:text-black transition-colors"
                      >
                        {tag}
                      </Link>
                    ))}
                </div>

                {/* Social share */}
                <div
                  className="social-share"
                  style={{ marginTop: 15, paddingTop: 15 }}
                >
                  <span style={{ fontSize: 13, color: '#3d3d3d' }}>Partager :</span>
                  <a
                    href="https://www.linkedin.com/company/factpilot-fr"
                    target="_blank"
                    rel="noopener noreferrer"
                    style={{ fontSize: 14, color: '#3d3d3d', marginLeft: 12, textDecoration: 'none' }}
                    className="hover:text-black transition-colors"
                  >
                    LinkedIn
                  </a>
                  <a
                    href="#"
                    style={{ fontSize: 14, color: '#3d3d3d', marginLeft: 12, textDecoration: 'none' }}
                    className="hover:text-black transition-colors"
                  >
                    Twitter
                  </a>
                  <a
                    href="#"
                    style={{ fontSize: 14, color: '#3d3d3d', marginLeft: 12, textDecoration: 'none' }}
                    className="hover:text-black transition-colors"
                  >
                    Facebook
                  </a>
                </div>

                {/* Post author */}
                <div
                  className="post-author"
                  style={{ maxWidth: 320, margin: '50px auto 10px', textAlign: 'center' }}
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src="https://i.pravatar.cc/80?img=23"
                    alt="Équipe FactPilot"
                    style={{
                      width: 75,
                      height: 75,
                      borderRadius: '50%',
                      marginBottom: 14,
                      display: 'inline-block',
                    }}
                  />
                  <h5
                    style={{
                      ...robotoSlab.style,
                      fontSize: 18,
                      fontWeight: 700,
                      color: '#000',
                      marginBottom: 8,
                      marginTop: 0,
                    }}
                  >
                    Équipe FactPilot
                  </h5>
                  <p style={{ fontSize: 13, color: '#646464', lineHeight: 1.6, margin: 0 }}>
                    Experts en automatisation comptable et conformité Factur-X 2026.
                  </p>
                </div>
              </div>


              {/* F. Related Posts */}
              {page.links && page.links.length > 0 && (
                <div
                  className="related-posts px-6 lg:px-[60px]"
                  style={{ paddingTop: 50, paddingBottom: 20, borderTop: '1px solid #e5e5e5', marginTop: 20 }}
                >
                  <h4
                    className="related-title"
                    style={{
                      ...robotoSlab.style,
                      fontSize: 22,
                      fontWeight: 700,
                      color: '#000',
                      marginBottom: 24,
                      marginTop: 0,
                    }}
                  >
                    Articles associés
                  </h4>
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                    {page.links.slice(0, 2).map((link) => (
                      <Link
                        key={link.href}
                        href={link.href}
                        style={{ textDecoration: 'none', display: 'block', textAlign: 'center' }}
                      >
                        <div style={{ height: 160, borderRadius: 4, marginBottom: 16, overflow: 'hidden', backgroundColor: '#f5f5f5' }}>
                          <img
                            src={getPseoImageUrl(link.href.split('/').pop(), 600, 300)}
                            alt={link.label}
                            style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
                          />
                        </div>
                        <h5
                          style={{
                            ...robotoSlab.style,
                            fontSize: 16,
                            fontWeight: 700,
                            color: '#000',
                            lineHeight: 1.5,
                            margin: 0,
                          }}
                        >
                          {link.label}
                        </h5>
                      </Link>
                    ))}
                  </div>
                </div>
              )}

              {/* G. FAQ */}
              <div
                className="faq px-6 lg:px-[60px]"
                style={{ paddingTop: 20, paddingBottom: 50 }}
              >
                <h4
                  style={{
                    ...robotoSlab.style,
                    fontSize: 22,
                    fontWeight: 700,
                    color: '#000',
                    marginTop: 40,
                    marginBottom: 24,
                  }}
                >
                  Questions fréquentes
                </h4>
                <PseoFaq items={content.faq} titleStyle={robotoSlab.style} />
              </div>

            </div>
            {/* END MAIN ARTICLE */}

            {/* ============================================================ */}
            {/* SIDEBAR (right, sticky)                                       */}
            {/* ============================================================ */}
            <aside className="hidden lg:block sticky top-24">



              {/* Widget 2 — Dans cette catégorie */}
              {page.links && page.links.length > 0 && (
                <div style={{ marginBottom: 40 }}>
                  <h4 style={widgetTitleStyle}>Dans cette catégorie</h4>
                  <div className="articles">
                    {page.links.slice(0, 6).map((link) => (
                      <div
                        key={link.href}
                        className="article"
                        style={{
                          display: 'flex',
                          gap: 12,
                          marginBottom: 16,
                          paddingBottom: 16,
                          borderBottom: '1px solid #f1f1f1',
                          alignItems: 'flex-start',
                        }}
                      >
                        <img
                          src={getPseoImageUrl(link.href.split('/').pop(), 80, 80)}
                          alt=""
                          style={{ width: 56, height: 56, objectFit: 'cover', borderRadius: 3, flexShrink: 0 }}
                        />
                        <div>
                          <h6 style={{ margin: 0 }}>
                            <Link
                              href={link.href}
                              style={{
                                ...robotoSlab.style,
                                fontSize: 13,
                                fontWeight: 700,
                                color: '#000',
                                lineHeight: 1.4,
                                textDecoration: 'none',
                              }}
                              className="hover:underline"
                            >
                              {link.label}
                            </Link>
                          </h6>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}


            </aside>
            {/* END SIDEBAR */}

          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section style={{ background: '#000', padding: '80px 24px', textAlign: 'center' }}>
        <h2 style={{ ...robotoSlab.style, fontSize: 'clamp(22px,3vw,32px)', fontWeight: 800, color: '#fff', marginBottom: 12 }}>
          Récupérez vos 120h/mois
        </h2>
        <p style={{ fontSize: 14, color: 'rgba(255,255,255,0.6)', marginBottom: 32, lineHeight: 1.6 }}>
          Essai 7 jours gratuit · Aucune CB requise · Opérationnel en 60 min
        </p>
        <Link
          href="/signup"
          style={{ ...robotoSlab.style, display: 'inline-block', background: '#fff', color: '#000', fontWeight: 800, fontSize: 15, padding: '16px 44px', borderRadius: 4, textDecoration: 'none' }}
          className="hover:opacity-80 transition-opacity"
        >
          Démarrer l&apos;essai gratuit
        </Link>
      </section>

      <Footer />

    </div>
  );
}
