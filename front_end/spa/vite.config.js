import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Vite config — React plugin and the standard SPA build.
// Output goes to ./dist which is uploaded to the S3 bucket by aws s3 sync.
export default defineConfig({
    plugins: [react()],
    build: {
        outDir: 'dist',
        sourcemap: false,
    },
    server: {
        port: 5173,
        // The dev server needs the same /api/v1/* proxy as the deployed app,
        // since the API Gateway CORS allow-list only includes the CloudFront
        // origin. See README.
        proxy: {
            '/api/v1': {
                target: 'https://<cloudfront-domain>',
                changeOrigin: true,
                secure: true,
            },
        },
    },
})
