global function fm_RebalancedInit

global struct RebalancedEntry {
    string name,
    string desc
}

global array<RebalancedEntry> BUFF_LIST = []
global array<RebalancedEntry> NERF_LIST = []
global array<RebalancedEntry> LATEST_LIST = []

void function fm_RebalancedInit() {
    Buff("double take",   "fire rate 2.0 => 2.4")
    Buff("smr",           "explosion dmg 15 => 20")
    Buff("b3 wingman",    "fire rate 2.6 => 3.7")
    Buff("arc grenade",   "explodes on impact")
    Buff("satchel",   "pilot damage 125 => 140")
    Buff("pulse blade",   "50% faster recharge")
    Buff("thunderbolt",   "direct hit dmg 70 => 100")
    Buff("archer", "dumbfire enabled, splash reduced")
    Buff("mgl", "explosion damage 35 => 55")

    Nerf("melee",         "dmg 100 => 60")
    Nerf("car",           "dmg 25 => 14")
    Nerf("r97",           "dmg 20 => 13")
    Nerf("alternator",    "dmg 35 => 22")
    Nerf("volt",          "dmg 25 => 18")
    Nerf("r201 & r101",   "dmg 25 => 18")
    Nerf("flatline",      "dmg 30 => 20")
    Nerf("g2",            "more falloff")
    Nerf("hemlok",        "dmg 33 => 25")
    Nerf("spitfire",      "dmg 35 => 25")
    Nerf("devotion",      "dmg 25 => 20")
    Nerf("dmr",           "dmg 55 => 45")
    Nerf("eva8",          "dmg 200 => 160")
    Nerf("mozam",         "dmg 30 => 25")
    Nerf("p2016",         "dmg 30 => 20")
    Nerf("re45",          "dmg 20 => 13")
    Nerf("gravstar",      "25% slower recharge")

    Latest("mgl", "explosion dmg 35 => 55")
    Latest("r201 & r101", "-2 dmg")
    Latest("re45", "+1 dmg")
    Latest("volt", "+2 dmg")
    Latest("satchel", "+15 pilot dmg")
    Latest("gravstar", "25% slower recharge")
}

void function Buff(string name, string desc) {
    BUFF_LIST.append(Entry(name, desc))
}

void function Nerf(string name, string desc) {
    NERF_LIST.append(Entry(name, desc))
}

void function Latest(string name, string desc) {
    LATEST_LIST.append(Entry(name, desc))
}

RebalancedEntry function Entry(string name, string desc) {
    RebalancedEntry entry
    entry.name = name
    entry.desc = desc
    return entry
}
