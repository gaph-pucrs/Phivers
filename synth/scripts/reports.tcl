################################################################################
# Phivers PE - reporting helpers
################################################################################

# Prints a banner in the log so that the phases are easy to find.
proc banner {msg} {
    puts "\n[string repeat = 80]"
    puts "== $msg"
    puts "[string repeat = 80]\n"
}

# Runs a report and keeps going if it fails. Reporting must never throw away a
# synthesis run, and -abort_on_error would do exactly that.
proc rpt {args} {
    if {[catch {uplevel 1 $args} msg]} {
        puts "WARNING: '[lindex $args 0]' failed, report skipped"
        puts "         $msg"
    }
}

# Reports that make sense right after elaboration / init_design.
proc report_elaboration {} {
    global REPORTS_DIR
    set dir $REPORTS_DIR/elaborate
    file mkdir $dir

    rpt check_design -all                            > $dir/check_design.rpt
    rpt check_timing_intent -verbose                 > $dir/check_timing_intent.rpt
    rpt report_timing -lint -verbose                 > $dir/timing_lint.rpt
    rpt report_timing -unconstrained -max_paths 100  > $dir/timing_unconstrained.rpt
    rpt report_clocks -generated                     > $dir/clocks.rpt
    rpt report_clock_groups                          > $dir/clock_groups.rpt
    rpt report_hierarchy                             > $dir/hierarchy.rpt
}

# QoR snapshot for one stage of the flow (generic, map, opt).
proc report_stage {stage} {
    global REPORTS_DIR
    set dir $REPORTS_DIR/$stage
    file mkdir $dir

    rpt report_area                                  > $dir/area.rpt
    rpt report_gates                                 > $dir/gates.rpt
    rpt report_timing -max_paths 50                  > $dir/timing.rpt
    rpt report_qor                                   > $dir/qor.rpt

    # and a short summary in the log itself
    rpt report_qor
}

# Sign-off style reporting, per analysis view. Restores the multi-view setup
# before returning.
proc report_final {} {
    global REPORTS_DIR

    set dir $REPORTS_DIR/final
    file mkdir $dir

    rpt report_qor                                   > $dir/qor.rpt
    rpt report_area                                  > $dir/area.rpt
    rpt report_area -depth 3                         > $dir/area_hier.rpt
    rpt report_gates                                 > $dir/gates.rpt
    rpt report_clock_gating                          > $dir/clock_gating.rpt
    rpt report_sequential -mapping                   > $dir/sequential_mapping.rpt
    rpt report_sequential -deleted -optimized        > $dir/sequential_deleted.rpt
    rpt report_timing_derate                         > $dir/timing_derate.rpt
    rpt report_timing -lint -verbose                 > $dir/timing_lint.rpt
    rpt report_timing -unconstrained -max_paths 100  > $dir/timing_unconstrained.rpt
    if {[get_db interconnect_mode] eq "ple"} {
        rpt report_ple                               > $dir/ple.rpt
    }

    # Setup timing per corner. Hold is not reported here on purpose: before CTS
    # the clock is ideal, so hold numbers out of Genus mean nothing. Hold is
    # closed in Innovus once the clock tree exists.
    foreach view {av_slow av_typ av_fast} {
        rpt report_timing -views $view -max_paths 50 > $dir/timing_$view.rpt
    }

    rpt report_power -view av_typ -unit mW           > $dir/power_av_typ.rpt
}
