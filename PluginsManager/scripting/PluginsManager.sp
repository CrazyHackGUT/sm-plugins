#include <sourcemod>
#include <core>
#include <console>

// System defines
#define PLUGIN_VERSION      "1.1"
#define SGT(%0)             SetGlobalTransTarget(%0)

// User settings
#define ACCESSFLAG          ADMFLAG_RCON

#pragma newdecls required

public Plugin myinfo = {
    name = "Plugins Manager",
    version = PLUGIN_VERSION,
    author = "CrazyHackGUT aka Kruzya",
    description = "Provides simple interface to manage plugins",
    url = "http://crazyhackgut.ru/"
};

public void OnPluginStart() {
    RegAdminCmd("sm_plugins", PluginsCmd, ACCESSFLAG);
    LoadTranslations("core.phrases");
    // LoadTranslations("pluginsmanager.phrases");
}

public Action PluginsCmd(int client, int args) {
    RenderPluginList(client);
    return Plugin_Handled;
}

/* Render functions */
void RenderPluginList(int client) {
    Menu menu = new Menu(PluginList_Hndl);
    // SGT(client);
    // menu.SetTitle("%t - %t", "PluginsManager_Listing");
    menu.SetTitle("Список плагинов\n ");
    
    char plName[150];
    char plVersion[30];
    char PluginLine[200];
    char plFile[PLATFORM_MAX_PATH];
    
    int iPluginNum = 1;
    
    ArrayList hLoadedPlugins = new ArrayList(ByteCountToCells(512));
    
    /* Find loaded plugins */
    Handle PluginsIterator = GetPluginIterator();
    while (MorePlugins(PluginsIterator)) {
        Handle PluginHndl = ReadPlugin(PluginsIterator);
        if (!GetPluginInfo(PluginHndl, PlInfo_Name, plName, sizeof(plName)))
            GetPluginFilename(PluginHndl, plName, sizeof(plName));
        
        if (!GetPluginInfo(PluginHndl, PlInfo_Version, plVersion, sizeof(plVersion)))
            plVersion[0] = 0;
        else
            Format(plVersion, sizeof(plVersion), " (v.%s)", plVersion);
        FormatEx(PluginLine, sizeof(PluginLine), "%03d. %s%s", iPluginNum, plName, plVersion);
        menu.AddItem(NULL_STRING, PluginLine);
        
        iPluginNum++;
        
        /* Write plugin to array */
        GetPluginFilename(PluginHndl, plFile, sizeof(plFile));
        
        // Scratch for Windows servers.
        ReplaceString(plFile, sizeof(plFile), "\\", "/");
        
        hLoadedPlugins.PushString(plFile);
        
        delete PluginHndl;
    }
    
    /* Find unloaded plugins */
    menu.AddItem(NULL_STRING, NULL_STRING, ITEMDRAW_SPACER);
    AddUnloadedPluginsToMenu(menu, hLoadedPlugins, "");
    
    menu.Display(client, 0);
    
    delete hLoadedPlugins;
    delete PluginsIterator;
}

void AddUnloadedPluginsToMenu(Menu hMenu, ArrayList hPlugins, char[] szDir) {
    char szFullPath[PLATFORM_MAX_PATH];
    char szParentPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, szParentPath, sizeof(szParentPath), "plugins");
    FormatEx(szFullPath, sizeof(szFullPath), "%s%s", szParentPath, szDir);
    
    if (!DirExists(szFullPath))
        return;
    
    DirectoryListing hOpenedDir = OpenDirectory(szFullPath);
    
    char szReadedObject[PLATFORM_MAX_PATH];
    char szCurrentEntry[PLATFORM_MAX_PATH];
    char szTemp[72];
    FileType oFT;
    
    // SGT(client);
    while (hOpenedDir.GetNext(szReadedObject, sizeof(szReadedObject), oFT)) {
        if (StrEqual(szReadedObject, ".") || StrEqual(szReadedObject, "..") || StrEqual(szReadedObject, "disabled"))
            continue;
        
        FormatEx(szCurrentEntry, sizeof(szCurrentEntry), "%s/%s", szDir, szReadedObject);
        MoveChars(szCurrentEntry, sizeof(szCurrentEntry), 1);
        
        if (oFT == FileType_File) {
            if (StrContains(szReadedObject, ".smx", false) == -1 || hPlugins.FindString(szCurrentEntry) != -1)
                continue;
            
            strcopy(szTemp, sizeof(szTemp), szCurrentEntry);
            // FormatEx(szTemp, sizeof(szTemp), "%t%s", "pluginsmanager_unloaded", szTemp);
            Format(szTemp, sizeof(szTemp), "[Выгружен] %s", szTemp);
            hMenu.AddItem(szCurrentEntry, szTemp);
        } else if (oFT == FileType_Directory) {
            Format(szCurrentEntry, sizeof(szCurrentEntry), "%s/%s", szDir, szReadedObject);
            AddUnloadedPluginsToMenu(hMenu, hPlugins, szCurrentEntry); // RECURSION!!!
        }
    }
    
    delete hOpenedDir;
}

