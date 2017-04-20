#include <amxmodx>
#include <amxmisc>

#if AMXX_VERSION_NUM < 183
	#include <dhudmessage>
#endif

#define PLUGIN_VERSION "2.1"
#define SYM_SUBSTRING "%s"
#define SYM_NEWLINE "%n"

enum _:Cvars
{
	CVAR_XPOS,
	CVAR_YPOS,
	CVAR_EFFECTS,
	CVAR_FXTIME,
	CVAR_HOLDTIME,
	CVAR_FADEINTIME,
	CVAR_FADEOUTTIME
}

enum
{
	TYPE_CHAT,
	TYPE_CENTER,
	TYPE_HUD,
	TYPE_DHUD
}

#define TRIE_MESSAGES 0 
#define TRIE_TYPE 1
#define TRIE_COLORS 2
#define TRIE_AUDIO 3

new g_iSayText
new g_eCvars[Cvars]
new Trie:g_eTries[4]

public plugin_init()
{
	register_plugin("Win Messages & Sounds", PLUGIN_VERSION, "OciXCrom")
	register_cvar("WinMessages", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_message(get_user_msgid("TextMsg"), "msgTextMsg")
	register_message(get_user_msgid("SendAudio"), "msgSendAudio")
	g_iSayText = get_user_msgid("SayText")
	
	g_eCvars[CVAR_XPOS] = register_cvar("winmsg_hud_xpos", "-1.0")
	g_eCvars[CVAR_YPOS] = register_cvar("winmsg_hud_ypos", "0.10")
	g_eCvars[CVAR_EFFECTS] = register_cvar("winmsg_hud_effects", "0")
	g_eCvars[CVAR_FXTIME] = register_cvar("winmsg_hud_fxtime", "2.0")
	g_eCvars[CVAR_HOLDTIME] = register_cvar("winmsg_hud_holdtime", "5.0")
	g_eCvars[CVAR_FADEINTIME] = register_cvar("winmsg_hud_fadeintime", "0.5")
	g_eCvars[CVAR_FADEOUTTIME] = register_cvar("winmsg_hud_fadeouttime", "1.0")
}

public plugin_precache()
{
	for(new i; i < sizeof(g_eTries); i++)
		g_eTries[i] = TrieCreate()
		
	fileRead()
}

public plugin_end()
{
	for(new i; i < sizeof(g_eTries); i++)
		TrieDestroy(g_eTries[i])
}

fileRead()
{
	new szConfigsName[256], szFilename[256]
	get_configsdir(szConfigsName, charsmax(szConfigsName))
	formatex(szFilename, charsmax(szFilename), "%s/WinMessages.ini", szConfigsName)
	new iFilePointer = fopen(szFilename, "rt")
	
	if(iFilePointer)
	{
		new szData[256], szMessage[64], szNewMessage[128], szType[4], szColors[12], iType
		
		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData))
			trim(szData)
			
			switch(szData[0])
			{
				case EOS, ';': continue
				case '#':
				{
					parse(szData, szMessage, charsmax(szMessage), szNewMessage, charsmax(szNewMessage), szType, charsmax(szType), szColors, charsmax(szColors))
					TrieSetString(g_eTries[TRIE_MESSAGES], szMessage, szNewMessage)
					
					switch(szType[2])
					{
						case 'A', 'a': iType = TYPE_CHAT
						case 'N', 'n': iType = TYPE_CENTER
						case 'D', 'd': iType = TYPE_HUD
						case 'U', 'u': iType = TYPE_DHUD
					}
					
					TrieSetCell(g_eTries[TRIE_TYPE], szMessage, iType)
					
					if(iType == TYPE_HUD || iType == TYPE_DHUD)
                        TrieSetString(g_eTries[TRIE_COLORS], szMessage, szColors)
						
					szNewMessage[0] = EOS
				}
				case '%':
				{
					parse(szData, szMessage, charsmax(szMessage), szNewMessage, charsmax(szNewMessage))
					TrieSetString(g_eTries[TRIE_AUDIO], szMessage, szNewMessage)
					
					if(!is_blank(szNewMessage))
						precache_sound(szNewMessage)
						
					szNewMessage[0] = EOS
				}
			}
		}
		
		fclose(iFilePointer)
	}
}

