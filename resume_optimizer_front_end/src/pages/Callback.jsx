import { useState, useEffect } from 'react'

function Callback() {
    const [text, setText] = useState('Please Wait.')
    useEffect(() => {
        async function fetchData() {
            //TODO:
            try {
                
            } catch (err) {

            } finally {
                setText("Properly Validated. You may now go to the dashboard.")
            }
        }
        fetchData();
    }, [])
    return <div className="callback-content">{text}</div>
}

export default Callback