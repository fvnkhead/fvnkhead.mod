global function fm_Init

//------------------------------------------------------------------------------
// structs
//------------------------------------------------------------------------------
struct Command {
    string name
    void functionref(entity, array<string>) fn
}

//------------------------------------------------------------------------------
// globals
//------------------------------------------------------------------------------
array<Command> COMMANDS = []

string WELCOME = ""
array<string> WELCOMED_PLAYERS = []


void function fm_Init() {
    #if SERVER

    WELCOME = GetConVarString("fm_welcome")
    if (WELCOME != "") {
        AddCallback_OnPlayerRespawned(OnPlayerRespawnedWelcome)
        AddCallback_OnClientDisconnected(OnClientDisconnectedWelcome)
    }

    AddCallback_OnReceivedSayTextMessage(ChatCallback)

    COMMANDS.append(newCommand("!help", CommandHelp))

    #endif
}

//------------------------------------------------------------------------------
// command handling
//------------------------------------------------------------------------------
Command function newCommand(string name, void functionref(entity, array<string>) fn) {
    Command command
    command.name = name
    command.fn = fn
    return command
}

ClServer_MessageStruct function ChatCallback(ClServer_MessageStruct messageInfo) {
    string message = strip(messageInfo.message)
    bool isCommand = format("%c", message[0]) == "!"
    if (isCommand) {
        entity player = messageInfo.player

        array<string> args = split(message, " ")
        string command = args[0]
        args.remove(0)

        bool commandFound = false
        foreach (Command c in COMMANDS) {
            if (command == c.name) {
                wait 0.1
                c.fn(player, args)
                commandFound = true
            }
        }

        if (!commandFound) {
            sendMessage(player, red("unknown command: " + command))
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
void function CommandHelp(entity player, array<string> args) {
    sendMessage(player, blue("help"))
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
