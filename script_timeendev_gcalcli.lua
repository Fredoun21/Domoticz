---------------------------------
-- Script de lecture de calendrier Google.
-- Actionne un interrupteur ou remplie un capteur virtuel Text
-- Auteur : Aurelien Neutrino
-- Date : 16 décembre 2015
-- Nécessite un capteur virtuel de type Text
-- Il faut suivre la source suivante et s'arrêter à la fin de l'étape 1
-- source :
-- http://easydomoticz.com/agenda-google-et-domoticz-version-2-partie-1/
---------------------------------
print('Script_time_gcalcli.lua') 

commandArray = {}

--Récupère l'heure et la date actuelle
time = os.time()
minutes=tonumber(os.date('%M',time))
hours=tonumber(os.date('%H',time))
jour = os.date('%d',time)

--Nombre de minutes depuis 00:00
maintenant=tonumber(hours*60+minutes)

--idx et nom du capteur Text 
idxText = '29'
nomText="Info Script"

--nom de l'agenda google
domoticz_cal="Domoticz" 

--fichier et chemin pour agenda
repertoire="/home/domoticz/domoticz/"
file="googlecal.txt"

-- Charge le script JSON for Lua
json = assert(loadfile "/home/domoticz/domoticz/scripts/lua/JSON.lua")()  -- For Linux
--   json = (loadfile "D:\\Domoticz\\scripts\\lua\\json.lua")()  -- For Windows

-- Envoi commande à Domoticz la liste des swtich 
local config=assert(io.popen('/usr/bin/curl "http://192.168.1.100:8080/json.htm?type=command&param=getlightswitches"'))
local blocjson = config:read('*all')
config:close()

-- Decodage JSON
local jsonValeur = json:decode(blocjson)

-- Création de la table des noms de radiateurs
radiateur = {}

-- table contenant la liste des dispositifs radiateur
-- radiateur={ "Cuisine", "ESPTest", "MaxAux", "Parent", "Romeo", "SDB"}

--Validation du nom du radiateur dans le calendrier // aux radiateurs de Domoticz
RadOK=false

--Consigne de temperature 
vTemperature	=	tonumber(otherdevices_temperature[("Station météo")])
vConsigne		=	tonumber(otherdevices_svalues["Thermostat"])

print()
print("######## DEBUT ########")
print()


print(string.format("Température: %.1f",vTemperature))
print(string.format("Consigne: %.1f",vConsigne))

-- Toutes les 5 minutes, on récupère l'agenda de la journée
if(maintenant%5==0)then

	-- Parcours et affiche les sections JSON
	for i, s in ipairs(jsonValeur.result) do 
	--	print("Result "..i)
		for j, v in pairs(s) do 
				StrV = tostring(v) -- Converti la valeur de la clef en tring
	--			print("-\t"..j..": "..StrV)	-- Affiche le résultat de décodage JSON
				if (j == "Name") then -- Si c'est la clef "Name"
					StrV = string.lower(StrV)
					StrV = string.sub(StrV,1,9)	-- Je ne recherche que le mot "radiateur"
					if (StrV == "radiateur") then
						table.insert(radiateur, string.sub(tostring(v),10)) -- Ajoute le nom du dimmer dans la table radiateur
					end
				end
		end
	end

	-- Affiche table contenant la liste des dispositifs radiateur
	print("Liste des radiateurs:")
	for i, v in pairs(radiateur) do print(v) end

	--on efface info script
	commandArray['UpdateDevice']=idxText.."|0| "

-- options d'agenda Google
	options = "--tsv --military"	
--	options="--tsv --military --noauth_local_webserver"
	agenda_start = "00:00"
	agenda_end = "23:59"
	 
	lignecde = "export LANG=\"fr_FR.UTF-8\" && sudo gcalcli --cal="..domoticz_cal.." agenda ".."'"..agenda_start.."' '"..agenda_end.."' "..options
--	lignecde="sudo gcalcli list"
	-- résultat dans un fichier texte
	lignecde = lignecde.." > "..repertoire..file 
	os.execute(lignecde)
