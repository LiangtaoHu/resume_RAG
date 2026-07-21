import { useAuthContext } from '../contexts/AuthContext'
import { useState } from 'react'

function FileSubmission() {
    const [selectedFile, setSelectedFile] = useState(null)
    const [submitStatus, setSubmitStatus] = useState(false)
    const {userIdentity} = useAuthContext();
    function handleSubmit() {
        //TODO
        //Publishes to API with file under user identity
        if (!userIdentity) return
        if (!fileUploaded) return
        //Some API Call
        //WIPE file, reset (let the file object live but move out of event?) if success, preserve if fail
    }
    function fileUploaded(event) {
        if (event.target.files && event.target.files[0]) {
            setSelectedFile(event.target.files[0])
        }
    }

    return (
        <form className="file-submit" onSubmit={handleSubmit}>
            <input id="file-input" type="file" className="file-input" accept=".pdf" onChange={fileUploaded}/>
            <label htmlFor="file-input" className="file-button" id="file-label">
                {submitStatus ? `Submitted: ${selectedFile.name}`: (selectedFile ? `Selected: ${selectedFile.name}` : "Drop a file here or click to upload!")}
            </label>
            <button type="submit" disabled={!selectedFile} className="file-submit">Submit</button>
        </form>
    )
}

export default FileSubmission