/**
 * =============================================================================
 * [VIP / CCC] Menu Editor
 * Menu for editing colors/prefix in chat.
 *
 * File: VIP_CCC.sp
 * Role: -
 * =============================================================================
 *
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

#include <clientprefs>
#include <sourcemod>
#include <vip_core>
#include <kruzya>
#include <ccc>

#pragma newdecls required
#pragma semicolon 1

/**
 * @section Constants
 */
#define PLUGIN_DESCRIPTION  "Menu for editing colors/prefix in chat."
#define PLUGIN_VERSION      "2.0.1"
#define PLUGIN_AUTHOR       "CrazyHackGUT aka Kruzya"
#define PLUGIN_NAME         "[VIP] Custom Chat Colors"
#define PLUGIN_URL          "https://kruzefag.ru/"

#define UNIXTIME            GetTime()
#define SZFS(%0)            %0, sizeof(%0)
#define SZFA(%0,%1)         %0[%1], sizeof(%0[])
#define SGT(%0)             SetGlobalTransTarget(%0)
#define CID(%0)             GetClientOfUserId(%0)
#define CUD(%0)             GetClientUserId(%0)
#define IsEmptyString(%0)   %0[0] == 0

#define PMP                 PLATFORM_MAX_PATH
#define MTL                 MAX_TARGET_LENGTH
#define MPL                 MAXPLAYERS
#define MCL                 MaxClients

#define nullvct             NULL_VECTOR
#define nullstr             NULL_STRING
#define nullptr             null

stock const char g_szVIPEnabler[]       = "CCC_Enabler";
stock const char g_szVIPSettings[]      = "CCC_Settings";
stock const char g_szVIPPermission[]    = "CCC";

stock const char g_szCookiesNames[][]   = {"VIP_CCC_Prefix", "VIP_CCC_ChatColor", "VIP_CCC_NameColor", "VIP_CCC_PrefixColor", "VIP_CCC_LastVIPDetect", "VIP_CCC_Enabled"};
stock const char g_szCookiesDescs[][]   = {"[VIP CCC] Storage for Prefix", "[VIP CCC] Storage for Chat Color", "[VIP CCC] Storage for Name Color", "[VIP CCC] Storage for Prefix Color", "[VIP CCC] Storage for Timestamp last detecting as VIP.", "[VIP CCC] Storage for Enable state."};

#define PREFIX          0
#define CHATCOLOR       1
#define NAMECOLOR       2
#define PREFIXCOLOR     3
#define LASTVIPDETECT   4

#define RED             0
#define GREEN           1
#define BLUE            2
#define ALPHA           3

/**
 * @section Global Variables
 */
Handle          g_hCookies[6];              /**< Handle Cookies Storage */
Handle          g_hPresets;                 /**< Color Presets */

bool            g_bChatEnabled[MPL+1];
char            g_szPrefix[MPL+1][32];      /**< Current Player Prefix */
int             g_iCPrefix[MPL+1];          /**< Current Player Prefix Color */
int             g_iCChat[MPL+1];            /**< Current Player Chat Text Color */
int             g_iCName[MPL+1];            /**< Current Player Name Color */

int             g_iMaxAFKTime;              /**< ConVar cached value */

CCC_ColorType   g_eType[MPL+1];             /**< Current selected color type */
int             g_iSelectedColor[MPL+1][3]; /**< Current selected color */
bool            g_bListenChat[MPL+1];       /**< Listen client chat for saving prefix? */

/**
 * @section Plugin Information.
 */
public Plugin myinfo = {
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    author      = PLUGIN_AUTHOR,
    name        = PLUGIN_NAME,
    url         = PLUGIN_URL
};

/**
 * @section Generic Events
 */
