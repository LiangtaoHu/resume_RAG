/**
 * Login / logout helpers for the SPA.
 *
 * The Hosted UI URL and client id are baked at build time via Vite env vars.
 * Configure with a .env file (see .env.example).
 *
 * The flow remains:
 *   1. Browser → Cognito Hosted UI
 *   2. Cognito → /callback?code=...&state=...
 *   3. parse_auth Lambda@Edge exchanges the code, sets HttpOnly cookies, and
 *      302s to /dashboard?token=<idToken>
 *   4. <Dashboard> captures the token via AuthContext.
 */

const DOMAIN = import.meta.env.VITE_COGNITO_DOMAIN
const CLIENT_ID = import.meta.env.VITE_COGNITO_CLIENT_ID

/**
 * Decode the payload of a JWT without verifying the signature. The signature
 * is verified server-side at the API Gateway; this just lets the UI show the
 * cognito:username claim in the dashboard greeting.
 */
export function decodeToken(token) {
    if (!token || typeof token !== 'string' || token.split('.').length < 2) {
        return {}
    }
    try {
        return JSON.parse(atob(token.split('.')[1]))
    } catch {
        return {}
    }
}

export function startLogin({ requestedUri } = {}) {
    if (!DOMAIN || !CLIENT_ID) {
        throw new Error(
            'VITE_COGNITO_DOMAIN and VITE_COGNITO_CLIENT_ID must be set in .env'
        )
    }
    const nonce = crypto.getRandomValues(new Uint8Array(16))
        .reduce((s, b) => s + String.fromCharCode(b), '')
    const stateToken = btoa(JSON.stringify({
        'spa-auth-edge-nonce': nonce,
        requested_uri: requestedUri || '/dashboard',
    }))

    const params = new URLSearchParams({
        response_type: 'code',
        client_id: CLIENT_ID,
        redirect_uri: `${window.location.origin}/callback`,
        state: stateToken,
        scope: 'openid email',
    })
    window.location.assign(`${DOMAIN}/login?${params}`)
}

export async function signOut() {
    // Clear local state immediately so the UI updates without waiting.
    sessionStorage.clear()
    if (DOMAIN && CLIENT_ID) {
        const params = new URLSearchParams({
            client_id: CLIENT_ID,
            logout_uri: window.location.origin + '/',
        })
        // Cognito will redirect back to / once logged out.
        window.location.assign(`${DOMAIN}/logout?${params}`)
    } else {
        window.location.assign('/')
    }
}
