import { useEffect, useRef, useState } from 'react'
import styles from '../styles/Chats.module.css'
import { useApi } from '../auth/api'

/**
 * Conversations page.
 *  - Loads `view_data` once on mount to enumerate the user's resumes, parsed
 *    job listings, and saved conversations.
 *  - Two-step flow for new chats: pick one resume + one listing, hit Generate.
 *  - Continuing an existing conversation loads its message history; sending
 *    posts to /api/v1/message (which proxies to Bedrock). Note: the existing
 *    conversations array only carries a name today; the API Gateway endpoint
 *    is the source of truth — this component currently shows whatever the
 *    DynamoDB CONV row stored as "chatHistory".
 */
export default function Chats() {
    const { apiFetch } = useApi()
    const [resumes, setResumes] = useState([])
    const [listings, setListings] = useState([])
    const [conversations, setConversations] = useState([])
    const [loadError, setLoadError] = useState(null)

    const [resumeIdx, setResumeIdx] = useState(null)
    const [listingIdx, setListingIdx] = useState(null)
    const [convIdx, setConvIdx] = useState(null)
    const [showCreation, setShowCreation] = useState(false)

    const [messages, setMessages] = useState([])
    const [draft, setDraft] = useState('')
    const [sending, setSending] = useState(false)
    const chatHistoryRef = useRef(null)

    useEffect(() => {
        document.title = 'Resume Optimizer — Your Conversations'
    }, [])

    useEffect(() => {
        let cancelled = false
        async function load() {
            try {
                const data = await apiFetch('/api/v1/view_data')
                if (cancelled) return
                setResumes(data.resumes || [])
                setListings(data.job_listings || [])
                setConversations(data.conversations || [])
                setLoadError(null)
            } catch {
                if (cancelled) return
                setLoadError('Failed to load data.')
            }
        }
        load()
        return () => { cancelled = true }
    }, [apiFetch])

    useEffect(() => {
        if (chatHistoryRef.current) {
            chatHistoryRef.current.scrollTop = chatHistoryRef.current.scrollHeight
        }
    }, [messages])

    const handleStartChat = () => {
        if (resumeIdx === null || listingIdx === null) return
        // Trigger a new conversation. The conversation history will populate as
        // the user sends messages via /api/v1/message.
        setMessages([])
        setConvIdx(null)
        setShowCreation(true)
    }

    const handleContinueChat = (idx) => {
        const conv = conversations[idx]
        setConvIdx(idx)
        setMessages(conv?.chatHistory || conv?.ChatHistory || [])
        setShowCreation(false)
    }

    const handleSend = async () => {
        const text = draft.trim()
        if (!text || sending) return
        const userMsg = { role: 'User', message: text }
        setMessages((prev) => [...prev, userMsg])
        setDraft('')
        setSending(true)
        try {
            const res = await apiFetch('/api/v1/message', {
                method: 'POST',
                body: JSON.stringify({
                    user_message: text,
                    conversation_id: convIdx !== null ? conversations[convIdx]?.SK?.replace(/^CONV#/, '') : '',
                    resume_id: resumeIdx !== null ? resumes[resumeIdx]?.SK : '',
                    job_id: listingIdx !== null ? listings[listingIdx]?.SK?.replace(/^JOB#/, '') : '',
                }),
            })
            if (res && res.agent_text) {
                setMessages((prev) => [...prev, { role: 'Agent', message: res.agent_text }])
            }
        } catch (err) {
            setMessages((prev) => [...prev, { role: 'Agent', message: `Error: ${err.message}` }])
        } finally {
            setSending(false)
        }
    }

    const showGenerate = resumeIdx !== null && listingIdx !== null
    const showMessageBar = messages.length > 0 || convIdx !== null

    return (
        <div className={styles.content}>
            <div id="outer-wrapper" className={styles.wrapper_flex}>
                <div
                    id="conversation_selection"
                    className={`${styles.selection_screen}${showCreation ? ` ${styles.hidden}` : ''}`}
                >
                    <div
                        id="create_button"
                        className={styles.create_icon}
                        onClick={() => setShowCreation(true)}
                        role="button"
                    >
                        create
                    </div>
                    {loadError && <div>{loadError}</div>}
                    {conversations.map((c, i) => (
                        <div
                            key={c.SK || i}
                            className={styles.icon}
                            onDoubleClick={() => handleContinueChat(i)}
                            title="Double-click to continue"
                        >
                            {c.SK}
                        </div>
                    ))}
                </div>

                <div
                    id="creation_menu"
                    className={`${styles.creation_layout}${showCreation ? '' : ` ${styles.hidden}`}`}
                >
                    <button
                        type="button"
                        id="back_button"
                        className={styles.back_button}
                        onClick={() => setShowCreation(false)}
                    >
                        &lt;&lt;
                    </button>
                    <div id="resume_grid" className={styles.creation_grid}>
                        {resumes.map((r, i) => (
                            <div
                                key={r.SK || i}
                                className={`${styles.icon}${resumeIdx === i ? ` ${styles.selected}` : ''}`}
                                onClick={() => setResumeIdx(resumeIdx === i ? null : i)}
                                title={r.SK}
                            >
                                {r.SK}
                            </div>
                        ))}
                    </div>
                    <h1 className={styles.plus_symbol}>+</h1>
                    <div id="listings_grid" className={styles.creation_grid}>
                        {listings.map((l, i) => (
                            <div
                                key={l.SK || i}
                                className={`${styles.icon}${listingIdx === i ? ` ${styles.selected}` : ''}`}
                                onClick={() => setListingIdx(listingIdx === i ? null : i)}
                                title={l.SK}
                            >
                                {l.SK}
                            </div>
                        ))}
                    </div>
                    <button
                        type="submit"
                        id="generate_chat_button"
                        className={styles.generate_chat_button}
                        disabled={!showGenerate}
                        onClick={handleStartChat}
                    >
                        Generate
                    </button>
                </div>
            </div>

            <div className={styles.chat_window}>
                <div id="chat_history" className={styles.chat_history} ref={chatHistoryRef}>
                    {messages.map((m, i) => (
                        <div
                            key={i}
                            className={m.role === 'Agent' ? styles.agent_message : styles.user_message}
                        >
                            {m.message}
                        </div>
                    ))}
                </div>
                <div className={styles.message_bar}>
                    <textarea
                        id="message_space"
                        className={styles.message_space}
                        value={draft}
                        onChange={(e) => setDraft(e.target.value)}
                        disabled={!showMessageBar || sending}
                        onKeyDown={(e) => {
                            if (e.key === 'Enter' && !e.shiftKey) {
                                e.preventDefault()
                                handleSend()
                            }
                        }}
                    />
                    <div className={styles.bottom_message_bar}>
                        <button
                            id="submit_message_button"
                            type="button"
                            className={styles.submit_message_button}
                            disabled={!showMessageBar || sending || !draft.trim()}
                            onClick={handleSend}
                            aria-label="Send"
                        >
                            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className={styles.arrow_icon}>
                                <path d="M13 19V7.83l5.59 5.59L20 12l-8-8-8 8 1.41 1.41L11 7.83V19h2z" />
                            </svg>
                        </button>
                    </div>
                </div>
            </div>
        </div>
    )
}
