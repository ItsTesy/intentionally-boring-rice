static const unsigned int borderpx  = 1;
static const int refreshrate = 120;
static const unsigned int snap      = 32;
static const int showbar            = 0;
static const int topbar             = 0;
static const char *fonts[]          = { "JetBrainsMono Nerd Font:size=10" };
static const char col_gray1[]       = "#101010";
static const char col_gray2[]       = "#2a2a2a";
static const char col_gray3[]       = "#6a6a6a";
static const char col_gray4[]       = "#b8b8b8";
static const char col_focus[]       = "#4a4a4a";
static const char *colors[][3]      = {
	[SchemeNorm] = { col_gray3, col_gray1, col_gray2 },
	[SchemeSel]  = { col_gray4, col_gray1, col_focus },
};

static const char *tags[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9" };

static const Rule rules[] = {
	{ NULL,       NULL,       NULL,       0,            0,           -1 },
};

static const float mfact     = 0.55;
static const int nmaster     = 1;
static const int resizehints = 0;
static const int lockfullscreen = 1;

static const Layout layouts[] = {
	{ "[]=",      tile },
	{ "><>",      NULL },
	{ "[M]",      monocle },
};

#define MODKEY Mod4Mask
#define TAGKEYS(KEY,TAG) \
	{ MODKEY,                       KEY,      view,           {.ui = 1 << TAG} }, \
	{ MODKEY|ShiftMask,             KEY,      tag,            {.ui = 1 << TAG} },

#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

static char dmenumon[2] = "0";
static const char *dmenucmd[] = { "/bin/sh", "-c", "@MENU@", NULL };
static const char *termcmd[]  = { "@TERM@", NULL };

/* nothing calls into config.h at startup so this runs before main */
__attribute__((constructor)) static void autostart(void) { system("~/.config/ibr/autostart &"); }

static void
togglefullscr(const Arg *arg)
{
	if (selmon->sel)
		setfullscreen(selmon->sel, !selmon->sel->isfullscreen);
}

static void
movestack(const Arg *arg)
{
	Client *c = selmon->sel, *t = NULL, *p;

	if (!c || c->isfloating || !selmon->lt[selmon->sellt]->arrange)
		return;
	if (arg->i > 0)
		for (t = c->next; t && (!ISVISIBLE(t) || t->isfloating); t = t->next);
	else
		for (p = selmon->clients; p && p != c; p = p->next)
			if (ISVISIBLE(p) && !p->isfloating)
				t = p;
	if (!t)
		return;
	detach(c);
	if (arg->i > 0) {
		c->next = t->next;
		t->next = c;
	} else if (t == selmon->clients) {
		c->next = selmon->clients;
		selmon->clients = c;
	} else {
		for (p = selmon->clients; p->next != t; p = p->next);
		p->next = c;
		c->next = t;
	}
	arrange(selmon);
}

static const Key keys[] = {
	{ MODKEY,                       XK_Return, spawn,          {.v = termcmd } },
	{ MODKEY,                       XK_d,      spawn,          {.v = dmenucmd } },
	{ MODKEY|ShiftMask,             XK_q,      killclient,     {0} },
	{ MODKEY,                       XK_f,      togglefullscr,  {0} },
	{ MODKEY|ShiftMask,             XK_space,  togglefloating, {0} },
	{ MODKEY|ShiftMask,             XK_e,      quit,           {0} },
	{ MODKEY,                       XK_h,      focusmon,       {.i = -1 } },
	{ MODKEY,                       XK_j,      focusstack,     {.i = +1 } },
	{ MODKEY,                       XK_k,      focusstack,     {.i = -1 } },
	{ MODKEY,                       XK_l,      focusmon,       {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_h,      tagmon,         {.i = -1 } },
	{ MODKEY|ShiftMask,             XK_j,      movestack,      {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_k,      movestack,      {.i = -1 } },
	{ MODKEY|ShiftMask,             XK_l,      tagmon,         {.i = +1 } },
	TAGKEYS(                        XK_1,                      0)
	TAGKEYS(                        XK_2,                      1)
	TAGKEYS(                        XK_3,                      2)
	TAGKEYS(                        XK_4,                      3)
	TAGKEYS(                        XK_5,                      4)
	TAGKEYS(                        XK_6,                      5)
	TAGKEYS(                        XK_7,                      6)
	TAGKEYS(                        XK_8,                      7)
	TAGKEYS(                        XK_9,                      8)
	{ 0,                            XK_Print,  spawn,          SHCMD("@SHOT@") },
};

static const Button buttons[] = {
	{ ClkClientWin,         MODKEY,         Button1,        movemouse,      {0} },
	{ ClkClientWin,         MODKEY,         Button2,        togglefloating, {0} },
	{ ClkClientWin,         MODKEY,         Button3,        resizemouse,    {0} },
};
