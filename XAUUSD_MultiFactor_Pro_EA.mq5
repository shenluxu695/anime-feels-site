//+------------------------------------------------------------------+
//|                         XAUUSD_MultiFactor_Pro_EA.mq5             |
//| Multi-factor professional Expert Advisor for XAUUSD/GOLD          |
//| 多因子专业黄金交易 EA                                             |
//+------------------------------------------------------------------+
#property copyright "OpenAI"
#property version   "1.00"
#property strict
#property description "XAUUSD/GOLD multi-timeframe multi-factor EA with risk management, news filter, logging and panel."

//+------------------------------------------------------------------+
//| Enumerations / 枚举                                               |
//+------------------------------------------------------------------+
enum ENUM_TREND_DIRECTION
  {
   TREND_NONE = 0,
   TREND_UP   = 1,
   TREND_DOWN = -1
  };

enum ENUM_SIGNAL_DIRECTION
  {
   SIGNAL_NONE = 0,
   SIGNAL_BUY  = 1,
   SIGNAL_SELL = -1
  };

enum ENUM_MONEY_MANAGEMENT
  {
   MM_FIXED_LOT = 0,       // Fixed lot / 固定手数
   MM_RISK_PERCENT = 1,    // Account percent risk / 账户百分比风险
   MM_SIMPLE_KELLY = 2     // Simplified Kelly / 简化凯利
  };

//+------------------------------------------------------------------+
//| Input parameters / 输入参数                                       |
//+------------------------------------------------------------------+
input string              InpTradeSymbol              = "XAUUSD";       // Trading symbol / 交易品种
input ulong               InpMagicNumber              = 26053001;       // Magic number / 魔术号
input ENUM_TIMEFRAMES     InpTrendTimeframe           = PERIOD_H1;      // Main trend timeframe / 主趋势周期
input ENUM_TIMEFRAMES     InpEntryTimeframe           = PERIOD_M15;     // Entry timeframe / 进场周期
input int                 InpMaxSlippagePoints        = 20;             // Max slippage in points / 最大滑点(points)
input int                 InpMaxSpreadPoints          = 80;             // Max spread in points / 最大点差(points)
input int                 InpTrendMinDiffPoints       = 0;              // Min EMA trend difference / 趋势最小EMA差距(points)

input bool                InpEnableEMACross           = true;           // Enable EMA9/21 cross / 启用EMA9/21交叉
input bool                InpEnableRSIReversal        = true;           // Enable RSI reversal / 启用RSI反转
input bool                InpEnableBollBreakout       = true;           // Enable Bollinger breakout / 启用布林突破
input int                 InpFastEMAPeriod            = 9;              // Fast EMA period / 快速EMA周期
input int                 InpSlowEMAPeriod            = 21;             // Slow EMA period / 慢速EMA周期
input int                 InpRSIPeriod                = 14;             // RSI period / RSI周期
input double              InpRSIOverbought            = 70.0;           // RSI overbought / RSI超买
input double              InpRSIOversold              = 30.0;           // RSI oversold / RSI超卖
input int                 InpBandsPeriod              = 20;             // Bollinger period / 布林周期
input double              InpBandsDeviation           = 2.0;            // Bollinger deviation / 布林标准差倍数

input string              InpNewsTimes                = "2026.06.07 20:30;2026.06.12 21:30"; // Manual news times / 手动新闻时间
input int                 InpNewsBlockMinutes         = 30;             // News block minutes before/after / 新闻前后禁开分钟
input int                 InpATRPeriod                = 14;             // ATR period / ATR周期
input double              InpMinATRPoints             = 100.0;          // Min ATR in points / 最小ATR(points)
input double              InpMinRewardRiskRatio       = 1.5;            // Min reward/risk ratio / 最小盈亏比
input bool                InpEnableFridayFilter       = true;           // Enable Friday filter / 启用周五过滤
input int                 InpFridayNoTradeHour        = 23;             // Friday no new trade hour / 周五禁止开仓小时
input bool                InpClosePositionsOnFriday   = false;          // Force close Friday positions / 周五强制平仓

input double              InpATRSLMultiplier          = 1.5;            // ATR SL multiplier / ATR止损倍数
input double              InpATRTPMultiplier          = 3.0;            // ATR TP multiplier / ATR止盈倍数
input double              InpTrailingStartSLMultiple  = 1.5;            // Trailing start in SL multiple / 移动止损启动SL倍数
input int                 InpTrailingStepPoints       = 10;             // Trailing step points / 移动止损步长(points)
input double              InpPartialClosePercent      = 50.0;           // TP1 close percent / TP1平仓比例
input int                 InpMaxHoldingHours          = 8;              // Max holding hours / 最大持仓小时

input ENUM_MONEY_MANAGEMENT InpMoneyManagement        = MM_RISK_PERCENT;// Money management mode / 资金管理模式
input double              InpFixedLot                 = 0.10;           // Fixed lot / 固定手数
input double              InpRiskPercent              = 2.0;            // Risk percent / 每笔风险百分比
input double              InpKellyWinRate             = 0.55;           // Kelly win rate / 凯利胜率
input int                 InpKellyMinTrades           = 30;             // Kelly minimum trades / 凯利最小样本数
input double              InpKellyMaxRiskPercent      = 5.0;            // Kelly max risk percent / 凯利最大风险百分比

