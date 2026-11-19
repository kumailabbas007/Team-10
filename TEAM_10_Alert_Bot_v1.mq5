//+------------------------------------------------------------------+
//| TEAM - $10 Alert Bot v1.0                                        |
//| MT5 Expert Advisor - alert only; never places orders             |
//| Strategy: H4 50 EMA trend + H1 50 EMA pullback confirmation      |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "TEAM - $10 alert-only 50 EMA trend-pullback EA"

input ENUM_TIMEFRAMES TrendTimeframe = PERIOD_H4;
input ENUM_TIMEFRAMES EntryTimeframe = PERIOD_H1;
input int    EMAPeriod              = 50;
input int    TrendSlopeLookback     = 3;
input int    SwingLookback          = 5;
input int    ATRPeriod              = 14;
input double PullbackATR            = 0.25; // EMA proximity tolerance
input double StopBufferATR          = 0.10; // buffer beyond recent swing
input double RewardRisk             = 2.0;  // target = 2R
input bool   EnablePopupAlert       = true;
input bool   EnablePushNotification = true;

int hTrendEMA = INVALID_HANDLE;
int hEntryEMA = INVALID_HANDLE;
int hEntryATR = INVALID_HANDLE;
datetime lastEntryBarTime = 0;

// Read one indicator value at a specified bar shift.
bool ReadBufferValue(const int handle, const int shift, double &value)
{
   double temp[1];
   if(CopyBuffer(handle, 0, shift, 1, temp) != 1)
      return false;

   value = temp[0];
   return (value != EMPTY_VALUE);
}

string PriceText(const double price)
{
   return DoubleToString(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

void SendSignal(const string direction,
                const double entry,
                const double stopLoss,
                const double takeProfit)
{
   string message = "TEAM-$10 " + _Symbol + " " + direction
                  + " | Entry ref: " + PriceText(entry)
                  + " | SL: " + PriceText(stopLoss)
                  + " | TP (2R): " + PriceText(takeProfit)
                  + " | Alert only - check chart.";

   Print(message);

   if(EnablePopupAlert)
      Alert(message);

   if(EnablePushNotification)
   {
      ResetLastError();
      if(!SendNotification(message))
         Print("Push notification failed. Error: ", GetLastError(),
               ". Check MT5 Notifications settings.");
   }
}

int OnInit()
{
   hTrendEMA = iMA(_Symbol, TrendTimeframe, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hEntryEMA = iMA(_Symbol, EntryTimeframe, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hEntryATR = iATR(_Symbol, EntryTimeframe, ATRPeriod);

   if(hTrendEMA == INVALID_HANDLE ||
      hEntryEMA == INVALID_HANDLE ||
      hEntryATR == INVALID_HANDLE)
   {
      Print("TEAM-$10: Could not create indicator handles. Error: ", GetLastError());
      return INIT_FAILED;
   }

   // Wait for the next new entry-timeframe candle after attachment.
   lastEntryBarTime = iTime(_Symbol, EntryTimeframe, 0);

   Print("TEAM-$10 Alert Bot v1.0 initialized on ", _Symbol,
         ". Alert-only mode; no orders will be placed.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(hTrendEMA != INVALID_HANDLE) IndicatorRelease(hTrendEMA);
   if(hEntryEMA != INVALID_HANDLE) IndicatorRelease(hEntryEMA);
   if(hEntryATR != INVALID_HANDLE) IndicatorRelease(hEntryATR);
}

void OnTick()
{
   datetime currentBarTime = iTime(_Symbol, EntryTimeframe, 0);
   if(currentBarTime == 0 || currentBarTime == lastEntryBarTime)
      return;

   // Process once, on the first tick of each new H1 candle.
   lastEntryBarTime = currentBarTime;

   int barsNeeded = MathMax(SwingLookback + 2, 4);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   if(CopyRates(_Symbol, EntryTimeframe, 1, barsNeeded, rates) < barsNeeded)
   {
      Print("TEAM-$10: Not enough entry timeframe price history yet.");
      return;
   }

   double trendEMA1, trendEMAold, entryEMA1, atr1;
   if(!ReadBufferValue(hTrendEMA, 1, trendEMA1) ||
      !ReadBufferValue(hTrendEMA, 1 + TrendSlopeLookback, trendEMAold) ||
      !ReadBufferValue(hEntryEMA, 1, entryEMA1) ||
      !ReadBufferValue(hEntryATR, 1, atr1))
   {
      Print("TEAM-$10: Indicator data not ready.");
      return;
   }

   if(atr1 <= 0.0)
      return;

   double trendClose = iClose(_Symbol, TrendTimeframe, 1);
   if(trendClose <= 0.0)
      return;

   bool bullishTrend = (trendClose > trendEMA1 && trendEMA1 > trendEMAold);
   bool bearishTrend = (trendClose < trendEMA1 && trendEMA1 < trendEMAold);

   // rates[0] is the most recently completed H1 candle.
   // rates[1] is the completed candle immediately before it.
   MqlRates signalBar = rates[0];
   MqlRates previousBar = rates[1];

   bool bullishCandle = (signalBar.close > signalBar.open);
   bool bearishCandle = (signalBar.close < signalBar.open);

   double proximity = atr1 * PullbackATR;
   bool touchedOrNearEMAForBuy = (signalBar.low <= entryEMA1 + proximity);
   bool touchedOrNearEMAForSell = (signalBar.high >= entryEMA1 - proximity);

   // Require the confirmation candle to close beyond the prior candle extreme.
   bool bullishConfirmation = (bullishCandle &&
                               signalBar.close > entryEMA1 &&
                               signalBar.close > previousBar.high);

   bool bearishConfirmation = (bearishCandle &&
                               signalBar.close < entryEMA1 &&
                               signalBar.close < previousBar.low);

   double recentLow = rates[0].low;
   double recentHigh = rates[0].high;

   for(int i = 1; i < SwingLookback; i++)
   {
      if(rates[i].low < recentLow) recentLow = rates[i].low;
      if(rates[i].high > recentHigh) recentHigh = rates[i].high;
   }

   // Reference entry is the signal candle close, not a guaranteed fill price.
   double entryReference = signalBar.close;
   double stopLoss, takeProfit, risk;

   if(bullishTrend && touchedOrNearEMAForBuy && bullishConfirmation)
   {
      stopLoss = recentLow - (atr1 * StopBufferATR);
      risk = entryReference - stopLoss;
      if(risk <= 0.0)
         return;

      takeProfit = entryReference + (risk * RewardRisk);
      SendSignal("BUY", entryReference, stopLoss, takeProfit);
   }
   else if(bearishTrend && touchedOrNearEMAForSell && bearishConfirmation)
   {
      stopLoss = recentHigh + (atr1 * StopBufferATR);
      risk = stopLoss - entryReference;
      if(risk <= 0.0)
         return;

      takeProfit = entryReference - (risk * RewardRisk);
      SendSignal("SELL", entryReference, stopLoss, takeProfit);
   }
}
//+------------------------------------------------------------------+
