class_name LocalizationService
extends Node

signal language_changed(language: String)

const DEFAULT_LANGUAGE := "en"
const SUPPORTED_LANGUAGES := ["en", "zh_CN"]
const LANGUAGE_NAMES := {
	"en": "English",
	"zh_CN": "中文",
}

const STRINGS := {
	"ui.hp": {"en": "HP", "zh_CN": "生命"},
	"ui.armor": {"en": "Armor", "zh_CN": "护甲"},
	"ui.floor": {"en": "Floor", "zh_CN": "层数"},
	"ui.weapon": {"en": "Weapon", "zh_CN": "武器"},
	"ui.weapon_none": {"en": "none", "zh_CN": "无"},
	"ui.drops": {"en": "Drops", "zh_CN": "掉落"},
	"ui.ready": {"en": "Ready", "zh_CN": "准备就绪"},
	"ui.camp": {"en": "Camp", "zh_CN": "营地"},
	"ui.equipment": {"en": "Equipment", "zh_CN": "装备"},
	"ui.forge": {"en": "Forge", "zh_CN": "锻造"},
	"ui.forge_locked": {"en": "Forge Locked", "zh_CN": "锻造未解锁"},
	"ui.settings": {"en": "Settings", "zh_CN": "设置"},
	"ui.back": {"en": "Back", "zh_CN": "返回"},
	"ui.language": {"en": "Language", "zh_CN": "语言"},
	"ui.next_room": {"en": "Next Room", "zh_CN": "下一房间"},
	"ui.seed": {"en": "Seed: %d", "zh_CN": "种子：%d"},
	"ui.no_run_recorded": {"en": "No run recorded", "zh_CN": "暂无上局记录"},
	"ui.run_ended": {"en": "Run ended", "zh_CN": "本局结束"},
	"ui.boss_defeated": {"en": "Boss defeated", "zh_CN": "Boss 已击败"},
	"interact.press_e": {"en": "Press E - %s", "zh_CN": "按 E - %s"},
	"interact.pick_up": {"en": "Pick Up %s", "zh_CN": "拾取 %s"},
	"interact.pick_up_generic": {"en": "Pick Up", "zh_CN": "拾取"},
	"interact.open_chest": {"en": "Open Chest", "zh_CN": "打开宝箱"},
	"interact.use_forge": {"en": "Use Forge", "zh_CN": "使用锻造台"},
	"interact.enter_next_room": {"en": "Enter Next Room", "zh_CN": "进入下一房间"},
	"interact.use_event": {"en": "Use %s", "zh_CN": "触发 %s"},
	"state.drop": {"en": "Drop", "zh_CN": "掉落"},
	"state.chest": {"en": "Chest", "zh_CN": "宝箱"},
	"state.opened": {"en": "Opened", "zh_CN": "已打开"},
	"state.forge": {"en": "Forge", "zh_CN": "锻造台"},
	"state.event": {"en": "Event", "zh_CN": "事件"},
	"state.resolved": {"en": "Resolved", "zh_CN": "已完成"},
	"run.floor_clear": {"en": "Floor %d clear", "zh_CN": "第 %d 层清理完成"},
	"run.end.run_ended": {"en": "Run Ended", "zh_CN": "本局结束"},
	"run.end.depths_cleared": {"en": "Depths Cleared", "zh_CN": "深层已肃清"},
	"run.end.death_body": {"en": "Your build collapsed in the depths. Start a fresh run and try a different drop path.", "zh_CN": "你的构筑倒在了深处。回到营地，下一局换一条掉落路线再试。"},
	"run.end.complete_body": {"en": "Boss defeated. The current vertical slice is complete.", "zh_CN": "Boss 已击败。当前 10 层垂直切片已通关。"},
	"run.summary.highest": {"en": "Highest Floor: %d   Rooms Cleared: %d", "zh_CN": "最高层数：%d   清理房间：%d"},
	"run.summary.kills": {"en": "Kills: %d   Elites: %d   Mini Boss: %d   Final Boss: %d", "zh_CN": "击杀：%d   精英：%d   小 Boss：%d   最终 Boss：%d"},
	"run.summary.rewards": {"en": "Rewards", "zh_CN": "奖励"},
	"run.summary.seed": {"en": "Seed: %d", "zh_CN": "种子：%d"},
	"run.summary.reward_line": {"en": "Gold +%d   Souls +%d   Talent Points +%d", "zh_CN": "金币 +%d   灵魂 +%d   天赋点 +%d"},
	"camp.title": {"en": "Forgebound Camp", "zh_CN": "铸渊营地"},
	"camp.currency": {"en": "Gold %d   Souls %d   Talent Points %d", "zh_CN": "金币 %d   灵魂 %d   天赋点 %d"},
	"camp.last_run_none": {"en": "Last Run: none", "zh_CN": "上局记录：无"},
	"camp.last_run": {"en": "Last Run: Seed %d, Floor %d, Rooms %d, Gold +%d, Souls +%d, TP +%d", "zh_CN": "上局：种子 %d，第 %d 层，房间 %d，金币 +%d，灵魂 +%d，天赋点 +%d"},
	"camp.talent_title": {"en": "Permanent Talents", "zh_CN": "永久天赋"},
	"camp.talent_button": {"en": "%s  Lv %d/%d\nCost %d TP - %s", "zh_CN": "%s  等级 %d/%d\n消耗 %d 天赋点 - %s"},
	"camp.seed": {"en": "Run Seed", "zh_CN": "本局种子"},
	"camp.seed_placeholder": {"en": "Blank = random", "zh_CN": "留空 = 随机"},
	"camp.random_seed": {"en": "Random", "zh_CN": "随机"},
	"camp.start_run": {"en": "Start Run", "zh_CN": "开始探索"},
	"camp.reset_save": {"en": "Reset Save", "zh_CN": "重置存档"},
	"settings.title": {"en": "Settings", "zh_CN": "设置"},
	"settings.language": {"en": "Language", "zh_CN": "语言"},
	"panel.details": {"en": "Details", "zh_CN": "详情"},
	"panel.close": {"en": "Close", "zh_CN": "关闭"},
	"panel.equip": {"en": "Equip", "zh_CN": "装备"},
	"panel.equip_weapon": {"en": "Equip Weapon", "zh_CN": "装备武器"},
	"panel.pickup_compare": {"en": "Pickup Compare", "zh_CN": "拾取对比"},
	"equipment.current_weapon": {"en": "Weapon: %s", "zh_CN": "武器：%s"},
	"equipment.current_weapon_none": {"en": "Weapon: none", "zh_CN": "武器：无"},
	"equipment.slot_line": {"en": "%s: %s", "zh_CN": "%s：%s"},
	"equipment.slot_empty": {"en": "%s: -", "zh_CN": "%s：-"},
	"equipment.filter_all": {"en": "All", "zh_CN": "全部"},
	"equipment.filter_weapons": {"en": "Weapons", "zh_CN": "武器"},
	"equipment.filter_equipment": {"en": "Equipment", "zh_CN": "装备"},
	"equipment.sort_rarity": {"en": "Sort: Rarity", "zh_CN": "排序：品质"},
	"equipment.sort_type": {"en": "Sort: Type", "zh_CN": "排序：类型"},
	"equipment.sort_level": {"en": "Sort: Level", "zh_CN": "排序：强化"},
	"equipment.sort_name": {"en": "Sort: Name", "zh_CN": "排序：名称"},
	"equipment.current_selection": {"en": "Current Equipment", "zh_CN": "当前装备"},
	"equipment.compare_selection": {"en": "Compare Selection", "zh_CN": "选择对比"},
	"equipment.currently_equipped": {"en": "Currently equipped", "zh_CN": "当前已装备"},
	"equipment.equipped": {"en": "Equipped", "zh_CN": "已装备"},
	"equipment.send_to_forge": {"en": "Send to Forge", "zh_CN": "送去锻造"},
	"equipment.forge_unavailable": {"en": "Forge Unavailable", "zh_CN": "锻造不可用"},
	"equipment.kind_weapon": {"en": "Weapon", "zh_CN": "武器"},
	"equipment.kind_equipment": {"en": "Equipment", "zh_CN": "装备"},
	"forge.selected_empty": {"en": "Selected: -", "zh_CN": "已选：-"},
	"forge.level_empty": {"en": "Level: -", "zh_CN": "等级：-"},
	"forge.chance_empty": {"en": "Chance: -", "zh_CN": "概率：-"},
	"forge.outcome_empty": {"en": "Outcome: -", "zh_CN": "结果：-"},
	"forge.selected": {"en": "Selected: %s", "zh_CN": "已选：%s"},
	"forge.level": {"en": "Level: +%d", "zh_CN": "等级：+%d"},
	"forge.chance": {"en": "Chance: %d%%", "zh_CN": "成功率：%d%%"},
	"forge.fail": {"en": "Fail: %s", "zh_CN": "失败：%s"},
	"forge.enhance": {"en": "Enhance", "zh_CN": "强化"},
	"forge.failure.materials": {"en": "Materials", "zh_CN": "材料损失"},
	"forge.failure.downgrade": {"en": "Downgrade", "zh_CN": "降级"},
	"forge.failure.durability": {"en": "Durability", "zh_CN": "耐久下降"},
	"forge.failure.break": {"en": "Break", "zh_CN": "破碎"},
	"item.no_selected": {"en": "No item selected.\nPick up or select an item to inspect its build value.", "zh_CN": "未选择物品。\n拾取或选择一个物品来查看构筑价值。"},
	"item.pickup": {"en": "Pickup: %s", "zh_CN": "拾取：%s"},
	"item.current": {"en": "Current: %s", "zh_CN": "当前：%s"},
	"item.none": {"en": "None", "zh_CN": "无"},
	"item.unknown": {"en": "Unknown Item", "zh_CN": "未知物品"},
	"item.compare": {"en": "Compare", "zh_CN": "对比"},
	"item.stats": {"en": "Stats:", "zh_CN": "属性："},
	"item.stats_none": {"en": "Stats: none", "zh_CN": "属性：无"},
	"item.no_direct_change": {"en": "Stats: no direct stat change", "zh_CN": "属性：无直接属性变化"},
	"item.affixes": {"en": "Affixes:", "zh_CN": "词条："},
	"item.affixes_inline": {"en": "Affixes: %s", "zh_CN": "词条：%s"},
	"item.affixes_none": {"en": "Affixes: none", "zh_CN": "词条：无"},
	"item.none_inline": {"en": "none", "zh_CN": "无"},
	"item.damage": {"en": "Damage", "zh_CN": "伤害"},
	"item.attack_speed": {"en": "Attack Speed", "zh_CN": "攻速"},
	"item.crit_chance": {"en": "Crit Chance", "zh_CN": "暴击率"},
	"item.crit_damage": {"en": "Crit Damage", "zh_CN": "暴击伤害"},
	"item.crit": {"en": "Crit", "zh_CN": "暴击"},
	"item.armor_pierce": {"en": "Armor Pierce", "zh_CN": "破甲"},
	"item.pierce": {"en": "Pierce", "zh_CN": "穿透"},
	"item.durability": {"en": "Durability", "zh_CN": "耐久"},
	"item.element": {"en": "Element", "zh_CN": "元素"},
	"item.same": {"en": "same", "zh_CN": "相同"},
	"item.vs_current": {"en": "%s vs current", "zh_CN": "相对当前 %s"},
	"item.damage_line": {"en": "Damage: %s", "zh_CN": "伤害：%s"},
	"item.attack_speed_line": {"en": "Attack Speed: %s/s", "zh_CN": "攻速：%s/秒"},
	"item.crit_line": {"en": "Crit: %s at x%s", "zh_CN": "暴击：%s，倍率 x%s"},
	"item.armor_pierce_line": {"en": "Armor Pierce: %s", "zh_CN": "破甲：%s"},
	"item.pierce_line": {"en": "Pierce: %d", "zh_CN": "穿透：%d"},
	"item.durability_line": {"en": "Durability: %s", "zh_CN": "耐久：%s"},
	"affix.fire_burst_effect": {"en": "%s Fire Burst", "zh_CN": "%s 火焰爆裂"},
	"affix.frostbite_effect": {"en": "%s Frostbite Slow", "zh_CN": "%s 冰蚀减速"},
	"affix.chain_lightning_effect": {"en": "%s Chain Lightning", "zh_CN": "%s 连锁闪电"},
	"affix.rift_echo_effect": {"en": "%s Rift Echo", "zh_CN": "%s 裂隙回响"},
	"affix.gravity_well_effect": {"en": "%s Gravity Well", "zh_CN": "%s 引力井"},
	"affix.proc_effect": {"en": "%s proc", "zh_CN": "%s 触发"},
	"affix.passive": {"en": "Passive", "zh_CN": "被动"},
	"rarity.common": {"en": "Common", "zh_CN": "普通"},
	"rarity.rare": {"en": "Rare", "zh_CN": "稀有"},
	"rarity.epic": {"en": "Epic", "zh_CN": "史诗"},
	"rarity.legendary": {"en": "Legendary", "zh_CN": "传说"},
	"rarity.mythic": {"en": "Mythic", "zh_CN": "神话"},
	"weapon_family.handgun": {"en": "Handgun", "zh_CN": "手枪"},
	"weapon_family.rifle": {"en": "Rifle", "zh_CN": "步枪"},
	"weapon_family.shotgun": {"en": "Shotgun", "zh_CN": "霰弹枪"},
	"weapon_family.sniper": {"en": "Sniper", "zh_CN": "狙击枪"},
	"weapon_family.staff": {"en": "Staff", "zh_CN": "法杖"},
	"weapon_family.bow": {"en": "Bow", "zh_CN": "弓"},
	"weapon_family.spear": {"en": "Spear", "zh_CN": "长矛"},
	"weapon_family.greatsword": {"en": "Greatsword", "zh_CN": "大剑"},
	"weapon_family.dual_blade": {"en": "Dual Blade", "zh_CN": "双刀"},
	"weapon_family.thrown": {"en": "Thrown", "zh_CN": "投掷"},
	"weapon_family.summon": {"en": "Summon", "zh_CN": "召唤"},
	"element.physical": {"en": "Physical", "zh_CN": "物理"},
	"element.fire": {"en": "Fire", "zh_CN": "火焰"},
	"element.ice": {"en": "Ice", "zh_CN": "冰霜"},
	"element.poison": {"en": "Poison", "zh_CN": "毒素"},
	"element.lightning": {"en": "Lightning", "zh_CN": "闪电"},
	"element.arcane": {"en": "Arcane", "zh_CN": "奥术"},
	"slot.weapon": {"en": "Weapon", "zh_CN": "武器"},
	"slot.helmet": {"en": "Helmet", "zh_CN": "头盔"},
	"slot.chest": {"en": "Chest", "zh_CN": "胸甲"},
	"slot.gloves": {"en": "Gloves", "zh_CN": "手套"},
	"slot.boots": {"en": "Boots", "zh_CN": "鞋子"},
	"slot.trinket": {"en": "Trinket", "zh_CN": "饰品"},
	"slot.ring": {"en": "Ring", "zh_CN": "戒指"},
	"stat.max_health": {"en": "Max Health", "zh_CN": "最大生命"},
	"stat.armor": {"en": "Armor", "zh_CN": "护甲"},
	"stat.armor_durability": {"en": "Armor Durability", "zh_CN": "护甲耐久"},
	"stat.armor_damage_reduction": {"en": "Armor DR", "zh_CN": "护甲减伤"},
	"stat.damage_multiplier": {"en": "Damage", "zh_CN": "伤害"},
	"stat.crit_chance": {"en": "Crit Chance", "zh_CN": "暴击率"},
	"stat.crit_damage": {"en": "Crit Damage", "zh_CN": "暴击伤害"},
	"stat.armor_pierce": {"en": "Armor Pierce", "zh_CN": "破甲"},
	"stat.attack_speed": {"en": "Attack Speed", "zh_CN": "攻速"},
	"stat.move_speed": {"en": "Move Speed", "zh_CN": "移速"},
	"stat.dodge_chance": {"en": "Dodge", "zh_CN": "闪避"},
	"stat.skill_cooldown_reduction": {"en": "Skill Cooldown", "zh_CN": "技能冷却"},
	"stat.energy_recovery": {"en": "Energy Recovery", "zh_CN": "能量恢复"},
	"room_type.combat": {"en": "Combat", "zh_CN": "战斗"},
	"room_type.elite": {"en": "Elite", "zh_CN": "精英"},
	"room_type.treasure": {"en": "Treasure", "zh_CN": "宝箱"},
	"room_type.shop": {"en": "Shop", "zh_CN": "商店"},
	"room_type.forge": {"en": "Forge", "zh_CN": "锻造"},
	"room_type.event": {"en": "Event", "zh_CN": "事件"},
	"room_type.boss": {"en": "Boss", "zh_CN": "Boss"},
	"talent.vital_core.name": {"en": "Vital Core", "zh_CN": "生命核心"},
	"talent.vital_core.desc": {"en": "+10 Max Health per level", "zh_CN": "每级 +10 最大生命"},
	"talent.reinforced_plating.name": {"en": "Reinforced Plating", "zh_CN": "强化镀层"},
	"talent.reinforced_plating.desc": {"en": "+4 Armor and +12 Armor Durability per level", "zh_CN": "每级 +4 护甲，+12 护甲耐久"},
	"talent.weapon_training.name": {"en": "Weapon Training", "zh_CN": "武器训练"},
	"talent.weapon_training.desc": {"en": "+5% Damage per level", "zh_CN": "每级 +5% 伤害"},
	"talent.scavenger_instinct.name": {"en": "Scavenger Instinct", "zh_CN": "拾荒本能"},
	"talent.scavenger_instinct.desc": {"en": "+3% enemy drop chance per level", "zh_CN": "每级 +3% 怪物掉落率"},
	"class.vanguard.name": {"en": "Vanguard", "zh_CN": "先锋"},
	"class.vanguard.desc": {"en": "A front-line class built around armor uptime and steady weapon pressure.", "zh_CN": "以前线抗压、护甲维持和稳定武器压制为核心的职业。"},
	"weapon.ember_snap.name": {"en": "Ember Snap", "zh_CN": "余烬短鸣"},
	"weapon.ember_snap.desc": {"en": "A compact sidearm tuned for fast close-range pressure.", "zh_CN": "一把紧凑副武器，适合快速近距离压制。"},
	"weapon.frostline_staff.name": {"en": "Frostline Staff", "zh_CN": "霜线法杖"},
	"weapon.frostline_staff.desc": {"en": "A slow arcane focus that rewards spacing and piercing shots.", "zh_CN": "慢速奥术焦点，奖励拉扯站位与穿透射击。"},
	"weapon.volt_spear.name": {"en": "Volt Spear", "zh_CN": "伏特长矛"},
	"weapon.volt_spear.desc": {"en": "A line weapon that punches through clustered armored targets.", "zh_CN": "线形武器，擅长击穿聚集的重甲目标。"},
	"weapon.warden_rift_staff.name": {"en": "Warden Rift Staff", "zh_CN": "守望裂隙杖"},
	"weapon.warden_rift_staff.desc": {"en": "A boss-forged staff that fires slow, piercing rift bolts.", "zh_CN": "Boss 熔铸的法杖，发射缓慢但可穿透的裂隙弹。"},
	"weapon.rift_needle.name": {"en": "Rift Needle", "zh_CN": "裂隙针"},
	"weapon.rift_needle.desc": {"en": "A narrow sniper focus that rewards precise void shots.", "zh_CN": "狭窄的狙击焦点，奖励精准的虚空射击。"},
	"weapon.null_orbit_staff.name": {"en": "Null Orbit Staff", "zh_CN": "归零轨杖"},
	"weapon.null_orbit_staff.desc": {"en": "A slow orbital staff that bends clustered enemies toward its impact point.", "zh_CN": "缓慢的环轨法杖，会把聚集敌人拉向命中点。"},
	"weapon.astral_repeater.name": {"en": "Astral Repeater", "zh_CN": "星界连发器"},
	"weapon.astral_repeater.desc": {"en": "A light rifle that layers quick arcane hits into echo pressure.", "zh_CN": "轻型步枪，以快速奥术命中叠出回响压力。"},
	"weapon.phase_halberd.name": {"en": "Phase Halberd", "zh_CN": "相位戟"},
	"weapon.phase_halberd.desc": {"en": "A heavy arcane spear that hooks armored packs into a gravity split.", "zh_CN": "沉重奥术长矛，将重甲群体拖入引力裂口。"},
	"equipment.ashguard_helm.name": {"en": "Ashguard Helm", "zh_CN": "灰卫头盔"},
	"equipment.ashguard_helm.desc": {"en": "A plain helm reinforced against glancing strikes.", "zh_CN": "朴素但加固过的头盔，可抵御擦击。"},
	"equipment.rivet_chestplate.name": {"en": "Rivet Chestplate", "zh_CN": "铆钉胸甲"},
	"equipment.rivet_chestplate.desc": {"en": "Heavy front plating with a real mobility cost.", "zh_CN": "厚重前甲，带来明显机动惩罚。"},
	"equipment.quickspark_gloves.name": {"en": "Quickspark Gloves", "zh_CN": "迅火手套"},
	"equipment.quickspark_gloves.desc": {"en": "Conductive grips that favor rapid weapons.", "zh_CN": "导电握具，适合高攻速武器。"},
	"equipment.trailblazer_boots.name": {"en": "Trailblazer Boots", "zh_CN": "开路者长靴"},
	"equipment.trailblazer_boots.desc": {"en": "Light boots made for strafing through narrow rooms.", "zh_CN": "轻便长靴，适合在狭窄房间中横移穿梭。"},
	"equipment.lumen_ring.name": {"en": "Lumen Ring", "zh_CN": "流明戒指"},
	"equipment.lumen_ring.desc": {"en": "A small ring that helps future active-skill builds.", "zh_CN": "一枚小戒指，为后续主动技能流派做准备。"},
	"equipment.cinderplate_core.name": {"en": "Cinderplate Core", "zh_CN": "烬甲核心"},
	"equipment.cinderplate_core.desc": {"en": "A dense chest core that rewards armor-heavy builds.", "zh_CN": "沉重的胸甲核心，奖励重甲构筑。"},
	"equipment.bulwark_ember_ring.name": {"en": "Bulwark Ember Ring", "zh_CN": "壁垒余烬戒"},
	"equipment.bulwark_ember_ring.desc": {"en": "A heated ring that turns pressure into piercing strikes.", "zh_CN": "灼热戒指，将压力转化为穿透打击。"},
	"equipment.abyssal_guard_helm.name": {"en": "Abyssal Guard Helm", "zh_CN": "深渊卫盔"},
	"equipment.abyssal_guard_helm.desc": {"en": "A void-marked helm for cooldown and armor builds.", "zh_CN": "带虚空印记的头盔，适合冷却与护甲构筑。"},
	"equipment.riftseer_hood.name": {"en": "Riftseer Hood", "zh_CN": "裂隙先知兜帽"},
	"equipment.riftseer_hood.desc": {"en": "A hood lined with glassy thread for reading void afterimages.", "zh_CN": "缝有玻璃丝线的兜帽，可辨读虚空残影。"},
	"equipment.voidglass_mantle.name": {"en": "Voidglass Mantle", "zh_CN": "虚玻披甲"},
	"equipment.voidglass_mantle.desc": {"en": "Dense voidglass plates that crack armor lines while slowing footwork.", "zh_CN": "密实虚玻甲片，能裂解护甲纹路但拖慢脚步。"},
	"equipment.astral_weave_grips.name": {"en": "Astral Weave Grips", "zh_CN": "星织握套"},
	"equipment.astral_weave_grips.desc": {"en": "Soft grip wraps that make rapid arcane bursts easier to control.", "zh_CN": "柔软握套，让高速奥术爆发更容易控制。"},
	"equipment.phasewalk_soles.name": {"en": "Phasewalk Soles", "zh_CN": "相位行靴"},
	"equipment.phasewalk_soles.desc": {"en": "Boot soles that slip slightly out of phase during lateral movement.", "zh_CN": "横移时会轻微脱相的靴底。"},
	"equipment.singularity_charm.name": {"en": "Singularity Charm", "zh_CN": "奇点护符"},
	"equipment.singularity_charm.desc": {"en": "A tiny sealed collapse that feeds power into high-risk builds.", "zh_CN": "封存微型塌缩的护符，为高风险构筑供能。"},
	"equipment.orbit_signet.name": {"en": "Orbit Signet", "zh_CN": "环轨戒"},
	"equipment.orbit_signet.desc": {"en": "A ring etched with orbital marks for precise armor-breaking shots.", "zh_CN": "刻有环轨纹的戒指，适合精准破甲射击。"},
	"affix.armor_piercing.name": {"en": "Armor Piercing", "zh_CN": "穿甲"},
	"affix.armor_piercing.desc": {"en": "Improves damage against armored targets.", "zh_CN": "提升对护甲目标的伤害。"},
	"affix.ember_burst.name": {"en": "Ember Burst", "zh_CN": "余烬爆裂"},
	"affix.ember_burst.desc": {"en": "Marks this weapon for future fire burst effects.", "zh_CN": "该武器可触发火焰爆裂效果。"},
	"affix.frostbite.name": {"en": "Frostbite", "zh_CN": "冰蚀"},
	"affix.frostbite.desc": {"en": "Marks this weapon for future freeze and shatter effects.", "zh_CN": "该武器可触发冰霜减速效果。"},
	"affix.storm_chain.name": {"en": "Storm Chain", "zh_CN": "风暴链"},
	"affix.storm_chain.desc": {"en": "Marks this weapon for future chain lightning effects.", "zh_CN": "该武器可触发连锁闪电效果。"},
	"affix.rift_echo.name": {"en": "Rift Echo", "zh_CN": "裂隙回响"},
	"affix.rift_echo.desc": {"en": "Repeats a fraction of a hit after a brief void delay.", "zh_CN": "短暂虚空延迟后重复一部分命中伤害。"},
	"affix.gravity_well.name": {"en": "Gravity Well", "zh_CN": "引力井"},
	"affix.gravity_well.desc": {"en": "Opens a small gravity tear that pulls and damages nearby enemies.", "zh_CN": "打开小型引力裂口，拉扯并伤害附近敌人。"},
	"enemy.ashling.name": {"en": "Ashling", "zh_CN": "灰烬灵"},
	"enemy.ashling.desc": {"en": "A fast pressure enemy that tests movement basics.", "zh_CN": "快速压迫型敌人，用来检验基础走位。"},
	"enemy.glassmite.name": {"en": "Glassmite", "zh_CN": "晶螨"},
	"enemy.glassmite.desc": {"en": "Fragile, quick, and built to punish tunnel vision.", "zh_CN": "脆弱但灵活，专门惩罚视野狭窄的玩家。"},
	"enemy.iron_husk.name": {"en": "Iron Husk", "zh_CN": "铁壳"},
	"enemy.iron_husk.desc": {"en": "A slow armored enemy that encourages pierce and armor break builds.", "zh_CN": "缓慢的重甲敌人，鼓励穿透和破甲构筑。"},
	"enemy.cinder_bulwark.name": {"en": "Cinder Bulwark", "zh_CN": "烬火壁垒"},
	"enemy.cinder_bulwark.desc": {"en": "The floor five armor check.", "zh_CN": "第 5 层的护甲检验者。"},
	"enemy.depths_warden.name": {"en": "Depths Warden", "zh_CN": "深层守望者"},
	"enemy.depths_warden.desc": {"en": "The first-theme boss for the ten-floor slice.", "zh_CN": "10 层切片第一主题的最终 Boss。"},
	"elite_affix.flaming.name": {"en": "Flaming", "zh_CN": "烈焰"},
	"elite_affix.flaming.desc": {"en": "Explodes after death with a readable short warning.", "zh_CN": "死亡后短暂预警并爆炸。"},
	"elite_affix.swift.name": {"en": "Swift", "zh_CN": "迅捷"},
	"elite_affix.swift.desc": {"en": "Moves faster and attacks with a shorter windup.", "zh_CN": "移动更快，攻击前摇更短。"},
	"elite_affix.juggernaut.name": {"en": "Juggernaut", "zh_CN": "重甲"},
	"elite_affix.juggernaut.desc": {"en": "Carries heavier armor and shrugs off stagger quickly.", "zh_CN": "拥有更厚护甲，并更快摆脱硬直。"},
	"elite_affix.phasing.name": {"en": "Phasing", "zh_CN": "虚化"},
	"elite_affix.phasing.desc": {"en": "Briefly becomes untouchable, then takes extra damage during recovery.", "zh_CN": "短暂不可命中，恢复期受到额外伤害。"},
	"elite_affix.vampiric.name": {"en": "Vampiric", "zh_CN": "吸血"},
	"elite_affix.vampiric.desc": {"en": "Heals when its attacks connect.", "zh_CN": "命中玩家后回复生命。"},
	"event.ember_pact.name": {"en": "Ember Pact", "zh_CN": "余烬契约"},
	"event.ember_pact.prompt": {"en": "Invoke Ember Pact", "zh_CN": "缔结余烬契约"},
	"event.ember_pact.desc": {"en": "Trade blood for a run-long damage surge.", "zh_CN": "以生命换取本局持续的伤害提升。"},
	"event.iron_oath.name": {"en": "Iron Oath", "zh_CN": "铁誓"},
	"event.iron_oath.prompt": {"en": "Swear Iron Oath", "zh_CN": "立下铁誓"},
	"event.iron_oath.desc": {"en": "Scar your plating for sharper armor break pressure.", "zh_CN": "损耗护甲耐久，换取更强破甲压力。"},
	"event.trial_altar.name": {"en": "Trial Altar", "zh_CN": "试炼祭坛"},
	"event.trial_altar.prompt": {"en": "Begin Trial", "zh_CN": "开始试炼"},
	"event.trial_altar.desc": {"en": "Call an elite guardian and claim its sealed cache.", "zh_CN": "召来精英守卫，击败后领取封印宝箱。"},
	"event.starless_lens.name": {"en": "Starless Lens", "zh_CN": "无星透镜"},
	"event.starless_lens.prompt": {"en": "Gaze Through Starless Lens", "zh_CN": "凝视无星透镜"},
	"event.starless_lens.desc": {"en": "Trade blood for sharper void-critical timing this run.", "zh_CN": "以生命换取本局更锋利的虚空暴击节奏。"},
	"event.rift_anchor.name": {"en": "Rift Anchor", "zh_CN": "裂隙锚"},
	"event.rift_anchor.prompt": {"en": "Bind Rift Anchor", "zh_CN": "绑定裂隙锚"},
	"event.rift_anchor.desc": {"en": "Scar your armor with a void anchor for heavier armor-breaking power.", "zh_CN": "用虚空锚刻伤护甲，换取更重的破甲力量。"},
	"room.combat_room.name": {"en": "Combat Room", "zh_CN": "战斗房"},
	"room.elite_room.name": {"en": "Elite Room", "zh_CN": "精英房"},
	"room.treasure_room.name": {"en": "Treasure Room", "zh_CN": "宝箱房"},
	"room.forge_room.name": {"en": "Forge Room", "zh_CN": "锻造房"},
	"room.event_room.name": {"en": "Event Room", "zh_CN": "事件房"},
	"room.mini_boss_room.name": {"en": "Bulwark Gate", "zh_CN": "壁垒之门"},
	"room.boss_room.name": {"en": "Depths Warden", "zh_CN": "深层守望者"},
}

