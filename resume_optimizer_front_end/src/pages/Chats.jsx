import { useState, useEffect } from 'react'
import { useAuthContext } from '../contexts/AuthContext'
import ChatSideBar from '../components/ChatSidebar'
import ChatWindow from '../components/ChatWindow'
import '../css/chats.css'

function Chats() {
    const {token} = useAuthContext();
    const [activeConversation, setActiveConversation] = useState(null)
    const [conversations, setConversations] = useState([])
    const [listings, setListings] = useState([])
    const [resumes, setResumes] = useState([])
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        async function loadUserChats() {
            try {
                if (!token) return; 
                const response = await fetch('/api/conversation_starter')
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                const result = await response.json()
                setConversations(result["data"]["conversations"])
            } catch (err) {
                setStatus(err)
            } finally {
                setLoading(false)
            }
        }
        loadUserChats();
    }, []);

    if (loading) {
        return <div className="chats-loading">Loading your conversations</div>
    }

    return <div className="chats-content">
        <ChatSideBar onChatSelect={setActiveConversation} conversations={conversations} listings={listings} resumes={resumes}/>
        <ChatWindow conversation={activeConversation} token={token}/>
    </div>
}

export default Chats