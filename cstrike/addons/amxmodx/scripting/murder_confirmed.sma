#include <amxmodx>
#include <reapi>
#include <aes_v>
#include <float>

#define IsPlayer(%1)            (1 <= (%1) <= MAX_PLAYERS)

//#define CSDM					// Раскоментировать, если у вас режим CSDM 

new const STYLES_URL[] = "http://gfsoul.csmix.ru/style";
new const TOKEN_MDL[] = "models/token.mdl";
new const SMOKE_SPR[] = "sprites/steam1.spr";
new const SND_PICKUP[] = "exp.wav";
new const SND_DELETE[] = "ambience/steamburst1.wav";

enum any:CVARS
{
	MC_MP_MODE,
    MC_MP_MAX_SCORE,
#if !defined CSDM
	MC_MP_INFINITE,
	MC_MP_GIVE_C4,
	MC_MP_INF_AMMO,
    Float:MC_MP_FORCERSPAWN,
	MC_MP_STIME,
	MC_MP_T_WP_PRIMARY,
	MC_MP_T_WP_SECONDARY,
	MC_MP_CT_WP_PRIMARY,
	MC_MP_CT_WP_SECONDARY,
	Float:MC_MP_SPAWNPROTECTIONTIME,
#endif
	Float:MC_MP_LIVE_MDL,
	MC_MP_SND_DELETE,
	Float:MC_MP_LIVE_USER,
	Float:MC_MP_BULLETS_DMG,
	Float:MC_MP_GRENADE_DMG,
	Float:MC_MP_OTHER_DMG,
	MC_MP_BONUS_FOR_WINTEAM,
    Float:MC_MP_EXP_FOR_WINTEAM,
    MC_MP_WITHDRAWING_BONUS_LOSERS,
    Float:MC_MP_WITHDRAWING_EXP_LOSERS
}

new g_Cvar[CVARS];
new g_iTokenCT, g_iTokenTT;
new iEntity;
new g_TokenMdl, g_iSmoke;
new g_iToken[MAX_PLAYERS+1], g_iTokenTeam[MAX_PLAYERS+1];
new g_iTokenBest, g_iTokenBests, g_Name[MAX_PLAYERS], g_Namer[MAX_PLAYERS], g_iUserTK[MAX_PLAYERS], g_iFrozen;
new bool: bTokenHardcore = false;

#if !defined CSDM
new Float: g_flProtectionOnSpawnStartTime[MAX_CLIENTS + 1];
#endif

new current_map[MAX_PLAYERS+1];
new iSelectKey[2];
new gMsgStatusIcon;
new giCurrentKills[MAX_PLAYERS + 1];
new g_iCTWins = 0, g_iTTWins = 0;
new g_MinPlayers = 0;

new const cvars[][] = 
{
	"mp_friendlyfire",
	"ff_damage_reduction_bullets",
	"ff_damage_reduction_grenade",
	"ff_damage_reduction_other",
#if !defined CSDM
	"mp_item_staytime",
	"mp_give_player_c4",
	"mp_infinite_ammo",
	"mp_forcerespawn",
	"mp_round_infinite",
	"mp_t_default_weapons_primary",
	"mp_t_default_weapons_secondary",
	"mp_ct_default_weapons_primary",
	"mp_ct_default_weapons_secondary",
	"mp_respawn_immunitytime"
#endif
};

#if !defined CSDM
new g_szMapPrefixes[][] = // Список префиксов карт, где плагин будет работать
{
	"$",
	"fy_"
};
#endif

const KEYS =
(
    IN_ATTACK | IN_ATTACK2 |
    IN_JUMP | IN_DUCK |
    IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT
);

#define IsUserMoved(%1) (get_member(id, m_afButtonPressed) & KEYS)

new const values[ sizeof(cvars) ][64];

public plugin_init ()
{
	register_plugin("Murder Confirmed", "1.2", "maFFyoZZyk");
#if !defined CSDM
	CheckMap();
#endif
	register_dictionary("murder_confirmed.txt");
	RegisterCvars();

	RegisterHookChain(RG_CSGameRules_RestartRound, "RoundStart_Post", .post = true);
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", .post = true);
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "TakeDamage_Pre", .post = false);
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", .post = true);									// Отлавливаем момент спавна игрока
#if !defined CSDM
	RegisterHookChain(RG_CBasePlayer_SetSpawnProtection, "CBasePlayer_SetSpawnProtection_Post", .post = true);
	RegisterHookChain(RG_CBasePlayer_RemoveSpawnProtection, "CBasePlayer_RemoveSpawnProtection_Post", .post = true);
#endif
	register_menucmd(register_menuid("TOKEN"), MENU_KEY_1|MENU_KEY_2, "NPMHandler");

	set_task(1.0, "Task_HudMsg", 132, "", _, "b");
	get_mapname(current_map, charsmax(current_map));
	
	gMsgStatusIcon = get_user_msgid("StatusIcon");
	
	AutoExecConfig(true, "murder_confirmed");
}

