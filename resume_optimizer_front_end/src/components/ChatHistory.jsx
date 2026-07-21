import '../css/ChatHistory.css'

function ChatHistory({messages}) {
    return <div className="chat-history">
        {messages.map((msg, index) => (
            <div key={index} className={msg["role"] === "Agent" ? "agent-message" : "client-message"}>{msg["message"]}</div>
        ))}
    </div>
}

export default ChatHistory