-- Remotes: creates ReplicatedStorage.Remotes, the only doors between client and server.
--   Notify    (server -> client)  banner text for one player or everyone
--   CashPopup (server -> client)  a "+$123" popup after collecting the vault
--   Combat    (server -> client)  attacker model, from, to, damage, color: lunge + projectile + damage number
--   Bonk      (server -> client)  weapon hit effect: position, color, word, hitter, flags { smoke, milk, crit, boss }
--   Fling     (server -> client)  a farm disaster caught you: velocity to throw your character with, kind
--   FuseMenu  (server -> client)  opens / refreshes the Barn Fuse Machine panel with the player's fusable groups
--   Request   (client -> server)  "Upgrade" <key> | "Rebirth" | "Lock" | "BuyWeapon" <id> | "FuseMenu"
--                                 | "Fuse" <brainrotId> <mutation> - always re-checked on the server

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function remoteEvent(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

Remotes.Notify = remoteEvent("Notify")
Remotes.CashPopup = remoteEvent("CashPopup")
Remotes.Combat = remoteEvent("Combat")
Remotes.Request = remoteEvent("Request")
Remotes.Bonk = remoteEvent("Bonk")
Remotes.FuseMenu = remoteEvent("FuseMenu")
Remotes.Fling = remoteEvent("Fling")
folder.Parent = ReplicatedStorage

local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)

function Remotes.notify(player: Player, text: string, color: Color3?)
	Remotes.Notify:FireClient(player, text, color or DEFAULT_COLOR)
end

function Remotes.announce(text: string, color: Color3?)
	Remotes.Notify:FireAllClients(text, color or DEFAULT_COLOR)
end

return Remotes
