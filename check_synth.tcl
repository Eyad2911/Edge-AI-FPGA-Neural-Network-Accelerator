open_project project_1.xpr
reset_run synth_1
launch_runs synth_1 -jobs 2
wait_on_run synth_1
set status [get_property STATUS [get_runs synth_1]]
puts "SYNTH_STATUS=$status"
if {[string first "Complete" $status] < 0} {
    exit 1
}
exit 0
