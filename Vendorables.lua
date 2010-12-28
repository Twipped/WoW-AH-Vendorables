Vendorables = LibStub("AceAddon-3.0"):NewAddon("Vendorables", "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0", "AceHook-3.0")

Vendorables.BuyoutHits = {}
Vendorables.TotalBuyoutHits = 0
Vendorables.FullScan = false

Vendorables.AHIsOpen = false

local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local QTC = LibStub('LibQTipClick-1.1')

local defaults = {
	profile = {
		LibDBIcon = { hide = false },
		threshold = 100,
		postProcessCount = 1000,
		craftables = {
			["52178"] = {{price=90000, craft="Jewelcrafting", creates=52086}}, -- raw zephyrite
			["52179"] = {{price=90000, craft="Jewelcrafting", creates=52094}} -- raw alicite
		}
	}
}

function Vendorables:OnInitialize()
	Vendorables.db = LibStub("AceDB-3.0"):New("VendorablesDB", defaults)
	self:RegisterEvent('AUCTION_ITEM_LIST_UPDATE')
	self:RegisterEvent("AUCTION_HOUSE_SHOW");
	self:RegisterEvent("AUCTION_HOUSE_CLOSED");
	self:SecureHook("QueryAuctionItems",
                    "QueryAuctionItems_Hook");

end


------------------------------------------------------------------------------------------------------------------------------
-- LDB Functions
------------------------------------------------------------------------------------------------------------------------------

Vendorables.dataObject = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("Vendorables", {
	type = "data source",
	text = "No Data",
	icon = "Interface\\Icons\\inv_misc_coin_02",
	OnEnter = function(frame)
		Vendorables:ShowToolTip(frame)
	end,
	OnLeave = function()
		return
	end
})

local function TooltipCallback(event, cell, arg, button)
	if arg == "scan" then
		Vendorables.FullScan = true
		Vendorables:Print("Initiating full scan, waiting for results...")
		QueryAuctionItems("",0,0,0,0,0,0,0,0,true)

	elseif arg == "clear" then
		Vendorables.BuyoutHits = {}
		Vendorables.AuctionHistory = {}
		Vendorables.TotalBuyoutHits = 0
		Vendorables:Print("Auction Data Cleared")
		Vendorables.dataObject.text = "No Data"
		
	elseif arg == "output" then
		Vendorables:Print("Current Results On File:")
		for key, entry in pairs(Vendorables.BuyoutHits) do
			local m
			if entry['creates'] ~= nil then
				m = entry['method']..entry['creates']
			else
				m = entry['method']
			end
			Vendorables:Print(entry['type'].." "..entry["count"].."x"..entry["link"].."  Price:"..Vendorables:CopperToString(entry['price']).."    "..m.."    Profit: "..Vendorables:CopperToString(entry['profit']))
		end
		Vendorables:Print("End of Results")
	end
end


function Vendorables:ShowToolTip(frame)
	if Vendorables.AHIsOpen==false then return end

	tooltip = QTC:Acquire("Broker_VendorablesTooltip", 1, "LEFT")
	tooltip:SmartAnchorTo(frame)
	tooltip:SetAutoHideDelay(0.25, frame)
	tooltip:SetCallback("OnMouseDown", TooltipCallback)
 	tooltip:Clear()
	
	_, canMassQuery = CanSendAuctionQuery("list")
	if (canMassQuery) then
		local y, x = tooltip:AddLine()
		y, x = tooltip:SetCell(y, 1, " Scan Auction House", "scan")
	end
	
	local y, x = tooltip:AddLine()
    y, x = tooltip:SetCell(y, 1, " Print Results", "output")

	local y, x = tooltip:AddLine()
    y, x = tooltip:SetCell(y, 1, " Clear History", "clear")

	
    tooltip:Show()

end


------------------------------------------------------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------------------------------------------------------

function Vendorables:AUCTION_HOUSE_SHOW()
	Vendorables.AHIsOpen = true
end
function Vendorables:AUCTION_HOUSE_CLOSED()
	Vendorables.AHIsOpen = false
end

Vendorables.QueryPending = false
function Vendorables:QueryAuctionItems_Hook()
--	self:Print('QueryAuctionItems')
	Vendorables.QueryPending = true;
end

Vendorables.Batch = nil
Vendorables.AuctionCache = {}
function Vendorables:AUCTION_ITEM_LIST_UPDATE()
--	self:Print('AUCTION_ITEM_LIST_UPDATE')
	-- we already processed the last query, ignore any further events
	if Vendorables.QueryPending==false then return end
	
	local Results = {}
	local BatchCount, TotalCount = GetNumAuctionItems("list")
	
	if (TotalCount==0) then return end

	local i, counted = 0,0
	for i=1,BatchCount do
		local item = self:GetAuctionItem(i)
		if Vendorables.AuctionCache[item.hash] == nil then
			Vendorables.AuctionCache[item.hash] = 1;
			Vendorables:ProcessItem(item);
			counted = counted + 1
		else
			Vendorables.AuctionCache[item.hash] = self.AuctionCache[item.hash] + 1;
		end
	end
	
	Vendorables.dataObject.text = Vendorables.TotalBuyoutHits.." Items"

	self:Print('Processed '..counted..'/'..BatchCount)
		
	Vendorables.FullScan = false
	Vendorables.QueryPending = false