#if !defined CSDM
CheckMap()
{
	new szMapName[32], bool:bMapType;
	get_mapname(szMapName, charsmax(szMapName));
	for(new i, iMapTypesNum = sizeof g_szMapPrefixes; i < iMapTypesNum; i++)
	{
		if(equali(szMapName, g_szMapPrefixes[i], strlen(g_szMapPrefixes[i])))
		{
			bMapType = true;
			log_amx("Карта: '%s'. Плагин был запущен префиксом: '%s'!", szMapName, g_szMapPrefixes[i]);
			
			break;
		}
	}
	if(!bMapType)
	{
		log_amx("Карта: '%s'. Плагин был остановлен!", szMapName);
		pause("a");
	}
}
#endif

public plugin_precache()
{
	g_TokenMdl = precache_model(TOKEN_MDL);
	g_iSmoke = precache_model(SMOKE_SPR);
	precache_sound(SND_PICKUP);
	precache_sound(SND_DELETE);
}

#if !defined CSDM
public plugin_cfg()
{
	for(new i; i < sizeof(cvars); i++)
		get_cvar_string(cvars[i], values[i], charsmax(values[]));

	new szPath[64], szMapName[32], szLoadedConfig[96];
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
	rh_get_mapname(szMapName, charsmax(szMapName));

	formatex(szLoadedConfig, charsmax(szLoadedConfig), "%s/tokenwpremover/%s.ini", szPath, szMapName);

	new szFilePointer = fopen(szLoadedConfig, "rt");
	if(!szFilePointer)
	{
		formatex(szLoadedConfig, charsmax(szLoadedConfig), "%s/tokenwpremover/default.ini", szPath);
		
		if(!(szFilePointer = fopen(szLoadedConfig, "rt")))
			set_fail_state("Configs not read :(");
	}

	new szWeaponModel[64], szWeapon[32];

	new Trie:tModels = TrieCreate();

	while(!feof(szFilePointer))
	{
		fgets(szFilePointer, szWeapon, charsmax(szWeapon));
		trim(szWeapon);

		if(!szWeapon[0] || szWeapon[0] == ';'
			|| (szWeapon[0] == '/' && szWeapon[1] == '/') )
			continue;

		formatex(szWeaponModel,charsmax(szWeaponModel),"models/w_%s.mdl",szWeapon);

		TrieSetCell(tModels, szWeaponModel, 0);
	}
	fclose(szFilePointer);

	new szModel[64], WepID = MaxClients;
	while((WepID = rg_find_ent_by_class(WepID,"armoury_entity")) != 0)
	{
		get_entvar(WepID, var_model, szModel, charsmax(szModel));

		if(TrieKeyExists(tModels, szModel)) {
			set_entvar(WepID, var_flags, get_entvar(WepID, var_flags) | FL_KILLME);
			//set_entvar(WepID, var_nextthink, get_gametime());
		}
	}

	TrieDestroy(tModels);
}

public OnConfigsExecuted()
{
	new inf[64], t_prim[64], t_sec[64], ct_prim[64], ct_sec[64];
	get_cvar_string("mc_mp_infinite", inf, 63);
	get_cvar_string("mc_mp_t_wp_primary", t_prim, 63);
	get_cvar_string("mc_mp_t_wp_secondary", t_sec, 63);
	get_cvar_string("mc_mp_ct_wp_primary", ct_prim, 63);
	get_cvar_string("mc_mp_ct_wp_secondary", ct_sec, 63);

	set_cvar_string("mp_round_infinite", inf);													// Бесконечный раунд
	set_cvar_num("mp_give_player_c4", g_Cvar[MC_MP_GIVE_C4]);									// Запрет выдачи бомбы
	set_cvar_num("mp_infinite_ammo", g_Cvar[MC_MP_INF_AMMO]);									// Пополнение патронов
	set_cvar_float("mp_forcerespawn", g_Cvar[MC_MP_FORCERSPAWN]);								// Автоматический респавн игрока после смерти
	set_cvar_float("mp_respawn_immunitytime", g_Cvar[MC_MP_SPAWNPROTECTIONTIME]);				// Защита после респавна
	set_cvar_num("mp_item_staytime", g_Cvar[MC_MP_STIME]);										// Время,через которое будут удаляться item'ы (Оружия),дропнутые игроком
	set_cvar_string("mp_t_default_weapons_primary", t_prim);									// Выдача основного оружия террористам
	set_cvar_string("mp_t_default_weapons_secondary", t_sec);									// Выдача запасного оружия террористам
	set_cvar_string("mp_ct_default_weapons_primary", ct_prim);									// Выдача основного оружия контр - террористам
	set_cvar_string("mp_ct_default_weapons_secondary", ct_sec);									// Выдача запасного оружия контр - террористам
}
#endif

public client_disconnected(id)	giCurrentKills[id] = 0;

public RoundStart_Post()
{
	new sHostName[100];
	get_user_name(0,sHostName,charsmax(sHostName));
	
	switch(g_Cvar[MC_MP_MODE])
	{
		case 0:	set_task(1.0,"StartVote");
		case 1:	client_print_color(0, -2, "%L %L", LANG_PLAYER, "MC_PREFIX", LANG_PLAYER, "MC_NORMAL", sHostName);
		case 2: 
		{
			StartHardToken();
			client_print_color(0, -2, "%L %L", LANG_PLAYER, "MC_PREFIX", LANG_PLAYER, "MC_HARDCORE", sHostName);
		}
	}
}

