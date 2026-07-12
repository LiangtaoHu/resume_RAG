import { useSearchParams } from 'react-router-dom'
import styles from '../styles/Error.module.css'

const REASONS = {
    internal_error: 'Something went wrong on our end. Please try again.',
    tampered_nonce: 'Your sign-in session did not look correct. Please try signing in again.',
    missing_access_code: 'Your sign-in flow was incomplete. Please try again.',
}

/**
 * Rendered for the /error route AND for any unmatched route (catch-all `*`).
 * If the URL carries ?error=auth_failed&reason=…, surface a friendly message;
 * otherwise show a generic 404 / "Resource Not Found" header.
 */
export default function ErrorPage({ code }) {
    const [searchParams] = useSearchParams()
    const reason = searchParams.get('reason')
    const errorType = searchParams.get('error')
    const detail = errorType === 'auth_failed' && REASONS[reason]
        ? REASONS[reason]
        : 'Resource Not Found'

    // When invoked for catch-all routing, `code` is 404.
    const headingText = code === 404 ? 'ERROR 404' : 'ERROR'

    return (
        <div className={styles.content}>
            <b className={styles.title}>{headingText}</b>
            <p className={styles.detail}>{detail}</p>
        </div>
    )
}
