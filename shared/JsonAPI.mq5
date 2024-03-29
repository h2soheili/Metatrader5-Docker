//+------------------------------------------------------------------+
//
// Copyright (C) 2019 Nikolai Khramkov
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//+------------------------------------------------------------------+

// TODO: Deviation

#property copyright   "Copyright 2019, Nikolai Khramkov."
#property link        "https://github.com/khramkov"
#property version     "2.00"
#property description "MQL5 JSON API"
#property description "See github link for documentation"

#include <Trade/AccountInfo.mqh>
#include <Trade/DealInfo.mqh>
#include <Trade/Trade.mqh>
#include <Zmq/Zmq.mqh>
#include <Json.mqh>
#include <StringToEnumInt.mqh>
#include <ControlErrors.mqh>

// Set ports and host for ZeroMQ
string HOST="*";
int SYS_PORT=15555;
int DATA_PORT=15556;
int LIVE_PORT=15557;
// ZeroMQ Connections
Context context("MQL5_JSON_API_1");

Socket sysSocket(context,ZMQ_REP);
Socket dataSocket(context,ZMQ_PUSH);
Socket liveSocket(context,ZMQ_PUSH);

// Load MQL5-JSON-API includes
// Required:
#include <MQL5-JSON_API/HistoryInfo.mqh>
// Optional:
#include <MQL5-JSON_API/StartIndicator.mqh>
#include <MQL5-JSON_API/ChartControl.mqh>


// Global variables \\
bool debug = false;
bool liveStream = true;
bool connectedFlag = true;
int deInitReason = -1;
double chartAttached = ChartID(); // Chart id where the expert is attached to




// Variables for handling price data stream
struct SymbolSubscription
  {
   string            symbol;
   string            chartTf;
   datetime          lastBar;
  };
SymbolSubscription symbolSubscriptions[];
int symbolSubscriptionCount = 0;
datetime startTime = TimeCurrent();
// Error handling
ControlErrors mControl;




//+------------------------------------------------------------------+
//| Get retcode message by retcode id                                |
//+------------------------------------------------------------------+
string GetRetcodeID(int retcode)
  {

   switch(retcode)
     {
      case 10004:
         return("TRADE_RETCODE_REQUOTE");
         break;
      case 10006:
         return("TRADE_RETCODE_REJECT");
         break;
      case 10007:
         return("TRADE_RETCODE_CANCEL");
         break;
      case 10008:
         return("TRADE_RETCODE_PLACED");
         break;
      case 10009:
         return("TRADE_RETCODE_DONE");
         break;
      case 10010:
         return("TRADE_RETCODE_DONE_PARTIAL");
         break;
      case 10011:
         return("TRADE_RETCODE_ERROR");
         break;
      case 10012:
         return("TRADE_RETCODE_TIMEOUT");
         break;
      case 10013:
         return("TRADE_RETCODE_INVALID");
         break;
      case 10014:
         return("TRADE_RETCODE_INVALID_VOLUME");
         break;
      case 10015:
         return("TRADE_RETCODE_INVALID_PRICE");
         break;
      case 10016:
         return("TRADE_RETCODE_INVALID_STOPS");
         break;
      case 10017:
         return("TRADE_RETCODE_TRADE_DISABLED");
         break;
      case 10018:
         return("TRADE_RETCODE_MARKET_CLOSED");
         break;
      case 10019:
         return("TRADE_RETCODE_NO_MONEY");
         break;
      case 10020:
         return("TRADE_RETCODE_PRICE_CHANGED");
         break;
      case 10021:
         return("TRADE_RETCODE_PRICE_OFF");
         break;
      case 10022:
         return("TRADE_RETCODE_INVALID_EXPIRATION");
         break;
      case 10023:
         return("TRADE_RETCODE_ORDER_CHANGED");
         break;
      case 10024:
         return("TRADE_RETCODE_TOO_MANY_REQUESTS");
         break;
      case 10025:
         return("TRADE_RETCODE_NO_CHANGES");
         break;
      case 10026:
         return("TRADE_RETCODE_SERVER_DISABLES_AT");
         break;
      case 10027:
         return("TRADE_RETCODE_CLIENT_DISABLES_AT");
         break;
      case 10028:
         return("TRADE_RETCODE_LOCKED");
         break;
      case 10029:
         return("TRADE_RETCODE_FROZEN");
         break;
      case 10030:
         return("TRADE_RETCODE_INVALID_FILL");
         break;
      case 10031:
         return("TRADE_RETCODE_CONNECTION");
         break;
      case 10032:
         return("TRADE_RETCODE_ONLY_REAL");
         break;
      case 10033:
         return("TRADE_RETCODE_LIMIT_ORDERS");
         break;
      case 10034:
         return("TRADE_RETCODE_LIMIT_VOLUME");
         break;
      case 10035:
         return("TRADE_RETCODE_INVALID_ORDER");
         break;
      case 10036:
         return("TRADE_RETCODE_POSITION_CLOSED");
         break;
      case 10038:
         return("TRADE_RETCODE_INVALID_CLOSE_VOLUME");
         break;
      case 10039:
         return("TRADE_RETCODE_CLOSE_ORDER_EXIST");
         break;
      case 10040:
         return("TRADE_RETCODE_LIMIT_POSITIONS");
         break;
      case 10041:
         return("TRADE_RETCODE_REJECT_CANCEL");
         break;
      case 10042:
         return("TRADE_RETCODE_LONG_ONLY");
         break;
      case 10043:
         return("TRADE_RETCODE_SHORT_ONLY");
         break;
      case 10044:
         return("TRADE_RETCODE_CLOSE_ONLY");
         break;

      default:
         return("TRADE_RETCODE_UNKNOWN="+IntegerToString(retcode));
         break;
     }
  }