public void OnPluginStart() {
    // Create Cookies Storage.
    for (int i; i < 6; i++) {
        g_hCookies[i] = RegClientCookie(g_szCookiesNames[i], g_szCookiesDescs[i], CookieAccess_Private);
    }

    // Load clients.
    for (int i; ++i <= MaxClients;) {
        if (!IsClientInGame(i) || IsFakeClient(i))
            continue;

        VIP_OnClientLoaded(i, VIP_IsClientVIP(i));
    }

    // Attach to VIP Core.
    if (LibraryExists("vip_core") && VIP_IsVIPLoaded()) {
        VIP_OnVIPLoaded();
    }

    // Load translations.
    LoadTranslations("vip_ccc.phrases");

    // For presets.
    g_hPresets = CreateTrie();

    // Hook chat.
    if (!AddCommandListener(OnSayHook, "say")) {
        SetFailState("AddCommandListener() feature not available on this game.");
    }

    // Create convar and hook.
    HookConVarChange(CreateConVar("sm_vip_ccc_autoclean", "30", "Раз в какое кол-во дней производить блокировку доступа к префиксу?\n0 - не чистить"), OnCvarChanged);
    AutoExecConfig(true, "CustomChatColors", "vip");
}

public void OnConfigsExecuted() {
    g_iMaxAFKTime = GetConVarInt(FindConVar("sm_vip_ccc_autoclean"));
}

public void OnCvarChanged(Handle hCvar, const char[] szOldValue, const char[] szNewValue) {
    g_iMaxAFKTime = GetConVarInt(hCvar);
}

public void OnPluginEnd() {
    VIP_UnregisterFeature(g_szVIPEnabler);
    VIP_UnregisterFeature(g_szVIPSettings);
    VIP_UnregisterFeature(g_szVIPPermission);
}

public void OnMapStart() {
    static Handle hSMC = nullptr;
    static char   szPath[PMP];

    if (hSMC == nullptr) {
        hSMC = SMC_CreateParser();
        SMC_SetReaders(hSMC, OnNewSection, OnKeyValues, OnEndSection);
    }
    if (IsEmptyString(szPath)) {
        BuildPath(Path_SM, SZFS(szPath), "data/vip/modules/CustomChatColors.presets.cfg");
    }
    if (!FileExists(szPath)) {
        LogError("Couldn't find color presets. Presets blocked.");
        return;
    }

    SMCError eError = SMC_ParseFile(hSMC, szPath);
    if (eError != SMCError_Okay) {
        LogError("Can't parse file %s. Error %d.", szPath, eError);
    }
}

public void OnMapEnd() {
    int iLength = GetTrieSize(g_hPresets);
    if (iLength == 0)
        return;

    ClearTrie(g_hPresets);
}

/**
 * @section VIP Loaders Events
 */
public void VIP_OnVIPLoaded() {
    // Permission Manager
    VIP_RegisterFeature(g_szVIPPermission, BOOL, HIDE);

    // Color disabler/enabler
    VIP_RegisterFeature(g_szVIPEnabler, VIP_NULL, TOGGLABLE, VIP_OnTouchedLever, _, VIP_OnCheckCCCAccess);
    // для ядра 3.0 (ещё не релизнуто, нестабильно, в течении августа Рико обещал)
    // VIP_SetFeatureDefStatus(g_szVIPEnabler, false);

    // Settings Manager
    VIP_RegisterFeature(g_szVIPSettings, VIP_NULL, SELECTABLE, VIP_OnTouchedSettings, _, VIP_OnCheckCCCAccess);
}

public void VIP_OnClientLoaded(int iClient, bool bIsVIP) {
    g_bChatEnabled[iClient] && Setup(iClient);
    if (!bIsVIP)
        return;

    UpdateAFKTime(iClient);
    if (VIP_IsClientFeatureUse(iClient, g_szVIPPermission))  {
        VIP_SetClientFeatureStatus(iClient, g_szVIPEnabler, g_bChatEnabled[iClient] ? ENABLED : DISABLED);
    }
}

/**
 * @section Cookies Loaded Event
 */
