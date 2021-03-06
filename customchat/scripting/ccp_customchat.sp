#pragma newdecls required

#include ccprocessor

public Plugin myinfo = 
{
	name = "[CCP] CCMessage",
	author = "nullent?",
	description = "Custom client message",
	version = "2.3.0",
	url = "discord.gg/ChTyPUG"
};

#define SZ(%0)	%0, sizeof(%0)
#define BUILD(%0,%1) BuildPath(Path_SM, SZ(%0), %1)
#define _CVAR_INIT_CHANGE(%0,%1) %0(FindConVar(%1), NULL_STRING, NULL_STRING)
#define _CVAR_ON_CHANGE(%0) public void %0(ConVar cvar, const char[] szOldVal, const char[] szNewVal)

#define PMP PLATFORM_MAX_PATH
#define MPL MAXPLAYERS+1

#define PATH  "configs/c_var/customchat/customchat.ini"

enum eAccess
{
    eNone = 0,
    eDefault,
    eAuth,
    eFlag,
    eGroup
};

enum
{
    CPREFIX = 0,
    VPREFIX,
    CNAME,
    CMESSAGE,

    CMAX
};

enum struct MessageEnv
{
    eAccess m_AType;

    char m_szCPrefix[STATUS_LENGTH];
    char m_szPrefix[PREFIX_LENGTH];
    char m_szCName[STATUS_LENGTH];
    char m_szCMessage[STATUS_LENGTH];

    char m_szAccess[64];

    bool IsHasAccess(const char[] szAuth, AdminId aId, int flagBits)
    {
        if(this.m_AType == eDefault)
            return true;
        
        else if(this.m_AType == eAuth && !strcmp(this.m_szAccess, szAuth))
            return true;
        
        else if(this.m_AType == eFlag && flagBits && (flagBits & ReadFlagString(this.m_szAccess)))
            return true;
        
        else if(this.m_AType == eGroup && aId != INVALID_ADMIN_ID)
        {
            char szGroup[64];

            for(int i; i < aId.GroupCount; i++)
            {
                aId.GetGroup(i, SZ(szGroup));
                if(StrEqual(this.m_szAccess, szGroup))
                    return true;
            }
        }

        return false;
    }

    void ClearEnv()
    {
        this.m_AType = eNone;
        this.m_szCPrefix[0] = 0;
        this.m_szPrefix[0] = 0;
        this.m_szCName[0] = 0;
        this.m_szAccess[0] = 0;
        this.m_szCMessage[0] = 0;
    }
}

enum struct ClientMessage
{
    MessageEnv m_EMessage;

    AdminId m_aId;
    int m_iFlags;

    char m_szAuth[64];

    bool IsUse(int iPart)
    {
        return  (iPart == CPREFIX)  ?   this.m_EMessage.m_szCPrefix[0]  :
                (iPart == VPREFIX)  ?   this.m_EMessage.m_szPrefix[0]   :  
                (iPart == CNAME)    ?   this.m_EMessage.m_szCName[0]    :
                                        this.m_EMessage.m_szCMessage[0] ;
    }

    char GetValue(int iPart)
    {
        // In this case, the size of the first variable is absolute.
        // Another feature in the piggy bank SP

        return      (iPart == VPREFIX)  ?   this.m_EMessage.m_szPrefix  :
                    (iPart == CPREFIX)  ?   this.m_EMessage.m_szCPrefix : 
                    (iPart == CNAME)    ?   this.m_EMessage.m_szCName   :
                                            this.m_EMessage.m_szCMessage;
    }


    void SetMessageProto(MessageEnv newProto)
    {
        this.m_EMessage = newProto;
    }

    eAccess GetCurrentAccess()
    {
        return this.m_EMessage.m_AType;
    }

    void Clear()
    {
        this.m_EMessage.ClearEnv();
        this.m_aId = INVALID_ADMIN_ID;
        this.m_szAuth[0] = 0;
        this.m_iFlags = 0;
    }

    bool IsEmpty()
    {
        return this.m_EMessage.m_AType == eNone;
    }

    bool IsProtoEqual(MessageEnv MessageProto)
    {
        return (
            this.m_EMessage.m_AType == MessageProto.m_AType &&
            StrEqual(this.m_EMessage.m_szCPrefix, MessageProto.m_szCPrefix) &&
            StrEqual(this.m_EMessage.m_szPrefix, MessageProto.m_szPrefix) &&
            StrEqual(this.m_EMessage.m_szCName, MessageProto.m_szCName) &&
            StrEqual(this.m_EMessage.m_szCMessage, MessageProto.m_szCMessage) &&
            StrEqual(this.m_EMessage.m_szAccess, MessageProto.m_szAccess)
        );
    }