void RenderPluginInformation(int client, int PluginNum) {
    char menuline[256];
    char Temp[256];

    Handle PluginHndl = FindPluginByNumber(PluginNum);
    if (PluginHndl == null) {
        PrintToChat(client, "[SM] Плагин под номером #%i не найден.", PluginNum);
        return;
    }
    
    Menu menu = new Menu(PluginInfo_Hndl);
    menu.Pagination = MENU_NO_PAGINATION;
    menu.SetTitle("Информация о плагине\n ");
    
    /* Plugin name */
    if (!GetPluginInfo(PluginHndl, PlInfo_Name, Temp, sizeof(Temp)))
        strcopy(Temp, sizeof(Temp), "Неизвестно");
    FormatEx(menuline, sizeof(menuline), "Имя: %s", Temp);
    menu.AddItem("null", menuline, ITEMDRAW_DISABLED);
    
    /* Plugin version */
    if (!GetPluginInfo(PluginHndl, PlInfo_Version, Temp, sizeof(Temp)))
        strcopy(Temp, sizeof(Temp), "1.0");
    FormatEx(menuline, sizeof(menuline), "Версия: %s", Temp);
    menu.AddItem("null", menuline, ITEMDRAW_DISABLED);
    
    /* Plugin author */
    if (!GetPluginInfo(PluginHndl, PlInfo_Author, Temp, sizeof(Temp)))
        strcopy(Temp, sizeof(Temp), "Аноним");
    FormatEx(menuline, sizeof(menuline), "Автор: %s", Temp);
    menu.AddItem("null", menuline, ITEMDRAW_DISABLED);
    
    /* Plugin description (optionally) */
    if (GetPluginInfo(PluginHndl, PlInfo_Description, Temp, sizeof(Temp))) {
        FormatEx(menuline, sizeof(menuline), "Описание: %s", Temp);
        menu.AddItem("null", menuline, ITEMDRAW_DISABLED);
    }
    
    /* Plugin URL (optionally) */
    if (GetPluginInfo(PluginHndl, PlInfo_URL, Temp, sizeof(Temp))) {
        FormatEx(menuline, sizeof(menuline), "Адрес в Интернете: %s", Temp);
        menu.AddItem("null", menuline, ITEMDRAW_DISABLED);
    }
    
    /* Plugin file */
    GetPluginFilename(PluginHndl, Temp, sizeof(Temp));
    FormatEx(menuline, sizeof(menuline), "Файл: %s", Temp);
    menu.AddItem("null", menuline, ITEMDRAW_DISABLED);
    
    /* Plugin status */
    switch (GetPluginStatus(PluginHndl)) {
        case Plugin_Running:            strcopy(Temp, sizeof(Temp), "Работает");
        case Plugin_Paused:            strcopy(Temp, sizeof(Temp), "Приостановлен");
        case Plugin_Error:                    strcopy(Temp, sizeof(Temp), "Работает, но имеется ошибка");
        case Plugin_Loaded:                strcopy(Temp, sizeof(Temp), "Готов к запуску");
        case Plugin_Failed:                strcopy(Temp, sizeof(Temp), "Работает");
        case Plugin_Created:            strcopy(Temp, sizeof(Temp), "Запускается...");
        case Plugin_Uncompiled:    strcopy(Temp, sizeof(Temp), "Не скомпилирован"); // ???
        case Plugin_BadLoad:            strcopy(Temp, sizeof(Temp), "Не удалось загрузить");
    }
    FormatEx(menuline, sizeof(menuline), "Состояние: %s", Temp);
    menu.AddItem("null", menuline, ITEMDRAW_DISABLED);
    
    menu.AddItem("null", " ", ITEMDRAW_SPACER);
    
    FormatEx(Temp, sizeof(Temp), "manage %i", PluginNum);
    menu.AddItem(Temp, "Управление плагином");
    menu.AddItem("close", "Закрыть");
    
    menu.Display(client, 0);
    delete PluginHndl;
}

