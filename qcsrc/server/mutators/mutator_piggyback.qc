.float cvar_cl_nocarry;

entity pb_TailOf(entity p)
{
	while(p.piggybacker)
		p = p.piggybacker;
	return p;
}

entity pb_RootOf(entity p)
{
	while(p.pbhost)
		p = p.pbhost;
	return p;
}

.float pb_oldmoveflags;
.float pb_oldverticalfly;
void pb_Attach(entity host, entity slave)
{
	entity root = pb_RootOf(host);
	host = pb_TailOf(host);
	
	if(host == slave || root == slave || host == slave.piggybacker || slave == host.piggybacker)
		return;
	
	host.piggybacker = slave;
	slave.movetype = MOVETYPE_FOLLOW;
	slave.aiment = host.pbent;
	slave.pbhost = host;
	slave.pb_oldsolid = slave.solid;
	slave.solid = SOLID_CORPSE;
	slave.pb_canattach = 0;

	if(IS_MONSTER(host))
	{
		host.pb_oldmoveflags = host.monster_moveflags;
		host.pb_oldverticalfly = (host.spawnflags & MONSTERFLAG_FLY_VERTICAL);
		host.spawnflags |= MONSTERFLAG_FLY_VERTICAL;
		host.monster_moveflags = MONSTER_MOVE_NOMOVE;
	}
	
	RemoveGrapplingHook(slave);
	
	Send_Notification(NOTIF_ONE, slave, MSG_CENTER, CENTER_PIGGYBACK_RIDING, (IS_MONSTER(host)) ? host.monster_name : host.netname);
	if(IS_PLAYER(host))
		Send_Notification(NOTIF_ONE, host, MSG_CENTER, CENTER_PIGGYBACK_CARRYING, slave.netname);
}

void pb_Detach(entity host)
{
	entity slave = host.piggybacker;
	
	if(!slave)
		return;
	
	slave.aiment = world;
	slave.pbhost = world;

	if(IS_MONSTER(host))
	{
		host.monster_moveto = '0 0 0';
		host.monster_moveflags = host.pb_oldmoveflags;
		if(!host.pb_oldverticalfly) { host.spawnflags &= ~MONSTERFLAG_FLY_VERTICAL; }
	}
	
	if(IS_PLAYER(slave))
	{
		// this doesn't happen when we're fixing a broken reference
		
		if(slave.movetype == MOVETYPE_FOLLOW) // don't reset if player was killed
			slave.movetype = MOVETYPE_WALK;
		slave.velocity = '0 0 0';
		slave.solid = slave.pb_oldsolid;
		
		tracebox(host.origin, slave.mins, slave.maxs, slave.origin, MOVE_NOMONSTERS, slave);
		
		if(trace_fraction < 1)
			setorigin(slave, trace_endpos); // fix player glitching out of the world
		
		Kill_Notification(NOTIF_ONE, slave, MSG_CENTER_CPID, CPID_PIGGYBACK);
		if(IS_PLAYER(host))
			Kill_Notification(NOTIF_ONE, host, MSG_CENTER_CPID, CPID_PIGGYBACK);
	}
	
	host.piggybacker = world;
}

void pb_PBEntThink()
{
	setorigin(self, self.owner.origin + '0 0 0.82' * self.owner.maxs_z);
	self.nextthink = time;
}

void pb_FixPBEnt(entity p)
{
	entity e = spawn();
	e.owner = p;
	e.classname = "pb_ent";
	e.think = pb_PBEntThink;
	e.nextthink = time;
	p.pbent = e;
}

#define BROKEN_PBREF(e) ((e).piggybacker && ((e).piggybacker.pbhost != (e) || (e).piggybacker.movetype != MOVETYPE_FOLLOW))

MUTATOR_HOOKFUNCTION(pb_MatchEnd)
{
	entity head;
	FOR_EACH_PLAYER(head) { pb_Detach(head); }
	FOR_EACH_MONSTER(head) { pb_Detach(head); }
	return FALSE;
}

MUTATOR_HOOKFUNCTION(pb_PlayerUseKey)
{
	if(MUTATOR_RETURNVALUE || gameover) { return FALSE; }
	
	if(self.pbhost)
	{
		pb_Detach(self.pbhost);
		return TRUE;
	}
	if(self.piggybacker)
	{
		pb_Detach(self);
		return TRUE;
	}

	if(!self.frozen)
	if(self.deadflag == DEAD_NO)
	if(!self.vehicle)
	{
		entity head, closest_target = world;

		head = WarpZone_FindRadius(self.origin, autocvar_g_vehicles_enter_radius, TRUE);
		while(head)
		{
			if(IS_PLAYER(head) || (IS_MONSTER(head) && ((get_monsterinfo(head.monsterid)).spawnflags & MON_FLAG_RIDE)))
			if(SAME_TEAM(head, self) || autocvar_g_piggyback_ride_enemies || (IS_MONSTER(head) && head.realowner == self))
			if(head != self)
			if(!head.cvar_cl_nocarry)
			if(head.deadflag == DEAD_NO)
			if(!head.vehicle)
			if(!head.frozen)
			if((!head.jb_isprisoned && !self.jb_isprisoned) || (head.jb_isprisoned && self.jb_isprisoned))
			{
				if(closest_target)
				{
					if(vlen(self.origin - head.origin) < vlen(self.origin - closest_target.origin))
					{ closest_target = head; }
				}
				else { closest_target = head; }
			}
			
			head = head.chain;
		}

		if(closest_target)
		if(IS_BOT_CLIENT(closest_target)) { pb_Attach(self, closest_target); return TRUE; }
		else { pb_Attach(closest_target, self); return TRUE; }
	}

	return FALSE;
}

