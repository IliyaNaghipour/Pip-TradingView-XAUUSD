//+------------------------------------------------------------------+
//|  Pip — Fractal / Trend / Order Block / 1-2-3 / Flag | XAUUSD      |
//|  MT5 desktop indicator (MQL5). Does NOT run on MT5 mobile.       |
//|  For the phone, use the TradingView version in the same folder:   |
//|  Pip_Fractal_OB_Flag_XAUUSD.pine                                 |
//|                                                                    |
//|  Install (MT5 desktop, demo account):                            |
//|    1. MT5 -> Tools -> MetaQuotes Language Editor (F4)              |
//|    2. File -> Open -> put this file in MQL5/Indicators/           |
//|    3. Compile (F7). 0 errors = OK.                                |
//|    4. Drag it from Navigator -> Indicators onto an XAUUSD chart.  |
//|    5. Tools -> Options -> Notifications: set your MetaQuotes ID   |
//|       to get push alerts on your MT5 phone app.                    |
//|  Recommended for XAUUSD: H1 for trend/structure, M15 for entry.  |
//|  Educational tool only — NOT a trading signal. Use on demo first.|
//+------------------------------------------------------------------+
#property copyright "Pip for Ilia — educational, XAUUSD tuned"
#property version   "1.00"
#property description "Fractal, trend (EMA 50/200), order blocks, 1-2-3, flags — XAUUSD"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_width1  2
#property indicator_label1  "Fractal Up"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrGreen
#property indicator_width2  2
#property indicator_label2  "Fractal Down"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_width3  1
#property indicator_label3  "EMA 50"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrange
#property indicator_width4  1
#property indicator_label4  "EMA 200"

//--- inputs
input group "=== Trend ==="
input bool   InpShowTrend   = true;
input int    InpEmaFast     = 50;
input int    InpEmaSlow     = 200;
input group "=== Fractal ==="
input bool   InpShowFractal = true;
input int    InpFractalBars = 2;      // bars each side (2 = classic 5-bar fractal)
input group "=== Order Block — XAUUSD tuned ==="
input bool   InpShowOB      = true;
input int    InpOBLookback  = 50;
input double InpOBDispATR   = 1.0;    // min displacement, x ATR(14)
input int    InpOBMax       = 8;      // max OB boxes kept
input int    InpOBExtendBars= 30;     // box extension, in bars
input group "=== 1-2-3 / Flag ==="
input bool   InpShow123     = true;
input bool   InpShowFlag    = true;
input double InpFlagPoleATR = 1.5;    // flag pole min move, x ATR(14) over 5 bars
input double InpFlagMaxRet  = 0.5;    // flag max retracement of pole
input group "=== Alerts ==="
input bool   InpAlerts      = true;
input bool   InpPush        = true;   // SendNotification to MT5 mobile

//--- buffers
double FractalUp[];
double FractalDown[];
double EmaFastBuf[];
double EmaSlowBuf[];

//--- handles
int hEmaFast = INVALID_HANDLE;
int hEmaSlow = INVALID_HANDLE;
int hAtr     = INVALID_HANDLE;

