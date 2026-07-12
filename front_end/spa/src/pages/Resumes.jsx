import { useEffect, useRef, useState } from 'react'
import styles from '../styles/Resumes.module.css'
import { useApi } from '../auth/api'

/**
 * Resume management page.
 *  - On mount, GET /api/v1/view_data and render resumes (DynamoDB SK is the
 *    filename).
 *  - File input + label + submit. Submit flow:
 *      1. GET /api/v1/upload_resume for presigned S3 POST
 *      2. Submit the file with the returned fields to S3 directly
 *      3. Append the new resume to local state
 *  - The server enforces one upload per EXPIRATION_TIME window via the LINK
 *    row in DynamoDB; 4xx errors surface inline in the label.
 */
export default function Resumes() {
    const { apiFetch } = useApi()
    const [resumes, setResumes] = useState([])
    const [loadError, setLoadError] = useState(null)
    const [selectedFile, setSelectedFile] = useState(null)
    const [submitting, setSubmitting] = useState(false)
    const [labelText, setLabelText] = useState('Drop a file here or click to upload!')
    const fileInputRef = useRef(null)

    useEffect(() => {
        document.title = 'Resume Optimizer — Your Resumes'
    }, [])

    useEffect(() => {
        let cancelled = false
        async function load() {
            try {
                const data = await apiFetch('/api/v1/view_data')
                if (cancelled) return
                setResumes(data.resumes || [])
                setLoadError(null)
            } catch {
                if (cancelled) return
                setLoadError('Failed to load data.')
            }
        }
        load()
        return () => { cancelled = true }
    }, [apiFetch])

    const handleFileChange = (e) => {
        const files = e.target.files
        if (files && files.length > 0) {
            setSelectedFile(files[0])
            setLabelText(`Selected: ${files[0].name}`)
        } else {
            setSelectedFile(null)
            setLabelText('No file selected')
        }
    }

    const handleSubmit = async (e) => {
        e.preventDefault()
        if (!selectedFile || submitting) return
        setSubmitting(true)
        setLabelText('Uploading File. Please Wait.')
        try {
            const presign = await apiFetch('/api/v1/upload_resume')
            const formData = new FormData()
            Object.entries(presign.fields).forEach(([k, v]) => formData.append(k, v))
            formData.append('file', selectedFile)
            const res = await fetch(presign.link, { method: 'POST', body: formData })
            if (!res.ok) throw new Error(`S3 upload failed: ${res.status}`)
            setLabelText('File Uploaded')
            setResumes((prev) => [...prev, { SK: selectedFile.name }])
        } catch (err) {
            setLabelText(`Error: ${err.message}`)
        } finally {
            setSubmitting(false)
            setSelectedFile(null)
            if (fileInputRef.current) fileInputRef.current.value = ''
        }
    }

    const labelClass = `${styles.res_upload_button}${submitting ? ` ${styles.disabled}` : ''}`
    const submitClass = `${styles.res_upload_submit}${selectedFile && !submitting ? ` ${styles.valid}` : ''}`

    return (
        <div className={styles.content}>
            <h1 className={styles.heading}>Your Resumes</h1>
            <form className={styles.file_submit} onSubmit={handleSubmit}>
                <input
                    ref={fileInputRef}
                    type="file"
                    id="res_upload_input"
                    className={styles.res_upload}
                    accept=".pdf"
                    onChange={handleFileChange}
                    disabled={submitting}
                />
                <label
                    htmlFor="res_upload_input"
                    className={labelClass}
                >
                    {labelText}
                </label>
                <button
                    type="submit"
                    id="res_upload_submit"
                    className={submitClass}
                    disabled={submitting || !selectedFile}
                >
                    Submit
                </button>
            </form>
            <div className={styles.dynamic_resumes}>
                {loadError && <div>{loadError}</div>}
                {!loadError && resumes.length === 0 && <div>No resumes yet.</div>}
                {resumes.map((r, i) => (
                    <div key={r.SK || i} className={styles.icon} title={r.SK}>
                        {r.SK}
                    </div>
                ))}
            </div>
        </div>
    )
}
