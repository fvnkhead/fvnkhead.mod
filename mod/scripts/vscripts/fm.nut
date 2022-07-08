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
    int minArgs,
    int maxArgs
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
    float val
}

struct NextMapScore {
    string map
    int votes
}

struct CustomCommand {
    string name
    string text
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
    int balanceMinPlayers
    int balanceThreshold
    array<entity> balanceVoters
    bool balancePostmatch

    bool extendEnabled
    float extendPercentage
    int extendMinutes
    int extendThreshold
    array<entity> extendVoters

    bool skipEnabled
    float skipPercentage
    int skipThreshold
    array<entity> skipVoters

    bool yellEnabled

    bool slayEnabled

    bool freezeEnabled

    bool rollEnabled

    bool customCommandsEnabled
    array<CustomCommand> customCommands
} file

//------------------------------------------------------------------------------
// init
//------------------------------------------------------------------------------
void function fm_Init() {
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
    file.balanceMinPlayers = GetConVarInt("fm_balance_min_players")
    file.balanceThreshold = 0
    file.balanceVoters = []
    file.balancePostmatch = GetConVarBool("fm_balance_postmatch")

    // extend
    file.extendEnabled = GetConVarBool("fm_extend_enabled")
    file.extendPercentage = GetConVarFloat("fm_extend_percentage")
    file.extendMinutes = GetConVarInt("fm_extend_minutes")
    file.extendThreshold = 0
    file.extendVoters = []

    // skip
    file.skipEnabled = GetConVarBool("fm_skip_enabled")
    file.skipPercentage = GetConVarFloat("fm_skip_percentage")
    file.skipVoters = []

    // yell
    file.yellEnabled = GetConVarBool("fm_yell_enabled")

    // slay
    file.slayEnabled = GetConVarBool("fm_slay_enabled")

    // freeze
    file.freezeEnabled = GetConVarBool("fm_freeze_enabled")

    // roll
    file.rollEnabled = GetConVarBool("fm_roll_enabled")

    // add commands and callbacks
    CommandInfo cmdHelp    = NewCommandInfo("!help",    CommandHelp,    0, 0,  false, false, "!help => get help")
    CommandInfo cmdRules   = NewCommandInfo("!rules",   CommandRules,   0, 0,  false, false, "!rules => show rules")
    CommandInfo cmdKick    = NewCommandInfo("!kick",    CommandKick,    1, 1,  false, false, "!kick <full or partial player name> => vote to kick a player")
    CommandInfo cmdMaps    = NewCommandInfo("!maps",    CommandMaps,    0, 0,  false, false, "!maps => list available maps")
    CommandInfo cmdNextMap = NewCommandInfo("!nextmap", CommandNextMap, 1, 3,  false, false, "!nextmap <full or partial map name> => vote for next map")
    CommandInfo cmdBalance = NewCommandInfo("!balance", CommandBalance, 0, 0,  false, false, "!balance => vote for team balance")
    CommandInfo cmdExtend  = NewCommandInfo("!extend",  CommandExtend,  0, 0,  false, false, "!extend => vote to extend map time")
    CommandInfo cmdSkip    = NewCommandInfo("!skip",    CommandSkip,    0, 0,  false, false, "!skip => vote to skip current map")
    CommandInfo cmdRoll    = NewCommandInfo("!roll",    CommandRoll,    0, 0,  false, false, "!roll => roll a number between 0 and 100")
    // admin commands
    CommandInfo cmdAuth    = NewCommandInfo("!auth",    CommandAuth,    1, 1,  true,  true,  "!auth <password> => authenticate yourself as an admin")
    CommandInfo cmdYell    = NewCommandInfo("!yell",    CommandYell,    1, -1, true,  true,  "!yell ... => yell something")
    CommandInfo cmdSlay    = NewCommandInfo("!slay",    CommandSlay,    1, 1,  false, true,  "!slay <full or partial player name> => kill a player")
    CommandInfo cmdFreeze  = NewCommandInfo("!freeze",  CommandFreeze,  1, 1,  false, true,  "!freeze <full or partial player name> => freeze a player")

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

    if (file.maps.len() > 0) {
        AddCallback_GameStateEnter(eGameState.Postmatch, PostmatchChangeMap)
    }
    if (file.mapsEnabled && file.maps.len() > 1) {
        file.commands.append(cmdMaps)
        if (file.nextMapEnabled) {
            file.commands.append(cmdNextMap)
            AddCallback_GameStateEnter(eGameState.WinnerDetermined, NextMap_OnWinnerDetermined)
            AddCallback_OnClientDisconnected(NextMap_OnClientDisconnected)
        }
    }

    if (file.balanceEnabled && !IsFFAGame()) {
        file.commands.append(cmdBalance)
        AddCallback_OnClientDisconnected(Balance_OnClientDisconnected)
    }

    if (file.balancePostmatch && !IsFFAGame()) {
        AddCallback_GameStateEnter(eGameState.Postmatch, Balance_Postmatch)
    }

    if (file.extendEnabled) {
        file.commands.append(cmdExtend)
        AddCallback_OnClientDisconnected(Extend_OnClientDisconnected)
    }

    if (file.skipEnabled && file.maps.len() > 1) {
        file.commands.append(cmdSkip)
        AddCallback_OnClientDisconnected(Skip_OnClientDisconnected)
    }

    if (file.yellEnabled) {
        file.commands.append(cmdYell)
    }

    if (file.slayEnabled) {
        file.commands.append(cmdSlay)
    }

    if (file.freezeEnabled) {
        file.commands.append(cmdFreeze)
    }

    if (file.rollEnabled) {
        file.commands.append(cmdRoll)
    }

    // custom commands
    file.customCommandsEnabled = GetConVarBool("fm_custom_commands_enabled")
    file.customCommands = []
    if (file.customCommandsEnabled) {
        string customCommands = GetConVarString("fm_custom_commands")
        array<string> entries = split(customCommands, "|")
        foreach (string entry in entries) {
            array<string> pair = split(entry, "=")
            if (pair.len() != 2) {
                Log("ignoring invalid custom command: " + entry)
                continue
            }

            CustomCommand command
            command.name = pair[0]
            command.text = pair[1]
            file.customCommands.append(command)
        }
    }


    // the beef
    AddCallback_OnReceivedSayTextMessage(ChatCallback)
}