void RenderPluginManagement(int client, int PluginNum) {
    Handle PluginHndl = FindPluginByNumber(PluginNum);
    if (!PluginHndl) {
        PrintToChat(client, "[SM] Плагин под номером #%i не найден.", PluginNum);
        return;
    }
    
    char PluginName[150];
    if (!GetPluginInfo(PluginHndl, PlInfo_Name, PluginName, sizeof(PluginName))) {
        GetPluginFilename(PluginHndl, PluginName, sizeof(PluginName));
    }
    
    Menu menu = new Menu(PluginManage_Hndl);
    menu.SetTitle("Управление плагином %s", PluginName);
    
    char MenuItemInfo[10];
    
    /* Unload */
    FormatEx(MenuItemInfo, sizeof(MenuItemInfo), "u%i", PluginNum);
    menu.AddItem(MenuItemInfo, "Выгрузить");
    
    /* Reload */
    FormatEx(MenuItemInfo, sizeof(MenuItemInfo), "r%i", PluginNum);
    menu.AddItem(MenuItemInfo, "Перезагрузить");
    
    /* Display */
    menu.Display(client, 0);
}

void RenderPluginLoader(int client, char[] szPluginFile) {
    char szPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, szPath, sizeof(szPath), "plugins/%s", szPluginFile);
    if (!FileExists(szPath)) {
        // PrintToChat(client, "[SM] %t", "pluginsmanager_filenotfound", szPluginFile);
        PrintToChat(client, "[SM] Файл плагина %s не найден.", szPluginFile);
        return;
    }
    
    Menu hMenu = new Menu(PluginLoader_Hndl);
    // SGT(client);
    // hMenu.SetTitle("%t\n ", "pluginsmanager_loaderquestion", szPluginFile);
    hMenu.SetTitle("Вы действительно желаете загрузить плагин %s в память сервера?\n ", szPluginFile);
    
    // char szBuffer[20];
    // FormatEx(szBuffer, sizeof(szBuffer), "%t", "pluginsmanager_loader_no");
    // hMenu.AddItem(NULL_STRING, szBuffer);
    // FormatEx(szBuffer, sizeof(szBuffer), "%t", "pluginsmanager_loader_yes");
    // hMenu.AddItem(szPluginFile, szBuffer);
    hMenu.AddItem(NULL_STRING, "Нет");
    hMenu.AddItem(szPluginFile, "Да");
    
    hMenu.Display(client, 0);
}

/* Handlers */
public int PluginLoader_Hndl(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select && param2 == 1) {
        char szBuffer[PLATFORM_MAX_PATH];
        menu.GetItem(1, szBuffer, sizeof(szBuffer));
        ServerCommand("sm plugins load %s", szBuffer);
        
        PrintToChat(param1, "[SM] Плагин %s загружен в память сервера.", szBuffer);
    }
}

public int PluginList_Hndl(Menu menu, MenuAction action, int param1, int param2) {
    // return 0;
    if (action == MenuAction_Select) {
        char szBuffer[PLATFORM_MAX_PATH];
        menu.GetItem(param2, szBuffer, sizeof(szBuffer));
        if (szBuffer[0])
            RenderPluginInformation(param1, param2+1);
        else
            RenderPluginLoader(param1, szBuffer);
    }
}

public int PluginInfo_Hndl(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char ParamResult[30];
        menu.GetItem(param2, ParamResult, sizeof(ParamResult));
        
        if (StrEqual(ParamResult, "close", false)) return;
        if (StrContains(ParamResult, "manage", false) != -1) {
            ReplaceString(ParamResult, sizeof(ParamResult), "manage ", "", false);
            
            RenderPluginManagement(param1, StringToInt(ParamResult));
        }
    }
}

public int PluginManage_Hndl(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char ParamResult[30];
        menu.GetItem(param2, ParamResult, sizeof(ParamResult));
        
        int myAction = ParamResult[0] == 'u' ? 0 : 1;
        int PluginNum = StringToInt(ParamResult);

        Handle PluginHndl = FindPluginByNumber(PluginNum);
        if (PluginHndl == null) {
            PrintToChat(param1, "[SM] Плагин под номером #%i не найден.", PluginNum);
            return;
        }
        
        char strPluginName[256];
        if (!GetPluginInfo(PluginHndl, PlInfo_Name, strPluginName, sizeof(strPluginName))) {
            GetPluginFilename(PluginHndl, strPluginName, sizeof(strPluginName));
        }
        delete PluginHndl;
        
        switch (myAction) {
            case 0:     ServerCommand("sm plugins unload %i", PluginNum);
            case 1:     ServerCommand("sm plugins reload %i", PluginNum);             
        }
        
        PrintToChat(param1, "[SM] Плагин %s %s.", strPluginName, (myAction==0)?"выгружен":"перезагружен");
    }
}

/* Helpers */
int MoveChars(char[] szString, int iMaxLength, int iCountBytesToMove) {
    for (int iCurrentPosition = 0; iCurrentPosition < iMaxLength; iCurrentPosition++) {
        szString[iCurrentPosition] = szString[iCurrentPosition+iCountBytesToMove];
        
        if (szString[iCurrentPosition] == 0)
            return iCurrentPosition+1;
    }
    
    return 0;
}