//+------------------------------------------------------------------+
//| Get error message by error id                                    |
//+------------------------------------------------------------------+
string GetErrorID(int error)
  {

   switch(error)
     {
      // Custom errors
      case 65537:
         return("ERR_DESERIALIZATION");
         break;
      case 65538:
         return("ERR_WRONG_ACTION");
         break;
      case 65539:
         return("ERR_WRONG_ACTION_TYPE");
         break;
      case 65540:
         return("ERR_CLEAR_SUBSCRIPTIONS_FAILED");
         break;
      case 65541:
         return("ERR_RETRIEVE_DATA_FAILED");
         break;
      case 65542:
         return("ERR_CVS_FILE_CREATION_FAILED");
         break;


      default:
         return("ERR_CODE_UNKNOWN="+IntegerToString(error));
         break;
     }
  }

//+------------------------------------------------------------------+
//| Return a textual description of the deinitialization reason code |
//+------------------------------------------------------------------+
string getUninitReasonText(int reasonCode)
  {
   string text="";
//---
   switch(reasonCode)
     {
      case REASON_ACCOUNT:
         text="Account was changed";
         break;
      case REASON_CHARTCHANGE:
         text="Symbol or timeframe was changed";
         break;
      case REASON_CHARTCLOSE:
         text="Chart was closed";
         break;
      case REASON_PARAMETERS:
         text="Input-parameter was changed";
         break;
      case REASON_RECOMPILE:
         text="Program "+__FILE__+" was recompiled";
         break;
      case REASON_REMOVE:
         text="Program "+__FILE__+" was removed from chart";
         break;
      case REASON_TEMPLATE:
         text="New template was applied to chart";
         break;
      default:
         text="Another reason";
     }
//---
   return text;
  }

//+------------------------------------------------------------------+
//| Fetch positions information                                      |
//+------------------------------------------------------------------+
void GetPositions(CJAVal &dataObject, string req_id){
// Get positions
   int positionsTotal = PositionsTotal();

   if(debug){
      Print("positionsTotal ",positionsTotal);
   }      
   CPositionInfo myposition;
   CJAVal data,position;

// Create empty array if no positions
  //  if(!positionsTotal)
    // data["positions"].Add(position);
    // double arr[];
    // data["positions"] = arr;
// Go through positions in a loop
   mControl.mResetLastError();
   for(int i=0; i<positionsTotal; i++){
      //if(myposition.Select(PositionGetSymbol(i)))
         if(myposition.SelectByIndex(i)){
         position["id"]=PositionGetInteger(POSITION_IDENTIFIER);
         position["magic"]=PositionGetInteger(POSITION_MAGIC);
         string sym = PositionGetString(POSITION_SYMBOL);
         position["symbol"]=(string) sym;
         position["type"]=EnumToString(ENUM_POSITION_TYPE(PositionGetInteger(POSITION_TYPE)));
         position["time_setup"]=PositionGetInteger(POSITION_TIME);
         position["open"]=PositionGetDouble(POSITION_PRICE_OPEN);
         position["stoploss"]=PositionGetDouble(POSITION_SL);
         position["takeprofit"]=PositionGetDouble(POSITION_TP);
         position["volume"]=PositionGetDouble(POSITION_VOLUME);
         position["profit"]=PositionGetDouble(POSITION_PROFIT);
         data["positions"].Add(position);
        } 
   } 
   data["req_id"]=req_id;
   string t = data.Serialize();
   if(debug){
    Print(t);
   }
   InformClientSocket(dataSocket, t);
}

