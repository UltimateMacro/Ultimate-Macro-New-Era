WebhookMentionSettings(settings) {
    if IniRead(settings, "Webhook", "MentionEvents", 0) != 1
        return ""
    id := Trim(IniRead(settings, "Webhook", "WebhookUserID", ""))
    return WebhookMentionIDValid(id) ? id : ""
}

WebhookMentionIDValid(id) => id ~= "^[0-9]{17,20}$"

WebhookMentionFields(id := "") {
    if !WebhookMentionIDValid(id)
        return '"allowed_mentions":{"parse":[]},'
    return '"content":"<@' id '>","allowed_mentions":{"parse":[],"users":["' id '"]},'
}
