using JuMP, GLPK
using CSV
using DataFrames

m=Model(GLPK.Optimizer)

cd(@__DIR__)
data = DataFrame(CSV.File("cont_data_interp.csv"))

days = 200

timestamps = data[1:48*days, 1]
DA_prices = data[1:48*days, 2]
ID_prices = data[1:48*days, 3]

n_battery = 0.92
B_cap = 1
SOC_initial = 0.1
SOC_up = 0.9
SOC_low = 0.1
lim_cycle = 4
Pc_rate = 0.6


# Variable definitions

@variable(m, p_DA_ch[1:48*days] >=0)
@variable(m, p_DA_dis[1:48*days] >=0)
@variable(m, p_ID_ch[1:48*days] >=0)
@variable(m, p_ID_dis[1:48*days] >=0)
@variable(m, SOC_low <=soc[1:48*days] <= SOC_up)
@variable(m, 1 >= Q_ch[1:48*days] >= 0)
@variable(m, 1 >= Q_dis[1:48*days] >= 0)
@variable(m, Z_DA_ch[1:48*days], Bin)
@variable(m, Z_DA_dis[1:48*days], Bin)
@variable(m, Z_ID_ch[1:48*days], Bin)
@variable(m, Z_ID_dis[1:48*days], Bin)

# Objective function
@objective(m, Max, sum(DA_prices[t]*(1/2)*(p_DA_dis[t] - p_DA_ch[t]) for t = 1:48*days) + sum(ID_prices[t]*(1/2)*(p_ID_dis[t] - p_ID_ch[t]) for t = 1:48*days))


# Constraint definitions
# Define start charge constraint
@constraint(m, soc[1] == SOC_initial + n_battery*Q_ch[1] - (1/n_battery)*Q_dis[1])

for t = 2:48*days
    # Next charge equal last charge + action
    @constraint(m, soc[t] == soc[t-1] + n_battery*Q_ch[t] - (1/n_battery)*Q_dis[t])
end

for t = 1:48*days
    # Next charge equal last charge + action

    @constraint(m,((p_DA_ch[t] - p_DA_dis[t] + p_ID_ch[t] - p_ID_dis[t])/B_cap)*1/2 == Q_ch[t]-Q_dis[t])

    # Only charge/discharge if z = 1
    @constraint(m, p_DA_ch[t] <= Pc_rate*Z_DA_ch[t])
    @constraint(m, p_DA_dis[t] <= Pc_rate*Z_DA_dis[t])
    @constraint(m, p_ID_ch[t] <= Pc_rate*Z_ID_ch[t])
    @constraint(m, p_ID_dis[t] <= Pc_rate*Z_ID_dis[t])
    @constraint(m, p_ID_ch[t] + p_DA_ch[t] <= Pc_rate)
    @constraint(m, p_ID_dis[t] + p_DA_dis[t] <= Pc_rate)
    @constraint(m, Z_DA_ch[t] + Z_DA_dis[t] <= 1)
    @constraint(m, Z_ID_ch[t] + Z_ID_dis[t] <= 1)

end

# Limit cycle constraint
for d = 1:days
    @constraint(m, sum(Q_ch[t] + Q_dis[t] for t = 1+48*(d-1):d*48) <= lim_cycle)
end

for t = 1:24*days
    @constraint(m, p_DA_ch[2*t-1] == p_DA_ch[2*t])
    @constraint(m, p_DA_dis[2*t-1] == p_DA_dis[2*t])
end


optimize!(m)
println(JuMP.value.(Z_ID_ch))
println(JuMP.value.(Z_ID_dis))
println(JuMP.value.(Z_DA_ch))
println(JuMP.value.(Z_DA_dis))
println(JuMP.value.(soc))

println(sum(JuMP.value.(Z_ID_dis)) + sum(JuMP.value.(Z_DA_dis)))
println("Objective value: ", JuMP.objective_value(m))

alldata = DataFrame(times = timestamps, da_price = DA_prices,id_prices = ID_prices, z_id_ch = JuMP.value.(Z_ID_ch),z_id_dis = JuMP.value.(Z_ID_dis),z_da_ch = JuMP.value.(Z_DA_ch),z_da_dis = JuMP.value.(Z_DA_dis),SOC = JuMP.value.(soc),q_ch = JuMP.value.(Q_ch),q_dis = JuMP.value.(Q_dis), p_da_dis = JuMP.value.(p_DA_dis),p_da_ch = JuMP.value.(p_DA_ch), p_id_dis = JuMP.value.(p_ID_dis), p_id_ch = JuMP.value.(p_ID_ch))
println(alldata)
CSV.write("C:\\Users\\Jonat\\OneDrive\\Skrivebord\\Kandidat\\Battery Project\\JuliaCode\\alldata.csv",alldata)
