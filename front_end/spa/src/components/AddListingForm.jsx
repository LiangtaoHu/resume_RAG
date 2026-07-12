import { useState } from 'react'
import styles from '../styles/Listings.module.css'

/**
 * Inline form for submitting a job-posting URL to the parse_listing backend.
 * Controlled component — owns only the local input string; submit/cancel/error
 * state all live in the parent so the parent can decide what to do with a
 * successful response (append a placeholder, refresh, etc.).
 *
 * Props:
 *   onSubmit(url)  — called after the user hits Add and the URL is well-formed.
 *   onCancel()     — called when the user clicks Cancel.
 *   submitting     — when true, disables both buttons and shows "Submitting...".
 *   error          — string to display below the input, or null.
 */
export default function AddListingForm({ onSubmit, onCancel, submitting, error }) {
    const [url, setUrl] = useState('')

    const handleSubmit = (e) => {
        e.preventDefault()
        const trimmed = url.trim()
        if (!trimmed || submitting) return
        // Native <input type="url" required> covers most of this, but be
        // defensive in case the browser skipped the validation.
        let parsed
        try {
            parsed = new URL(trimmed)
        } catch {
            // Should never reach here — the form has type="url" required.
            return
        }
        if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
            return
        }
        onSubmit(trimmed)
    }

    const canSubmit = url.trim().length > 0 && !submitting

    return (
        <form className={styles.add_form} onSubmit={handleSubmit}>
            <div className={styles.add_form_row}>
                <input
                    type="url"
                    className={styles.add_form_input}
                    placeholder="https://example.com/job-posting"
                    value={url}
                    onChange={(e) => setUrl(e.target.value)}
                    disabled={submitting}
                    required
                    aria-label="Job posting URL"
                />
                <div className={styles.add_form_actions}>
                    <button
                        type="submit"
                        className={styles.add_form_button}
                        disabled={!canSubmit}
                    >
                        {submitting ? 'Submitting…' : 'Add'}
                    </button>
                    <button
                        type="button"
                        className={styles.add_form_button_secondary}
                        onClick={onCancel}
                        disabled={submitting}
                    >
                        Cancel
                    </button>
                </div>
            </div>
            {error && (
                <p className={styles.add_form_error} role="alert">
                    {error}
                </p>
            )}
        </form>
    )
}
