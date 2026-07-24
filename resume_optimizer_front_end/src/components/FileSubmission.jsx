import { useAuthContext } from '../contexts/AuthContext'
import { useState } from 'react'

function FileSubmission() {
    const fileInputRef = useRef(null)
    const [selectedFile, setSelectedFile] = useState(null)
    const [isSubmitting, setIsSubmitting] = useState(false)
    const [boxStatus, setBoxStatus] = useState("Drop a file here or click to upload!")
    const {token, userIdentity} = useAuthContext();
    const [status, setStatus] = useState("")
    async function handleSubmit(event) {
        event.preventDefault()
        setIsSubmitting(true)  
        try {
            if (!userIdentity) return
            if (!selectedFile) return
    
            const url_response = await fetch("/api/upload_resume", {
                method: "GET",
                headers: {
                    'Authorization': token,
                    'Content-type': "application/json"
                }
            })
            if (!url_response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const url_response_json = await url_response.json()
            const url_link = url_response_json["body"]["link"]
            const url_fields = url_response_json["body"]["fields"]

            const formData = new FormData()
            Object.entries(url_fields).forEach(([key, value]) => {
                formData.append(key, value);
            });
            formData.append("file", selectedFile)
            // Publish now send actual resume into
            const publish_response = await fetch(url_link, {
                method: "POST",
                body: formData
            })

            if (!publish_response.ok) {
                setBoxStatus(`Failed to submit: ${selectedFile.name}`)
            } else {
                setBoxStatus(`Submitted: ${selectedFile.name}`)
                setSelectedFile(null)
                if (fileInputRef.current) {
                    fileInputRef.current.value = ""
                }
            }
        } catch (err) {
            setStatus(err)
        } finally {
            setIsSubmitting(false)
        }
    }
    function fileUploaded(event) {
        if (event.target.files && event.target.files[0]) {
            setSelectedFile(event.target.files[0])
            setBoxStatus(`Selected ${event.target.files[0].name}`)
        }
    }

    return (
        <form className="file-submit" onSubmit={handleSubmit}>
            <input ref={fileInputRef} id="file-input" type="file" className="file-input" accept=".pdf" onChange={fileUploaded} disabled={isSubmitting}/>
            <label htmlFor="file-input" className="file-button" id="file-label">
                {boxStatus}
            </label>
            <button type="submit" disabled={!selectedFile || isSubmitting} className="file-submit">Submit</button>
        </form>
    )
}

export default FileSubmission