public void OnClientCookiesCached(int iClient) {
    if ((Kruzya_GetClientIntCookie(iClient, g_hCookies[4]) + g_iMaxAFKTime * 86400) < UNIXTIME) {
        Kruzya_SetClientIntCookie(iClient, g_hCookies[5], 0);
    }

    g_iCChat[iClient]       = Kruzya_GetClientIntCookie(iClient, g_hCookies[1]);
    g_iCName[iClient]       = Kruzya_GetClientIntCookie(iClient, g_hCookies[2]);
    g_iCPrefix[iClient]     = Kruzya_GetClientIntCookie(iClient, g_hCookies[3]);
    g_bChatEnabled[iClient] = (Kruzya_GetClientIntCookie(iClient, g_hCookies[5]) != 0);

    GetClientCookie(iClient, g_hCookies[0], SZFA(g_szPrefix, iClient));
}

public void OnClientDisconnect(int iClient) {
    Kruzya_SetClientIntCookie(iClient, g_hCookies[1], g_iCChat[iClient]);
    Kruzya_SetClientIntCookie(iClient, g_hCookies[2], g_iCName[iClient]);
    Kruzya_SetClientIntCookie(iClient, g_hCookies[3], g_iCPrefix[iClient]);
    Kruzya_SetClientIntCookie(iClient, g_hCookies[5], g_bChatEnabled[iClient] ? 1 : 0);
    SetClientCookie(iClient, g_hCookies[0], g_szPrefix[iClient]);
}

/**
 * @section VIP Callbacks
 */
public Action VIP_OnTouchedLever(int iClient, const char[] szFeatureName, VIP_ToggleState eOldStatus, VIP_ToggleState &eNewStatus) {
    if (eNewStatus == ENABLED) {
        g_bChatEnabled[iClient] = true;
        AreClientCookiesCached(iClient) && Setup(iClient);
        return Plugin_Continue;
    }
    g_bChatEnabled[iClient] = false;

    Reset(iClient);
    return Plugin_Continue;
}

public bool VIP_OnTouchedSettings(int iClient, const char[] szFeatureName) {
    Menu_RenderMain(iClient);
    return false;
}

public int VIP_OnCheckCCCAccess(int iClient, const char[] szFeatureName, int iStyle) {
    return VIP_IsClientFeatureUse(iClient, g_szVIPPermission) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
}

/**
 * @section Menu Renderers.
 */
void Menu_RenderMain(int iClient) {
    Handle hMenu = CreateMenu(Menu_MainHandler);
    SetMenuTitle(hMenu, "%T\n ", "CCC_Main_Title", iClient);

    char szBuffer[64];
    FormatEx(SZFS(szBuffer), "%T", "CCC_Item_PrefixSetup", iClient);
    AddMenuItem(hMenu, nullstr, szBuffer, ITEMDRAW_DEFAULT);

    FormatEx(SZFS(szBuffer), "%T", "CCC_Item_PrefixColorSetup", iClient);
    AddMenuItem(hMenu, nullstr, szBuffer, ITEMDRAW_DEFAULT);

    FormatEx(SZFS(szBuffer), "%T", "CCC_Item_NameColorSetup", iClient);
    AddMenuItem(hMenu, nullstr, szBuffer, ITEMDRAW_DEFAULT);

    FormatEx(SZFS(szBuffer), "%T", "CCC_Item_TextColorSetup", iClient);
    AddMenuItem(hMenu, nullstr, szBuffer, ITEMDRAW_DEFAULT);

    SetMenuExitBackButton(hMenu, true);
    SetMenuExitButton(hMenu, true);
    DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
}

void Menu_SetupPrefix(int iClient) {
    g_bListenChat[iClient] = true;

    Handle hMenu = CreateMenu(Menu_PrefixHandler);
    SetMenuTitle(hMenu, "%T\n ", "CCC_Item_PrefixSetup", iClient);

    char szBuffer[256];
    FormatEx(SZFS(szBuffer), "%T", "CCC_Help_PrefixSetup_1", iClient);
    AddMenuItem(hMenu, nullstr, szBuffer, ITEMDRAW_DISABLED);

    FormatEx(SZFS(szBuffer), "%T", "CCC_Help_PrefixSetup_2", iClient);
    AddMenuItem(hMenu, nullstr, szBuffer, ITEMDRAW_DISABLED);

    SetMenuExitBackButton(hMenu, true);
    SetMenuExitButton(hMenu, false);
    DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
}

