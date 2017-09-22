local _M={}
--自己申请的AccessKeyId&SECRET_KEY
_M.AccessKeyId="xxxxxx-xxxxxx"
_M.SECRET_KEY="xxxx-xxxxx-xxxx"
_M.DOMAIN="be.huobi.com"

function _M.urlEncode(s)  
     s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)  
    return string.gsub(s, " ", "+")  
end  
  
function _M.urlDecode(s)  
    s = string.gsub(s, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)  
    return s  
end 


function _M.get_symbol_data()
	local data={}
	data[1]=[[AccessKeyId=]].._M.AccessKeyId
	data[2]=[[SignatureMethod=HmacSHA256]]
	data[3]=[[SignatureVersion=2]]
	data[4]=[[Timestamp=]].._M.urlEncode(os.date("%Y-%m-%dT%H:%M:%S",os.time()-8*3600))
	return data
end


function _M.createSign(method,action,dataTable)
	--生产认证签名Signature
	table.sort(dataTable)
	local	msg=method.."\n".._M.DOMAIN.."\n"..action.."\n"..table.concat(dataTable,"&")
    	require "hmac.sha2"
	require "base64"
	local	Signature=base64.encode(hmac.sha256(msg,_M.SECRET_KEY))
	Signature=_M.urlEncode(Signature)
	--print(Signature)
	return Signature
end

function _M.getAccount()
	--查询当前用户的所有账户(即account-id)
	local action="/v1/account/accounts"
	local method="GET"
	local dataTable=_M.get_symbol_data()
	dataTable[5]=[[Signature=]].._M.createSign(method,action,dataTable)
	local requesturl=[[https://]].._M.DOMAIN..action.."?"..table.concat(dataTable,"&")
	local result=_M.runRequest(requesturl,nil)
	--result={"status":"ok","data":[{"id":xxx,"type":"spot","state":"working"}]}
	local cjson = require "cjson"
	local datajson=cjson.decode(result)
	return datajson["data"][1]["id"],datajson["data"][1]["state"],datajson["status"]
end

function _M.getAccountBalance(uid)
	--查询指定账户的余额
	local action=[[/v1/account/accounts/]]..uid..[[/balance]]
	local method="GET"
	local dataTable=_M.get_symbol_data()
        dataTable[5]=[[Signature=]].._M.createSign(method,action,dataTable)
	local requesturl=[[https://]].._M.DOMAIN..action.."?"..table.concat(dataTable,"&")
	local result=_M.runRequest(requesturl,nil)
	return result
end

function _M.oneStepPlace(uid,amount,price,symbol,bstype)
	--创建并执行一个新订单 (一步下单， 推荐使用),返回 订单号，status
	local source="api"
	
	local postTable={}
	postTable[1]=[["account-id":"]]..uid..[["]]
	postTable[2]=[["amount":"]]..amount..[["]]
	postTable[3]=[["source":"api"]]
	postTable[4]=[["symbol":"]]..symbol..[["]]
	postTable[5]=[["type":"]]..bstype..[["]]
	if string.match(bstype,"limit") then
		postTable[6]=[["price":"]]..price..[["]]
	end

	local action="/v1/order/orders/place"
	local method="POST"
	local dataTable=_M.get_symbol_data()
        dataTable[5]=[[Signature=]].._M.createSign(method,action,dataTable)
	local postdata=[[{]]..table.concat(postTable,",")..[[}]]
	local requesturl= [[https://]].._M.DOMAIN..action.."?"..table.concat(dataTable,"&")
	local result=_M.runRequest(requesturl,postdata)
	--result={"status": "ok","data": "59378" }
        local cjson = require "cjson"
        local datajson=cjson.decode(result)
        return datajson["data"],datajson["status"]
	--return result

end

function _M.allSell(uid,amount,symbol)
	--showhand
	return _M.oneStepPlace(uid,amount,"10000000000",symbol,"sell-market")
end

function _M.cancleOrder(orderid)
	--申请撤销一个订单请求
	local action=[[/v1/order/orders/]]..orderid..[[/submitcancel]]
        local method="POST"
        local dataTable=_M.get_symbol_data()
        dataTable[5]=[[Signature=]].._M.createSign(method,action,dataTable)
	local postdata=""	
	local requesturl=[[https://]].._M.DOMAIN..action.."?"..table.concat(dataTable,"&")
	local result=_M.runRequest(requesturl,postdata)
        return result
end

function _M.getCurrentTradeInfo(symbol)
	--获取 Trade Detail 数据 , 返回 成交价格，成交量，动作 
	local action="/market/trade?symbol="..symbol
	local requesturl=[[https://]].._M.DOMAIN..action
	local result=_M.runRequest(requesturl,nil)
        local cjson=require "cjson"
        local currentTradeInfoData=cjson.decode(result)
	local currentPrice=currentTradeInfoData["tick"]["data"][1]["price"]
	local currentAmount=currentTradeInfoData["tick"]["data"][1]["amount"]
	local currentOp=currentTradeInfoData["tick"]["data"][1]["direction"]
        return currentPrice,currentAmount,currentOp
end


function _M.getHistoryKline(symbol,period,size)
	--获取K线数据, 返回 period时间内价格的 最大值 最小值 开始值 结束值 成交量
	local action=[[/market/history/kline]]
	local method="GET"
	local dataTable=_M.get_symbol_data()
	dataTable[5]=[[Signature=]].._M.createSign(method,action,dataTable)

	local inputParams="symbol="..symbol.."&period="..period.."&size="..size
	local requesturl=[[https://]].._M.DOMAIN..action.."?"..table.concat(dataTable,"&")..[[&]]..inputParams
	local result=_M.runRequest(requesturl)
	--print(result,"\n")
	local cjson=require "cjson"
	local klineJson=cjson.decode(result)
	local highPrice=klineJson["data"][size]["high"]
	local lowPrice=klineJson["data"][size]["low"]
	local openPrice=klineJson["data"][size]["open"]
	local closePrice=klineJson["data"][size]["close"]
	local amount=klineJson["data"][size]["amount"]
	return highPrice,lowPrice,openPrice,closePrice,amount

end

function _M.runRequest(requesturl,postdata)
	local curl = require "lcurl"
	local result=nil
	local c=curl.easy()
	c:setopt{
		-- xxx = curl.OPT_XXX
	 	--url = 'https://be.huobi.com/market/history/kline?period=1day&size=2&symbol=etccny',
 		[curl.OPT_URL] =requesturl,
		httpheader = {
		      "Content-type:application/json;charset=UTF-8",
		      "User-Agent: Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.71 Safari/537.36"
		},
		writefunction = function(str) result=(result or '')..str end,
		connecttimeout = 3,
		ssl_verifyhost=0,
		ssl_verifypeer=0
		--verbose = true
	 }
	if postdata then
		c:setopt_postfields (postdata)
	end
	c:perform()
	c:close()
	return result
end

return _M
