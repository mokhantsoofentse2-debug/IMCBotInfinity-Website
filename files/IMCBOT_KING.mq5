//+------------------------------------------------------------------+
//|                                  IMCBOT KING - UNIVERSAL V1.1    |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

// --- User & Security Inputs ---
input string BotPassword = "";
input double RiskPercent = 15.0;   
input int Lookback = 60;               
input int MaxPositions = 5; 
input double MaxLotLimit = 0.50;   
input long MagicNumber = 888111;   

//--- Global Variables
double H1_Trap_High = 0, H1_Trap_Low = 0;
int    Last_Confirmed_Swing = 0; 
double Last_Entry_SL = 0; 

string IconName = "IMCBOT_V10_ICON";
string TextName = "IMCBOT_V10_TEXT";

// --- CLOUD COMMAND CENTER ---
void CheckWebsiteCommands() {
   string cookie=NULL, headers;
   char post[], result[];
   // Ensure the domain is added to MT5 -> Tools -> Options -> Expert Advisors -> Allow WebRequest
   string url = "https://your-website.com/api/trade-status.json"; 
   
   int res = WebRequest("GET", url, cookie, NULL, 500, post, 0, result, headers);

   if(res == 200) {
      string response = CharArrayToString(result);
      
      // Parse for BUY command
      if(StringFind(response, "\"action\":\"buy\"") >= 0 && !IsBotTradeOpen()) {
         double sl = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 15, 1));
         double lot = CalculateLotSize(sl);
         if(lot > 0) {
            trade.Buy(lot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, 0, "(IMCBOT_KING)Cloud_Buy");
            Print("Cloud Command Executed: Buy Order Opened");
         }
      }
      
      // Parse for SELL command
      if(StringFind(response, "\"action\":\"sell\"") >= 0 && !IsBotTradeOpen()) {
         double sl = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 15, 1));
         double lot = CalculateLotSize(sl);
         if(lot > 0) {
            trade.Sell(lot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, 0, "(IMCBOT_KING)Cloud_Sell");
            Print("Cloud Command Executed: Sell Order Opened");
         }
      }
   }
}

//--- Helper Functions
double GetATR(string symbol, ENUM_TIMEFRAMES timeframe, int period, int shift) {
   double res[1];
   int handle = iATR(symbol, timeframe, period);
   if(handle == INVALID_HANDLE) return 0;
   if(CopyBuffer(handle, 0, shift, 1, res) > 0) return res[0];
   return 0;
}

bool IsBotTradeOpen() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionSelectByTicket(PositionGetTicket(i))) {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) return true;
      }
   }
   return false;
}

//--- UPDATED: TRAILING LOGIC (Starts at 50% to Swing Target)
void ManageTrailingAndHolding() {
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   
   double m5_close1 = iClose(_Symbol, PERIOD_M5, 1);
   double m5_open1  = iOpen(_Symbol, PERIOD_M5, 1);
   double m5_high2  = iHigh(_Symbol, PERIOD_M5, 2);
   double m5_low2   = iLow(_Symbol, PERIOD_M5, 2);
   double m5_low1   = iLow(_Symbol, PERIOD_M5, 1);
   double m5_high1  = iHigh(_Symbol, PERIOD_M5, 1);

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            
            double entry = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            // BREAK EVEN LOGIC: 5% distance -> 2% profit
            double breakEvenDist = entry * 0.05;
            double profitLock = entry * 0.02;

            if(type == POSITION_TYPE_BUY) {
               if(currentBid >= (entry + breakEvenDist)) {
                  double targetBE = entry + profitLock;
                  if(sl < targetBE) trade.PositionModify(ticket, NormalizeDouble(targetBE, _Digits), 0);
               }
            } else {
               if(currentAsk <= (entry - breakEvenDist)) {
                  double targetBE = entry - profitLock;
                  if(sl > targetBE || sl == 0) trade.PositionModify(ticket, NormalizeDouble(targetBE, _Digits), 0);
               }
            }

            // Determine Swing Target based on setup
            double swingTarget = (type == POSITION_TYPE_BUY) ? H1_Trap_High : H1_Trap_Low;
            double totalDistance = MathAbs(swingTarget - entry);
            double currentProgress = (type == POSITION_TYPE_BUY) ? (currentBid - entry) : (entry - currentAsk);

            // ONLY TRAIL IF 50% TOWARDS TARGET
            if(currentProgress >= (totalDistance * 0.5)) {
               if(type == POSITION_TYPE_BUY) {
                  if(m5_close1 > m5_open1 && m5_close1 > m5_high2) {
                     double newSL = m5_low1 - spread;
                     if(newSL > sl) trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), 0);
                  }
               } else {
                  if(m5_close1 < m5_open1 && m5_close1 < m5_low2) {
                     double newSL = m5_high1 + spread;
                     if(newSL < sl || sl == 0) trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), 0);
                  }
               }
            }
         }
      }
   }
}

