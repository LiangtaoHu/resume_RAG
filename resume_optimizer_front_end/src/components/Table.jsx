import "../css/Table.css"
import TableHeader from "TableHeader.jsx"
import Listing from "Listing.jsx"
import {useState, useRef} from 'react'

function Table({token, listings, setListings}) {
    const [url, setUrl] = useState("")
    const [isSubmitting, setIsSubmitting] = useState(false)
    const [deleteMode, setDeleteMode] = useState(false)
    const [deleteObjs, setDeleteObjs] = useState([])
    const [status, setStatus] = useState("")

    async function addListing(link) {
        setIsSubmitting(true)
        try {
            const response = await fetch("/api/parse_listing", {
                method: "POST",
                headers: {
                    'Authorization': token,
                    'Content-Type': 'application/json'
                },
                body: {
                    "url": link
                }
            })
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const response_json = await response.json()
            const newListing = response_json["body"]["data"]
            newListing["id"] = listing[-1]["id"]+1
            setListings(prevListings => [...prevListings, newListing])
        } catch (err) {
            setStatus(err)
        } finally {
            setIsSubmitting(false)
        }
    }

    function toggleDeleteMode() {
        //TODO
        //Upon press, you'll be able to select tickboxes next to listings (which just appear) and then press the confirm button that just appears
    }

    function toggleDelete() {
        //TODO
        //Adds a listing to a deleteObjs
    }

    function confirmDelete() {
        //TODO
        //Sends the API call to delete then removes shown listings
    }

    return (
        <div className="listing-table">
            <TableHeader url={url} setUrl={setUrl} addFunc={addListing} deleteFunc={toggleDeleteMode} deleteMode={deleteMode} isSubmitting={isSubmitting} confirmDelete={confirmDelete}/>
            <div className="listing-entries">
                {listings.map(listing => (
                    <Listing listing={listing} key={listing.id} deleteMode={deleteMode} toggleDelete={toggleDelete}/>
                ))}
            </div>
        </div>
    )
}

export default Table