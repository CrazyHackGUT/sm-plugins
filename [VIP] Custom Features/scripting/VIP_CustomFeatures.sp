/**
 * =============================================================================
 * [VIP] Custom Features
 * Custom Items in VIP Menu.
 *
 * File: VIP_CustomFeatures.sp
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

#include <vip_core>

#pragma newdecls required
#pragma semicolon 1

/**
 * @section Constants
 */
#define PLUGIN_DESCRIPTION  "Custom Items in VIP Menu."
#define PLUGIN_VERSION      "1.0"
#define PLUGIN_AUTHOR       "CrazyHackGUT aka Kruzya"
#define PLUGIN_NAME         "[VIP] Custom Features"
#define PLUGIN_URL          "https://kruzefag.ru/"

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

/**
 * @section Global Variables
 */
Handle  g_hFeatures;    /**< All registered features. ArrayList contains StringMaps. */
int     g_iID;

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
 * @section Events
 */
public void OnPluginStart() {
    RegServerCmd("sm_reloadvipci", ReloadCustomItems_Cmd);
    g_hFeatures = CreateArray(4);

    LoadTranslations("vip_modules.phrases");
}

public void OnPluginEnd() {
    VIP_UnloadFeatures();
}

public void OnMapStart() {
    VIP_LoadFeatures();
}

public void OnMapEnd() {
    VIP_UnloadFeatures();
}

public void VIP_OnVIPLoaded() {
    int iLength = GetArraySize(g_hFeatures);
    if (iLength == 0)
        return;

    for (int i; i < iLength; i++) {
        Handle hFeatureInformation = GetArrayCell(g_hFeatures, i);

        char szTemp[64];
        GetTrieString(hFeatureInformation, "Feature", SZFS(szTemp));

        // Register feature, if not exists.
        if (!VIP_IsValidFeature(szTemp)) {
            VIP_FeatureType eFType;
            if (!GetTrieValue(hFeatureInformation, "FeatureType", eFType)) {
                eFType = SELECTABLE;
            }

            ItemSelectCallback fCallback;
            switch (eFType) {
                case TOGGLABLE:     fCallback = VIP_OnItemPressed;
                case SELECTABLE:    fCallback = VIP_OnItemTouched;
            }
            VIP_RegisterFeature(szTemp, BOOL, eFType, fCallback, VIP_OnRenderTextItem);
        } else {
            LogError("Feature %s already registered! Skipping...", szTemp);
        }
    }
}

public void OnRebuildAdminCache(AdminCachePart ePart) {
    switch (ePart) {
        case AdminCache_Overrides:  VIP_BuildOverrides();
        case AdminCache_Groups:     VIP_BuildGroups();
        case AdminCache_Admins:     VIP_BuildAdmins();
    }
}

public void VIP_OnClientLoaded(int iClient, bool bIsVIP) {
    if (!bIsVIP || GetArraySize(g_hFeatures) == 0)
        return;

    VIP_BuildAdmin(iClient);
}

/**
 * @section Commands
 */
public Action ReloadCustomItems_Cmd(int iArgc) {
    VIP_UnloadFeatures();
    VIP_LoadFeatures();

    return Plugin_Handled;
}

/**
 * @section Features Loader
 */
void VIP_LoadFeatures() {
    static Handle hSMC = nullptr;
    static char szPath[PMP];

    if (!hSMC) {
        hSMC = SMC_CreateParser();
        SMC_SetReaders(hSMC, OnNewSection, OnKeyValue, OnEndSection);
    }

    if (IsEmptyString(szPath)) {
        BuildPath(Path_SM, SZFS(szPath), "data/vip/cfg/custom_items.cfg");
    }

    if (!FileExists(szPath)) {
        SetFailState("Couldn't find configuration file: %s", szPath);
    }

    g_iID = -1;
    SMCError eError = SMC_ParseFile(hSMC, szPath);
    if (eError != SMCError_Okay) {
        SetFailState("Couldn't parse configuration file: %s. Error code %d.", szPath, eError);
    }

    if (VIP_IsVIPLoaded()) {
        VIP_OnVIPLoaded();
    }

    VIP_BuildOverrides();
    VIP_BuildGroups();
    VIP_BuildAdmins();
}

