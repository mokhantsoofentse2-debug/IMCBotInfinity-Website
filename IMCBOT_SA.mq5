//+------------------------------------------------------------------+
//|                                IMCBOT SMALL ACCOUNT - V9.2       |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

// --- User & Security Inputs ---
input string BotPassword = "";
input int Lookback = 60;           
input int StructureLookback = 15;  
input long MagicNumber = 123456;   

// UI Object Names
string IconName = "IMCBOT_SA_ICON";
string TextName = "IMCBOT_SA_TEXT";

double CalculateLotSize() {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   return (minLot <= 0) ? 0.01 : minLot;
}

void UpdateStatus(string message, bool isError = false) {
   
   color parakeet = C'34,139,34';
   color shamrock = C'0,158,96';
   
   color textColor = isError ? clrOrangeRed : parakeet;
   
   if(IsBotTradeOpen()) textColor = shamrock;

   double currentMinLot = CalculateLotSize();

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
   
   string uiOutput = "IMCBOT SA [" + _Symbol + "]: " + message + " | Lot: " + DoubleToString(currentMinLot, 2) + " (x2)";
   ObjectSetString(0, TextName, OBJPROP_TEXT, uiOutput);
   ObjectSetInteger(0, TextName, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, TextName, OBJPROP_FONTSIZE, 9);
   ChartRedraw(0); 
}

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

void TrailByCompletedSwings() {
   if(PositionsTotal() == 0) return;
   double spreadBuffer = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;

   double m15H = iHigh(_Symbol, PERIOD_M15, iHighest(_Symbol, PERIOD_M15, MODE_HIGH, Lookback, 1));
   double m15L = iLow(_Symbol, PERIOD_M15, iLowest(_Symbol, PERIOD_M15, MODE_LOW, Lookback, 1));
   double range = m15H - m15L;

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionSelectByTicket(PositionGetTicket(i))) {
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

         ulong ticket = PositionGetTicket(i);
         long type = PositionGetInteger(POSITION_TYPE);
         double currentSL = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         double price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         double totalDistance = MathAbs(tp - entry);
         if(totalDistance <= 0) continue; 

         double currentDistance = MathAbs(price - entry);
         double progressPercent = (currentDistance / totalDistance) * 100.0;

         // STICKY REQUIREMENT: 5% distance break-even to 2% profit
         if(progressPercent >= 5.0 && progressPercent < 40.0) {
             double beProfit = (type == POSITION_TYPE_BUY) ? (entry + (totalDistance * 0.02)) : (entry - (totalDistance * 0.02));
             if((type == POSITION_TYPE_BUY && beProfit > currentSL) || (type == POSITION_TYPE_SELL && (beProfit < currentSL || currentSL == 0))) {
                 trade.PositionModify(ticket, NormalizeDouble(beProfit, _Digits), tp);
             }
         }

         if(progressPercent < 40.0 && range > 0) {
            if(type == POSITION_TYPE_BUY && entry > (m15L + range * 0.5) && currentSL <= m15L) {
               int recentLow = iLowest(_Symbol, PERIOD_M5, MODE_LOW, StructureLookback, 1);
               double boxSL = iLow(_Symbol, PERIOD_M5, recentLow) - spreadBuffer;
               if(boxSL > currentSL) trade.PositionModify(ticket, NormalizeDouble(boxSL, _Digits), tp);
            }
            else if(type == POSITION_TYPE_SELL && entry < (m15H - range * 0.5) && currentSL >= m15H) {
               int recentHigh = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, StructureLookback, 1);
               double boxSL = iHigh(_Symbol, PERIOD_M5, recentHigh) + spreadBuffer;
               if(boxSL < currentSL || currentSL == 0) trade.PositionModify(ticket, NormalizeDouble(boxSL, _Digits), tp);
            }
         }

         if(progressPercent >= 40.0 && progressPercent < 50.0) {
            double profitLockPrice = (type == POSITION_TYPE_BUY) ? (entry + (totalDistance * 0.20)) : (entry - (totalDistance * 0.20));
            if((type == POSITION_TYPE_BUY && profitLockPrice > currentSL) || 
               (type == POSITION_TYPE_SELL && (profitLockPrice < currentSL || currentSL == 0))) {
               trade.PositionModify(ticket, NormalizeDouble(profitLockPrice, _Digits), tp);
               UpdateStatus("LOCKED 20% PROFIT");
            }
         }

         if(progressPercent >= 50.0) {
            double newSL = 0;
            if(type == POSITION_TYPE_BUY) {
               int highBar = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, StructureLookback, 2);
               if(iClose(_Symbol, PERIOD_M5, 1) > iHigh(_Symbol, PERIOD_M5, highBar)) {
                  int lowBar = iLowest(_Symbol, PERIOD_M5, MODE_LOW, StructureLookback, 1);
                  newSL = iLow(_Symbol, PERIOD_M5, lowBar) - spreadBuffer;
                  if(newSL > currentSL) trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), tp);
               }
            } 
            else if(type == POSITION_TYPE_SELL) {
               int lowBar = iLowest(_Symbol, PERIOD_M5, MODE_LOW, StructureLookback, 2);
               if(iClose(_Symbol, PERIOD_M5, 1) < iLow(_Symbol, PERIOD_M5, lowBar)) {
                  int highBar = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, StructureLookback, 1);
                  newSL = iHigh(_Symbol, PERIOD_M5, highBar) + spreadBuffer;
                  if(newSL < currentSL || currentSL == 0) trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), tp);
               }
            }
         }
      }
   }
}