input double              InpMaxDailyLossMoney        = 500.0;          // Max daily loss money / 最大当日亏损金额
input double              InpMaxDailyLossPercent      = 5.0;            // Max daily loss percent / 最大当日亏损百分比
input int                 InpMaxDailyTrades           = 5;              // Max daily trades / 最大单日交易次数
input string              InpCSVFileName              = "XAUUSD_MultiFactor_Pro_Trades.csv"; // CSV file / CSV文件名
input bool                InpEnablePanel              = true;           // Enable chart panel / 启用图表面板
input int                 InpTimerSeconds             = 10;             // Timer seconds / 定时器秒数

//+------------------------------------------------------------------+
//| Global state / 全局状态                                           |
//+------------------------------------------------------------------+
string   g_symbol;
double   g_point = 0.0;
double   g_tick_size = 0.0;
double   g_tick_value = 0.0;
int      g_digits = 0;
string   g_last_signal_source = "None";
string   g_block_reason = "";
bool     g_allow_trade = true;
datetime g_last_bar_time = 0;

ulong    g_tp1_tickets[];
bool     g_tp1_done[];

//+------------------------------------------------------------------+
//| Utility functions / 工具函数                                      |
//+------------------------------------------------------------------+

// CN: 安全获取当天零点服务器时间。 EN: Safely get server day start time.
datetime DayStart(datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

// CN: 判断数值是否有效。 EN: Check whether a number is valid.
bool IsValidNumber(const double value)
  {
   return (MathIsValidNumber(value) && value != EMPTY_VALUE);
  }

// CN: 标准化价格到品种小数位。 EN: Normalize price by symbol digits.
double NormalizePrice(const double price)
  {
   return NormalizeDouble(price, g_digits);
  }

// CN: 将方向转换为文本。 EN: Convert direction to text.
string DirectionToString(const int direction)
  {
   if(direction > 0) return "BUY";
   if(direction < 0) return "SELL";
   return "NONE";
  }

// CN: 将趋势转换为文本。 EN: Convert trend to text.
string TrendToString(const ENUM_TREND_DIRECTION trend)
  {
   if(trend == TREND_UP) return "UP / 上涨";
   if(trend == TREND_DOWN) return "DOWN / 下跌";
   return "NONE / 无趋势";
  }

// CN: 复制指标缓冲区的单个值并检查结果。 EN: Copy one indicator buffer value and validate it.
bool CopyIndicatorValue(const int handle, const int buffer, const int shift, double &value)
  {
   if(handle == INVALID_HANDLE)
      return false;

   double data[];
   ArraySetAsSeries(data, true);
   if(CopyBuffer(handle, buffer, shift, 1, data) != 1)
      return false;

   value = data[0];
   return IsValidNumber(value);
  }

// CN: 复制指标缓冲区的两个值并检查结果。 EN: Copy two indicator buffer values and validate them.
bool CopyTwoIndicatorValues(const int handle, const int buffer, const int shift, double &v1, double &v2)
  {
   if(handle == INVALID_HANDLE)
      return false;

   double data[];
   ArraySetAsSeries(data, true);
   if(CopyBuffer(handle, buffer, shift, 2, data) != 2)
      return false;

   v1 = data[0];
   v2 = data[1];
   return (IsValidNumber(v1) && IsValidNumber(v2));
  }

// CN: 获取当前点差(points)。 EN: Get current spread in points.
double CurrentSpreadPoints()
  {
   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   if(g_point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return 999999.0;
   return (ask - bid) / g_point;
  }

// CN: 获取品种允许的订单填充模式。 EN: Get an allowed order filling mode for the symbol.
ENUM_ORDER_TYPE_FILLING GetFillingMode()
  {
   long filling = SymbolInfoInteger(g_symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
  }

//+------------------------------------------------------------------+
//| CNewsFilter / 新闻过滤类                                          |
//+------------------------------------------------------------------+
class CNewsFilter
  {
private:
   datetime m_news_times[];
   int      m_block_minutes;
   bool     m_enabled;

public:
   // CN: 初始化新闻过滤器。 EN: Initialize the news filter.
   bool Init(const string news_string, const int block_minutes)
     {
      m_block_minutes = MathMax(0, block_minutes);
      m_enabled = !MQLInfoInteger(MQL_TESTER);
      ArrayResize(m_news_times, 0);

      if(!m_enabled)
        {
         Print("News filter disabled in tester. / 回测模式自动禁用新闻过滤。");
         return true;
        }

      string parts[];
      int count = StringSplit(news_string, ';', parts);
      for(int i = 0; i < count; i++)
        {
         string item = StringTrimLeft(StringTrimRight(parts[i]));
         if(StringLen(item) <= 0)
            continue;

         datetime nt = StringToTime(item);
         if(nt <= 0)
           {
            Print("Invalid news time ignored / 已忽略无效新闻时间: ", item);
            continue;
           }

         int size = ArraySize(m_news_times);
         ArrayResize(m_news_times, size + 1);
         m_news_times[size] = nt;
        }
      return true;
     }

   // CN: 判断当前时间是否处于新闻禁开窗口。 EN: Check whether current time is inside a news blocking window.
   bool IsBlocked(datetime now, string &reason)
     {
      reason = "";
      if(!m_enabled)
         return false;

      for(int i = 0; i < ArraySize(m_news_times); i++)
        {
         long diff_seconds = (long)MathAbs((double)(now - m_news_times[i]));
         if(diff_seconds <= (long)m_block_minutes * 60L)
           {
            reason = "News filter / 新闻过滤: " + TimeToString(m_news_times[i], TIME_DATE|TIME_MINUTES);
            return true;
           }
        }
      return false;
     }

   // CN: 返回是否启用新闻过滤。 EN: Return whether news filtering is enabled.
   bool Enabled()
     {
      return m_enabled;
     }
  };

//+------------------------------------------------------------------+
//| CRiskManager / 风险管理类                                         |
//+------------------------------------------------------------------+
class CRiskManager
  {
private:
   // CN: 获取历史交易样本数。 EN: Get historical closed trade sample size.
   int ClosedTradeCount()
     {
      if(!HistorySelect(0, TimeCurrent()))
         return 0;

      int count = 0;
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong deal = HistoryDealGetTicket(i);
         if(deal == 0)
            continue;
         if((ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagicNumber)
            continue;
         if(HistoryDealGetString(deal, DEAL_SYMBOL) != g_symbol)
            continue;
         if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_OUT)
            count++;
        }
      return count;
     }

public:
   // CN: 标准化手数到交易商允许范围。 EN: Normalize lots to broker limits.
   double NormalizeLot(double lot)
     {
      double min_lot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MAX);
      double step = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP);
      if(min_lot <= 0.0 || max_lot <= 0.0 || step <= 0.0)
        {
         Print("Invalid symbol volume settings. / 品种手数设置无效。 Error=", GetLastError());
         return 0.0;
        }

      lot = MathMax(min_lot, MathMin(max_lot, lot));
      lot = MathFloor(lot / step) * step;
      int digits = 0;
      double tmp = step;
      while(digits < 8 && MathAbs(tmp - MathRound(tmp)) > 0.00000001)
        {
         tmp *= 10.0;
         digits++;
        }
      lot = NormalizeDouble(lot, digits);
      if(lot < min_lot)
         return 0.0;
      return lot;
     }

   // CN: 根据止损距离和资金管理模式计算手数。 EN: Calculate lot size from SL distance and money management mode.
   double CalculateLot(const double sl_points, const double reward_risk_ratio)
     {
      if(sl_points <= 0.0 || g_tick_size <= 0.0 || g_tick_value <= 0.0 || g_point <= 0.0)
         return 0.0;

      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double risk_percent = InpRiskPercent;

      if(InpMoneyManagement == MM_FIXED_LOT)
         return NormalizeLot(InpFixedLot);

      if(InpMoneyManagement == MM_SIMPLE_KELLY)
        {
         int samples = ClosedTradeCount();
         if(samples >= InpKellyMinTrades && reward_risk_ratio > 0.0)
           {
            double kelly = InpKellyWinRate - (1.0 - InpKellyWinRate) / reward_risk_ratio;
            if(IsValidNumber(kelly) && kelly > 0.0)
               risk_percent = MathMin(kelly * 100.0, InpKellyMaxRiskPercent);
            else
               risk_percent = InpRiskPercent;
           }
         else
           {
            risk_percent = InpRiskPercent;
           }
        }

      risk_percent = MathMax(0.0, MathMin(risk_percent, InpKellyMaxRiskPercent));
      double risk_money = balance * risk_percent / 100.0;
      double price_distance = sl_points * g_point;
      double ticks = price_distance / g_tick_size;
      if(ticks <= 0.0)
         return 0.0;

      double loss_per_lot = ticks * g_tick_value;
      if(loss_per_lot <= 0.0)
         return 0.0;

      return NormalizeLot(risk_money / loss_per_lot);
     }

   // CN: 计算今日已实现盈亏。 EN: Calculate today's realized profit/loss.
   double TodayProfit()
     {
      datetime start = DayStart(TimeCurrent());
      if(!HistorySelect(start, TimeCurrent()))
         return 0.0;

      double profit = 0.0;
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong deal = HistoryDealGetTicket(i);
         if(deal == 0)
            continue;
         if((ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagicNumber)
            continue;
         if(HistoryDealGetString(deal, DEAL_SYMBOL) != g_symbol)
            continue;
         profit += HistoryDealGetDouble(deal, DEAL_PROFIT);
         profit += HistoryDealGetDouble(deal, DEAL_SWAP);
         profit += HistoryDealGetDouble(deal, DEAL_COMMISSION);
        }
      return profit;
     }

   // CN: 统计今日开仓次数。 EN: Count today's entry deals.
   int TodayTradeCount()
     {
      datetime start = DayStart(TimeCurrent());
      if(!HistorySelect(start, TimeCurrent()))
         return 0;

      int count = 0;
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong deal = HistoryDealGetTicket(i);
         if(deal == 0)
            continue;
         if((ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagicNumber)
            continue;
         if(HistoryDealGetString(deal, DEAL_SYMBOL) != g_symbol)
            continue;
         if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
            count++;
        }
      return count;
     }

   // CN: 检查当日风控限制。 EN: Check daily risk limits.
   bool DailyRiskAllowed(string &reason)
     {
      reason = "";
      double today = TodayProfit();
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      int trades = TodayTradeCount();

      if(InpMaxDailyLossMoney > 0.0 && today <= -InpMaxDailyLossMoney)
        {
         reason = "Max daily money loss / 达到最大当日亏损金额";
         return false;
        }

      if(InpMaxDailyLossPercent > 0.0 && balance > 0.0 && today <= -balance * InpMaxDailyLossPercent / 100.0)
        {
         reason = "Max daily percent loss / 达到最大当日亏损百分比";
         return false;
        }

      if(InpMaxDailyTrades > 0 && trades >= InpMaxDailyTrades)
        {
         reason = "Max daily trades / 达到最大单日交易次数";
         return false;
        }

      return true;
     }
  };

