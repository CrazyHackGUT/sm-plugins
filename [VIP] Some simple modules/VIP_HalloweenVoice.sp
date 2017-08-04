/**
 * =============================================================================
 * [VIP] Halloween Distorted Voice
 * The effect of the distorted voice of the mercenary Team Fortress 2
 * from Halloween.
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
#define PLUGIN_DESCRIPTION  "The effect of the distorted voice of the mercenary Team Fortress 2 from Halloween."
#define PLUGIN_VERSION      "1.0"
#define PLUGIN_AUTHOR       "CrazyHackGUT aka Kruzya"
#define PLUGIN_NAME         "[VIP] Halloween Distorted Voice"
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

stock const char g_szVIP[] = "TF2_DistortedHalloweenVoice";

/**
 * @section Global Variables
 */
Handle  g_hCookie;
bool    g_bEnabled[MPL+1];
bool    g_bChecked[MPL+1];

/**
 * @section SourceMod events.
 */
public void OnPluginStart() {
    g_hCookie = RegClientCookie(g_szVIP, "[TF2] Halloween Distorted Voice - Toggler", CookieAccess_Private);

    if (VIP_IsVIPLoaded()) {
        VIP_OnVIPLoaded();
    }

    for (int i; ++i <= MaxClients;) {
        if (!IsClientInGame(i) || IsFakeClient(i) || !AreClientCookiesCached(i))
            continue;

        OnClientCookiesCached(i);
    }
}

public void OnPluginEnd() {
    if (VIP_IsVIPLoaded()) {
        VIP_IsValidFeature(g_szVIP) && VIP_UnregisterFeature(g_szVIP);
    }

    for (int i; ++i <= MaxClients;) {
        if (!IsClientInGame(i) || IsFakeClient(i) || !AreClientCookiesCached(i))
            continue;

        OnClientDisconnect(i);
        ToggleHalloweenVoice(i, g_bEnabled[i]);
    }
}

public void OnClientCookiesCached(int iClient) {
    g_bEnabled[iClient] = Kruzya_GetClientIntCookie(iClient, g_hCookie, 0) != 0;

    if (g_bChecked[iClient] && VIP_IsClientVIP(iClient) && VIP_GetClientFeatureStatus(iClient, g_szVIP) != NO_ACCESS) {
        VIP_SetClientFeatureStatus(iClient, g_szVIP, g_bEnabled[iClient] ? ENABLED : DISABLED);
    }
}

public void OnClientDisconnect(int iClient) {
    if (!AreClientCookiesCached(iClient) || !VIP_IsClientVIP(iClient))
        return;

    Kruzya_SetClientIntCookie(iClient, g_hCookie, g_bEnabled[iClient] ? 1 : 0);
    g_bChecked[iClient] = false;
}

/**
 * @section VIP events.
 */
public void VIP_OnVIPLoaded() {
    if (VIP_IsValidFeature(g_szVIP)) {
        SetFailState("Feature already registered (%s)", g_szVIP);
    }

    VIP_RegisterFeature(g_szVIP, BOOL, TOGGLABLE, VIP_OnToggledItem);
}

public void VIP_OnClientLoaded(int iClient, bool bIsVIP) {
    g_bChecked[iClient] = true;
    if (!AreClientCookiesCached(iClient))
        return;

    if (AreClientCookiesCached(iClient) && VIP_IsClientVIP(iClient) && VIP_GetClientFeatureStatus(iClient, g_szVIP) != NO_ACCESS) {
        VIP_SetClientFeatureStatus(iClient, g_szVIP, g_bEnabled[iClient] ? ENABLED : DISABLED);
    }

    ToggleHalloweenVoice(iClient, g_bEnabled[iClient]);
}

public Action VIP_OnToggledItem(int iClient, const char[] szFeatureName, VIP_ToggleState eOldState, VIP_ToggleState &eNewState) {
    g_bEnabled[iClient] = (eNewState == ENABLED);
    ToggleHalloweenVoice(iClient, g_bEnabled[iClient]);

    return Plugin_Continue;
}

/**
 * @section Toggler
 */
void ToggleHalloweenVoice(int iClient, bool bNewState) {
    if (!g_bChecked[iClient])
        return;

    float fValue = bNewState ? 1.0 : 0.0;
    TF2Attrib_SetByDefIndex(iClient, 1006, fValue);
}