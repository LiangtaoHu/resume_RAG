import '../css/Resumes.css'
import FileSubmission from './components/FileSubmission'
import Resume from './components/Resume'
import { useEffect, useState } from 'react'
import { useAuthContext } from '../contexts/AuthContext'

function Resumes() {
    const { userIdentity } = useAuthContext();
    const [resumes, setResumes] = useState([])
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        async function fetchResumes() {
            if (!userIdentity) return
            // TODO
        }
    }, [userIdentity])

    if (loading) {
        return <div className="resume-loading">Loading Your Resumes.</div>
    }

    return <div className="resume-content">
        <h2>Your Resumes</h2>
        <FileSubmission/>
        <div className="resume-grid">
            {resumes.map(resume => (
                <Resume resume={resume} key={resume.id}/>
            ))}
        </div>
    </div>
}

export default Resumes