#include <sourcemod>

#include <morecolors>
#include <clientprefs>
#include <DynamicChannels>
#include <cookiemgr>

#include <shavit/core>
#include <shavit/hud>
#include <shavit/replay-playback>

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
    name = "zSpeed",
    author = "Shahrazad, Picrisol45",
    description = "Center Speed HUD with dynamic colors and some customizations",
    version = "1.1",
    url = ""
};

/* ------------------Default Settings----------------- */

// Usage
#define DEFAULT_SHOW_SPEED        true
// Dynamic Color
#define DEFAULT_DYNAMIC_COLOR     true
// Speed Difference
#define DEFAULT_SPEED_DIFF        false
// X Position
#define POSITION_CENTER 		  -1.0
// Y Position
#define DEFAULT_POSITION_Y        0.55
// Default Speed Color
#define DEFAULT_COLOR_INC   	  "Cyan"
#define DEFAULT_COLOR_CONST 	  "White"
#define DEFAULT_COLOR_DEC         "Orange"
// HUD Refresh Rate
#define DEFAULT_TICKS_PER_UPDATE   5


#define SPEED_EPSILON 			   0.05             // Speed color ​​change threshold
#define HUD_BUF_SIZE 			   64
/* ------------------------------------------------------ */
enum {
	AXIS_X = 0,
	AXIS_Y
};

enum struct SpeedCookies {
	Cookie showSpeed;
	Cookie positionX;
	Cookie positionY;
	Cookie dynamic;
	Cookie speedDiff;
	// Color Cookies
	Cookie colorInc;
	Cookie colorConst;
	Cookie colorDec;
	// Frequancy Cookies
	Cookie TicksPerUpdate;
}

enum struct SpeedSettings {
	bool showSpeed;
	float position[2];
	bool dynamic;
	bool speedDiff;

	int colorInc[3];
	int colorConst[3];
	int colorDec[3];

	int TicksPerUpdate;
}

SpeedCookies Cookies;
SpeedSettings Settings[MAXPLAYERS + 1];


bool gB_SettingAxis[MAXPLAYERS + 1];
float gF_Modifier[MAXPLAYERS + 1];
float gF_LastSpeed[MAXPLAYERS + 1];
int g_RGBStep[MAXPLAYERS+1];
char g_CurrentRGBType[MAXPLAYERS+1][16];


char g_ColorNames[][] =
{
	"White",
	"Red",
	"Green",
	"Blue",
	"Cyan",
	"Orange",
	"Yellow",
	"Purple"
};

int g_ColorValues[][3] =
{
	{255,255,255}, 	// White   (Default Const Color)
	{255,0,0},  	// Red
	{0,255,0},  	// Green
	{30,140,255},  	// Blue
	{0,180,255},  	// Cyan    (Deafault Inc Color)
	{230,72,16},  	// Orange  (Deafault Dec Color)
	{255,255,0}, 	// Yellow
	{180,0,255} 	// Purple
};

public void OnPluginStart() {
	RegConsoleCmd("sm_showspeed", Command_ShowSpeed, "Toggles zSpeed HUD.");

	RegConsoleCmd("sm_zspeed", Command_ZSpeedMenu, "Opens zSpeed settings menu.");
	RegConsoleCmd("sm_speed", Command_ZSpeedMenu, "Opens zSpeed settings menu.");
	RegConsoleCmd("sm_spd", Command_ZSpeedMenu, "Opens zSpeed settings menu.");
	// RegConsoleCmd("sm_ve", Command_Vel, "Check your speed now(for debug)", ADMFLAG_GENERIC);
	// RegConsoleCmd("sm_ccc", Command_CheckColorCookies, "Check color cookies (for debug)", ADMFLAG_GENERIC);
	
	Cookies.showSpeed = new Cookie("showspeed_enabled", "[zSpeed] Main", CookieAccess_Protected);
	Cookies.positionX = new Cookie("showspeed_positionx", "[zSpeed] Position (x)", CookieAccess_Protected);
	Cookies.positionY = new Cookie("showspeed_positiony", "[zSpeed] Position (y)", CookieAccess_Protected);
	Cookies.dynamic   = new Cookie("showspeed_dynamic", "[zSpeed] Dynamic Colors", CookieAccess_Protected);
	Cookies.speedDiff = new Cookie("showspeed_difference", "[zSpeed] Speed Difference", CookieAccess_Protected);
	Cookies.colorInc  = new Cookie("zspeed_color_inc",   "[zSpeed] Increase Color", CookieAccess_Protected);
	Cookies.colorConst = new Cookie("zspeed_color_const", "[zSpeed] Constant Color", CookieAccess_Protected);
	Cookies.colorDec   = new Cookie("zspeed_color_dec",   "[zSpeed] Decrease Color", CookieAccess_Protected);
	Cookies.TicksPerUpdate   = new Cookie("zspeed_ticks_per_update", "[zSpeed] TicksPerUpdate", CookieAccess_Protected);
	// RegisterFreshmanCookie("zSpeed");
	
	for (int i = 1; i <= MaxClients; i++) {
		if (AreClientCookiesCached(i)) {
			OnClientCookiesCached(i);
		} 
	}
}

