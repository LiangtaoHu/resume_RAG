import "../css/Listing.css"

function Listing({listing, deleteMode, toggleDelete}) {
    return (
        <div className="listing">
            {deleteMode && <input type="checkbox" onClick={toggleDelete}></input>}
            <p>{listing.SK}</p>
        </div>
    )
}

export default Listing