//+------------------------------------------------------------------+
//| CSignalGenerator / 信号生成类                                     |
//+------------------------------------------------------------------+
class CSignalGenerator
  {
private:
   int m_trend_ema50;
   int m_trend_ema200;
   int m_entry_ema_fast;
   int m_entry_ema_slow;
   int m_rsi;
   int m_bands;
   int m_atr;

public:
   // CN: 构造函数初始化句柄。 EN: Constructor initializes handles.
   CSignalGenerator()
     {
      m_trend_ema50 = INVALID_HANDLE;
      m_trend_ema200 = INVALID_HANDLE;
      m_entry_ema_fast = INVALID_HANDLE;
      m_entry_ema_slow = INVALID_HANDLE;
      m_rsi = INVALID_HANDLE;
      m_bands = INVALID_HANDLE;
      m_atr = INVALID_HANDLE;
     }

   // CN: 创建所有指标句柄。 EN: Create all indicator handles.
   bool Init()
     {
      m_trend_ema50 = iMA(g_symbol, InpTrendTimeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_trend_ema200 = iMA(g_symbol, InpTrendTimeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_entry_ema_fast = iMA(g_symbol, InpEntryTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_entry_ema_slow = iMA(g_symbol, InpEntryTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_rsi = iRSI(g_symbol, InpEntryTimeframe, InpRSIPeriod, PRICE_CLOSE);
      m_bands = iBands(g_symbol, InpEntryTimeframe, InpBandsPeriod, 0, InpBandsDeviation, PRICE_CLOSE);
      m_atr = iATR(g_symbol, InpEntryTimeframe, InpATRPeriod);

      if(m_trend_ema50 == INVALID_HANDLE || m_trend_ema200 == INVALID_HANDLE ||
         m_entry_ema_fast == INVALID_HANDLE || m_entry_ema_slow == INVALID_HANDLE ||
         m_rsi == INVALID_HANDLE || m_bands == INVALID_HANDLE || m_atr == INVALID_HANDLE)
        {
         Print("Failed to create indicator handles. / 创建指标句柄失败。 Error=", GetLastError());
         return false;
        }
      return true;
     }

   // CN: 释放指标句柄。 EN: Release indicator handles.
   void Deinit()
     {
      if(m_trend_ema50 != INVALID_HANDLE) IndicatorRelease(m_trend_ema50);
      if(m_trend_ema200 != INVALID_HANDLE) IndicatorRelease(m_trend_ema200);
      if(m_entry_ema_fast != INVALID_HANDLE) IndicatorRelease(m_entry_ema_fast);
      if(m_entry_ema_slow != INVALID_HANDLE) IndicatorRelease(m_entry_ema_slow);
      if(m_rsi != INVALID_HANDLE) IndicatorRelease(m_rsi);
      if(m_bands != INVALID_HANDLE) IndicatorRelease(m_bands);
      if(m_atr != INVALID_HANDLE) IndicatorRelease(m_atr);
     }

   // CN: 获取主趋势方向。 EN: Get main trend direction.
   ENUM_TREND_DIRECTION GetTrend()
     {
      double ema50 = 0.0;
      double ema200 = 0.0;
      if(!CopyIndicatorValue(m_trend_ema50, 0, 1, ema50) || !CopyIndicatorValue(m_trend_ema200, 0, 1, ema200))
         return TREND_NONE;

      double min_diff = InpTrendMinDiffPoints * g_point;
      if(ema50 > ema200 + min_diff)
         return TREND_UP;
      if(ema50 < ema200 - min_diff)
         return TREND_DOWN;
      return TREND_NONE;
     }

   // CN: 获取当前ATR点数。 EN: Get current ATR in points.
   double GetATRPoints()
     {
      double atr = 0.0;
      if(!CopyIndicatorValue(m_atr, 0, 1, atr) || g_point <= 0.0)
         return 0.0;
      return atr / g_point;
     }

   // CN: 生成多因子入场信号。 EN: Generate multi-factor entry signal.
   ENUM_SIGNAL_DIRECTION GenerateSignal(ENUM_TREND_DIRECTION trend, string &source)
     {
      source = "None";
      if(trend == TREND_NONE)
         return SIGNAL_NONE;

      if(InpEnableEMACross)
        {
         double fast1 = 0.0, fast2 = 0.0, slow1 = 0.0, slow2 = 0.0;
         if(CopyTwoIndicatorValues(m_entry_ema_fast, 0, 1, fast1, fast2) &&
            CopyTwoIndicatorValues(m_entry_ema_slow, 0, 1, slow1, slow2))
           {
            if(fast2 <= slow2 && fast1 > slow1 && trend == TREND_UP)
              {
               source = "EMA9/21 Golden Cross / EMA金叉";
               return SIGNAL_BUY;
              }
            if(fast2 >= slow2 && fast1 < slow1 && trend == TREND_DOWN)
              {
               source = "EMA9/21 Death Cross / EMA死叉";
               return SIGNAL_SELL;
              }
           }
        }

      if(InpEnableRSIReversal)
        {
         double rsi = 0.0;
         if(CopyIndicatorValue(m_rsi, 0, 1, rsi))
           {
            if(rsi < InpRSIOversold && trend == TREND_UP)
              {
               source = "RSI Reversal Buy / RSI多头反转";
               return SIGNAL_BUY;
              }
            if(rsi > InpRSIOverbought && trend == TREND_DOWN)
              {
               source = "RSI Reversal Sell / RSI空头反转";
               return SIGNAL_SELL;
              }
           }
        }

      if(InpEnableBollBreakout)
        {
         double upper = 0.0, lower = 0.0;
         double close1 = iClose(g_symbol, InpEntryTimeframe, 1);
         if(CopyIndicatorValue(m_bands, 1, 1, upper) && CopyIndicatorValue(m_bands, 2, 1, lower) && close1 > 0.0)
           {
            if(close1 > upper && trend == TREND_UP)
              {
               source = "Bollinger Upper Breakout / 布林上轨突破";
               return SIGNAL_BUY;
              }
            if(close1 < lower && trend == TREND_DOWN)
              {
               source = "Bollinger Lower Breakout / 布林下轨突破";
               return SIGNAL_SELL;
              }
           }
        }

      return SIGNAL_NONE;
     }
  };

//+------------------------------------------------------------------+
//| CTradeManager / 交易管理类                                        |
//+------------------------------------------------------------------+
class CTradeManager
  {
private:
   CRiskManager *m_risk;

   // CN: 查找TP1跟踪索引。 EN: Find TP1 tracking index.
   int FindTP1Index(const ulong ticket)
     {
      for(int i = 0; i < ArraySize(g_tp1_tickets); i++)
        {
         if(g_tp1_tickets[i] == ticket)
            return i;
        }
      return -1;
     }

   // CN: 标记TP1状态。 EN: Mark TP1 status.
   void SetTP1Done(const ulong ticket, const bool done)
     {
      int idx = FindTP1Index(ticket);
      if(idx < 0)
        {
         int size = ArraySize(g_tp1_tickets);
         ArrayResize(g_tp1_tickets, size + 1);
         ArrayResize(g_tp1_done, size + 1);
         g_tp1_tickets[size] = ticket;
         g_tp1_done[size] = done;
         return;
        }
      g_tp1_done[idx] = done;
     }

   // CN: 检查TP1是否已执行。 EN: Check if TP1 has been executed.
   bool IsTP1Done(const ulong ticket)
     {
      int idx = FindTP1Index(ticket);
      if(idx < 0)
         return false;
      return g_tp1_done[idx];
     }

public:
   // CN: 初始化交易管理器。 EN: Initialize trade manager.
   void Init(CRiskManager &risk)
     {
      m_risk = GetPointer(risk);
     }

   // CN: 统计当前EA持仓数量。 EN: Count current EA positions.
   int PositionCount()
     {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) == g_symbol && (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            count++;
        }
      return count;
     }

   // CN: 检查是否已有同方向持仓。 EN: Check whether same-direction position already exists.
   bool HasSameDirectionPosition(const ENUM_SIGNAL_DIRECTION signal)
     {
      ENUM_POSITION_TYPE want = (signal == SIGNAL_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != g_symbol || (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
            continue;
         if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == want)
            return true;
        }
      return false;
     }

   // CN: 写入CSV交易日志。 EN: Write a CSV trade log row.
   void LogTrade(const string open_time, const string close_time, const string symbol, const string direction,
                 const double lot, const double open_price, const double close_price, const double sl, const double tp,
                 const double profit_points, const double profit_money, const string reason)
     {
      ResetLastError();
      bool exists = FileIsExist(InpCSVFileName);
      int handle = FileOpen(InpCSVFileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI);
      if(handle == INVALID_HANDLE)
        {
         Print("Failed to open CSV log. / 打开CSV日志失败。 Error=", GetLastError());
         return;
        }

      if(!exists || FileSize(handle) == 0)
        {
         FileWrite(handle, "open_time", "close_time", "symbol", "direction", "lot", "open_price", "close_price", "sl", "tp", "profit_points", "profit_money", "reason");
        }
      FileSeek(handle, 0, SEEK_END);
      FileWrite(handle, open_time, close_time, symbol, direction, DoubleToString(lot, 2),
                DoubleToString(open_price, g_digits), DoubleToString(close_price, g_digits),
                DoubleToString(sl, g_digits), DoubleToString(tp, g_digits),
                DoubleToString(profit_points, 1), DoubleToString(profit_money, 2), reason);
      FileClose(handle);
     }

   // CN: 按方向执行市价单。 EN: Execute a market order by direction.
   bool OpenPosition(const ENUM_SIGNAL_DIRECTION signal, const double atr_points, const string reason)
     {
      if(signal == SIGNAL_NONE || atr_points <= 0.0)
         return false;

      double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
      if(ask <= 0.0 || bid <= 0.0)
         return false;

      double sl_points = MathMax(atr_points * InpATRSLMultiplier, 1.0);
      double tp_points = MathMax(atr_points * InpATRTPMultiplier, 1.0);
      double rr = tp_points / sl_points;
      if(rr < InpMinRewardRiskRatio)
        {
         Print("Reward/risk too low. / 盈亏比过低: ", DoubleToString(rr, 2));
         return false;
        }

      int stop_level = (int)SymbolInfoInteger(g_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      if(stop_level > 0)
        {
         sl_points = MathMax(sl_points, stop_level + 2.0);
         tp_points = MathMax(tp_points, stop_level + 2.0);
        }

      double lot = m_risk.CalculateLot(sl_points, rr);
      if(lot <= 0.0)
        {
         Print("Invalid lot, order skipped. / 手数无效，跳过开仓。");
         return false;
        }

      double price = (signal == SIGNAL_BUY ? ask : bid);
      double sl = (signal == SIGNAL_BUY ? price - sl_points * g_point : price + sl_points * g_point);
      double tp = (signal == SIGNAL_BUY ? price + tp_points * g_point : price - tp_points * g_point);
      sl = NormalizePrice(sl);
      tp = NormalizePrice(tp);

      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);
      request.action = TRADE_ACTION_DEAL;
      request.symbol = g_symbol;
      request.magic = InpMagicNumber;
      request.volume = lot;
      request.type = (signal == SIGNAL_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      request.price = NormalizePrice(price);
      request.sl = sl;
      request.tp = tp;
      request.deviation = InpMaxSlippagePoints;
      request.type_filling = GetFillingMode();
      request.comment = reason;

      ResetLastError();
      if(!OrderSend(request, result))
        {
         Print("OrderSend failed. / 下单失败。 Error=", GetLastError(), " retcode=", result.retcode);
         return false;
        }

      if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED)
        {
         Print("Order rejected. / 订单被拒绝。 retcode=", result.retcode, " comment=", result.comment);
         return false;
        }

      Print("Position opened. / 已开仓 ticket=", result.order, " lot=", DoubleToString(lot, 2), " reason=", reason);
      LogTrade(TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), "", g_symbol, DirectionToString((int)signal), lot,
               request.price, 0.0, sl, tp, 0.0, 0.0, "OPEN: " + reason);
      return true;
     }

   // CN: 修改持仓止损止盈。 EN: Modify position SL/TP.
   bool ModifyPosition(const ulong ticket, const double sl, const double tp)
     {
      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);
      request.action = TRADE_ACTION_SLTP;
      request.position = ticket;
      request.symbol = g_symbol;
      request.magic = InpMagicNumber;
      request.sl = NormalizePrice(sl);
      request.tp = NormalizePrice(tp);

      ResetLastError();
      if(!OrderSend(request, result))
        {
         Print("Modify failed. / 修改止损止盈失败。 Error=", GetLastError(), " ticket=", ticket);
         return false;
        }
      if(result.retcode != TRADE_RETCODE_DONE)
        {
         Print("Modify rejected. / 修改被拒绝。 retcode=", result.retcode, " ticket=", ticket);
         return false;
        }
      return true;
     }

   // CN: 平仓指定持仓的指定手数。 EN: Close specified volume of a position.
   bool ClosePositionVolume(const ulong ticket, const double volume, const string reason)
     {
      if(!PositionSelectByTicket(ticket))
         return false;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double close_price = (ptype == POSITION_TYPE_BUY ? SymbolInfoDouble(g_symbol, SYMBOL_BID) : SymbolInfoDouble(g_symbol, SYMBOL_ASK));
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double old_volume = PositionGetDouble(POSITION_VOLUME);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double close_volume = m_risk.NormalizeLot(MathMin(volume, old_volume));
      if(close_volume <= 0.0)
        {
         Print("Invalid close volume. / 平仓手数无效。 ticket=", ticket);
         return false;
        }

      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);
      request.action = TRADE_ACTION_DEAL;
      request.position = ticket;
      request.symbol = g_symbol;
      request.magic = InpMagicNumber;
      request.volume = close_volume;
      request.type = (ptype == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
      request.price = NormalizePrice(close_price);
      request.deviation = InpMaxSlippagePoints;
      request.type_filling = GetFillingMode();
      request.comment = reason;

      ResetLastError();
      if(!OrderSend(request, result))
        {
         Print("Close failed. / 平仓失败。 Error=", GetLastError(), " ticket=", ticket);
         return false;
        }
      if(result.retcode != TRADE_RETCODE_DONE)
        {
         Print("Close rejected. / 平仓被拒绝。 retcode=", result.retcode, " ticket=", ticket);
         return false;
        }

      double points = (ptype == POSITION_TYPE_BUY ? (close_price - open_price) / g_point : (open_price - close_price) / g_point);
      double close_profit = 0.0;
      if(result.deal > 0 && HistorySelect(TimeCurrent() - 86400, TimeCurrent() + 60))
         close_profit = HistoryDealGetDouble(result.deal, DEAL_PROFIT) + HistoryDealGetDouble(result.deal, DEAL_SWAP) + HistoryDealGetDouble(result.deal, DEAL_COMMISSION);
      LogTrade(TimeToString((datetime)PositionGetInteger(POSITION_TIME), TIME_DATE|TIME_SECONDS),
               TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), g_symbol,
               DirectionToString(ptype == POSITION_TYPE_BUY ? 1 : -1), close_volume, open_price, close_price, sl, tp,
               points, close_profit, "CLOSE: " + reason);
      return true;
     }

   // CN: 管理移动止损、分批出场和时间退出。 EN: Manage trailing stop, partial close and time exit.
   void ManagePositions()
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != g_symbol || (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
            continue;

         ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         double volume = PositionGetDouble(POSITION_VOLUME);
         datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
         double current = (ptype == POSITION_TYPE_BUY ? SymbolInfoDouble(g_symbol, SYMBOL_BID) : SymbolInfoDouble(g_symbol, SYMBOL_ASK));
         if(current <= 0.0 || g_point <= 0.0)
            continue;

         double profit_points = (ptype == POSITION_TYPE_BUY ? (current - open_price) / g_point : (open_price - current) / g_point);
         double sl_points = (sl > 0.0 ? MathAbs(open_price - sl) / g_point : 0.0);
         double tp_points = (tp > 0.0 ? MathAbs(tp - open_price) / g_point : 0.0);

         if(InpMaxHoldingHours > 0 && TimeCurrent() - open_time >= InpMaxHoldingHours * 3600)
           {
            ClosePositionVolume(ticket, volume, "Time exit / 时间退出");
            continue;
           }

         if(tp_points > 0.0 && !IsTP1Done(ticket))
           {
            double tp1_points = tp_points * 0.5;
            if(profit_points >= tp1_points)
              {
               double min_lot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);
               double close_lot = m_risk.NormalizeLot(volume * InpPartialClosePercent / 100.0);
               double remain_lot = m_risk.NormalizeLot(volume - close_lot);
               if(close_lot >= min_lot && remain_lot >= min_lot && close_lot < volume)
                 {
                  if(ClosePositionVolume(ticket, close_lot, "TP1 partial close / TP1分批平仓"))
                     SetTP1Done(ticket, true);
                 }
               else
                 {
                  Print("Partial close skipped due to min lot. / 因最小手数限制跳过分批平仓。 ticket=", ticket);
                  SetTP1Done(ticket, true);
                 }
              }
           }

         if(sl_points > 0.0 && profit_points >= sl_points * InpTrailingStartSLMultiple)
           {
            double new_sl = sl;
            if(ptype == POSITION_TYPE_BUY)
              {
               new_sl = current - InpTrailingStepPoints * g_point;
               if((sl <= 0.0 || new_sl > sl + InpTrailingStepPoints * g_point) && new_sl < current)
                  ModifyPosition(ticket, new_sl, tp);
              }
            else
              {
               new_sl = current + InpTrailingStepPoints * g_point;
               if((sl <= 0.0 || new_sl < sl - InpTrailingStepPoints * g_point) && new_sl > current)
                  ModifyPosition(ticket, new_sl, tp);
              }
           }
        }
     }

   // CN: 周五强制平仓。 EN: Force close positions on Friday.
   void CloseFridayPositionsIfNeeded()
     {
      if(!InpEnableFridayFilter || !InpClosePositionsOnFriday)
         return;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week != 5 || dt.hour < InpFridayNoTradeHour)
         return;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) == g_symbol && (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            ClosePositionVolume(ticket, PositionGetDouble(POSITION_VOLUME), "Friday force close / 周五强制平仓");
        }
     }
  };

