#include <sourcemod>
#include <sdktools>
#include <tf2items>

#pragma newdecls required

#include "TF2_TauntMenu/TauntEm.sp"
#include "TF2_TauntMenu/Config.sp"
#include "TF2_TauntMenu/Menu.sp"
#include "TF2_TauntMenu/API.sp"

static const char[][] g_szCommands = {
    "sm_taunt",
    "sm_taunts",
    "sm_t"
};

public Plugin myinfo = {
    description = "Allow to use taunts.",
    version     = "1.0",
    author      = "CrazyHackGUT aka Kruzya",
    name        = "[TF2] Advanced TauntMenu",
    url         = "https://github.com/CrazyHackGUT/sm-plugins/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    API_CreateNatives();
    API_CreateForwards();

    return APLRes_Success;
}

public void OnPluginStart() {
    TauntEm_Init();
    Config_Init();

    for (int i = 0; i < sizeof(g_szCommands); i++)
        RegConsoleCmd(g_szCommands[i], CmdTauntCallback, "Shows menu with taunts.");

    RegConsoleCmd("sm_reload_taunts", CmdConfigReload, "Reloads the configuration file.");
}

public void OnMapStart() {
    Config_Start();
}

public Action CmdTauntCallback(int iClient, int iArgs) {
    if (iClient)
        Menu_Draw(iClient);

    return Plugin_Handled;
}

public Action CmdConfigReload(int iClient, int iArgs) {
    Config_Start();
    return Plugin_Handled;
}