    void ClearEnv()
    {
        this.m_EMessage.ClearEnv();
    }
}

ArrayList aProtoBase;

ClientMessage clMessage[MAXPLAYERS+1];

int PLEVEL[CMAX];

bool
    IsMenuDisabled,
    DisableToDef;

#if defined API_KEY

#define API_KEY_OOD "The plugin module uses an outdated API. You must update it."

public void cc_proc_APIHandShake(const char[] APIKey)
{
    if(!StrEqual(APIKey, API_KEY, true))
        SetFailState(API_KEY_OOD);
}

#endif

public void OnPluginStart()
{
    #if defined API_KEY
    
    if(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "cc_is_APIEqual") == FeatureStatus_Available && !cc_is_APIEqual(API_KEY))
        cc_proc_APIHandShake(NULL_STRING);

    #endif
    
    LoadTranslations("ccp_customchat.phrases");

    aProtoBase = new ArrayList(MAX_NAME_LENGTH, 0);

    CreateConVar("ccm_prefix_priority", "1", "Priority for replacing the prefix", _, true, 0.0).AddChangeHook(ChangePrefixPrior);
    CreateConVar("ccm_cname_priority", "1", "Priority for replacing the username color", _, true, 0.0).AddChangeHook(ChangeCNamePrior);
    CreateConVar("ccm_cprefix_priority", "1", "Priority for replacing the prefix color", _, true, 0.0).AddChangeHook(ChangeCPrefixPrior);
    CreateConVar("ccm_cmessage_priority", "1", "Priority for replacing the message color", _, true, 0.0).AddChangeHook(ChangeCMessagePrior);

    CreateConVar("ccm_disable_todefault", "1", "Set the default value when turning off the template", _, true, 0.0, true, 1.0).AddChangeHook(DisableToDefault);
    CreateConVar("ccm_disable_menu", "0", "Disable the menu when entering a command", _, true, 0.0, true, 1.0).AddChangeHook(DisableMenu);
    AutoExecConfig(true, "ccp_ccmessage", "ccprocessor");
    
    RegConsoleCmd("sm_prefix", Cmd_Prefix);
}

_CVAR_ON_CHANGE(ChangePrefixPrior)
{
    PLEVEL[VPREFIX] = cvar.IntValue;
}

_CVAR_ON_CHANGE(ChangeCNamePrior)
{
    PLEVEL[CNAME] = cvar.IntValue;
}

_CVAR_ON_CHANGE(ChangeCPrefixPrior)
{
    PLEVEL[CPREFIX] = cvar.IntValue;
}

_CVAR_ON_CHANGE(ChangeCMessagePrior)
{
    PLEVEL[CMESSAGE] = cvar.IntValue;
}

_CVAR_ON_CHANGE(DisableToDefault)
{
    DisableToDef = cvar.BoolValue;
}

_CVAR_ON_CHANGE(DisableMenu)
{
    IsMenuDisabled = cvar.BoolValue;
}

public void OnMapStart()
{
    _CVAR_INIT_CHANGE(ChangePrefixPrior, "ccm_prefix_priority");
    _CVAR_INIT_CHANGE(ChangeCNamePrior, "ccm_cname_priority");
    _CVAR_INIT_CHANGE(ChangeCPrefixPrior, "ccm_cprefix_priority");
    _CVAR_INIT_CHANGE(ChangeCMessagePrior, "ccm_cmessage_priority");

    _CVAR_INIT_CHANGE(DisableToDefault, "ccm_disable_todefault");
    _CVAR_INIT_CHANGE(DisableMenu, "ccm_disable_menu");

    char szFullPath[PMP];
    BUILD(szFullPath, PATH);

    if(!FileExists(szFullPath))
    {
        LogError("Where is my config: %s ???", szFullPath);
        return;
    }

    aProtoBase.Clear();

    SMCParser smParser = new SMCParser();
    smParser.OnKeyValue = OnValueRead;

    int iLine;

    if(smParser.ParseFile(szFullPath, iLine) != SMCError_Okay)
        LogError("Error On parse: %s | Line: %i", szFullPath, iLine);
}