public CBasePlayer_Spawn_Post(const id)
{
	if(get_member_game(m_bCompleteReset))
		bTokenHardcore = false;

	if(!is_user_alive(id))
		return;

	if(is_user_connected(id) && g_iFrozen == 1)
		FrozenUsers(0);

	if(bTokenHardcore)
		set_entvar(id, var_health, g_Cvar[MC_MP_LIVE_USER]);									// Устанавливаем сколько HP давать каждому игроку
		
	ProcessDigit(id, .reset = true);															// Обнуление собранных жетонов
}

public CBasePlayer_Killed_Post(pVictim, pAttacker, pGib)
{
	new Float: vecOrigin[3];
	new Float: vecVelocity[3];

	get_entvar(pVictim, var_origin, vecOrigin);
	vecOrigin[2] -= 25.0;
	iEntity = rg_create_entity("info_target", false);

	if (is_nullent(iEntity))
		return;

	vecVelocity[0] = random_float(-200.0, 200.0);
	vecVelocity[1] = random_float(-200.0, 200.0);
	vecVelocity[2] = random_float(1.0, 200.0);
	
	new TeamName:iTeam = get_member(pVictim, m_iTeam);
	
	set_entvar(iEntity, var_model, TOKEN_MDL);
	set_entvar(iEntity, var_modelindex, g_TokenMdl);
	set_entvar(iEntity, var_classname, "token");
	set_entvar(iEntity, var_skin, iTeam == TEAM_CT ? 1 : 2);

	set_entvar(iEntity, var_framerate, 1.0);
	set_entvar(iEntity, var_sequence, 0);
	set_entvar(iEntity, var_animtime, get_gametime() + 0.5);

	set_entvar(iEntity, var_origin, vecOrigin);
	set_entvar(iEntity, var_movetype, MOVETYPE_TOSS);
	set_entvar(iEntity, var_solid, SOLID_TRIGGER);
	set_entvar(iEntity, var_velocity, vecVelocity);
	set_entvar(iEntity, var_nextthink, get_gametime() + g_Cvar[MC_MP_LIVE_MDL]);
	set_entvar(iEntity, var_owner, pVictim);

	SetThink(iEntity, "Token_Think");
	SetTouch(iEntity, "Token_Touch");
	
	if(IsPlayer(pAttacker) && (get_member(pAttacker, m_iTeam) == iTeam))
	{
		g_iUserTK[pAttacker] = get_member(pAttacker, m_iTeamKills);

		switch(g_iUserTK[pAttacker])
		{
			case 1:	client_print_color(pAttacker, -2, "%L", LANG_PLAYER, "MC_USERTK");
			case 2: client_print_color(pAttacker, -2, "%L", LANG_PLAYER, "MC_USERTK1");
		}

		if(g_iUserTK[pAttacker] >= 3)
		{
			set_dhudmessage(200, 0, 0, -1.0, 0.03, 0, 5.0, 5.0);
			show_dhudmessage(pAttacker, "%L", LANG_PLAYER, "MC_USERTK2");
		}
	}
}

public TakeDamage_Pre(const pevVictim, pevInflictor, pevAttacker, Float:flDamage, bitsDamageType)
{
	if(!is_user_connected(pevVictim) || !is_user_connected(pevAttacker)) return	HC_CONTINUE;
	if(get_member(pevVictim, m_iTeam) == get_member(pevAttacker, m_iTeam))
	{
		if((bitsDamageType & DMG_BULLET) && (g_iUserTK[pevAttacker] >= 3))
		{
			user_silentkill(pevAttacker);
			SetHookChainReturn(ATYPE_INTEGER, 0);				
			return HC_SUPERCEDE;
		}
	}
	return HC_CONTINUE;
}

public Token_Think(pEntity)
{
	if (!is_entity(pEntity))
		return;

	if (get_entvar(pEntity, var_iuser2))
	{
		new Float: fRenderAmt;
		get_entvar(pEntity, var_renderamt, fRenderAmt);

		if (fRenderAmt > 20.0)
		{
			set_entvar(pEntity, var_renderamt, fRenderAmt - 20.0);
			set_entvar(pEntity, var_nextthink, get_gametime() + 0.1);
		}
		else
			set_entvar(pEntity, var_flags, FL_KILLME);
	}
	else
	{
		//set_entvar(pEntity, var_rendermode, kRenderTransTexture);
		//set_entvar(pEntity, var_renderamt, 255.0);
		new Float:fOrigin[3];
		get_entvar(pEntity, var_origin, fOrigin);
		
		if(g_Cvar[MC_MP_SND_DELETE] > 0)
		{
			emit_sound(pEntity, CHAN_ITEM, SND_DELETE, 0.3, ATTN_NORM, 0, PITCH_NORM);
		}
			
		set_entvar(pEntity, var_iuser2, 1);
		set_entvar(pEntity, var_nextthink, get_gametime());
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
		write_byte(5);
		write_coord(floatround(fOrigin[0]));
		write_coord(floatround(fOrigin[1]));
		write_coord(floatround(fOrigin[2]));
		write_short(g_iSmoke);
		write_byte(10);
		write_byte(15);
		message_end();
	}
}

