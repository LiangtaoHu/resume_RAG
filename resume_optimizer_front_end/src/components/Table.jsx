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

    function toggleDelete(listing) {
        setDeleteObjs(prevObjs => [...prevObjs, listing])
    }

    function confirmDelete() {
        //TODO
        //Sends the API call to delete then removes shown listings
        setIsSubmitting(true)
        try {
            deleteObjs.forEach(item => {
                const response = fetch("/api/delete_entries", {
                    method: "POST", 
                    headers: {
                        'Authorization': token, 
                        'Content-type': 'application/json'
                    },
                    body: {
                        "listing_id": JSON.stringify({deleteObjs})
                    }
                })
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
            })
            setListings(listings.filter(item => !deleteObjs.includes(item)))
            setDeleteObjs([])
            setDeleteMode(false)
        } catch(err) {
            setStatus(err)
        } finally {
            setIsSubmitting(false)
        }
    }

    return (
        <div className="listing-table">
            <TableHeader url={url} setUrl={setUrl} addFunc={addListing} deleteFunc={setDeleteMode} deleteMode={deleteMode} isSubmitting={isSubmitting} confirmDelete={confirmDelete}/>
            <div className="listing-entries">
                {listings.map(listing => (
                    <Listing listing={listing} key={listing.id} deleteMode={deleteMode} toggleDelete={toggleDelete}/>
                ))}
            </div>
        </div>
    )
}

export default Table