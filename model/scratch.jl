function f(b...) 
	idx = 2
	for i in eachindex(b)
		nothing		
		# attr[i] = b[i][idx]
	end
end

a = [[1], [2], [3]]
b = [[1, 3], [2, 4], [3, 5]]
f(a, b)
# a = f(a,b)