void OnTick() {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) { UpdateStatus("ALGO BUTTON OFF", true); return; }
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) { UpdateStatus("EA NOT ALLOWED", true); return; }
   if(Period() != PERIOD_M5) { UpdateStatus("SWITCH TO M5", true); return; }
   
   trade.SetExpertMagicNumber(MagicNumber);
   TrailByCompletedSwings(); 
   
   if(IsBotTradeOpen()) { 
      UpdateStatus("MANAGING TRADES"); 
      return; 
   }

   // EMA 5 and EMA 10 setup
   double ema5 = iMA(_Symbol, PERIOD_M5, 5, 0, MODE_EMA, PRICE_CLOSE);
   double ema10 = iMA(_Symbol, PERIOD_M5, 10, 0, MODE_EMA, PRICE_CLOSE);

   // Structure and ChoCh detection on M5
   int lastHigh = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 10, 1);
   int lastLow = iLowest(_Symbol, PERIOD_M5, MODE_LOW, 10, 1);
   bool bodyBreakUp = iClose(_Symbol, PERIOD_M5, 1) > iHigh(_Symbol, PERIOD_M5, lastHigh);
   bool bodyBreakDown = iClose(_Symbol, PERIOD_M5, 1) < iLow(_Symbol, PERIOD_M5, lastLow);

   double m15H = iHigh(_Symbol, PERIOD_M15, iHighest(_Symbol, PERIOD_M15, MODE_HIGH, Lookback, 1));
   double m15L = iLow(_Symbol, PERIOD_M15, iLowest(_Symbol, PERIOD_M15, MODE_LOW, Lookback, 1));
   double close = iClose(_Symbol, PERIOD_M5, 0);
   
   string tradeComment = "(IMCBOT_SA) Setup_Entry";
   double spreadBuffer = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;

   // BUY SETUP: EMA 5 > 10 + ChoCh/Structure Break
   if(ema5 > ema10 && bodyBreakUp) {
      if(close < m15H && close > m15L) {
         double lot = CalculateLotSize();
         double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl = m15L;
         
         if(entryPrice > (m15L + (m15H - m15L) * 0.5)) {
            int recentSupportBar = iLowest(_Symbol, PERIOD_M5, MODE_LOW, StructureLookback, 1);
            sl = iLow(_Symbol, PERIOD_M5, recentSupportBar) - spreadBuffer;
         }

         if(trade.Buy(lot, _Symbol, entryPrice, sl, m15H, tradeComment)) {
            trade.Buy(lot, _Symbol, entryPrice, sl, m15H, tradeComment);
         }
      } else UpdateStatus("SCANNING BUY");
   } 
   // SELL SETUP: EMA 10 > 5 + ChoCh/Structure Break
   else if(ema10 > ema5 && bodyBreakDown) {
      if(close < m15H && close > m15L) {
         double lot = CalculateLotSize();
         double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl = m15H;

         if(entryPrice < (m15H - (m15H - m15L) * 0.5)) {
            int recentResistBar = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, StructureLookback, 1);
            sl = iHigh(_Symbol, PERIOD_M5, recentResistBar) + spreadBuffer;
         }

         if(trade.Sell(lot, _Symbol, entryPrice, sl, m15L, tradeComment)) {
            trade.Sell(lot, _Symbol, entryPrice, sl, m15L, tradeComment);
         }
      } else UpdateStatus("SCANNING SELL");
   }
   else UpdateStatus("WAITING TREND");
}

int OnInit() { 
   if(BotPassword != "IMCBOTSA_9922") {
      Alert("UNAUTHORIZED: Invalid Password for IMCBOT SA.");
      ExpertRemove(); // Shut down the bot
      return(INIT_FAILED);
   }

   ObjectsDeleteAll(0, "IMCBOT"); 
   trade.SetExpertMagicNumber(MagicNumber);
   UpdateStatus("INITIALIZING...");
   return(INIT_SUCCEEDED); 
}

void OnDeinit(const int reason) { 
   ObjectDelete(0, IconName); 
   ObjectDelete(0, TextName); 
}