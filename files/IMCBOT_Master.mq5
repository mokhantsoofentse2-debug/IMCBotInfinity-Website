//+------------------------------------------------------------------+
//|                                  IMCBOT MASTER - UNIVERSAL V10.3 |
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
double M15_Trap_High = 0, M15_Trap_Low = 0;
int    Last_Confirmed_Swing = 0; 
double Last_Entry_SL = 0; 

string IconName = "IMCBOT_V10_ICON";
string TextName = "IMCBOT_V10_TEXT";

//--- HELPER: CHECK IF THIS BOT HAS TRADES ON THIS SPECIFIC SYMBOL
bool IsBotTradeOpen() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionSelectByTicket(PositionGetTicket(i))) {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            return true;
         }
      }
   }
   return false;
}

//--- BREAK EVEN LOGIC ---
void ManageBreakEven() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            
            double entry = PositionGetDouble(POSITION_PRICE_OPEN);
            double tp = PositionGetDouble(POSITION_TP);
            double sl = PositionGetDouble(POSITION_SL);
            double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            string comment = PositionGetString(POSITION_COMMENT);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

            double totalDistance = MathAbs(tp - entry);
            if(totalDistance <= 0) continue;

            // --- NEW 4% / 1.5% BREAK EVEN ADDITION ---
            double distFromEntry = (type == POSITION_TYPE_BUY) ? (currentBid - entry) : (entry - currentAsk);
            double fivePercentTrigger = entry * 0.04;
            double twoPercentProfit = entry * 0.015;

            if(distFromEntry >= fivePercentTrigger) {
               double beSL = (type == POSITION_TYPE_BUY) ? NormalizeDouble(entry + twoPercentProfit, _Digits) : NormalizeDouble(entry - twoPercentProfit, _Digits);
               if((type == POSITION_TYPE_BUY && sl < beSL) || (type == POSITION_TYPE_SELL && (sl > beSL || sl == 0))) {
                  trade.PositionModify(ticket, beSL, tp);
                  continue; // Move to next position after modifying
               }
            }

            // --- EXISTING BREAK EVEN LOGIC ---
            double triggerLevel = 0;
            double profitLockLevel = 0;

            if(StringFind(comment, "Setup_Entry") >= 0) {
               triggerLevel = totalDistance * 0.40;   
               profitLockLevel = totalDistance * 0.20; 
            } else {
               triggerLevel = totalDistance * 0.30;   
               profitLockLevel = totalDistance * 0.15; 
            }

            if(type == POSITION_TYPE_BUY) {
               double currentProfitPoints = currentBid - entry;
               double newSL = NormalizeDouble(entry + profitLockLevel, _Digits);
               if(currentProfitPoints >= triggerLevel && sl < newSL) {
                  trade.PositionModify(ticket, newSL, tp);
               }
            } 
            else if(type == POSITION_TYPE_SELL) {
               double currentProfitPoints = entry - currentAsk;
               double newSL = NormalizeDouble(entry - profitLockLevel, _Digits);
               if(currentProfitPoints >= triggerLevel && (sl > newSL || sl == 0)) {
                  trade.PositionModify(ticket, newSL, tp);
               }
            }
         }
      }
   }
}

//--- DYNAMIC LOT CALCULATION
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

//--- PRO VISUAL STATUS
void UpdateStatus(string message, bool isError = false) {
  
   color textColor = IsBotTradeOpen() ? clrCyan : clrDodgerBlue;
   
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
   ObjectSetString(0, TextName, OBJPROP_TEXT, "IMCBOT MASTER [" + _Symbol + "]: " + message);
   ObjectSetInteger(0, TextName, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, TextName, OBJPROP_FONTSIZE, 9);
   ChartRedraw(0); 
}

//--- SWORD & SWING LOGIC
bool ConfirmM1Sword(ENUM_POSITION_TYPE type) {
   if(type == POSITION_TYPE_BUY) return (iClose(_Symbol, PERIOD_M1, 1) < iOpen(_Symbol, PERIOD_M1, 1) && iClose(_Symbol, PERIOD_M1, 0) > iHigh(_Symbol, PERIOD_M1, 1));
   else return (iClose(_Symbol, PERIOD_M1, 1) > iOpen(_Symbol, PERIOD_M1, 1) && iClose(_Symbol, PERIOD_M1, 0) < iLow(_Symbol, PERIOD_M1, 1));
}

