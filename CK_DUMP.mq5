//+------------------------------------------------------------------+
//| CK_DUMP.mq5 - export OHLC of the tested window to CSV (no trades).|
//| Used to build charts of where strategies lose in chop.           |
//+------------------------------------------------------------------+
#property strict
input int InpBars = 60000;
int OnInit(){ return(INIT_SUCCEEDED); }
void OnTick(){}
double OnTester(){
   MqlRates r[]; ArraySetAsSeries(r,false);
   int n=CopyRates(_Symbol,_Period,0,InpBars,r);
   int h=FileOpen("xau_dump.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,",");
   if(h!=INVALID_HANDLE){
      FileWrite(h,"time","open","high","low","close");
      for(int i=0;i<n;i++)
         FileWrite(h,TimeToString(r[i].time,TIME_DATE|TIME_MINUTES),
                   DoubleToString(r[i].open,2),DoubleToString(r[i].high,2),
                   DoubleToString(r[i].low,2),DoubleToString(r[i].close,2));
      FileClose(h);
      PrintFormat("[DUMP] wrote %d bars to xau_dump.csv",n);
   }
   return(0.0);
}
