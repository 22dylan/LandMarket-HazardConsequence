# struct Foo{T, D}   
# 	bar::T
#   	baz::D
# end


# foo = Foo([1], 2)
# too = Foo(1.2, 3)
# println(foo.bar, ' ', foo.baz)
# println(too.bar, ' ', too.baz)
# println(fieldnames(Foo))
# for field in fieldnames(Foo)
#    println(field)
#    println(typeof(field))
#    println(typeof(getfield(too,field)))
#    println()
# end

function logistic_population(t, k, P0, r)
	A = (k-P0)/P0
	P = k/(1+A*exp(-r*t))
	return round(Int, P)
end


p = logistic_population(100, 600, 102, 0.1)
println(p)