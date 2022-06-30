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

void function message(entity player, string text) {
    Chat_ServerPrivateMessage(player, text, false)
}

//------------------------------------------------------------------------------
// welcome
//------------------------------------------------------------------------------
void function OnPlayerRespawnedWelcome(entity player) {
    string uid = player.GetUID()
    if (welcomedPlayers.contains(uid)) {
        return
    }

    message(player, red(welcome))
    welcomedPlayers.append(uid)
}

void function OnClientDisconnectedWelcome(entity player) {
    string uid = player.GetUID()
    if (welcomedPlayers.contains(uid)) {
        welcomedPlayers.remove(welcomedPlayers.find(uid))
    }
}
