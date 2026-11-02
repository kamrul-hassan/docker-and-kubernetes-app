import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Produces .next/standalone: a minimal server bundle for the Docker image
  output: "standalone",
  poweredByHeader: false,
};

export default nextConfig;