//--- state
datetime g_lastAlertBar = 0;
int      g_obCount      = 0;
double   g_lastPh = 0.0, g_lastPl = 0.0;
double   g_p1Low = 0.0, g_p2High = 0.0, g_p3Low = 0.0;
double   g_p1High = 0.0, g_p2Low = 0.0, g_p3High = 0.0;
int      g_bull123 = 0, g_bear123 = 0;   // 0 none, 1 = point 1, 2 = point 2, 3 = point 3

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, FractalUp,   INDICATOR_DATA);
   SetIndexBuffer(1, FractalDown, INDICATOR_DATA);
   SetIndexBuffer(2, EmaFastBuf,  INDICATOR_DATA);
   SetIndexBuffer(3, EmaSlowBuf,  INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_ARROW, 234); // down triangle
   PlotIndexSetInteger(1, PLOT_ARROW, 233); // up triangle
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 0);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, 0);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);

   ArraySetAsSeries(FractalUp,   true);
   ArraySetAsSeries(FractalDown, true);
   ArraySetAsSeries(EmaFastBuf,  true);
   ArraySetAsSeries(EmaSlowBuf,  true);

   hEmaFast = iMA(_Symbol, _Period, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hEmaSlow = iMA(_Symbol, _Period, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   hAtr     = iATR(_Symbol, _Period, 14);
   if(hEmaFast == INVALID_HANDLE || hEmaSlow == INVALID_HANDLE || hAtr == INVALID_HANDLE)
      return INIT_FAILED;

   IndicatorSetString(INDICATOR_SHORTNAME, "Pip OB/Flag XAUUSD");
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Remove objects created by this indicator
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, "Pip_") == 0)
         ObjectDelete(0, name);
   }
   if(hEmaFast != INVALID_HANDLE) IndicatorRelease(hEmaFast);
   if(hEmaSlow != INVALID_HANDLE) IndicatorRelease(hEmaSlow);
   if(hAtr     != INVALID_HANDLE) IndicatorRelease(hAtr);
}
//+------------------------------------------------------------------+
void AlertOnce(string text, datetime barTime)
{
   if(!InpAlerts) return;
   if(barTime == g_lastAlertBar) return;
   g_lastAlertBar = barTime;
   Alert(text);
   if(InpPush) SendNotification(text);
}
//+------------------------------------------------------------------+
void DrawLabel(string name, datetime t, double price, string text, color col, bool below)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, below ? ANCHOR_UPPER : ANCHOR_LOWER);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
}
//+------------------------------------------------------------------+
void CreateOB(string prefix, datetime t1, double top, double bottom, color col)
{
   string name = prefix + "_" + IntegerToString(g_obCount++);
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, top, t1 + (datetime)(InpOBExtendBars * PeriodSeconds()), bottom);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   // Extend to the right on every new bar (done in the OB loop below via time update)
}
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < 250) return 0;
   int start = prev_calculated == 0 ? 250 : prev_calculated - 1;
   if(start < 250) start = 250;

   //--- copy indicator values
   double emaF[], emaS[], atr[];
   ArraySetAsSeries(emaF, true); ArraySetAsSeries(emaS, true); ArraySetAsSeries(atr, true);
   if(CopyBuffer(hEmaFast, 0, 0, rates_total, emaF) <= 0) return prev_calculated;
   if(CopyBuffer(hEmaSlow, 0, 0, rates_total, emaS) <= 0) return prev_calculated;
   if(CopyBuffer(hAtr,     0, 0, rates_total, atr)  <= 0) return prev_calculated;

   // Series arrays are reversed in OnCalculate: index 0 = newest bar.
   // We work with the newest bar at index 0 for alerts, and scan back for patterns.
   for(int i = start; i >= 0; i--)
   {
      EmaFastBuf[i] = emaF[i];
      EmaSlowBuf[i] = emaS[i];
      FractalUp[i]   = 0.0;
      FractalDown[i] = 0.0;
   }

   //--- Fractals (classic 5-bar, InpFractalBars = 2 each side)
   // A fractal is confirmed 2 bars after its middle candle, so we mark it at i+2.
   for(int i = 2; i < rates_total - 2; i++)
   {
      if(!InpShowFractal) break;
      bool up = true, dn = true;
      for(int k = 1; k <= InpFractalBars; k++)
      {
         if(high[i] <= high[i - k] || high[i] <= high[i + k]) up = false;
         if(low[i]  >= low[i - k]  || low[i]  >= low[i + k])  dn = false;
      }
      if(up) { FractalUp[i] = high[i]; g_lastPh = high[i]; }
      if(dn) { FractalDown[i] = low[i];  g_lastPl = low[i]; }
   }

   //--- Trend label (top-left of chart)
   if(InpShowTrend)
   {
      int    trend = 0;
      string txt;
      color  col = clrGray;
      if(close[0] > emaF[0] && emaF[0] > emaS[0])      { trend = 1;  txt = "TREND: UP — XAUUSD, longs only";   col = clrGreen; }
      else if(close[0] < emaF[0] && emaF[0] < emaS[0]) { trend = -1; txt = "TREND: DOWN — XAUUSD, shorts only"; col = clrRed; }
      else                                              { trend = 0;  txt = "TREND: SIDEWAYS — wait";         col = clrGray; }
      string lname = "Pip_Trend";
      if(ObjectFind(0, lname) < 0)
         ObjectCreate(0, lname, OBJ_LABEL, 0, 0, 0);
      ObjectSetString(0, lname, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, lname, OBJPROP_COLOR, col);
      ObjectSetInteger(0, lname, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, lname, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, lname, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, lname, OBJPROP_YDISTANCE, 15);
   }

   //--- Order blocks: displacement on the newest closed bar (index 1)
   // Bullish displacement: strong up candle. OB = last bearish candle before it.
   if(InpShowOB && rates_total > InpOBLookback + 5)
   {
      double a = atr[1] > 0 ? atr[1] : 1.0;
      // Bullish
      if(close[1] > open[1] && (close[1] - open[1]) > a * InpOBDispATR && close[1] > high[2])
      {
         for(int j = 2; j <= 6; j++)
         {
            if(close[j] < open[j])
            {
               CreateOB("Pip_OB_Bull", time[j], high[j], low[j], clrGreen);
               break;
            }
         }
      }
      // Bearish
      if(close[1] < open[1] && (open[1] - close[1]) > a * InpOBDispATR && close[1] < low[2])
      {
         for(int j = 2; j <= 6; j++)
         {
            if(close[j] > open[j])
            {
               CreateOB("Pip_OB_Bear", time[j], high[j], low[j], clrRed);
               break;
            }
         }
      }
      // Mitigate / touch: scan OB rectangles, extend them, delete if closed through
      for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i, -1, -1);
         if(StringFind(name, "Pip_OB_") != 0) continue;
         double top = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
         double bot = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
         ObjectSetInteger(0, name, OBJPROP_TIME, 1, time[0] + (datetime)(InpOBExtendBars * PeriodSeconds()));
         bool isBull = StringFind(name, "Bull") >= 0;
         if(isBull && close[0] < bot)
            ObjectDelete(0, name);
         else if(!isBull && close[0] > top)
            ObjectDelete(0, name);
         else if(isBull && low[0] <= top && low[0] >= bot)
            AlertOnce("Pip XAUUSD: price touched a bullish order block", time[0]);
         else if(!isBull && high[0] >= bot && high[0] <= top)
            AlertOnce("Pip XAUUSD: price touched a bearish order block", time[0]);
      }
   }

   //--- 1-2-3: use the last confirmed fractal high/low as points 1/2/3 (simplified)
   if(InpShow123)
   {
      // Bullish: a fractal low higher than the previous fractal low, then break of last fractal high
      if(g_lastPl > 0 && g_lastPh > 0 && close[0] > g_lastPh && g_bull123 != 99)
      {
         DrawLabel("Pip_123_Bull", time[0], low[0], "1-2-3", clrGreen, true);
         AlertOnce("Pip XAUUSD: bullish 1-2-3 broke point 2", time[0]);
         g_bull123 = 99;
      }
      if(g_lastPl > 0 && g_lastPh > 0 && close[0] < g_lastPl && g_bear123 != 99)
      {
         DrawLabel("Pip_123_Bear", time[0], high[0], "1-2-3", clrRed, false);
         AlertOnce("Pip XAUUSD: bearish 1-2-3 broke point 2", time[0]);
         g_bear123 = 99;
      }
      if(close[0] < g_lastPl) g_bull123 = 0;
      if(close[0] > g_lastPh) g_bear123 = 0;
   }

   //--- Flag: strong 5-bar pole, shallow pullback, breakout of the pullback range
   if(InpShowFlag && rates_total > 20)
   {
      double a = atr[0] > 0 ? atr[0] : 1.0;
      double poleUp   = close[0] - close[5];
      double poleDown = close[5] - close[0];
      double hi5 = high[0], lo5 = low[0];
      for(int k = 1; k < 5; k++) { hi5 = MathMax(hi5, high[k]); lo5 = MathMin(lo5, low[k]); }
      double range5 = hi5 - lo5;
      if(poleUp > a * InpFlagPoleATR && range5 < poleUp * InpFlagMaxRet && close[0] > hi5)
      {
         DrawLabel("Pip_Flag_Bull", time[0], low[0], "FLAG", clrTeal, true);
         AlertOnce("Pip XAUUSD: bull flag breakout", time[0]);
      }
      if(poleDown > a * InpFlagPoleATR && range5 < poleDown * InpFlagMaxRet && close[0] < lo5)
      {
         DrawLabel("Pip_Flag_Bear", time[0], high[0], "FLAG", clrMaroon, false);
         AlertOnce("Pip XAUUSD: bear flag breakout", time[0]);
      }
   }

   //--- Fractal break alerts (newest bar only)
   if(g_lastPh > 0 && close[0] > g_lastPh && close[1] <= g_lastPh)
      AlertOnce("Pip XAUUSD: fractal high broken", time[0]);
   if(g_lastPl > 0 && close[0] < g_lastPl && close[1] >= g_lastPl)
      AlertOnce("Pip XAUUSD: fractal low broken", time[0]);

   return rates_total;
}
//+------------------------------------------------------------------+
