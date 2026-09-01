//+------------------------------------------------------------------+
//| CK_ExportBook.mq5  — READ-ONLY data exporter (NO trading at all)  |
//| Exports D1 OHLC for a list of symbols to Common\Files\<SYM>_D1.csv|
//| Also logs the connected account mode (DEMO/REAL) for a safety     |
//| check. Contains ZERO order/trade calls by design.                 |
//+------------------------------------------------------------------+
#property strict

input string InpSymbols = "BTCUSD,ETHUSD,NAS100"; // symbols (comma separated)
input int    InpBars    = 900;                    // D1 bars to export (~ up to ~3y, uses what's available)

void WriteLog(int h, string s)
{
   if(h != INVALID_HANDLE) FileWriteString(h, s + "\r\n");
   Print(s);
}

int OnInit()
{
   // 1) wait for the broker connection (history needs it) — up to ~40s
   for(int i = 0; i < 80 && !TerminalInfoInteger(TERMINAL_CONNECTED); i++)
      Sleep(500);

   int hlog = FileOpen("book_export_log.txt", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);

   long tm = AccountInfoInteger(ACCOUNT_TRADE_MODE); // 0=DEMO,1=CONTEST,2=REAL
   string modeStr = (tm == 0 ? "DEMO" : (tm == 1 ? "CONTEST" : (tm == 2 ? "REAL" : "UNKNOWN")));
   WriteLog(hlog, StringFormat("ACCOUNT login=%d mode=%s company=%s server=%s ccy=%s balance=%.2f connected=%d",
            (int)AccountInfoInteger(ACCOUNT_LOGIN), modeStr,
            AccountInfoString(ACCOUNT_COMPANY), AccountInfoString(ACCOUNT_SERVER),
            AccountInfoString(ACCOUNT_CURRENCY), AccountInfoDouble(ACCOUNT_BALANCE),
            (int)TerminalInfoInteger(TERMINAL_CONNECTED)));

   string parts[];
   int n = StringSplit(InpSymbols, ',', parts);
   for(int i = 0; i < n; i++)
   {
      string sym = parts[i];
      StringTrimLeft(sym); StringTrimRight(sym);
      if(sym == "") continue;

      bool sel = SymbolSelect(sym, true);
      MqlRates r[];
      ArraySetAsSeries(r, false);
      int c = 0;
      for(int t = 0; t < 40; t++)
      {
         c = CopyRates(sym, PERIOD_D1, 0, InpBars, r);
         if(c > 0) break;
         Sleep(500);
      }

      if(c > 0)
      {
         int h = FileOpen(sym + "_D1.csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
         if(h != INVALID_HANDLE)
         {
            FileWriteString(h, "date,open,high,low,close,volume\r\n");
            for(int k = 0; k < c; k++)
            {
               MqlDateTime dt;
               TimeToStruct(r[k].time, dt);
               FileWriteString(h, StringFormat("%04d-%02d-%02d,%s,%s,%s,%s,%d\r\n",
                  dt.year, dt.mon, dt.day,
                  DoubleToString(r[k].open, 5), DoubleToString(r[k].high, 5),
                  DoubleToString(r[k].low, 5),  DoubleToString(r[k].close, 5),
                  (long)r[k].tick_volume));
            }
            FileClose(h);
         }
         WriteLog(hlog, StringFormat("%s D1 bars=%d first=%s last=%s -> %s_D1.csv",
                  sym, c, TimeToString(r[0].time, TIME_DATE),
                  TimeToString(r[c-1].time, TIME_DATE), sym));
      }
      else
      {
         WriteLog(hlog, StringFormat("%s FAILED select=%d copied=%d (check exact name in Market Watch)", sym, (int)sel, c));
      }
   }

   WriteLog(hlog, "EXPORT_DONE");
   if(hlog != INVALID_HANDLE) FileClose(hlog);
   return(INIT_SUCCEEDED);
}

void OnTick() { }
void OnDeinit(const int reason) { }
//+------------------------------------------------------------------+