//+------------------------------------------------------------------+
//| Fetch orders information                                         |
//+------------------------------------------------------------------+
void GetOrders(CJAVal &dataObject, string req_id){
   mControl.mResetLastError();

   COrderInfo myorder;
   CJAVal data, order;

// Get orders
   if(HistorySelect(0,TimeCurrent())){
      int ordersTotal = OrdersTotal();
      // Create empty array if no orders
      // if(!ordersTotal)
      //   {
      //    data["error"]=(bool) false;
      //    data["orders"].Add(order);
      //   }

      for(int i=0; i<ordersTotal; i++)
        {
         if(myorder.Select(OrderGetTicket(i)))
           {
            order["id"]=(string) myorder.Ticket();
            order["magic"]=OrderGetInteger(ORDER_MAGIC);
            order["symbol"]=OrderGetString(ORDER_SYMBOL);
            order["type"]=EnumToString(ENUM_ORDER_TYPE(OrderGetInteger(ORDER_TYPE)));
            order["time_setup"]=OrderGetInteger(ORDER_TIME_SETUP);
            order["open"]=OrderGetDouble(ORDER_PRICE_OPEN);
            order["stoploss"]=OrderGetDouble(ORDER_SL);
            order["takeprofit"]=OrderGetDouble(ORDER_TP);
            order["volume"]=OrderGetDouble(ORDER_VOLUME_INITIAL);
            data["orders"].Add(order);
           }
         // Error handling
         // CheckError(__FUNCTION__);
        }
     }

   data["req_id"] = req_id;
   string t=data.Serialize();
   if(debug)
      Print(t);
   InformClientSocket(dataSocket,t);
}

