import '../css/Listings.css'
import { useState, useEffect } from 'react'
import Table from './components/Table'
import { useAuthContext } from '../contexts/AuthContext'

function Listings() {
    const {token} = useAuthContext();
    const [listings, setListings] = useState([])
    const [status, setStatus] = useState("")
    const [activeListing, setActiveListing] = useState(null)
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        async function fetchListings() {
            try {
                if (!token) return; 
                const response = await fetch('/api/conversation_starter')
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                const result = await response.json()
                setListings(result["data"]["job_listings"])
            } catch (err) {
                setStatus(err)
            } finally {
                setLoading(false)
            }
        }
        fetchListings()
    }, [])

    if (loading) {
        return <div className="listing-loading">Loading Your Listings</div>
    }

    return <div className="listing-content">
        <h2>Your Listings</h2>
        <Table content={listings} setListings={setListings}/>
    </div>
}

export default Listings