--	print("02 "..lignecde)


	local file = io.open(repertoire..file, "r") -- Ouvre le fichier en mode lecture
	local ligne = {} -- Table pour les lignes du fichier

	if(file~=nil)then
	--le fichier n'est pas vide
		for line in file:lines() do -- Pour chaque lignes
	--		print("line: "..line)
			table.insert(ligne, line) -- On insère les lignes dans la table
		end
	end

	-- Affiche les rdv google du jours
	print("RDV Google du jour")
	for i, v in ipairs(ligne) do  
		print("\t"..i.." Ligne: "..v)
	end
	print("\n")

	for i, v in ipairs(ligne) do -- Lecture de la table des RDV
		dateDebut,heureDebut,minutesDebut,dateFin,heureFin,minutesFin,action = v:match("([^;]+)\t([^;]+):([^;]+)\t([^;]+)\t([^;]+):([^;]+)\t([^;]+)")
	--	print("Date: "..dateDebut.." Heure: "..heureDebut.." Action: "..action)
		action = action:gsub(" = ","=")
		debutAction = heureDebut*60+minutesDebut
		finAction = heureFin*60+minutesFin
		anneeAction,moisAction,jourAction = dateDebut:match("([^;]+)-([^;]+)-([^;]+)")
		
		if(action:find("Radiateur")~=nil and jourAction == jour)then
		--L'action contient "Radiateur", c'est un radiateur à actionner en mode CONFORT
	--		print("05 ".."Action : "..action)
			if (action:find("=")~=nil) then
			--Si l'action contient un signe "=" prendre en compte le mode demandé
				interrupteur,etat=action:match("([^;]+)=([^;]+)")
	--			interrupteur:sub(interrupteur,11)
				print("07 "..interrupteur)
				etat:upper()
				print("07 "..etat)
				print("08 "..otherdevices[interrupteur])
	--			print("08 ".."Interrupteur: "..interrupteur.." Etat: "..etat.." Device: "..otherdevices[interrupteur])
			else
				-- ne prend que le nom du radiateur
				interrupteur=string.sub(action,11)
				print("09 "..interrupteur)
			end

			--l'action ne fini pas aujourd'hui
			if(dateDebut~=dateFin)then
				finAction=finAction+(24*60)					
				print("10 fin action: "..finAction)
			end		
			
			--vérifie que le nom du radiateur dans le calendrier existe dans Domoticz
			RadOK = false
			for i, v in ipairs(radiateur) do
				if(interrupteur == v) then
					RadOK = true
				end
			end
			
			if RadOK==true then
--				interrupteur="Radiateur "..interrupteur
	--			print("500 Commande radiateur: "..interrupteur)
			else
				commandArray['UpdateDevice']=idxText.."|0|".."Radiateur "..interrupteur.." introuvable"
				print("500 Radiateur introuvable: "..interrupteur)
			end
			
			if RadOK == true then
				--L'interrupteur existe, et l'heure actuelle est dans la plage
				if (otherdevices[string.format("Radiateur %s", interrupteur)] ~= nil and debutAction <= maintenant and maintenant <= finAction) then
					--La T° de la piéce est inférieure à la consigne du thermostat ou c'est la salle de bain
					if (tonumber(otherdevices_svalues[string.format("%s T°", interrupteur)]) <= vConsigne) or interrupteur == "SDB" then
						etat="CONFORT"
						print(string.format("T° de %s: %.1f",interrupteur,otherdevices_svalues[string.format("%s T°", interrupteur)]))
						print("100 "..interrupteur.." passe en mode "..etat.." pendant "..tostring(finAction-maintenant).." minutes")
						commandArray[string.format("Radiateur %s", interrupteur)]="Set Level 50"
					else
						print("400 T° piéce OK, "..interrupteur.." ne change pas de mode "..otherdevices[string.format("Radiateur %s", interrupteur)])
					end
				else
					if (debutAction < maintenant) then 
					--L'interrupteur n'existe pas, ou l'heure actuelle n'est pas dans la plage ou l'heure de début n'est pas atteinte
						etat = "HORS GEL"
						print("200 "..interrupteur.." passe en mode "..etat)
						commandArray[string.format("Radiateur %s", interrupteur)]="Set Level 10"
					else
		--				print("300 "..maintenant.." < " ..debutAction)
						print("300 il est trop tôt "..interrupteur.." ne change pas de mode "..otherdevices[string.format("Radiateur %s", interrupteur)])
					end
				end
			end
		end
	end
else
	print("Pas maintenant")		
end

print()
print("######## FIN ########")
print()

return commandArray