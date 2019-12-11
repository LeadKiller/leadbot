util.AddNetworkString("botLeadBot.VoicePresetStart")

LeadBot.VoicePreset = {}
LeadBot.VoicePreset["css"] = {}
LeadBot.VoicePreset["css"]["join"] = {"bot/its_a_party.wav", "bot/oh_boy2.wav", "bot/whoo.wav"}
LeadBot.VoicePreset["css"]["taunt"] = {"bot/do_not_mess_with_me.wav", "bot/i_am_dangerous.wav", "bot/i_am_on_fire.wav", "bot/i_wasnt_worried_for_a_minute.wav", "bot/nice2.wav", "bot/owned.wav", "bot/made_him_cry.wav", "bot/they_never_knew_what_hit_them.wav", "bot/who_wants_some_more.wav", "bot/whos_the_man.wav", "bot/yea_baby.wav", "bot/wasted_him.wav"}
LeadBot.VoicePreset["css"]["help"] = {"bot/help.wav", "bot/i_could_use_some_help.wav", "bot/i_could_use_some_help_over_here.wav", "bot/im_in_trouble.wav", "bot/need_help.wav", "bot/need_help2.wav", "bot/the_actions_hot_here.wav"}
LeadBot.VoicePreset["css"]["downed"] = LeadBot.VoicePreset["css"]["help"]

LeadBot.VoicePreset["female"] = {}
LeadBot.VoicePreset["female"]["join"] = {"vo/npc/female01/hi01.wav"}
LeadBot.VoicePreset["female"]["taunt"] = {"vo/coast/odessa/female01/nlo_cheer03.wav", "vo/npc/female01/gotone02.wav", "vo/npc/female01/likethat.wav", "vo/npc/female01/nice01.wav", "vo/npc/female01/question17.wav", "vo/npc/female01/yeah02.wav"}

LeadBot.VoicePreset["male"] = {}
LeadBot.VoicePreset["male"]["join"] = {"vo/npc/male01/hi01.wav"}
LeadBot.VoicePreset["male"]["taunt"] = {"vo/coast/odessa/male01/nlo_cheer03.wav", "vo/npc/male01/gotone02.wav", "vo/npc/male01/likethat.wav", "vo/npc/male01/nice01.wav", "vo/npc/male01/question17.wav", "vo/npc/male01/yeah02.wav"}

LeadBot.VoicePreset["nick"] = {}
LeadBot.VoicePreset["nick"]["join"] = {"player/survivor/voice/gambler/worldc5m5b04.wav", "player/survivor/voice/gambler/worldc5m5b04.wav", "player/survivor/voice/gambler/worldc5m505.wav"}
LeadBot.VoicePreset["nick"]["wallbuy"] = {"player/survivor/LeadBot.VoicePreset/gambler/takemelee01.wav", "player/survivor/LeadBot.VoicePreset/gambler/takemelee05.wav", "player/survivor/LeadBot.VoicePreset/gambler/takemelee03.wav", "player/survivor/LeadBot.VoicePreset/gambler/takemelee06.wav", "player/survivor/LeadBot.VoicePreset/gambler/takefirstaid02.wav", "player/survivor/LeadBot.VoicePreset/gambler/takefirstaid01.wav"}
LeadBot.VoicePreset["nick"]["taunt"] = {"player/survivor/LeadBot.VoicePreset/gambler/taunt01.wav", "player/survivor/LeadBot.VoicePreset/gambler/taunt02.wav", "player/survivor/LeadBot.VoicePreset/gambler/taunt03.wav", "player/survivor/LeadBot.VoicePreset/gambler/taunt04.wav", "player/survivor/LeadBot.VoicePreset/gambler/taunt05.wav", "player/survivor/LeadBot.VoicePreset/gambler/taunt06.wav", "player/survivor/LeadBot.VoicePreset/gambler/taunt07.wav", "player/survivor/LeadBot.VoicePreset/gambler/taunt08.wav", "player/survivor/LeadBot.VoicePreset/gambler/taunt09.wav", }
LeadBot.VoicePreset["nick"]["help"] = {"player/survivor/LeadBot.VoicePreset/gambler/help01.wav", "player/survivor/LeadBot.VoicePreset/gambler/help02.wav", "player/survivor/LeadBot.VoicePreset/gambler/help03.wav", "player/survivor/LeadBot.VoicePreset/gambler/help04.wav", "player/survivor/LeadBot.VoicePreset/gambler/help05.wav"}
LeadBot.VoicePreset["nick"]["downed"] = {"player/survivor/LeadBot.VoicePreset/gambler/ledgehangmiddle02.wav", "player/survivor/LeadBot.VoicePreset/gambler/ledgehangmiddle03.wav", "player/survivor/LeadBot.VoicePreset/gambler/ledgehangmiddle04.wav", "player/survivor/LeadBot.VoicePreset/gambler/ledgehangstart03.wav", "player/survivor/LeadBot.VoicePreset/gambler/ledgehangstart04.wav", "player/survivor/LeadBot.VoicePreset/gambler/ledgehangstart01.wav"}

-- TODO: rest of survivors

local convar = CreateConVar("leadbot_voice", "css", {FCVAR_ARCHIVE}, "Voice Preset.\nOptions are: \n- \"" .. table.concat(table.GetKeys(LeadBot.VoicePreset), "\"\n- \"") .. "\"")

function LeadBot.TalkToMe(ply, type)
    if !ply:IsBot() then return end

    local hear = {}
    local sound = ""
    local selectedvoice = "css"

    if LeadBot.VoicePreset[convar:GetString()] then
        selectedvoice = convar:GetString()
    end

    for k, v in pairs(player.GetAll()) do
        if hook.Call("PlayerCanHearPlayersLeadBot.VoicePreset", gmod.GetGamemode(), v, ply) then
            table.insert(hear, v)
        end
    end

    if type and LeadBot.VoicePreset[selectedvoice][type] then
        sound = table.Random(LeadBot.VoicePreset[selectedvoice][type])
    end

    net.Start("botLeadBot.VoicePresetStart")
        net.WriteEntity(ply)
        net.WriteString(sound)
    net.Send(hear)
end