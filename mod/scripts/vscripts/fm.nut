//------------------------------------------------------------------------------
// disclaimer: shamelessly stolen code from takyon
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

struct PlayerScore {
    entity player
    float score
}

//------------------------------------------------------------------------------
// globals
//------------------------------------------------------------------------------
struct {
    bool debugEnabled

    array<string> adminUids
    bool adminAuthEnabled
    string adminPassword
    array<string> authenticatedAdmins

    array<CommandInfo> commands

    bool welcomeEnabled
    string welcome
    array<string> welcomedPlayers

    bool rulesEnabled
    string rulesOk
    string rulesNotOk

    bool kickEnabled
    bool kickSave
    float kickPercentage
    int kickMinPlayers
    table<string, KickInfo> kickTable
    array<string> kickedPlayers
    
    bool mapsEnabled
    array<string> maps
    bool nextMapEnabled
    table<entity, string> nextMapVoteTable

    bool balanceEnabled
    float balancePercentage
    int balanceThreshold
    array<string> balanceVotedPlayers

    bool customCommandsEnabled
    table<string, string> customCommands
} file

//------------------------------------------------------------------------------
// init
//------------------------------------------------------------------------------
void function fm_Init() {
    #if SERVER

    file.debugEnabled = GetConVarBool("fm_debug_enabled")

    // admins
    array<string> adminUids = split(GetConVarString("fm_admin_uids"), ",")
    foreach (string uid in adminUids) {
        file.adminUids.append(strip(uid))
    }
    file.adminAuthEnabled = GetConVarBool("fm_admin_auth_enabled")
    file.adminPassword = GetConVarString("fm_admin_password")
    file.authenticatedAdmins = []

    // welcome
    file.welcomeEnabled = GetConVarBool("fm_welcome_enabled")
    file.welcome = GetConVarString("fm_welcome")
    file.welcomedPlayers = []

    // rules
    file.rulesEnabled = GetConVarBool("fm_rules_enabled")
    file.rulesOk = GetConVarString("fm_rules_ok")
    file.rulesNotOk = GetConVarString("fm_rules_not_ok")

    // kick
    file.kickEnabled = GetConVarBool("fm_kick_enabled")
    file.kickSave = GetConVarBool("fm_kick_save")
    file.kickPercentage = GetConVarFloat("fm_kick_percentage")
    file.kickMinPlayers = GetConVarInt("fm_kick_min_players")
    file.kickTable = {}
    file.kickedPlayers = []

    // maps
    file.mapsEnabled = GetConVarBool("fm_maps_enabled")

    file.maps = []
    array<string> maps = split(GetConVarString("fm_maps"), ",")
    foreach (string dirtyMap in maps) {
        string map = strip(dirtyMap)
        if (!IsValidMap(map)) {
            Log("ignoring invalid map '" + map + "'")
            continue
        }

        file.maps.append(map)
    }
    file.nextMapEnabled = GetConVarBool("fm_nextmap_enabled")
    file.nextMapVoteTable = {}

    // balance
    file.balanceEnabled = GetConVarBool("fm_balance_enabled")
    file.balancePercentage = GetConVarFloat("fm_balance_percentage")
    file.balanceThreshold = 0
    file.balanceVotedPlayers = []

    // commands
    CommandInfo cmdAuth    = NewCommandInfo("!auth",    CommandAuth,    1, true,  true,  "!auth <password> => authenticate yourself as an admin")
    CommandInfo cmdHelp    = NewCommandInfo("!help",    CommandHelp,    0, false, false, "!help => get help")
    CommandInfo cmdRules   = NewCommandInfo("!rules",   CommandRules,   0, false, false, "!rules => show rules")
    CommandInfo cmdKick    = NewCommandInfo("!kick",    CommandKick,    1, false, false, "!kick <full or partial player name> => vote to kick a player")
    CommandInfo cmdMaps    = NewCommandInfo("!maps",    CommandMaps,    0, false, false, "!maps => list available maps")
    CommandInfo cmdNextMap = NewCommandInfo("!nextmap", CommandNextMap, 1, false, false, "!nextmap <full or partial map name> => vote for next map")
    CommandInfo cmdBalance = NewCommandInfo("!balance", CommandBalance, 0, false, false, "!balance => vote for team balance")

    if (file.welcomeEnabled) {
        AddCallback_OnPlayerRespawned(Welcome_OnPlayerRespawned)
        AddCallback_OnClientDisconnected(Welcome_OnClientDisconnected)
    }

    if (file.adminAuthEnabled) {
        file.commands.append(cmdAuth)
    }

    file.commands.append(cmdHelp)

    if (file.rulesEnabled) {
        file.commands.append(cmdRules)
    }

    if (file.kickEnabled) {
        file.commands.append(cmdKick)
        AddCallback_OnPlayerRespawned(Kick_OnPlayerRespawned)
        AddCallback_OnClientDisconnected(Kick_OnClientDisconnected)
    }

    if (file.mapsEnabled && file.maps.len() > 1) {
        file.commands.append(cmdMaps)
        AddCallback_GameStateEnter(eGameState.Postmatch, PostmatchChangeMap)
        if (file.nextMapEnabled) {
            file.commands.append(cmdNextMap)
            AddCallback_OnClientDisconnected(NextMap_OnClientDisconnected)
        }
    }

    if (file.balanceEnabled && !IsFFAGame()) {
        file.commands.append(cmdBalance)
    }

    // custom commands
    file.customCommandsEnabled = GetConVarBool("fm_custom_commands_enabled")
    file.customCommands = {}
    if (file.customCommandsEnabled) {
        string customCommands = GetConVarString("fm_custom_commands")
        array<string> entries = split(customCommands, ";")
        foreach (string entry in entries) {
            array<string> pair = split(entry, "=")
            if (pair.len() != 2) {
                Log("ignoring invalid custom command: " + entry)
                continue
            }

            string command = pair[0]
            string text = pair[1]
            file.customCommands[command] <- text
        }
    }


    // the beef
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
        // prevent mewn from leaking the admin password
        if (file.adminAuthEnabled && IsAdmin(player) && message.tolower().find(file.adminPassword.tolower()) != null) {
            SendMessage(player, Red("learn to type, mewn"))
            messageInfo.shouldBlock = true
        }
        return messageInfo
    }

    array<string> args = split(message, " ")
    string command = args[0].tolower()
    args.remove(0)

    if (command in file.customCommands) {
        string text = file.customCommands[command]
        SendMessage(player, Blue(text))
        return messageInfo
    }

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
void function Welcome_OnPlayerRespawned(entity player) {
    string uid = player.GetUID()
    if (file.welcomedPlayers.contains(uid)) {
        return
    }

    SendMessage(player, Blue(file.welcome))
    file.welcomedPlayers.append(uid)
}

