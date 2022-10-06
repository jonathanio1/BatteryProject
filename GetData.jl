using CSV
using DataFrames


cd(@__DIR__)
data = DataFrame(CSV.File("cont_data_interp.csv"))
timestamps = data[1:48, 1]
DA_prices = data[1:48, 2]
ID_prices = data[1:48, 3]
println(timestamps)
println(data[1488,1])
