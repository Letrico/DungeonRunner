local dungeons = {
    DGN_Frac_DeadMansDredge = {
        quest_id = 586309,
        objectives = {
            "animus",
            "prisoners"
        },
        explorer = {
            max_target_distance = 25,
            target_distance_states = {20, 15, 10, 5},
            check_radius = 10,
            exploration_radius = 4
        },
        blocker = {
            name = "DRLGKit_fxKit_harmless_barrierWall_blood_01"
        }
    },
    DGN_Scos_SaratsLair = {
        quest_id = 433938,
        objectives = {
            "kill",
            "boss_sphere"
        },
        kill = {
            name = "DRLG_Structure_Spider_Cocoon",
            count = 3
        },
        boss_sphere = {
            name = "spider_adult_miniboss_unique_DGN_SaratsLair"
        },
        explorer = {
            max_target_distance = 25,
            target_distance_states = {20, 15, 10, 5},
            check_radius = 10,
            exploration_radius = 4
        }
    },
    DGN_Hawe_MaugansWorks = {
        quest_id = 702108,
        objectives = {
            "prisoners_key",
            "unlock_door",
            "boss_room"
        },
        prisoners_key = {
            name = "Global_Flippy_Items_RustedIronKeys_01_Item"
        },
        unlock_door = {
            name = "DRLG_Blocker_Protodun_Keep_DGN_Hawe_MaugansWorks"
        },
        boss_room = {
            name = "Trigger_BossRoom_Entrance"
        },
        boss = {
            name = "council_miniboss"
        },
        boss_room_direction = {
            x = -23,
            y = -23,
            z = 0,
        },
        blocker = {
            name = "DRLG_Blocker_Protodun_Keep_DGN_Hawe_MaugansWorks"
        },
        explorer = {
            max_target_distance = 20,
            target_distance_states = {30, 25, 15, 5},
            check_radius = 10,
            exploration_radius = 6
        },
    },
    DGN_Kehj_SiroccoCaverns = {
        quest_id = 731250,
        objectives = {
            "kill",
            "kill_spider_callers"
        },
        kill = {
            name = "DRLG_Structure_Spider_Cocoon",
            count = 3
        },
        kill_spider_callers = {
            name = "fallen_shaman_fire_unique_DGN_Kehj_SiroccoCaverns",
            count = 2
        },
        explorer = {
            max_target_distance = 25,
            target_distance_states = {20, 15, 10, 5},
            check_radius = 10,
            exploration_radius = 4
        },
        blocker = {
            name = "DRLGKit_fxKit_harmless_barrierWall_blood_01"
        }
    }
}

return dungeons