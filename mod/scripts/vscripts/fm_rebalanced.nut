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
    Buff("softball",        "explosion dmg 90 => 100")
    Buff("b3 wingman",    "fire rate 2.6 => 3.7")
    Buff("arc grenade",   "explodes on impact")
    Buff("smoke grenade",   "increased dmg")
    Buff("satchel",   "pilot dmg 125 => 140")
    Buff("pulse blade",   "3x faster recharge, 2x shorter sonar")
    Buff("thunderbolt",   "increased dmg to pilots")
    Buff("archer", "dumbfire enabled, splash reduced")
    Buff("mgl", "explosion dmg 35 => 60")
    Buff("silencers", "don't break cloak")
    Buff("tactikill", "25% => 40%")

    Nerf("melee",         "dmg 100 => 60")
    Nerf("car",           "dmg 25 => 15")
    Nerf("r97",           "dmg 20 => 13")
    Nerf("alternator",    "dmg 35 => 22")
    Nerf("volt",          "dmg 25 => 20")
    Nerf("r201 & r101",   "dmg 25 => 18")
    Nerf("flatline",      "dmg 30 => 20")
    Nerf("g2",            "more falloff")
    Nerf("hemlok",        "dmg 33 => 25")
    Nerf("spitfire",      "dmg 35 => 28")
    Nerf("devotion",      "dmg 25 => 22")
    Nerf("dmr",           "more falloff")
    Nerf("eva8",          "improved dmg calculation")
    Nerf("mozam",         "dmg 30 => 25")
    Nerf("p2016",         "dmg 30 => 20")
    Nerf("re45",          "dmg 20 => 12")
    Nerf("gravstar",      "25% slower recharge")
    Nerf("stim & phase",  "25% slower recharge")

    Latest("stim & phase",  "25% slower recharge")
    Latest("volt", "+2 dmg")
    Latest("r97", "-1 dmg")
    Latest("smoke grenade", "increased dmg")
    Latest("alternator", "-3 dmg")
    Latest("eva8", "improved dmg calculation")
    Latest("softball", "explosion dmg 90 => 100")
    Latest("silencers", "don't break cloak")
    Latest("tactikill", "25% => 40%")
    Latest("thunderbolt",   "increased dmg to pilots")
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
