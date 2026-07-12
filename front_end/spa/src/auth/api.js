import { useAuth } from './AuthContext'

/**
 * Thin fetch wrapper that injects the Bearer token from AuthContext and
 * parses JSON. Throws on !ok so callers can use try/catch / await patterns
 * uniformly.
 */
export function useApi() {
    const { idToken } = useAuth()

    const apiFetch = async (path, options = {}) => {
        const headers = new Headers(options.headers || {})
        if (idToken) {
            headers.set('Authorization', `Bearer ${idToken}`)
        }
        if (!headers.has('Accept')) {
            headers.set('Accept', 'application/json')
        }
        // Only set Content-Type when there's a body; for FormData the browser
        // sets it itself with the right boundary.
        const hasBody = options.body !== undefined && options.body !== null
        if (hasBody && !(options.body instanceof FormData) && !headers.has('Content-Type')) {
            headers.set('Content-Type', 'application/json')
        }

        const res = await fetch(path, { ...options, headers })
        const contentType = res.headers.get('content-type') || ''
        const isJson = contentType.includes('application/json')
        const payload = isJson ? await res.json() : await res.text()
        if (!res.ok) {
            const err = new Error(
                (isJson && payload && payload.error) || `HTTP ${res.status}`
            )
            err.status = res.status
            err.payload = payload
            throw err
        }
        return payload
    }

    return { apiFetch }
}