public Token_Touch(pEntity, pToucher)
{
	if (!is_entity(pEntity) || !is_user_connected(pToucher))
		return;
	
	new iOwner = get_entvar(pEntity, var_owner);

	switch(get_member(pToucher, m_iTeam))
	{
		case TEAM_CT:
		{
			switch(get_member(iOwner, m_iTeam))
			{
				case TEAM_CT:
				{
					g_iTokenTeam[pToucher]++;
			
					set_hudmessage(0, 100, 255, 0.02, 0.50, 0, 0.02, 6.0, 0.01, 0.1, -1);
					show_hudmessage(pToucher, "%L", LANG_PLAYER, "MC_TOKEN_RETURNED");
				}
				case TEAM_TERRORIST:
				{
					g_iTokenCT++;
					g_iToken[pToucher]++;
					
					set_hudmessage(0, 255, 0, 0.02, 0.52, 0, 0.02, 6.0, 0.01, 0.1, -1);
					show_hudmessage(pToucher, "%L", LANG_PLAYER, "MC_MURDER_CONFIRMED", g_iTokenCT);
					
					if ( giCurrentKills[pToucher] < 9 )	// don't process if limit of 9 is reached
						ProcessDigit( pToucher );
				}
			}
		}
		case TEAM_TERRORIST:
		{
			switch(get_member(iOwner, m_iTeam))
			{
				case TEAM_CT:
				{
					g_iTokenTT++;
					g_iToken[pToucher]++;
					
					set_hudmessage(0, 255, 0, 0.02, 0.52, 0, 0.02, 6.0, 0.01, 0.1, -1);
					show_hudmessage(pToucher, "%L", LANG_PLAYER, "MC_MURDER_CONFIRMED", g_iTokenTT);
					
					if ( giCurrentKills[pToucher] < 9 )	// don't process if limit of 9 is reached
						ProcessDigit( pToucher );
				}
				case TEAM_TERRORIST:
				{
					g_iTokenTeam[pToucher]++;
					
					set_hudmessage(0, 100, 255, 0.02, 0.50, 0, 0.02, 6.0, 0.01, 0.1, -1);
					show_hudmessage(pToucher, "%L", LANG_PLAYER, "MC_TOKEN_RETURNED");
				}
			}
		}
	}

	TouchResult(pEntity, pToucher);
}

TouchResult(pEntity, pToucher)
{
	rh_emit_sound2(pToucher, pToucher, CHAN_ITEM, SND_PICKUP, VOL_NORM, ATTN_NORM);
	set_entvar(pEntity, var_flags, FL_KILLME);

	if(g_Cvar[MC_MP_MAX_SCORE] == (get_member(pToucher, m_iTeam) == TEAM_CT ? g_iTokenCT : g_iTokenTT))
	{
		for(new i = 1; i <= MaxClients ; i++)
		{
			if( g_iToken[i] == g_iTokenBest && is_user_connected(i))
				get_user_name(i, g_Name, 31);

			if(g_iToken[i] > g_iTokenBest  && is_user_connected(i))
			{
				g_iTokenBest = g_iToken[i];
				get_user_name(i, g_Name, 31);
			}

			if( g_iTokenTeam[i] == g_iTokenBests && is_user_connected(i))
				get_user_name(i, g_Namer, 31);

			if( g_iTokenTeam[i] > g_iTokenBests  && is_user_connected(i))
			{
				g_iTokenBests = g_iTokenTeam[i];
				get_user_name(i, g_Namer, 31);
			}
		}

		StopToken();
		ScreenFade(1);
		FrozenUsers(1);
		set_task(1.0, "showMotd");
		GiveBonuses();
		set_task(7.0, "intermission");
	}
}

public Task_HudMsg()
{
	set_dhudmessage(255, 255, 255, -1.0, 0.01, 0, 0.1, 1.0, 0.0, 0.0);
	show_dhudmessage(0, "%d | %d | %d", g_iTokenCT, g_Cvar[MC_MP_MAX_SCORE], g_iTokenTT);
}

#if !defined CSDM
public CBasePlayer_SetSpawnProtection_Post(id)
{
	if(!is_user_alive(id))
		return HC_CONTINUE;

	set_member(id, m_flSpawnProtectionEndTime, get_gametime() + g_Cvar[MC_MP_SPAWNPROTECTIONTIME]);

	if(g_Cvar[MC_MP_SPAWNPROTECTIONTIME] > 0)
	{
		CCSPlayer_SetProtectionOnSpawn(id);
		return HC_SUPERCEDE;
	}
	
	return HC_CONTINUE;
}

public CBasePlayer_RemoveSpawnProtection_Post(id)
{
	if(!is_user_alive(id))
		return;

	if(g_Cvar[MC_MP_SPAWNPROTECTIONTIME] > 0.0
		&& g_flProtectionOnSpawnStartTime[id] > 0.0
		&& get_gametime() > (g_flProtectionOnSpawnStartTime[id] + g_Cvar[MC_MP_SPAWNPROTECTIONTIME])
		|| IsUserMoved(id))
	{
		CCSPlayer_RemoveProtectionOnSpawn(id);
	}	
}
#endif