void OnTick() {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) { UpdateStatus("ALGO BUTTON OFF", true); return; }
   if(_Period != PERIOD_M5) { UpdateStatus("SWITCH TO M5"); return; }
   
   trade.SetExpertMagicNumber(MagicNumber);
   bool tradeIsOpen = IsBotTradeOpen();
   if(!tradeIsOpen) { Last_Confirmed_Swing = 0; Last_Entry_SL = 0; }
   if(tradeIsOpen) ManageBreakEven();

   // --- EMA 5 & 10 ON M5 TIMEFRAME ---
   double ema5 = iMA(_Symbol, PERIOD_M5, 5, 0, MODE_EMA, PRICE_CLOSE);
   double ema10 = iMA(_Symbol, PERIOD_M5, 10, 0, MODE_EMA, PRICE_CLOSE);
   
   bool emaBullish = (ema5 > ema10);
   bool emaBearish = (ema10 > ema5);

   // --- CHOCH & STRUCTURE SWING DETECTION (M5) ---
   // ChoCh: Price breaking previous minor high/low
   bool chochBuy = iClose(_Symbol, PERIOD_M5, 0) > iHigh(_Symbol, PERIOD_M5, 1);
   bool chochSell = iClose(_Symbol, PERIOD_M5, 0) < iLow(_Symbol, PERIOD_M5, 1);

   // 1st Complete Structure Swing (Body Break)
   bool bodyBreakBuy = iClose(_Symbol, PERIOD_M5, 1) > iHigh(_Symbol, PERIOD_M5, 2);
   bool bodyBreakSell = iClose(_Symbol, PERIOD_M5, 1) < iLow(_Symbol, PERIOD_M5, 2);

   M15_Trap_High = iHigh(_Symbol, PERIOD_M15, iHighest(_Symbol, PERIOD_M15, MODE_HIGH, Lookback, 1));
   M15_Trap_Low = iLow(_Symbol, PERIOD_M15, iLowest(_Symbol, PERIOD_M15, MODE_LOW, Lookback, 1));
   double close = iClose(_Symbol, PERIOD_M5, 0);

   double trapRange = M15_Trap_High - M15_Trap_Low;
   bool isLateBuy = (close - M15_Trap_Low) > (trapRange * 0.25);
   bool isLateSell = (M15_Trap_High - close) > (trapRange * 0.25);

   if(tradeIsOpen) UpdateStatus("MANAGING TRADE");
   else {
      if(emaBullish) UpdateStatus(isLateBuy ? "LATE BUY: WAITING SWING" : "SCAN SETUP BUY");
      else if(emaBearish) UpdateStatus(isLateSell ? "LATE SELL: WAITING SWING" : "SCAN SETUP SELL");
      else UpdateStatus("WAITING M5 EMA CROSS");
   }

   // --- STRICT ENTRY LOGIC WITH TRIPLE CONDITIONS ---
   if(!tradeIsOpen && Last_Confirmed_Swing == 0) {
      // BUY SETUP: EMA 5 > 10 + CHOCH + Body Break
      if(emaBullish && chochBuy && bodyBreakBuy && !isLateBuy) {
         if(trade.Buy(CalculateLotSize(M15_Trap_Low), _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), M15_Trap_Low, M15_Trap_High, "(IMCBOT_Master) Setup_Entry")) {
            Last_Confirmed_Swing = 1;
            Last_Entry_SL = M15_Trap_Low;
         }
      } 
      // SELL SETUP: EMA 10 > 5 + CHOCH + Body Break
      else if(emaBearish && chochSell && bodyBreakSell && !isLateSell) {
         if(trade.Sell(CalculateLotSize(M15_Trap_High), _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), M15_Trap_High, M15_Trap_Low, "(IMCBOT_Master) Setup_Entry")) {
            Last_Confirmed_Swing = 1;
            Last_Entry_SL = M15_Trap_High;
         }
      }
      
      if((emaBullish && isLateBuy) || (emaBearish && isLateSell)) {
         Last_Confirmed_Swing = 1; 
      }
   }

   // --- SWING CYCLE ---
   if(PositionsTotal() < MaxPositions && Last_Confirmed_Swing >= 1) {
      bool setupIsBullish = (Last_Entry_SL < close && Last_Entry_SL != 0) || (emaBullish && !emaBearish && !tradeIsOpen);
      ENUM_POSITION_TYPE type = (setupIsBullish) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      
      double structLow = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 15, 1));
      double structHigh = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 15, 1));
      double fib50 = structLow + (structHigh - structLow) * 0.5;

      bool isAtDiscount = (type == POSITION_TYPE_BUY) ? (close <= fib50) : (close >= fib50);

      if(isAtDiscount && ConfirmM1Sword(type)) {
         double current_struct_sl = (type == POSITION_TYPE_BUY) ? structLow : structHigh;
         double tp = (type == POSITION_TYPE_BUY) ? M15_Trap_High : M15_Trap_Low;
         double sl = (Last_Entry_SL != 0) ? Last_Entry_SL : current_struct_sl;
         
         string comment = (PositionsTotal() == 0) ? "(IMCBOT_Master) Late_Join" : "(IMCBOT_Master) Swing_Entry";

         bool success = false;
         if(type == POSITION_TYPE_BUY) success = trade.Buy(CalculateLotSize(sl), _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, tp, comment);
         else success = trade.Sell(CalculateLotSize(sl), _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, tp, comment);
         
         if(success) {
            Last_Confirmed_Swing++;
            Last_Entry_SL = current_struct_sl;
         }
      }
   }
}

int OnInit() { 
      if(BotPassword != "IMCBOTMaster_101033") {
      Alert("UNAUTHORIZED: Invalid Password for IMCBOT Master.");
      ExpertRemove(); // Shut down the bot
      return(INIT_FAILED);
      }
      trade.SetExpertMagicNumber(MagicNumber); return(INIT_SUCCEEDED); 
     }
void OnDeinit(const int reason) { ObjectDelete(0, IconName); ObjectDelete(0, TextName); }