public void OnClientPutInServer(int client) {
	gF_Modifier[client] = 0.1; // Step for position settings
	g_RGBStep[client] = 10; // Step for custom color settings
}

/* -- Cookies -- */

public void OnClientCookiesCached(int client) {

	CheckFreshMan(client);
    // Load cookies to settings

	Settings[client].showSpeed   = GetCookie(client, Cookies.showSpeed, CT_Boolean);
	Settings[client].dynamic     = GetCookie(client, Cookies.dynamic,   CT_Boolean);
	Settings[client].position[0] = GetCookie(client, Cookies.positionX, CT_Float);
	Settings[client].position[1] = GetCookie(client, Cookies.positionY, CT_Float);
	Settings[client].speedDiff   = GetCookie(client, Cookies.speedDiff, CT_Boolean);
	Settings[client].TicksPerUpdate = GetCookie(client, Cookies.TicksPerUpdate, CT_Integer);
	char cname[16];

	Cookies.colorInc.Get(client, cname, sizeof(cname));
	ApplyColorByName(cname, Settings[client].colorInc);

	Cookies.colorConst.Get(client, cname, sizeof(cname));
	ApplyColorByName(cname, Settings[client].colorConst);

	Cookies.colorDec.Get(client, cname, sizeof(cname));
	ApplyColorByName(cname, Settings[client].colorDec);
}

void CheckFreshMan(int client) {
	char buffer[32];

    // showSpeed
    Cookies.showSpeed.Get(client, buffer, sizeof(buffer));
    if (buffer[0] == '\0')
        SetCookie(client, Cookies.showSpeed, CT_Boolean, DEFAULT_SHOW_SPEED);

    // dynamic
    Cookies.dynamic.Get(client, buffer, sizeof(buffer));
    if (buffer[0] == '\0')
        SetCookie(client, Cookies.dynamic, CT_Boolean, DEFAULT_DYNAMIC_COLOR);

    // speedDiff
    Cookies.speedDiff.Get(client, buffer, sizeof(buffer));
    if (buffer[0] == '\0')
        SetCookie(client, Cookies.speedDiff, CT_Boolean, DEFAULT_SPEED_DIFF);

	// positionX
	Cookies.positionX.Get(client, buffer, sizeof(buffer));
	if (buffer[0] == '\0')
		SetCookie(client, Cookies.positionX, CT_Float, POSITION_CENTER);

	// positionY
	Cookies.positionY.Get(client, buffer, sizeof(buffer));
	if (buffer[0] == '\0')
		SetCookie(client, Cookies.positionY, CT_Float, DEFAULT_POSITION_Y);

    // Color Settings
    Cookies.colorInc.Get(client, buffer, sizeof(buffer));
	if (buffer[0] == '\0')
		Cookies.colorInc.Set(client, DEFAULT_COLOR_INC);

	Cookies.colorConst.Get(client, buffer, sizeof(buffer));
	if (buffer[0] == '\0')
		Cookies.colorConst.Set(client, DEFAULT_COLOR_CONST);
	

	Cookies.colorDec.Get(client, buffer, sizeof(buffer));
	if (buffer[0] == '\0')
		Cookies.colorDec.Set(client, DEFAULT_COLOR_DEC);

	// frequency
    Cookies.TicksPerUpdate.Get(client, buffer, sizeof(buffer));
    if (buffer[0] == '\0')
        SetCookie(client, Cookies.TicksPerUpdate, CT_Integer, DEFAULT_TICKS_PER_UPDATE);

}

void OnCookieChanged(int client) {
	SetCookie(client, Cookies.showSpeed, CT_Boolean, Settings[client].showSpeed);
	SetCookie(client, Cookies.positionX, CT_Float,   Settings[client].position[AXIS_X]);
	SetCookie(client, Cookies.positionY, CT_Float,   Settings[client].position[AXIS_Y]);
	SetCookie(client, Cookies.dynamic,   CT_Boolean, Settings[client].dynamic);
	SetCookie(client, Cookies.speedDiff, CT_Boolean, Settings[client].speedDiff);
}

/* -- Commands -- */

public Action Command_ShowSpeed(int client, int args) {
	if (client == 0) { return Plugin_Handled; }

	Settings[client].showSpeed = !Settings[client].showSpeed;
	OnCookieChanged(client);
		
	CPrintToChat(
		client, "{cyan}[zSpeed] {white} Center Speed HUD %s{white}.",
		Settings[client].showSpeed ? "{lightgreen}Enabled" : "{red}Disabled"
	);
	
	return Plugin_Handled;
}

public Action Command_ZSpeedMenu(int client, int args) {
	if (client == 0) { return Plugin_Handled; }

	OpenZSpeedMenu(client);

	return Plugin_Handled;
}

