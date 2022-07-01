//------------------------------------------------------------------------------
// shamelessly stolen code from takyon
//------------------------------------------------------------------------------

global function fm_Init

//------------------------------------------------------------------------------
// structs
//------------------------------------------------------------------------------
struct CommandInfo {
    string name
    bool functionref(entity, array<string>) fn
    int argCount,
    bool isSilent,
    bool isAdmin,
    string usage
}

struct KickInfo {
    array<entity> voters
    int threshold
}

//------------------------------------------------------------------------------
// globals
//------------------------------------------------------------------------------
struct {
    array<string> adminUids
    string adminPassword
    array<string> authenticatedAdmins

    array<CommandInfo> commands

    string welcome
    array<string> welcomedPlayers

    float kickPercentage
    int kickMinPlayers
    table<string, KickInfo> kickTable
    array<string> kickedPlayers

    array<string> maps
} file

//------------------------------------------------------------------------------
// init
//------------------------------------------------------------------------------
void function fm_Init() {
    #if SERVER

    array<string> adminUids = split(GetConVarString("fm_admin_uids"), ",")
    foreach (string uid in adminUids) {
        file.adminUids.append(strip(uid))
    }
    file.adminPassword = GetConVarString("fm_admin_password")
    file.authenticatedAdmins = []

    file.welcome = GetConVarString("fm_welcome")
    if (file.welcome != "") {
        AddCallback_OnPlayerRespawned(OnPlayerRespawnedWelcome)
        AddCallback_OnClientDisconnected(OnClientDisconnectedWelcome)
    }
    file.welcomedPlayers = []

    file.kickPercentage = GetConVarFloat("fm_kick_percentage")
    file.kickMinPlayers = GetConVarInt("fm_kick_min_players")
    file.kickTable = {}
    file.kickedPlayers = []

    file.maps = []
    array<string> maps = split(GetConVarString("fm_maps"), ",")
    foreach (string map in maps) {
        file.maps.append(strip(map))
    }
    AddCallback_GameStateEnter(eGameState.Postmatch, PostmatchNextMap)

    file.commands.append(NewCommandInfo("!help", CommandHelp, 0, false, false, "!help => get help"))
    file.commands.append(NewCommandInfo("!kick", CommandKick, 1, false, false, "!kick <full or partial player name> => vote to kick a player"))
    file.commands.append(NewCommandInfo("!maps", CommandMaps, 0, false, false, "!maps => list available maps"))
    file.commands.append(NewCommandInfo("!auth", CommandAuth, 1, true, true,  "!auth <password> => authenticate yourself as an admin"))

    AddCallback_OnReceivedSayTextMessage(ChatCallback)

    #endif
}

//------------------------------------------------------------------------------
// command handling
//------------------------------------------------------------------------------
CommandInfo function NewCommandInfo(string name, bool functionref(entity, array<string>) fn, int argCount, bool isSilent, bool isAdmin, string usage) {
    CommandInfo commandInfo
    commandInfo.name = name
    commandInfo.fn = fn
    commandInfo.argCount = argCount
    commandInfo.isSilent = isSilent
    commandInfo.isAdmin = isAdmin
    commandInfo.usage = usage
    return commandInfo
}

ClServer_MessageStruct function ChatCallback(ClServer_MessageStruct messageInfo) {
    if (IsLobby()) {
        return messageInfo
    }

    entity player = messageInfo.player
    string message = strip(messageInfo.message)
    bool isCommand = format("%c", message[0]) == "!"
    if (!isCommand) {
        if (IsAdmin(player) && message.tolower().find(file.adminPassword.tolower())) {
            SendMessage(player, Red("learn to type, mewn"))
            messageInfo.shouldBlock = true
        }
        return messageInfo
    }

    array<string> args = split(message, " ")
    string command = args[0]
    args.remove(0)

    bool commandFound = false
    bool commandSuccess = false
    foreach (CommandInfo c in file.commands) {
        if (command != c.name) {
            continue
        }

        if (c.isAdmin && !IsAdmin(player)) {
            break
        }

        commandFound = true
        messageInfo.shouldBlock = c.isSilent

        if (args.len() != c.argCount) {
            SendMessage(player, Red("usage: " + c.usage))
            commandSuccess = false
            break
        }

        commandSuccess = c.fn(player, args)
    }

    if (!commandFound) {
        SendMessage(player, Red("unknown command: " + command))
        messageInfo.shouldBlock = true
    } else if (!commandSuccess) {
        messageInfo.shouldBlock = true
    }

    return messageInfo
}