void VIP_UnloadFeatures() {
    int iLength = GetArraySize(g_hFeatures);
    if (iLength == 0)
        return;

    bool bReloadHash = false;

    for (int i; i < iLength; i++) {
        Handle hFeatureInformation = GetArrayCell(g_hFeatures, i);

        char szFeature[64];
        char szTemp[64];
        GetTrieString(hFeatureInformation, "Feature", SZFS(szFeature));

        // Unregister feature, if exists.
        VIP_IsValidFeature(szFeature) && VIP_UnregisterFeature(szFeature);

        // Delete override and admin group, if exists.
        bool bOverride;
        if (GetTrieValue(hFeatureInformation, "Override", bOverride) && bOverride) {
            GetTrieString(hFeatureInformation, "Command", SZFS(szTemp));
            UnsetCommandOverride(szTemp, Override_Command);

            if (!bReloadHash) {
                FormatEx(SZFS(szTemp), "%s_VIPFeature", szFeature);
                GroupId eGID = FindAdmGroup(szTemp);
                if (eGID != INVALID_GROUP_ID) {
                    bReloadHash = true;
                }
            }
        }

        // Close Handle.
        delete hFeatureInformation;
    }

    // Reload group admin hash, if need.
    if (bReloadHash) {
        DumpAdminCache(AdminCache_Groups, true);
    }

    // Clear array.
    ClearArray(g_hFeatures);
}

/**
 * @section Touch/Press/Renderer callbacks.
 */
public Action VIP_OnItemPressed(int iClient, const char[] szFeatureName, VIP_ToggleState eOldStatus, VIP_ToggleState &eNewStatus) {
    VIP_ExecuteFeature(iClient, szFeatureName);
    return Plugin_Handled;
}

public bool VIP_OnItemTouched(int iClient, const char[] szFeatureName) {
    VIP_ExecuteFeature(iClient, szFeatureName);
    return false;
}

public bool VIP_OnRenderTextItem(int iClient, const char[] szFeatureName, char[] szDisplay, int iMaxLength) {
    FormatEx(szDisplay, iMaxLength, "%T", szFeatureName, iClient);
    return true;
}

/**
 * @section Executor
 */
void VIP_ExecuteFeature(int iClient, const char[] szFeatureName) {
    int iLength = GetArraySize(g_hFeatures);
    if (iLength == 0)
        return;

    char szFeature[64];
    for (int i; i < iLength; i++) {
        Handle hFeatureInformation = GetArrayCell(g_hFeatures, i);
        GetTrieString(hFeatureInformation, "Feature", SZFS(szFeature));

        if (strcmp(szFeature, szFeatureName, true) == 0) {
            char szCommand[256];
            GetTrieString(hFeatureInformation, "Command", SZFS(szCommand));

            FakeClientCommand(iClient, "%s", szCommand);
            return;
        }
    }

    LogError("Couldn't execute VIP feature %s for client %L", szFeatureName, iClient);
}

/**
 * @section AdminCache Workers.
 */
void VIP_BuildOverrides()   {
    int iLength = GetArraySize(g_hFeatures);
    if (iLength == 0)
        return;

    for (int i; i < iLength; i++) {
        Handle hFeatureInformation = GetArrayCell(g_hFeatures, i);

        bool bOverride;
        GetTrieValue(hFeatureInformation, "Override", bOverride);

        if (bOverride) {
            char szCommand[2][256];
            GetTrieString(hFeatureInformation, "Command", SZFA(szCommand, 0));
            ExplodeString(szCommand[0], " ", szCommand, sizeof(szCommand), sizeof(szCommand[]), false);

            AddCommandOverride(szCommand[0], Override_Command, ADMFLAG_GENERIC);
        }
    }
}

