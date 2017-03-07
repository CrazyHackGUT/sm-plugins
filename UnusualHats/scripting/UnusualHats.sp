#error "This plugin don't ready for usage."

#include <tf2attributes>
#include <tf2_stocks>
#include <tf2>
#include <dbi>

#define PLUGIN_VERSION  "0.1"
#define PLUGIN_FAQ      "Preparing..."

#pragma newdecls required

/* Enums */
enum {
    DatabaseType_Unknown    = -1,
    DatabaseType_MySQL      = 0,
    DatabaseType_SQLite     = 1
}

/* Global vars */
Database g_hDB;
int g_iDBType;

/* Plugin information */
public Plugin myinfo = {
    version = PLUGIN_VERSION,
    author  = "CrazyHackGUT aka Kruzya",
    name    = "[TF2] Unusual Hats"
    url     = "https://github.com/CrazyHackGUT/sm-plugins/"
};

/* Basic Forwards */
public void OnPluginStart() {
    RegConsoleCmd("sm_unusual", CmdCallback);
    RegConsoleCmd("sm_uhats", CmdCallback);
    RegConsoleCmd("sm_hats", CmdCallback);
}

public void OnMapStart() {
    DB_Connect();
}

public void OnMapEnd() {
    DB_Kill();
}

/* Command handler */
public Action CmdCallback(int iClient, int iArgs) {
    return Plugin_Handled;
}

/* SQL: Helpers */
public void DB_Connect() {
    if (g_hDB)
        return;

    Database.Connect(DB_ConnectCallback, "unusualhats");
}

public void DB_Kill() {
    if (!g_hDB)
        return;

    delete g_hDB;
    g_hDB = null;
}

public void DB_DetectType() {
    if (!g_hDB)
        return;

    char szIdentify[2];
    g_hDB.Driver.GetIdentifier(szIdentify, sizeof(szIdentify));

    if (szIdentity[0] == 'm')
        g_iDBType   = DatabaseType_MySQL;
    else if (szIdentity[0] == 's')
        g_iDBType   = DatabaseType_SQLite;
    else
        g_iDBType   = DatabaseType_Unknown;
}

public void DB_CreateTables() {
    if (!g_hDB)
        return;

    // Preparing...
}

/* SQL: Callbacks */
public void DB_ConnectCallback(Database db, const char[] error, any data) {
    if (!db) {
        LogError("[SQL] Database connection failed: %s. See FAQ: %s", error, PLUGIN_FAQ);
        return;
    }

    g_hDB = db;
    g_hDB.SetCharset("utf8");

    DB_DetectType();
    DB_CreateTables();
}
