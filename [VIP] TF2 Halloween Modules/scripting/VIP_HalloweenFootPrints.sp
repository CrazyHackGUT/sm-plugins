/**
 * =============================================================================
 * [VIP] Halloween Footprints
 * The footprints of the mercenary Team Fortress 2 from Halloween.
 *
 * File: VIP_HalloweenVoice.sp
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

#include <tf2attributes>
#include <clientprefs>
#include <vip_core>
#include <kruzya>

#pragma newdecls required
#pragma semicolon 1

/**
 * @section Constants
 */
#define PLUGIN_DESCRIPTION  "The footprints of the mercenary Team Fortress 2 from Halloween."
#define PLUGIN_VERSION      "1.1"
#define PLUGIN_AUTHOR       "CrazyHackGUT aka Kruzya"
#define PLUGIN_NAME         "[VIP] Halloween Footprints"
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

stock const char g_szVIP[] = "TF2_HalloweenFootprints";

stock const char g_szFootsteps[][] = {
    "TF2_NoEffect",         "TF2_TeamBased",    "TF2_Blue",                 "TF2_LightBlue",    "TF2_Yellow",
    "TF2_CorruptedGreen",   "TF2_DarkGreen",    "TF2_Lime",                 "TF2_Brown",
    "TF2_OakTreeBrown",     "TF2_Flames",       "TF2_Cream",                "TF2_Pink",         "TF2_SatansBlue",
    "TF2_Purple",           "TF2_numbers",      "TF2_GhostInTheMachine",    "TF2_HolyFlame"
};

stock const int g_iFootstepsIDs[] = {
    0,          1,          7777,       933333,     8421376,
    4552221,    3100495,    51234123,   5322826,
    8355220,    13595446,   8208497,    41234123,   300000,
    2,          3,          83552,      9335510
};

/**
 * @section Global Variables
 */
Handle  g_hCookie;
int     g_iFootprint[MPL+1];

/**
 * @section SourceMod events.
 */
public void OnPluginStart() {
    g_hCookie = RegClientCookie(g_szVIP, "[TF2] Halloween Footprints", CookieAccess_Private);

    if (VIP_IsVIPLoaded()) {
        VIP_OnVIPLoaded();
        
        for (int i; ++i <= MaxClients;) {
            if (!IsClientInGame(i) || IsFakeClient(i) || !AreClientCookiesCached(i))
                continue;
            
            VIP_OnClientLoaded(i, VIP_IsClientVIP(i));
        }
    }

    LoadTranslations("vip_footprints.phrases");
}

public void OnPluginEnd() {
    if (VIP_IsVIPLoaded()) {
        VIP_IsValidFeature(g_szVIP) && VIP_UnregisterFeature(g_szVIP);
    }

    for (int i; ++i <= MaxClients;) {
        if (!IsClientInGame(i) || IsFakeClient(i) || !AreClientCookiesCached(i))
            continue;

        OnClientDisconnect(i);
        SetupFootprint(i, g_iFootprint[i]);
    }
}

public void OnClientCookiesCached(int iClient) {
    g_iFootprint[iClient] = Kruzya_GetClientIntCookie(iClient, g_hCookie, 0);
}

public void OnClientDisconnect(int iClient) {
    if (!AreClientCookiesCached(iClient) || !VIP_IsClientVIP(iClient))
        return;

    Kruzya_SetClientIntCookie(iClient, g_hCookie, g_iFootprint[iClient]);
}

/**
 * @section VIP events.
 */
public void VIP_OnVIPLoaded() {
    if (VIP_IsValidFeature(g_szVIP)) {
        SetFailState("Feature already registered (%s)", g_szVIP);
    }

    VIP_RegisterFeature(g_szVIP, BOOL, SELECTABLE, VIP_OnTouchedItem);
}

public void VIP_OnClientLoaded(int iClient, bool bIsVIP) {
    SetupFootprint(iClient, g_iFootprint[iClient]);
}

public bool VIP_OnTouchedItem(int iClient, const char[] szFeatureName) {
    RenderMenu(iClient);
    return false;
}

/**
 * @section Editor
 */
void SetupFootprint(int iClient, int iFootprintID) {
    float fValue = iFootprintID * 1.0;
    TF2Attrib_SetByDefIndex(iClient, 1005, fValue);
}

/**
 * @section Menu
 */
void RenderMenu(int iClient) {
    Handle hMenu = CreateMenu(MenuCallback);
    SetMenuTitle(hMenu, "%T\n ", "MenuTitle", iClient);

    char szEffectName[72];
    for (int i; i < sizeof(g_iFootstepsIDs); i++) {
        bool bActive = (g_iFootprint[iClient] == g_iFootstepsIDs[i]);
        FormatEx(SZFS(szEffectName), "%T [%s]", g_szFootsteps[i], iClient, bActive ? "X" : " ");
        AddMenuItem(hMenu, nullstr, szEffectName, bActive ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    }

    SetMenuExitBackButton(hMenu, true);
    SetMenuExitButton(hMenu, false);
    DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
}

public int MenuCallback(Handle hMenu, MenuAction eAction, int iParam1, int iParam2) {
    switch (eAction) {
        case MenuAction_Cancel: {
            if (iParam2 == MenuCancel_ExitBack) {
                VIP_SendClientVIPMenu(iParam1);
            }
        }

        case MenuAction_Select: {
            g_iFootprint[iParam1] = g_iFootstepsIDs[iParam2];
            SetupFootprint(iParam1, g_iFootprint[iParam1]);
            RenderMenu(iParam1);
        }

        case MenuAction_End:    {
            CloseHandle(hMenu);
        }
    }
}