var current_language := DEFAULT_LANGUAGE
var settings_service: Node

func _ready() -> void:
	add_to_group("localization_service")

func bind_settings(service: Node) -> void:
	settings_service = service
	if settings_service != null and settings_service.has_signal("language_changed"):
		var language_callable := Callable(self, "_on_settings_language_changed")
		if not settings_service.language_changed.is_connected(language_callable):
			settings_service.language_changed.connect(language_callable)
	if settings_service != null and settings_service.has_method("get_language"):
		_apply_language(settings_service.get_language())

func set_language(language: String) -> void:
	var normalized := normalize_language(language)
	if settings_service != null and settings_service.has_method("set_language"):
		settings_service.set_language(normalized)
	else:
		_apply_language(normalized)

func language() -> String:
	return current_language

func supported_languages() -> Array:
	return SUPPORTED_LANGUAGES.duplicate()

func language_display_name(language: String) -> String:
	return str(LANGUAGE_NAMES.get(normalize_language(language), language))

func text(key: String, fallback := "") -> String:
	var entry = STRINGS.get(key)
	if entry is Dictionary:
		if entry.has(current_language):
			return str(entry[current_language])
		if entry.has(DEFAULT_LANGUAGE):
			return str(entry[DEFAULT_LANGUAGE])
	return fallback if not fallback.is_empty() else key

