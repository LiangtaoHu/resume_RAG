/*
TODO:
- Load up current resumes
- Hook upload resume to actually uploading a resume and then updating your resume UI
*/
const LAMBDA_RESUME_DATA_URL = "/api/v1/view_data"
const LAMBDA_RESUME_UPLOAD_URL = "/api/v1/upload_resume"

const res_input = document.getElementById('res_upload_input');
const res_submit_button = document.getElementById('res_upload_submit');
const res_upload_label = document.getElementById('res_upload_label');
const INVALID_COLOR = '#f5f5f5';
const VALID_COLOR = '#62c472';

async function populate_resumes() {
    const resume_box = document.getElementById("my_resume_box")
    try {
        resume_box.textContent = "Loading data..."
        const response = fetch(LAMBDA_RESUME_DATA_URL, {
            method: 'GET',
            headers: { 'Accept': 'application/json' }
        })
        if (!response.ok) {
            const error_data = await response.json()
            throw Error(error_data.error)
        }
        const user_data = await response.json()
        const resume_data = user_data["resumes"]

        index = 0;
        resume_data.forEach(resume_json => {
            // Resume id is the sorting key. 
            const resume_id = resume_json["SK"]
            // Create a new element and put it in the resume box
            const new_element = document.createElement("div");
            new_element.textContent = resume_id;
            new_element.classList.add("icon");
            new_element.id = index;
            index++;
            resume_box.append(new_element);
        })
    } catch (error) {
        console.log("Error fetching user resumes from Lambda:", error)
        resume_box.textContent = "Failed to load data."
    }
}

async function upload_resume(file_obj) {
    try {
        // TODO: Disable label for further input "grey it out" until at the end where we delete that file
        res_input.disabled = true;
        res_upload_label.textContent = "Uploading File. Please Wait."
        const response = fetch(LAMBDA_RESUME_UPLOAD_URL, {
            method: 'GET', 
            headers: { 'Accept': 'application/json' }
        })
        if (!response.ok) {
            const error_data = await response.json()
            throw Error(error_data.error)
        }
        const response_json = await response.json()
        const s3_link = response_json["link"]
        const fields = response_json["fields"]
        res_upload_label.textContent = "Uploading File"
        const form_data = new FormData()
        Object.entries(fields).forEach(([key, value]) => {
            form_data.append(key, value)
        })
        form_data.append("file", file_obj)
        const response = await fetch(s3_link, {
            method: "POST",
            body: form_data
        })

        if (response.ok) {
             res_upload_label.textContent = "File Uploaded"
             // We need to reflect that something has been uploaded.
             // We can either call to entirely populate the div again or just make a "local" version of what was uploaded. Resume ID is just the filename for now anyway.
            const resume_id = file_obj.name;
            // Create a new element and put it in the resume box
            const resume_box = document.getElementById("my_resume_box")
            const new_element = document.createElement("div");
            new_element.textContent = resume_id;
            new_element.classList.add("icon");
            new_element.id = resume_box.childElementCount;
            resume_box.append(new_element);
        } else {
            throw Error()
        }
    } catch (error) {
        res_upload_label.textContent = "Error uploading user resume to Lambda"
    }
    res_input.disabled = false;
}
//populate_resumes();

// Initialization
res_submit_button.disabled = true;

// Events
res_input.addEventListener('change', (event) => {
    const files = event.target.files;
    if (files && files.length > 0) {
        res_upload_label.textContent = `Selected: ${files[0].name}`;
        res_submit_button.style.backgroundColor = VALID_COLOR;
        res_submit_button.disabled = false;
    } else {
        res_upload_label.textContent = "No file selected";
        res_submit_button.style.backgroundColor = INVALID_COLOR;
        res_submit_button.disabled = true;
    }
})

res_submit_button.addEventListener('click', (event) => {
    res_submit_button.disabled = true;
    res_submit_button.style.backgroundColor = INVALID_COLOR;
    // AWS calls and such then at the end reset the file selected
    user_file = res_input.files[0];
    upload_resume(user_file)
})