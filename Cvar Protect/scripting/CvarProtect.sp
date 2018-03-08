#include <sourcemod>
#include <textparse>
#include <convars>

#pragma newdecls  required
#pragma semicolon 1

char      g_szPluginLog[PLATFORM_MAX_PATH];
ArrayList g_hProtected;
StringMap g_hCvValues;
SMCParser g_hParser;

#define LOG(%0)         LogToFileEx(g_szPluginLog, %0)

#define PLUGIN_VERSION  "1.0"
#define PLUGIN_AUTHOR   "CrazyHackGUT aka Kruzya"
#define PLUGIN_URL      "https://kruzefag.ru/"

public Plugin myinfo = {
  description = "Protects server convars from changing.",
  version     = PLUGIN_VERSION,
  author      = PLUGIN_AUTHOR,
  name        = "Cvar Protector",
  url         = PLUGIN_URL
};

public void OnPluginStart() {
  BuildPath(Path_SM, g_szPluginLog, sizeof(g_szPluginLog), "logs/CvarProtect.log");

  g_hProtected  = new ArrayList(4);
  g_hCvValues   = new StringMap();
  g_hParser     = new SMCParser();

  g_hParser.OnEnterSection  = Parser_SectionStart;
  g_hParser.OnLeaveSection  = Parser_SectionEnd;
  g_hParser.OnKeyValue      = Parser_KeyValue;

  RegServerCmd("sm_dump_cvarprotect", Cmd_DumpCvarProtect);
  RegServerCmd("sm_reloadcvarprotect", Cmd_ReloadCvarProtect);
}

public void OnMapStart() {
  LoadMapConfig("default", true);

  char szMap[PLATFORM_MAX_PATH];
  GetCurrentMap(szMap, sizeof(szMap));

  int iPos;
  if ((iPos = FindCharInString(szMap, '_')) != -1) {
    iPos++;
    char[] szMapPrefix = new char[iPos];
    strcopy(szMapPrefix, iPos, szMap);

    LoadMapConfig(szMapPrefix, false);
  }

  if ((iPos = FindCharInString(szMap, '/', true)) != -1) { // workshop map scratch
    LoadMapConfig(szMap[iPos+1], false);
  } else {
    LoadMapConfig(szMap, false);
  }
}

public void OnConfigsExecuted() {
  RecheckConvars();
}

public void OnMapEnd() {
  int iLength = g_hProtected.Length;

  LOG("Disable hooks... Current hook count: %d", iLength);
  for (int i; i < iLength; ++i) {
    (view_as<ConVar>(g_hProtected.Get(i))).RemoveChangeHook(OnCvarChanged);
  }

  g_hProtected.Clear();
}

void LoadMapConfig(const char[] szConfigName, bool bRequired = false) {
  LOG("Loading %s.conf configuration...", szConfigName);

  char szFilePath[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, szFilePath, sizeof(szFilePath), "data/cvar_protect/%s.conf", szConfigName);

  if (!FileExists(szFilePath)) {
    LOG("Couldn't load %s.conf file, because file not exists.", szConfigName);

    if (bRequired)
      ThrowError("See %s log file for more information.", g_szPluginLog);

    return;
  }

  int iLine, iCol;
  SMCError eRes = g_hParser.ParseFile(szFilePath, iLine, iCol);

  if (eRes != SMCError_Okay) {
    LOG("Couldn't parse %s.conf. Error code %d, line %d, column %d.", szConfigName, eRes, iLine, iCol);

    if (bRequired) {
      ThrowError("See %s log file for more information.", g_szPluginLog);
      return;
    }
  }
}

void OnCvarChanged(ConVar hCvar, const char[] szOldValue, const char[] szNewValue) {
  char szCvarName[256];
  hCvar.GetName(szCvarName, sizeof(szCvarName));

  char szRequiredValue[1024];
  if (!g_hCvValues.GetString(szCvarName, szRequiredValue, sizeof(szRequiredValue))) {
    // This should never happen!

    SaveConvarValue(hCvar);
    return;
  }

  bool bResult = (strcmp(szRequiredValue, szNewValue, true) == 0);

  if (!bResult) {
    LOG("Attempt edit cvar (address %x, name %s) value (%s). Resetting...", hCvar, szCvarName, szNewValue);
    hCvar.SetString(szRequiredValue);
  }
}

