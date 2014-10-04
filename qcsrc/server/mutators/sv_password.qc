.string cvar_cl_server_password;
.float cl_server_password_initialized;

float password_check()
{
	return autocvar_sv_usepassword && self.cvar_cl_server_password == autocvar_sv_password ;
}

MUTATOR_HOOKFUNCTION(sv_password_GetCvars)
{
	GetCvars_handleString(get_cvars_s, get_cvars_f, cvar_cl_server_password, autocvar_sv_password_cvar);
	self.cl_server_password_initialized = 1;
	return FALSE;
}

MUTATOR_HOOKFUNCTION(sv_password_ClientConnect)
{
	self.cl_server_password_initialized = 0;
	return 1;
}

MUTATOR_HOOKFUNCTION(sv_password_PlayerPreThink)
{
	if (IS_REAL_CLIENT(self))
	if ( autocvar_sv_usepassword )
	if ( self.cl_server_password_initialized )
	if ( !password_check() )
	{
		if(autocvar_sv_eventlog)
			GameLogEcho(strcat(":passwordfail:", ftos(self.playerid), ":", ftos(num_for_edict(self)), ":", self.netaddress, ":", self.netname));
		dropclient(self);
	}
	return FALSE;
}
	
MUTATOR_DEFINITION(sv_password)
{
	
	MUTATOR_HOOK(GetCvars, sv_password_GetCvars, CBC_ORDER_ANY);
	MUTATOR_HOOK(ClientConnect, sv_password_ClientConnect, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerPreThink, sv_password_PlayerPreThink, CBC_ORDER_ANY);
	return FALSE;
}

