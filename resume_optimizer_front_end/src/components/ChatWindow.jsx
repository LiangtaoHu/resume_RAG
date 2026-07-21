import "../css/ChatWindow.css"
import ChatHistory from "ChatHistory.jsx"
import MessageBox from "MessageBox.jsx"
import {useState, useEffect} from 'react'

function ChatWindow({activeConversation, userIdentity}) {
    const [messages, setMessages] = useState([])
    useEffect(() => {
        setMessages(activeConversation?.ChatHistory || [])
    }, [activeConversation])

    const handleAddMessage = (newMessage) => {
        setMessages((prevMessages) => [...prevMessages, newMessage])
    }

    return (
        <div className="chat-window">
            <ChatHistory messages={messages}/>
            <MessageBox onSendMessage={handleAddMessage} userIdentity={userIdentity}/>
        </div>
    )
}

export default ChatWindow