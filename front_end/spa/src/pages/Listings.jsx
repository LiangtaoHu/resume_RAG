import { useEffect, useState } from 'react'
import styles from '../styles/Listings.module.css'
import { useApi } from '../auth/api'
import AddListingForm from '../components/AddListingForm.jsx'
import SearchJobsForm from '../components/SearchJobsForm.jsx'

/**
 * Job-listings page.
 *  - On mount, GET /api/v1/view_data and render the user's parsed listings
 *    (the conversation_starter Lambda returns `job_listings` keyed by
 *    `JOB#<company>-<position>`; soft-deleted rows — `deletedAt` set — are
 *    filtered out server-side).
 *  - Click a row to open the side panel with company/position/url details.
 *  - "Add +" expands an inline URL-paste form. Submitting POSTs to
 *    /api/v1/parse_listing; a "Currently Processing" placeholder is appended
 *    to the list while the Selenium-driven scraper runs; the real entry
 *    appears after the user reloads (or once view_data is re-pulled).
 *  - "Search" banner sits above the table. It calls /api/v1/search_jobs and
 *    renders Adzuna hits in a preview list; "Add" on a hit POSTs to
 *    /api/v1/jobs/add, "Discard" removes it from the preview.
 *  - Each row has a Delete button (always visible) and the header
 *    "Remove −" deletes the currently selected row. Both call
 *    /api/v1/jobs/delete, which soft-deletes via UpdateItem.
 */
