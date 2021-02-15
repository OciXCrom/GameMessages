#include <amxmodx>
#include <amxmisc>
#include <cromchat>

#if AMXX_VERSION_NUM < 183
	#include <dhudmessage>
#endif

new const PLUGIN_VERSION[] = "3.0.2"
new const Float:POS_DEFAULT = 9.99

new const SYM_SUBSTRING[] = "%s"
new const SYM_NEWLINE[] = "%n"
new const REP_NEWLINE_HUD[] = "^n"
new const REP_NEWLINE_CENTER[] = "^r"

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

enum _:Values
{
	VALUE_EFFECTS,
	Float:VALUE_FXTIME,
	Float:VALUE_HOLDTIME,
	Float:VALUE_FADEINTIME,
	Float:VALUE_FADEOUTTIME
}

enum _:Messages
{
	MSG_NEW[128],
	Types:MSG_TYPE,
	MSG_COLOR[3],
	Float:MSG_POSITION[2]
}

enum _:Types
{
	TYPE_CHAT,
	TYPE_CENTER,
	TYPE_HUD,
	TYPE_DHUD
}

new g_eCvars[Cvars],
	g_eValues[Values],
	Array:g_aMessages,
	Trie:g_tMessages,
	Trie:g_tSounds,
	g_iMessagesNum

public plugin_init()
{
	register_plugin("Game Messages & Sounds Manager", PLUGIN_VERSION, "OciXCrom")
	register_cvar("WinMessages", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_message(get_user_msgid("TextMsg"), "OnTextMsg")
	register_message(get_user_msgid("SendAudio"), "OnSendAudio")
	
	g_eCvars[CVAR_XPOS] = register_cvar("gmsm_hud_xpos", "-1.0")
	g_eCvars[CVAR_YPOS] = register_cvar("gmsm_hud_ypos", "0.10")
	g_eCvars[CVAR_EFFECTS] = register_cvar("gmsm_hud_effects", "0")
	g_eCvars[CVAR_FXTIME] = register_cvar("gmsm_hud_fxtime", "2.0")
	g_eCvars[CVAR_HOLDTIME] = register_cvar("gmsm_hud_holdtime", "5.0")
	g_eCvars[CVAR_FADEINTIME] = register_cvar("gmsm_hud_fadeintime", "0.5")
	g_eCvars[CVAR_FADEOUTTIME] = register_cvar("gmsm_hud_fadeouttime", "1.0")
}

public plugin_precache()
{
	g_aMessages = ArrayCreate(Messages)
	g_tMessages = TrieCreate()
	g_tSounds = TrieCreate()
	ReadFile()
}

public plugin_end()
{
	ArrayDestroy(g_aMessages)
	TrieDestroy(g_tMessages)
	TrieDestroy(g_tSounds)
}

public plugin_cfg()
{
	new Float:fPosition[2]
	fPosition[0] = get_pcvar_float(g_eCvars[CVAR_XPOS])
	fPosition[1] = get_pcvar_float(g_eCvars[CVAR_YPOS])

	for(new eMessage[Messages], i, j; i < g_iMessagesNum; i++)
	{
		ArrayGetArray(g_aMessages, i, eMessage)

		for(j = 0; j < 2; j++)
		{
			if(eMessage[MSG_POSITION][j] == POS_DEFAULT)
				eMessage[MSG_POSITION][j] = _:fPosition[j]
		}

		ArraySetArray(g_aMessages, i, eMessage)
	}

	g_eValues[VALUE_EFFECTS] = get_pcvar_num(g_eCvars[CVAR_EFFECTS])
	g_eValues[VALUE_FXTIME] = _:get_pcvar_float(g_eCvars[CVAR_FXTIME])
	g_eValues[VALUE_HOLDTIME] = _:get_pcvar_float(g_eCvars[CVAR_HOLDTIME])
	g_eValues[VALUE_FADEINTIME] = _:get_pcvar_float(g_eCvars[CVAR_FADEINTIME])
	g_eValues[VALUE_FADEOUTTIME] = _:get_pcvar_float(g_eCvars[CVAR_FADEOUTTIME])
}

ReadFile()
{
	new szFilename[256]
	get_configsdir(szFilename, charsmax(szFilename))
	add(szFilename, charsmax(szFilename), "/GameMessages.ini")

	new iFilePointer = fopen(szFilename, "rt")
	
	if(iFilePointer)
	{
		new eMessage[Messages], szColors[3][4], szCoordinates[2][6], szData[256], szSound[128], szMessage[64], szFullColor[12], szPosition[12], szType[4], i
		
		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData))
			trim(szData)
			
			switch(szData[0])
			{
				case EOS, '#', ';': continue
				case '%':
				{
					parse(szData, szMessage, charsmax(szMessage), szSound, charsmax(szSound))
					TrieSetString(g_tSounds, szMessage, szSound)
					
					if(szSound[0])
						precache_generic(szSound)
						
					szSound[0] = EOS
				}
				default:
				{
					szFullColor[0] = EOS
					szPosition[0] = EOS
					eMessage[MSG_NEW][0] = EOS

					for(i = 0; i < 3; i++)
					{
						szColors[i][0] = EOS
						eMessage[MSG_COLOR][i] = 0
					}

					for(i = 0; i < 2; i++)
					{
						szCoordinates[i][0] = EOS
						eMessage[MSG_POSITION][i] = _:POS_DEFAULT
					}

					parse(szData, szMessage, charsmax(szMessage), eMessage[MSG_NEW], charsmax(eMessage[MSG_NEW]), szType, charsmax(szType), szFullColor, charsmax(szFullColor), szPosition, charsmax(szPosition))
					format(szMessage, charsmax(szMessage), "#%s", szMessage)
					TrieSetCell(g_tMessages, szMessage, g_iMessagesNum++)

					switch(szType[2])
					{
						case 'A', 'a': eMessage[MSG_TYPE] = _:TYPE_CHAT
						case 'N', 'n': eMessage[MSG_TYPE] = _:TYPE_CENTER
						case 'D', 'd': eMessage[MSG_TYPE] = _:TYPE_HUD
						case 'U', 'u': eMessage[MSG_TYPE] = _:TYPE_DHUD
					}
					
					if(_:eMessage[MSG_TYPE] == TYPE_HUD || _:eMessage[MSG_TYPE] == TYPE_DHUD)
					{
						if(szFullColor[0])
						{
							parse(szFullColor, szColors[0], charsmax(szColors[]), szColors[1], charsmax(szColors[]), szColors[2], charsmax(szColors[]))

							for(i = 0; i < 3; i++)
								eMessage[MSG_COLOR][i] = str_to_num(szColors[i])
						}

						if(szPosition[0])
						{
							parse(szPosition, szCoordinates[0], charsmax(szCoordinates[]), szCoordinates[1], charsmax(szCoordinates[]))

							for(i = 0; i < 2; i++)
								eMessage[MSG_POSITION][i] = _:str_to_float(szCoordinates[i])
						}
					}

					ArrayPushArray(g_aMessages, eMessage)
				}
			}
		}
		
		fclose(iFilePointer)
	}
}