void function Welcome_OnClientDisconnected(entity player) {
    string uid = player.GetUID()
    if (file.welcomedPlayers.contains(uid)) {
        file.welcomedPlayers.remove(file.welcomedPlayers.find(uid))
    }
}

//------------------------------------------------------------------------------
// help
//------------------------------------------------------------------------------
bool function CommandHelp(entity player, array<string> args) {
    array<string> commandNames = []
    foreach (CommandInfo c in file.commands) {
        if (c.isAdmin && !IsAdmin(player)) {
            continue
        }
        commandNames.append(c.name)
    }

    foreach (string customCommand, string text in file.customCommands) {
        commandNames.append(customCommand)
    }

    string help = "available commands: " + Join(commandNames, ", ")
    thread AsyncSendMessage(player, Blue(help))

    return true
}

//------------------------------------------------------------------------------
// rules
//------------------------------------------------------------------------------
bool function CommandRules(entity player, array<string> args) {
    thread AsyncSendMessage(player, Green("ok = ") + Blue(file.rulesOk))
    thread AsyncSendMessage(player, Red("not ok = ") + Blue(file.rulesNotOk))
    return true
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

    if (player == target) {
        SendMessage(player, Red("you cannot kick yourself"))
        return false
    }

    if (IsAdmin(target)) {
        SendMessage(player, Red("you cannot kick an admin"))
        return false
    }

    if (IsAuthenticatedAdmin(player)) {
        KickPlayer(target)
        return true
    }

    if (GetPlayerArray().len() < file.kickMinPlayers) {
        // TODO: store into kicktable anyway?
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
        thread AsyncAnnounceMessage(Purple(player.GetPlayerName() + " wants to kick " + targetName + ", " + remainingVotes + " more vote(s) required"))
    }

    return true
}

