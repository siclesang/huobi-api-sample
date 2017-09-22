#!/usr/bin/env lua

--package.path = '/xxxx/?.lua;'..package.path
local huobi=require("huobi")
local cjson = require 'cjson'
local symbol="etccny"
local amount=nil

local lowper=0.8
local highper=1.1

--print(m.getAccount())

local uid,_,_ = huobi.getAccount()

local today=os.date("%Y%m%d",os.time())

local currentPrice=huobi.getCurrentTradeInfo(symbol)

local lowPrice=currentPrice*lowper
local highPrice=currentPrice*highper

while true do
	print("----------------------------------------------------"..os.date("%Y-%m-%d %H:%M:%S"))
	
	if today~=os.date("%Y%m%d",os.time()) then
	 	today=os.date("%Y%m%d",os.time())
		local currentPrice=huobi.getCurrentTradeInfo(symbol)

		local lowPrice=currentPrice*lowper
		local highPrice=currentPrice*highper
	end
	print("prelowPrice:",lowPrice)
	print("prehighPrice:",highPrice)

	local balanceresult =huobi.getAccountBalance(uid)
	--print(balanceresult)
	local balanceJson=cjson.decode(balanceresult)
	local balance=balanceJson["data"]["list"][3]["balance"]
	print("balance:",balance)

	--orderid,status=huobi.oneStepPlace(uid,"10","2.0","etccny","buy-limit")
	--print(orderid,status)
	--os.execute("sleep 60 " )
	--print(huobi.cancleOrder(orderid))
	--
	--local currentPrice,currentAmount,currenOp=huobi.getCurrentTradeInfo(symbol)
	local currentPrice=huobi.getCurrentTradeInfo(symbol)
	print("price:",currentPrice)

	if currentPrice < lowPrice then
		amount=(balance-2)/currentPrice
		local orderid,status=huobi.oneStepPlace(uid,amount,currentPrice,"etccny","buy-limit")
		print("buy",orderid,status)
	end

	if currentPrice > highPrice and amount  then
		local orderid,status=huobi.oneStepPlace(uid,amount,currentPrice,"etccny","sell-limit")
		print("sell",orderid,status)
	end

end

