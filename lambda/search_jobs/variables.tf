variable "adzuna_app_id" {
    type        = string
    description = "Adzuna application id (https://developer.adzuna.com/)."
    sensitive   = true
}

variable "adzuna_app_key" {
    type        = string
    description = "Adzuna application key."
    sensitive   = true
}

variable "adzuna_default_country" {
    type        = string
    description = "Default country code for Adzuna searches (e.g. 'us', 'gb')."
    default     = "us"
}
