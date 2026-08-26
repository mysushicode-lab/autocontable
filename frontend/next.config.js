/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone', // Official Next.js recommendation for Docker

  // API proxying is now handled by src/app/api/[...path]/route.js
  // This allows runtime BACKEND_URL changes without rebuilding

  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'i.pravatar.cc' },
      { protocol: 'https', hostname: 'images.unsplash.com' },
      { protocol: 'https', hostname: 'picsum.photos' },
      { protocol: 'https', hostname: 'fastly.picsum.photos' },
    ],
  },
};

module.exports = nextConfig;