void Menu_SetupColor(int iClient) {
    char szBuffer[256];
    Handle hMenu = CreateMenu(Menu_ColorHandler);

    switch (g_eType[iClient]) {
        case CCC_TagColor:  strcopy(SZFS(szBuffer), "CCC_Item_PrefixColorSetup");
        case CCC_NameColor: strcopy(SZFS(szBuffer), "CCC_Item_NameColorSetup");
        case CCC_ChatColor: strcopy(SZFS(szBuffer), "CCC_Item_TextColorSetup");
    }

    SetMenuTitle(hMenu, "%T\n ", szBuffer, iClient);

    FormatEx(SZFS(szBuffer), "%T", "CCC_Item_Red", iClient);
    AddMenuItem(hMenu, nullstr, szBuffer, ITEMDRAW_DEFAULT);

    FormatEx(SZFS(szBuffer), "%T", "CCC_Item_Green", iClient);
    AddMenuItem(hMenu, nullstr, szBuffer, ITEMDRAW_DEFAULT);

    FormatEx(SZFS(szBuffer), "%T\n ", "CCC_Item_Blue", iClient);
    AddMenuItem(hMenu, nullstr, szBuffer, ITEMDRAW_DEFAULT);

    FormatEx(SZFS(szBuffer), "%T", "CCC_Item_Save", iClient);
    AddMenuItem(hMenu, nullstr, szBuffer, ITEMDRAW_DEFAULT);

    FormatEx(SZFS(szBuffer), "%T", "CCC_Item_Presets", iClient);
    AddMenuItem(hMenu, nullstr, szBuffer, (GetTrieSize(g_hPresets) == 0) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    FormatEx(SZFS(szBuffer), "%T\n ", "CCC_Item_Reset", iClient);
    AddMenuItem(hMenu, nullstr, szBuffer, ITEMDRAW_DEFAULT);

    // FormatEx(SZFS(szBuffer), "%T", "CCC_Item_Preview", iClient);
    // AddMenuItem(hMenu, nullstr, szBuffer, ITEMDRAW_DEFAULT);

    SetMenuExitBackButton(hMenu, true);
    SetMenuExitButton(hMenu, false);
    DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
}

void Menu_RenderColorizer(int iClient, int iColorType) {
    Handle hMenu = CreateMenu(Menu_ColorizerHandler);
    char szBuffer[256];
    char szColor[2];

    switch (iColorType) {
        case RED:   strcopy(SZFS(szBuffer), "CCC_TitleColorizer_RED"), szColor[0] = 'R';
        case GREEN: strcopy(SZFS(szBuffer), "CCC_TitleColorizer_GREEN"), szColor[0] = 'G';
        case BLUE:  strcopy(SZFS(szBuffer), "CCC_TitleColorizer_BLUE"), szColor[0] = 'B';
    }

    SetMenuTitle(hMenu, "%T (%T)\n ", szBuffer, iClient, "CCC_TitleColorizer_Consistency", iClient, g_iSelectedColor[iClient][iColorType]);
    szColor[1] = 0;

    int iColor = g_iSelectedColor[iClient][iColorType];

    int iRenderUp = (iColor == 255) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
    int iRenderDown = (iColor == 0) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;

    FormatEx(SZFS(szBuffer), "%T", "CCC_Item_Up", iClient, 1);
    AddMenuItem(hMenu, szColor, szBuffer, iRenderUp);

    FormatEx(SZFS(szBuffer), "%T", "CCC_Item_Up", iClient, 10);
    AddMenuItem(hMenu, szColor, szBuffer, iRenderUp);

    FormatEx(SZFS(szBuffer), "%T\n ", "CCC_Item_UpMAX", iClient);
    AddMenuItem(hMenu, szColor, szBuffer, iRenderUp);

    FormatEx(SZFS(szBuffer), "%T", "CCC_Item_Down", iClient, 1);
    AddMenuItem(hMenu, szColor, szBuffer, iRenderDown);

    FormatEx(SZFS(szBuffer), "%T", "CCC_Item_Down", iClient, 10);
    AddMenuItem(hMenu, szColor, szBuffer, iRenderDown);

    FormatEx(SZFS(szBuffer), "%T", "CCC_Item_DownMAX", iClient);
    AddMenuItem(hMenu, szColor, szBuffer, iRenderDown);

    SetMenuExitBackButton(hMenu, true);
    SetMenuExitButton(hMenu, false);
    DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
}

void Menu_RenderPresets(int iClient) {
    int iLength = GetTrieSize(g_hPresets);
    if (iLength == 0) {
        PrintToChat(iClient, "\x04[VIP] \x01%t", "CCC_Text_NoAvailablePresets");
        Menu_SetupColor(iClient);
        return;
    }

    Handle hMenu = CreateMenu(Menu_PresetsHandler);
    SetMenuTitle(hMenu, "%T\n ", "CCC_Text_SelectPreset", iClient);

    char szBuffer[2][64];
    int iColor;
    Handle hSnap = CreateTrieSnapshot(g_hPresets);
    for (int i; i < iLength; i++) {
        GetTrieSnapshotKey(hSnap, i, SZFA(szBuffer, 0));
        GetTrieValue(g_hPresets, szBuffer[0], iColor);
        IntToString(iColor, SZFA(szBuffer, 1));

        AddMenuItem(hMenu, szBuffer[1], szBuffer[0], ITEMDRAW_DEFAULT);
    }

    CloseHandle(hSnap);
    SetMenuExitBackButton(hMenu, true);
    SetMenuExitButton(hMenu, false);
    DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
}

/**
 * @section Menu Callbacks.
 */
public int Menu_MainHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2) {
    switch (eAction) {
        case MenuAction_Select: {
            if (!iParam2) {
                Menu_SetupPrefix(iParam1);
            } else {
                g_eType[iParam1] = view_as<CCC_ColorType>(iParam2-1);

                int iColor;
                switch (g_eType[iParam1]) {
                    case CCC_ChatColor: iColor = g_iCChat[iParam1];
                    case CCC_NameColor: iColor = g_iCName[iParam1];
                    case CCC_TagColor:  iColor = g_iCPrefix[iParam1];
                }

                if (iColor == -1) {
                    for (int i; i < 3; i++) {
                        g_iSelectedColor[iParam1][i] = 0;
                    }
                } else {
                    Kruzya_DEC2RGB(iColor, g_iSelectedColor[iParam1][0], g_iSelectedColor[iParam1][1], g_iSelectedColor[iParam1][2]);
                }

                Menu_SetupColor(iParam1);
            }
        }

        case MenuAction_Cancel: {
            if (iParam2 == MenuCancel_ExitBack) {
                VIP_SendClientVIPMenu(iParam1);
            }
        }

        case MenuAction_End:    {
            CloseHandle(hMenu);
        }
    }
}