public StartVote()
{
	new szMenu[256], iLen, iKeys = MENU_KEY_1|MENU_KEY_2;
	iLen = formatex(szMenu, charsmax(szMenu), "%L", LANG_PLAYER, "MC_SELECT_GAME");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%L", LANG_PLAYER, "MC_SELECT_1");
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "%L", LANG_PLAYER, "MC_SELECT_2");

	ScreenFade(1);
	FrozenUsers(1);

	set_task(float(10), "CheckResult");
	return show_menu(0, iKeys, szMenu, 10, "TOKEN");
}

public NPMHandler(id, iKey)
{
	new name [32];
	get_user_name(id, name, 31);

	switch(iKey)
	{
		case 0:
		{
			iSelectKey[0]++;
			client_print_color(0, -2, "%L %L", LANG_PLAYER, "MC_PREFIX", LANG_PLAYER, "MC_NORMAL", name);
		}
		case 1:
		{
			iSelectKey[1]++;
			client_print_color(0, -2, "%L %L", LANG_PLAYER, "MC_PREFIX", LANG_PLAYER, "MC_HARDCORE", name);
		}
	}

	return HC_SUPERCEDE;
}

public CheckResult()
{
	if(iSelectKey[0] > iSelectKey[1])
	{
		client_print_color(0, -2, "%L %L", LANG_PLAYER, "MC_PREFIX", LANG_PLAYER, "MC_NORMAL_RESULT");
		ScreenFade(0);
		FrozenUsers(0);
		return;
	}
	if(iSelectKey[1] > iSelectKey[0])
	{
		client_print_color(0, -2, "%L %L", LANG_PLAYER, "MC_PREFIX", LANG_PLAYER, "MC_HARD_RESULT");
		StartHardToken();
		ScreenFade(0);
		FrozenUsers(0);
		return;
	}
	if((!iSelectKey[0] && !iSelectKey[1]) || (iSelectKey[0] == iSelectKey[1]))
	{
		switch(random_num(0,1))
		{
			case 0:
			{
				client_print_color(0, -2, "%L %L", LANG_PLAYER, "MC_PREFIX", LANG_PLAYER, "MC_N_DONT_RESULT");
				ScreenFade(0);
				FrozenUsers(0);
				return;
			}
			case 1:
			{
				client_print_color(0, -2, "%L %L", LANG_PLAYER, "MC_PREFIX", LANG_PLAYER, "MC_H_DONT_RESULT");
				ScreenFade(0);
				FrozenUsers(0);
				StartHardToken();
				return;
			}
		}
	}

	arrayset(iSelectKey, 0, sizeof iSelectKey);
}

ProcessDigit( id, bool:reset = false ) {
	static szSpriteNames[][] = {
		"number_0",
		"number_1",
		"number_2",
		"number_3",
		"number_4",
		"number_5",
		"number_6",
		"number_7",
		"number_8",
		"number_9"
	}

	// set digits color
	static iColor[3] = {
		0,		// red
		160,	// green
		0		// blue
	}

	// hide current digit
	if ( giCurrentKills[id] ) { 	// hiding doesn't needed if there was 0 frags
		message_begin( MSG_ONE_UNRELIABLE, gMsgStatusIcon, _, id )
		write_byte(0) // status: 0 - off, 1 - on, 2 - flash
		write_string( szSpriteNames[ giCurrentKills[id] ] ) // sprite name
		message_end()
	}

	if ( reset ) {
		giCurrentKills[id] = 0
		return
	}

	// show new digit
	message_begin( MSG_ONE_UNRELIABLE, gMsgStatusIcon, _, id )
	write_byte( 1 ) // status: 0 - off, 1 - on, 2 - flash
	write_string( szSpriteNames[ ++giCurrentKills[id] ] ) // sprite name
	write_byte( iColor[0] )
	write_byte( iColor[1] )
	write_byte( iColor[2] )
	message_end()
}

StartHardToken()
{
	set_cvar_float("ff_damage_reduction_bullets", g_Cvar[MC_MP_BULLETS_DMG]);											// Уменьшение урона по товарищам при выстреле
	set_cvar_float("ff_damage_reduction_grenade", g_Cvar[MC_MP_GRENADE_DMG]);											// Уменьшение урона по товарищам от гранаты
	set_cvar_float("ff_damage_reduction_other", g_Cvar[MC_MP_OTHER_DMG]);												// Уменьшение урона по товарищам от других типов нанесения урона
	set_cvar_num("mp_friendlyfire", 1);																					// Урон по союзникам

	bTokenHardcore = true;
	for(new id = 1; id <= MaxClients ; id++)
		user_silentkill(id);
}

