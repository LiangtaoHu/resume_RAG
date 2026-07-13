let parsing_in_progress = false;
const test_listings = [{"name": "Listing 1", "url": "url1", "job_position": "pos1", "job_company": "com1"}, 
    {"name": "Listing 2", "url": "url2", "job_position": "pos2", "job_company": "com2", "creation_details": "timestamp"}]

const table_entries = document.getElementById("table_entries");
const LAMBDA_LISTING_URL = ""

async function retrieve_listings() {
    try {
        table_entries.textContent = "Loading data..."
        const response = fetch(LAMBDA_LISTING_URL, {
            method: 'GET',
            headers: { 'Accept': 'application/json' }
        })
        if (!response.ok) {
            const error_data = await response.json()
            throw Error(error_data.error)
        }
        const user_data = await response.json()
        const listing_data = user_data["listings"]

        index = 0;
        listing_data.forEach(resume_json => {
            const listing_entry = {
                'name': resume_json['SK'],
                'url': resume_json['url'],
                "job_position": resume_json["position"],
                "job_company": resume_json["company"],
            }
            test_listings.append(listing_entry)
        })
    } catch (error) {
        table_entries.textContent = "Error fetching user listings from Lambda"
    }
}

function populate_listings(listings) {
    //retrieve_listings();
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

const add_button = document.getElementById("add_button")

async function publish_listing(link) {
    const LAMBDA_PARSE_LISTING = "/api/v1/parse_listing"
    try {
        const response = await fetch(LAMBDA_PARSE_LISTING, {
            method: "POST", 
            headers: {
                'Content-Type': 'text/plain'
            },
            body: link
        });
        if (response.ok) {
            // We need to reload our table by adding a new entry to illustrate we added something
            // The problem this time is that we'll need the lambda to finish in order to recognize the job listing. 
            // We can in the mean time create an "instance" of the job listing in our table and provide the details of it later. 
            // However because the current approach is to use the job title as the id, this doesn't work. 
            // Temp Sol: Just add a temporary entry named "New Submission in progress." with filler details.
            const listing_entry = {
                'name': 'New Submission in progress.',
                'url': link,
                "job_position": "Currently Processing",
                "job_company": "Currently Processing",
            }
            listings.append(listing_entry)
            const new_element = document.createElement("div");
            new_element.textContent = 'New Submission in progress';
            new_element.classList.add("listing");
            new_element.id = table_entries.childElementCount;
            table_entries.append(new_element);
        } else {
            const error_data = await response.json()
            throw Error(error_data.error)
        }
    } catch (error) {
        alert(error.message)
    }
    parsing_in_progress = false;
}

add_button.addEventListener("click", (event) => {
    if (!parsing_in_progress) {
        parsing_in_progress = true;
        let link = prompt("Please enter a job posting link.")
        publish_listing(link)
    }
})