public int Menu_PrefixHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2) {
    switch (eAction) {
        case MenuAction_Cancel: {
            if (iParam2 == MenuCancel_ExitBack) {
                g_bListenChat[iParam1] = false;
                Menu_RenderMain(iParam1);
            }
        }

        case MenuAction_End:    {
            CloseHandle(hMenu);
        }
    }
}

public int Menu_ColorHandler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2) {
    switch (eAction) {
        case MenuAction_Cancel: {
            if (iParam2 == MenuCancel_ExitBack) {
                // VIP_PrintToChatClient(iParam1, "Тополиный пух, #FF0000админ питух!");
                PrintToChat(iParam1, "\x04[VIP] \x01%t", "CCC_Text_AllChangesCancelled");

                for (int i; i < 3; i++) {
                    g_iSelectedColor[iParam1][i] = 0;
                }

                Menu_RenderMain(iParam1);
            }
        }

        case MenuAction_Select: {
            switch (iParam2) {
                // red, green, blue, save, presets, reset
                case 0: Menu_RenderColorizer(iParam1, RED);
                case 1: Menu_RenderColorizer(iParam1, GREEN);
                case 2: Menu_RenderColorizer(iParam1, BLUE);

                case 3: {
                    int iColor = Kruzya_RGB2DEC(g_iSelectedColor[iParam1][0], g_iSelectedColor[iParam1][1], g_iSelectedColor[iParam1][2]);

                    switch (g_eType[iParam1]) {
                        case CCC_ChatColor: g_iCChat[iParam1]   = iColor;
                        case CCC_NameColor: g_iCName[iParam1]   = iColor;
                        case CCC_TagColor:  g_iCPrefix[iParam1] = iColor;
                    }

                    Reload(iParam1);
                    PrintToChat(iParam1, "\x04[VIP] \x01%t", "CCC_Text_AllChangesSaved");
                    Menu_RenderMain(iParam1);
                }

                case 4: {
                    Menu_RenderPresets(iParam1);
                }

                case 5: {
                    switch (g_eType[iParam1]) {
                        case CCC_ChatColor: g_iCChat[iParam1] = -1;
                        case CCC_NameColor: g_iCName[iParam1] = -1;
                        case CCC_TagColor:  g_iCPrefix[iParam1] = -1;
                    }

                    Reload(iParam1);
                    PrintToChat(iParam1, "\x04[VIP] \x01%t", "CCC_Text_ChangesReseted");
                    Menu_SetupColor(iParam1);
                }

                case 6: {
                    char szBuffer[8];
                    FormatEx(SZFS(szBuffer), "%.6x", Kruzya_RGB2DEC(g_iSelectedColor[iParam1][0], g_iSelectedColor[iParam1][1], g_iSelectedColor[iParam1][2]));
                    PrintToChat(iParam1, "\x04[VIP] \x07%s0123456789 ABCDEF", szBuffer);
                    Menu_SetupColor(iParam1);
                }
            }
        }

        case MenuAction_End:    {
            CloseHandle(hMenu);
        }
    }
}

