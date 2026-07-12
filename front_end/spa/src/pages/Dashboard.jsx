import { useEffect, useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import styles from '../styles/Dashboard.module.css'
import { useAuth } from '../auth/AuthContext'
import { decodeToken } from '../auth/login'

/**
 * Post-login landing page. The parse_auth Lambda@Edge drops the user here
 * with `?token=<idToken>` in the URL. This component:
 *  - captures the token via AuthContext
 *  - strips `?token=…` from the URL bar with history.replaceState
 *  - if /dashboard was originally requested (the typical case), no further redirect
 *  - shows a greeting sourced from the cognito:username JWT claim
 *  - links out to the three feature pages
 */
export default function Dashboard() {
    const { idToken, setIdToken } = useAuth()
    const location = useLocation()
    const [username, setUsername] = useState('User')
    const navigate = useNavigate()

    useEffect(() => {
        document.title = 'Resume Optimizer — Dashboard'

        // Pick up ?token=<idToken> from the URL exactly once.
        const params = new URLSearchParams(location.search)
        const fromQuery = params.get('token')
        if (fromQuery) {
            setIdToken(fromQuery)
            params.delete('token')
            const qs = params.toString()
            navigate('/dashboard', { replace: true })
        }
    }, [location.search, setIdToken, navigate])

    useEffect(() => {
        if (idToken) {
            const claims = decodeToken(idToken)
            setUsername(claims['cognito:username'] || claims.sub || 'User')
        }
    }, [idToken])

    return (
        <div className={styles.content}>
            <h1 className={styles.greeting}>
                Hello <span id="user_tag">{username}</span>!
            </h1>
            <ul className={styles.user_actions}>
                <li><Link to="/chats">&gt;&gt; View Conversations</Link></li>
                <li><Link to="/resumes">&gt;&gt; View Resumes</Link></li>
                <li><Link to="/listings">&gt;&gt; View Listings</Link></li>
            </ul>
        </div>
    )
}
