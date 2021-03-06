#pragma newdecls required

#include ccprocessor

/*enum
{
    TeamSPEC = 0,
    TeamAuto,
    TeamT,
    TeamCT,
    TeamMax
};*/

static const int 
    TeamAuto = 1,
    TeamMax = 4;

int iSender;

public Plugin myinfo = 
{
	name = "[CCP] Split color tag",
	author = "nullent?",
	description = "Split several colors in one tag",
	version = "1.2.0",
	url = "discord.gg/ChTyPUG"
};

#if defined API_KEY

#define API_KEY_OOD "The plugin module uses an outdated API. You must update it."

public void cc_proc_APIHandShake(const char[] APIKey)
{
    if(!StrEqual(APIKey, API_KEY, true))
        SetFailState(API_KEY_OOD);
}

#endif

ArrayList aTeamSplit;

public void OnPluginStart()
{
    #if defined API_KEY
    
    if(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "cc_is_APIEqual") == FeatureStatus_Available && !cc_is_APIEqual(API_KEY))
        cc_proc_APIHandShake(NULL_STRING);

    #endif

    aTeamSplit = new ArrayList(STATUS_LENGTH, 0);
}

public void cc_config_parsed()
{
    aTeamSplit.Clear();

    ArrayList buffer = cc_drop_palette();

    char szColor[STATUS_LENGTH];

    for(int i = 1; i < buffer.Length; i+=3)
    {
        buffer.GetString(i, szColor, sizeof(szColor));
        if(szColor[0] != '3' || strlen(szColor) > 1)
            continue;
        
        buffer.GetString(i-1, szColor, sizeof(szColor));
        aTeamSplit.PushString(szColor);
    }

    delete buffer;

    if(aTeamSplit.Length != TeamMax)
        aTeamSplit.Clear();
}

public void cc_proc_OnMessageBuilt(int iClient, const char[] szMessage)
{
    if(!iClient)
        return;
    
    char szColor[STATUS_LENGTH];

    iSender = iClient;

    for(int i; i < aTeamSplit.Length; i++)
    {
        aTeamSplit.GetString(i, szColor, sizeof(szColor));
        if(StrContains(szMessage, szColor) != -1)
        {
            iSender = (GetClientTeam(iClient) != i && i != TeamAuto) ? GetSenderByTeam(i) : iClient;
            break;
        }
    }
}

public void cc_proc_IndexApproval(int &iIndex)
{
    iIndex = iSender;
}

int GetSenderByTeam(int Team)
{
    int i;
    while(i++ < MaxClients)
    {
        if(IsClientInGame(i) && GetClientTeam(i) == Team)
            return i;
    }

    return i;
}
