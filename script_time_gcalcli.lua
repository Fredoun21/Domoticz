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
minutes = tonumber(os.date('%M', time))
hours = tonumber(os.date('%H', time))
jour = os.date('%d', time)

--Nombre de minutes depuis 00:00
maintenant = tonumber(hours * 60 + minutes)

--idx et nom du capteur Text
idxText = '29'
nomText = "Info Script"

--nom de l'agenda google
domoticz_cal = "domoticz"

--fichier et chemin pour agenda
repertoire = "/home/domoticz/domoticz/"
file = "googlecal.txt"

--table contenant la liste des dispositifs radiateur
radiateur = { "Cuisine", "Auxence", "Maximilien", "Romeo", "SDB" }
--Validation du nom du radiateur dans le calendrier // aux radiateurs de Domoticz
RadOK = false

--Consigne de temperature
vTemperature = tonumber(otherdevices_temperature[("Garage Temp")])
vConsigne    = tonumber(otherdevices_svalues["Thermostat"])

print("")
print("######## DEBUT ########")
print("")

print(string.format("T° extérieure: %.1f", vTemperature))
print(string.format("Consigne thermostat: %.1f", vConsigne))

-- Toutes les 5 minutes, on récupère l'agenda de la journée
if (maintenant % 5 == 0) then

	--on efface info script
	commandArray['UpdateDevice'] = idxText .. "|0| "

	--if(true)then
	options = "--tsv --military"
	--	options="--tsv --military --noauth_local_webserver"
	agenda_start = "00:00"
	agenda_end = "23:59"

	--	lignecde="export LANG=\"fr_FR.UTF-8\" && sudo gcalcli --cal="..domoticz_cal.." agenda ".."'"..agenda_start.."' '"..agenda_end.."' "..options
	--	lignecde="sudo gcalcli list"
	lignecde = "sudo gcalcli --cal=" .. domoticz_cal .. " agenda " .. "'" .. agenda_start ..
		"' '" .. agenda_end .. "' " .. options
	lignecde = lignecde .. " > " .. repertoire .. file
	--print("02 "..lignecde) --debug
	os.execute(lignecde)

	local file = io.open(repertoire .. file, "r") -- Ouvre le fichier en mode lecture
	local ligne = {} -- Table pour les lignes du fichier

	if (file ~= nil) then
		--le fichier n'est pas vide
		for line in file:lines() do -- Pour chaque lignes
			-- print("01 line: "..line)
			table.insert(ligne, line) -- On insère les lignes dans la table
		end
	end

	-- Affiche les rdv google du jours
	print("RDV Google du jour")
	for i, v in ipairs(ligne) do
		print("\t" .. i .. " Ligne: " .. v)
	end
	--print("\n")

	for i, v in ipairs(ligne) do
		-- Lecture de la table des RDV
		dateDebut, heureDebut, minutesDebut, dateFin, heureFin, minutesFin, action = v:match("([^;]+)\t([^;]+):([^;]+)\t([^;]+)\t([^;]+):([^;]+)\t([^;]+)")
		-- print("000 Date: "..dateDebut.." Heure: "..heureDebut..":"..minutesDebut.." Action: "..action) --debug
		action = action:gsub(" = ", "=")
		debutAction = heureDebut * 60 + minutesDebut
		finAction = heureFin * 60 + minutesFin
		anneeAction, moisAction, jourAction = dateDebut:match("([^;]+)-([^;]+)-([^;]+)")

		if (action:find("Radiateur") ~= nil and jourAction == jour) then
			--L'action contient "Radiateur", c'est un radiateur à actionner en mode CONFORT
			--print("05 ".."Action : "..action) --debug
			if (action:find("=") ~= nil) then
				--Si l'action contient un signe "=" prendre en compte le mode demandé
				interrupteur, etat = action:match("([^;]+)=([^;]+)")
				interrupteur:sub(interrupteur, 11)
				--print("006 "..interrupteur) --debug
				etat:upper()
				--print("007 "..etat) --debug
				--print("008 "..otherdevices[interrupteur]) --debug
				--print("009 ".."Interrupteur: "..interrupteur.." Etat: "..etat.." Device: "..otherdevices[interrupteur])
			else
				-- ne prend que le nom du radiateur
				interrupteur = string.sub(action, 11)
			end

			--l'action ne fini pas aujourd'hui
			if (dateDebut ~= dateFin) then
				finAction = finAction + (24 * 60)
				print("010 fin action: " .. finAction)
			end

			--vérifie que le nom du radiateur dans le calendrier existe dans Domoticz
			RadOK = false
			for i, v in ipairs(radiateur) do
				if (interrupteur == v) then
					RadOK = true
				end
			end

			if RadOK == true then
				-- interrupteur="Radiateur "..interrupteur
				-- print("500 Commande radiateur: "..interrupteur) --debug
			else
				commandArray['UpdateDevice'] = idxText .. "|0|" .. "Radiateur " .. interrupteur .. " introuvable"
				print("501 Radiateur introuvable: " .. interrupteur)
			end

			if RadOK == true then
				--L'interrupteur existe, et l'heure actuelle est dans la plage
				if (
					otherdevices[string.format("Radiateur %s", interrupteur)] ~= nil and debutAction <= maintenant and
						maintenant <= finAction) then
					--La T° extérieure est inférieure au thermostat
					if (tonumber(otherdevices_temperature[("Garage Temp")]) <= vConsigne) or interrupteur == "SDB" then
						etat = "CONFORT"
						-- print("502: "..interrupteur)
						-- print("503: "..otherdevices_svalues[string.format("%s T°", interrupteur)])
						-- print(string.format("100 T° de %s: %.1f",interrupteur,otherdevices_svalues[string.format("%s T°", interrupteur)]))
						print("101 " .. interrupteur .. " passe en mode " .. etat ..
							" pendant " .. tostring(finAction - maintenant) .. " minutes")
						commandArray[string.format("Radiateur %s", interrupteur)] = "Set Level 50"
					else
						if interrupteur == "SDB" then
							etat = "HORS GEL"
							print("200 " .. interrupteur .. " passe en mode " .. etat)
							commandArray[string.format("Radiateur %s", interrupteur)] = "Set Level 10"
						else
							etat = "ECO"
							print("201 " .. interrupteur .. " passe en mode " .. etat)
							commandArray[string.format("Radiateur %s", interrupteur)] = "Set Level 20"
							-- print("400 T° piéce OK, " ..
							-- 	interrupteur .. " ne change pas de mode " .. otherdevices[string.format("Radiateur %s", interrupteur)])
						end
					end
				else
					if (debutAction < maintenant) then
						--L'interrupteur n'existe pas, ou l'heure actuelle n'est pas dans la plage ou l'heure de début n'est pas atteinte
						if interrupteur == "SDB" then
							etat = "HORS GEL"
							print("200 " .. interrupteur .. " passe en mode " .. etat)
							commandArray[string.format("Radiateur %s", interrupteur)] = "Set Level 10"
						else
							etat = "ECO"
							print("201 " .. interrupteur .. " passe en mode " .. etat)
							commandArray[string.format("Radiateur %s", interrupteur)] = "Set Level 20"
						end
					else
						--				print("300 "..maintenant.." < " ..debutAction)
						print("300 il est trop tôt " ..
							interrupteur .. " ne change pas de mode " .. otherdevices[string.format("Radiateur %s", interrupteur)])
					end
				end
			end
		end
	end
else
	print("Pas maintenant")
end

print("")
print("######## FIN ########")
print("")

return commandArray