public int Menu_ColorizerHandler(Handle hMenu, MenuAction eAction, int iParam1, int iParam2) {
    switch (eAction) {
        case MenuAction_Cancel: {
            if (iParam2 == MenuCancel_ExitBack)
                Menu_SetupColor(iParam1);
        }

        case MenuAction_Select: {
            char szColor[2];
            GetMenuItem(hMenu, iParam2, SZFS(szColor));

            int iChange = (iParam2 > 2) ? -1 : 1;
            switch (iParam2) {
                // +1, +10, +MAX, -1, -10, -MIN
                case 0, 3:  iChange *= 1;
                case 1, 4:  iChange *= 10;
                case 2, 5:  iChange *= 255;
            }

            int iColorType;
            switch (szColor[0]) {
                case 'R':   iColorType = RED;
                case 'G':   iColorType = GREEN;
                case 'B':   iColorType = BLUE;
            }

            g_iSelectedColor[iParam1][iColorType] += iChange;

            // проверки выхода за пределы
            if (g_iSelectedColor[iParam1][iColorType] > 255) {
                g_iSelectedColor[iParam1][iColorType] = 255;
            }
            if (g_iSelectedColor[iParam1][iColorType] < 0) {
                g_iSelectedColor[iParam1][iColorType] = 0;
            }

            Menu_RenderColorizer(iParam1, iColorType);
        }

        case MenuAction_End:    {
            CloseHandle(hMenu);
        }
    }
}