//------------------------------------------------------------------------------
// command handling
//------------------------------------------------------------------------------
CommandInfo function NewCommandInfo(string name, bool functionref(entity, array<string>) fn, int minArgs, int maxArgs, bool isSilent, bool isAdmin, string usage) {
    CommandInfo commandInfo
    commandInfo.name = name
    commandInfo.fn = fn
    commandInfo.minArgs = minArgs
    commandInfo.maxArgs = maxArgs
    commandInfo.isSilent = isSilent
    commandInfo.isAdmin = isAdmin
    commandInfo.usage = usage
    return commandInfo
}

ClServer_MessageStruct function ChatCallback(ClServer_MessageStruct messageInfo) {
    // might be buggy
    //if (IsLobby()) {
    //    return messageInfo
    //}

    entity player = messageInfo.player
    string message = strip(messageInfo.message)
    Debug("[ChatCallback] ----- BEGIN -----")
    Debug("[ChatCallback] player: " + player.GetPlayerName())
    Debug("[ChatCallback] message: " + message)
    bool isCommand = format("%c", message[0]) == "!"
    if (!isCommand) {
        // prevent mewn from leaking the admin password
        if (file.adminAuthEnabled && IsAdmin(player) && message.tolower().find(file.adminPassword.tolower()) != null) {
            SendMessage(player, Red("learn to type, mewn"))
            messageInfo.shouldBlock = true
            Debug("[ChatCallback] mewn moment")
        }
        Debug("[ChatCallback] not a command")
        Debug("[ChatCallback] ----- END -----")
        return messageInfo
    }

    array<string> args = split(message, " ")
    string command = args[0].tolower()
    args.remove(0)

    foreach (CustomCommand c in file.customCommands) {
        if (c.name == command) {
            SendMessage(player, Blue(c.text))
            Debug("[ChatCallback] custom command")
            Debug("[ChatCallback] ----- END -----")
            return messageInfo
        }
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

        if (c.isAdmin && IsAdmin(player) && !IsAuthenticatedAdmin(player) && c.name != "!auth") {
            SendMessage(player, Red("authenticate first"))
            commandSuccess = false
            break
        }

        if (args.len() < c.minArgs || (c.maxArgs != -1 && args.len() > c.maxArgs)) {
            SendMessage(player, Red("usage: " + c.usage))
            commandSuccess = false
            break
        }

        commandSuccess = c.fn(player, args)
    }

    if (!commandFound) {
        SendMessage(player, Red("unknown command: " + command))
        messageInfo.shouldBlock = true
        Debug("[ChatCallback] command not found")
    } else if (!commandSuccess) {
        Debug("[ChatCallback] command failure")
        messageInfo.shouldBlock = true
    }

    Debug("[ChatCallback] ----- END -----")
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
    array<string> userCommands = []
    array<string> adminCommands = []
    foreach (CommandInfo c in file.commands) {
        if (c.isAdmin) {
            adminCommands.append(c.name)
        } else {
            userCommands.append(c.name)
        }
    }

    foreach (CustomCommand c in file.customCommands) {
        userCommands.append(c.name)
    }

    string userHelp = "available commands: " + Join(userCommands, ", ")
    SendMessage(player, Blue(userHelp))

    if (!IsAdmin(player)) {
        return true
    }

    string adminHelp = "admin commands: " + Join(adminCommands, ", ")
    SendMessage(player, Blue(adminHelp))

    return true
}

