global function fm_Init

//------------------------------------------------------------------------------
// structs
//------------------------------------------------------------------------------
struct CommandInfo {
    string name
    bool functionref(entity, array<string>) fn
    int argCount
    string usage
}

struct KickInfo {
    entity target
    array<entity> voters
    int threshold
}

//------------------------------------------------------------------------------
// globals
//------------------------------------------------------------------------------
array<string> ADMIN_UIDS = []

array<CommandInfo> COMMANDS = []

string WELCOME = ""
array<string> WELCOMED_PLAYERS = []

float KICK_PERCENTAGE = 0.0
int KICK_MIN_PLAYERS = 0
array<KickInfo> VOTEKICKS = []
array<entity> KICKED_PLAYERS = []

//------------------------------------------------------------------------------
// init
//------------------------------------------------------------------------------
void function fm_Init() {
    #if SERVER

    initAdmins()
    initWelcome()
    initKick()
    initCommands()

    #endif
}

void function initAdmins() {
    array<string> adminUids = split(GetConVarString("fm_admin_uids"), ",")
    foreach (string uid in adminUids) {
        ADMIN_UIDS.append(strip(uid))
    }
}

void function initWelcome() {
    WELCOME = GetConVarString("fm_welcome")
    if (WELCOME != "") {
        AddCallback_OnPlayerRespawned(OnPlayerRespawnedWelcome)
        AddCallback_OnClientDisconnected(OnClientDisconnectedWelcome)
    }
}

void function initKick() {
    KICK_PERCENTAGE = GetConVarFloat("fm_kick_percentage")
    KICK_MIN_PLAYERS = GetConVarInt("fm_kick_min_players")
}

void function initCommands() {
    COMMANDS.append(newCommandInfo("!help", CommandHelp, 0, "!help => get help"))
    COMMANDS.append(newCommandInfo("!kick", CommandKick, 1, "!kick <player> => vote to kick a player"))

    AddCallback_OnReceivedSayTextMessage(ChatCallback)
}

//------------------------------------------------------------------------------
// command handling
//------------------------------------------------------------------------------
CommandInfo function newCommandInfo(string name, bool functionref(entity, array<string>) fn, int argCount, string usage) {
    CommandInfo commandInfo
    commandInfo.name = name
    commandInfo.fn = fn
    commandInfo.argCount = argCount
    commandInfo.usage = usage
    return commandInfo
}

ClServer_MessageStruct function ChatCallback(ClServer_MessageStruct messageInfo) {
    string message = strip(messageInfo.message)
    bool isCommand = format("%c", message[0]) == "!"
    if (isCommand && !IsLobby()) {
        entity player = messageInfo.player

        array<string> args = split(message, " ")
        string command = args[0]
        args.remove(0)

        bool commandFound = false
        bool commandSuccess = false
        foreach (CommandInfo c in COMMANDS) {
            if (command != c.name) {
                continue
            }

            commandFound = true

            if (args.len() != c.argCount) {
                sendMessage(player, red("usage: " + c.usage))
                commandSuccess = false
                break
            }

            commandSuccess = c.fn(player, args)
        }

        if (!commandFound) {
            sendMessage(player, red("unknown command: " + command))
            messageInfo.shouldBlock = true
        } else if (!commandSuccess) {
            messageInfo.shouldBlock = true
        }
    }

    return messageInfo
}

//------------------------------------------------------------------------------
// welcome
//------------------------------------------------------------------------------
void function OnPlayerRespawnedWelcome(entity player) {
    string uid = player.GetUID()
    if (WELCOMED_PLAYERS.contains(uid)) {
        return
    }

    sendMessage(player, purple(WELCOME))
    WELCOMED_PLAYERS.append(uid)
}

void function OnClientDisconnectedWelcome(entity player) {
    string uid = player.GetUID()
    if (WELCOMED_PLAYERS.contains(uid)) {
        WELCOMED_PLAYERS.remove(WELCOMED_PLAYERS.find(uid))
    }
}

//------------------------------------------------------------------------------
// help
//------------------------------------------------------------------------------
bool function CommandHelp(entity player, array<string> args) {
    string help = "available commands:"
    foreach (CommandInfo c in COMMANDS) {
        help += " " + c.name
    }
    sendMessage(player, blue(help))
    return true
}

//------------------------------------------------------------------------------
// kick
//------------------------------------------------------------------------------
bool function CommandKick(entity player, array<string> args) {
    string playerName = args[0]
    array<entity> foundPlayers = findPlayersBySubstring(playerName)

    if (foundPlayers.len() == 0) {
        sendMessage(player, red("player '" + playerName + "' not found"))
        return false
    }

    if (foundPlayers.len() > 1) {
        sendMessage(player, red("multiple matches for player '" + playerName + "', be more specific"))
    }

    entity target = foundPlayers[0]

    return true
}

//------------------------------------------------------------------------------
// utils
//------------------------------------------------------------------------------
string function red(string s) {
    return "\x1b[1;31m" + s
}

string function blue(string s) {
    return "\x1b[1;34m" + s
}

string function purple(string s) {
    return "\x1b[1;35m" + s
}

void function sendMessage(entity player, string text) {
    Chat_ServerPrivateMessage(player, text, false)
}

void function announceMessage(string text) {
    Chat_ServerBroadcast(text)
}

array<entity> function findPlayersBySubstring(string substring) {
    substring = substring.tolower()
    array<entity> players = []
    foreach (entity player in GetPlayerArray()) {
        string name = player.GetPlayerName().tolower()
        if (name.find(substring) != null) {
            players.append(player)
        }
    }

    return players
}