//------------------------------------------------------------------------------
// welcome
//------------------------------------------------------------------------------
void function OnPlayerRespawnedWelcome(entity player) {
    string uid = player.GetUID()
    if (file.welcomedPlayers.contains(uid)) {
        return
    }

    SendMessage(player, Blue(file.welcome))
    if (IsAdmin(player)) {
        string additional = "it looks like you're an admin, use !auth <password> to gain special powers"
        SendMessage(player, Blue(additional))
    }

    file.welcomedPlayers.append(uid)
}

void function OnClientDisconnectedWelcome(entity player) {
    string uid = player.GetUID()
    if (file.welcomedPlayers.contains(uid)) {
        file.welcomedPlayers.remove(file.welcomedPlayers.find(uid))
    }
}

//------------------------------------------------------------------------------
// help
//------------------------------------------------------------------------------
bool function CommandHelp(entity player, array<string> args) {
    string help = "available commands:"
    foreach (CommandInfo c in file.commands) {
        if (c.isAdmin && !IsAdmin(player)) {
            continue
        }
        help += " " + c.name
    }
    thread AsyncSendMessage(player, Blue(help))
    return true
}

//------------------------------------------------------------------------------
// kick
//------------------------------------------------------------------------------
bool function CommandKick(entity player, array<string> args) {
    string playerName = args[0]
    array<entity> foundPlayers = FindPlayersBySubstring(playerName)

    if (foundPlayers.len() == 0) {
        SendMessage(player, Red("player '" + playerName + "' not found"))
        return false
    }

    if (foundPlayers.len() > 1) {
        SendMessage(player, Red("multiple matches for player '" + playerName + "', be more specific"))
        return false
    }

    entity target = foundPlayers[0]
    string targetUid = target.GetUID()
    string targetName = target.GetPlayerName()

    // admins are safe from kicking (for now)
    if (IsAdmin(target)) {
        SendMessage(player, Red("you cannot kick an admin"))
        return false
    }

    // kick player right away if the voter is an admin
    if (IsAuthenticatedAdmin(player)) {
        KickPlayer(target)
        return true
    }

    if (GetPlayerArray().len() < file.kickMinPlayers) {
        SendMessage(player, Red("not enough players for vote kick, at least " + file.kickMinPlayers + " are required"))
        return false
    }

    // ensure kicked player is in file.kickTable
    if (targetUid in file.kickTable) {
        KickInfo kickInfo = file.kickTable[targetUid]
        foreach (entity voter in kickInfo.voters) {
            if (voter.GetUID() == player.GetUID()) {
                SendMessage(player, Red("you have already voted to kick " + targetName))
                return false
            }
        }
        kickInfo.voters.append(player)
    } else {
        KickInfo kickInfo
        kickInfo.voters = []
        kickInfo.voters.append(player)
        kickInfo.threshold = int(GetPlayerArray().len() * file.kickPercentage)
        file.kickTable[targetUid] <- kickInfo
    }

    // kick if votes exceed threshold
    KickInfo kickInfo = file.kickTable[targetUid]
    if (kickInfo.voters.len() >= kickInfo.threshold) {
        KickPlayer(target)
    } else {
        int remainingVotes = kickInfo.threshold - kickInfo.voters.len()
        thread AsyncAnnounceMessage(Blue(player.GetPlayerName() + " voted to kick " + targetName + ", " + remainingVotes + " more vote(s) required"))
    }

    return true
}