SMCResult OnValueRead(SMCParser smc, const char[] sKey, const char[] sValue, bool bKey_Quotes, bool bValue_quotes)
{
    if(!sKey[0] || !sValue[0])
        return SMCParse_Continue;

    static MessageEnv EBuffer;
    static int i;

    if(!strcmp("type", sKey))
    {
        // // LogMessage("Type; %s", sValue);
        EBuffer.m_AType = CharToAccessType(sValue);
        i++;
    }
    
    else if(!strcmp("type_value", sKey))
    {
        // LogMessage("type_value; %s", sValue);
        strcopy(EBuffer.m_szAccess, sizeof(EBuffer.m_szAccess), sValue);

        if(!strcmp(EBuffer.m_szAccess, "NULL", false))
            EBuffer.m_szAccess[0] = 0;

        i++;
    }

    else if(!strcmp("color_prefix", sKey))
    {
        // LogMessage("color_prefix; %s", sValue);
        strcopy(EBuffer.m_szCPrefix, sizeof(EBuffer.m_szCPrefix), sValue);

        if(!strcmp(EBuffer.m_szCPrefix, "NULL", false))
            EBuffer.m_szCPrefix[0] = 0;

        i++;
    }

    else if(!strcmp("value_prefix", sKey))
    {
        // LogMessage("value_prefix; %s", sValue);
        strcopy(EBuffer.m_szPrefix, sizeof(EBuffer.m_szPrefix), sValue);

        if(!strcmp(EBuffer.m_szPrefix, "NULL", false))
            EBuffer.m_szPrefix[0] = 0;

        i++;
    }

    else if(!strcmp("color_username", sKey))
    {
        // LogMessage("color_username; %s", sValue);
        strcopy(EBuffer.m_szCName, sizeof(EBuffer.m_szCName), sValue);

        if(!strcmp(EBuffer.m_szCName, "NULL", false))
            EBuffer.m_szCName[0] = 0;

        i++;
    }

    else if(!strcmp("color_message", sKey))
    {
        // LogMessage("color_username; %s", sValue);
        strcopy(EBuffer.m_szCMessage, sizeof(EBuffer.m_szCMessage), sValue);

        if(!strcmp(EBuffer.m_szCMessage, "NULL", false))
            EBuffer.m_szCMessage[0] = 0;

        i++;
    }

    if(i == 6)
    {
        i = 0;

        // // LogMessage("I:%i", i);
        if(EBuffer.m_AType != eNone)
            aProtoBase.PushArray(SZ(EBuffer));
    }

    return SMCParse_Continue;
}

public void OnClientPutInServer(int iClient)
{
    clMessage[iClient].Clear();

    GetClientAuthId(iClient, AuthId_Engine, clMessage[iClient].m_szAuth, sizeof(clMessage[].m_szAuth));

    GetClientProto(iClient);
}

public void OnClientPostAdminCheck(int iClient)
{
    clMessage[iClient].m_iFlags = GetUserFlagBits(iClient);
    clMessage[iClient].m_aId = GetUserAdmin(iClient);

    GetClientProto(iClient);
}

void GetClientProto(int iClient)
{
    MessageEnv EBuffer;

    for(int i; i < aProtoBase.Length; i++)
    {
        aProtoBase.GetArray(i, EBuffer, sizeof(EBuffer));

        if(EBuffer.IsHasAccess(clMessage[iClient].m_szAuth, clMessage[iClient].m_aId, clMessage[iClient].m_iFlags))
            clMessage[iClient].SetMessageProto(EBuffer);
        
        EBuffer.ClearEnv();
    }
}

public Action Cmd_Prefix(int iClient, int args)
{
    if(iClient && IsClientInGame(iClient) && !IsFakeClient(iClient))
    {
        if(!IsMenuDisabled)
        {
            Menu menu = GetClientPrototypes(iClient);
            if(menu)
                menu.Display(iClient, MENU_TIME_FOREVER);
        }
        else
        {
            switch(clMessage[iClient].GetCurrentAccess())
            {
                case eNone:
                {
                    if(!DisableToDef) GetClientProto(iClient);
                }

                case eDefault:
                {
                    if(DisableToDef) GetClientProto(iClient);
                    else clMessage[iClient].m_EMessage.ClearEnv();
                }

                default:
                    GetTemplateByAccess(iClient, (DisableToDef) ? eDefault : eNone);
            }
        }
    }
    
    return Plugin_Handled;
}