public msgTextMsg(iMessage, iDest, id)
{ 
	static szMessage[64]
	get_msg_arg_string(2, szMessage, charsmax(szMessage))
	
	if(TrieKeyExists(g_eTries[TRIE_MESSAGES], szMessage))
	{
		new szNewMessage[128], iType
		TrieGetString(g_eTries[TRIE_MESSAGES], szMessage, szNewMessage, charsmax(szNewMessage))
		TrieGetCell(g_eTries[TRIE_TYPE], szMessage, iType)
		
		new iArgs = get_msg_args()
		
		if(iArgs > 2)
		{
			for(new szSubString[32], i = 2; i < iArgs; i++)
			{
				get_msg_arg_string(i + 1, szSubString, charsmax(szSubString))
				replace(szNewMessage, charsmax(szNewMessage), SYM_SUBSTRING, szSubString)
			}
		}
		
		replace_all(szNewMessage, charsmax(szNewMessage), SYM_SUBSTRING, "")
		replace_all(szNewMessage, charsmax(szNewMessage), SYM_NEWLINE, "^n")
		
		switch(iType)
		{
			case TYPE_CHAT: ColorChat(id, szNewMessage)
			case TYPE_CENTER: client_print(id, print_center, szNewMessage)
			case TYPE_HUD, TYPE_DHUD:
			{
				new szColors[12], szRed[4], szGreen[4], szBlue[4], iRed, iGreen, iBlue
				TrieGetString(g_eTries[TRIE_COLORS], szMessage, szColors, charsmax(szColors))
				parse(szColors, szRed, charsmax(szRed), szGreen, charsmax(szGreen), szBlue, charsmax(szBlue))
				iRed = is_random(szRed) ? random(256) : str_to_num(szRed)
				iGreen = is_random(szGreen) ? random(256) : str_to_num(szGreen)
				iBlue = is_random(szBlue) ? random(256) : str_to_num(szBlue)
				
				switch(iType)
				{
					case TYPE_HUD:
					{
						set_hudmessage(iRed, iGreen, iBlue, get_pcvar_float(g_eCvars[CVAR_XPOS]), get_pcvar_float(g_eCvars[CVAR_YPOS]), get_pcvar_num(g_eCvars[CVAR_EFFECTS]), 
						get_pcvar_float(g_eCvars[CVAR_FXTIME]), get_pcvar_float(g_eCvars[CVAR_HOLDTIME]), get_pcvar_float(g_eCvars[CVAR_FADEINTIME]), get_pcvar_float(g_eCvars[CVAR_FADEOUTTIME]), -1)
						show_hudmessage(id, szNewMessage)
					}
					case TYPE_DHUD:
					{
						set_dhudmessage(iRed, iGreen, iBlue, get_pcvar_float(g_eCvars[CVAR_XPOS]), get_pcvar_float(g_eCvars[CVAR_YPOS]), get_pcvar_num(g_eCvars[CVAR_EFFECTS]), 
						get_pcvar_float(g_eCvars[CVAR_FXTIME]), get_pcvar_float(g_eCvars[CVAR_HOLDTIME]), get_pcvar_float(g_eCvars[CVAR_FADEINTIME]), get_pcvar_float(g_eCvars[CVAR_FADEOUTTIME]))
						show_dhudmessage(id, szNewMessage)
					}
				}
			}
		}
		
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public msgSendAudio(MsgId, MsgDest, MsgEntity)
{
	static szMessage[32]
	get_msg_arg_string(2, szMessage, charsmax(szMessage))
	
	if(TrieKeyExists(g_eTries[TRIE_AUDIO], szMessage))
	{
		new szNewMessage[128]
		TrieGetString(g_eTries[TRIE_AUDIO], szMessage, szNewMessage, charsmax(szNewMessage))
		
		if(!is_blank(szNewMessage))
			client_cmd(0, "spk %s", szNewMessage)
			
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

bool:is_blank(szString[])
	return szString[0] == EOS ? true : false
	
bool:is_random(szString[])
	return szString[0] == 'R' ? true : false
	
ColorChat(const id, const szInput[], any:...)
{
	new iPlayers[32], iCount = 1
	static szMessage[191]
	vformat(szMessage, charsmax(szMessage), szInput, 3)
	
	replace_all(szMessage, charsmax(szMessage), "!g", "^4")
	replace_all(szMessage, charsmax(szMessage), "!n", "^1")
	replace_all(szMessage, charsmax(szMessage), "!t", "^3")
	
	if(id)
		iPlayers[0] = id
	else
		get_players(iPlayers, iCount, "ch")
	
	for(new i; i < iCount; i++)
	{
		if(is_user_connected(iPlayers[i]))
		{
			message_begin(MSG_ONE_UNRELIABLE, g_iSayText, _, iPlayers[i])
			write_byte(iPlayers[i])
			write_string(szMessage)
			message_end()
		}
	}
}