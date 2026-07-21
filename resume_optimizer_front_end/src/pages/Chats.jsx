import { useState, useEffect } from 'react'
import { useAuthContext } from '../contexts/AuthContext'
import ChatSideBar from '../components/ChatSideBar'
import ChatWindow from '../components/ChatWindow'
import '../css/chats.css'

function Chats() {
    const {userIdentity} = useAuthContext();
    const [activeConversation, setActiveConversation] = useState(null)
    const [conversations, setConversations] = useState([])
    const [listings, setListings] = useState([])
    const [resumes, setResumes] = useState([])
    const [loading, setLoading] = useState(true)

    useEffect(() => {
        async function loadUserChats() {
            if (!userIdentity) return;
            //TODO
        }
        loadUserChats();
    }, [userIdentity]);

    if (loading) {
        return <div className="chats-loading">Loading your conversations</div>
    }

    return <div className="chats-content">
        <ChatSideBar onChatSelect={setActiveConversation} conversations={conversations} listings={listings} resumes={resumes}/>
        <ChatWindow conversation={activeConversation} userIdentity={userIdentity}/>
    </div>
}

export default Chats