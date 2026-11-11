//+------------------------------------------------------------------+
//|  Pip v2.0 — Fractal / Trend / OB / 1-2-3 / Flag / FVG / BOS      |
//|  MT5 desktop indicator (MQL5). Does NOT run on MT5 mobile.       |
//|  TradingView v2 is in Pip_Fractal_OB_Flag_XAUUSD_v2.pine         |
//|                                                                    |
//|  v2 changes vs v1:                                                 |
//|   + HTF trend filter (default H1) — OBs only in HTF direction    |
//|   + Fair Value Gap (FVG) boxes                                     |
//|   + BOS / CHoCH and liquidity-sweep labels                         |
//|   + Premium / Discount (50% of last 50-bar swing range)            |
//|   + London / New York session filter for alerts (UTC)              |
//|   + SL / TP1 (1:2) / TP2 (1:3) lines on the last OB touch          |
//|   + Dashboard label: HTF trend, LTF trend, ATR, last signal       |
//|                                                                    |
//|  Install: MetaEditor (F4) -> MQL5/Indicators/ -> Compile (F7)     |
//|  -> drag onto an XAUUSD chart. Demo first.                         |
//|  Educational tool only — NOT a trading signal.                     |
//+------------------------------------------------------------------+
#property copyright "Pip v2 for Ilia — educational, XAUUSD tuned"
#property version   "2.00"
#property description "v2: Fractal, HTF trend, OB, FVG, BOS/CHoCH, sweep, 1-2-3, flags — XAUUSD"
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

input group "=== Trend + HTF ==="
input bool   InpShowTrend   = true;
input int    InpEmaFast     = 50;
input int    InpEmaSlow     = 200;
input ENUM_TIMEFRAMES InpHTF = PERIOD_H1;
input bool   InpOBOnlyHTF   = true;
input group "=== Fractal ==="
input bool   InpShowFractal = true;
input int    InpFractalBars = 2;
input group "=== Order Block — XAUUSD ==="
input bool   InpShowOB      = true;
input int    InpOBLookback  = 50;
input double InpOBDispATR   = 1.0;
input int    InpOBMax       = 8;
input int    InpOBExtendBars= 30;
input group "=== FVG / BOS / Sweep ==="
input bool   InpShowFVG     = true;
input bool   InpShowBOS     = true;
input bool   InpShowSweep   = true;
input group "=== 1-2-3 / Flag ==="
input bool   InpShow123     = true;
input bool   InpShowFlag    = true;
input double InpFlagPoleATR = 1.5;
input double InpFlagMaxRet  = 0.5;
input group "=== Session (UTC) ==="
input bool   InpUseSession  = false;
input int    InpLondonStart = 7;
input int    InpLondonEnd   = 11;
input int    InpNYStart     = 12;
input int    InpNYEnd       = 16;
input group "=== Risk / Alerts ==="
input bool   InpShowRisk    = true;
input bool   InpAlerts      = true;
input bool   InpPush        = true;

