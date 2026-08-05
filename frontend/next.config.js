/** @type {import('next').NextConfig} */
const nextConfig = {
  // API proxying is now handled by src/app/api/[...path]/route.js
  // This allows runtime BACKEND_URL changes without rebuilding

  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'i.pravatar.cc' },
      { protocol: 'https', hostname: 'images.unsplash.com' },
    ],
  },
};

module.exports = nextConfig;
