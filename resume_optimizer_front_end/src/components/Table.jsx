import "../css/Table.css"
import TableHeader from "TableHeader.jsx"
import Listing from "Listing.jsx"
import {useState} from 'react'

function Table({listings, setListings}) {
    const [url, setUrl] = useState("")
    const [deleteMode, setDeleteMode] = useState(false)
    const [deleteObjs, setDeleteObjs] = useState([])

    function addListing(link) {
        //TODO
        //Local ID will be shown of the highest + 1
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
            <TableHeader url={url} setUrl={setUrl} addFunc={addListing} deleteFunc={toggleDeleteMode} deleteMode={deleteMode}/>
            <div className="listing-entries">
                {listings.map(listing => (
                    <Listing listing={listing} key={listing.id} deleteMode={deleteMode} toggleDelete={toggleDelete}/>
                ))}
            </div>
        </div>
    )
}

export default Table