//+------------------------------------------------------------------+
//| Trading module                                                   |
//+------------------------------------------------------------------+
void TradingModule(CJAVal &dataObject, string req_id)
  {
   mControl.mResetLastError();
   CTrade trade;

   string   actionType = dataObject["actionType"].ToStr();
   string   symbol=dataObject["symbol"].ToStr();
   SymbolInfoString(symbol, SYMBOL_DESCRIPTION);
   CheckError(__FUNCTION__,req_id);

   int      idNimber=dataObject["id"].ToInt();
   double   volume=dataObject["volume"].ToDbl();
   double   SL=dataObject["stoploss"].ToDbl();
   double   TP=dataObject["takeprofit"].ToDbl();
   double   price=NormalizeDouble(dataObject["price"].ToDbl(),_Digits);
   double   deviation=dataObject["deviation"].ToDbl();
   string   comment=dataObject["comment"].ToStr();

// Order expiration section
   ENUM_ORDER_TYPE_TIME exp_type = ORDER_TIME_GTC;
   datetime expiration = 0;
   if(dataObject["expiration"].ToInt() != 0)
     {
      exp_type = ORDER_TIME_SPECIFIED;
      expiration=dataObject["expiration"].ToInt();
     }

// Market orders
   if(actionType=="ORDER_TYPE_BUY" || actionType=="ORDER_TYPE_SELL")
     {
      ENUM_ORDER_TYPE orderType=ORDER_TYPE_BUY;
      price = SymbolInfoDouble(symbol,SYMBOL_ASK);
      if(actionType=="ORDER_TYPE_SELL")
        {
         orderType=ORDER_TYPE_SELL;
         price=SymbolInfoDouble(symbol,SYMBOL_BID);
        }

      if(trade.PositionOpen(symbol,orderType,volume,price,SL,TP,comment))
        {
         OrderDoneOrError(false, __FUNCTION__, trade, req_id);
         return;
        }
     }

// Pending orders
   else
      if(actionType=="ORDER_TYPE_BUY_LIMIT" || actionType=="ORDER_TYPE_SELL_LIMIT" || actionType=="ORDER_TYPE_BUY_STOP" || actionType=="ORDER_TYPE_SELL_STOP")
        {
         if(actionType=="ORDER_TYPE_BUY_LIMIT")
           {
            if(trade.BuyLimit(volume,price,symbol,SL,TP,ORDER_TIME_GTC,expiration,comment))
              {
               OrderDoneOrError(false, __FUNCTION__, trade, req_id);
               return;
              }
           }
         else
            if(actionType=="ORDER_TYPE_SELL_LIMIT")
              {
               if(trade.SellLimit(volume,price,symbol,SL,TP,ORDER_TIME_GTC,expiration,comment))
                 {
                  OrderDoneOrError(false, __FUNCTION__, trade, req_id);
                  return;
                 }
              }
            else
               if(actionType=="ORDER_TYPE_BUY_STOP")
                 {
                  if(trade.BuyStop(volume,price,symbol,SL,TP,ORDER_TIME_GTC,expiration,comment))
                    {
                     OrderDoneOrError(false, __FUNCTION__, trade, req_id);
                     return;
                    }
                 }
               else
                  if(actionType=="ORDER_TYPE_SELL_STOP")
                    {
                     if(trade.SellStop(volume,price,symbol,SL,TP,ORDER_TIME_GTC,expiration,comment))
                       {
                        OrderDoneOrError(false, __FUNCTION__, trade, req_id);
                        return;
                       }
                    }
        }
      // Position modify
      else
         if(actionType=="POSITION_MODIFY")
           {
            if(trade.PositionModify(idNimber,SL,TP))
              {
               OrderDoneOrError(false, __FUNCTION__, trade, req_id);
               return;
              }
           }
         // Position close partial
         else
            if(actionType=="POSITION_PARTIAL")
              {
               if(trade.PositionClosePartial(idNimber,volume))
                 {
                  OrderDoneOrError(false, __FUNCTION__, trade, req_id);
                  return;
                 }
              }
            // Position close by id
            else
               if(actionType=="POSITION_CLOSE_ID")
                 {
                  if(trade.PositionClose(idNimber))
                    {
                     OrderDoneOrError(false, __FUNCTION__, trade, req_id);
                     return;
                    }
                 }
               // Position close by symbol
               else
                  if(actionType=="POSITION_CLOSE_SYMBOL")
                    {
                     if(trade.PositionClose(symbol))
                       {
                        OrderDoneOrError(false, __FUNCTION__, trade, req_id);
                        return;
                       }
                    }
                  // Modify pending order
                  else
                     if(actionType=="ORDER_MODIFY")
                       {
                        if(trade.OrderModify(idNimber,price,SL,TP,ORDER_TIME_GTC,expiration))
                          {
                           OrderDoneOrError(false, __FUNCTION__, trade, req_id);
                           return;
                          }
                       }
                     // Cancel pending order
                     else
                        if(actionType=="ORDER_CANCEL")
                          {
                           if(trade.OrderDelete(idNimber))
                             {
                              OrderDoneOrError(false, __FUNCTION__, trade, req_id);
                              return;
                             }
                          }
                        // Action type dosen't exist
                        else
                          {
                           mControl.mSetUserError(65538, GetErrorID(65538));
                           CheckError(__FUNCTION__,req_id);
                          }

// This part of the code runs if order was not completed
   OrderDoneOrError(true, __FUNCTION__, trade, req_id);
  }

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {

   ENUM_TRADE_TRANSACTION_TYPE  trans_type=trans.type;
   switch(trans.type)
     {
      case  TRADE_TRANSACTION_REQUEST:
        {
         CJAVal data, req, res;
         data["req_id"]=(string) request.comment;
         req["action"]=EnumToString(request.action);
         req["order"]=(int) request.order;
         req["symbol"]=(string) request.symbol;
         req["volume"]=(double) request.volume;
         req["price"]=(double) request.price;
         req["stoplimit"]=(double) request.stoplimit;
         req["sl"]=(double) request.sl;
         req["tp"]=(double) request.tp;
         req["deviation"]=(int) request.deviation;
         req["type"]=EnumToString(request.type);
         req["type_filling"]=EnumToString(request.type_filling);
         req["type_time"]=EnumToString(request.type_time);
         req["expiration"]=(int) request.expiration;
         req["comment"]=(string) request.comment;
         req["position"]=(int) request.position;
         req["position_by"]=(int) request.position_by;

         res["retcode"]=(int) result.retcode;
         res["result"]=(string) GetRetcodeID(result.retcode);
         res["deal"]=(int) result.order;
         res["order"]=(int) result.order;
         res["volume"]=(double) result.volume;
         res["price"]=(double) result.price;
         res["comment"]=(string) result.comment;
         res["request_id"]=(int) result.request_id;
         res["retcode_external"]=(int) result.retcode_external;

         data["request"].Set(req);
         data["result"].Set(res);

         string t = data.Serialize();
         if(debug){
            Print(t);
         }
         InformClientSocket(dataSocket, t);
        }
      break;
      default:
        {} break;
     }
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Bind ZMQ sockets to ports                                        |
//+------------------------------------------------------------------+
bool BindSockets(){
   sysSocket.setLinger(1000);
   dataSocket.setLinger(1000);
   liveSocket.setLinger(1000);
// Number of messages to buffer in RAM.
   sysSocket.setSendHighWaterMark(1000);
   dataSocket.setSendHighWaterMark(1000);
   liveSocket.setSendHighWaterMark(1000);

   bool result = false;
   result = sysSocket.bind(StringFormat("tcp://%s:%d", HOST,SYS_PORT));
   if(result == false)
     {
      return result;
     }
   else
     {
      Print("Bound 'System' socket on port ", SYS_PORT);
     }
   result = dataSocket.bind(StringFormat("tcp://%s:%d", HOST,DATA_PORT));
   if(result == false)
     {
      return result;
     }
   else
     {
      Print("Bound 'Data' socket on port ", DATA_PORT);
     }
   result = liveSocket.bind(StringFormat("tcp://%s:%d", HOST,LIVE_PORT));
   if(result == false)
     {
      return result;
     }
   else
     {
      Print("Bound 'Live' socket on port ", LIVE_PORT);
     }
   return true;
}

void subscribeInitial(){
   // CJAVal incomingMessage;
   // incomingMessage["symbol"] = (string) _Symbol;
   // incomingMessage["chartTF"] = "TICK";
   // ScriptConfiguration(incomingMessage);

   // CJAVal incomingMessage2;
   // incomingMessage2["symbol"] = (string) _Symbol;
   // incomingMessage2["chartTF"] = "M1";
   // ScriptConfiguration(incomingMessage2);

   // CJAVal incomingMessage3;
   // incomingMessage3["symbol"] = (string) _Symbol;
   // incomingMessage3["chartTF"] = "M5";
   // ScriptConfiguration(incomingMessage3);

   // CJAVal incomingMessage4;
   // incomingMessage4["symbol"] = (string) _Symbol;
   // incomingMessage4["chartTF"] = "M15";
   // ScriptConfiguration(incomingMessage4);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {


// Setting up error reporting
   mControl.SetAlert(true);
   mControl.SetSound(false);
   mControl.SetWriteFlag(false);
   /* Bindinig ZMQ ports on init */
// Skip reloading of the EA script when the reason to reload is a chart timeframe change
   if(deInitReason != REASON_CHARTCHANGE)
     {

      EventSetMillisecondTimer(50);

      int bindSocketsDelay = 65; // Seconds to wait if binding of sockets fails.
      int bindAttemtps = 4; // Number of binding attemtps

      Print("Binding sockets...");

      for(int i=0; i<bindAttemtps; i++)
        {
         if(BindSockets()){
            // subscribeInitial();
            return(INIT_SUCCEEDED);
         }
         else
           {
            Print("Binding sockets failed. Waiting ", bindSocketsDelay, " seconds to try again...");
            Sleep(bindSocketsDelay*1000);
           }
        }

      Print("Binding of sockets failed permanently.");
      return(INIT_FAILED);
     }
   // subscribeInitial();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   /* Unbinding ZMQ ports on denit */

// TODO Ports do not get freed immediately under Wine. How to properly close ports? There is a timeout of about 60 sec.
// https://forum.winehq.org/viewtopic.php?t=22758
// https://github.com/zeromq/cppzmq/issues/139

   deInitReason = reason;

// Skip reloading of the EA script when the reason to reload is a chart timeframe change
   if(reason != REASON_CHARTCHANGE)
     {
      Print(__FUNCTION__," Deinitialization reason: ", getUninitReasonText(reason));

      Print("Unbinding 'System' socket on port ", SYS_PORT, "..");
      sysSocket.unbind(StringFormat("tcp://%s:%d", HOST, SYS_PORT));
      Print("Unbinding 'Data' socket on port ", DATA_PORT, "..");
      dataSocket.unbind(StringFormat("tcp://%s:%d", HOST, DATA_PORT));
      Print("Unbinding 'Live' socket on port ", LIVE_PORT, "..");
      liveSocket.unbind(StringFormat("tcp://%s:%d", HOST, LIVE_PORT));

      // Shutdown ZeroMQ Context
      context.shutdown();
      context.destroy(0);

      // Reset
      ResetSubscriptionsAndIndicators("reset");

      EventKillTimer();
     }
  }

//+------------------------------------------------------------------+
//| Check if subscribed to symbol and timeframe combination          |
//+------------------------------------------------------------------+
bool HasChartSymbol(string symbol, string chartTF)
  {
   for(int i=0; i<ArraySize(symbolSubscriptions); i++)
     {
      if(symbolSubscriptions[i].symbol == symbol && symbolSubscriptions[i].chartTf == chartTF)
        {
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Stream candle data                                           |
//+------------------------------------------------------------------+
void StreamCandleData() {

   for(int i=0; i<symbolSubscriptionCount; i++)
      {
            string chartTF = symbolSubscriptions[i].chartTf;
            if(chartTF == "TICK"){
               continue;
            }
            string symbol=symbolSubscriptions[i].symbol;
            datetime lastBar=symbolSubscriptions[i].lastBar;
            datetime thisBar = 0;
            MqlRates rates[1];
            int spread[1];

            ENUM_TIMEFRAMES period = GetTimeframe(chartTF);
            if(CopyRates(symbol, period, 1, 1, rates)!=1) {
               /*mControl.Check();*/
            }
            if(CopySpread(symbol, period, 1, 1, spread)!=1) {
               /*mControl.Check();*/;
            }
            thisBar= (datetime) rates[0].time;
            if(lastBar!=thisBar)
            {
               if(lastBar!=0)  // skip first price data after startup/reset
               {
                  CJAVal last;
                  CJAVal Data;
                  Data[0] = (long) rates[0].time;
                  Data[1] = (double) rates[0].open;
                  Data[2] = (double) rates[0].high;
                  Data[3] = (double) rates[0].low;
                  Data[4] = (double) rates[0].close;
                  Data[5] = (double) rates[0].tick_volume;
                  Data[6] = (int) spread[0];
                  last["symbol"] = (string) symbol;
                  last["timeframe"] = (string) chartTF;
                  last["data"].Set(Data);

                  string t = last.Serialize();
                  if(debug){
                     Print(t);
                  }
                  InformClientSocket(liveSocket, t);
               }
               symbolSubscriptions[i].lastBar = thisBar;
            }
      }
}


//+------------------------------------------------------------------+
//| Request handler                                                  |
//+------------------------------------------------------------------+
void RequestHandler(ZmqMsg &request)
  {

   CJAVal incomingMessage;

   ResetLastError();
// Get data from reguest
   string msg = request.getData();

   if(debug)
      Print("Processing: " + msg);

   if(!incomingMessage.Deserialize(msg))
     {
      if(debug){
         Print("incomingMessage.Deserialize error: " + GetLastError());
      }
      mControl.mSetUserError(65537, GetErrorID(65537));
      CheckError(__FUNCTION__,"IncomingMessageDeserializeError");
     }

// Send response to System socket that request was received
// Some historical data requests can take a lot of time
   InformClientSocket(sysSocket, "ok");

// Process action command
   string action = incomingMessage["action"].ToStr();
   string req_id = incomingMessage["req_id"].ToStr();

   if(action=="CONFIG"){
      ScriptConfiguration(incomingMessage, req_id);
      return;
   }
   if(action=="ACCOUNT"){
      GetAccountInfo(incomingMessage, req_id);
      return;
   }
   if(action=="BALANCE"){
      GetBalanceInfo(incomingMessage, req_id);
      return;
   }
   if(action=="HISTORY"){
      HistoryInfo(incomingMessage, req_id);
      return;
   }
   if(action=="TRADE"){
      TradingModule(incomingMessage, req_id);
      return;
   }
   if(action=="POSITIONS"){
      GetPositions(incomingMessage, req_id);
      return;
   }
   if(action=="ORDERS"){
      GetOrders(incomingMessage, req_id);
      return;
   }
   if(action=="RESET"){
      ResetSubscriptionsAndIndicators(req_id);
      return;
   }
   if(debug){
      Print("No actions finded " + req_id + "  " + msg);
   }
   mControl.mSetUserError(65538, GetErrorID(65538));
   CheckError(__FUNCTION__, req_id);

  }

//+------------------------------------------------------------------+
//| Reconfigure the script params                                    |
//+------------------------------------------------------------------+
void ScriptConfiguration(CJAVal &dataObject, string req_id)
  {

   string symbol = dataObject["symbol"].ToStr();
   string chartTF = dataObject["chartTF"].ToStr();

   ArrayResize(symbolSubscriptions, symbolSubscriptionCount+1);
   symbolSubscriptions[symbolSubscriptionCount].symbol = symbol;
   symbolSubscriptions[symbolSubscriptionCount].chartTf = chartTF;
// to initialze with value 0 skips the first price
   symbolSubscriptions[symbolSubscriptionCount].lastBar = 0;
   symbolSubscriptionCount++;
   if(MarketBookAdd(symbol)){
      PrintFormat("%s: MarketBookAdd(%s) function returned true", __FUNCTION__, symbol);
   } else{
      PrintFormat("%s: MarketBookAdd(%s) function returned false! GetLastError()=%d", __FUNCTION__, symbol, GetLastError());
   }
   mControl.mResetLastError();
   SymbolInfoString(symbol, SYMBOL_DESCRIPTION);
   if(!CheckError(__FUNCTION__,req_id)){
      ActionDoneOrError(ERR_SUCCESS, __FUNCTION__, "ERR_SUCCESS", req_id);
   }
  }

//+------------------------------------------------------------------+
//| Account information                                              |
//+------------------------------------------------------------------+
void GetAccountInfo(CJAVal &dataObject, string req_id)
  {

   CJAVal info;
   info["req_id"] = req_id;
   info["error"] = false;
   info["broker"] = AccountInfoString(ACCOUNT_COMPANY);
   info["currency"] = AccountInfoString(ACCOUNT_CURRENCY);
   info["server"] = AccountInfoString(ACCOUNT_SERVER);
   info["trading_allowed"] = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
   info["bot_trading"] = AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
   info["balance"] = AccountInfoDouble(ACCOUNT_BALANCE);
   info["equity"] = AccountInfoDouble(ACCOUNT_EQUITY);
   info["margin"] = AccountInfoDouble(ACCOUNT_MARGIN);
   info["margin_free"] = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   info["margin_level"] = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

   string t = info.Serialize();
   if(debug)
      Print(t);
   InformClientSocket(dataSocket, t);
  }

//+------------------------------------------------------------------+
//| Balance information                                              |
//+------------------------------------------------------------------+
void GetBalanceInfo(CJAVal &dataObject, string req_id)
  {

   CJAVal info;
   info["req_id"] = req_id;
   info["balance"] = AccountInfoDouble(ACCOUNT_BALANCE);
   info["equity"] = AccountInfoDouble(ACCOUNT_EQUITY);
   info["margin"] = AccountInfoDouble(ACCOUNT_MARGIN);
   info["margin_free"] = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   string t = info.Serialize();
   if(debug){
      Print(t);
   }
   InformClientSocket(dataSocket, t);
  }

//+------------------------------------------------------------------+
//| Push historical data to ZMQ socket                               |
//+------------------------------------------------------------------+
bool PushHistoricalData(CJAVal &data)
  {
   string t = data.Serialize();
   if(debug){
      Print(t);
   }
   InformClientSocket(dataSocket,t);
   return true;
  }

//+------------------------------------------------------------------+
//| Convert chart timeframe from string to enum                      |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetTimeframe(string chartTF)
  {

   ENUM_TIMEFRAMES tf;
   tf=NULL;

   if(chartTF=="TICK")
      tf=PERIOD_CURRENT;

   if(chartTF=="M1")
      tf=PERIOD_M1;

   if(chartTF=="M5")
      tf=PERIOD_M5;

   if(chartTF=="M15")
      tf=PERIOD_M15;

   if(chartTF=="M30")
      tf=PERIOD_M30;

   if(chartTF=="H1")
      tf=PERIOD_H1;

   if(chartTF=="H2")
      tf=PERIOD_H2;

   if(chartTF=="H3")
      tf=PERIOD_H3;

   if(chartTF=="H4")
      tf=PERIOD_H4;

   if(chartTF=="H6")
      tf=PERIOD_H6;

   if(chartTF=="H8")
      tf=PERIOD_H8;

   if(chartTF=="H12")
      tf=PERIOD_H12;

   if(chartTF=="D1")
      tf=PERIOD_D1;

   if(chartTF=="W1")
      tf=PERIOD_W1;

   if(chartTF=="MN1")
      tf=PERIOD_MN1;

//if tf == NULL an error will be raised in config function
   return(tf);
  }

//+------------------------------------------------------------------+
//| Trade confirmation                                               |
//+------------------------------------------------------------------+
void OrderDoneOrError(bool error, string funcName, CTrade &trade, string req_id)
  {

   CJAVal conf;
   conf["req_id"]=(string) req_id;
   conf["error"]=(bool) error;
   conf["retcode"]=(int) trade.ResultRetcode();
   conf["description"]=(string) GetRetcodeID(trade.ResultRetcode());
// conf["deal"]=(int) trade.ResultDeal();
   conf["order"]=(int) trade.ResultOrder();
   conf["volume"]=(double) trade.ResultVolume();
   conf["price"]=(double) trade.ResultPrice();
   conf["bid"]=(double) trade.ResultBid();
   conf["ask"]=(double) trade.ResultAsk();
   conf["function"]=(string) funcName;

   string t = conf.Serialize();
   if(debug){
      Print(t);
   }
   InformClientSocket(dataSocket,t);
  }


//+------------------------------------------------------------------+
//| Error reporting                                                  |
//+------------------------------------------------------------------+
bool CheckError(string funcName, string req_id)
  {
   int lastError = mControl.mGetLastError();
   if(lastError)
     {
      string desc = mControl.mGetDesc();
      Print("Error handling source: ", funcName," description: ", desc);
      mControl.Check();
      ActionDoneOrError(lastError, funcName, desc, req_id);
      return true;
     }
   else
      return false;

  }

//+------------------------------------------------------------------+
//| Action confirmation                                              |
//+------------------------------------------------------------------+
void ActionDoneOrError(int lastError, string funcName, string desc, string req_id)
  {

   CJAVal conf;

   conf["error"]=(bool)true;
   if(lastError==0)
      conf["error"]=(bool)false;

   conf["lastError"]=(string) lastError;
   conf["description"]=(string) desc;
   conf["function"]=(string) funcName;
   conf["req_id"]=(string) req_id;

   string t=conf.Serialize();
   if(debug)
      Print(t);
   InformClientSocket(dataSocket,t);
  }

//+------------------------------------------------------------------+
//| Inform Client via socket                                         |
//+------------------------------------------------------------------+
void InformClientSocket(Socket &workingSocket, string replyMessage)
{

// non-blocking
   workingSocket.send(replyMessage, true);
// TODO: Array out of range error
   mControl.mResetLastError();
//mControl.Check();
}

//+------------------------------------------------------------------+
//| Clear symbol subscriptions and indicators                        |
//+------------------------------------------------------------------+
void ResetSubscriptionsAndIndicators(string req_id)
  {
      for(int i=0; i < ArraySize(symbolSubscriptions); i++){
         string symbol = symbolSubscriptions[i].symbol;
         if(!MarketBookRelease(symbol))
         {
            PrintFormat("%s: MarketBookRelease(%s) returned false! GetLastError()=%d", symbol, GetLastError());
         }
      }


   ArrayFree(symbolSubscriptions);
   symbolSubscriptionCount=0;

   bool error = false;
#ifdef START_INDICATOR
   for(int i=0; i<indicatorCount; i++)
     {
      if(!IndicatorRelease(indicators[i].indicatorHandle))
         error = true;
     }
   ArrayFree(indicators);
   indicatorCount = 0;
#endif
#ifdef CHART_CONTROL
   for(int i=0; i<chartWindowIndicatorCount; i++)
     {
      if(!IndicatorRelease(chartWindowIndicators[i].indicatorHandle))
         error = true;
     }
   ArrayFree(chartWindowIndicators);
   chartWindowIndicatorCount = 0;

   for(int i=0; i<ArraySize(chartWindows); i++)
     {
      // TODO check if chart exists first: if(ChartGetInteger...
      //if(!IndicatorRelease(chartWindows[i].indicatorHandle)) error = true;
      if(chartWindows[i].id != 0)
         ChartClose(chartWindows[i].id);
     }
   ArrayFree(chartWindows);
#endif

   /*
   if(ArraySize(symbolSubscriptions)!=0 || ArraySize(indicators)!=0 || ArraySize(chartWindows)!=0 || error){
     // Set to only Alert. Fails too often, this happens when i.e. the backtrader script gets aborted unexpectedly
     mControl.Check();
     mControl.mSetUserError(65540, GetErrorID(65540));
     CheckError(__FUNCTION__);
   }
   */
   ActionDoneOrError(ERR_SUCCESS, __FUNCTION__, "ERR_SUCCESS", req_id);
  }
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
  {


   ZmqMsg request;

// Get request from client via System socket.
   sysSocket.recv(request, true);

// Request recived
   if(request.size()>0)
   {
      // Pull request to RequestHandler().
      RequestHandler(request);
   }
   // datetime now = TimeCurrent();
   // Stream live price data
   // if(liveStream && (now - startTime) >= 1){
   //    StreamCandleData();
   // }
   // startTime = now;
  }

//+------------------------------------------------------------------+
//| BookEvent function                                               |
//+------------------------------------------------------------------+
//void OnBookEvent(const string &symbol){


      //--- array of the DOM structures
      // MqlBookInfo lastBookArray[];

      // //--- get the book
      // if(MarketBookGet(symbol, lastBookArray))
      //   {

      //    //--- process book data
      //    for(int idx=0; idx<ArraySize(lastBookArray);idx++)
      //      {
      //       MqlBookInfo currentInfo= lastBookArray[idx];
      //       CJAVal last;
      //       CJAVal Data;
      //       Data[0] = (string) EnumToString(currentInfo.type);
      //       Data[1] = (double)  currentInfo.price;
      //       Data[2] = (double)  currentInfo.volume;

      //       last["symbol"] = (string) symbol;
      //       last["timeframe"] = "BOOK";
      //       last["data"].Set(Data);

      //       string t = last.Serialize();
      //       if(debug){
      //          Print(t);
      //       }
      //       InformClientSocket(liveSocket, t);
      //      }
      //  }
//}


  //+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   for(int i=0; i<symbolSubscriptionCount; i++)
   {
      string chartTF = symbolSubscriptions[i].chartTf;
      if(chartTF != "TICK"){
         continue;
      }
      string symbol = symbolSubscriptions[i].symbol;
      MqlTick lastTick;
      if(SymbolInfoTick(symbol, lastTick)){
         datetime lastBar = symbolSubscriptions[i].lastBar;
         datetime thisBar = (datetime) lastTick.time_msc;
         if(lastBar != thisBar){
            CJAVal last;
            CJAVal Data;
            Data[0] = (long)    lastTick.time_msc;
            Data[1] = (double)  lastTick.bid;
            Data[2] = (double)  lastTick.ask;
            Data[3] = (double)  lastTick.last;
            Data[4] = (double)  lastTick.volume;
            last["symbol"] = (string) symbol;
            last["timeframe"] = "TICK";
            last["data"].Set(Data);
            string t = last.Serialize();
            if(debug){
               Print(t);
            }
            InformClientSocket(liveSocket, t);
            symbolSubscriptions[i].lastBar=thisBar;
         }

      }
   }
}