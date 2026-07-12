import { Link, useLocation } from 'react-router-dom'
import { startLogin, signOut } from '../auth/login'
import { useAuth } from '../auth/AuthContext'

/**
 * Site-wide header. Logo on the left; nav on the right.
 * - "Home" is always present.
 * - "Sign out" is shown when authenticated; clicking calls Cognito's /logout,
 *   clears sessionStorage, and lands back on Home.
 * - "Sign in" is shown when not authenticated; clicking starts the Hosted UI
 *   flow. (Currently the only "public" page is Home, so Sign in lives here
 *   rather than only on Home.)
 */
export default function Header() {
    const { idToken } = useAuth()
    const location = useLocation()
    const home = <li><Link to="/">home</Link></li>

    return (
        <header>
            <div className="logo">
                <h2> Resume Optimizer </h2>
            </div>
            <nav>
                <ul>
                    {home}
                    {idToken ? (
                        <li>
                            <button
                                type="button"
                                className="link_like"
                                onClick={signOut}
                                style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'inherit', font: 'inherit', padding: 0 }}
                            >
                                Sign Out
                            </button>
                        </li>
                    ) : (
                        location.pathname !== '/' && (
                            <li>
                                <button
                                    type="button"
                                    onClick={() => startLogin({ requestedUri: location.pathname })}
                                    style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'inherit', font: 'inherit', padding: 0 }}
                                >
                                    Sign In
                                </button>
                            </li>
                        )
                    )}
                </ul>
            </nav>
        </header>
    )
}