public showMotd()
{
	new motd[MAX_MOTD_LENGTH];
	new len = formatex(
		motd, charsmax(motd),
		"<!DOCTYPE html>^n<html lang='ru'><head><meta charset='utf-8'><link rel='stylesheet' href='%s/win_motd.css'></head>",
		STYLES_URL
	);

	new hostname[64];
	get_cvar_string("hostname",hostname,63);
	len += formatex(motd[len], charsmax(motd) - len, "<body><h3>%s</h3>", hostname);

	if(g_iTokenCT == g_Cvar[MC_MP_MAX_SCORE])
	{
		len += formatex(
			motd[len], charsmax(motd) - len,
			"<hr class='ct'><div class='ct'>Команда <span class='name'>СПЕЦНАЗА</span> победила!</div><hr class='ct'>"
		);
		len += formatex(
			motd[len], charsmax(motd) - len,
			"<font class='ct'>Каждый участник команды получает: %i бонусов и %d опыта</font>",
			g_Cvar[MC_MP_BONUS_FOR_WINTEAM], floatround(g_Cvar[MC_MP_EXP_FOR_WINTEAM])
		);
	}
	else if(g_iTokenTT == g_Cvar[MC_MP_MAX_SCORE])
	{
		len += formatex(
			motd[len], charsmax(motd) - len,
			"<hr class='tt'><div class='tt'>Команда <span class='name'>ТЕРРОРИСТОВ</span> победила!</div><hr class='tt'>"
		);
		len += formatex(
			motd[len], charsmax(motd) - len,
			"<font class='tt'>Каждый участник команды получает: %i бонусов и %d опыта</font>",
			g_Cvar[MC_MP_BONUS_FOR_WINTEAM], floatround(g_Cvar[MC_MP_EXP_FOR_WINTEAM])
		);
	}
	else if(g_iTokenCT == g_Cvar[MC_MP_MAX_SCORE] || g_iTokenTT == g_Cvar[MC_MP_MAX_SCORE])
	{
		len += formatex(
			motd[len], charsmax(motd) - len,
			"<hr class='spec'><div class='spec'><span class='name'>НИЧЬЯ</span></div><hr class='spec'>"
		);
		len += formatex(
			motd[len], charsmax(motd) - len,
			"<font class='spec'>Награда делится на пополам, для обеих команд</font>"
		);
	}
	len += formatex(
		motd[len], charsmax(motd) - len,
		"<center><table><tr><th><div class='map'><img src='%s/maps/%s.jpg'></div></th>",
		STYLES_URL, current_map
	);

	len += formatex(
		motd[len], charsmax(motd) - len,
		"<th><ul class='info'><li>Карта <font color='00CC00'>%s</font></li><li>Игроков на карте <font color='00CC00'>[%d]</font></li>",
		current_map, get_playersnum()
	);

	len += formatex(
		motd[len], charsmax(motd) - len,
		"<li>Жетонов у спецназа <font color='#1E90FF'>[%d]</font></li><li>Жетонов у террористов <font color='#FF0000'>[%d]</font></li>",
		g_iTokenCT, g_iTokenTT
		);

	len += formatex(
		motd[len], charsmax(motd) - len,
		"<hr class='spec'><div class='spec'>Лидер по сбору <span class='name'>%s</span><br>Он набрал <span class='name'>%d</span> жетонов<br>",
		g_Name, g_iTokenBest
		);

	len += formatex(
		motd[len], charsmax(motd) - len,
		"Лидер по спасению <span class='name'>%s</span><br>Он спас <span class='name'>%d</span> жетонов своей команды</div>",
		g_Namer, g_iTokenBests
		);
	formatex(motd[len], charsmax(motd) - len, "</body></html>");

	new players[MAX_PLAYERS], num;
	get_players(players, num, "ch");
	for (new i = 0; i < num; i++)
		show_motd(players[i], motd, "Конец карты");

}

public intermission()
{
    emessage_begin(MSG_ALL, SVC_INTERMISSION);
    emessage_end();
}

public GiveBonuses()
{	
	if(get_playersnum() > g_MinPlayers) 
	{
		new players[MAX_PLAYERS], num;
		get_players(players, num, "ch");

		for(new i, player; i < num; i++) 
		{
			player = players[i];

			switch(get_member(player, m_iTeam)) 
			{
				case TEAM_CT: 
				{
					if(g_iCTWins > g_iTTWins) 
					{
						aes_add_player_exp_f(player, g_Cvar[MC_MP_EXP_FOR_WINTEAM]);
						aes_add_player_bonus_f(player, g_Cvar[MC_MP_BONUS_FOR_WINTEAM]);
					} 
					else if(g_iCTWins < g_iTTWins) 
					{
						aes_add_player_exp_f(player, -g_Cvar[MC_MP_WITHDRAWING_EXP_LOSERS]);
						aes_add_player_bonus_f(player, -g_Cvar[MC_MP_WITHDRAWING_BONUS_LOSERS]);
					}
					else if(g_iCTWins == g_iTTWins) 
					{
						aes_add_player_exp_f(player, (g_Cvar[MC_MP_EXP_FOR_WINTEAM]/2));
						aes_add_player_bonus_f(player, (g_Cvar[MC_MP_BONUS_FOR_WINTEAM]/2));
					}
				}
				case TEAM_TERRORIST: 
				{
					if(g_iCTWins < g_iTTWins) 
					{
						aes_add_player_exp_f(player, g_Cvar[MC_MP_EXP_FOR_WINTEAM]);
						aes_add_player_bonus_f(player, g_Cvar[MC_MP_BONUS_FOR_WINTEAM]);
					}
					else if(g_iCTWins > g_iTTWins) 
					{
						aes_add_player_exp_f(player, -g_Cvar[MC_MP_WITHDRAWING_EXP_LOSERS]);
						aes_add_player_bonus_f(player, -g_Cvar[MC_MP_WITHDRAWING_BONUS_LOSERS]);
					}
					else if(g_iCTWins == g_iTTWins) 
					{
						aes_add_player_exp_f(player, (g_Cvar[MC_MP_EXP_FOR_WINTEAM]/2));
						aes_add_player_bonus_f(player, (g_Cvar[MC_MP_BONUS_FOR_WINTEAM]/2));
					}
				}
			}
		}
	}
}

