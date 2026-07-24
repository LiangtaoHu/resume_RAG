import '../css/Resumes.css'
import FileSubmission from './components/FileSubmission'
import Icon from './components/Icon'
import { useEffect, useState } from 'react'
import { useAuthContext } from '../contexts/AuthContext'

function Resumes() {
    const { token } = useAuthContext();
    const [resumes, setResumes] = useState([])
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        async function fetchResumes() {
            if (!token) return
            try {
                const response = await fetch("/api/conversation_starter")
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                const result = await response.json()
                setResumes(result["data"]["resumes"])
            } catch (err) {
                setStatus(err)
            } finally {
                setLoading(false)
            }
        }
        fetchResumes()
    }, [])

    if (loading) {
        return <div className="resume-loading">Loading Your Resumes.</div>
    }

    return <div className="resume-content">
        <h2>Your Resumes</h2>
        <FileSubmission/>
        <div className="resume-grid">
            {resumes.map(resume => (
                <Icon obj={resume} key={resume.id}/>
            ))}
        </div>
    </div>
}

export default Resumes