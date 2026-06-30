/*
TODO:
- aws calls
*/

const res_input = document.getElementById('res_upload_input');
const res_submit_button = document.getElementById('res_upload_submit');
const res_upload_label = document.getElementById('res_upload_label');
const INVALID_COLOR = '#f5f5f5';
const VALID_COLOR = '#62c472';


// Initialization
res_submit_button.disabled = true;

// Events
res_input.addEventListener('change', (event) => {
    const files = event.target.files;
    if (files && files.length > 0) {
        console.log(files.length);
        res_upload_label.textContent = `Selected: ${files[0].name}`;
        res_submit_button.style.backgroundColor = VALID_COLOR;
        res_submit_button.disabled = false;
    } else {
        console.log("print");
        res_upload_label.textContent = "No file selected";
        res_submit_button.style.backgroundColor = INVALID_COLOR;
        res_submit_button.disabled = true;
    }
})

res_submit_button.addEventListener('click', (event) => {
    res_submit_button.disabled = true;
    res_submit_button.style.backgroundColor = INVALID_COLOR;
    // AWS calls and such then at the end reset the file selected
    // Grey out file select in the meantime

})