//------------------------------------------------------------------------------
// rules
//------------------------------------------------------------------------------
bool function CommandRules(entity player, array<string> args) {
    SendMessage(player, Blue("ok = " + file.rulesOk))
    SendMessage(player, Red("not ok = " + file.rulesNotOk))
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
        SendMessage(player, Red("not enough players for kick vote, at least " + file.kickMinPlayers + " required"))
        return false
    }

    // ensure kicked player is in file.kickTable
    if (targetUid in file.kickTable) {
        KickInfo kickInfo = file.kickTable[targetUid]
        if (!kickInfo.voters.contains(player)){
            kickInfo.voters.append(player)
        }
    } else {
        KickInfo kickInfo
        kickInfo.voters = []
        kickInfo.voters.append(player)
        kickInfo.threshold = Threshold(GetPlayerArray().len(), file.kickPercentage)
        file.kickTable[targetUid] <- kickInfo
    }

    // kick if votes exceed threshold
    KickInfo kickInfo = file.kickTable[targetUid]
    if (kickInfo.voters.len() >= kickInfo.threshold) {
        KickPlayer(target)
    } else {
        int remainingVotes = kickInfo.threshold - kickInfo.voters.len()
        AnnounceMessage(Purple(player.GetPlayerName() + " wants to kick " + targetName + ", " + remainingVotes + " more vote(s) required"))
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
        AnnounceMessage(Purple(player.GetPlayerName() + " has been kicked"))
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
        if (voters.contains(player)) {
            voters.remove(voters.find(player))
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
    SendMessage(player, Blue(MapsString()))

    return true
}

bool function CommandNextMap(entity player, array<string> args) {
    string mapName = Join(args, " ")
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
    AnnounceMessage(Purple(player.GetPlayerName() + " wants to play on " + MapName(nextMap)))
    return true;
}

void function PostmatchChangeMap() {
    thread DoChangeMap(GAME_POSTMATCH_LENGTH - 1)
}

void function DoChangeMap(float waitTime) {
    wait waitTime

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

    Debug("[DrawNextMapFromVoteTable] maps = [" + Join(maps, ", ") + "]")

    if (maps.len() == 0) {
        return ""
    }

    string nextMap = maps[RandomInt(maps.len())]
    Debug("[DrawNextMapFromVoteTable] nextMap = " + nextMap)
    return nextMap
}

string function NextMapCandidatesString() {
    array<NextMapScore> scores = NextMapCandidates()
    int totalVotes = file.nextMapVoteTable.len()
    string msg = ""
    for (int i = 0; i < scores.len(); i++) {
        NextMapScore score = scores[i]
        msg += MapName(score.map) + " (" + score.votes + "/" + totalVotes + ")"
        if (i < scores.len() - 1) {
            msg += ", "
        }
    }

    return msg
}

array<NextMapScore> function NextMapCandidates() {
    table<string, int> mapVotes = {}
    foreach (entity player, string map in file.nextMapVoteTable) {
        Debug("[NextMapCandidates] player = " + player.GetPlayerName() + ", map = " + map)
        if (map in mapVotes) {
            int currentVotes = mapVotes[map]
            mapVotes[map] <- currentVotes + 1
            Debug("[NextMapCandidates] map " + map + " incremented")
        } else {
            mapVotes[map] <- 1
            Debug("[NextMapCandidates] map " + map + " initialized")
        }
    }

    array<NextMapScore> scores = []
    foreach (string map, int votes in mapVotes) {
        NextMapScore score
        score.map = map
        score.votes = votes
        scores.append(score)
        Debug("[NextMapCandidates] map = " + score.map + ", votes = " + score.votes)
    }

    scores.sort(NextMapScoreSort)
    return scores
}

int function NextMapScoreSort(NextMapScore a, NextMapScore b) {
    if (a.votes == b.votes) {
        return 0
    }
    return a.votes < b.votes ? 1 : -1
}

void function NextMap_OnWinnerDetermined() {
    if (file.nextMapVoteTable.len() > 0) {
        AnnounceMessage(Purple("next map candidates: " + NextMapCandidatesString()))
    }
}

void function NextMap_OnClientDisconnected(entity player) {
    if (player in file.nextMapVoteTable) {
        delete file.nextMapVoteTable[player]
        Debug("[NextMap_OnClientDisconnected] " + player.GetPlayerName() + " removed from next map vote table")
    }
}

//------------------------------------------------------------------------------
// balance
//------------------------------------------------------------------------------
bool function CommandBalance(entity player, array<string> args) {
    Debug("[CommandBalance] balance by " + player.GetPlayerName() + ", balance voters: " + file.balanceVoters.len() + ", threshold: " + file.balanceThreshold + ", percentage: " + file.balancePercentage)
    if (IsAuthenticatedAdmin(player)) {
        Debug("[CommandBalance] admin balance by " + player.GetPlayerName())
        DoBalance()
        return true
    }

    if (GetPlayerArray().len() < file.balanceMinPlayers) {
        SendMessage(player, Red("not enough players for balance, at least " + file.balanceMinPlayers + " required"))
        return false
    }

    if (file.balanceVoters.len() == 0) {
        file.balanceThreshold = Threshold(GetPlayerArray().len(), file.balancePercentage)
        Debug("[CommandBalance] setting balance threshold to " + file.balanceThreshold)
    }

    if (!file.balanceVoters.contains(player)) {
        file.balanceVoters.append(player)
    }

    if (file.balanceVoters.len() >= file.balanceThreshold) {
        Debug("[CommandBalance] balance voters: " + file.balanceVoters.len())
        DoBalance()
    } else {
        int remainingVotes = file.balanceThreshold - file.balanceVoters.len()
        Debug("[CommandBalance] remaining balance votes: " + remainingVotes)
        AnnounceMessage(Purple(player.GetPlayerName() + " wants team balance, " + remainingVotes + " more vote(s) required"))
    }

    return true
}

void function DoBalance() {
    Debug("[DoBalance] balancing teams")
    array<entity> players = GetPlayerArray()

    array<entity> switchablePlayers = []
    foreach (entity player in players) {
        if (CanSwitchTeams(player)) {
            switchablePlayers.append(player)
        }
    }

    array<PlayerScore> scores = GetPlayerScores(switchablePlayers)
    for (int i = 0; i < scores.len(); i++) {
        if (IsEven(i)) {
            SetTeam(scores[i].player, TEAM_IMC)
        } else {
            SetTeam(scores[i].player, TEAM_MILITIA)
        }
    }

    AnnounceMessage(Purple("teams have been balanced"))

    file.balanceVoters.clear()
}

bool function CanSwitchTeams(entity player) {
    // ctf bug, flag can become other team flag so they have 2 flags
    if (HasFlag(player)) {
        Debug("[CanSwitchTeams] " + player.GetPlayerName() + " has a flag, can't switch")
        return false
    }

    return true
}

array<PlayerScore> function GetPlayerScores(array<entity> players) {
    array<PlayerScore> scores
    foreach (entity player in players) {
        PlayerScore score
        score.player = player
        score.val = CalculatePlayerScore(player)
        scores.append(score)
    }

    scores.sort(PlayerScoreSort)

    return scores
}

float function CalculatePlayerScore(entity player) {
    if (GameRules_GetGameMode() == CAPTURE_THE_FLAG) {
        return CalculateCTFScore(player)
    }

    return CalculateKDScore(player)
}

float function CalculateCTFScore(entity player) {
    int captureWeight = 10
    int returnWeight = 5

    int captures = player.GetPlayerGameStat(PGS_ASSAULT_SCORE)
    int returns = player.GetPlayerGameStat(PGS_DEFENSE_SCORE)
    int kills = player.GetPlayerGameStat(PGS_KILLS)
    float score = float((captures * captureWeight) + (returns + returnWeight) + kills)
    Debug("[CalculateCTFScore] " + player.GetPlayerName() + " = " + score)
    return score
}

float function CalculateKDScore(entity player) {
    int kills = player.GetPlayerGameStat(PGS_KILLS)
    int deaths = player.GetPlayerGameStat(PGS_DEATHS)
    if (deaths == 0) {
        deaths = 1
    }

    return float(kills) / float(deaths)
}

int function PlayerScoreSort(PlayerScore a, PlayerScore b) {
    if (a.val == b.val) {
        return 0
    }

    return a.val < b.val ? 1 : -1
}

void function Balance_Postmatch() {
    DoBalance()
}

void function Balance_OnClientDisconnected(entity player) {
    if (file.balanceVoters.contains(player)) {
        file.balanceVoters.remove(file.balanceVoters.find(player))
        Debug("[Balance_OnClientDisconnected] " + player.GetPlayerName() + " removed from balance voters")
    }
}

//------------------------------------------------------------------------------
// extend
//------------------------------------------------------------------------------
bool function CommandExtend(entity player, array<string> args) {
    if (IsAuthenticatedAdmin(player)) {
        DoExtend()
        return true
    }

    if (file.extendVoters.len() == 0) {
        file.extendThreshold = Threshold(GetPlayerArray().len(), file.extendPercentage)
    }

    if (!file.extendVoters.contains(player)) {
        file.extendVoters.append(player)
    }

    if (file.extendVoters.len() >= file.extendThreshold) {
        DoExtend()
    } else {
        int remainingVotes = file.extendThreshold - file.extendVoters.len()
        AnnounceMessage(Purple(player.GetPlayerName() + " wants to extend the map, " + remainingVotes + " more vote(s) required"))
    }

    return true
}

void function DoExtend() {
    float currentEndTime = expect float(GetServerVar("gameEndTime"))
    float newEndTime = currentEndTime + (60 * file.extendMinutes)
    SetServerVar("gameEndTime", newEndTime)

    AnnounceMessage(Purple("map has been extended"))

    file.extendVoters.clear()
}

void function Extend_OnClientDisconnected(entity player) {
    if (file.extendVoters.contains(player)) {
        file.extendVoters.remove(file.extendVoters.find(player))
        Debug("[Extend_OnClientDisconnected] " + player.GetPlayerName() + " removed from extend voters")
    }
}

//------------------------------------------------------------------------------
// skip
//------------------------------------------------------------------------------
bool function CommandSkip(entity player, array<string> args) {
    if (GetGameState() >= eGameState.WinnerDetermined) {
        SendMessage(player, Red("match is over already"))
        return false
    }
    
    if (IsAuthenticatedAdmin(player)) {
        DoSkip()
        return true
    }

    if (file.skipVoters.len() == 0) {
        file.skipThreshold = Threshold(GetPlayerArray().len(), file.skipPercentage)
    }

    if (!file.skipVoters.contains(player)) {
        file.skipVoters.append(player)
    }

    if (file.skipVoters.len() >= file.skipThreshold) {
        DoSkip()
    } else {
        int remainingVotes = file.skipThreshold - file.skipVoters.len()
        AnnounceMessage(Purple(player.GetPlayerName() + " wants to skip the current map, " + remainingVotes + " more vote(s) required"))
    }

    return true
}

void function DoSkip() {
    float waitTime = 5.0
    thread SkipAnnounceLoop(waitTime)
    thread DoChangeMap(waitTime)
    file.skipVoters.clear()
}

void function SkipAnnounceLoop(float waitTime) {
    int seconds = int(waitTime)
    AnnounceMessage(Purple("current map will be skipped in " + seconds + "..."))
    for (int i = seconds - 1; i > 0; i--) {
        wait 1.0
        AnnounceMessage(Purple(i + "..."))
    }
}

void function Skip_OnClientDisconnected(entity player) {
    if (file.skipVoters.contains(player)) {
        file.skipVoters.remove(file.skipVoters.find(player))
        Debug("[Skip_OnClientDisconnected] " + player.GetPlayerName() + " removed from skip voters")
    }
}

//------------------------------------------------------------------------------
// yell
//------------------------------------------------------------------------------
bool function CommandYell(entity player, array<string> args) {
    string msg = Join(args, " ")
    AnnounceHUD(msg, 255, 0, 0)
    return true
}

//------------------------------------------------------------------------------
// slay
//------------------------------------------------------------------------------
bool function CommandSlay(entity player, array<string> args) {
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
    if (!IsAlive(target)) {
        SendMessage(player, Red(target.GetPlayerName() + " is already dead"))
        return false
    }

    target.Die()
    AnnounceMessage(Purple(target.GetPlayerName() + " has been slain"))

    return true
}

//------------------------------------------------------------------------------
// freeze
//------------------------------------------------------------------------------
bool function CommandFreeze(entity player, array<string> args) {
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
    if (!IsAlive(target)) {
        SendMessage(player, Red(target.GetPlayerName() + " is dead"))
        return false
    }

    target.MovementDisable()
    target.ConsumeDoubleJump()
    target.DisableWeaponViewModel()

    AnnounceMessage(Purple(target.GetPlayerName() + " has been frozen"))

    return true
}

//------------------------------------------------------------------------------
// roll
//------------------------------------------------------------------------------
bool function CommandRoll(entity player, array<string> args) {
    int num = RandomInt(101)
    string msg = player.GetPlayerName() + " rolled " + num
    if (num == 0) {
        msg += ", what a noob lol"
    } else if (num == 69) {
        msg += ", nice"
    } else if (num == 100) {
        msg += ", what a " + Red("CHAD")
    } else {
        msg += ", meh"
    }

    AnnounceMessage(Purple(msg))
    return true
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
    return "\x1b[112m" + s
}

string function Blue(string s) {
    return "\x1b[111m" + s
}

string function Purple(string s) {
    return "\x1b[95m" + s
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

int function Threshold(int count, float percentage) {
    return int(ceil(count * percentage))
}

void function SendMessage(entity player, string text) {
    thread AsyncSendMessage(player, text)
    // TODO: testing
    //Chat_ServerPrivateMessage(player, text, false)
}

void function AsyncSendMessage(entity player, string text) {
    wait 0.1

    if (!IsValid(player)) {
        return
    }

    Chat_ServerPrivateMessage(player, text, false)
}

void function AnnounceMessage(string text) {
    AsyncAnnounceMessage(text)
    // TODO: testing
    //Chat_ServerBroadcast(text)
}

void function AsyncAnnounceMessage(string text) {
    foreach (entity player in GetPlayerArray()) {
        SendMessage(player, text)
    }
    // TODO: testing
    //Chat_ServerBroadcast(text)
}

void function SendHUD(entity player, string msg, int r, int g, int b, int time = 10) {
    SendHudMessage(player, msg, -1, 0.2, r, g, b, 255, 0.15, time, 1)
}

void function AnnounceHUD(string msg, int r, int g, int b, int time = 10) {
    foreach (entity player in GetPlayerArray()) {
        SendHUD(player, msg, r, g, b, time)
    }
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

bool function HasFlag(entity player) {
    array<entity> children = GetChildren(player)
    foreach (entity childEnt in children) {
        if (childEnt.GetClassName() == "item_flag") {
            return true
        }
    }
    return false
}

array<entity> function GetChildren(entity parentEnt) {
    entity childEnt = parentEnt.FirstMoveChild()
    array<entity> children = []
    while (childEnt != null) {
        children.append(childEnt)
        childEnt = childEnt.NextMovePeer()
    }

    return children
}
