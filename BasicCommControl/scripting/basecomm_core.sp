/**
 * =============================================================================
 * [API] Basic Comm Control
 * Provides API methods of controlling communication.
 *
 * File: basecomm_core.sp
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

#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

/**
 * @section Plugin information.
 */
public Plugin myinfo = {
    description = "Provides API methods of controlling communication.",
    version     = "1.0 (compiled for " ... SOURCEMOD_VERSION ... ")",
    author      = "AlliedModders LLC, CrazyHackGUT aka Kruzya",
    name        = "[API] Basic Comm Control"
};

#define H2I(%0) view_as<int>(%0)

/**
 * @section CommType Enumeration.
 */
enum CommType {
    Voice,
    Chat
}

/**
 * @section Global Variables.
 */
bool    g_bState[MAXPLAYERS+1][CommType];   // Is the player muted/gagged?
Handle  g_hForwards[CommType];              // Holds the handles for Global Forwards

/**
 * @section Generic SourceMod events.
 */
public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] szError, int iErrMax) {
    /**
     * @section Natives: Getters.
     */
    CreateNative("BaseComm_IsClientGagged", Native_IsClientGagged);
    CreateNative("BaseComm_IsClientMuted",  Native_IsClientMuted);

    /**
     * @section Natives: Setters.
     */
    CreateNative("BaseComm_SetClientGag",   Native_SetClientGag);
    CreateNative("BaseComm_SetClientMute",  Native_SetClientMute);

    /**
     * @section Forwards.
     */
    g_hForwards[Voice]  = H2I(CreateGlobalForward("BaseComm_OnClientMute",      ET_Ignore, Param_Cell, Param_Cell));
    g_hForwards[Chat]   = H2I(CreateGlobalForward("BaseComm_OnClientGagged",    ET_Ignore, Param_Cell, Param_Cell));

    /**
     * @section Library
     */
    RegPluginLibrary("basecomm");

    return APLRes_Success;
}

public bool OnClientConnect(int iClient, char[] szRejectMessage, int iLength) {
    g_bState[iClient][Voice]    = false;
    g_bState[iClient][Chat]     = false;

    return true;
}

public Action OnClientSayCommand(int iClient, const char[] szCommand, const char[] szArgs) {
    return (iClient && g_bState[iClient][Chat]) ? Plugin_Handled : Plugin_Continue;
}

/**
 * @section UTILs
 */
bool UTIL_PerformAction(CommType eType, int iTarget, bool bDisabledComm, bool bFireForward = true) {
    if (g_bState[iTarget][eType] == bDisabledComm) {
        return false;
    }

    switch (eType)  {
        case Voice: {
            // Change voice state and local boolean.
            SetClientListeningFlags(
                iTarget,
                bDisabledComm ? VOICE_MUTED : VOICE_NORMAL
            );

            g_bState[iTarget][Voice]    = bDisabledComm;
        }

        case Chat:  {
            // Just change local boolean.
            g_bState[iTarget][Chat]     = bDisabledComm;
        }
    }

    // Fire forward, if this need.
    if (bFireForward) {
        UTIL_FireForward(eType, iTarget);
    }

    return true;
}

void UTIL_FireForward(CommType eType, int iClient) {
    Call_StartForward(g_hForwards[eType]);
    Call_PushCell(iClient);
    Call_PushCell(g_bState[iClient][eType]);
    Call_Finish();
}

int UTIL_ValidateNativeClient(int iParamNum) {
    int iClient = GetNativeCell(iParamNum);
    if (iClient < 1 || iClient > MaxClients) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
    }

    if (!IsClientInGame(iClient)) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", iClient);
    }

    return iClient;
}

/**
 * @section Natives
 */
public int Native_IsClientGagged(Handle hPlugin, int iNumParams) {
    return g_bState
        [UTIL_ValidateNativeClient(1)]
        [Chat];
}

public int Native_IsClientMuted(Handle hPlugin, int iNumParams) {
    return g_bState
        [UTIL_ValidateNativeClient(1)]
        [Voice];
}

public int Native_SetClientGag(Handle hPlugin, int iNumParams) {
    return UTIL_PerformAction(
        Chat,
        UTIL_ValidateNativeClient(1),
        GetNativeCell(2)
    );
}

public int Native_SetClientMute(Handle hPlugin, int iNumParams) {
    return UTIL_PerformAction(
        Voice,
        UTIL_ValidateNativeClient(1),
        GetNativeCell(2)
    );
}