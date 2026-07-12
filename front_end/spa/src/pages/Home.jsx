import { useEffect } from 'react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import styles from '../styles/Home.module.css'
import { startLogin } from '../auth/login'

/**
 * Marketing landing page. The "Sign up / Log in" button triggers the Cognito
 * Hosted UI flow. If the visit was a bounce from <ProtectedRoute> (via
 * ?next=…), the requested path is preserved through the state parameter so
 * parse_auth Lambda@Edge can redirect back to it post-login.
 */
export default function Home() {
    const navigate = useNavigate()
    const [searchParams] = useSearchParams()
    const next = searchParams.get('next')

    useEffect(() => {
        document.title = 'Resume Optimizer — Main Page'
    }, [])

    const handleSignIn = () => {
        startLogin({ requestedUri: next || '/dashboard' })
    }

    return (
        <div className={styles.content}>
            <h1 className={styles.title}>Say Hello to Resume Optimizer!</h1>
            <div>
                <h2>A web service where you can upload and customize your resumes to specific job listings.</h2>
                <h3>Backed with a serverless cloud architecture.</h3>
                <button type="button" className={styles.register_button} onClick={handleSignIn}>
                    Sign up / Log in
                </button>
            </div>
        </div>
    )
}
