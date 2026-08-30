//+------------------------------------------------------------------+
//| CK_ExportOHLC.mq5                                                 |
//| Exports OHLC history for a symbol/timeframe to a CSV in           |
//| Common\Files, in the format:  datetime,open,high,low,close,volume |
//| (datetime as  yyyy-MM-dd HH:mm:ss). Run as a Script on a chart.   |
//| Inputs let you pick symbol, timeframe, and how many years back.   |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict

input string InpSymbol   = "XAUUSD";   // symbol to export (XAUUSD / XAGUSD / DXY / USDX ...)
input ENUM_TIMEFRAMES InpTF = PERIOD_M15; // timeframe (PERIOD_M15 / PERIOD_M5 / PERIOD_H1 ...)
input int    InpYearsBack = 6;         // how many years of history to export
input string InpOutFile  = "";         // output filename ("" = auto: <SYMBOL>_<TF>_export.csv)

string TFName(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
   }
   return "TF" + IntegerToString((int)tf);
}

void OnStart()
{
   string sym = InpSymbol;
   if(!SymbolSelect(sym, true))
   {
      Print("ERROR: cannot select symbol '", sym, "'. Check the exact name in Market Watch.");
      return;
   }

   datetime to   = TimeCurrent();
   datetime from = to - (datetime)InpYearsBack * 365 * 24 * 60 * 60;

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(sym, InpTF, from, to, rates);
   if(copied <= 0)
   {
      Print("ERROR: CopyRates returned ", copied, " for ", sym, " ", TFName(InpTF),
            ". Try opening a chart of this symbol/timeframe first so history downloads.");
      return;
   }

   string outfile = InpOutFile;
   if(outfile == "")
      outfile = sym + "_" + TFName(InpTF) + "_export.csv";

   // FILE_COMMON => writes to  ...\MetaQuotes\Terminal\Common\Files
   int h = FileOpen(outfile, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
   {
      Print("ERROR: cannot open output file ", outfile, " err=", GetLastError());
      return;
   }

   FileWriteString(h, "datetime,open,high,low,close,volume\r\n");
   for(int i = 0; i < copied; i++)
   {
      MqlDateTime dt;
      TimeToStruct(rates[i].time, dt);
      string line = StringFormat("%04d-%02d-%02d %02d:%02d:%02d,%s,%s,%s,%s,%d\r\n",
         dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec,
         DoubleToString(rates[i].open,  5),
         DoubleToString(rates[i].high,  5),
         DoubleToString(rates[i].low,   5),
         DoubleToString(rates[i].close, 5),
         (long)rates[i].tick_volume);
      FileWriteString(h, line);
   }
   FileClose(h);

   Print("EXPORT OK: ", sym, " ", TFName(InpTF), "  bars=", copied,
         "  file=Common\\Files\\", outfile);
}
//+------------------------------------------------------------------+
