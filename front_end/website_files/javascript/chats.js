const conversation_selection = document.getElementById("conversation_selection");
const creation_menu = document.getElementById("creation_menu");
const chat_history = document.getElementById("chat_history");

const message_text_field = document.getElementById("message_space");

const create_button = document.getElementById("create_button");
const back_button = document.getElementById("back_button");
const generate_button = document.getElementById("generate_chat_button");
const message_submit_button = document.getElementById("submit_message_button");

const current_icons = Array.from(document.getElementsByClassName("icon"));
const current_resume_icons = current_icons.filter(el => el.parentNode.id === "resume_grid");
const current_listing_icons = current_icons.filter(el => el.parentNode.id === "listings_grid");
const conversation_icons = current_icons.filter(el => el.parentNode.id == "conversation_selection");

conversations = []
const test_messages = [
    {'role': "Agent", 'message': 'hey whats up dog'}, 
    {'role': 'User', 'message':'hahahahahahah i get the joke. HAH HAHAHHA. ITS SO FUNNY LIKE UP DOG LOL.'},
    {'role': 'User', 'message':'hahahahahahah i get the joke. HAH HAHAHHA. ITS SO FUNNY LIKE UP DOG LOL.'},
    {'role': 'User', 'message':'hahahahahahah i get the joke. HAH HAHAHHA. ITS SO FUNNY LIKE UP DOG LOL.'},
    {'role': 'User', 'message':'hahahahahahah i get the joke. HAH HAHAHHA. ITS SO FUNNY LIKE UP DOG LOL.'},
    {'role': 'User', 'message':'hahahahahahah i get the joke. HAH HAHAHHA. ITS SO FUNNY LIKE UP DOG LOL.'},
    {'role': "Agent", 'message': 'dude chill out man. I\'m just a robot *wink* but I still have feelings you know. If you didn\t like the joke you could\'ve just said so calmly.'},
];
conversations.push(test_messages);

generate_button.disabled = true;
message_submit_button.disabled = true;
message_text_field.disabled = true;

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

current_resume_icons.forEach(icon => icon.addEventListener("click", (event) => {
    if (resume_selected == false) {
        resume_selected = true;
        resume_id_selected = icon
        icon.classList.add('selected');
        if (resume_selected && listing_selected) {
            generate_button.disabled = false;
        }
    } else {
        if (resume_id_selected == icon) {
            resume_selected = false;
            resume_id_selected = null;
            icon.classList.remove('selected');
            generate_button.disabled = true;
        }
    }
}));

current_listing_icons.forEach(icon => icon.addEventListener("click", (event) => {
    if (listing_selected == false) {
        listing_selected = true;
        listing_id_selected = icon
        icon.classList.add('selected');
        if (resume_selected && listing_selected) {
            generate_button.disabled = false;
        }
    } else {
        if (listing_id_selected == icon) {
            listing_selected = false;
            listing_id_selected = null;
            icon.classList.remove('selected');
            generate_button.disabled = true;
        }
    }
}));

conversation_icons.forEach(icon => icon.addEventListener("dblclick", (event) => {
    destroy_chat();
    console.log('hey')
    set_up_chat(conversations[parseInt(icon.id)]);
}));

/*
Loading up chat history function. 
Chat History format for now (will add generated file later):
[
    {
        "role": "User",
        "message": "text"
    }, 
    {
        "role": "Agent",
        "message": "text"
    }
]
*/
function load_data() {}

function add_message(message) {
    const message_div = document.createElement('div');
    message_div.textContent = message['message']
    if (message['role'] == "Agent") {
        message_div.classList.add('agent_message')
    } else {
        message_div.classList.add('user_message')
    }
    chat_history.append(message_div);
}

function populate_chat_history(messages_json) {
    messages_json.forEach(message => {
        add_message(message)
    });
}

function set_up_chat(messages_json) {
    populate_chat_history(messages_json)
    chat_history.scrollTop = chat_history.scrollHeight;
    message_text_field.disabled = false;
    message_submit_button.disabled = false;
}

function destroy_chat() {
    chat_history.replaceChildren();
    message_text_field.value = "";
    chat_history.scrollTop = chat_history.scrollHeight;
}

message_submit_button.addEventListener("click", (event) => {
    if (message_text_field.value != "") {
        add_message({"role": "user", "message": message_text_field.value});
        message_text_field.value = "";
        chat_history.scrollTop = chat_history.scrollHeight;
    }
});