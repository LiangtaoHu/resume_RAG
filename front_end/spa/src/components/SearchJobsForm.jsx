import { useState } from 'react'
import styles from '../styles/Listings.module.css'

/**
 * Keyword-search banner for /listings.
 *
 * Renders a keywords input + Search button at the top, then a preview list
 * of Adzuna hits with per-row Add / Discard buttons. Pure controlled
 * component — does not own API state. The parent (Listings.jsx) provides
 * the search results, in-flight flags, error strings, and the three
 * callbacks:
 *
 *   onSearch(keywords)  — parent hits POST /api/v1/search_jobs and updates
 *                         `results` prop with the response.
 *   onAdd(result)       — parent hits POST /api/v1/jobs/add and, on
 *                         success, prepends the row to its main listings
 *                         table and removes it from the preview list.
 *   onDiscard(idx)      — parent removes the row from the preview list.
 *
 * Props:
 *   searching  — disables the Search button while the request is in flight.
 *   searchError — last error string from a search call (cleared on next search).
 *   results     — array of normalized hits: { adzuna_id, title, company, location, url, snippet }.
 *   adding      — true while an Add call is in flight (disables all Add buttons).
 *   addError    — last error string from an Add call.
 */
export default function SearchJobsForm({
    onSearch,
    onAdd,
    onDiscard,
    searching,
    searchError,
    results,
    adding,
    addError,
}) {
    const [keywords, setKeywords] = useState('')

    const handleSearch = (e) => {
        e.preventDefault()
        const trimmed = keywords.trim()
        if (!trimmed || searching) return
        onSearch(trimmed)
    }

    const handleClear = () => {
        if (searching) return
        setKeywords('')
    }

    const canSearch = keywords.trim().length > 0 && !searching

    return (
        <section className={styles.search_section} aria-label="Search job postings by keyword">
            <form className={styles.add_form} onSubmit={handleSearch}>
                <div className={styles.add_form_row}>
                    <input
                        type="text"
                        className={styles.add_form_input}
                        placeholder="Keywords (e.g. react developer remote)"
                        value={keywords}
                        onChange={(e) => setKeywords(e.target.value)}
                        disabled={searching}
                        aria-label="Search keywords"
                    />
                    <div className={styles.add_form_actions}>
                        <button
                            type="submit"
                            className={styles.add_form_button}
                            disabled={!canSearch}
                        >
                            {searching ? 'Searching…' : 'Search'}
                        </button>
                        <button
                            type="button"
                            className={styles.add_form_button_secondary}
                            onClick={handleClear}
                            disabled={searching || keywords.length === 0}
                        >
                            Clear
                        </button>
                    </div>
                </div>
                {searchError && (
                    <p className={styles.add_form_error} role="alert">
                        {searchError}
                    </p>
                )}
                {addError && (
                    <p className={styles.add_form_error} role="alert">
                        {addError}
                    </p>
                )}
            </form>

            {results && results.length > 0 && (
                <ul className={styles.results_list}>
                    {results.map((r, idx) => (
                        <li
                            key={`${r.adzuna_id || idx}`}
                            className={styles.results_row}
                        >
                            <div className={styles.results_meta}>
                                <div className={styles.results_title}>{r.title || '(untitled)'}</div>
                                <div className={styles.results_subtitle}>
                                    {r.company || 'Unknown company'}
                                    {r.location ? ` · ${r.location}` : ''}
                                </div>
                            </div>
                            <div className={styles.results_actions}>
                                <button
                                    type="button"
                                    className={styles.add_form_button}
                                    onClick={() => onAdd(r)}
                                    disabled={adding}
                                    aria-label={`Add ${r.title}`}
                                >
                                    Add
                                </button>
                                <button
                                    type="button"
                                    className={styles.add_form_button_secondary}
                                    onClick={() => onDiscard(idx)}
                                    disabled={adding}
                                    aria-label={`Discard ${r.title}`}
                                >
                                    Discard
                                </button>
                            </div>
                        </li>
                    ))}
                </ul>
            )}
        </section>
    )
}