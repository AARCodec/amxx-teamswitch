/**/
	public stock const PluginAuthor[]		=	"AARTronic";
	public stock const PluginName[]			=	"Team Switch";
	public stock const PluginDescription[]	=	"Automate team switch in a competitive environment (Per @Carl's view).";
	public stock const PluginVersion[] 		=	"0.1";
	public stock const PluginURL[] 			=	"AARTronic @Discord";
	public stock const PluginTag[]			= 	"[^4Team Switch^1]";
/**/

#include <amxmodx>
#include <hamsandwich>
#include <reapi>

#if !defined MAX_MAPNAME_LENGTH
#define MAX_MAPNAME_LENGTH 64
#endif

new bool:g_bGameOver, bool:g_bSwitchTeams;
new g_pGameMaxRounds, g_pGameHalfTime, g_pGameWinLimit;

public plugin_init()
{
	bind_pcvar_num(create_cvar("mp_game_max_rounds", "15", FCVAR_SERVER, "Amount of rounds total that can be played. If no team reaches mp_game_win_limit.", true, 0.0), g_pGameMaxRounds);
	bind_pcvar_num(create_cvar("mp_game_half_time", "7", FCVAR_SERVER, "Amount of rounds to switch teams. Half time.", true, 0.0), g_pGameHalfTime);
	bind_pcvar_num(create_cvar("mp_game_win_limit", "8", FCVAR_SERVER, "Amount of rounds needed to win to win the game.", true, 0.0), g_pGameWinLimit);

	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false);
	RegisterHookChain(RG_RoundEnd, "RoundEnd", false);

	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true);
	RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "CBasePlayer_ResetMaxSpeed_Post", true);
}

public CSGameRules_RestartRound_Pre()
{
	if(!get_member_game(m_bGameStarted))
		return;

	client_print_color(0, print_team_default, "^4<<< ROUNDS PLAYED: %d >>>^1", (get_member_game(m_iTotalRoundsPlayed) + 1));
	client_print_color(0, print_team_default, "^4<<< CT %d | %d TR >>>^1", get_member_game(m_iNumCTWins), get_member_game(m_iNumTerroristWins));

	if(!g_bSwitchTeams)
		return;

	client_print_color(0, print_team_grey, "%s ^3Switching teams!^1", PluginTag);
	rg_swap_all_players();

	for(new i = 1; i <= MaxClients; i++)
	{
		if(!is_user_connected(i))
			continue;

		set_member(i, m_iAccount, 800);
		set_member(i, m_bReceivesNoMoneyNextRound, false);

		rg_add_account(i, 800, AS_SET, false);
		rg_remove_all_items(i);
		rg_give_default_items(i);
	}

	set_member_game(m_iAccountTerrorist, 0);
	set_member_game(m_iAccountCT, 0);
	set_member_game(m_iLoserBonus, 0);
	set_member_game(m_iNumConsecutiveTerroristLoses, 0);
	set_member_game(m_iNumConsecutiveCTLoses, 0);

	g_bSwitchTeams = false;
}

public RoundEnd(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay)
{
	if(!get_member_game(m_bGameStarted) || get_member_game(m_bCompleteReset))
		return HC_CONTINUE;

	if(g_pGameMaxRounds <= 0 && g_pGameWinLimit <= 0 && g_pGameHalfTime <= 0)
		return HC_CONTINUE;

	if(g_pGameWinLimit > 0 && (g_pGameWinLimit - (status == WINSTATUS_TERRORISTS ? 1 : 0)) == get_member_game(m_iNumTerroristWins))
	{
		client_print_color(0, print_team_red, "%s The ^3Terrorist team^1 won^4 %d-%d^1!", PluginTag, get_member_game(m_iNumTerroristWins), get_member_game(m_iNumCTWins));
	}
	else if(g_pGameWinLimit > 0 && (g_pGameWinLimit - (status == WINSTATUS_CTS ? 1 : 0)) == get_member_game(m_iNumCTWins))
	{
		client_print_color(0, print_team_blue, "%s The ^3Counter-Terrorist^1 team won^4 %d-%d^1!", PluginTag, get_member_game(m_iNumCTWins), get_member_game(m_iNumTerroristWins));
	}
	else if(g_pGameMaxRounds > 0 && (g_pGameMaxRounds - 1) == (get_member_game(m_iTotalRoundsPlayed) + 1))
	{
		client_print_color(0, print_team_grey, "%s ^3Game tied!^1 The maxmimum number of rounds has been reached.", PluginTag);
	}
	else
	{
		if(g_pGameHalfTime > 0 && g_pGameHalfTime == (get_member_game(m_iTotalRoundsPlayed) + 1))
			g_bSwitchTeams = true;

		return HC_CONTINUE;
	}

	g_bGameOver = true;
	client_print_color(0, print_team_grey, "%s Good Game!", PluginTag);

	for(new i = 1; i <= MaxClients; i++)
	{
		if(!is_user_alive(i))
			continue;

		CBasePlayer_Spawn_Post(i);
		CBasePlayer_ResetMaxSpeed_Post(i);
	}

	ChangeMap();

	SetHookChainArg(3, ATYPE_FLOAT, 100000.0);
	return HC_CONTINUE;
}

ChangeMap(szMap[MAX_MAPNAME_LENGTH] = "")
{
	if(szMap[0])
		set_cvar_string("amx_nextmap", szMap);

	new Entity = rg_create_entity("game_end");
	if(is_entity(Entity))
		ExecuteHamB(Ham_Use, Entity, 0, 0, 1.0, 0.0);
}

public CBasePlayer_Spawn_Post(id)
{
	if(!is_user_alive(id) || !g_bGameOver)
		return HC_CONTINUE;

	rg_remove_all_items(id);
	rg_give_item(id, "weapon_knife");

	return HC_CONTINUE;
}

public CBasePlayer_ResetMaxSpeed_Post(id)
{
	if(!g_bGameOver)
		return HC_CONTINUE;

	set_entvar(id, var_maxspeed, 0.1);
	return HC_CONTINUE;
}

