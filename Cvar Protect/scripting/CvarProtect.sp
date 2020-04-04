/**
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#include <sourcemod>
#include <textparse>
#include <convars>

#pragma newdecls  required
#pragma semicolon 1

char      g_szPluginLog[PLATFORM_MAX_PATH];
ArrayList g_hProtected;
StringMap g_hCvValues;
SMCParser g_hParser;

ConVar    g_hFrequency;
Handle    g_hTimer;

#define LOG(%0)         LogToFileEx(g_szPluginLog, %0)

#define PLUGIN_VERSION  "1.2.0.0"
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

  g_hFrequency = CreateConVar("sm_cvarprotect_frequency", "0.0", "How often convar values should be verified? Use value less 1.0 for disabling this option", _, true, 0.0, false, 0.0);
  g_hFrequency.AddChangeHook(OnFrequencyChanged);
}

public void OnMapStart() {
  // config load order (example map: workshop/12345678/de_olddust2)
  // - default
  // - de
  // - de_olddust2

  LoadMapConfig("default", true);

  char szMap[PLATFORM_MAX_PATH];
  GetCurrentMap(szMap, sizeof(szMap));

  int iPos = FindCharInString(szMap, '/', true);
  if (iPos != -1)
    strcopy(szMap, sizeof(szMap), szMap[iPos+1]);

  if ((iPos = FindCharInString(szMap, '_')) != -1) {
    iPos++;
    char[] szMapPrefix = new char[iPos];
    strcopy(szMapPrefix, iPos, szMap);

    LoadMapConfig(szMapPrefix, false);
  }

  LoadMapConfig(szMap, false);
}

public void OnConfigsExecuted() {
  OnFrequencyChanged(null, NULL_STRING, NULL_STRING);
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

  if (strcmp(szRequiredValue, szNewValue, true) != 0) {
    LOG("Attempt edit cvar with name %s. New value: '%s'. Resetting to old value...", szCvarName, szNewValue);
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

Action RecheckConvarsTimer(Handle hTimer) {
  RecheckConvars();
}

void OnFrequencyChanged(ConVar hCvar, const char[] szOldValue, const char[] szNewValue) {
  if (g_hTimer != null)
  {
    KillTimer(g_hTimer, false);
  }

  float flValue = g_hFrequency.FloatValue;
  if (flValue < 1.0)
  {
    return;
  }

  g_hTimer = CreateTimer(flValue, RecheckConvarsTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}