CNewsFilter      g_news;
CRiskManager     g_risk;
CSignalGenerator g_signal;
CTradeManager    g_trade;

// CN: 检查是否新K线。 EN: Check for a new entry timeframe bar.
bool IsNewBar()
  {
   datetime bt = iTime(g_symbol, InpEntryTimeframe, 0);
   if(bt <= 0)
      return false;
   if(bt != g_last_bar_time)
     {
      g_last_bar_time = bt;
      return true;
     }
   return false;
  }

// CN: 检查基础开仓过滤条件。 EN: Check basic entry filters.
bool CheckEntryFilters(const double atr_points, const double rr, string &reason)
  {
   reason = "";

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      reason = "Trading not allowed / 终端或EA不允许交易";
      return false;
     }

   if(CurrentSpreadPoints() > InpMaxSpreadPoints)
     {
      reason = "Spread too high / 点差过高";
      return false;
     }

   string daily_reason = "";
   if(!g_risk.DailyRiskAllowed(daily_reason))
     {
      reason = daily_reason;
      return false;
     }

   string news_reason = "";
   if(g_news.IsBlocked(TimeCurrent(), news_reason))
     {
      reason = news_reason;
      return false;
     }

   if(atr_points < InpMinATRPoints)
     {
      reason = "ATR too low / ATR低波动过滤";
      return false;
     }

   if(rr < InpMinRewardRiskRatio)
     {
      reason = "Reward/risk too low / 盈亏比过低";
      return false;
     }

   if(InpEnableFridayFilter)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5 && dt.hour >= InpFridayNoTradeHour)
        {
         reason = "Friday no-trade time / 周五禁开时间";
         return false;
        }
     }

   return true;
  }