MUTATOR_HOOKFUNCTION(pb_PlayerThink)
{
	if(BROKEN_PBREF(self)) { pb_Detach(self); }
	
	if(!self.pbent)
		pb_FixPBEnt(self);

	if(IS_MONSTER(self.pbhost))
	if(self.movement || (self.BUTTON_JUMP || self.BUTTON_CROUCH))
	if(!self.pbhost.enemy)
	{
		float forw, rit, updown = 0;
		vector wishvel = '0 0 0';

		makevectors(self.angles);
		if(self.BUTTON_JUMP)
			updown = 500;
		else if(self.BUTTON_CROUCH)
			updown = -500;

		if(self.movement)
		{
			forw = self.movement_x * 500;
			rit = self.movement_y * 500;
			//updown = self.movement_z * 100;
			
			wishvel = v_forward * forw + v_right * rit;
		}
		
		//vector wishvel = normalize(('10 0 0' + v_forward * self.movement_x) + ('0 10 0' + v_right * self.movement_y) + ('0 0 1' * self.movement_z));
		//print(vtos(self.origin), vtos(self.origin + wishvel), "\n");
		self.pbhost.monster_moveto = self.origin + wishvel;
		self.pbhost.monster_moveto_z = v_up_z * updown;
	}

	return FALSE;
}

MUTATOR_HOOKFUNCTION(pb_MonsterThink)
{
	if(BROKEN_PBREF(self)) { pb_Detach(self); }
	
	if(!self.pbent)
		pb_FixPBEnt(self);

	return FALSE;
}

MUTATOR_HOOKFUNCTION(pb_ResetMap)
{
	FOR_EACH_PLAYER(self) { pb_Detach(self); }
	return FALSE;
}

MUTATOR_HOOKFUNCTION(pb_RemovePlayer)
{
	if(self.piggybacker)
	{
		self.piggybacker.pb_canattach = 1;
		pb_Detach(self);
	}
	
	if(self.pbhost)
		pb_Detach(self.pbhost);
	self.pb_canattach = 0;

	return FALSE;
}

MUTATOR_HOOKFUNCTION(pb_PlayerDies)
{
	if(!self.pbhost && self.pb_canattach)
		self.pb_canattach = 0;
		
	if(self.piggybacker)
	{
		self.piggybacker.pb_canattach = 1;
		pb_Detach(self);
	}
	
	if(self.pbhost)
		pb_Detach(self.pbhost);
	self.pb_canattach = 0;
	
	return FALSE;
}

MUTATOR_HOOKFUNCTION(pb_ItemTouch)
{
	if(self.weapon)
	if(other.piggybacker)
	if(other.weapons & self.weapons)
	{
		entity p = other;
		while(p.piggybacker)
		{
			p = p.piggybacker;
			if(!(p.weapons & self.weapons))
			{
				other = p;
				break;
			}
		}
	}

	return FALSE;
}

MUTATOR_HOOKFUNCTION(pb_GetCvars)
{
	GetCvars_handleFloat(get_cvars_s, get_cvars_f, cvar_cl_nocarry, "cl_nocarry");
	return FALSE;
}

MUTATOR_DEFINITION(mutator_piggyback)
{
	MUTATOR_HOOK(MatchEnd, pb_MatchEnd, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerUseKey, pb_PlayerUseKey, CBC_ORDER_LAST);
	MUTATOR_HOOK(PlayerPreThink, pb_PlayerThink, CBC_ORDER_ANY);
	MUTATOR_HOOK(MonsterMove, pb_MonsterThink, CBC_ORDER_ANY);
	MUTATOR_HOOK(reset_map_players, pb_ResetMap, CBC_ORDER_FIRST);
	MUTATOR_HOOK(MakePlayerObserver, pb_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(ClientDisconnect, pb_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerDies, pb_PlayerDies, CBC_ORDER_ANY);
	MUTATOR_HOOK(MonsterDies, pb_PlayerDies, CBC_ORDER_ANY);
	MUTATOR_HOOK(MonsterRemove, pb_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(ItemTouch, pb_ItemTouch, CBC_ORDER_ANY);
	MUTATOR_HOOK(GetCvars, pb_GetCvars, CBC_ORDER_ANY);

	return FALSE;
}