void function KickPlayer(entity player, bool announce = true) {
    string playerUid = player.GetUID()
    if (playerUid in file.kickTable) {
        delete file.kickTable[playerUid]
    }

    if (file.kickSave && !file.kickedPlayers.contains(playerUid)) {
        file.kickedPlayers.append(playerUid)
    }

    ServerCommand("kick " + player.GetPlayerName())
    if (announce) {
        thread AsyncAnnounceMessage(Purple(player.GetPlayerName() + " has been kicked"))
    }
}

void function Kick_OnPlayerRespawned(entity player) {
    if (file.kickedPlayers.contains(player.GetUID())) {
        Debug("[Kick_OnPlayerRespawned] previously kicked " + player.GetPlayerName() + " tried to rejoin")
        KickPlayer(player, false)
    }
}

void function Kick_OnClientDisconnected(entity player) {
    foreach (string targetUid, KickInfo kickInfo in file.kickTable) {
        array<entity> voters = kickInfo.voters
        for (int i = 0; i < voters.len(); i++) {
            if (voters[i] != player) {
                continue
            }

            voters.remove(i)
            Debug("[Kick_OnClientDisconnected] kick vote from " + player.GetPlayerName() + " removed")
        }

        if (voters.len() == 0) {
            delete file.kickTable[targetUid]
        } else {
            kickInfo.voters = voters
            file.kickTable[targetUid] = kickInfo
        }
    }
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

string function MapName(string map) {
    return mapNameTable[map].tolower()
}

bool function IsValidMap(string map) {
    return map in mapNameTable
}

string function MapsString() {
    array<string> mapNames = []
    foreach (string map in file.maps) {
        mapNames.append(MapName(map))
    }

    return Join(mapNames, ", ")
}

bool function CommandMaps(entity player, array<string> args) {
    thread AsyncSendMessage(player, Blue(MapsString()))

    return true
}

bool function CommandNextMap(entity player, array<string> args) {
    string mapName = args[0]
    array<string> foundMaps = FindMapsBySubstring(mapName)

    if (foundMaps.len() == 0) {
        SendMessage(player, Red("map '" + mapName + "' not found"))
        return false
    }

    if (foundMaps.len() > 1) {
        SendMessage(player, Red("multiple matches for map '" + mapName + "', be more specific"))
        return false
    }

    string nextMap = foundMaps[0]
    if (!file.maps.contains(nextMap)) {
        SendMessage(player, Red(MapName(nextMap) + " is not in the map pool, available maps: " + MapsString()))
        return false
    }

    file.nextMapVoteTable[player] <- nextMap
    thread AsyncAnnounceMessage(Purple(player.GetPlayerName() + " wants to play on " + MapName(nextMap)))
    return true;
}

void function PostmatchChangeMap() {
    thread DoChangeMap()
}

void function DoChangeMap() {
    wait GAME_POSTMATCH_LENGTH - 1

    string nextMap = GetUsualNextMap()
    if (file.nextMapEnabled) {
        string drawnNextMap = DrawNextMapFromVoteTable()
        if (drawnNextMap != "") {
            nextMap = drawnNextMap
        }
    }

    GameRules_ChangeMap(nextMap, GameRules_GetGameMode())
}

string function GetUsualNextMap() {
    string currentMap = GetMapName()
    bool isLastMap = currentMap == file.maps[file.maps.len() - 1]
    bool isUnknownMap = !file.maps.contains(currentMap)
    if (isLastMap || isUnknownMap) {
        return file.maps[0]
    }

    string nextMap = file.maps[file.maps.find(currentMap) + 1]

    return nextMap
}

string function DrawNextMapFromVoteTable() {
    array<string> maps = []
    foreach (entity player, string map in file.nextMapVoteTable) {
        maps.append(map)
    }

    if (maps.len() == 0) {
        return ""
    }

    return maps[RandomInt(maps.len())]
}

void function NextMap_OnClientDisconnected(entity player) {
    if (player in file.nextMapVoteTable) {
        delete file.nextMapVoteTable[player]
        Debug("[NextMap_OnClientDisconnected] " + player.GetPlayerName() + "removed from next map vote table")
    }
}

//------------------------------------------------------------------------------
// balance
//------------------------------------------------------------------------------
bool function CommandBalance(entity player, array<string> args) {
    string playerUid = player.GetUID()

    if (IsAuthenticatedAdmin(player)) {
        DoBalance()
        return true
    }

    if (file.balanceVotedPlayers.contains(playerUid)) {
        SendMessage(player, Red("you have already voted for balance"))
        return false
    }

    if (file.balanceVotedPlayers.len() == 0) {
        file.balanceThreshold = int(GetPlayerArray().len() * file.balancePercentage)
    }

    file.balanceVotedPlayers.append(playerUid)
    if (file.balanceVotedPlayers.len() >= file.balanceThreshold) {
        DoBalance()
    } else {
        int remainingVotes = file.balanceThreshold - file.balanceVotedPlayers.len()
        thread AsyncAnnounceMessage(Purple(player.GetPlayerName() + " wants team balance, " + remainingVotes + " more vote(s) required"))
    }

    return true
}

void function DoBalance() {
    array<PlayerScore> scores
    foreach (entity player in GetPlayerArray()) {
        PlayerScore score
        score.player = player
        int kills = player.GetPlayerGameStat(PGS_KILLS)
        int deaths = player.GetPlayerGameStat(PGS_DEATHS)
        if (deaths == 0) {
            deaths = 1
        }

        score.score = float(kills) / float(deaths)
        scores.append(score)
    }

    scores.sort(PlayerScoreSort)
    
    for (int i = 0; i < GetPlayerArray().len(); i++) {
        if (IsEven(i)) {
            SetTeam(scores[i].player, TEAM_IMC)
        } else {
            SetTeam(scores[i].player, TEAM_MILITIA)
        }
    }

    file.balanceVotedPlayers = []

    thread AsyncAnnounceMessage(Purple("teams have been balanced by k/d"))
}

int function PlayerScoreSort(PlayerScore a, PlayerScore b) {
    if (a.score == b.score) {
        return 0
    }

    return a.score < b.score ? -1 : 1
}

//------------------------------------------------------------------------------
// utils
//------------------------------------------------------------------------------
void function Log(string s) {
     print("[fvnkhead.mod] " + s)
}

void function Debug(string s) {
    if (!file.debugEnabled) {
        return
    }

    print("[fvnkhead.mod/debug] " + s)
}

string function Red(string s) {
    return "\x1b[1;31m" + s
}

string function Green(string s) {
    return "\x1b[1;32m" + s
}

string function Purple(string s) {
    return "\x1b[1;35m" + s
}

string function Blue(string s) {
    return "\x1b[1;36m" + s
}

string function Join(array<string> list, string separator) {
    string s = ""
    for (int i = 0; i < list.len(); i++) {
        s += list[i]
        if (i < list.len() - 1) {
            s += separator
        }
    }

    return s
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

array<string> function FindMapsBySubstring(string substring) {
    substring = substring.tolower()
    array<string> maps = []
    foreach (string mapKey, string mapName in mapNameTable) {
        if (mapName.tolower().find(substring) != null) {
            maps.append(mapKey)
        }
    }

    return maps
}

bool function IsAdmin(entity player) {
    return file.adminUids.contains(player.GetUID())
}

bool function IsAuthenticatedAdmin(entity player) {
    if (file.adminAuthEnabled) {
        return IsAdmin(player) && file.authenticatedAdmins.contains(player.GetUID())
    }

    return IsAdmin(player)
}
