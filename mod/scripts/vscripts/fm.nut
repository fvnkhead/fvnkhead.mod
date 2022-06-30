global function fm_Init

//------------------------------------------------------------------------------
// globals
//------------------------------------------------------------------------------
string welcome = ""
array<string> welcomedPlayers = []

void function fm_Init() {
    welcome = GetConVarString("fm_welcome")
    if (welcome != "") {
        AddCallback_OnPlayerRespawned(OnPlayerRespawnedWelcome)
        AddCallback_OnClientDisconnected(OnClientDisconnectedWelcome)
    }

    AddCallback_OnReceivedSayTextMessage(ChatCallback)
}

//------------------------------------------------------------------------------
// utils
//------------------------------------------------------------------------------
string function red(string s) {
    return "\x1b[0;31m" + s
}

string function blue(string s) {
    return "\x1b[0;34m" + s
}

string function purple(string s) {
    return "\x1b[0;35m" + s
}

void function message(entity player, string text) {
    Chat_ServerPrivateMessage(player, text, false)
}

void function announce(string text) {
    Chat_ServerBroadcast(text)
}

//------------------------------------------------------------------------------
// welcome
//------------------------------------------------------------------------------
void function OnPlayerRespawnedWelcome(entity player) {
    string uid = player.GetUID()
    if (welcomedPlayers.contains(uid)) {
        return
    }

    message(player, purple(welcome))
    welcomedPlayers.append(uid)
}

void function OnClientDisconnectedWelcome(entity player) {
    string uid = player.GetUID()
    if (welcomedPlayers.contains(uid)) {
        welcomedPlayers.remove(welcomedPlayers.find(uid))
    }
}

//------------------------------------------------------------------------------
// command handling
//------------------------------------------------------------------------------
ClServer_MessageStruct function ChatCallback(ClServer_MessageStruct messageInfo) {
    string message = strip(messageInfo.message)
    bool isCommand = format("%c", message[0]) == "!"
    if (isCommand) {
        announce(blue("got command"))
        entity player = messageInfo.player

        array<string> args = split(message, " ")
        args.remove(0)

        handleCommand(player, message, args)
    }

    return messageInfo
}

void function handleCommand(entity player, string command, array<string> args) {
    message(player, "command " + command)
}
