import "../css/ChatSidebar.css"
import {useState} from 'react'
import Icon from "./Icon.jsx"

function ChatSidebar({setActiveConversation, conversations, listings, resumes, userIdentity, setConversations}) {
    const [onSelection, setOnSelection] = useState(true)
    const [selectedConv, setSelectedConv] = useState(null)
    const [selectedListing, setSelectedListing] = useState(null)
    const [selectedResume, setSelectedResume] = useState(null)
    const generateButtonCond = !(selectedListing && selectedResume)
    function handleGenerate() {
        new_chat_item = {
            'HK': `USER#${userIdentity}`,
            'SK': `CONV#${selectedResume.SK.replace("RESUME#", "")}-${selectedListing.SK.replace("JOB#", "")}`,
            'resumeID': selectedResume.SK.replace("RESUME#", ""),
            'jobID': selectedListing.SK.replace("JOB#", ""),
            'chatHistory': {}
        }
        setConversations(prevConv => [...prevConv, new_chat_item])
        setActiveConversation(new_chat_item)
    }

    function loadConversation() {
        setActiveConversation(selectedConv)
    }

    return <div className="chat-sidebar">
        <div className="selectionScreen" hidden={!onSelection}>
            <button className="create-conv-button" type="button" onClick={() => {setOnSelection(false)}}>Create</button>
            {conversations.map(conv => (
                <Icon obj={conv} key={conv.id} onClick={() => {setSelectedConv(conv)}} isSelected={selectedConv?.id === conv.id}/> 
            ))}
            <button type="button" className="load-conv-button" disabled={!selectedConv} onClick={loadConversation}>Load</button>
        </div>
        
        <div className="generateScreen" hidden={onSelection}>
            <button type="button" className="back-button" onClick={() => {setOnSelection(true)}}>&lt;&lt;</button>
            <div id="resume-grid" className="creation-grid">
                {resumes.map(resume => (
                    <Icon obj={resume} key={resume.id} onClick={() => {setSelectedResume(resume)}} isSelected={selectedResume?.id === resume.id}/>
                ))}
            </div>
            <h1 className="plus-symbol">+</h1>
            <div id="listing-grid" className="creation-grid">
                {listings.map(listing => (
                    <Icon obj={listing} key={listing.id} onClick={() => {setSelectedListing(listing)}} isSelected={selectedListing?.id === listing.id}/>
                ))}
            </div>
            <button type="button" className="submit-generate-button" disabled={generateButtonCond} onClick={handleGenerate}>Generate</button>
        </div>
    </div>
}

export default ChatSidebar