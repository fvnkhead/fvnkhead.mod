global function fm_RebalancedInit

global struct RebalancedEntry {
    string name,
    string desc
}

global array<RebalancedEntry> BUFF_LIST = []
global array<RebalancedEntry> NERF_LIST = []
global array<RebalancedEntry> LATEST_LIST = []

void function fm_RebalancedInit() {
    Buff("smr",           "explosion dmg 15 => 20")
    Buff("b3 wingman",    "fire rate 2.6 => 3.7")
    Buff("arc grenade",   "explodes on impact")
    Buff("satchel",   "pilot damage 125 => 140")
    Buff("pulse blade",   "3x faster recharge, 2x shorter sonar")
    Buff("thunderbolt",   "direct hit dmg 70 => 100")
    Buff("archer", "dumbfire enabled, splash reduced")
    Buff("mgl", "explosion damage 35 => 60")

    Nerf("melee",         "dmg 100 => 60")
    Nerf("car",           "dmg 25 => 15")
    Nerf("r97",           "dmg 20 => 14")
    Nerf("alternator",    "dmg 35 => 25")
    Nerf("volt",          "dmg 25 => 18")
    Nerf("r201 & r101",   "dmg 25 => 18")
    Nerf("flatline",      "dmg 30 => 20")
    Nerf("g2",            "more falloff")
    Nerf("hemlok",        "dmg 33 => 25")
    Nerf("spitfire",      "dmg 35 => 28")
    Nerf("devotion",      "dmg 25 => 22")
    Nerf("dmr",           "more falloff")
    Nerf("eva8",          "dmg 200 => 140, improved dmg calculation")
    Nerf("mozam",         "dmg 30 => 25")
    Nerf("p2016",         "dmg 30 => 20")
    Nerf("re45",          "dmg 20 => 12")
    Nerf("gravstar",      "25% slower recharge")

    Latest("pulse blade", "3x faster recharge, 2x shorter sonar")
    Latest("car and r97", "+1 dmg")
    Latest("alternator", "+3 dmg")
    Latest("dmr", "removed dmg nerf, increased falloff")
    Latest("spitfire", "+3 dmg")
    Latest("devotion", "+2 dmg")
    Latest("r201 & r101", "-2 dmg")
    Latest("eva8", "-20 dmg, improved dmg calculation")
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