/* -- Menus -- */

/*      >>>>> == Main Menu == <<<<<      */

void OpenZSpeedMenu(int client, int item = 0) {
	Menu hMenu = new Menu(ZSpeedMenu_Handler);
	hMenu.SetTitle("Center Speed HUD Settings");

	char sInfo[128];
	float frequency = 1.0 / (GetTickInterval() * Settings[client].TicksPerUpdate);
	char incStr[32], constStr[32], decStr[32];

	GetColorDisplay(client, Cookies.colorInc, incStr, sizeof(incStr));
	GetColorDisplay(client, Cookies.colorConst, constStr, sizeof(constStr));
	GetColorDisplay(client, Cookies.colorDec, decStr, sizeof(decStr));

	FormatEx(sInfo, sizeof(sInfo), "Usage: [%s]", Settings[client].showSpeed ? "ON" : "OFF");
	hMenu.AddItem("master", sInfo);

	FormatEx(sInfo, sizeof(sInfo), "Dynamic Color: [%s] ", Settings[client].dynamic ? "ON" : "OFF");
	hMenu.AddItem("dynamic", sInfo);

	FormatEx(sInfo, sizeof(sInfo), "Speed Difference: [%s]\n ", Settings[client].speedDiff ? "ON" : "OFF");
	hMenu.AddItem("difference", sInfo);

	FormatEx(sInfo, sizeof(sInfo), "Position Settings\n    Current: %.3f, %.3f", Settings[client].position[0], Settings[client].position[1]);
		hMenu.AddItem("position", sInfo);

	FormatEx(sInfo, sizeof(sInfo),
    		"Color Settings\n    Increasing Color: %s\n    Constant Color: %s\n    Decreasing Color: %s",
    		incStr, constStr, decStr);

	hMenu.AddItem("colors", sInfo);

	FormatEx(sInfo, sizeof(sInfo), "Frequency Settings\n    %d ticks - %.1f Hz\n ", Settings[client].TicksPerUpdate, frequency);
	hMenu.AddItem("tickrate", sInfo);

	hMenu.AddItem("reset", "Reset All & Info");

	hMenu.ExitButton = true;
	hMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int ZSpeedMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char sInfo[16];

        menu.GetItem(param2, sInfo, sizeof(sInfo));

        if (StrEqual(sInfo, "master"))
        {
            Settings[param1].showSpeed = !Settings[param1].showSpeed;
        }
        else if (StrEqual(sInfo, "dynamic"))
        {
            Settings[param1].dynamic = !Settings[param1].dynamic;
        }
        else if (StrEqual(sInfo, "difference"))
        {
            Settings[param1].speedDiff = !Settings[param1].speedDiff;
        }
		else if (StrEqual(sInfo, "position"))
        {
            OpenPositionSettingsMenu(param1);
            return 0;
        }
        else if (StrEqual(sInfo, "colors"))
        {
            OpenColorMenu(param1);
            return 0;
        }
		else if (StrEqual(sInfo, "tickrate"))
		{
			OpenTickRateMenu(param1);
			return 0;
		}
		else if (StrEqual(sInfo, "reset"))
		{
			OpenResetConfirmMenu(param1);
			CPrintToChat(param1, "{cyan}★ zSpeed {white} Version:{lightgreen} 1.1");
			CPrintToChat(param1, "{white}Developed by {lightgreen}Shahrazad {white}& {lightgreen}Picrisol45\n ");
			CPrintToChat(param1, "{lightblue} /spd{white}, {lightblue}/speed{white}, {lightblue}/zspeed {white}--- Show Main Menu");
			CPrintToChat(param1, "{lightblue} /showspeed {white}--- Toggle Center Speed HUD\n ");
			CPrintToChat(param1, "{orange} NOTE! ! !{white}: Display {warning}Speed Difference HUD{white} may {warning}BREAK{white} other HUDs(JHUD, StrafeTrainer)!!!So don’t open it unless necessary.");
			return 0;
		}

        if (Settings[param1].speedDiff)
        {
            CPrintToChat(param1, "{cyan}[zSpeed]{warning} WARNING{white}: Display {warning}Speed Difference HUD{white} may {warning}BREAK{white} other HUDs(JHUD, StrafeTrainer)!!!So don’t open it unless necessary.");
        }

        OnCookieChanged(param1);
        OpenZSpeedMenu(param1, GetMenuSelectionPosition());
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

/*      >>>>> == Position Menu == <<<<<      */

void OpenPositionSettingsMenu(int client) {
	Menu hMenu = new Menu(PositionSettingsMenu_Handler);
	hMenu.SetTitle(
		"Position Settings\nCurrent Position: (%.3f, %.3f)\n ",
		Settings[client].position[0], Settings[client].position[1]
	);

	char sInfo[33];

	FormatEx(sInfo, sizeof(sInfo), "Axis: %s", gB_SettingAxis[client] ? "X" : "Y");
	hMenu.AddItem("axis", sInfo);

	FormatEx(sInfo, sizeof(sInfo), "Modifier: %d", RoundToFloor(gF_Modifier[client] * 1000.0));
	hMenu.AddItem("modifier", sInfo);

	hMenu.AddItem("center", "Center\n ");

	FormatEx(sInfo, sizeof(sInfo), "+%d", RoundToFloor(gF_Modifier[client] * 1000.0));
	hMenu.AddItem("+", sInfo);

	FormatEx(sInfo, sizeof(sInfo), "-%d", RoundToFloor(gF_Modifier[client] * 1000.0));
	hMenu.AddItem("-", sInfo);

	hMenu.ExitBackButton = true;
	hMenu.Display(client, MENU_TIME_FOREVER);
}

int PositionSettingsMenu_Handler(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Select) {
		char sInfo[16];
		menu.GetItem(param2, sInfo, sizeof(sInfo));

		int iAxis = gB_SettingAxis[param1] ? AXIS_X : AXIS_Y;

		if (StrEqual(sInfo, "axis"))          { gB_SettingAxis[param1] = !gB_SettingAxis[param1]; }
		else if (StrEqual(sInfo, "modifier")) { gF_Modifier[param1] = gF_Modifier[param1] == 0.1 ? 0.01 : gF_Modifier[param1] == 0.01 ? 0.001 : 0.1; }
		else if (StrEqual(sInfo, "center"))   { Settings[param1].position[iAxis] = POSITION_CENTER; }
		else if (StrEqual(sInfo, "+"))        { AddOrMinusPosition(param1, iAxis, gF_Modifier[param1], true); }
		else if (StrEqual(sInfo, "-"))        { AddOrMinusPosition(param1, iAxis, gF_Modifier[param1], false); }

		OpenPositionSettingsMenu(param1);
	} else if (action == MenuAction_Cancel) {
		OpenZSpeedMenu(param1);
	} else if (action == MenuAction_End) {
		delete menu;
	}

	return 0;
}

