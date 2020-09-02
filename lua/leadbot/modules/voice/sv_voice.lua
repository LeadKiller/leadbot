util.AddNetworkString("botVoiceStart")

LeadBot.VoicePreset = {}
LeadBot.VoiceModels = {}

local convar = CreateConVar("leadbot_voice", "random", {FCVAR_ARCHIVE}, "Voice Preset.\nOptions are: \n- \"random\"\n- \"" .. table.concat(table.GetKeys(LeadBot.VoicePreset), "\"\n- \"") .. "\"")

function LeadBot.TalkToMe(ply, type)
    if !ply:IsLBot(true) then return end

    local hear = {}
    local sound = ""
    local selectedvoice = "metropolice"
    local voice = convar:GetString()

    if voice == "random" then
        if !ply.LeadBot_Voice then
            local model = ply:Nick()
            if LeadBot.VoiceModels[model] then
                ply.LeadBot_Voice = LeadBot.VoiceModels[model]
            else
                local _, selectedplyvoice = table.Random(LeadBot.VoicePreset)
                ply.LeadBot_Voice = selectedplyvoice
            end
        end

        if !LeadBot.VoicePreset[ply.LeadBot_Voice] then
            ply.LeadBot_Voice = "metropolice"
        end

        selectedvoice = ply.LeadBot_Voice
    elseif LeadBot.VoicePreset[voice] then
        selectedvoice = voice
    end

    for k, v in pairs(player.GetAll()) do
        if hook.Call("PlayerCanHearPlayersVoice", gmod.GetGamemode(), v, ply) then
            table.insert(hear, v)
        end
    end

    if type and LeadBot.VoicePreset[selectedvoice][type] then
        sound = table.Random(LeadBot.VoicePreset[selectedvoice][type])
    end

    net.Start("botVoiceStart")
        net.WriteEntity(ply)
        net.WriteString(sound)
    net.Send(hear)
end

-- Valve Games

if IsMounted("cstrike") then
    LeadBot.VoicePreset["css"] = {}
    LeadBot.VoicePreset["css"]["join"] = {"bot/its_a_party.wav", "bot/oh_boy2.wav", "bot/whoo.wav"}
    LeadBot.VoicePreset["css"]["taunt"] = {"bot/do_not_mess_with_me.wav", "bot/i_am_dangerous.wav", "bot/i_am_on_fire.wav", "bot/i_wasnt_worried_for_a_minute.wav", "bot/nice2.wav", "bot/owned.wav", "bot/made_him_cry.wav", "bot/they_never_knew_what_hit_them.wav", "bot/who_wants_some_more.wav", "bot/whos_the_man.wav", "bot/yea_baby.wav", "bot/wasted_him.wav"}
    LeadBot.VoicePreset["css"]["help"] = {"bot/help.wav", "bot/i_could_use_some_help.wav", "bot/i_could_use_some_help_over_here.wav", "bot/im_in_trouble.wav", "bot/need_help.wav", "bot/need_help2.wav", "bot/the_actions_hot_here.wav"}
    LeadBot.VoicePreset["css"]["downed"] = LeadBot.VoicePreset["css"]["help"]
end

-- Citizens

LeadBot.VoicePreset["male"] = {}
LeadBot.VoicePreset["male"]["join"] = {"vo/npc/male01/hi01.wav", "vo/npc/male01/hi02.wav", "vo/npc/male01/yeah02.wav", "vo/npc/male01/squad_reinforce_single04.wav", "vo/npc/male01/squad_affirm06.wav", "vo/npc/male01/readywhenyouare01.wav", "vo/npc/male01/okimready03.wav", "vo/npc/male01/letsgo02.wav"}
LeadBot.VoicePreset["male"]["taunt"] = {"vo/coast/odessa/male01/nlo_cheer03.wav", "vo/npc/male01/gotone02.wav", "vo/npc/male01/likethat.wav", "vo/npc/male01/nice01.wav", "vo/npc/male01/question17.wav", "vo/npc/male01/yeah02.wav", "vo/npc/male01/vquestion01.wav"}
LeadBot.VoicePreset["male"]["pain"] = {"vo/npc/male01/help01.wav", "vo/npc/male01/startle01.wav", "vo/npc/male01/startle02.wav", "vo/npc/male01/uhoh.wav"}

