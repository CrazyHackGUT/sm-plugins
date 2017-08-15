/**
 * =============================================================================
 * [Keys] LK 1mpulse
 * Adds a new type of keys for LK from Impulse.
 *
 * File: Keys_1mpulseLK.sp
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

#include <keys_core>
#include <lk>

#pragma newdecls required
#pragma semicolon 1

static const char g_szKeyName[] = "lk_1mpulse";

public Plugin myinfo = {
    version = "1.0",
    author  = "CrazyHackGUT aka Kruzya",
    name    = "[Keys] LK 1mpulse",
    url     = "https://kruzefag.ru/"
};

public void OnPluginStart() {
    if (Keys_IsCoreStarted()) {
        Keys_OnCoreStarted();
    }

    LoadTranslations("lk_1mpulse_keys.phrases");
}

public int Keys_OnCoreStarted() {
    Keys_RegKey(g_szKeyName, OnKeyParamsValidate, OnKeyUse, OnKeyPrint);
}

/**
 * @section [CORE] Keys; Callbacks.
 */
public bool OnKeyParamsValidate(int iClient, const char[] szKeyType, Handle hParamsArray, char[] szError, int iErrorLength) {
    if (GetArraySize(hParamsArray) != 1) {
        FormatEx(szError, iErrorLength, "%T", "InvalidArgumentCount", iClient);
        return false;
    }

    char szBuffer[16];
    GetArrayString(hParamsArray, 0, szBuffer, sizeof(szBuffer));
    if (StringToInt(szBuffer) < 1) {
        FormatEx(szError, iErrorLength, "%T", "InvalidArgument", iClient);
        return false;
    }

    return true;
}

public bool OnKeyUse(int iClient, const char[] szKeyType, Handle hParamsArray, char[] szError, int iErrorLength) {
    char szBuffer[16];
    GetArrayString(hParamsArray, 0, szBuffer, sizeof(szBuffer));

    int iSumm = StringToInt(szBuffer);
    LK_AddClientCash(iClient, iSumm);

    return true;
}

public int OnKeyPrint(int iClient, const char[] szKeyType, Handle hParamsArray, char[] szBuffer, int iBufferLength) {
    GetArrayString(hParamsArray, 0, szBuffer, iBufferLength);
    Format(szBuffer, iBufferLength, "%T", "KeyPrint", iClient, szBuffer);
}