void VIP_BuildGroups()      {
    int iLength = GetArraySize(g_hFeatures);
    if (iLength == 0)
        return;

    for (int i; i < iLength; i++) {
        Handle hFeatureInformation = GetArrayCell(g_hFeatures, i);

        bool bOverride;
        GetTrieValue(hFeatureInformation, "Override", bOverride);

        if (bOverride) {
            char szCommand[2][256];
            GetTrieString(hFeatureInformation, "Command", SZFA(szCommand, 0));
            ExplodeString(szCommand[0], " ", szCommand, sizeof(szCommand), sizeof(szCommand[]), false);

            char szFeature[80];
            GetTrieString(hFeatureInformation, "Feature", SZFS(szFeature));
            Format(SZFS(szFeature), "%s_VIPFeature", szFeature);

            GroupId eGID = CreateAdmGroup(szFeature);
            if (eGID == INVALID_GROUP_ID) {
                eGID = FindAdmGroup(szFeature);
            }

            AddAdmGroupCmdOverride(eGID, szCommand[0], Override_Command, Command_Allow);
        }
    }
}

void VIP_BuildAdmins()      {
    int iLength = GetArraySize(g_hFeatures);
    int iOnlineClients = GetClientCount(true);
    if (iOnlineClients == 0 || iLength == 0)
        return;

    for (int i; ++i <= MaxClients;) {
        if (!IsClientInGame(i) || IsFakeClient(i) || !VIP_IsClientVIP(i)) {
            continue;
        }

        VIP_BuildAdmin(i);
    }
}

void VIP_BuildAdmin(int iClient) {
    int iLength = GetArraySize(g_hFeatures);
    if (iLength == 0)
        return;

    AdminId eAID = GetUserAdmin(iClient);
    if (eAID == INVALID_ADMIN_ID) {
        eAID = CreateAdmin();
        SetUserAdmin(iClient, eAID);
    }

    for (int i; i < iLength; i++) {
        Handle hFeatureInformation = GetArrayCell(g_hFeatures, i);

        char szFeature[80];
        GetTrieString(hFeatureInformation, "Feature", SZFS(szFeature));
        if (VIP_IsClientFeatureUse(iClient, szFeature)) {
            Format(SZFS(szFeature), "%s_VIPFeature", szFeature);

            GroupId eGID = FindAdmGroup(szFeature);
            if (eGID == INVALID_GROUP_ID) {
                // SetFailState("Something wrong... Report this incident to developer. Error code: 2");
                continue;
            }

            AdminInheritGroup(eAID, eGID);
        }
    }
}

/**
 * @section Config Parsers.
 */
public SMCResult OnNewSection(Handle hSMC, const char[] szSectionName, bool bOptQuotes) {
    if (strcmp(szSectionName, "CustomFeatures") == 0)
        return SMCParse_Continue;

    g_iID = PushArrayCell(g_hFeatures, CreateTrie());
    SetTrieString(GetArrayCell(g_hFeatures, g_iID), "Feature", szSectionName);

    return SMCParse_Continue;
}

public SMCResult OnKeyValue(Handle hSMC, const char[] szKey, const char[] szValue, bool bKeyQuotes, bool bValueQuotes) {
    if (g_iID == -1) {
        SetFailState("Invalid Config");
    }

    /**
     * Trigger.
     */
    if (strcmp(szKey, "Trigger") == 0) {
        SetTrieString(GetArrayCell(g_hFeatures, g_iID), "Command", szValue);
        return SMCParse_Continue;
    }

    /**
     * Trigger Type.
     */
    if (strcmp(szKey, "TriggerType") == 0) {
        VIP_FeatureType eFType;

        if (strcmp(szValue, "select") == 0) {
            eFType = SELECTABLE;
        } else if (strcmp(szValue, "toggle") == 0) {
            eFType = TOGGLABLE;
        } else {
            SetFailState("Invalid Config");
        }

        SetTrieValue(GetArrayCell(g_hFeatures, g_iID), "FeatureType", eFType);
        return SMCParse_Continue;
    }

    /**
     * Override.
     */
    if (strcmp(szKey, "Override") == 0) {
        SetTrieValue(GetArrayCell(g_hFeatures, g_iID), "Override", (szValue[0] != '0'));
        return SMCParse_Continue;
    }

    /**
     * Other unknown stuff.
     */
    SetFailState("Invalid Config");
    return SMCParse_HaltFail;
}

public SMCResult OnEndSection(Handle hSMC) {}