func format_text(key: String, args: Array = [], fallback := "") -> String:
	return text(key, fallback) % args

func has_text(key: String, language := "") -> bool:
	var target_language := normalize_language(language) if not language.is_empty() else current_language
	var entry = STRINGS.get(key)
	return entry is Dictionary and entry.has(target_language) and not str(entry[target_language]).is_empty()

func resource_name(resource: Resource) -> String:
	return text(resource_key(resource, "name"), _resource_fallback(resource, "display_name"))

func resource_description(resource: Resource) -> String:
	return text(resource_key(resource, "desc"), _resource_fallback(resource, "description"))

func resource_prompt(resource: Resource) -> String:
	var fallback := _resource_fallback(resource, "prompt_text")
	if fallback.is_empty() and resource != null:
		fallback = format_text("interact.use_event", [_resource_fallback(resource, "display_name")], "Use %s")
	return text(resource_key(resource, "prompt"), fallback)

func has_resource_translation(resource: Resource, suffix: String, language: String) -> bool:
	return has_text(resource_key(resource, suffix), language)

func resource_key(resource: Resource, suffix: String) -> String:
	if resource == null:
		return ""
	var id := str(resource.get("id"))
	if id.is_empty():
		return ""
	return "%s.%s.%s" % [_resource_prefix(resource), id, suffix]

func normalize_language(language: String) -> String:
	return language if SUPPORTED_LANGUAGES.has(language) else DEFAULT_LANGUAGE

func _on_settings_language_changed(language: String) -> void:
	_apply_language(language)

func _apply_language(language: String) -> void:
	var normalized := normalize_language(language)
	if current_language == normalized:
		return
	current_language = normalized
	language_changed.emit(current_language)

func _resource_prefix(resource: Resource) -> String:
	if resource == null:
		return "resource"
	if resource.has_method("create_damage_packet"):
		return "weapon"
	if resource.has_method("get_slot_name"):
		return "equipment"
	if resource.has_method("is_boss"):
		return "enemy"
	if resource.has_method("room_type_name"):
		return "room"
	if resource.has_method("get_prompt"):
		return "event"
	if resource.get("effect_id") != null:
		return "affix"
	if resource.get("active_skill_id") != null:
		return "class"
	if resource.get("contact_damage_multiplier") != null:
		return "elite_affix"
	return "resource"

func _resource_fallback(resource: Resource, property_name: String) -> String:
	if resource == null:
		return ""
	var value = resource.get(property_name)
	return str(value) if value != null else ""
