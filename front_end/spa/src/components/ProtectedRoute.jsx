import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'

/**
 * Guard for authenticated routes. Redirects to / (Home) when there's no
 * idToken. The page passes requested_uri through to Home so it can dispatch
 * the user into the login flow with the right back-redirect target.
 */
export default function ProtectedRoute({ children }) {
    const { idToken } = useAuth()
    const location = useLocation()
    if (!idToken) {
        return <Navigate to={`/?next=${encodeURIComponent(location.pathname)}`} replace />
    }
    return children
}
