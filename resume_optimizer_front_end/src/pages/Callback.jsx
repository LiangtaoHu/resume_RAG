import { useState, useEffect } from 'react'

function Callback() {
    const [text, setText] = useState('Please Wait.')
    useEffect(() => {
        async function fetchData() {
            //TODO:
        }
        fetchData();
    }, [])
    return <div className="callback-content">{text}</div>
}

export default Callback