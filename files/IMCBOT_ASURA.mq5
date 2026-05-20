//+------------------------------------------------------------------+
//|                                  IMCBOT ASURA - UNIVERSAL V1.1   |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

// --- User & Security Inputs ---
input string BotPassword = "";
input double RiskPercent = 8.0;    
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

// cloud
void CheckWebsiteCommands() {
   string cookie=NULL, headers;
   char post[], result[];
   string url = "https://your-website.com/api/trade-status.json"; // Your command file
   
   // Reset headers for a clean GET request
   int res = WebRequest("GET", url, cookie, NULL, 500, post, 0, result, headers);

   if(res == 200) {
      string response = CharArrayToString(result);
      if(StringFind(response, "\"action\":\"buy\"") >= 0) {
         // Logic to execute BUY trade here
         Print("Command Received: Opening Buy Order");
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

//--- UPDATED: TRAILING LOGIC (Break-even at 5%, Switch to Candle-Trail at 80%)
void ManageTrailingAndHolding() {
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            
            double entry = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            double swingTarget = (type == POSITION_TYPE_BUY) ? H1_Trap_High : H1_Trap_Low;
            double totalDistance = MathAbs(swingTarget - entry);
            double currentProgress = (type == POSITION_TYPE_BUY) ? (currentBid - entry) : (entry - currentAsk);

            // UPDATED: Break even into 2% profits once 5% of the way to target
            if(currentProgress >= (totalDistance * 0.05) && currentProgress < (totalDistance * 0.80)) {
               double profitLockPrice = 0;
               if(type == POSITION_TYPE_BUY) {
                  profitLockPrice = entry + (totalDistance * 0.02);
                  if(sl < profitLockPrice) trade.PositionModify(ticket, NormalizeDouble(profitLockPrice, _Digits), 0);
               } else {
                  profitLockPrice = entry - (totalDistance * 0.02);
                  if(sl > profitLockPrice || sl == 0) trade.PositionModify(ticket, NormalizeDouble(profitLockPrice, _Digits), 0);
               }
            }

            // TRAILING LOGIC
            if(currentProgress >= (totalDistance * 0.20) && currentProgress < (totalDistance * 0.80)) {
               if(type == POSITION_TYPE_BUY) {
                  int highestBar = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 15, 2);
                  if(highestBar >= 0) {
                     double prevStructureHigh = iHigh(_Symbol, PERIOD_M5, highestBar);
                     if(iClose(_Symbol, PERIOD_M5, 1) > prevStructureHigh && iClose(_Symbol, PERIOD_M5, 1) > iOpen(_Symbol, PERIOD_M5, 1)) {
                        int lowestBar = iLowest(_Symbol, PERIOD_M5, MODE_LOW, highestBar, 1);
                        if(lowestBar >= 0) {
                           double structuralLow = iLow(_Symbol, PERIOD_M5, lowestBar);
                           double newSL = structuralLow - spread;
                           if(newSL > sl) trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), 0);
                        }
                     }
                  }
               } else {
                  int lowestBar = iLowest(_Symbol, PERIOD_M5, MODE_LOW, 15, 2);
                  if(lowestBar >= 0) {
                     double prevStructureLow = iLow(_Symbol, PERIOD_M5, lowestBar);
                     if(iClose(_Symbol, PERIOD_M5, 1) < prevStructureLow && iClose(_Symbol, PERIOD_M5, 1) < iOpen(_Symbol, PERIOD_M5, 1)) {
                        int highestBar = iHighest(_Symbol, PERIOD_M5, MODE_HIGH, lowestBar, 1);
                        if(highestBar >= 0) {
                           double structuralHigh = iHigh(_Symbol, PERIOD_M5, highestBar);
                           double newSL = structuralHigh + spread;
                           if(newSL < sl || sl == 0) trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), 0);
                        }
                     }
                  }
               }
            }
            
            //  After 80% progress, trail by following candles that break previous candle bodies
            if(currentProgress >= (totalDistance * 0.80)) {
               if(type == POSITION_TYPE_BUY) {
                  if(iClose(_Symbol, PERIOD_M5, 1) > iHigh(_Symbol, PERIOD_M5, 2)) {
                     double newSL = iLow(_Symbol, PERIOD_M5, 1) - spread;
                     if(newSL > sl) trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), 0);
                  }
               } else {
                  if(iClose(_Symbol, PERIOD_M5, 1) < iLow(_Symbol, PERIOD_M5, 2)) {
                     double newSL = iHigh(_Symbol, PERIOD_M5, 1) + spread;
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
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double riskAmount = balance * (RiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double entryPrice = (sl_price < SymbolInfoDouble(_Symbol, SYMBOL_ASK)) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID); 
   double slDistPoints = MathAbs(entryPrice - sl_price) / _Point;
   if(slDistPoints <= 0) return 0.01;
   double lot = riskAmount / (slDistPoints * _Point * (tickValue / tickSize));
   lot = NormalizeDouble(lot, 2);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lot < minLot) lot = minLot;
   if(lot > MaxLotLimit) lot = MaxLotLimit;
   if((lot * SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL)) > freeMargin) {
      lot = NormalizeDouble(freeMargin / SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL), 2);
      if(lot < minLot) return 0.0;
   }
   return lot;
}

