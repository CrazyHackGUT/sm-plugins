Handle g_hPlayTaunt;

enum {
    TError_None = 0,                /**< No error */
    TError_NotOnGround,             /**< Client entity not on ground. */
    TError_EntityNotCreated,        /**< Couldn't create entity. */
    TError_CEconItemViewNotFound,   /**< Couldn't find CEconItemView for taunt. */
    TError_SDKCall                  /**< SDK Call error. */
}

public void TauntEm_Init() {
    Handle hConf = LoadGameConfigFile("tf2.tauntem");
    if (!hConf) {
        SetFailState("Unable to load gamedata/tf2.tauntem.txt.\nGood luck figuring that out.");
        return;
    }

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTFPlayer::PlayTauntSceneFromItem");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
    g_hPlayTaunt = EndPrepSDKCall();

    if (!g_hPlayTaunt)
        SetFailState("Unable to initialize call to CTFPlayer::PlayTauntSceneFromItem. Wait patiently for a fix.");

    delete hConf;
}

public bool TauntEm_ForceTaunt(int iClient, int iTaunt, int iParticle = -1, int &iError) {
    if (!(GetEntityFlags(iClient) & FL_ONGROUND)) {
        iError = TError_NotOnGround;
        return false;
    }

    int iEnt = TauntEm_MakeCEIVEnt(iClient, iTaunt, iParticle);
    if (!IsValidEntity(iEnt)) {
        LogError("[TAUNTS] Couldn't create entity for taunt.");
        iError = TError_EntityNotCreated;
        return false;
    }

    Address pEconItemView = GetEntityAddress(iEnt) + view_as<Address>(FindSendPropInfo("CTFWearable", "m_Item"));
    if (!IsValidAddress(pEconItemView)) {
        LogError("[TAUNTS] Couldn't find CEconItemView for taunt.");
        iError = TError_CEconItemViewNotFound;
        return false;
    }

    bool iResult = SDKCall(g_hPlayTaunt, iClient, pEconItemView);
    iError = iResult ? TError_None : TError_SDKCall;
    return iResult;
}

stock int TauntEm_MakeCEIVEnt(int client, int itemdef, int particle=0)
{
    static Handle hItem;

    if (hItem == INVALID_HANDLE) {
        hItem = TF2Items_CreateItem(OVERRIDE_ALL|PRESERVE_ATTRIBUTES|FORCE_GENERATION);
        TF2Items_SetClassname(hItem, "tf_wearable_vm");
        TF2Items_SetQuality(hItem, 6);
        TF2Items_SetLevel(hItem, 1);
    }

    TF2Items_SetItemIndex(hItem, itemdef);

    TF2Items_SetNumAttributes(hItem, particle ? 1 : 0);
    if (particle) TF2Items_SetAttribute(hItem, 0, 2041, float(particle));

    return TF2Items_GiveNamedItem(client, hItem);
}

stock bool IsValidAddress(Address pAddress)
{
    if (pAddress == Address_Null)  //yes the other one overlaps this but w/e
        return false;

    return ((pAddress & view_as<Address>(0x7FFFFFFF)) >= Address_MinimumValid);
}
