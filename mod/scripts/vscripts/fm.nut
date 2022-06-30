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
table<string, KickInfo> KICK_TABLE = {}
array<string> KICKED_PLAYERS = []

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
    COMMANDS.append(newCommandInfo("!help", commandHelp, 0, "!help => get help"))
    COMMANDS.append(newCommandInfo("!kick", commandKick, 1, "!kick <player> => vote to kick a player"))

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

    thread sendMessage(player, purple(WELCOME))
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
bool function commandHelp(entity player, array<string> args) {
    string help = "available commands:"
    foreach (CommandInfo c in COMMANDS) {
        help += " " + c.name
    }
    thread sendMessage(player, blue(help))
    return true
}

//------------------------------------------------------------------------------
// kick
//------------------------------------------------------------------------------
bool function commandKick(entity player, array<string> args) {
    string playerName = args[0]
    array<entity> foundPlayers = findPlayersBySubstring(playerName)

    if (foundPlayers.len() == 0) {
        sendMessage(player, red("player '" + playerName + "' not found"))
        return false
    }

    if (foundPlayers.len() > 1) {
        sendMessage(player, red("multiple matches for player '" + playerName + "', be more specific"))
        return false
    }

    entity target = foundPlayers[0]
    string targetUid = target.GetUID()
    string targetName = target.GetPlayerName()

    // kick player right away if the voter is an admin
    if (isAdmin(player)) {
        kick(target)
        return true
    }

    if (GetPlayerArray().len() < KICK_MIN_PLAYERS) {
        sendMessage(player, red("not enough players for vote kick, at least " + KICK_MIN_PLAYERS + " are required"))
        return false
    }

    // ensure kicked player is in KICK_TABLE
    if (targetUid in KICK_TABLE) {
        KickInfo kickInfo = KICK_TABLE[targetUid]
        foreach (entity voter in kickInfo.voters) {
            if (voter.GetUID() == player.GetUID()) {
                sendMessage(player, red("you have already voted to kick " + targetName))
                return false
            }
        }

        kickInfo.voters.append(player)
    } else {
        KickInfo kickInfo
        kickInfo.voters = []
        kickInfo.voters.append(player)
        kickInfo.threshold = int(GetPlayerArray().len() * KICK_PERCENTAGE)
        KICK_TABLE[targetUid] <- kickInfo
    }

    // kick if votes exceed threshold
    KickInfo kickInfo = KICK_TABLE[targetUid]
    if (kickInfo.voters.len() >= kickInfo.threshold) {
        kick(target)
    } else {
        int remainingVotes = kickInfo.threshold - kickInfo.voters.len()
        thread announceMessage(blue(player.GetPlayerName() + " voted to kick " + targetName + ", " + remainingVotes + " more vote(s) required"))
    }

    return true
}

void function kick(entity player) {
    string playerUid = player.GetUID()
    if (playerUid in KICK_TABLE) {
        delete KICK_TABLE[playerUid]
    }
    KICKED_PLAYERS.append(playerUid)
    //ServerCommand("kick " + player.GetPlayerName())
    thread announceMessage(blue(player.GetPlayerName() + " has been kicked"))
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
    wait 0.1
    Chat_ServerPrivateMessage(player, text, false)
}

void function announceMessage(string text) {
    wait 0.1
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

bool function isAdmin(entity player) {
    return ADMIN_UIDS.contains(player.GetUID())
}