void UpdateStatus(string message, bool isError = false) {
   bool hasTrades = IsBotTradeOpen();
   color textColor = isError ? clrOrangeRed : (hasTrades ? C'231,114,213' : C'129,20,192');
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
   ObjectSetString(0, TextName, OBJPROP_TEXT, "IMCBOT ASURA [" + _Symbol + "]: " + message); 
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
   
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   trade.SetExpertMagicNumber(MagicNumber);
   bool tradeIsOpen = IsBotTradeOpen();
   if(!tradeIsOpen) { Last_Confirmed_Swing = 0; Last_Entry_SL = 0; }

   if(tradeIsOpen) { ManageTrailingAndHolding(); }

   H1_Trap_High = iHigh(_Symbol, PERIOD_H1, iHighest(_Symbol, PERIOD_H1, MODE_HIGH, Lookback, 1));
   H1_Trap_Low = iLow(_Symbol, PERIOD_H1, iLowest(_Symbol, PERIOD_H1, MODE_LOW, Lookback, 1));
   double close = iClose(_Symbol, PERIOD_M5, 0);
   
   // UPDATED: Now uses 5 EMA and 10 EMA for Approval
   double ema5 = iMA(_Symbol, PERIOD_M5, 5, 0, MODE_EMA, PRICE_CLOSE);
   double ema10 = iMA(_Symbol, PERIOD_M5, 10, 0, MODE_EMA, PRICE_CLOSE);
   bool bullishEMA = (ema5 > ema10);
   bool bearishEMA = (ema10 > ema5);

   // NEW: CHoCH and 1st Structure Swing Logic (Body Break)
   bool buyCHoCH = (iClose(_Symbol, PERIOD_M5, 0) > iHigh(_Symbol, PERIOD_M5, 1));
   bool sellCHoCH = (iClose(_Symbol, PERIOD_M5, 0) < iLow(_Symbol, PERIOD_M5, 1));

   double trapRange = H1_Trap_High - H1_Trap_Low;
   bool isLateBuy = (close - H1_Trap_Low) > (trapRange * 0.25);
   bool isLateSell = (H1_Trap_High - close) > (trapRange * 0.25);

   if(tradeIsOpen) UpdateStatus("MANAGING TRADE");
   else {
      if(bullishEMA) UpdateStatus(isLateBuy ? "LATE BUY: WAITING SWING" : "SCAN SETUP BUY");
      else if(bearishEMA) UpdateStatus(isLateSell ? "LATE SELL: WAITING SWING" : "SCAN SETUP SELL");
      else UpdateStatus("WAITING H1 TRAP");
   }

   // UPDATED: Combined conditions (EMA Cross + CHoCH + Body Break Swing)
   if(!tradeIsOpen && Last_Confirmed_Swing == 0) {
      if(bullishEMA && buyCHoCH && close > iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 5, 1))) {
         double sl = H1_Trap_Low - spread;
         double calculatedLot = CalculateLotSize(sl);
         if(calculatedLot > 0 && trade.Buy(calculatedLot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, 0, "(IMCBOT_ASURA)Setup_Entry")) { 
            Last_Confirmed_Swing = 1; Last_Entry_SL = sl;
         }
      } 
      else if(bearishEMA && sellCHoCH && close < iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 5, 1))) {
         double sl = H1_Trap_High + spread;
         double calculatedLot = CalculateLotSize(sl);
         if(calculatedLot > 0 && trade.Sell(calculatedLot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, 0, "(IMCBOT_ASURA)Setup_Entry")) { 
            Last_Confirmed_Swing = 1; Last_Entry_SL = sl;
         }
      }
      if((bullishEMA && isLateBuy) || (bearishEMA && isLateSell)) Last_Confirmed_Swing = 1; 
   }

   if(Last_Confirmed_Swing >= 2) {
      double s2_high = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 15, 5));
      double s2_low = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 15, 5));

      if(bearishEMA) {
         bool m5_wick_touch = (iHigh(_Symbol, PERIOD_M5, 1) >= s2_high && iClose(_Symbol, PERIOD_M5, 1) <= s2_high);
         if(m5_wick_touch) {
            bool m1_break_1 = (iClose(_Symbol, PERIOD_M1, 1) < iLow(_Symbol, PERIOD_M1, 2));
            bool m1_break_2 = (iClose(_Symbol, PERIOD_M1, 0) < iLow(_Symbol, PERIOD_M1, 1));
            double pullback_bull_low = iLow(_Symbol, PERIOD_M1, 3); 
            bool pullback_broken = (iClose(_Symbol, PERIOD_M1, 0) < pullback_bull_low);
            if(m1_break_1 && m1_break_2 && pullback_broken) {
               double sl = s2_high + spread;
               double calculatedLot = CalculateLotSize(sl);
               if(calculatedLot > 0) trade.Sell(calculatedLot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, 0, "(IMCBOT_ASURA)M_Entry"); 
            }
         }
      }
      else if(bullishEMA) {
         bool m5_wick_touch = (iLow(_Symbol, PERIOD_M5, 1) <= s2_low && iClose(_Symbol, PERIOD_M5, 1) >= s2_low);
         if(m5_wick_touch) {
            bool m1_break_1 = (iClose(_Symbol, PERIOD_M1, 1) > iHigh(_Symbol, PERIOD_M1, 2));
            bool m1_break_2 = (iClose(_Symbol, PERIOD_M1, 0) > iHigh(_Symbol, PERIOD_M1, 1));
            double pullback_bear_high = iHigh(_Symbol, PERIOD_M1, 3);
            bool pullback_broken = (iClose(_Symbol, PERIOD_M1, 0) > pullback_bear_high);
            if(m1_break_1 && m1_break_2 && pullback_broken) {
               double sl = s2_low - spread;
               double calculatedLot = CalculateLotSize(sl);
               if(calculatedLot > 0) trade.Buy(calculatedLot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, 0, "(IMCBOT_ASURA)M_Entry"); 
            }
         }
      }
   }

   if(PositionsTotal() < MaxPositions && Last_Confirmed_Swing >= 1) {
      bool setupIsBullish = (Last_Entry_SL < close && Last_Entry_SL != 0) || (bullishEMA && !bearishEMA && !tradeIsOpen);
      ENUM_POSITION_TYPE type = (setupIsBullish) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      double structLow = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, 15, 1));
      double structHigh = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, 15, 1));
      double fib50 = structLow + (structHigh - structLow) * 0.5;

      if(((type == POSITION_TYPE_BUY && close <= fib50) || (type == POSITION_TYPE_SELL && close >= fib50)) && ConfirmM1Sword(type)) {
         double current_struct_sl = (type == POSITION_TYPE_BUY) ? (structLow - spread) : (structHigh + spread);
         double sl = (Last_Entry_SL != 0) ? Last_Entry_SL : current_struct_sl;
         string comment = (PositionsTotal() == 0) ? "(IMCBOT_ASURA)Late Join" : "(IMCBOT_ASURA)Swing_Entry"; 
         double calculatedLot = CalculateLotSize(sl);
         if(calculatedLot > 0) {
            if(type == POSITION_TYPE_BUY) {
               if(trade.Buy(calculatedLot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, 0, comment)) { Last_Confirmed_Swing++; Last_Entry_SL = sl; }
            } else {
               if(trade.Sell(calculatedLot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, 0, comment)) { Last_Confirmed_Swing++; Last_Entry_SL = sl; }
            }
         }
      }
   }
}

int OnInit() { 
      if(BotPassword != "IMCBOTAsura_10112") {
      Alert("UNAUTHORIZED: Invalid Password for IMCBOT Asura.");
      ExpertRemove(); // Shut down the bot
      return(INIT_FAILED);
      }
   trade.SetExpertMagicNumber(MagicNumber); return(INIT_SUCCEEDED);
  }
void OnDeinit(const int reason) { ObjectDelete(0, IconName); ObjectDelete(0, TextName); }
