/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  // @react-pdf/renderer darf nicht ins Server-Bundle gezogen werden, sonst
  // crasht die PDF-Erzeugung auf Vercel-Serverless. Als externes Node-Modul
  // zur Laufzeit laden:
  serverExternalPackages: ["@react-pdf/renderer"],
  experimental: {
    optimizePackageImports: ["clsx", "tailwind-merge"],
  },
};

export default nextConfig;
