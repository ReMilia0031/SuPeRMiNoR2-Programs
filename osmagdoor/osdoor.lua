local component = require("component")
local event = require("event")
local os = require("os")
local serialization = require("serialization")
local filesystem = require("filesystem")
local keyboard = require("keyboard")
local string = require("string")
local math = require("math")
local term = require("term")
local superlib = require("superlib")
local osmag = require("osmag")

dbfile = "/authdb.dat"
logfile = "/authlog.txt"

writer = component.os_cardwriter

local function log(logdata)
    f = io.open(logfile, "a")
    f:write(logdata.."\n")
    f:close()
end

local function checkCard(UUID)
    db = osmag.loadDB()
    for i in ipairs(db["registered"]) do
        if db["registered"][i]["uuid"] == UUID then
            return true, db["registered"]["username"]
        end
    end
    return false
end

local function getUser(msg)
    io.write(msg)
    return io.read()
end

local function registerCard()
    db = osmag.loadDB()
    term.clear()
    superlib.clearMenu()
    superlib.addItem("Full Access Card", "full")
    superlib.addItem("Temporary Card", "temp")
    superlib.addItem("Cancel", "c")
    choice = superlib.runMenu("Select new card type")
    if choice ~= "c" then
        cardcode = osmag.makeCode()
        carddata = {code=cardcode}
        term.clear()
        title = getUser("Enter the title for the card: ")
        if choice == "full" then
            carddata["type"] = "full"
        elseif choice == "temp" then
            carddata["type"] = "temp"
            ctime = os.time()
            days = getUser("Enter the amount of minecraft days you want the card to last: ")
            days = tonumber(days)
            extratime = days * 86400
            expiretime = ctime + extratime
            carddata["expire"] = expiretime
        end

        cardstring = serialization.serialize(carddata)
        writer.write(cardstring, title, true)
        table.insert(db["new"], {code=cardcode, title=title, type=carddata["type"], expire=expiretime})
        print("The card will be registered to the user who swipes it next.")
        osmag.saveDB(db)
        os.sleep(1)
    end
end

local function registerDoor()
    ddb = osmag.loadDB()
    freeDoors = {}
    freeMags = {}

    for address, ctype in component.list() do
        if ctype == "os_door" then
            reg = false
            for raddr in ipairs(ddb["pairs"]) do
                if address == ddb["pairs"][raddr]["door"] then
                    reg = true
                end
            end
            if not reg then 
                table.insert(freeDoors, address) 
            end
        end

        if ctype == "os_magreader" then
            reg = false
            for raddr in ipairs(ddb["pairs"]) do
                if address == ddb["pairs"][raddr]["mag"] then
                    reg = true
                end
            end
            if not reg then 
                table.insert(freeMags, address) 
            end
        end
    end

    superlib.clearMenu()
    for i, d in ipairs(freeDoors) do
        superlib.addItem("Door: "..d, d)
    end
    superlib.addItem("Cancel", "c")
    door = superlib.runMenu("Please select the door uuid you want to add.")

    if door ~= "c" then
        superlib.clearMenu()
        for i, d in ipairs(freeMags) do
            superlib.addItem("Reader: "..d, d)
        end
        superlib.addItem("Cancel", "c")
        mag = superlib.runMenu("Please select the mag reader uuid you want to pair to the door.")

        if mag ~= "c" then
            term.clear()
            name = getUser("Enter a name for this pair: ")
            print("Generating door password.")
            newpass = osmag.makeCode()
            doorc = component.proxy(door)
            print("Setting door password.")
            success, msg = doorc.setPassword(newpass)
            if msg == nil then
                msg = success
            end
            if msg == "Password set" then
                print("Door password set successfully.")
                table.insert(ddb["pairs"], {door=door, mag=mag, name=name, password=newpass})
                osmag.saveDB(ddb)
                os.sleep(1)
            else
                print("Failed to set door password, please break the door[s] and replace them to clear the password.")
                os.sleep(2)
            end
        end
    end
end

local function removeDoor()
    ldb = osmag.loadDB()
    superlib.clearMenu()
    superlib.addItem("Cancel", "c")
    for i, d in ipairs(ldb["pairs"]) do
        superlib.addItem(d["name"], i)
    end
    door = superlib.runMenu("Please select the door you want to remove.")
    if door ~= "c" then
        doorinfo = ldb["pairs"][door]
        m.tryToDeleteDoor(doorinfo["address"], doorinfo["password"])
        table.remove(ldb["pairs"], door)
    end
    osmag.saveDB(ldb)
end

local function removeCard()
    ldb = osmag.loadDB()
    superlib.clearMenu()
    superlib.addItem("Cancel", "c")
    for i, d in ipairs(ldb["registered"]) do
        superlib.addItem(d["title"] .. " (" ..d["username"] .. ", " .. d["uuid"]..")", i)
    end
    card = superlib.runMenu("Please select the card you want to remove.")
    if card ~= "c" then
        table.remove(ldb["registered"], card)
    end
    osmag.saveDB(ldb)
end

local function clearCards()
    ldb = osmag.loadDB()
    term.clear()
    print("Clearing all unregistered cards...")
    for c, d in pairs(ldb["new"]) do
        print("Removing card: "..d["title"])
        table.remove(ldb["new"], c)
    end
    osmag.saveDB(ldb)
    os.sleep(1)
end

local function menus() 
    superlib.clearMenu()
    superlib.addItem("Exit", "e")
    superlib.addItem("Register a card", "r")
    superlib.addItem("Register a door", "d")
    superlib.addItem("Remove a door", "rd")
    superlib.addItem("Remove a card", "rc")
    superlib.addItem("Clear waiting cards", "cc")
    key = superlib.runMenu("Super Security System [Beta]")

    if key == "r" then
        registerCard()
    elseif key == "d" then
        registerDoor()
    elseif key == "rd" then
        removeDoor()
    elseif key == "rc" then
        removeCard()
    elseif key == "cc" then
        clearCards()
    elseif key == "e" then
        return "exit"
    end
end

function main()
    term.clear()
    while true do
        r = menus()
        if r == "exit" then
            term.clear()
            break
        end
    end
end
main()
