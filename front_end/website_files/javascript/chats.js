const conversation_selection = document.getElementById("conversation_selection");
const creation_menu = document.getElementById("creation_menu");

const create_button = document.getElementById("create_button");
const back_button = document.getElementById("back_button");

resume_selected = false;
resume_id_selected = null;
listing_selected = false;
listing_id_selected = null;

create_button.addEventListener("click", (event) => {
    conversation_selection.classList.add('hidden');
    creation_menu.classList.remove('hidden');
});

back_button.addEventListener("click", (event) => {
    creation_menu.classList.add('hidden');
    conversation_selection.classList.remove('hidden');
});

const current_icons = Array.from(document.getElementsByClassName("icon"));
const current_resume_icons = current_icons.filter(el => el.parentNode.id === "resume_grid");
const current_listing_icons = current_icons.filter(el => el.parentNode.id === "listings_grid");

current_resume_icons.forEach(icon => icon.addEventListener("click", (event) => {
    if (resume_selected == false) {
        resume_selected = true;
        resume_id_selected = icon
        icon.classList.add('selected');
    } else {
        if (resume_id_selected == icon) {
            resume_selected = false;
            resume_id_selected = null;
            icon.classList.remove('selected');
        }
    }
}));

current_listing_icons.forEach(icon => icon.addEventListener("click", (event) => {
    if (listing_selected == false) {
        listing_selected = true;
        listing_id_selected = icon
        icon.classList.add('selected');
    } else {
        if (listing_id_selected == icon) {
            listing_selected = false;
            listing_id_selected = null;
            icon.classList.remove('selected');
        }
    }
}));