public int Menu_PresetsHandler(Handle hMenu, MenuAction eAction, int iParam1, int iParam2) {
    switch (eAction) {
        case MenuAction_Cancel: {
            if (iParam2 == MenuCancel_ExitBack) {
                Menu_SetupColor(iParam1);
            }
        }

        case MenuAction_Select: {
            char szBuffer[2][64];
            GetMenuItem(hMenu, iParam2, SZFA(szBuffer, 0), _, SZFA(szBuffer, 1));
            PrintToChat(iParam1, "\x04[VIP] \x01%t", "CCC_Text_PresetInstalled", szBuffer[1]);
            int iColor = StringToInt(szBuffer[0]);

            switch (g_eType[iParam1]) {
                case CCC_ChatColor: g_iCChat[iParam1] = iColor;
                case CCC_NameColor: g_iCName[iParam1] = iColor;
                case CCC_TagColor:  g_iCPrefix[iParam1] = iColor;
            }

            Reload(iParam1);
            Menu_RenderMain(iParam1);
        }

        case MenuAction_End:    {
            CloseHandle(hMenu);
        }
    }
}

/**
 * @section Setup color.
 */
void UpdateAFKTime(int iClient) {
    Kruzya_SetClientIntCookie(iClient, g_hCookies[4], UNIXTIME);
}

void Setup(int iClient) {
    CCC_SetTag(iClient, g_szPrefix[iClient]);

    if (g_iCPrefix[iClient] == -1)
        CCC_ResetColor(iClient, CCC_TagColor);
    else
        CCC_SetColor(iClient, CCC_TagColor, g_iCPrefix[iClient], false);

    if (g_iCChat[iClient] == -1)
        CCC_ResetColor(iClient, CCC_ChatColor);
    else
        CCC_SetColor(iClient, CCC_ChatColor, g_iCChat[iClient], false);

    if (g_iCName[iClient] == -1)
        CCC_ResetColor(iClient, CCC_NameColor);
    else
        CCC_SetColor(iClient, CCC_NameColor, g_iCName[iClient], false);
}

void Reset(int iClient) {
    for (CCC_ColorType eCType; eCType <= CCC_ChatColor; eCType++)
        CCC_ResetColor(iClient, eCType);
    CCC_ResetTag(iClient);
}

void Reload(int iClient) {
    if (!VIP_IsClientFeatureUse(iClient, g_szVIPEnabler))
        return;

    Reset(iClient);
    Setup(iClient);
}

/**
 * @section Config Parser.
 */
public SMCResult OnNewSection(Handle hSMC, const char[] szSection, bool bOptQuotes) {}
public SMCResult OnEndSection(Handle hSMC) {}
public SMCResult OnKeyValues(Handle hSMC, const char[] szKey, const char[] szValue, bool bKeyQuotes, bool bValueQuotes) {
    SetTrieValue(g_hPresets, szKey, Kruzya_HEX2DEC(szValue), true);
}

/**
 * @section Chat Hook.
 */
public Action OnSayHook(int iClient, const char[] szCommand, int iArgC) {
    if (!g_bListenChat[iClient])
        return Plugin_Continue;

    char szBuffer[32];
    if (iArgC == 1) {
        GetCmdArg(1, SZFS(szBuffer)-2);
    } else {
        GetCmdArgString(SZFS(szBuffer)-2);
    }

    g_bListenChat[iClient] = false;
    TrimString(szBuffer);
    if (strcmp(szBuffer, "!cancel") == 0) {
        PrintToChat(iClient, "\x04[VIP] \x01%t", "CCC_Text_ActionCancelled");
    } else {
        PrintToChat(iClient, "\x04[VIP] \x01%t", "CCC_Text_PrefixInstalled");
        int iByte = strcopy(SZFA(g_szPrefix, iClient), szBuffer);
        g_szPrefix[iClient][iByte] = ' ';
        g_szPrefix[iClient][iByte+1] = 0;
    }

    Reload(iClient);
    Menu_RenderMain(iClient);
    return Plugin_Stop;
}