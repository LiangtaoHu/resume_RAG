const test_listings = [{"name": "Listing 1", "url": "url1", "job_position": "pos1", "job_company": "com1", "creation_details": "timestamp"}, 
    {"name": "Listing 2", "url": "url2", "job_position": "pos2", "job_company": "com2", "creation_details": "timestamp"}]

const table_entries = document.getElementById("table_entries");

function populate_listings(listings) {
    index = 0;
    listings.forEach(listing => {
        const new_element = document.createElement("div");
        new_element.textContent = listing["name"];
        new_element.classList.add("listing");
        new_element.id = index;
        index++;
        table_entries.append(new_element);
    })
}

populate_listings(test_listings)

const side_view_details = document.getElementById("listing_details");
const listings = Array.from(document.getElementsByClassName("listing"));
const view_listings = document.getElementById("view_listings")
const close_side_view_button = document.getElementById("close_side_view")

listing_id_selected = null;

close_side_view_button.addEventListener("click", (event) => {
    if (listing_id_selected != null) {
        listing_id_selected.classList.remove('selected');
    }
    view_listings.classList.remove('info_shown')
})

listings.forEach(listing => listing.addEventListener("click", (event) => {
    // Update side view then make it visible
    listing_json = test_listings[listing.id];
    
    if ((listing_id_selected != listing) && (listing_id_selected != null)) {
        listing_id_selected.classList.remove('selected');
    }
    listing_id_selected = listing;
    listing.classList.add('selected');

    const attributes = side_view.querySelectorAll(".listing_details > div");
    attributes.forEach(attribute => {
        const value_div = attribute.querySelector("div");
        const attributeKey = attribute.className;
        value_div.textContent = listing_json[attributeKey];
    })

    if (!view_listings.classList.contains('info_shown')) {
        view_listings.classList.add('info_shown')
    }
}));