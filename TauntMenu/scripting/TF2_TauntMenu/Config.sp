char g_szConfigPath[PLATFORM_MAX_PATH];
static KeyValues g_hConfig;

public void Config_Init() {
    BuildPath(Path_SM, g_szConfigPath, sizeof(g_szConfigPath), "configs/TauntList.cfg");
}

public void Config_Start() {
    if (g_hConfig) {
        delete g_hConfig;
        g_hConfig = null;
    }

    g_hConfig = new KeyValues("TauntList");
    g_hConfig.ImportFromFile(g_szConfigPath);
}
