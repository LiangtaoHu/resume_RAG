import { useState, useEffect } from 'react'
import { useAuthContext } from '../contexts/AuthContext'
import ChatSideBar from '../components/ChatSideBar'
import ChatWindow from '../components/ChatWindow'
import '../css/chats.css'

function Chats() {
    const {userIdentity} = useAuthContext();
    const [activeChatId, setActiveChatId] = useState(null)
    const [chats, SetChats] = useState([])
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
        <ChatSideBar onChatSelect={setActiveChatId} activeChatId={activeChatId}/>
        <ChatWindow chatId={activeChatId} userIdentity={userIdentity}/>
    </div>
}

export default Chats