LeadBot.VoicePreset["female"] = {}
LeadBot.VoicePreset["female"]["join"] = {"vo/npc/female01/hi01.wav", "vo/npc/female01/hi02.wav", "vo/npc/female01/yeah02.wav", "vo/npc/female01/squad_reinforce_single04.wav", "vo/npc/female01/squad_affirm06.wav", "vo/npc/female01/readywhenyouare01.wav", "vo/npc/female01/okimready03.wav", "vo/npc/female01/letsgo02.wav"}
LeadBot.VoicePreset["female"]["taunt"] = {"vo/coast/odessa/female01/nlo_cheer03.wav", "vo/npc/female01/gotone02.wav", "vo/npc/female01/likethat.wav", "vo/npc/female01/nice01.wav", "vo/npc/female01/question17.wav", "vo/npc/female01/yeah02.wav", "vo/npc/female01/vquestion01.wav"}
LeadBot.VoicePreset["female"]["pain"] = {"vo/npc/female01/help01.wav", "vo/npc/female01/startle01.wav", "vo/npc/female01/startle02.wav", "vo/npc/female01/uhoh.wav"}

-- Main Characters

LeadBot.VoicePreset["alyx"] = {}
LeadBot.VoicePreset["alyx"]["join"] = {"vo/npc/alyx/al_excuse03.wav", "vo/npc/alyx/getback01.wav", "vo/npc/alyx/lookout01.wav", "vo/npc/alyx/getback02.wav"}
LeadBot.VoicePreset["alyx"]["taunt"] = {"vo/npc/alyx/al_excuse03.wav", "vo/npc/alyx/lookout01.wav", "vo/npc/alyx/lookout03.wav", "vo/npc/alyx/brutal02.wav", "vo/npc/alyx/youreload02.wav"}
LeadBot.VoicePreset["alyx"]["pain"] = {"vo/npc/alyx/gasp03.wav", "vo/npc/alyx/ohgod01.wav", "vo/npc/alyx/ohno_startle01.wav"}

LeadBot.VoicePreset["barney"] = {}
LeadBot.VoicePreset["barney"]["join"] = {"vo/npc/barney/ba_ohyeah.wav", "vo/npc/barney/ba_yell.wav", "vo/npc/barney/ba_bringiton.wav"}
LeadBot.VoicePreset["barney"]["taunt"] = {"vo/npc/barney/ba_downyougo.wav", "vo/npc/barney/ba_losttouch.wav", "vo/npc/barney/ba_yell.wav", "vo/npc/barney/ba_getaway.wav"}
LeadBot.VoicePreset["barney"]["help"] = {"vo/npc/barney/ba_no01.wav", "vo/npc/barney/ba_no02.wav", "vo/npc/barney/ba_damnit.wav"}

LeadBot.VoicePreset["grigori"] = {}
LeadBot.VoicePreset["grigori"]["join"] = {"vo/ravenholm/monk_death07.wav", "vo/ravenholm/exit_nag02.wav", "vo/ravenholm/engage04.wav", "vo/ravenholm/engage05.wav", "vo/ravenholm/engage06.wav", "vo/ravenholm/engage07.wav", "vo/ravenholm/engage08.wav", "vo/ravenholm/engage09.wav"}
LeadBot.VoicePreset["grigori"]["taunt"] = {"vo/ravenholm/madlaugh01.wav", "vo/ravenholm/madlaugh02.wav", "vo/ravenholm/madlaugh03.wav", "vo/ravenholm/madlaugh04.wav", "vo/ravenholm/monk_kill01.wav", "vo/ravenholm/monk_kill02.wav", "vo/ravenholm/monk_kill03.wav", "vo/ravenholm/monk_kill04.wav", "vo/ravenholm/monk_kill05.wav", "vo/ravenholm/monk_kill06.wav", "vo/ravenholm/monk_kill07.wav", "vo/ravenholm/monk_kill08.wav", "vo/ravenholm/monk_kill09.wav", "vo/ravenholm/firetrap_vigil.wav"}
LeadBot.VoicePreset["grigori"]["pain"] = {"vo/ravenholm/monk_pain12.wav", "vo/ravenholm/monk_rant13.wav", "vo/ravenholm/monk_pain06.wav", "vo/ravenholm/engage08.wav"}

-- Enemies

LeadBot.VoicePreset["metropolice"] = {}
LeadBot.VoicePreset["metropolice"]["join"] = {"npc/metropolice/vo/lookingfortrouble.wav", "npc/metropolice/vo/pickupthecan1.wav", "npc/metropolice/vo/youwantamalcomplianceverdict.wav", "npc/metropolice/vo/unitisonduty10-8.wav", "npc/metropolice/vo/unitis10-8standingby.wav", "npc/metropolice/vo/readytoamputate.wav", "npc/metropolice/vo/prepareforjudgement.wav", "npc/metropolice/vo/readytoprosecutefinalwarning.wav"}
LeadBot.VoicePreset["metropolice"]["taunt"] = {"npc/metropolice/vo/finalverdictadministered.wav", "npc/metropolice/vo/firstwarningmove.wav", "npc/metropolice/vo/isaidmovealong.wav", "npc/metropolice/vo/nowgetoutofhere.wav", "npc/metropolice/vo/pickupthecan2.wav", "npc/metropolice/vo/pickupthecan3.wav", "npc/metropolice/vo/putitinthetrash1.wav", "npc/metropolice/vo/putitinthetrash2.wav", "npc/metropolice/vo/suspectisbleeding.wav", "npc/metropolice/vo/thisisyoursecondwarning.wav"}
LeadBot.VoicePreset["metropolice"]["pain"] = {"npc/metropolice/vo/11-99officerneedsassistance.wav", "npc/metropolice/vo/wehavea10-108.wav", "npc/metropolice/vo/runninglowonverdicts.wav", "npc/metropolice/pain4.wav"}