void SaveConvarValue(ConVar hCvar, bool bReplace = true) {
  char szCvarName[256];
  char szValue[1024];

  hCvar.GetName(szCvarName, sizeof(szCvarName));
  hCvar.GetString(szValue, sizeof(szValue));

  g_hCvValues.SetString(szCvarName, szValue, bReplace);
}

// parsers
ConVar g_hCurrentParseCvar;

SMCResult Parser_SectionStart(SMCParser hParser, const char[] szValue, bool bOptQuotes) {
  if (strcmp(szValue, "CvarProtect") == 0)
    return;

  g_hCurrentParseCvar = FindConVar(szValue);
  if (g_hCurrentParseCvar == null)
    LOG("Failed to locate convar %s. Skipping...", szValue);
}

SMCResult Parser_SectionEnd(SMCParser hParser) {}

SMCResult Parser_KeyValue(SMCParser hParser, const char[] szKey, const char[] szValue, bool bKeyQuotes, bool bValueQuotes) {
  if (g_hCurrentParseCvar == null)
    return;

  if (strcmp(szKey, "Hook", false) == 0) {
    bool bHookRes = szValue[0] != '0';

    if (!bHookRes) {
      int iCvarId = g_hProtected.FindValue(g_hCurrentParseCvar);
      if (iCvarId == -1) {
        return;
      }

      g_hProtected.Erase(iCvarId);
      g_hCurrentParseCvar.RemoveChangeHook(OnCvarChanged);
    } else {
      g_hProtected.Push(g_hCurrentParseCvar);
      g_hCurrentParseCvar.AddChangeHook(OnCvarChanged);
    }
  } else if (strcmp(szKey, "Value", false) == 0) {
    if (strcmp(szValue, "CURRENT_VALUE", true) == 0) {
      SaveConvarValue(g_hCurrentParseCvar);
    } else if (strcmp(szValue, "CACHED_VALUE", true) == 0) {
      SaveConvarValue(g_hCurrentParseCvar, false);
    } else if (strcmp(szValue, "DEFAULT_VALUE", true) == 0) {
      char szCvarName[256];
      char szDefaultValue[1024];

      g_hCurrentParseCvar.GetName(szCvarName, sizeof(szCvarName));
      g_hCurrentParseCvar.GetDefault(szDefaultValue, sizeof(szDefaultValue));
      g_hCvValues.SetString(szCvarName, szDefaultValue, true);
    } else {
      char szCvarName[256];
      g_hCurrentParseCvar.GetName(szCvarName, sizeof(szCvarName));

      g_hCvValues.SetString(szCvarName, szValue, true);
    }
  } else {
    LOG("Unknown key %s (cvar handle %x).", szKey, g_hCurrentParseCvar);
  }
}

// commands
Action Cmd_DumpCvarProtect(int iArgC) {
  int iLength = g_hProtected.Length;

  PrintToServer("----==== CVAR PROTECT | DUMP MEMORY ====----");
  PrintToServer("   ID  |  Address | Name | (on next string - required value)");

  char szCvarName[256];
  char szRequiredValue[1024];
  ConVar hCv;

  for (int i; i < iLength; ++i) {
    hCv = g_hProtected.Get(i);
    hCv.GetName(szCvarName, sizeof(szCvarName));
    g_hCvValues.GetString(szCvarName, szRequiredValue, sizeof(szRequiredValue));

    PrintToServer("- %04d | %08x | %s", i+1, hCv, szCvarName);
    PrintToServer("  %s", szRequiredValue);
  }

  return Plugin_Handled;
}

Action Cmd_ReloadCvarProtect(int iArgC) {
  OnMapEnd();
  OnMapStart();
  OnConfigsExecuted();
  return Plugin_Handled;
}

// rechecker
void RecheckConvars() {
  int iLength = g_hProtected.Length;
  ConVar hCvar;
  char szCurrentValue[1024];

  for (int i; i < iLength; ++i) {
    hCvar = g_hProtected.Get(i);
    hCvar.GetString(szCurrentValue, sizeof(szCurrentValue));

    OnCvarChanged(hCvar, NULL_STRING, szCurrentValue);
  }
}