StopToken()
{
	for(new i; i < sizeof(cvars); i++) 
		set_cvar_string(cvars[i], values[i]);
}

public ScreenFade(fade)
{
	new flags;
	new time = (0 <= fade <= 1) ? 4096 : 1;
	new hold = (0 <= fade <= 1) ? 1024 : 1;
	static mScreenFade; if(!mScreenFade) mScreenFade = get_user_msgid("ScreenFade");

	switch(fade)
	{
		case 0:
		{
			flags = 2;
			set_msg_block(mScreenFade, BLOCK_NOT);
		}
		case 1:
		{
			flags = 1;
			set_task(1.0, "ScreenFade", 2);
		}
		case 2:
		{
			flags = 4;
			set_msg_block(mScreenFade, BLOCK_SET);
		}
	}

	message_begin(MSG_ALL, mScreenFade);
	write_short(time);
	write_short(hold);
	write_short(flags);
	write_byte(0);
	write_byte(0);
	write_byte(0);
	write_byte(255);
	message_end();
}

FrozenUsers(frozen)
{	
	g_iFrozen = frozen;
	new players[MAX_PLAYERS]; new pnum;
	get_players(players, pnum);

	for(new i; i < pnum; ++i)
		set_entvar(players[i], var_flags, frozen == 1 ? get_entvar(players[i], var_flags) | FL_FROZEN : get_entvar(players[i], var_flags) & ~FL_FROZEN);
}

#if !defined CSDM
CCSPlayer_SetProtectionOnSpawn(id)
{
    set_entvar(id, var_takedamage, DAMAGE_NO);
    set_entvar(id, var_rendermode, kRenderTransAdd);
    set_entvar(id, var_renderamt, 100.0);

    g_flProtectionOnSpawnStartTime[id] = get_gametime();
}

CCSPlayer_RemoveProtectionOnSpawn(id)
{
    set_entvar(id, var_takedamage, DAMAGE_AIM);
    set_entvar(id, var_rendermode, kRenderNormal);

    g_flProtectionOnSpawnStartTime[id] = 0.0;
}
#endif