/*      >>>>> == Color Menu == <<<<<      */

void OpenColorMenu(int client)
{
    Menu menu = new Menu(ColorMenu_Handler);

    char incStr[32], constStr[32], decStr[32];
    GetColorDisplay(client, Cookies.colorInc,   incStr,   sizeof(incStr));
    GetColorDisplay(client, Cookies.colorConst, constStr, sizeof(constStr));
    GetColorDisplay(client, Cookies.colorDec,   decStr,   sizeof(decStr));

    menu.SetTitle("Color Settings");

    char buffer[64];

    FormatEx(buffer, sizeof(buffer), "Increase Color: %s", incStr);
    menu.AddItem("inc", buffer);

    FormatEx(buffer, sizeof(buffer), "Constant Color: %s", constStr);
    menu.AddItem("const", buffer);

    FormatEx(buffer, sizeof(buffer), "Decrease Color: %s", decStr);
    menu.AddItem("dec", buffer);

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

int ColorMenu_Handler(Menu menu, MenuAction action, int client, int item)
{
    if(action == MenuAction_Select)
    {
        char info[16];
        menu.GetItem(item, info, sizeof(info));

        OpenPresetColorMenu(client, info);
    }
    else if(action == MenuAction_Cancel)
    {
        OpenZSpeedMenu(client);
    }
    else if(action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}


void OpenPresetColorMenu(int client, const char[] type)
{
    Menu menu = new Menu(PresetColor_Handler);

    char current[32];
    char typeName[32];

    if(StrEqual(type, "inc"))
    {
        strcopy(typeName, sizeof(typeName), "Increasing Color");
        GetColorDisplay(client, Cookies.colorInc, current, sizeof(current));
    }
    else if(StrEqual(type, "const"))
    {
        strcopy(typeName, sizeof(typeName), "Constant Color");
        GetColorDisplay(client, Cookies.colorConst, current, sizeof(current));
    }
    else
    {
        strcopy(typeName, sizeof(typeName), "Decreasing Color");
        GetColorDisplay(client, Cookies.colorDec, current, sizeof(current));
    }

    char title[96];
    FormatEx(title, sizeof(title),
        "Select Color\n%s : %s",
        typeName,
        current);

    menu.SetTitle(title);

    menu.AddItem(type, "Custom RGB");

    for(int i = 0; i < sizeof(g_ColorNames); i++)
    {
        menu.AddItem(type, g_ColorNames[i]);
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

int PresetColor_Handler(Menu menu, MenuAction action, int client, int item)
{
	if(action == MenuAction_Select)
	{
		char type[16], color[16];
		menu.GetItem(item, type, sizeof(type), _, color, sizeof(color));

		strcopy(g_CurrentRGBType[client], sizeof(g_CurrentRGBType[]), type);

		if(StrEqual(color, "Custom RGB"))
		{
			OpenCustomRGBMenu(client, g_CurrentRGBType[client]);
			return 0;
		}

		if(StrEqual(type, "inc"))
		{
			ApplyColorByName(color, Settings[client].colorInc);
			Cookies.colorInc.Set(client, color);		
		}
		else if(StrEqual(type, "const"))
		{
			ApplyColorByName(color, Settings[client].colorConst);
			Cookies.colorConst.Set(client, color);
		}
		else if(StrEqual(type, "dec"))
		{
			ApplyColorByName(color, Settings[client].colorDec);
			Cookies.colorDec.Set(client, color);
		}

		OpenPresetColorMenu(client, type);
	}
	else if(action == MenuAction_Cancel)
	{
		OpenColorMenu(client);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void OpenCustomRGBMenu(int client, const char[] type)
{
	int color[3];
	char typeName[32];
	// correct steps
	if (g_RGBStep[client] <= 0) g_RGBStep[client] = 10;

	// Check speed type
	if(StrEqual(type, "inc"))
		strcopy(typeName, sizeof(typeName), "Increasing Color");
	else if(StrEqual(type, "const"))
		strcopy(typeName, sizeof(typeName), "Constant Color");
	else
		strcopy(typeName, sizeof(typeName), "Decreasing Color");
	
	// Check color in cookies
	if(StrEqual(type,"inc")) 		color = Settings[client].colorInc;
	else if(StrEqual(type,"const")) color = Settings[client].colorConst;
	else if(StrEqual(type,"dec"))   color = Settings[client].colorDec;
	else
	{
		// Invalild RGB
		PrintToServer("ERROR: Invalid RGB type for client %d", client);
		return;
	}

	// Main Custom Color Menu
	Menu menu = new Menu(CustomRGB_Handler);

	char title[128];
	Format(title, sizeof(title),
			"=== RGB Editor ===\nMode: %s\nStep: %d\n \nCurrent: %d %d %d\n ",
			typeName,
			g_RGBStep[client],
			color[0], color[1], color[2]);

	menu.SetTitle(title);
	// Adjust (R, G, B) value
	menu.AddItem("r_plus", "Red +");
	menu.AddItem("r_minus", "Red -");
	menu.AddItem("g_plus", "Green +");
	menu.AddItem("g_minus", "Green -");
	menu.AddItem("b_plus", "Blue +");
	menu.AddItem("b_minus", "Blue - \n ");
	// Adjust steps
	menu.AddItem("step", "Switch Step");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int CustomRGB_Handler(Menu menu, MenuAction action, int client, int item)
{
	if(action == MenuAction_Select)
	{
		char info[32], actionText[32];
		menu.GetItem(item, info, sizeof(info), _, actionText, sizeof(actionText));

		// swithe step
		if(StrEqual(info, "step"))
		{
			if(g_RGBStep[client] == 1)
				g_RGBStep[client] = 10;
			else if(g_RGBStep[client] == 10)
				g_RGBStep[client] = 100;
			else
				g_RGBStep[client] = 1;

			OpenCustomRGBMenu(client, g_CurrentRGBType[client]);
			return 0;
		}

		int delta = g_RGBStep[client];

		// check speed mode
		if(StrEqual(g_CurrentRGBType[client],"inc"))
		{
			if(StrEqual(info, "r_plus"))
				AdjustColorValue(Settings[client].colorInc, 0, delta);
			else if(StrEqual(info, "r_minus"))
				AdjustColorValue(Settings[client].colorInc, 0, -delta);
			else if(StrEqual(info, "g_plus"))
				AdjustColorValue(Settings[client].colorInc, 1, delta);
			else if(StrEqual(info, "g_minus"))
				AdjustColorValue(Settings[client].colorInc, 1, -delta);
			else if(StrEqual(info, "b_plus"))
				AdjustColorValue(Settings[client].colorInc, 2, delta);
			else if(StrEqual(info, "b_minus"))
				AdjustColorValue(Settings[client].colorInc, 2, -delta);

			SaveColorToCookie(client, "inc", Settings[client].colorInc);
		}
		else if(StrEqual(g_CurrentRGBType[client],"const"))
		{
			// for Const speed
			if(StrEqual(info, "r_plus"))
				AdjustColorValue(Settings[client].colorConst, 0, delta);
			else if(StrEqual(info, "r_minus"))
				AdjustColorValue(Settings[client].colorConst, 0, -delta);
			else if(StrEqual(info, "g_plus"))
				AdjustColorValue(Settings[client].colorConst, 1, delta);
			else if(StrEqual(info, "g_minus"))
				AdjustColorValue(Settings[client].colorConst, 1, -delta);
			else if(StrEqual(info, "b_plus"))
				AdjustColorValue(Settings[client].colorConst, 2, delta);
			else if(StrEqual(info, "b_minus"))
				AdjustColorValue(Settings[client].colorConst, 2, -delta);

			SaveColorToCookie(client, "const", Settings[client].colorConst);
		}
		else
		{
			// for Dec speed
			if(StrEqual(info, "r_plus"))
				AdjustColorValue(Settings[client].colorDec, 0, delta);
			else if(StrEqual(info, "r_minus"))
				AdjustColorValue(Settings[client].colorDec, 0, -delta);
			else if(StrEqual(info, "g_plus"))
				AdjustColorValue(Settings[client].colorDec, 1, delta);
			else if(StrEqual(info, "g_minus"))
				AdjustColorValue(Settings[client].colorDec, 1, -delta);
			else if(StrEqual(info, "b_plus"))
				AdjustColorValue(Settings[client].colorDec, 2, delta);
			else if(StrEqual(info, "b_minus"))
				AdjustColorValue(Settings[client].colorDec, 2, -delta);

			SaveColorToCookie(client, "dec", Settings[client].colorDec);
		}

		OpenCustomRGBMenu(client, g_CurrentRGBType[client]);
	}
	else if(action == MenuAction_Cancel)
	{
		OpenPresetColorMenu(client, g_CurrentRGBType[client]);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

/*      >>>>> == Refresh Rate Menu == <<<<<      */

void OpenTickRateMenu(int client)
{
	Menu menu = new Menu(TickRateMenu_Handler);

	float interval = GetTickInterval();
	float frequency = 1.0 / (interval * Settings[client].TicksPerUpdate);
	float hz;
	char title[128];
	char buffer[64];
	
	Format(title, sizeof(title),
		"HUD Refresh Rate\n \nServer: %.1f tick \nTime Per Update: %d ticks\nFrequency: %.1f Hz (updates/sec)\nHUD HoldTime: %.2f \n ",
		1 / GetTickInterval(),
		Settings[client].TicksPerUpdate,
		frequency,
		GetHudHoldTime(client)
	);

	menu.SetTitle(title);

	/* Modify the rate */
	menu.AddItem("inc", "+ Increase");
	menu.AddItem("dec", "- Decrease");

	// ===== 2 =====
	hz = 1.0 / (interval * 2.0);
	Format(buffer, sizeof(buffer),
		"%s2 ticks - %.1f Hz (Rapid)",
		(Settings[client].TicksPerUpdate == 2) ? "√ " : "",
		hz
	);
	menu.AddItem("2", buffer);

	// ===== 3 =====
	hz = 1.0 / (interval * 3.0);
	Format(buffer, sizeof(buffer),
		"%s3 ticks - %.1f Hz (Moderate)",
		(Settings[client].TicksPerUpdate == 3) ? "√ " : "",
		hz
	);
	menu.AddItem("3", buffer);

	// ===== 5 =====
	hz = 1.0 / (interval * 5.0);
	Format(buffer, sizeof(buffer),
		"%s5 ticks - %.1f Hz (Recommended)",
		(Settings[client].TicksPerUpdate == 5) ? "√ " : "",
		hz
	);
	menu.AddItem("5", buffer);

	// ===== 6 =====
	hz = 1.0 / (interval * 6.0);
	Format(buffer, sizeof(buffer),
		"%s6 ticks - %.1f Hz (Recommended)",
		(Settings[client].TicksPerUpdate == 6) ? "√ " : "",
		hz
	);
	menu.AddItem("6", buffer);

	// ===== 10 =====
	hz = 1.0 / (interval * 10.0);
	Format(buffer, sizeof(buffer),
		"%s10 ticks - %.1f Hz (Slow)",
		(Settings[client].TicksPerUpdate == 10) ? "√ " : "",
		hz
	);
	menu.AddItem("10", buffer);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int TickRateMenu_Handler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[16];
		menu.GetItem(item, info, sizeof(info));

		int value = Settings[client].TicksPerUpdate;
		// float frequency = 1.0 / (GetTickInterval() * Settings[client].TicksPerUpdate);

		if (StrEqual(info, "inc"))
		{
			value++;
		}
		else if (StrEqual(info, "dec"))
		{
			value--;
		}
		else if (StrEqual(info, "sep"))
		{
			OpenTickRateMenu(client);
			return 0;
		}
		else
		{
			value = StringToInt(info);
		}

		// tick range (1, 15)
		if (value < 1) value = 1;
		if (value > 15) value = 15;

		Settings[client].TicksPerUpdate = value;
		SetCookie(client, Cookies.TicksPerUpdate, CT_Integer, value);
		// CPrintToChat(client,
		// 	"{cyan}[zSpeed]{white} Ticks Per Update: {lightgreen}%d {white}, Freq: {lightgreen}%.1f {white}Hz",
		// 	value, frequency);

		OpenTickRateMenu(client);
	}
	else if (action == MenuAction_Cancel)
	{
		OpenZSpeedMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

/* -- HUD -- */

public Action OnPlayerRunCmd(
	int client, int &buttons, int &impulse,
	float vel[3], float angles[3],
	int &weapon, int &subtype, int &cmdnum,
	int &tickcount, int &seed, int mouse[2]
) {
	if (
		!Settings[client].showSpeed
		 || !IsValidClient(client)
		 || IsFakeClient(client) 
		 || (Settings[client].TicksPerUpdate > 0 &&
		 	cmdnum % Settings[client].TicksPerUpdate != 0)  // give up GetGameTickCount() 
	) {
		return Plugin_Continue;
	}

	int iTarget = GetSpectatorTarget(client, client);

	float fSpeed[3];
	GetEntPropVector(iTarget, Prop_Data, "m_vecVelocity", fSpeed);

	bool bTrueVel = !view_as<bool>(Shavit_GetHUDSettings(client) & HUD_2DVEL);

	char sBuffer[HUD_BUF_SIZE];

	/* -- Speed -- */
	DrawMainSpeedHUD(client, fSpeed, sBuffer, bTrueVel);

	/* -- Difference -- */
	if (
		Settings[client].speedDiff
		 && Shavit_GetClientTime(client) != 0.0
		 && Shavit_GetClosestReplayTime(client) != -1.0
	) {
		DrawSpeedDiffHUD(client, sBuffer, bTrueVel);
	}
	return Plugin_Continue;
}

void DrawMainSpeedHUD(int client, float vel[3], char[] buffer, bool trueVel) {
	float fCurrentSpeed = trueVel ? GetVectorLength(vel) : SquareRoot(Pow(vel[0], 2.0) + Pow(vel[1], 2.0));
	int iColor[3];

	float diff = fCurrentSpeed - gF_LastSpeed[client];

	if (!Settings[client].dynamic)
	{
		iColor = Settings[client].colorInc;
	}
	else if (FloatAbs(diff) <= SPEED_EPSILON)
	{
		iColor = Settings[client].colorConst;
	}
	else if (diff > 0.0)
	{
		iColor = Settings[client].colorInc;
	}
	else
	{
		iColor = Settings[client].colorDec;
	}

	SetHudTextParams(
		Settings[client].position[AXIS_X], Settings[client].position[AXIS_Y],
		GetHudHoldTime(client), iColor[0], iColor[1], iColor[2], 255, 0, 1.0, 0.0, 0.0
	);
	Format(buffer, HUD_BUF_SIZE, "%d", RoundToFloor(fCurrentSpeed));
	ShowHudText(client, GetDynamicChannel(4), "%s", buffer);

	gF_LastSpeed[client] = fCurrentSpeed;
}

void DrawSpeedDiffHUD(int client, char[] buffer, bool trueVel) {
	float fDiff = Shavit_GetClosestReplayVelocityDifference(client, trueVel);
	int iColor[3];

	if (fDiff >= 0.0) {
		iColor = Settings[client].colorInc;
	} else {
		iColor = Settings[client].colorDec;
	}

	SetHudTextParams(
		Settings[client].position[AXIS_X],
		Settings[client].position[AXIS_Y] == POSITION_CENTER ? 0.52 : Settings[client].position[AXIS_Y] + 0.03,
		GetHudHoldTime(client), iColor[0], iColor[1], iColor[2], 255, 0, 1.0, 0.0, 0.0 // 暂时不改
	);
	Format(buffer, HUD_BUF_SIZE, "%d", RoundToFloor(fDiff));
	ShowHudText(client, GetDynamicChannel(0), "(%s%s)", (fDiff >= 0.0) ? "+" : "", buffer);
}

/* -- Helper -- */
void ResetZSpeedSettings(int client)
{
    // Reset Cookies
    SetCookie(client, Cookies.showSpeed, CT_Boolean, DEFAULT_SHOW_SPEED);
    SetCookie(client, Cookies.dynamic, CT_Boolean, DEFAULT_DYNAMIC_COLOR);
    SetCookie(client, Cookies.speedDiff, CT_Boolean, DEFAULT_SPEED_DIFF);
    SetCookie(client, Cookies.positionX, CT_Float, POSITION_CENTER);
    SetCookie(client, Cookies.positionY, CT_Float, DEFAULT_POSITION_Y);

    Cookies.colorInc.Set(client, DEFAULT_COLOR_INC);
    Cookies.colorConst.Set(client, DEFAULT_COLOR_CONST);
    Cookies.colorDec.Set(client, DEFAULT_COLOR_DEC);

    SetCookie(client, Cookies.TicksPerUpdate, CT_Integer, DEFAULT_TICKS_PER_UPDATE);

    // Reset settings in game 
    Settings[client].showSpeed      = DEFAULT_SHOW_SPEED;
    Settings[client].dynamic        = DEFAULT_DYNAMIC_COLOR;
    Settings[client].speedDiff      = DEFAULT_SPEED_DIFF;
    Settings[client].position[AXIS_X] = POSITION_CENTER;
    Settings[client].position[AXIS_Y] = DEFAULT_POSITION_Y;
    Settings[client].TicksPerUpdate = DEFAULT_TICKS_PER_UPDATE;

    ApplyColorByName(DEFAULT_COLOR_INC,   Settings[client].colorInc);
    ApplyColorByName(DEFAULT_COLOR_CONST, Settings[client].colorConst);
    ApplyColorByName(DEFAULT_COLOR_DEC,   Settings[client].colorDec);

	CPrintToChat(client, "{cyan}[zSpeed] {white} Settings reset to default.");
}

void OpenResetConfirmMenu(int client)
{
    Menu menu = new Menu(ResetConfirm_Handler);

    menu.SetTitle("Reset All Settings?\nThis cannot be undone.");

    menu.AddItem("yes", "Yes - Reset to Default");
    menu.AddItem("no",  "No - Go Back");

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

int ResetConfirm_Handler(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        char info[16];
        menu.GetItem(item, info, sizeof(info));

        if (StrEqual(info, "yes"))
        {
            ResetZSpeedSettings(client);
            OpenZSpeedMenu(client);
        }
        else
        {
            OpenZSpeedMenu(client);
        }
    }
    else if (action == MenuAction_Cancel)
    {
        OpenZSpeedMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

void AddOrMinusPosition(int client, int axis, float value, bool add) 
{
	if (Settings[client].position[axis] == POSITION_CENTER) {
		Settings[client].position[axis] = add ? 0.49 : 0.50;
		SetCookie(client, Cookies.positionX, CT_Float, Settings[client].position[axis]);

		return;
	}

	Settings[client].position[axis] += add ? value : -value;

	if (add ? Settings[client].position[axis] > 1.0 : Settings[client].position[axis] < 0.0) {
		Settings[client].position[axis] = add ? 1.0 : 0.0;
	}

	SetCookie(client, axis == AXIS_X ? Cookies.positionX : Cookies.positionY, CT_Float, Settings[client].position[axis]);
}

float GetHudHoldTime(int client)
{
    float interval = GetTickInterval() * float(Settings[client].TicksPerUpdate);
    float holdtime = interval * 5.0 + 0.15 / float(Settings[client].TicksPerUpdate);

    if (holdtime < 0.12)
        return 0.12;

    return holdtime;
}

void SaveColorToCookie(int client, const char[] type, int color[3])
{
    char buffer[32];
    Format(buffer, sizeof(buffer), "%d %d %d", color[0], color[1], color[2]);

    if(StrEqual(type, "inc"))
        Cookies.colorInc.Set(client, buffer);
    else if(StrEqual(type, "const"))
        Cookies.colorConst.Set(client, buffer);
    else
        Cookies.colorDec.Set(client, buffer);
}

void AdjustColorValue(int color[3], int index, int delta)
{
	color[index] += delta;
	// RGB value 0 ~ 255
	if(color[index] < 0)   color[index] = 0;
	if(color[index] > 255) color[index] = 255;
}

void ApplyColorByName(const char[] value, int color[3])
{
	 // if include " "(space) → Custom RGB Mode
    if(StrContains(value, " ") != -1)
    {
        char parts[3][8];
        ExplodeString(value, " ", parts, 3, 8);

        color[0] = StringToInt(parts[0]);
        color[1] = StringToInt(parts[1]);
        color[2] = StringToInt(parts[2]);
        return;
    }
    // else default Mode
    for (int i = 0; i < sizeof(g_ColorNames); i++)
    {
        if (StrEqual(value, g_ColorNames[i]))
        {
            color[0] = g_ColorValues[i][0];
            color[1] = g_ColorValues[i][1];
            color[2] = g_ColorValues[i][2];
            return;
        }
    }
    // all white if error
    color[0] = 255;
    color[1] = 255;
    color[2] = 255;
}

bool IsCustomColor(const char[] value)
{
    return StrContains(value, " ") != -1;
}

void GetColorDisplay(int client, Cookie cookie, char[] buffer, int maxlen)
{
    char value[32];
    cookie.Get(client, value, sizeof(value));

    if (value[0] == '\0')
    {
        strcopy(buffer, maxlen, "Default");
        return;
    }

    if (IsCustomColor(value))
    {
        // Custom RGB Mode
        strcopy(buffer, maxlen, value);
    }
    else
    {
        // Default Mode
        strcopy(buffer, maxlen, value);
    }
}

/* DEBUG */
public Action Command_Vel(int client, int args)
{
    float vel[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);

    PrintToChat(client, "X: %.1f Y: %.1f Z: %.1f", vel[0], vel[1], vel[2]);

    return Plugin_Handled;
}

public Action Command_CheckColorCookies(int client, int args)
{
    if (!IsClientInGame(client) || IsFakeClient(client))
    {
        return Plugin_Handled;
    }

    char inc[16], constColor[16], dec[16];

    Cookies.colorInc.Get(client, inc, sizeof(inc));
    Cookies.colorConst.Get(client, constColor, sizeof(constColor));
    Cookies.colorDec.Get(client, dec, sizeof(dec));

    PrintToChat(client, "[zSpeed] inc color: %s", inc);
    PrintToChat(client, "[zSpeed] const color: %s", constColor);
    PrintToChat(client, "[zSpeed] dec color: %s", dec);
	PrintToChat(client, "TICK: %f", 1 / GetTickInterval());

    return Plugin_Handled;
}

