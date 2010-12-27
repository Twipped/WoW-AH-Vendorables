Vendorables = LibStub("AceAddon-3.0"):NewAddon("Vendorables", "AceEvent-3.0", "AceConsole-3.0")
Vendorables.AuctionData = {}
Vendorables.AuctionHistory = {}
Vendorables.TotalResults = 0
Vendorables.LastRowCount = 0;
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
--local L = LibStub("AceLocale-3.0"):GetLocale("Vendorables")
--local AceConfig = LibStub("AceConfig-3.0")
--local AceConfigDialog = LibStub("AceConfigDialog-3.0")
--local AceDB = LibStub("AceDB-3.0")
--local AceDBOptions = LibStub("AceDBOptions-3.0")
local QTC = LibStub('LibQTipClick-1.1')

local defaults = {
	profile = {
		LibDBIcon = { hide = false },
		threshold = 100,
		craftables = {
			-- raw zephyrite
			["52178"] = {{price=90000, craft="Jewelcrafting", creates=52086}},
			["52179"] = {{price=90000, craft="Jewelcrafting", creates=52094}}
		}
	},
	realm = {
		ScanTime = 0,
		ScanData = {}
	}
}

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
		Vendorables.AuctionData = {}
		Vendorables.AuctionHistory = {}
		Vendorables.TotalResults = 0
		Vendorables.db.realm.ScanData = {}
		Vendorables.db.realm.ScanTime = time()
		Vendorables:Print("Initiating Full Scan, please wait...")
		QueryAuctionItems("",0,80,0,0,0,0,false,0,true)

	elseif arg == "clear" then
		Vendorables.AuctionData = {}
		Vendorables.AuctionHistory = {}
		Vendorables.TotalResults = 0
		Vendorables:Print("Auction Data Cleared")
		Vendorables.dataObject.text = "No Data"
		
	elseif arg == "output" then
		Vendorables:Print("Current Results On File:")
		for key, entry in pairs(Vendorables.AuctionData) do
			local m
			if entry['creates'] ~= nil then
				m = entry['method']..entry['creates']
			else
				m = entry['method']
			end
			Vendorables:Print(entry['type'].." "..entry["total"].."x"..entry["link"].."  Lowest:"..Vendorables:CopperToString(entry['low']).."    "..m.."    Profit: "..Vendorables:CopperToString(entry['profit']))
		end
		Vendorables:Print("End of Results")
	end

end


function Vendorables:OnInitialize()
	Vendorables.db = LibStub("AceDB-3.0"):New("VendorablesDB", defaults)
	Vendorables:RegisterEvent('AUCTION_ITEM_LIST_UPDATE')
end

function Vendorables:ShowToolTip(frame)
	if (InCombatLockdown()) then return end

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

function Vendorables:AUCTION_ITEM_LIST_UPDATE()
	
	local hitCount = 0;
    local _,MaxAuctions = GetNumAuctionItems("list")
	
	Vendorables.LastRowCount = MaxAuctions
	
    for tableloop=1,MaxAuctions do
		local name, texture, count, quality, canUse, level, minBid, minIncrement, buyoutPrice, bidAmount, highestBidder, owner, sold = GetAuctionItemInfo("list",tableloop)
		
		if name ~= nil and owner ~= nil then
			local duration = GetAuctionItemTimeLeft("list", tableloop)
			local link = GetAuctionItemLink("list", tableloop)
			
		--	if (buyoutPrice ~= nil) then
				local uniq = strjoin('', name, count, minBid, buyoutPrice, owner, duration)
		--	else
		--		local uniq = strjoin('', name, count, minBid, owner, duration)
		--	end
			 
			
			if (link) then
				local linkType, itemID, _,_,_,_,_,suffixId, uniqueId = strsplit(":", link)
				local uniq = strjoin('', itemID, count, buyoutPrice, owner, duration)

				
				local boPrice = math.floor(buyoutPrice/count)
				
				if (buyoutPrice>0 and Vendorables.AuctionHistory[uniq]==nil) then
					Vendorables.AuctionHistory[uniq] = true
					local method, creates, profit = Vendorables:CheckPrice(itemID, buyoutPrice)
					
					if method ~= nil and profit~=nil and profit > Vendorables.db.profile.threshold then
				
						local key = method..":"..itemID
						if (Vendorables.AuctionData[key] == nil) then
							Vendorables.AuctionData[key] = {method=method, type="Buyout", link=link, low=boPrice, count=count, total=count, profit=profit, creates=creates}
						else
							if Vendorables.AuctionData[key]["low"] > boPrice then
								Vendorables.AuctionData[key]["low"] = boPrice
								Vendorables.AuctionData[key]["count"] = count
							elseif Vendorables.AuctionData[key]["low"] == boPrice then
								Vendorables.AuctionData[key]["count"] = Vendorables.AuctionData[key]["count"] + count
							end
							Vendorables.AuctionData[key]["total"] = Vendorables.AuctionData[key]["total"] + count
						end
						
						hitCount = hitCount + 1
						Vendorables.TotalResults = Vendorables.TotalResults + 1
					end
				end
			end
        end
    end

	if Vendorables.FullScan then
		Vendorables.FullScan = false
		Vendorables:Print("Scan complete, found "..#Vendorables.AuctionData.." undervalued items")
	elseif hitCount>0 then
		Vendorables:Print("Found "..hitCount.." new items")
	end
	
	Vendorables.dataObject.text = (Vendorables.TotalResults).." Items"
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

function Vendorables:CopperToString(c)
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