double CalculateLotSize(double sl_price) {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double entryPrice = (sl_price < SymbolInfoDouble(_Symbol, SYMBOL_ASK)) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID); 
   double slDistPoints = MathAbs(entryPrice - sl_price) / _Point;
   if(slDistPoints <= 0) return 0.01;
   double lot = riskAmount / (slDistPoints * _Point * (tickValue / tickSize));
   lot = NormalizeDouble(lot, 2);
   if(lot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lot > MaxLotLimit) lot = MaxLotLimit;
   return lot;
}

void UpdateStatus(string message, bool isError = false) {
   bool hasTrades = IsBotTradeOpen();
   
   color textColor = hasTrades ? (color)0x22188A : (color)0x2525FF;
   
   if(ObjectFind(0, IconName) < 0) ObjectCreate(0, IconName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, IconName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, IconName, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, IconName, OBJPROP_YDISTANCE, 40);
   ObjectSetString(0, IconName, OBJPROP_FONT, "Webdings");
   ObjectSetString(0, IconName, OBJPROP_TEXT, CharToString(131)); 
   ObjectSetInteger(0, IconName, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, IconName, OBJPROP_FONTSIZE, 14);
   
   if(ObjectFind(0, TextName) < 0) ObjectCreate(0, TextName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, TextName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, TextName, OBJPROP_XDISTANCE, 45); 
   ObjectSetInteger(0, TextName, OBJPROP_YDISTANCE, 43);
   ObjectSetString(0, TextName, OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, TextName, OBJPROP_TEXT, "IMCBOT KING [" + _Symbol + "]: " + message);
   ObjectSetInteger(0, TextName, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, TextName, OBJPROP_FONTSIZE, 9);
   ChartRedraw(0); 
}

bool ConfirmM1Sword(ENUM_POSITION_TYPE type) {
   if(type == POSITION_TYPE_BUY) return (iClose(_Symbol, PERIOD_M1, 1) < iOpen(_Symbol, PERIOD_M1, 1) && iClose(_Symbol, PERIOD_M1, 0) > iHigh(_Symbol, PERIOD_M1, 1));
   else return (iClose(_Symbol, PERIOD_M1, 1) > iOpen(_Symbol, PERIOD_M1, 1) && iClose(_Symbol, PERIOD_M1, 0) < iLow(_Symbol, PERIOD_M1, 1));
}

