#pragma newdecls required

#include ccprocessor

#include sdkhooks
#include sdktools

int m_iCompTeammateColor = -1;

int ColorArray[MAXPLAYERS+1];

bool IsMapEnd, EnColor;

char szStatusSmb[STATUS_LENGTH];
int Level;

public Plugin myinfo = 
{
    name        = "[CCP, CSGO] CMarker",
    author      = "nullent?",
    description = "Competitive color marker into chat",
    version     = "1.2.0",
    url         = "discord.gg/ChTyPUG"
};

#if defined API_KEY

#define API_KEY_OOD "The plugin module uses an outdated API. You must update it."

public void cc_proc_APIHandShake(const char[] APIKey)
{
    if(!StrEqual(APIKey, API_KEY, true))
        SetFailState(API_KEY_OOD);
}
#endif

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{ 
    return (GetEngineVersion() != Engine_CSGO || FindConVar("game_mode").IntValue != 1) ? APLRes_SilentFailure : APLRes_Success;
}

public void OnPluginStart()
{
    #if defined API_KEY
    
    if(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "cc_is_APIEqual") == FeatureStatus_Available && !cc_is_APIEqual(API_KEY))
        cc_proc_APIHandShake(NULL_STRING);

    #endif

    m_iCompTeammateColor = FindSendPropInfo("CCSPlayerResource", "m_iCompTeammateColor");

    CreateConVar("cmarker_priority_level", "1", "Replacement Priority", _, true, 0.0).AddChangeHook(OnLevelChanged);
    CreateConVar("cmarker_status_symbol", "●", "Any character").AddChangeHook(OnSymbolChanged);
    CreateConVar("cmarker_added_color", "1", "Enable/Disable color").AddChangeHook(OnColorChanged);

    AutoExecConfig(true, "cmarker_comp", "ccprocessor");
}

public void OnLevelChanged(ConVar cvar, const char[] szOldVal, const char[] szNewVal)
{
    Level = cvar.IntValue;
}

public void OnColorChanged(ConVar cvar, const char[] szOldVal, const char[] szNewVal)
{
    EnColor = cvar.BoolValue;
}

public void OnSymbolChanged(ConVar cvar, const char[] szOldVal, const char[] szNewVal)
{
    cvar.GetString(szStatusSmb, sizeof(szStatusSmb));
}

public void OnMapStart()
{
    OnLevelChanged(FindConVar("cmarker_priority_level"), NULL_STRING, NULL_STRING);
    OnSymbolChanged(FindConVar("cmarker_status_symbol"), NULL_STRING, NULL_STRING);
    OnColorChanged(FindConVar("cmarker_added_color"), NULL_STRING, NULL_STRING);

    IsMapEnd = false;

    SDKHook(GetPlayerResourceEntity(), SDKHook_ThinkPost, OnThinkPost); 
}

public void OnMapEnd()
{
    IsMapEnd = true;
}

public void OnThinkPost(int entity)
{
    if(entity == -1)
        return;
    
    else if(IsMapEnd)
        SDKUnhook(entity, SDKHook_ThinkPost, OnThinkPost);
    
    GetEntDataArray(entity, m_iCompTeammateColor, ColorArray, sizeof(ColorArray));
}

int TemplateType;

public void cc_proc_MsgBroadType(const int type)
{
    TemplateType = type;
}

public void cc_proc_RebuildString(int iClient, int &pLevel, const char[] szBind, char[] szBuffer, int iSize)
{
    if(TemplateType < eMsg_SERVER && !strcmp(szBind, "{STATUS}") && pLevel < Level)
    {
        pLevel = Level;

        FormatEx(szBuffer, iSize, "%s", szStatusSmb);

        if(EnColor)
        {
            cc_clear_allcolors(szBuffer, iSize);
            
            Format(szBuffer, iSize, "%c%s", GetColor(iClient), szBuffer);
        }
            
        
        // Exception reported: Instruction contained invalid parameter - > NULL_STRING before the value throws this exception
        // FormatEx(szBuffer, iSize, "%s%s", (EnColor) ? GetColor(iClient) : "", szStatusSmb);
    }
}

int GetColor(int iClient)
{
    static const int colors[] = {9, 14, 4, 11, 16};

    return (ColorArray[iClient] >= sizeof(colors) || ColorArray[iClient] < 0) ? 1 : colors[ColorArray[iClient]];
}