double FractalUp[], FractalDown[], EmaFastBuf[], EmaSlowBuf[];
int hEmaFast = INVALID_HANDLE, hEmaSlow = INVALID_HANDLE, hAtr = INVALID_HANDLE;
int hHtfEmaF = INVALID_HANDLE, hHtfEmaS = INVALID_HANDLE;
datetime g_lastAlertBar = 0;
int      g_obCount = 0, g_fvgCount = 0;
double   g_lastPh = 0.0, g_lastPl = 0.0;
string   g_lastSignal = "—";

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, FractalUp,   INDICATOR_DATA);
   SetIndexBuffer(1, FractalDown, INDICATOR_DATA);
   SetIndexBuffer(2, EmaFastBuf,  INDICATOR_DATA);
   SetIndexBuffer(3, EmaSlowBuf,  INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 234);
   PlotIndexSetInteger(1, PLOT_ARROW, 233);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   ArraySetAsSeries(FractalUp, true); ArraySetAsSeries(FractalDown, true);
   ArraySetAsSeries(EmaFastBuf, true); ArraySetAsSeries(EmaSlowBuf, true);
   hEmaFast = iMA(_Symbol, _Period, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hEmaSlow = iMA(_Symbol, _Period, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   hAtr     = iATR(_Symbol, _Period, 14);
   hHtfEmaF = iMA(_Symbol, InpHTF, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   hHtfEmaS = iMA(_Symbol, InpHTF, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   if(hEmaFast==INVALID_HANDLE || hEmaSlow==INVALID_HANDLE || hAtr==INVALID_HANDLE ||
      hHtfEmaF==INVALID_HANDLE || hHtfEmaS==INVALID_HANDLE) return INIT_FAILED;
   IndicatorSetString(INDICATOR_SHORTNAME, "Pip v2 OB/Flag XAUUSD");
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i = ObjectsTotal(0,-1,-1)-1; i>=0; i--)
   {
      string n = ObjectName(0,i,-1,-1);
      if(StringFind(n,"Pip_")==0) ObjectDelete(0,n);
   }
   if(hEmaFast!=INVALID_HANDLE) IndicatorRelease(hEmaFast);
   if(hEmaSlow!=INVALID_HANDLE) IndicatorRelease(hEmaSlow);
   if(hAtr!=INVALID_HANDLE) IndicatorRelease(hAtr);
   if(hHtfEmaF!=INVALID_HANDLE) IndicatorRelease(hHtfEmaF);
   if(hHtfEmaS!=INVALID_HANDLE) IndicatorRelease(hHtfEmaS);
}
//+------------------------------------------------------------------+
bool InSession()
{
   if(!InpUseSession) return true;
   MqlDateTime dt; TimeToStruct(TimeGMT(), dt);
   return (dt.hour>=InpLondonStart && dt.hour<InpLondonEnd) ||
          (dt.hour>=InpNYStart && dt.hour<InpNYEnd);
}
void AlertOnce(string text, datetime barTime)
{
   if(!InpAlerts || !InSession()) return;
   if(barTime==g_lastAlertBar) return;
   g_lastAlertBar = barTime;
   g_lastSignal = text;
   Alert(text);
   if(InpPush) SendNotification(text);
}
void DrawLabel(string name, datetime t, double price, string text, color col, bool below)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TEXT,0,t,price);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR, below?ANCHOR_UPPER:ANCHOR_LOWER);
   ObjectSetInteger(0,name,OBJPROP_TIME,0,t);
   ObjectSetDouble(0,name,OBJPROP_PRICE,0,price);
}
void DrawRect(string name, datetime t1, double top, double bottom, color col)
{
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_RECTANGLE,0,t1,top,t1+(datetime)(InpOBExtendBars*PeriodSeconds()),bottom);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
}
void DrawRiskLines(double entry, double sl, bool isBull)
{
   if(!InpShowRisk) return;
   double risk = MathAbs(entry-sl);
   double tp1 = isBull ? entry+risk*2 : entry-risk*2;
   double tp2 = isBull ? entry+risk*3 : entry-risk*3;
   string names[3] = {"Pip_SL","Pip_TP1","Pip_TP2"};
   double vals[3]  = {sl, tp1, tp2};
   color  cols[3]  = {clrRed, clrGreen, clrGreen};
   for(int i=0;i<3;i++)
   {
      if(ObjectFind(0,names[i])<0)
         ObjectCreate(0,names[i],OBJ_HLINE,0,0,vals[i]);
      ObjectSetDouble(0,names[i],OBJPROP_PRICE,vals[i]);
      ObjectSetInteger(0,names[i],OBJPROP_COLOR,cols[i]);
      ObjectSetInteger(0,names[i],OBJPROP_STYLE, i==0?STYLE_DASH:STYLE_DOT);
   }
}
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[], const double &high[],
                const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   if(rates_total < 250) return 0;
   double emaF[], emaS[], atr[], htfF[], htfS[], htfClose[];
   ArraySetAsSeries(emaF,true); ArraySetAsSeries(emaS,true); ArraySetAsSeries(atr,true);
   ArraySetAsSeries(htfF,true); ArraySetAsSeries(htfS,true); ArraySetAsSeries(htfClose,true);
   if(CopyBuffer(hEmaFast,0,0,rates_total,emaF)<=0) return prev_calculated;
   if(CopyBuffer(hEmaSlow,0,0,rates_total,emaS)<=0) return prev_calculated;
   if(CopyBuffer(hAtr,0,0,rates_total,atr)<=0) return prev_calculated;
   if(CopyBuffer(hHtfEmaF,0,0,10,htfF)<=0) return prev_calculated;
   if(CopyBuffer(hHtfEmaS,0,0,10,htfS)<=0) return prev_calculated;
   // HTF close: use iClose on HTF
   double htfC = iClose(_Symbol, InpHTF, 0);
   int htfTrend = 0;
   if(htfC > htfF[0] && htfF[0] > htfS[0]) htfTrend = 1;
   else if(htfC < htfF[0] && htfF[0] < htfS[0]) htfTrend = -1;

   int start = prev_calculated==0 ? 250 : prev_calculated-1;
   if(start < 250) start = 250;
   for(int i=start;i>=0;i--){ EmaFastBuf[i]=emaF[i]; EmaSlowBuf[i]=emaS[i]; FractalUp[i]=0.0; FractalDown[i]=0.0; }

   // Fractals
   for(int i=2;i<rates_total-2;i++)
   {
      if(!InpShowFractal) break;
      bool up=true, dn=true;
      for(int k=1;k<=InpFractalBars;k++)
      {
         if(high[i]<=high[i-k] || high[i]<=high[i+k]) up=false;
         if(low[i]>=low[i-k] || low[i]>=low[i+k]) dn=false;
      }
      if(up){ FractalUp[i]=high[i]; g_lastPh=high[i]; }
      if(dn){ FractalDown[i]=low[i];  g_lastPl=low[i]; }
   }

   // Dashboard / trend label
   if(InpShowTrend)
   {
      int trend = 0; string txt; color col=clrGray;
      if(close[0]>emaF[0] && emaF[0]>emaS[0]){ trend=1; txt="Pip v2 | HTF "+(htfTrend==1?"UP":htfTrend==-1?"DOWN":"FLAT")+" | LTF UP | ATR "+DoubleToString(atr[0],2); col=clrGreen; }
      else if(close[0]<emaF[0] && emaF[0]<emaS[0]){ trend=-1; txt="Pip v2 | HTF "+(htfTrend==1?"UP":htfTrend==-1?"DOWN":"FLAT")+" | LTF DOWN | ATR "+DoubleToString(atr[0],2); col=clrRed; }
      else { txt="Pip v2 | HTF "+(htfTrend==1?"UP":htfTrend==-1?"DOWN":"FLAT")+" | LTF FLAT | ATR "+DoubleToString(atr[0],2); }
      if(!InSession()) txt += " | OFF-SESSION";
      txt += " | Last: " + g_lastSignal;
      string lname="Pip_Trend";
      if(ObjectFind(0,lname)<0) ObjectCreate(0,lname,OBJ_LABEL,0,0,0);
      ObjectSetString(0,lname,OBJPROP_TEXT,txt);
      ObjectSetInteger(0,lname,OBJPROP_COLOR,col);
      ObjectSetInteger(0,lname,OBJPROP_FONTSIZE,10);
      ObjectSetInteger(0,lname,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,lname,OBJPROP_XDISTANCE,10);
      ObjectSetInteger(0,lname,OBJPROP_YDISTANCE,15);
   }

   // Premium / Discount: 50% of last 50-bar range
   double swHi=high[0], swLo=low[0];
   for(int k=1;k<50 && k<rates_total;k++){ swHi=MathMax(swHi,high[k]); swLo=MathMin(swLo,low[k]); }
   double eq=(swHi+swLo)/2.0;
   if(ObjectFind(0,"Pip_EQ")<0) ObjectCreate(0,"Pip_EQ",OBJ_HLINE,0,0,eq);
   ObjectSetDouble(0,"Pip_EQ",OBJPROP_PRICE,eq);
   ObjectSetInteger(0,"Pip_EQ",OBJPROP_COLOR,clrGray);
   ObjectSetInteger(0,"Pip_EQ",OBJPROP_STYLE,STYLE_DOT);

   // BOS / CHoCH + Sweep (newest bar)
   if(InpShowBOS)
   {
      if(g_lastPh>0 && close[0]>g_lastPh && close[1]<=g_lastPh)
      {
         string t = (close[0]>emaF[0]) ? "BOS" : "CHoCH";
         DrawLabel("Pip_BOS_Up", time[0], low[0], t, clrTeal, true);
         AlertOnce("Pip v2 XAUUSD: swing high broken ("+t+")", time[0]);
      }
      if(g_lastPl>0 && close[0]<g_lastPl && close[1]>=g_lastPl)
      {
         string t = (close[0]<emaF[0]) ? "BOS" : "CHoCH";
         DrawLabel("Pip_BOS_Down", time[0], high[0], t, clrMaroon, false);
         AlertOnce("Pip v2 XAUUSD: swing low broken ("+t+")", time[0]);
      }
   }
   if(InpShowSweep)
   {
      if(g_lastPh>0 && high[0]>g_lastPh && close[0]<g_lastPh)
      {
         DrawLabel("Pip_Sweep_Up", time[0], high[0], "SWEEP", clrPurple, false);
         AlertOnce("Pip v2 XAUUSD: liquidity sweep above high", time[0]);
      }
      if(g_lastPl>0 && low[0]<g_lastPl && close[0]>g_lastPl)
      {
         DrawLabel("Pip_Sweep_Down", time[0], low[0], "SWEEP", clrPurple, true);
         AlertOnce("Pip v2 XAUUSD: liquidity sweep below low", time[0]);
      }
   }

   // FVG: low > high[2] (bull) / high < low[2] (bear)
   if(InpShowFVG && rates_total>5)
   {
      if(low[1] > high[3] && close[1] > open[1])
         DrawRect("Pip_FVG_Bull_"+IntegerToString(g_fvgCount++), time[3], low[1], high[3], clrAqua);
      if(high[1] < low[3] && close[1] < open[1])
         DrawRect("Pip_FVG_Bear_"+IntegerToString(g_fvgCount++), time[3], high[1], low[3], clrMagenta);
      for(int i=ObjectsTotal(0,-1,-1)-1;i>=0;i--)
      {
         string n=ObjectName(0,i,-1,-1);
         if(StringFind(n,"Pip_FVG_")!=0) continue;
         double top=ObjectGetDouble(0,n,OBJPROP_PRICE,0);
         double bot=ObjectGetDouble(0,n,OBJPROP_PRICE,1);
         bool isBull = StringFind(n,"Bull")>=0;
         if(isBull && low[0]<=top) ObjectDelete(0,n);
         else if(!isBull && high[0]>=bot) ObjectDelete(0,n);
      }
   }

   // Order blocks (HTF-filtered)
   if(InpShowOB && rates_total>InpOBLookback+5)
   {
      double a = atr[1]>0 ? atr[1] : 1.0;
      bool bullOK = !InpOBOnlyHTF || htfTrend>=0;
      bool bearOK = !InpOBOnlyHTF || htfTrend<=0;
      if(bullOK && close[1]>open[1] && (close[1]-open[1])>a*InpOBDispATR && close[1]>high[2])
      {
         for(int j=2;j<=6;j++) if(close[j]<open[j])
         {
            DrawRect("Pip_OB_Bull_"+IntegerToString(g_obCount++), time[j], high[j], low[j], clrGreen);
            break;
         }
      }
      if(bearOK && close[1]<open[1] && (open[1]-close[1])>a*InpOBDispATR && close[1]<low[2])
      {
         for(int j=2;j<=6;j++) if(close[j]>open[j])
         {
            DrawRect("Pip_OB_Bear_"+IntegerToString(g_obCount++), time[j], high[j], low[j], clrRed);
            break;
         }
      }
      for(int i=ObjectsTotal(0,-1,-1)-1;i>=0;i--)
      {
         string n=ObjectName(0,i,-1,-1);
         if(StringFind(n,"Pip_OB_")!=0) continue;
         double top=ObjectGetDouble(0,n,OBJPROP_PRICE,0);
         double bot=ObjectGetDouble(0,n,OBJPROP_PRICE,1);
         ObjectSetInteger(0,n,OBJPROP_TIME,1,time[0]+(datetime)(InpOBExtendBars*PeriodSeconds()));
         bool isBull = StringFind(n,"Bull")>=0;
         if(isBull && close[0]<bot) ObjectDelete(0,n);
         else if(!isBull && close[0]>top) ObjectDelete(0,n);
         else if(isBull && low[0]<=top && low[0]>=bot)
         {
            DrawRiskLines(close[0], bot-atr[0]*0.2, true);
            AlertOnce("Pip v2 XAUUSD: price touched a bullish order block (HTF-filtered)", time[0]);
         }
         else if(!isBull && high[0]>=bot && high[0]<=top)
         {
            DrawRiskLines(close[0], top+atr[0]*0.2, false);
            AlertOnce("Pip v2 XAUUSD: price touched a bearish order block (HTF-filtered)", time[0]);
         }
      }
   }

   // 1-2-3 (simplified, same as v1)
   if(InpShow123)
   {
      if(g_lastPl>0 && g_lastPh>0 && close[0]>g_lastPh)
      {
         DrawLabel("Pip_123_Bull", time[0], low[0], "1-2-3", clrGreen, true);
         AlertOnce("Pip v2 XAUUSD: bullish 1-2-3 broke point 2", time[0]);
      }
      if(g_lastPl>0 && g_lastPh>0 && close[0]<g_lastPl)
      {
         DrawLabel("Pip_123_Bear", time[0], high[0], "1-2-3", clrRed, false);
         AlertOnce("Pip v2 XAUUSD: bearish 1-2-3 broke point 2", time[0]);
      }
   }

   // Flag
   if(InpShowFlag && rates_total>20)
   {
      double a=atr[0]>0?atr[0]:1.0;
      double poleUp=close[0]-close[5], poleDown=close[5]-close[0];
      double hi5=high[0], lo5=low[0];
      for(int k=1;k<5;k++){ hi5=MathMax(hi5,high[k]); lo5=MathMin(lo5,low[k]); }
      if(poleUp>a*InpFlagPoleATR && (hi5-lo5)<poleUp*InpFlagMaxRet && close[0]>hi5)
      {
         DrawLabel("Pip_Flag_Bull", time[0], low[0], "FLAG", clrTeal, true);
         AlertOnce("Pip v2 XAUUSD: bull flag breakout", time[0]);
      }
      if(poleDown>a*InpFlagPoleATR && (hi5-lo5)<poleDown*InpFlagMaxRet && close[0]<lo5)
      {
         DrawLabel("Pip_Flag_Bear", time[0], high[0], "FLAG", clrMaroon, false);
         AlertOnce("Pip v2 XAUUSD: bear flag breakout", time[0]);
      }
   }

   return rates_total;
}
//+------------------------------------------------------------------+
