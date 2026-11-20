-- Format: turns raw numbers into short, readable strings for the HUD and the BillboardGuis
-- ($1.2K, $3.4M/s, 12s). Shared by server and client so both show the same text.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }

function Format.cash(amount: number): string
	local n = math.max(0, amount)
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return "$" .. tostring(math.floor(n))
	end
	local text
	if n >= 100 then
		text = tostring(math.floor(n))
	else
		text = string.format("%.1f", math.floor(n * 10) / 10)
	end
	return "$" .. text .. SUFFIXES[i]
end

function Format.perSecond(amount: number): string
	return Format.cash(amount) .. "/s"
end

function Format.seconds(seconds: number): string
	return tostring(math.max(0, math.ceil(seconds))) .. "s"
end

return Format