end


------------------------------------------------------------------------------------------------------------------------------
-- Internal Functions
------------------------------------------------------------------------------------------------------------------------------

function Vendorables:GetAuctionItem(i)
	local name, _, count, _, _, _, minBid, minIncrement, buyout, bidAmount, highestBidder, owner, sold = GetAuctionItemInfo("list",i)
	local duration = GetAuctionItemTimeLeft("list", i)
	local link = GetAuctionItemLink("list", i)
	
	--if owner == nil then return nil end
	if owner == nil then owner = '' end
	if name == nil then name = '' end
	
	local _, _, _, _, itemID, _, _, _, _, _, suffixID, uniqueID, _, _ = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")	
	
	local bid;
	if bidAmount <= 0 then
		bid = minBid;
	else
		bid = bidAmount + minIncrement;
		if bid > buyout and buyout > 0 then
			bid = buyout;
		end
	end

	local hash = strjoin(':', itemID, suffixID, count, bid, buyout)
  
	return {
		link = link, name = name, id = itemID, suffix = suffixID, unique = uniqueID, count = count,
		bid = bid, buyout = buyout, owner = owner, duration = duration, hash = hash
	}
end

function Vendorables:ProcessAuctions(Results)
	Vendorables:Print('Processing '..#Results..' Records')
	local i, item, counted = 0,0,0
	for i,item in ipairs(Results) do
		if Vendorables.AuctionCache[item.hash] == nil then
			Vendorables.AuctionCache[item.hash] = 1;
			Vendorables:ProcessItem(item);
			counted = counted + 1
		else
			Vendorables.AuctionCache[item.hash] = self.AuctionCache[item.hash] + 1;
		end
	end
	Vendorables:Print('Processed '..counted..'/'..#Results)

	Vendorables.dataObject.text = Vendorables.TotalBuyoutHits.." Items"
end

function Vendorables:ProcessItem(item)
	if item.buyout>0 then

		local boPrice = math.floor(item.buyout/item.count)
		buyMethod, buyCreates, buyProfit = Vendorables:CheckPrice(item.id, boPrice)

		if method ~= nil and profit~=nil and profit > Vendorables.db.profile.threshold then
		
			local key = strjoin(':', method, item.id, boPrice)
			if (Vendorables.BuyoutHits[key] == nil) then
				Vendorables.BuyoutHits[key] = {method=method, link=item.link, price=boPrice, count=item.count, profit=profit, creates=creates}
			else
				Vendorables.BuyoutHits[key]["count"] = Vendorables.BuyoutHits[key]["count"] + item.count
			end
		
			Vendorables.TotalBuyoutHits = Vendorables.TotalBuyoutHits + item.count		
		
		end
	end
end

function Vendorables:CheckPrice(itemid, price)
	local method, creates, profit = nil, nil, 0

	-- scan for craftables
	if Vendorables.db.profile.craftables[itemid] ~= nil then
		for i,craftable in ipairs(Vendorables.db.profile.craftables[itemid]) do
			if craftable["price"] > price and craftable["price"] - price > profit then
				local _, link, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(craftable["creates"])
				method, creates, profit = craftable["craft"], link, craftable["price"] - price
			end
		end
	end
	
	-- check vendor price
	local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(itemid)
	if price < vendorPrice and vendorPrice - price > profit then
		 method, creates, profit = "vendor", nil, vendorPrice - price
	end
	
	return method, creates, profit
end

function Vendorables:CopperToString(c) -- shamelessly taken from Broker_DurabilityInfo
	local str = ""
	if not c or c < 0 then 
		return str 
	end
	
	if c >= 10000 then
		local g = math.floor(c/10000)
		c = c - g*10000
		str = str.."|cFFFFD800"..g.."|r |TInterface\\MoneyFrame\\UI-GoldIcon.blp:0:0:0:0|t"
	end
	if c >= 100 then
		local s = math.floor(c/100)
		c = c - s*100
		str = str.."|cFFC7C7C7"..s.."|r |TInterface\\MoneyFrame\\UI-SilverIcon.blp:0:0:0:0|t"
	end
	if math.floor(c) > 0 then
		str = str.."|cFFEEA55F"..c.."|r |TInterface\\MoneyFrame\\UI-CopperIcon.blp:0:0:0:0|t"
	end
	
	return str
end