-- Player Config

LeadBot.VoiceModels["Alyx Vance"] = "alyx"
LeadBot.VoiceModels["Isaac Kleiner"] = "male"
LeadBot.VoiceModels["Dr. Wallace Breen"] = "male"
LeadBot.VoiceModels["The G-Man"] = "male"
LeadBot.VoiceModels["Odessa Cubbage"] = "male"
LeadBot.VoiceModels["Eli Vance"] = "male"
LeadBot.VoiceModels["Father Grigori"] = "grigori"
LeadBot.VoiceModels["Judith Mossman"] = "female"
LeadBot.VoiceModels["Barney Calhoun"] = "barney"

LeadBot.VoiceModels["Magnusson"] = "male"

LeadBot.VoiceModels["American Soldier"] = "male"
LeadBot.VoiceModels["German Soldier"] = "male"

LeadBot.VoiceModels["GIGN"] = "css"
LeadBot.VoiceModels["Elite Crew"] = "css"
LeadBot.VoiceModels["Artic Avengers"] = "css"
LeadBot.VoiceModels["SEAL Team Six"] = "css"
LeadBot.VoiceModels["GSG-9"] = "css"
LeadBot.VoiceModels["SAS"] = "css"
LeadBot.VoiceModels["Phoenix Connexion"] = "css"
LeadBot.VoiceModels["Guerilla Warfare"] = "css"
LeadBot.VoiceModels["Cohrt"] = "male"

LeadBot.VoiceModels["Chell"] = "female"

LeadBot.VoiceModels["Civil Protection"] = "metropolice"
LeadBot.VoiceModels["Combine Soldier"] = "metropolice"
LeadBot.VoiceModels["Combine Prison Guard"] = "metropolice"
LeadBot.VoiceModels["Elite Combine Soldier"] = "metropolice"
LeadBot.VoiceModels["Stripped Combine Soldier"] = "metropolice"

LeadBot.VoiceModels["Zombie"] = "css"
LeadBot.VoiceModels["Fast Zombie"] = "css"
LeadBot.VoiceModels["Zombine"] = "css"
LeadBot.VoiceModels["Corpse"] = "css"
LeadBot.VoiceModels["Charple"] = "css"
LeadBot.VoiceModels["Skeleton"] = "css"

LeadBot.VoiceModels["Van"] = "male"
LeadBot.VoiceModels["Ted"] = "male"
LeadBot.VoiceModels["Joe"] = "male"
LeadBot.VoiceModels["Eric"] = "male"
LeadBot.VoiceModels["Art"] = "male"
LeadBot.VoiceModels["Sandro"] = "male"
LeadBot.VoiceModels["Mike"] = "male"
LeadBot.VoiceModels["Vance"] = "male"
LeadBot.VoiceModels["Erdin"] = "male"
LeadBot.VoiceModels["Van"] = "male"
LeadBot.VoiceModels["Ted"] = "male"
LeadBot.VoiceModels["Joe"] = "male"
LeadBot.VoiceModels["Eric"] = "male"
LeadBot.VoiceModels["Art"] = "male"
LeadBot.VoiceModels["Sandro"] = "male"
LeadBot.VoiceModels["Mike"] = "male"
LeadBot.VoiceModels["Vance"] = "male"
LeadBot.VoiceModels["Erdin"] = "male"
LeadBot.VoiceModels["Joey"] = "female"
LeadBot.VoiceModels["Kanisha"] = "female"
LeadBot.VoiceModels["Kim"] = "female"
LeadBot.VoiceModels["Chau"] = "female"
LeadBot.VoiceModels["Naomi"] = "female"
LeadBot.VoiceModels["Lakeetra"] = "female"
LeadBot.VoiceModels["Joey"] = "female"
LeadBot.VoiceModels["Kanisha"] = "female"
LeadBot.VoiceModels["Kim"] = "female"
LeadBot.VoiceModels["Chau"] = "female"
LeadBot.VoiceModels["Naomi"] = "female"
LeadBot.VoiceModels["Lakeetra"] = "female"