public OnTextMsg(iMessage, iDest, id)
{ 
	static szMessage[64]
	get_msg_arg_string(2, szMessage, charsmax(szMessage))
	
	if(TrieKeyExists(g_tMessages, szMessage))
	{
		new eMessage[Messages], iMessage
		TrieGetCell(g_tMessages, szMessage, iMessage)
		ArrayGetArray(g_aMessages, iMessage, eMessage)
		
		new iArgs = get_msg_args()
		
		if(iArgs > 2)
		{
			for(new szSubString[32], i = 2; i < iArgs; i++)
			{
				get_msg_arg_string(i + 1, szSubString, charsmax(szSubString))
				replace(eMessage[MSG_NEW], charsmax(eMessage[MSG_NEW]), SYM_SUBSTRING, szSubString)
			}
		}
		
		replace_all(eMessage[MSG_NEW], charsmax(eMessage[MSG_NEW]), SYM_SUBSTRING, "")
		
		switch(eMessage[MSG_TYPE])
		{
			case TYPE_CHAT: CC_SendMessage(id, eMessage[MSG_NEW])
			case TYPE_CENTER:
			{
				replace_all(eMessage[MSG_NEW], charsmax(eMessage[MSG_NEW]), SYM_NEWLINE, REP_NEWLINE_CENTER)
				client_print(id, print_center, eMessage[MSG_NEW])
			}
			case TYPE_HUD, TYPE_DHUD:
			{
				replace_all(eMessage[MSG_NEW], charsmax(eMessage[MSG_NEW]), SYM_NEWLINE, REP_NEWLINE_HUD)

				switch(eMessage[MSG_TYPE])
				{
					case TYPE_HUD:
					{
						set_hudmessage(handle_color(eMessage[MSG_COLOR][0]), handle_color(eMessage[MSG_COLOR][1]), handle_color(eMessage[MSG_COLOR][2]),\
						eMessage[MSG_POSITION][0], eMessage[MSG_POSITION][1], g_eValues[VALUE_EFFECTS], g_eValues[VALUE_FXTIME], g_eValues[VALUE_HOLDTIME],\
						g_eValues[VALUE_FADEINTIME], g_eValues[VALUE_FADEOUTTIME])
						show_hudmessage(id, eMessage[MSG_NEW])
					}
					case TYPE_DHUD:
					{
						set_dhudmessage(handle_color(eMessage[MSG_COLOR][0]), handle_color(eMessage[MSG_COLOR][1]), handle_color(eMessage[MSG_COLOR][2]),\
						eMessage[MSG_POSITION][0], eMessage[MSG_POSITION][1], g_eValues[VALUE_EFFECTS], g_eValues[VALUE_FXTIME], g_eValues[VALUE_HOLDTIME],\
						g_eValues[VALUE_FADEINTIME], g_eValues[VALUE_FADEOUTTIME])
						show_dhudmessage(id, eMessage[MSG_NEW])
					}
				}
			}
		}
		
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public OnSendAudio(MsgId, MsgDest, MsgEntity)
{
	static szMessage[32]
	get_msg_arg_string(2, szMessage, charsmax(szMessage))
	
	if(TrieKeyExists(g_tSounds, szMessage))
	{
		new szNewMessage[128]
		TrieGetString(g_tSounds, szMessage, szNewMessage, charsmax(szNewMessage))
		
		if(szNewMessage[0])
			client_cmd(0, "spk %s", szNewMessage)
			
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}
	
handle_color(iColor)
	return iColor == -1 ? random(256) : iColor