export default function Listings() {
    const { apiFetch } = useApi()
    const [listings, setListings] = useState([])
    const [loadError, setLoadError] = useState(null)
    const [selected, setSelected] = useState(null)

    // Inline "Add Job Posting" form state.
    const [addFormOpen, setAddFormOpen] = useState(false)
    const [addSubmitting, setAddSubmitting] = useState(false)
    const [addError, setAddError] = useState(null)

    // Keyword search banner state.
    const [searchResults, setSearchResults] = useState([])
    const [searching, setSearching] = useState(false)
    const [searchError, setSearchError] = useState(null)

    // Soft-delete state.
    const [deletingKey, setDeletingKey] = useState(null)
    const [deleteError, setDeleteError] = useState(null)

    useEffect(() => {
        document.title = 'Resume Optimizer — My Listings'
    }, [])

    useEffect(() => {
        let cancelled = false
        async function load() {
            try {
                const data = await apiFetch('/api/v1/view_data')
                if (cancelled) return
                setListings(data.job_listings || [])
                setLoadError(null)
            } catch {
                if (cancelled) return
                setLoadError('Failed to load data.')
            }
        }
        load()
        return () => { cancelled = true }
    }, [apiFetch])

    const handleAddClick = () => {
        if (addSubmitting) return
        setAddError(null)
        setAddFormOpen((prev) => !prev)
    }

    const handleAddCancel = () => {
        if (addSubmitting) return
        setAddError(null)
        setAddFormOpen(false)
    }

    const handleAddSubmit = async (url) => {
        setAddSubmitting(true)
        setAddError(null)
        try {
            await apiFetch('/api/v1/parse_listing', {
                method: 'POST',
                body: JSON.stringify({ url }),
            })
            // Optimistic placeholder row until view_data picks up the real entry.
            setListings((prev) => [
                ...prev,
                {
                    SK: 'Currently Processing',
                    url,
                    company: 'Currently Processing',
                    position: 'Currently Processing',
                },
            ])
            setAddFormOpen(false)
        } catch (err) {
            setAddError(err.message || 'Failed to add listing.')
        } finally {
            setAddSubmitting(false)
        }
    }

    // --- Keyword search ---

    const handleSearch = async (keywords) => {
        setSearching(true)
        setSearchError(null)
        setDeleteError(null)
        try {
            const data = await apiFetch('/api/v1/search_jobs', {
                method: 'POST',
                body: JSON.stringify({ keywords, max_results: 20 }),
            })
            setSearchResults(data.results || [])
        } catch (err) {
            setSearchError(err.message || 'Search failed.')
            setSearchResults([])
        } finally {
            setSearching(false)
        }
    }

    const handleAddFromSearch = async (result) => {
        setDeleteError(null)
        const idx = searchResults.findIndex((r) => r === result)
        try {
            await apiFetch('/api/v1/jobs/add', {
                method: 'POST',
                body: JSON.stringify({
                    company: result.company,
                    position: result.title,
                    url: result.url,
                    adzuna_id: result.adzuna_id,
                }),
            })
            // Prepend a JOB# row to the main table (matching what view_data
            // would return once reloaded). Soft-delete keys are derived from
            // company-position so a delete later will target the same row.
            const sk = `JOB#${result.company}-${result.title}`
            setListings((prev) => [
                {
                    SK: sk,
                    company: result.company,
                    position: result.title,
                    url: result.url,
                    status: 'PENDING_INGEST',
                    adzunaId: result.adzuna_id,
                },
                ...prev,
            ])
            // Remove the hit from the preview list.
            if (idx >= 0) {
                setSearchResults((prev) => prev.filter((_, i) => i !== idx))
            }
            // If the user had a row selected and we just added another row,
            // the selection index may have shifted — drop it.
            setSelected(null)
        } catch (err) {
            setDeleteError(err.message || 'Failed to add listing.')
        }
    }

    const handleDiscardFromSearch = (idx) => {
        setSearchResults((prev) => prev.filter((_, i) => i !== idx))
    }

    // --- Soft delete ---

    const softDelete = async (listing) => {
        const company = (listing.company || '').trim()
        const position = (listing.position || '').trim()
        if (!company || !position) {
            setDeleteError('Cannot delete: missing company or position.')
            return
        }
        setDeletingKey(listing.SK || `${company}-${position}`)
        setDeleteError(null)
        try {
            await apiFetch('/api/v1/jobs/delete', {
                method: 'POST',
                body: JSON.stringify({ company, position }),
            })
            setListings((prev) => prev.filter((l) => l !== listing))
            setSelected(null)
        } catch (err) {
            setDeleteError(err.message || 'Failed to delete listing.')
        } finally {
            setDeletingKey(null)
        }
    }

    const handleRowDelete = (e, listing) => {
        e.stopPropagation() // don't also select the row
        softDelete(listing)
    }

    const handleHeaderRemove = () => {
        if (selected === null) return
        softDelete(listings[selected])
    }

    // --- UI helpers ---

    const handleSelect = (idx) => setSelected(idx)
    const handleClose = () => setSelected(null)

    const selectedListing = selected !== null ? listings[selected] : null

    return (
        <div className={styles.content}>
            <h1>My Listings</h1>
            <SearchJobsForm
                onSearch={handleSearch}
                onAdd={handleAddFromSearch}
                onDiscard={handleDiscardFromSearch}
                searching={searching}
                searchError={searchError}
                results={searchResults}
                adding={!!deletingKey}
                addError={deleteError}
            />
            <div
                id="view_listings"
                className={`${styles.listing_data}${selectedListing ? ` ${styles.info_shown}` : ''}`}
            >
                {addFormOpen && (
                    <AddListingForm
                        onSubmit={handleAddSubmit}
                        onCancel={handleAddCancel}
                        submitting={addSubmitting}
                        error={addError}
                    />
                )}
                <div className={styles.table}>
                    <div className={styles.table_header}>
                        <button
                            id="add_button"
                            type="button"
                            className={styles.header_button}
                            onClick={handleAddClick}
                            disabled={addSubmitting}
                            aria-expanded={addFormOpen}
                        >
                            {addFormOpen ? 'Close −' : 'Add +'}
                        </button>
                        <button
                            id="remove_button"
                            type="button"
                            className={styles.header_button}
                            onClick={handleHeaderRemove}
                            disabled={selected === null || !!deletingKey}
                            aria-label="Remove selected listing"
                        >
                            Remove −
                        </button>
                        <div />
                    </div>
                    <div id="table_entries" className={styles.table_entries}>
                        {loadError && <div>{loadError}</div>}
                        {!loadError && listings.length === 0 && (
                            <div>No listings yet.</div>
                        )}
                        {listings.map((l, idx) => {
                            const isDeleting = deletingKey === (l.SK || `${l.company}-${l.position}`)
                            // "Currently Processing" is a placeholder for the
                            // parse_listing flow; it has no real SK, so we
                            // can't soft-delete it. Hide the row's Delete
                            // button for that case.
                            const isPlaceholder = l.SK === 'Currently Processing'
                            return (
                                <div
                                    key={l.SK || idx}
                                    className={`${styles.listing}${selected === idx ? ` ${styles.selected}` : ''}`}
                                    onClick={() => handleSelect(idx)}
                                >
                                    <span className={styles.listing_text}>{l.SK}</span>
                                    {!isPlaceholder && (
                                        <button
                                            type="button"
                                            className={styles.row_delete_btn}
                                            onClick={(e) => handleRowDelete(e, l)}
                                            disabled={isDeleting}
                                            aria-label={`Delete ${l.SK}`}
                                        >
                                            {isDeleting ? '…' : 'Delete'}
                                        </button>
                                    )}
                                </div>
                            )
                        })}
                    </div>
                </div>
                {selectedListing && (
                    <div id="side_view" className={styles.side_view}>
                        <div className={styles.listing_details_header}>
                            <h2>Listing Details</h2>
                            <button
                                id="close_side_view"
                                type="button"
                                className={styles.close_side_view_btn}
                                onClick={handleClose}
                            >
                                X
                            </button>
                        </div>
                        <div className={styles.listing_details}>
                            <div>
                                <span className={styles.title}>Company:</span>
                                <div>{selectedListing.company ?? ''}</div>
                            </div>
                            <div>
                                <span className={styles.title}>Position:</span>
                                <div>{selectedListing.position ?? ''}</div>
                            </div>
                            <div>
                                <span className={styles.title}>URL:</span>
                                <div>{selectedListing.url ?? ''}</div>
                            </div>
                        </div>
                    </div>
                )}
            </div>
        </div>
    )
}