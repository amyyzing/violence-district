return function(c)
	local feature = {}

	function feature.setEnabled(on)
		local nextValue = on == true
		if c.getEnabled() == nextValue then
			return
		end

		c.setEnabled(nextValue)
		if c.apply then
			c.apply()
		end
		c.emit()
	end

	function feature.toggle()
		feature.setEnabled(not c.getEnabled())
	end

	return feature
end