void OnTick() {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) { UpdateStatus("ALGO BUTTON OFF", true); return; }
   if(_Period != PERIOD_M5) { UpdateStatus("SWITCH TO M5"); return; }
   
   // --- ACTIVE CLOUD MONITORING ---
   CheckWebsiteCommands();

   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   trade.SetExpertMagicNumber(MagicNumber);
   bool tradeIsOpen = IsBotTradeOpen();
   if(!tradeIsOpen) { Last_Confirmed_Swing = 0; Last_Entry_SL = 0; }

   if(tradeIsOpen) { ManageTrailingAndHolding(); }

   H1_Trap_High = iHigh(_Symbol, PERIOD_H1, iHighest(_Symbol, PERIOD_H1, MODE_HIGH, Lookback, 1));
   H1_Trap_Low = iLow(_Symbol, PERIOD_H1, iLowest(_Symbol, PERIOD_H1, MODE_LOW, Lookback, 1));
   double close = iClose(_Symbol, PERIOD_M5, 0);
   
   // SENSITIVE EMA CROSS ON M5
   double ema5 = iMA(_Symbol, PERIOD_M5, 5, 0, MODE_EMA, PRICE_CLOSE);
   double ema10 = iMA(_Symbol, PERIOD_M5, 10, 0, MODE_EMA, PRICE_CLOSE);
   bool emaBuyAllowed = (ema5 > ema10);
   bool emaSellAllowed = (ema10 > ema5);

   // CHOCH & STRUCTURE BODY BREAK LOGIC (M5)
   double m5_high1 = iHigh(_Symbol, PERIOD_M5, 1);
   double m5_low1  = iLow(_Symbol, PERIOD_M5, 1);
   double m5_close1 = iClose(_Symbol, PERIOD_M5, 1);
   double prev_high = iHigh(_Symbol, PERIOD_M5, 2);
   double prev_low  = iLow(_Symbol, PERIOD_M5, 2);

   bool chochBuy = (m5_close1 > prev_high); // Body break of previous structure
   bool chochSell = (m5_close1 < prev_low); // Body break of previous structure

   double trapRange = H1_Trap_High - H1_Trap_Low;
   bool isLateBuy = (close - H1_Trap_Low) > (trapRange * 0.25);
   bool isLateSell = (H1_Trap_High - close) > (trapRange * 0.25);

   if(tradeIsOpen) UpdateStatus("MANAGING TRADE");
   else {
      if(emaBuyAllowed) UpdateStatus(isLateBuy ? "LATE BUY: WAITING SWING" : "SCAN SETUP BUY");
      else if(emaSellAllowed) UpdateStatus(isLateSell ? "LATE SELL: WAITING SWING" : "SCAN SETUP SELL");
      else UpdateStatus("WAITING H1 TRAP");
   }

   // ENTRY EXECUTION WITH COMBINED CONDITIONS
   if(!tradeIsOpen && Last_Confirmed_Swing == 0) {
      // BUY SETUP: EMA Cross + ChoCh + Body Break
      if(emaBuyAllowed && chochBuy && !isLateBuy && close > iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 5, 1))) {
         double sl = H1_Trap_Low - spread;
         if(trade.Buy(CalculateLotSize(sl), _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, 0, "(IMCBOT_King) Setup_Entry")) {
            Last_Confirmed_Swing = 1; Last_Entry_SL = sl;
         }
      } 
      // SELL SETUP: EMA Cross + ChoCh + Body Break
      else if(emaSellAllowed && chochSell && !isLateSell && close < iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 5, 1))) {
         double sl = H1_Trap_High + spread;
         if(trade.Sell(CalculateLotSize(sl), _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, 0, "(IMCBOT_King) Setup_Entry")) {
            Last_Confirmed_Swing = 1; Last_Entry_SL = sl;
         }
      }
      if((emaBuyAllowed && isLateBuy) || (emaSellAllowed && isLateSell)) Last_Confirmed_Swing = 1; 
   }

   if(Last_Confirmed_Swing >= 2) {
      double s2_high = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 15, 5));
      double s2_low = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 15, 5));

      if(emaSellAllowed) {
         bool m5_wick_touch = (iHigh(_Symbol, PERIOD_M5, 1) >= s2_high && iClose(_Symbol, PERIOD_M5, 1) <= s2_high);
         if(m5_wick_touch) {
            bool m1_break_1 = (iClose(_Symbol, PERIOD_M1, 1) < iLow(_Symbol, PERIOD_M1, 2));
            bool m1_break_2 = (iClose(_Symbol, PERIOD_M1, 0) < iLow(_Symbol, PERIOD_M1, 1));
            double pullback_bull_low = iLow(_Symbol, PERIOD_M1, 3); 
            bool pullback_broken = (iClose(_Symbol, PERIOD_M1, 0) < pullback_bull_low);
            if(m1_break_1 && m1_break_2 && pullback_broken) {
               double sl = s2_high + spread;
               trade.Sell(CalculateLotSize(sl), _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, 0, "(IMCBOT_KING)M_Entry");
            }
         }
      }
      else if(emaBuyAllowed) {
         bool m5_wick_touch = (iLow(_Symbol, PERIOD_M5, 1) <= s2_low && iClose(_Symbol, PERIOD_M5, 1) >= s2_low);
         if(m5_wick_touch) {
            bool m1_break_1 = (iClose(_Symbol, PERIOD_M1, 1) > iHigh(_Symbol, PERIOD_M1, 2));
            bool m1_break_2 = (iClose(_Symbol, PERIOD_M1, 0) > iHigh(_Symbol, PERIOD_M1, 1));
            double pullback_bear_high = iHigh(_Symbol, PERIOD_M1, 3);
            bool pullback_broken = (iClose(_Symbol, PERIOD_M1, 0) > pullback_bear_high);
            if(m1_break_1 && m1_break_2 && pullback_broken) {
               double sl = s2_low - spread;
               trade.Buy(CalculateLotSize(sl), _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, 0, "(IMCBOT_KING)M_Entry");
            }
         }
      }
   }

   if(PositionsTotal() < MaxPositions && Last_Confirmed_Swing >= 1) {
      bool setupIsBullish = (Last_Entry_SL < close && Last_Entry_SL != 0) || (emaBuyAllowed && !emaSellAllowed && !tradeIsOpen);
      ENUM_POSITION_TYPE type = (setupIsBullish) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      double structLow = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 15, 1));
      double structHigh = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 15, 1));
      double fib50 = structLow + (structHigh - structLow) * 0.5;

      if(((type == POSITION_TYPE_BUY && close <= fib50) || (type == POSITION_TYPE_SELL && close >= fib50)) && ConfirmM1Sword(type)) {
         double current_struct_sl = (type == POSITION_TYPE_BUY) ? (structLow - spread) : (structHigh + spread);
         double sl = (Last_Entry_SL != 0) ? Last_Entry_SL : current_struct_sl;
         string comment = (PositionsTotal() == 0) ? "(IMCBOT_KING) Late Join" : "(IMCBOT_King) Swing_Entry";
         if(type == POSITION_TYPE_BUY) {
            if(trade.Buy(CalculateLotSize(sl), _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, 0, comment)) { Last_Confirmed_Swing++; Last_Entry_SL = sl; }
         } else {
            if(trade.Sell(CalculateLotSize(sl), _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, 0, comment)) { Last_Confirmed_Swing++; Last_Entry_SL = sl; }
         }
      }
   }
}

int OnInit() { 
   if(BotPassword != "IMCBOTKing_10111") {
      Alert("UNAUTHORIZED: Invalid Password for IMCBOT King.");
      ExpertRemove(); 
      return(INIT_FAILED);
   }
   trade.SetExpertMagicNumber(MagicNumber); 
   return(INIT_SUCCEEDED); 
}

void OnDeinit(const int reason) { 
   ObjectDelete(0, IconName); 
   ObjectDelete(0, TextName); 
}
