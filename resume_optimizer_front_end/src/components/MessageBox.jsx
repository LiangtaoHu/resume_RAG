import {useState} from 'react'
import '../css/MessageBox.css'

function MessageBox({onSendMessage, userIdentity}) {
    const [userMessage, setUserMessage] = useState("")
    const [isSubmitting, setIsSubmitting] = useState(false)

    function handleSubmit() {
        // TODO
        // Send local message via setNewMessages, then API call, reset usermessage
        // If API Call fails, retract userMessage
        // If API Call succeeds, add Agent Message
        // While waiting for API Call to finish disable more messages via button blocking
    }

    return <div className="message-box">
        <textarea class="message-input" value={userMessage} onChange={(e) => {setUserMessage(e.target.value)}}></textarea>
        <div className="bottom-message-bar">
            <button className="submit-message-button" type="button" onClick={handleSubmit} disabled={!userMessage.trim() || isSubmitting}>
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="arrow_icon">
                    <path d="M13 19V7.83l5.59 5.59L20 12l-8-8-8 8 1.41 1.41L11 7.83V19h2z"/>
                </svg>
            </button> 
        </div>
    </div>
}

export default MessageBox