void function KickPlayer(entity player) {
    string playerUid = player.GetUID()
    if (playerUid in file.kickTable) {
        delete file.kickTable[playerUid]
    }
    file.kickedPlayers.append(playerUid)
    ServerCommand("kick " + player.GetPlayerName())
    thread AsyncAnnounceMessage(Blue(player.GetPlayerName() + " has been kicked"))
}

//------------------------------------------------------------------------------
// auth
//------------------------------------------------------------------------------
bool function CommandAuth(entity player, array<string> args) {
    if (IsAuthenticatedAdmin(player)) {
        SendMessage(player, Blue("you are already authenticated"))
        return false
    }

    string password = args[0]
    if (password != file.adminPassword) {
        SendMessage(player, Red("wrong password"))
        return false
    }

    file.authenticatedAdmins.append(player.GetUID())
    SendMessage(player, Blue("hello, admin!"))

    return true
}

//------------------------------------------------------------------------------
// maps
//------------------------------------------------------------------------------
table<string, string> mapNameTable = {
    mp_angel_city = "Angel City",
    mp_black_water_canal = "Black Water Canal",
    mp_coliseum = "Coliseum",
    mp_coliseum_column = "Pillars",
    mp_colony02 = "Colony",
    mp_complex3 = "Complex",
    mp_crashsite3 = "Crashsite",
    mp_drydock = "Drydock",
    mp_eden = "Eden",
    mp_forwardbase_kodai = "Forwardbase Kodai",
    mp_glitch = "Glitch",
    mp_grave = "Boomtown",
    mp_homestead = "Homestead",
    mp_lf_deck = "Deck",
    mp_lf_meadow = "Meadow",
    mp_lf_stacks = "Stacks",
    mp_lf_township = "Township",
    mp_lf_traffic = "Traffic",
    mp_lf_uma = "UMA",
    mp_relic02 = "Relic",
    mp_rise = "Rise",
    mp_thaw = "Exoplanet",
    mp_wargames = "Wargames"
}

bool function IsValidMap(string map) {
    return map in mapNameTable
}

bool function CommandMaps(entity player, array<string> args) {
    string msg = ""
    for (int i = 0; i < file.maps.len(); i++) {
        string map = file.maps[i]
        string mapName = mapNameTable[map]
        msg += mapName.tolower()
        if (i < file.maps.len() - 1) {
            msg += ", "
        }
    }

    thread AsyncSendMessage(player, Blue(msg))
    return true
}

void function PostmatchNextMap() {
    thread SetNextMap()
}

void function SetNextMap() {
    wait GAME_POSTMATCH_LENGTH - 1

    string currentMap = GetMapName()
    string nextMap
    if (currentMap == file.maps[file.maps.len() - 1]) {
        nextMap = file.maps[0]
    } else {
        nextMap = file.maps[file.maps.find(currentMap) + 1]
    }

    GameRules_ChangeMap(nextMap, GameRules_GetGameMode())
}

//------------------------------------------------------------------------------
// utils
//------------------------------------------------------------------------------
string function Red(string s) {
    return "\x1b[1;31m" + s
}

string function Blue(string s) {
    return "\x1b[1;36m" + s
}

void function SendMessage(entity player, string text) {
    Chat_ServerPrivateMessage(player, text, false)
}

void function AsyncSendMessage(entity player, string text) {
    wait 0.1
    Chat_ServerPrivateMessage(player, text, false)
}

void function AnnounceMessage(string text) {
    Chat_ServerBroadcast(text)
}

void function AsyncAnnounceMessage(string text) {
    wait 0.1
    Chat_ServerBroadcast(text)
}

array<entity> function FindPlayersBySubstring(string substring) {
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

bool function IsAdmin(entity player) {
    return file.adminUids.contains(player.GetUID())
}

bool function IsAuthenticatedAdmin(entity player) {
    return IsAdmin(player) && file.authenticatedAdmins.contains(player.GetUID())
}