// CN: 更新图表面板。 EN: Update chart comment panel.
void UpdatePanel()
  {
   if(!InpEnablePanel)
      return;

   ENUM_TREND_DIRECTION trend = g_signal.GetTrend();
   string text = "XAUUSD MultiFactor Pro EA\n";
   text += "EA Status / 状态: " + (g_allow_trade ? "ALLOW / 允许" : "BLOCK / 禁止") + "\n";
   text += "Trend / 趋势: " + TrendToString(trend) + "\n";
   text += "Signal / 信号来源: " + g_last_signal_source + "\n";
   text += "Balance / 余额: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
   text += "Equity / 净值: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n";
   text += "Today PnL / 今日盈亏: " + DoubleToString(g_risk.TodayProfit(), 2) + "\n";
   text += "Today Trades / 今日交易次数: " + IntegerToString(g_risk.TodayTradeCount()) + "\n";
   text += "Positions / 当前持仓: " + IntegerToString(g_trade.PositionCount()) + "\n";
   text += "Spread(points) / 点差: " + DoubleToString(CurrentSpreadPoints(), 1) + "\n";
   text += "Allow Trade / 是否允许交易: " + (g_allow_trade ? "Yes / 是" : "No / 否") + "\n";
   text += "Block Reason / 禁止原因: " + (g_block_reason == "" ? "None / 无" : g_block_reason);
   Comment(text);
  }

