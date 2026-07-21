import "../css/TableHeader.css"

function TableHeader({url, setUrl, addFunc, deleteFunc, deleteMode}) {
    if (deleteMode)
    return (
        <div className="table-header">
            <div className="add-field">
                <input type="text" placeholder="Job URL" value={url} onChange={(e) => setUrl(e.target.value)}></input>
                <button type="button" onClick={() => {addFunc(url)}}>Add +</button>
            </div>
            <div className="delete-field">
                <button type="button" onClick={deleteFunc}>Delete -</button>
            </div>
            {deleteMode && <div className="confirm-field"><button type="button" onClick={confirmDelete}>Confirm</button></div>}
        </div>
    )
}

export default TableHeader