
xrepl do
	inputs.keyboard.key_held.d ? @player.dx = 6 : @player.dx = 0
	inputs.keyboard.key_held.a ? @player.dx = -6 : @player.dx = 0
end