//+------------------------------------------------------------------+
//| Expert initialization function / EA初始化函数                     |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_symbol = (InpTradeSymbol == "" ? _Symbol : InpTradeSymbol);
   if(!SymbolSelect(g_symbol, true))
     {
      Print("Failed to select symbol. / 选择品种失败: ", g_symbol, " Error=", GetLastError());
      return INIT_FAILED;
     }

   g_point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   g_tick_size = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);
   g_tick_value = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_VALUE);
   g_digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
   if(g_point <= 0.0 || g_tick_size <= 0.0 || g_tick_value <= 0.0)
     {
      Print("Invalid symbol trading properties. / 品种交易属性无效。");
      return INIT_FAILED;
     }

   if(!g_news.Init(InpNewsTimes, InpNewsBlockMinutes))
      return INIT_FAILED;
   if(!g_signal.Init())
      return INIT_FAILED;
   g_trade.Init(g_risk);

   EventSetTimer(MathMax(1, InpTimerSeconds));
   g_last_bar_time = iTime(g_symbol, InpEntryTimeframe, 0);
   Print("EA initialized. / EA初始化完成: ", g_symbol);
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function / EA反初始化函数                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_signal.Deinit();
   Comment("");
   Print("EA deinitialized. / EA已卸载 reason=", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function / EA报价驱动函数                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_trade.ManagePositions();
   g_trade.CloseFridayPositionsIfNeeded();

   ENUM_TREND_DIRECTION trend = g_signal.GetTrend();
   double atr_points = g_signal.GetATRPoints();
   double rr = (InpATRSLMultiplier > 0.0 ? InpATRTPMultiplier / InpATRSLMultiplier : 0.0);

   g_block_reason = "";
   g_allow_trade = CheckEntryFilters(atr_points, rr, g_block_reason);

   if(!IsNewBar())
     {
      UpdatePanel();
      return;
     }

   string source = "None";
   ENUM_SIGNAL_DIRECTION signal = g_signal.GenerateSignal(trend, source);
   g_last_signal_source = source;

   if(signal != SIGNAL_NONE)
     {
      if(!g_allow_trade)
        {
         Print("Signal blocked. / 信号被过滤: ", g_block_reason, " source=", source);
        }
      else if(g_trade.HasSameDirectionPosition(signal))
        {
         g_block_reason = "Same-direction position exists / 已有同方向持仓";
         g_allow_trade = false;
         Print(g_block_reason);
        }
      else
        {
         g_trade.OpenPosition(signal, atr_points, source);
        }
     }

   UpdatePanel();
  }

//+------------------------------------------------------------------+
//| Timer function / 定时器函数                                       |
//+------------------------------------------------------------------+
void OnTimer()
  {
   g_trade.ManagePositions();
   g_trade.CloseFridayPositionsIfNeeded();
   UpdatePanel();
  }

//+------------------------------------------------------------------+
//| Chart event function / 图表事件函数                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   // CN: 当前EA无需复杂图表交互，保留事件入口便于扩展。 EN: No complex chart interaction is needed now; keep this hook for extension.
   if(id == CHARTEVENT_CHART_CHANGE)
      UpdatePanel();
  }

//+------------------------------------------------------------------+
//| Tester custom criterion / 回测自定义指标                          |
//+------------------------------------------------------------------+
double OnTester()
  {
   // CN: 返回净利润与最大回撤的简化评分，避免除零。 EN: Return simplified net-profit/drawdown score and avoid division by zero.
   double profit = TesterStatistics(STAT_PROFIT);
   double dd = TesterStatistics(STAT_EQUITY_DD);
   if(dd <= 0.0)
      return profit;
   return profit / dd;
  }
//+------------------------------------------------------------------+
