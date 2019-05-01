extends CanvasLayer

func _ready():
	Network.connect("stats", self, "update_HUD")

func update_bar(bar):
	var bar_node = get_node("HUD/" + bar + "Bar")
	var label = get_node("HUD/" + bar + "Label")
	
	label.set_text(str(bar_node.value, "/", bar_node.max_value))
	if bar_node.value < bar_node.max_value / 8:
		label.modulate = Color.red
	elif bar_node.value < bar_node.max_value / 4:
		label.modulate = Color.yellow
	else:
		label.modulate = Color.white

func exp_for_level(level):
	return level * 10
	
func total_exp_for_level(level):
	return level * (level + 1) * 5

func update_HUD(data):
	if "max_hp" in data:
		$HUD/HPBar.max_value = data.max_hp
		update_bar("HP")
	
	if "hp" in data:
		$HUD/HPBar.value = data.hp
		update_bar("HP")
	
	if "max_mp" in data:
		$HUD/MPBar.max_value = data.max_mp
		update_bar("MP")
	
	if "mp" in data:
		$HUD/MPBar.value = data.mp
		update_bar("MP")
	
	if "level" in data:
		$HUD/LvLabel.text = str(data.level)
	
	if "exp" in data:
		var lv = int($HUD/LvLabel.text)
		$HUD/ExpBar.max_value = exp_for_level(lv)
		$HUD/ExpBar.value = data.exp - total_exp_for_level(lv-1)