Menu GetClientPrototypes(int iClient)
{
    Menu hMenu;

    if(aProtoBase.Length)
    {
        SetGlobalTransTarget(iClient);

        hMenu = new Menu(PrefList_CallBack);
        hMenu.SetTitle("%t \n \n", "ccm_proto_list");

        char szBuffer[PREFIX_LENGTH], szOpt[8];
        int DRAWTYPE, a;
        MessageEnv EBuffer;

        FormatEx(SZ(szBuffer), "%t \n \n", "ccp_disable");
        hMenu.AddItem("r", szBuffer, (clMessage[iClient].IsEmpty() || (DisableToDef && clMessage[iClient].GetCurrentAccess() == eDefault)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

        for(int i; i < aProtoBase.Length; i++)
        {
            EBuffer.ClearEnv();

            aProtoBase.GetArray(i, SZ(EBuffer));

            if(!EBuffer.IsHasAccess(clMessage[iClient].m_szAuth, clMessage[iClient].m_aId, clMessage[iClient].m_iFlags))
                continue;

            DRAWTYPE = (clMessage[iClient].IsProtoEqual(EBuffer)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
            
            GetTranslationByAccess(iClient, EBuffer.m_AType, EBuffer.m_szAccess, SZ(szBuffer));

            IntToString(i, SZ(szOpt));

            hMenu.AddItem(szOpt, szBuffer, DRAWTYPE);
            a++;
        }

        if(!a) delete hMenu;
    }

    return hMenu;
}

void GetTemplateByAccess(int iClient, eAccess AValue)
{
    MessageEnv EBuffer;

    if(AValue == eNone)
    {
        clMessage[iClient].m_EMessage.ClearEnv();
        return;
    }
        
    for(int i; i < aProtoBase.Length; i++)
    {
        aProtoBase.GetArray(i, EBuffer, sizeof(EBuffer));

        if(EBuffer.m_AType == AValue)
        {
            clMessage[iClient].SetMessageProto(EBuffer);
            return;
        }
    }

    EBuffer.ClearEnv();
}

public int PrefList_CallBack(Menu hMenu, MenuAction action, int iClient, int iOpt2)
{
    switch(action)
    {
        case MenuAction_End: delete hMenu;
        case MenuAction_Select:
        {
            char szOpt[8];
            hMenu.GetItem(iOpt2, SZ(szOpt));
            
            if(szOpt[0] == 'r')
            {
                if(!DisableToDef) clMessage[iClient].ClearEnv();
                else GetTemplateByAccess(iClient, eDefault);

                return;
            }

            aProtoBase.GetArray(StringToInt(szOpt), clMessage[iClient].m_EMessage, sizeof(clMessage[].m_EMessage));              
        }
    }
}

int iType;

public void cc_proc_MsgBroadType(const int typeMsg)
{
    iType = typeMsg;
}

public void cc_proc_RebuildString(int iClient, int &pLevel, const char[] szBind, char[] szBuffer, int iSize)
{
    if(!iClient || clMessage[iClient].IsEmpty())
        return;
    
    if(iType < eMsg_SERVER)
    {
        static int i;
        i = (!strcmp(szBind, "{NAMECO}")) ? CNAME : (!strcmp(szBind, "{PREFIX}")) ? VPREFIX : (!strcmp(szBind, "{MSGCO}")) ? CMESSAGE : (!strcmp(szBind, "{PREFIXCO}")) ? CPREFIX : -1;

        if(i == -1)
            return;
        
        if(PLEVEL[i] < pLevel)
            return;
        
        if(!clMessage[iClient].IsUse(i))
            return;
        
        pLevel = PLEVEL[i];
        FormatEx(szBuffer, iSize, "%s", clMessage[iClient].GetValue(i));
    }
    
}


// auth, flag, group
eAccess CharToAccessType(const char[] szAccess)
{
    return (!strcmp(szAccess, "auth", false)) ? eAuth : (!strcmp(szAccess, "flag", false)) ? eFlag : (!strcmp(szAccess, "group", false)) ? eGroup : (!strcmp(szAccess, "default", false)) ? eDefault : eNone;
}

void GetTranslationByAccess(int iClient, const eAccess accessType, const char[] szValue, char[] szBuffer, int size)
{
    SetGlobalTransTarget(iClient);

    switch(accessType)
    {
        case eDefault: FormatEx(szBuffer, size, "%t", "ccm_default_item");
        case eAuth: FormatEx(szBuffer, size, "%t", "ccm_personal_item");
        case eFlag: FormatEx(szBuffer, size, "%t", "ccm_flag_item", szValue);
        case eGroup: FormatEx(szBuffer, size, "%t", "ccm_group_item", szValue);
    }
}

stock char AccessTypeToChar(eAccess eAValue)
{
    char szAccess[12];

    switch(eAValue)
    {
        case eAuth: szAccess = "auth";
        case eFlag: szAccess = "flag";
        case eGroup: szAccess = "group";
        case eDefault: szAccess = "default";
    }

    return szAccess;
}