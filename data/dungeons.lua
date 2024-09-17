local dungeons = {
    DGN_Frac_DeadMansDredge = {
        quest_id = 586309,
        objectives = {
            "animus",
            "prisoners"
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
        }
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
        }
    }
}

return dungeons