RegisterCvars()
{
	bind_pcvar_num(
		create_cvar(
			.name = "mc_mp_mode",
			.string = "0",
			.flags = FCVAR_SERVER,
			.description = fmt("%l", "MC_CVAR_MP_MODE"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_MODE]
	);
	bind_pcvar_num(
		create_cvar(
			.name = "mc_mp_max_score",
			.string = "100",
			.flags = FCVAR_SERVER,
			.description = fmt("%l", "MC_CVAR_MP_MAX_SCORE"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_MAX_SCORE]
	);
#if !defined CSDM
	bind_pcvar_string(
		create_cvar(
		  .name = "mc_mp_infinite",
		  .string = "aef",
		  .flags = FCVAR_SERVER,
		  .description = fmt("%l", "MC_CVAR_MP_INFINITE")
		  ), g_Cvar[MC_MP_INFINITE], charsmax(g_Cvar[MC_MP_INFINITE])
	);
	bind_pcvar_num(
		create_cvar(
			.name = "mc_mp_give_c4",
			.string = "0",
			.flags = FCVAR_SERVER,
			.description = fmt("%l", "MC_CVAR_MP_GIVE_C4"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_GIVE_C4]
	);
	bind_pcvar_num(
		create_cvar(
			.name = "mc_mp_inf_ammo",
			.string = "2",
			.flags = FCVAR_SERVER,
			.description = fmt("%l", "MC_CVAR_MP_INF_AMMO"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_INF_AMMO]
	);
	bind_pcvar_num(
		create_cvar(
			.name = "mc_mp_stime",
			.string = "2",
			.flags = FCVAR_SERVER,
			.description = fmt("%l", "MC_CVAR_MP_STIME"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_STIME]
	);
	bind_pcvar_float(
		create_cvar(
			.name = "mc_mp_forcerspawn",
			.string = "0.3",
			.flags = FCVAR_SERVER,
			.description =  fmt("%l", "MC_CVAR_MP_FORCERSPAWN"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_FORCERSPAWN]
	);
	bind_pcvar_string(
		create_cvar(
		  .name = "mc_mp_t_wp_primary",
		  .string = "ak47",
		  .flags = FCVAR_SERVER,
		  .description = fmt("%l", "MC_CVAR_MP_T_WP_PRIMARY")
		  ), g_Cvar[MC_MP_T_WP_PRIMARY], charsmax(g_Cvar[MC_MP_T_WP_PRIMARY])
	);
	bind_pcvar_string(
		create_cvar(
		  .name = "mc_mp_t_wp_secondary",
		  .string = "deagle",
		  .flags = FCVAR_SERVER,
		  .description = fmt("%l", "MC_CVAR_MP_T_WP_SECONDARY")
		  ), g_Cvar[MC_MP_T_WP_SECONDARY], charsmax(g_Cvar[MC_MP_T_WP_SECONDARY])
	);
	bind_pcvar_string(
		create_cvar(
		  .name = "mc_mp_ct_wp_primary",
		  .string = "m4a1",
		  .flags = FCVAR_SERVER,
		  .description = fmt("%l", "MC_CVAR_MP_CT_WP_PRIMARY")
		  ), g_Cvar[MC_MP_CT_WP_PRIMARY], charsmax(g_Cvar[MC_MP_CT_WP_PRIMARY])
	);
	bind_pcvar_string(
		create_cvar(
		  .name = "mc_mp_ct_wp_secondary",
		  .string = "deagle",
		  .flags = FCVAR_SERVER,
		  .description = fmt("%l", "MC_CVAR_MP_CT_WP_SECONDARY")
		  ), g_Cvar[MC_MP_CT_WP_SECONDARY], charsmax(g_Cvar[MC_MP_CT_WP_SECONDARY])
	);
	bind_pcvar_float(
		create_cvar(
			.name = "mc_mp_spawnprotectiontime",
			.string = "2.0",
			.flags = (FCVAR_SERVER | FCVAR_SPONLY),
			.description =  fmt("%l", "MC_CVAR_MP_SPAWNPROTECTIONTIME"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_SPAWNPROTECTIONTIME]
	);
#endif
	bind_pcvar_float(
		create_cvar(
			.name = "mc_mp_live_mdl",
			.string = "5.0",
			.flags = (FCVAR_SERVER | FCVAR_SPONLY),
			.description =  fmt("%l", "MC_CVAR_MP_LIVE_MDL"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_LIVE_MDL]
	);
	bind_pcvar_num(
		create_cvar(
			.name = "mc_mp_snd_delete",
			.string = "1",
			.flags = FCVAR_SERVER,
			.description = fmt("%l", "MC_CVAR_MP_SND_DELETE"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_SND_DELETE]
	);
	bind_pcvar_float(
		create_cvar(
			.name = "mc_mp_live_user",
			.string = "25.0",
			.flags = FCVAR_SERVER,
			.description =  fmt("%l", "MC_CVAR_MP_LIVE_USER"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_LIVE_USER]
	);
	bind_pcvar_float(
		create_cvar(
			.name = "mc_mp_bullets_dmg",
			.string = "1.0",
			.flags = FCVAR_SERVER,
			.description =  fmt("%l", "MC_CVAR_MP_BULLETS_DMG"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_BULLETS_DMG]
	);
	bind_pcvar_float(
		create_cvar(
			.name = "mc_mp_grenade_dmg",
			.string = "1.0",
			.flags = FCVAR_SERVER,
			.description =  fmt("%l", "MC_CVAR_MP_GRENADE_DMG"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_GRENADE_DMG]
	);
	bind_pcvar_float(
		create_cvar(
			.name = "mc_mp_other_dmg",
			.string = "1.0",
			.flags = FCVAR_SERVER,
			.description =  fmt("%l", "MC_CVAR_MP_OTHER_DMG"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_OTHER_DMG]
	);
	bind_pcvar_num(
		create_cvar(
			.name = "mc_mp_bonus_for_winteam",
			.string = "1",
			.flags = FCVAR_SERVER,
			.description = fmt("%l", "MC_CVAR_MP_BONUS_FOR_WINTEAM"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_BONUS_FOR_WINTEAM]
	);
	bind_pcvar_float(
		create_cvar(
			.name = "mc_mp_exp_for_winteam",
			.string = "5.0",
			.flags = FCVAR_SERVER,
			.description = fmt("%l", "MC_CVAR_MP_EXP_FOR_WINTEAM"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_EXP_FOR_WINTEAM]
	);
	bind_pcvar_num(
		create_cvar(
			.name = "mc_mp_withdrawing_bonus_losers",
			.string = "1",
			.flags = FCVAR_SERVER,
			.description = fmt("%l", "MC_CVAR_MP_WITHDRAWING_BONUS_LOSERS"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_WITHDRAWING_BONUS_LOSERS]
	);
	bind_pcvar_float(
		create_cvar(
			.name = "mc_mp_withdrawing_exp_losers",
			.string = "5.0",
			.flags = FCVAR_SERVER,
			.description = fmt("%l", "MC_CVAR_MP_WITHDRAWING_EXP_LOSERS"),
			.has_min = true,
			.min_val = 0.0
		), g_Cvar[MC_MP_WITHDRAWING_EXP_LOSERS]
	);
}